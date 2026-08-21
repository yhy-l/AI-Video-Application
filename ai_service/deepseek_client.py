"""DeepSeek 对话客户端：多轮会话 + ToolCalling（工具调用）"""

import asyncio
import json
import re
import uuid
from datetime import datetime

from openai import OpenAI

from config import (
    DEEPSEEK_API_KEY,
    DEEPSEEK_BASE_URL,
    DEFAULT_MODEL,
    DEFAULT_TEMPERATURE,
    DEFAULT_MAX_TOKENS,
)
from tools import TOOLS, TOOL_MAP, get_recommend_videos, get_danmaku_sentiment, \
    get_user_history, get_user_stats, get_video_info


SYSTEM_PROMPT = (
    "你是「bilibili AI 智能助手」，一只住在桌面上的猫娘助手喵～\n"
    "你可以调用工具读取 bilibili 的实时业务数据，帮助主人：\n"
    "1. 个性化视频推荐（结合主人的观看历史与热门榜）；\n"
    "2. 弹幕情感分析（分析某个视频弹幕的正面/负面情绪）；\n"
    "3. 观看行为建议（根据历史记录给主人提建议）。\n"
    "回答要简洁（一般 150 字内）、口语化，句尾带喵～；\n"
    "数据来自工具返回，不要编造数字。用户未登录时涉及个人数据要提示先登录。"
)


class AiAssistant:
    """单例：会话管理 + 流式/非流式 DeepSeek 对话 + ToolCalling"""

    _instance: "AiAssistant | None" = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        self._client = None
        if DEEPSEEK_API_KEY and DEEPSEEK_API_KEY != "YOUR_DEEPSEEK_API_KEY":
            self._client = OpenAI(api_key=DEEPSEEK_API_KEY, base_url=DEEPSEEK_BASE_URL)
        self._conversations: dict[str, list[dict]] = {}
        self._meta: dict[str, dict] = {}
        self._lock = asyncio.Lock()

    @property
    def online(self) -> bool:
        return self._client is not None

    async def get_or_create_session(self, session_id: str | None) -> str:
        async with self._lock:
            if session_id and session_id in self._conversations:
                return session_id
            sid = session_id or uuid.uuid4().hex[:12]
            self._conversations[sid] = [{"role": "system", "content": SYSTEM_PROMPT}]
            self._meta[sid] = {"created_at": datetime.now().isoformat(), "message_count": 0}
            return sid

    async def chat(self, session_id: str, question: str, token: str = ""):
        """非流式聊天：自动执行 ToolCalling，返回 (answer, tools_used)"""
        sid = await self.get_or_create_session(session_id)
        conv = self._conversations[sid]
        conv.append({"role": "user", "content": question})

        if self._client is None:
            answer, tools_used = self._mock_chat(question, token)
        else:
            answer, tools_used = await self._tool_chat(conv, token)

        conv.append({"role": "assistant", "content": answer})
        self._meta[sid]["message_count"] += 1
        return sid, answer, tools_used

    async def _tool_chat(self, conv: list[dict], token: str):
        """DeepSeek ToolCalling 循环（最多 5 轮工具调用）"""
        used: list[str] = []
        for _ in range(5):
            resp = self._client.chat.completions.create(
                model=DEFAULT_MODEL,
                messages=conv,
                tools=TOOLS,
                tool_choice="auto",
                temperature=DEFAULT_TEMPERATURE,
                max_tokens=DEFAULT_MAX_TOKENS,
            )
            msg = resp.choices[0].message
            if not msg.tool_calls:
                return (msg.content or "（无回复）"), used

            conv.append({
                "role": "assistant",
                "content": msg.content or "",
                "tool_calls": [tc.model_dump() for tc in msg.tool_calls],
            })
            for tc in msg.tool_calls:
                name = tc.function.name
                try:
                    args = json.loads(tc.function.arguments or "{}")
                except json.JSONDecodeError:
                    args = {}
                try:
                    result = TOOL_MAP[name](token=token, **args)
                except Exception as e:  # noqa: BLE001
                    result = {"error": str(e)}
                used.append(name)
                conv.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "content": json.dumps(result, ensure_ascii=False),
                })
        return "抱歉喵，我调用工具的次数有点多了，换个问法试试？", used

    def _mock_chat(self, question: str, token: str):
        """本地演示模式：没配 API Key 时按意图直接调工具，用真实数据拼回答"""
        q = question.lower()
        if any(w in q for w in ["你好", "hello", "hi", "在吗", "你是谁", "介绍"]):
            return ("我是 bilibili AI 智能助手喵～ 可以给你推荐视频、分析弹幕情感、"
                    "查看观看记录和账号数据。当前是本地演示模式，"
                    "配置 DEEPSEEK_API_KEY（ai_service/.env）后就能自由聊天啦喵～"), []
        if "推荐" in q or "看什么" in q or "视频" in q:
            data = get_recommend_videos(token, 5)
            if isinstance(data, list) and data:
                lines = "\n".join(
                    f"{i+1}.《{v['title']}》 by {v['author']}（{v['viewCount']}播放）"
                    for i, v in enumerate(data)
                )
                return (f"主人，这是当前最热门的视频喵～\n{lines}\n"
                        "（本地演示模式，未配置 DeepSeek Key；配置后我可以结合你的历史记录做个性化推荐）"), ["get_recommend_videos"]
            return "暂时没拿到视频数据喵…", ["get_recommend_videos"]
        if "弹幕" in q or "情感" in q:
            vid = ""
            m = re.search(r"[A-Za-z0-9][A-Za-z0-9-]{11,}", q)
            if m:
                vid = m.group(0)
            if not vid:
                rec = get_recommend_videos(token, 1)
                if isinstance(rec, list) and rec:
                    vid = rec[0]["id"]
            data = get_danmaku_sentiment(token, vid)
            if isinstance(data, dict) and "error" not in data:
                pos_txt = "、".join(data["positive_samples"][:3]) or "（暂无）"
                neg_txt = "、".join(data["negative_samples"][:3]) or "（暂无）"
                return (f"弹幕情感分析结果喵～ 共{data['total']}条：正面 {data['positive']}（{int(data['positive_ratio']*100)}%）、"
                        f"负面 {data['negative']}（{int(data['negative_ratio']*100)}%）。"
                        f"正面代表弹幕：{pos_txt}；负面代表弹幕：{neg_txt}。"
                        "（本地演示模式，配置 DeepSeek Key 后可以给你更完整的解读）"), ["get_danmaku_sentiment"]
            return "这个视频还没有弹幕可以分析喵…", ["get_danmaku_sentiment"]
        if "历史" in q or "看过" in q or "记录" in q:
            data = get_user_history(token, 10)
            if isinstance(data, list) and data:
                lines = "\n".join(f"· {v['title']}" for v in data[:5])
                return (f"主人最近看过这些喵～\n{lines}\n"
                        "看多了的话建议休息一下眼睛喵！"), ["get_user_history"]
            return "还没有观看记录喵，先去看看视频吧～", ["get_user_history"]
        if "统计" in q or "数据" in q or "我" in q and ("关注" in q or "粉丝" in q):
            data = get_user_stats(token)
            if isinstance(data, dict) and "error" not in data:
                return (f"主人「{data['nickname']}」的数据喵～ 关注 {data['followingCount']} 人，"
                        f"粉丝 {data['followerCount']} 人，看过 {data['historyCount']} 个视频。"), ["get_user_stats"]
            return data.get("error", "获取统计失败喵…"), ["get_user_stats"]
        return ("我没太听懂主人想做什么喵～ 可以试试问我："
                "「推荐点视频看」「分析 demo-video-001 的弹幕情感」「我最近看过什么」"
                "「我的账号数据」。想要自由对话的话，在 ai_service/.env 里配置 "
                "DEEPSEEK_API_KEY 并重启服务，我就能认真回答你的任何问题啦喵～"), []

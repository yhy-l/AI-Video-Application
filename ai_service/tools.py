"""业务工具（ToolCalling）—— 实时读取 bilibili 后端数据"""

import json
import httpx

from config import BILIBILI_API


def _get(path: str, token: str = "", params: dict | None = None):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    try:
        resp = httpx.get(BILIBILI_API + path, headers=headers, params=params, timeout=8)
        data = resp.json()
        if data.get("code") == 0:
            return data.get("data")
        return {"error": data.get("message", "请求失败")}
    except Exception as e:  # noqa: BLE001
        return {"error": f"连接 bilibili 服务失败: {e}"}


def _login_required(token: str):
    return {"error": "需要登录才能查看个人数据，请先在客户端登录"}


# ── 工具定义（给大模型的 function calling 用） ─────
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_recommend_videos",
            "description": "获取当前热门/推荐视频列表，用于个性化视频推荐",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "description": "返回数量，默认8", "default": 8}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_video_info",
            "description": "获取某个视频的详细信息（标题、作者、播放量、点赞、评论数等）",
            "parameters": {
                "type": "object",
                "properties": {
                    "video_id": {"type": "string", "description": "视频ID"}
                },
                "required": ["video_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_danmaku_sentiment",
            "description": "对某个视频的弹幕做情感分析，返回正面/负面占比与代表弹幕",
            "parameters": {
                "type": "object",
                "properties": {
                    "video_id": {"type": "string", "description": "视频ID"}
                },
                "required": ["video_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_user_history",
            "description": "获取当前登录用户的观看历史（最近看过的视频）",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "description": "返回数量，默认10", "default": 10}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_user_stats",
            "description": "获取当前登录用户的账号统计（昵称、关注数、粉丝数、历史记录数等）",
            "parameters": {"type": "object", "properties": {}}
        }
    },
]


def get_recommend_videos(token: str = "", limit: int = 8):
    data = _get("/api/videos", token, {"page": 1, "size": limit, "sort": "hot"})
    if not isinstance(data, list):
        return data
    return [
        {
            "id": v.get("id"),
            "title": v.get("title"),
            "author": v.get("author"),
            "viewCount": v.get("viewCount"),
            "commentCount": v.get("commentCount"),
        }
        for v in data
    ]


def get_video_info(token: str = "", video_id: str = ""):
    if not video_id:
        return {"error": "缺少 video_id"}
    data = _get(f"/api/videos/{video_id}", token)
    if not isinstance(data, dict):
        return data
    return {
        "id": data.get("id"),
        "title": data.get("title"),
        "author": data.get("author"),
        "viewCount": data.get("viewCount"),
        "likeCount": data.get("likeCount"),
        "coinCount": data.get("coinCount"),
        "commentCount": data.get("commentCount"),
        "tags": data.get("tags"),
        "uploadDate": data.get("uploadDate"),
    }


POSITIVE_WORDS = ["好", "赞", "好看", "哈哈", "牛", "神作", "太棒", "喜欢", "精彩",
                  "热血", "治愈", "可爱", "好玩", "厉害", "感动", "顶", "妙"]
NEGATIVE_WORDS = ["差", "烂", "无聊", "难看", "坑", "垃圾", "失望", "恶心", "拉胯",
                  "难受", "烂片", "没意思", "骗", "浪费"]


def get_danmaku_sentiment(token: str = "", video_id: str = ""):
    if not video_id:
        return {"error": "缺少 video_id"}
    data = _get(f"/api/videos/{video_id}/danmaku", token)
    if not isinstance(data, list) or not data:
        return {"error": "该视频还没有弹幕"}

    positive, negative, neutral = 0, 0, 0
    pos_samples, neg_samples = [], []
    for d in data:
        text = (d.get("content") or "").strip()
        if not text:
            continue
        if any(w in text for w in POSITIVE_WORDS):
            positive += 1
            if len(pos_samples) < 5:
                pos_samples.append(text)
        elif any(w in text for w in NEGATIVE_WORDS):
            negative += 1
            if len(neg_samples) < 5:
                neg_samples.append(text)
        else:
            neutral += 1

    total = positive + negative + neutral
    if total == 0:
        return {"error": "没有可分析的弹幕文本"}
    return {
        "total": total,
        "positive": positive,
        "negative": negative,
        "neutral": neutral,
        "positive_ratio": round(positive / total, 2),
        "negative_ratio": round(negative / total, 2),
        "positive_samples": pos_samples,
        "negative_samples": neg_samples,
    }


def get_user_history(token: str = "", limit: int = 10):
    if not token:
        return _login_required(token)
    data = _get("/api/me/history", token)
    if not isinstance(data, list):
        return data
    items = []
    for v in data[:limit]:
        items.append({
            "title": v.get("title"),
            "author": v.get("author"),
            "viewCount": v.get("viewCount"),
            "watchedAt": v.get("watchedAt") or v.get("createdAt", ""),
        })
    return items


def get_user_stats(token: str = ""):
    if not token:
        return _login_required(token)
    me = _get("/api/me", token)
    if not isinstance(me, dict):
        return me
    history = _get("/api/me/history", token)
    following = _get("/api/me/following", token)
    followers = _get("/api/me/followers", token)
    return {
        "nickname": me.get("nickname"),
        "account": me.get("account"),
        "signature": me.get("signature"),
        "historyCount": len(history) if isinstance(history, list) else 0,
        "followingCount": len(following) if isinstance(following, list) else 0,
        "followerCount": len(followers) if isinstance(followers, list) else 0,
    }


TOOL_MAP = {
    "get_recommend_videos": get_recommend_videos,
    "get_video_info": get_video_info,
    "get_danmaku_sentiment": get_danmaku_sentiment,
    "get_user_history": get_user_history,
    "get_user_stats": get_user_stats,
}

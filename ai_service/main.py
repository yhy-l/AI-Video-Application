"""bilibili AI 智能助手服务（DeepSeek + ToolCalling + 实时业务数据）"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from config import SERVER_HOST, SERVER_PORT
from deepseek_client import AiAssistant

app = FastAPI(title="bilibili AI 助手", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

assistant = AiAssistant()


class ChatRequest(BaseModel):
    question: str
    session_id: str = ""
    token: str = ""          # bilibili 登录 token（可选，用于读取个人数据）


@app.post("/chat")
async def chat(req: ChatRequest):
    """多轮对话（非流式）：自动执行 ToolCalling 并返回最终回答"""
    if not req.question.strip():
        return {"session_id": req.session_id, "answer": "说点什么吧喵～", "tools_used": []}
    sid, answer, tools_used = await assistant.chat(
        req.session_id or None, req.question.strip(), req.token or "",
    )
    return {
        "session_id": sid,
        "answer": answer,
        "tools_used": tools_used,
        "model": "deepseek-chat" if assistant.online else "local-demo",
    }


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "online": assistant.online,
        "model": "deepseek-chat" if assistant.online else "local-demo",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=SERVER_HOST, port=SERVER_PORT)

"""AI 智能助手服务配置"""

import os


def _load_env_file():
    """读取同目录 .env（DEEPSEEK_API_KEY=sk-xxx），不覆盖已有环境变量"""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip())


_load_env_file()

# ── DeepSeek ──────────────────────────────────────
# 从环境变量读取，也可以直接在这里填
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
DEEPSEEK_BASE_URL = "https://api.deepseek.com"
# DeepSeek 官方对话模型；如需推理模型可改为 deepseek-reasoner
DEFAULT_MODEL = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")
DEFAULT_TEMPERATURE = 0.7
DEFAULT_MAX_TOKENS = 2048

# ── 服务 ─────────────────────────────────────────
SERVER_HOST = "127.0.0.1"
SERVER_PORT = 8010

# ── bilibili 业务数据（走 nginx 入口，实时读取） ──
BILIBILI_API = os.getenv("BILIBILI_API", "http://127.0.0.1:8090")

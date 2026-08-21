# bilibili 视频平台（课程项目）

一个前后端分离的 B 站风格视频应用：**Qt 6 客户端 + Qt C++ 服务端 + MySQL + Redis + nginx**，并内置 **DeepSeek AI 智能助手（ToolCalling）与置顶桌面宠物**。

## 架构

```text
client（Qt Quick + C++ 异步网络层）
   │ HTTP/JSON
   ▼
nginx(8090) ──/api/*──► server(QHttpServer:3000) ──► MySQL(3306)
   │                          │
   │ /media/* 直接读磁盘       └── Redis(库15, 热门排行/观看防刷)
   ▼
ai_service(Python FastAPI:8010) ── DeepSeek API（多轮对话 + ToolCalling）
   └── httpx 调 nginx /api/* 读取实时业务数据
```

## 目录结构

```text
bilibili/
├── client/                  Qt Quick 客户端
│   ├── main.cpp             入口：注入控制器、恢复登录态、创建桌面宠物
│   ├── src/
│   │   ├── api_client.*     统一 HTTP 客户端（token 持久化、媒体 URL 编码）
│   │   ├── video_controller.*  视频列表/搜索/评论/弹幕/上传/播放量上报
│   │   ├── user_controller.*   登录/注册/资料/头像/历史/关注/点赞/投币
│   │   ├── chat_client.*    站内聊天（HTTP 轮询）
│   │   ├── download_manager.*  异步视频下载（进度/目录可配置）
│   │   ├── ai_chat_client.* 与 AI 服务通信（自动带登录 token）
│   │   └── settings_manager.* 设置持久化（QSettings INI）
│   ├── qml/                 页面：首页/播放器/评论/上传/个人中心/下载管理/AI 宠物
│   └── icons/               SVG 图标（点赞/投币/下载等）
├── server/                  Qt C++ 服务端（QHttpServer）
│   └── src/
│       ├── database.*       MySQL 连接 + 自动建表（12 张表）
│       ├── auth.*           密码加盐哈希 + token（落库）
│       ├── repository.*     全部 SQL（prepared statement 防注入）
│       ├── redis_client.*   极简 RESP 客户端（热门 zset、观看防刷）
│       └── server.*         路由 + 全部业务接口
├── ai_service/              Python AI 服务（DeepSeek + ToolCalling）
│   ├── main.py              FastAPI：POST /chat、GET /health
│   ├── deepseek_client.py   多轮会话 + 工具调用循环（未配 Key 自动降级本地演示）
│   ├── tools.py             5 个业务工具（推荐/视频详情/弹幕情感/观看历史/账号统计）
│   ├── config.py            模型、端口、bilibili 入口配置
│   └── start_ai.ps1         一键启动（复用 AI_Chat 的 venv）
├── start_all.ps1 / stop_all.ps1   一键启停（MySQL + 服务端 + nginx + AI）
└── config.ini.example       服务端配置模板（数据库账号密码不入库）
```

## 功能清单

- 账号：注册 / 登录 / 退出 / 自动登录恢复 / 改资料 / 换头像
- 视频：首页热门流（Redis 热度 + 播放量）、加载更多、刷新、搜索、播放量上报（30 分钟防刷）
- 播放：播放/暂停、倍速、音量、全屏、弹幕开关与发送（按时间轴滚动）
- 互动：点赞 / 投币 / 评论（发表/回复/点赞/踩）/ 关注与粉丝 / 观看历史
- 上传：分块上传（16MB/块，最大 2GB）、断点续传、标签、封面
- 下载：异步下载不卡界面、设置页可改下载目录、下载管理页看进度、打开文件夹
- 聊天：站内消息（HTTP 轮询）
- AI 助手：置顶桌面宠物，点击展开聊天；DeepSeek 多轮对话 + ToolCalling
  （视频推荐 / 视频详情 / 弹幕情感分析 / 观看历史 / 账号统计）
- 系统：nginx 反向代理 + 静态文件、夜间模式、下载目录持久化

## 技术要点

- 前后端分离：客户端只走 HTTP，不内嵌服务器、不直连数据库；
- 全异步：所有网络请求走 QNetworkAccessManager 回调，UI 不阻塞；
- 安全：密码加盐哈希、token 认证（服务重启不失效）、SQL 参数化、上传防目录穿越；
- 大文件上传：16MB 分块边收边写盘，内存恒定，支持断点续传；
- 热门榜：互动时 Redis ZINCRBY 加权（播放1/点赞3/投币5），Redis 挂了回退 MySQL；
- AI ToolCalling：模型按需调用业务工具，工具经 httpx 实时读 bilibili 接口，
  无 DeepSeek Key 时自动进入本地演示模式（意图匹配 + 真实数据）；
- 桌面宠物：无边框 + 始终置顶 + 系统原生拖动（startSystemMove），点击展开聊天。

## 端口规划（与其它项目隔离）

| 端口 | 用途 | 归属 |
|---|---|---|
| 3306 | MySQL | 本项目 |
| 3000 | bilibili_server | 本项目 |
| 8090 | nginx（入口） | 本项目 |
| 8010 | AI 助手服务（ai_service） | 本项目 |
| 8000 / 9880 | AI_Chat / GPT-SoVITS（可选，未占用时） | 其它 |
| 80/8080-8085/4369/5672/6379/25672 | 其它项目（WSL） | 请勿占用 |

## 一键启动

```powershell
cd E:\program_modified\bilibili
.\start_all.ps1   # 启动 MySQL + 服务端(3000) + nginx(8090) + AI 服务(8010)，并自检
.\stop_all.ps1    # 停止服务端 / nginx / AI 服务（保留 MySQL）
```

AI 服务也可单独启停：`.\ai_service\start_ai.ps1`。

### 配置

- 数据库：复制 `config.ini.example` 为 `server/config.ini`，填 MySQL 账号密码；
- AI（可选，默认本地演示模式）：在 `ai_service/.env` 写入
  `DEEPSEEK_API_KEY=sk-xxxx`，重启 AI 服务后即接入真实 DeepSeek。
  这两个文件已在 .gitignore 中，不会提交。

## 运行环境

- Qt 6.11（MinGW）+ CMake：用 Qt Creator 打开 `client/CMakeLists.txt` 构建运行；
- 服务端：`server/build/bilibili_server.exe`（或 `run_server.ps1`）；
- Python 3.x（复用 `D:\PYcharm\AI_Chat\.venv`，依赖见 `ai_service/requirements.txt`）；
- 演示账号：demo / demo123456（可先 POST /api/dev/seed 生成演示数据）。

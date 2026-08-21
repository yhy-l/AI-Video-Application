# 一键启动 bilibili 全套环境：MySQL + 服务端 + nginx
$ErrorActionPreference = "Continue"

Write-Host "== bilibili 环境一键启动 =="

# 1) MySQL
$svc = Get-Service MySQL80 -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne "Running") {
    Write-Host "启动 MySQL80 ..."
    try { Start-Service MySQL80; Start-Sleep 3 } catch { Write-Host "启动 MySQL 失败: $_" }
} elseif ($svc) {
    Write-Host "MySQL80 已运行"
} else {
    Write-Host "未找到 MySQL80 服务，请先安装 MySQL"
}

# 2) 服务端
if (-not (Get-Process bilibili_server -ErrorAction SilentlyContinue)) {
    Write-Host "启动 bilibili_server (3000) ..."
    $server = Join-Path $PSScriptRoot "server\build\bilibili_server.exe"
    if (Test-Path $server) {
        $env:PATH = "E:\QT\6.11.1\mingw_64\bin;$env:PATH"
        Start-Process -FilePath $server -WorkingDirectory (Split-Path $server) -WindowStyle Hidden
        Start-Sleep 3
    } else {
        Write-Host "未找到 $server ，请先构建服务端"
    }
} else {
    Write-Host "bilibili_server 已运行"
}

# 3) nginx
if (-not (Get-Process nginx -ErrorAction SilentlyContinue)) {
    Write-Host "启动 nginx (8090) ..."
    if (Test-Path "E:\nginx\nginx.exe") {
        Start-Process -FilePath "E:\nginx\nginx.exe" -WorkingDirectory "E:\nginx" -WindowStyle Hidden
        Start-Sleep 2
    } else {
        Write-Host "未找到 E:\nginx\nginx.exe"
    }
} else {
    Write-Host "nginx 已运行"
}

# 3.5) AI 智能助手服务（DeepSeek + ToolCalling，8010）
if (-not (Get-NetTCPConnection -LocalPort 8010 -State Listen -ErrorAction SilentlyContinue)) {
    Write-Host "启动 AI 助手服务 (8010) ..."
    $aiPython = "D:\PYcharm\AI_Chat\.venv\Scripts\python.exe"
    if (Test-Path $aiPython) {
        Start-Process -FilePath $aiPython -ArgumentList "E:\program_modified\bilibili\ai_service\main.py" -WorkingDirectory "E:\program_modified\bilibili\ai_service" -WindowStyle Hidden
        Start-Sleep 2
    } else {
        Write-Host "未找到 AI 服务 Python 环境（D:\PYcharm\AI_Chat\.venv），跳过"
    }
} else {
    Write-Host "AI 助手服务已运行"
}

# 4) 验证
Start-Sleep 2
try {
    $code = curl.exe -s --max-time 5 -o NUL -w "%{http_code}" "http://127.0.0.1:8090/api/videos"
} catch {
    $code = "ERR"
}
Write-Host ""
if ($code -eq "200") {
    Write-Host "环境就绪：http://127.0.0.1:8090 (nginx -> server:3000 -> MySQL)"
} else {
    Write-Host "接口未就绪 (HTTP $code)，请检查上方日志"
}

Read-Host "按回车键退出..."

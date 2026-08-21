# 一键启动 bilibili AI 助手服务（复用 AI_Chat 的 Python 环境，无需额外安装）
$ErrorActionPreference = "Continue"

$python = "D:\PYcharm\AI_Chat\.venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    Write-Host "未找到 $python ，请先创建 AI_Chat 的 venv"
    Read-Host "按回车退出"
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Get-NetTCPConnection -LocalPort 8010 -State Listen -ErrorAction SilentlyContinue) {
    Write-Host "AI 助手服务已在 8010 运行"
} else {
    Write-Host "启动 AI 助手服务 (8010) ..."
    Start-Process -FilePath $python -ArgumentList (Join-Path $scriptDir "main.py") -WorkingDirectory $scriptDir -WindowStyle Hidden
    Start-Sleep 3
}

try {
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:8010/health" -TimeoutSec 5
    Write-Host ("AI 服务就绪，模式: " + $r.model)
} catch {
    Write-Host "AI 服务未就绪: $_"
}

Read-Host "按回车退出"

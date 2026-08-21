# 停止 bilibili 服务端与 nginx（保留 MySQL）
Get-Process bilibili_server -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process nginx -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
# 停止 AI 助手服务（只杀 ai_service 的 python，不动其它 Python 项目）
Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*ai_service*main.py*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host "已停止 bilibili_server / nginx / AI 助手（MySQL 保留运行）"
Read-Host "按回车键退出..."

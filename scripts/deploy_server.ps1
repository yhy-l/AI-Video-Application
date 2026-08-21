# 打包服务端：exe + MySQL 运行库 + 配置模板到 dist/server
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$src = Join-Path $root "server\build"
$dist = Join-Path $root "dist\server"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item (Join-Path $src "bilibili_server.exe") $dist -Force
foreach ($dll in @("libmysql.dll","libssl-3-x64.dll","libcrypto-3-x64.dll")) {
    $p = Join-Path $src $dll
    if (Test-Path $p) { Copy-Item $p $dist -Force }
}
if (-not (Test-Path (Join-Path $dist "config.ini"))) {
    Copy-Item (Join-Path $root "config.ini.example") (Join-Path $dist "config.ini") -Force
}
Write-Host "服务端已打包到 $dist"
Write-Host "运行前请确认 MySQL 已启动，并按需修改 config.ini"
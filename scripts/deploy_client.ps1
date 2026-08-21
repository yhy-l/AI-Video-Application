# 打包客户端：windeployqt 收集 Qt 运行库到 dist/client
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)   # bilibili/
$exe = Join-Path $root "client\build\appBilibili.exe"
if (-not (Test-Path $exe)) { Write-Host "未找到 $exe，请先构建客户端"; exit 1 }
$dist = Join-Path $root "dist\client"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item $exe $dist -Force
$windeployqt = "E:\QT\6.11.1\mingw_64\bin\windeployqt.exe"
& $windeployqt --qmldir (Join-Path $root "client") $dist\appBilibili.exe
Write-Host "客户端已打包到 $dist"
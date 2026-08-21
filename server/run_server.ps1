# 便捷启动脚本：补全运行库后启动服务端
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $root "bilibili_server.exe"

if (-not (Test-Path $exe)) {
    Write-Host "未找到 bilibili_server.exe，请先构建："
    Write-Host "  cd $root"
    Write-Host "  cmake -B build -G `"MinGW Makefiles`" -DCMAKE_PREFIX_PATH=E:/QT/6.11.1/mingw_64 -DMYSQL_BIN_DIR=`"E:/MySQL/MySQL Server 8.0/bin`""
    Write-Host "  cmake --build build -j 4"
    exit 1
}

# MySQL 运行库（构建时一般已拷贝，这里兜底）
$mysqlBin = "E:\MySQL\MySQL Server 8.0\bin"
foreach ($dll in @("libmysql.dll", "libssl-3-x64.dll", "libcrypto-3-x64.dll")) {
    $dst = Join-Path $root $dll
    if (-not (Test-Path $dst) -and (Test-Path (Join-Path $mysqlBin $dll))) {
        Copy-Item (Join-Path $mysqlBin $dll) $dst
    }
}

$env:PATH = "E:\QT\6.11.1\mingw_64\bin;$env:PATH"
Push-Location $root
& $exe @args
Pop-Location
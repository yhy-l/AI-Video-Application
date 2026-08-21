# bilibili API smoke test (requires server on 8090)
$ErrorActionPreference = "Continue"
$base = "http://127.0.0.1:8090"
$pass = 0; $fail = 0
function Check($name, $cond) {
    if ($cond) { $script:pass++; Write-Host "  [PASS] $name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $name" -ForegroundColor Red }
}
function ReqJson($method, $path, $body, $token) {
    $headers = @{}
    if ($token) { $headers["Authorization"] = "Bearer $token" }
    try {
        $params = @{ Uri = $base + $path; Method = $method; Headers = $headers }
        if ($body -ne $null) {
            $params.ContentType = "application/json"
            $params.Body = ($body | ConvertTo-Json -Compress)
        }
        return Invoke-RestMethod @params
    } catch {
        return @{ code = 1; message = $_.Exception.Message }
    }
}

Write-Host "== bilibili API smoke test =="
$acc = "smoke_" + (Get-Random -Minimum 100000 -Maximum 999999)

$r = ReqJson "Post" "/api/register" @{ account = $acc; password = "smoke123456"; nickname = "Smoke" } $null
Check "register" ($r.code -eq 0)
$r = ReqJson "Post" "/api/login" @{ account = $acc; password = "smoke123456" } $null
$tok = $r.data.token
Check "login token" ($r.code -eq 0 -and $tok.Length -gt 10)

$r = ReqJson "Get" "/api/me" $null $tok
Check "GET /api/me" ($r.code -eq 0 -and $r.data.account -eq $acc)
$r = ReqJson "Get" "/api/videos?page=1&size=10" $null $null
Check "video list" ($r.code -eq 0 -and $r.data.Count -ge 1)
$r = ReqJson "Get" "/api/videos/search?keyword=test" $null $null
Check "search" ($r.code -eq 0)

$r = ReqJson "Post" "/api/videos/demo-video-001/view" @{} $null
Check "view +1" ($r.code -eq 0)
$r = ReqJson "Post" "/api/videos/demo-video-001/comments" @{ content = "smoke comment" } $tok
Check "add comment" ($r.code -eq 0)
$r = ReqJson "Post" "/api/videos/demo-video-001/like" @{} $tok
Check "like" ($r.code -eq 0)
$r = ReqJson "Post" "/api/videos/demo-video-001/favorite" @{} $tok
Check "favorite" ($r.code -eq 0)
$r = ReqJson "Post" "/api/me/history/demo-video-001" @{} $tok
Check "history" ($r.code -eq 0)
$r = ReqJson "Post" "/api/videos/demo-video-001/danmaku" @{ content = "smoke danmaku"; time = 1; color = "#FFFFFF" } $tok
Check "send danmaku" ($r.code -eq 0)
$r = ReqJson "Get" "/api/videos/demo-video-001/danmaku" $null $null
Check "get danmaku" ($r.code -eq 0 -and $r.data.Count -ge 1)
$r = ReqJson "Post" "/api/users/demo-user-001/follow" @{} $tok
Check "follow" ($r.code -eq 0)
$dtok = (ReqJson "Post" "/api/login" @{ account = "demo"; password = "demo123456" } $null).data.token
$r = ReqJson "Get" "/api/me/followers" $null $dtok
Check "followers" ($r.code -eq 0 -and $r.data.Count -ge 1)

$r = ReqJson "Post" "/api/videos/meta" @{ title = "smoke video"; description = "t"; videoUrl = "http://example.com/s.mp4"; tags = "smoke" } $tok
Check "meta upload tags" ($r.code -eq 0 -and $r.data.tags -eq "smoke")

$r = ReqJson "Post" "/api/logout" @{} $tok
Check "logout" ($r.code -eq 0)

Write-Host ""
Write-Host "Result: PASS $pass / FAIL $fail"
if ($fail -gt 0) { exit 1 } else { exit 0 }
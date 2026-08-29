$extPath = "$env:LOCALAPPDATA\Programs\Antigravity IDE\resources\app\extensions\antigravity\dist\extension.js"

if (-not (Test-Path $extPath)) {
    Write-Host "[!] extension.js not found at $extPath" -ForegroundColor Red
    exit 1
}

$backup = "$extPath.backup"
if (-not (Test-Path $backup)) {
    Copy-Item $extPath $backup
    Write-Host "[*] Backup created at $backup" -ForegroundColor Cyan
}

$code = [System.IO.File]::ReadAllText($extPath)

if ($code.Contains("__agyAutoPreload")) {
    Write-Host "[+] Already patched! All conversation histories are active." -ForegroundColor Green
    exit 0
}

$helper = @"

function __agyAutoPreload(port, csrf) {
  try {
    const _fs = require("fs");
    const _path = require("path");
    const _os = require("os");
    const _http = require("http");
    const _dirs = [
      _path.join(_os.homedir(), ".gemini", "antigravity-ide", "conversations"),
      _path.join(_os.homedir(), ".gemini", "antigravity", "conversations")
    ];
    if (!port || !csrf) return;
    const _seen = new Set();
    for (const _d of _dirs) {
      if (_fs.existsSync(_d)) {
        for (const _f of _fs.readdirSync(_d)) {
          if ((_f.endsWith(".db") && !_f.endsWith("-wal") && !_f.endsWith("-shm")) || (_f.endsWith(".pb") && _f.length === 39)) {
            const _cid = _f.slice(0, -3);
            if (!_seen.has(_cid)) {
              _seen.add(_cid);
              const _req = _http.request({
                hostname: "127.0.0.1",
                port: port,
                path: "/exa.language_server_pb.LanguageServerService/GetCascadeTrajectorySteps",
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  "x-codeium-csrf-token": csrf,
                  "Connect-Protocol-Version": "1"
                },
                timeout: 2000
              }, function() {});
              _req.on("error", function() {});
              _req.write(JSON.stringify({ cascadeId: _cid }));
              _req.end();
            }
          }
        }
      }
    }
  } catch (_e) {}
}
"@

$target = "this.isFirstHeartbeatComplete||(this.isFirstHeartbeatComplete=!0,"
$replacement = "this.isFirstHeartbeatComplete||(this.isFirstHeartbeatComplete=!0,__agyAutoPreload(this.process?.httpPort,this.process?.csrfToken),"

if ($code.Contains($target)) {
    $idx = $code.IndexOf($target)
    $newCode = $helper + "`n" + $code.Substring(0, $idx) + $replacement + $code.Substring($idx + $target.Length)
    [System.IO.File]::WriteAllText($extPath, $newCode)
    Write-Host "[+] SUCCESS: Antigravity IDE permanently patched! Please restart the IDE." -ForegroundColor Green
} else {
    Write-Host "[!] Target integration point not found in extension.js." -ForegroundColor Red
}

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

# If old patch is present, restore from backup first
if ($code.Contains("__agyAutoPreload") -and (Test-Path $backup)) {
    Copy-Item $backup $extPath -Force
    $code = [System.IO.File]::ReadAllText($extPath)
}

$helper = @"

function __agyAutoPreload(proc) {
  try {
    if (!proc) return;
    const _fs = require("fs");
    const _path = require("path");
    const _os = require("os");
    const _http = require("http");
    const _https = require("https");
    const _url = require("url");
    let addr = proc.address;
    let csrf = proc.csrfToken;
    let port = proc.httpPort || proc.port;
    let isHttps = false;
    let hostname = "127.0.0.1";
    if (addr) {
      try {
        const parsed = new _url.URL(addr);
        hostname = parsed.hostname || "127.0.0.1";
        port = parsed.port || port;
        isHttps = (parsed.protocol === "https:");
      } catch (e) {}
    }
    if (!port || !csrf) return;
    const client = isHttps ? _https : _http;
    const _dirs = [
      _path.join(_os.homedir(), ".gemini", "antigravity-ide", "conversations"),
      _path.join(_os.homedir(), ".gemini", "antigravity", "conversations")
    ];
    const _cids = [];
    const _seen = new Set();
    for (const _d of _dirs) {
      if (_fs.existsSync(_d)) {
        for (const _f of _fs.readdirSync(_d)) {
          if ((_f.endsWith(".db") && !_f.endsWith("-wal") && !_f.endsWith("-shm")) || (_f.endsWith(".pb") && _f.length === 39)) {
            const _cid = _f.slice(0, -3);
            if (!_seen.has(_cid)) {
              _seen.add(_cid);
              _cids.push(_cid);
            }
          }
        }
      }
    }
    let _idx = 0;
    function _loadNext() {
      if (_idx >= _cids.length) return;
      const _cid = _cids[_idx++];
      try {
        const _req = client.request({
          hostname: hostname,
          port: port,
          path: "/exa.language_server_pb.LanguageServerService/LoadTrajectory",
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-codeium-csrf-token": csrf,
            "Connect-Protocol-Version": "1"
          },
          rejectUnauthorized: false,
          timeout: 5000
        }, function(res) {
          res.on("data", function() {});
          res.on("end", function() { setTimeout(_loadNext, 15); });
        });
        _req.on("error", function() { setTimeout(_loadNext, 15); });
        _req.write(JSON.stringify({ cascadeId: _cid }));
        _req.end();
      } catch (e) {
        setTimeout(_loadNext, 15);
      }
    }
    _loadNext();
  } catch (_e) {}
}
"@

$target = "this.isFirstHeartbeatComplete||(this.isFirstHeartbeatComplete=!0,"
$replacement = "this.isFirstHeartbeatComplete||(this.isFirstHeartbeatComplete=!0,__agyAutoPreload(this.process),"

if ($code.Contains($target)) {
    $idx = $code.IndexOf($target)
    $newCode = $helper + "`n" + $code.Substring(0, $idx) + $replacement + $code.Substring($idx + $target.Length)
    [System.IO.File]::WriteAllText($extPath, $newCode)
    Write-Host "[+] SUCCESS: Paced sequential preloader applied! Please restart the IDE." -ForegroundColor Green
} else {
    Write-Host "[!] Target integration point not found in extension.js." -ForegroundColor Red
}

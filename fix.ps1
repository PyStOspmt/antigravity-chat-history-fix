$extPath = "$env:LOCALAPPDATA\Programs\Antigravity IDE\resources\app\extensions\antigravity\dist\extension.js"

if (-not (Test-Path $extPath)) {
    Write-Host "[!] extension.js not found at $extPath" -ForegroundColor Red
    exit 1
}

$origBackup = "$extPath.original_backup"
$backup = "$extPath.backup"

if (Test-Path $origBackup) {
    Copy-Item $origBackup $extPath -Force
} elseif (Test-Path $backup) {
    Copy-Item $backup $extPath -Force
} else {
    Copy-Item $extPath $backup
}

$code = [System.IO.File]::ReadAllText($extPath)

$esmImports = @"
import * as __agy_fs from "node:fs";
import * as __agy_path from "node:path";
import * as __agy_os from "node:os";
import * as __agy_http from "node:http";
import * as __agy_https from "node:https";
import * as __agy_url from "node:url";

function __agyAutoPreload(proc) {
  try {
    if (!proc) return;
    let addr = proc.address;
    let csrf = proc.csrfToken;
    let port = proc.httpPort || proc.port;
    let isHttps = false;
    let hostname = "127.0.0.1";
    if (addr) {
      try {
        const parsed = new __agy_url.URL(addr);
        hostname = parsed.hostname || "127.0.0.1";
        port = parsed.port || port;
        isHttps = (parsed.protocol === "https:");
      } catch (e) {}
    }
    if (!port || !csrf) return;
    const client = isHttps ? __agy_https : __agy_http;
    const dirs = [
      __agy_path.join(__agy_os.homedir(), ".gemini", "antigravity-ide", "conversations"),
      __agy_path.join(__agy_os.homedir(), ".gemini", "antigravity", "conversations")
    ];
    const cids = [];
    const seen = new Set();
    for (const d of dirs) {
      if (__agy_fs.existsSync(d)) {
        for (const f of __agy_fs.readdirSync(d)) {
          if ((f.endsWith(".db") && !_f.endsWith("-wal") && !_f.endsWith("-shm")) || (_f.endsWith(".pb") && _f.length === 39)) {
            const cid = f.slice(0, -3);
            if (!seen.has(cid)) {
              seen.add(cid);
              cids.push(cid);
            }
          }
        }
      }
    }
    let idx = 0;
    function loadNext() {
      if (idx >= cids.length) return;
      const cid = cids[idx++];
      try {
        const req = client.request({
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
          res.on("end", function() { setTimeout(loadNext, 15); });
        });
        req.on("error", function() { setTimeout(loadNext, 15); });
        req.write(JSON.stringify({ cascadeId: cid }));
        req.end();
      } catch (e) {
        setTimeout(loadNext, 15);
      }
    }
    loadNext();
  } catch (err) {}
}
"@

$target = "this.isFirstHeartbeatComplete||(this.isFirstHeartbeatComplete=!0,"
$replacement = "this.isFirstHeartbeatComplete||(this.isFirstHeartbeatComplete=!0,__agyAutoPreload(this.process),"

if ($code.Contains($target)) {
    $idx = $code.IndexOf($target)
    $newCode = $esmImports + "`n" + $code.Substring(0, $idx) + $replacement + $code.Substring($idx + $target.Length)
    [System.IO.File]::WriteAllText($extPath, $newCode)
    Write-Host "[+] SUCCESS: Native ESM patch applied! Please restart the IDE." -ForegroundColor Green
} else {
    Write-Host "[!] Target integration point not found in extension.js." -ForegroundColor Red
}

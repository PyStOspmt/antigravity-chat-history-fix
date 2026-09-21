import os
import sys
import shutil

def fix_antigravity():
    possible_paths = [
        os.path.expandvars(r"%LOCALAPPDATA%\Programs\Antigravity IDE\resources\app\extensions\antigravity\dist\extension.js"),
        os.path.expanduser(r"~\AppData\Local\Programs\Antigravity IDE\resources\app\extensions\antigravity\dist\extension.js"),
        "/Applications/Antigravity IDE.app/Contents/Resources/app/extensions/antigravity/dist/extension.js",
        "/usr/share/antigravity-ide/resources/app/extensions/antigravity/dist/extension.js",
        "/opt/Antigravity IDE/resources/app/extensions/antigravity/dist/extension.js"
    ]
    
    ext_path = None
    for p in possible_paths:
        if os.path.exists(p):
            ext_path = p
            break
            
    if not ext_path:
        print("[!] Antigravity IDE installation not found at default paths.")
        return False
        
    print(f"[*] Found extension.js at: {ext_path}")
    
    backup_path = ext_path + ".backup"
    if not os.path.exists(backup_path):
        shutil.copy2(ext_path, backup_path)
        print(f"[*] Created backup at: {backup_path}")
        
    # If original_backup exists, restore from it to get clean base
    orig_backup = ext_path + ".original_backup"
    if os.path.exists(orig_backup):
        shutil.copy2(orig_backup, ext_path)
    elif os.path.exists(backup_path):
        shutil.copy2(backup_path, ext_path)

    with open(ext_path, "r", encoding="utf-8") as f:
        code = f.read()

    esm_imports = """import * as __agy_fs from "node:fs";
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
          if ((f.endsWith(".db") && !f.endsWith("-wal") && !f.endsWith("-shm")) || (f.endsWith(".pb") && f.length === 39)) {
            const cid = f.slice(0, -3);
            if (!_seen.has(cid)) {
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
"""

    target = "this.isFirstHeartbeatComplete||(this.isFirstHeartbeatComplete=!0,"
    replacement = "this.isFirstHeartbeatComplete||(this.isFirstHeartbeatComplete=!0,__agyAutoPreload(this.process),"

    if target in code:
        new_code = esm_imports + "\n" + code.replace(target, replacement, 1)
        with open(ext_path, "w", encoding="utf-8") as f:
            f.write(new_code)
        print("[+] SUCCESS: Native ESM patch applied! Restart Antigravity IDE to view all historical chats.")
        return True
    else:
        print("[!] Integration point not found in extension.js.")
        return False

if __name__ == "__main__":
    fix_antigravity()

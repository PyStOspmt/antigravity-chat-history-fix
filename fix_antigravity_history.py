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
        
    with open(ext_path, "r", encoding="utf-8") as f:
        code = f.read()
        
    if "__agyAutoPreload" in code and "LoadTrajectory" in code:
        print("[+] Antigravity IDE is already patched with LoadTrajectory RPC! All conversation histories are active.")
        return True
    
    # If old version with GetCascadeTrajectorySteps was present, revert from backup first
    if "__agyAutoPreload" in code and os.path.exists(backup_path):
        shutil.copy2(backup_path, ext_path)
        with open(ext_path, "r", encoding="utf-8") as f:
            code = f.read()
        
    helper_code = """
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
                path: "/exa.language_server_pb.LanguageServerService/LoadTrajectory",
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  "x-codeium-csrf-token": csrf,
                  "Connect-Protocol-Version": "1"
                },
                timeout: 5000
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
"""

    target = "this.isFirstHeartbeatComplete||(this.isFirstHeartbeatComplete=!0,"
    replacement = "this.isFirstHeartbeatComplete||(this.isFirstHeartbeatComplete=!0,__agyAutoPreload(this.process?.httpPort,this.process?.csrfToken),"

    if target in code:
        new_code = helper_code + "\n" + code.replace(target, replacement, 1)
        with open(ext_path, "w", encoding="utf-8") as f:
            f.write(new_code)
        print("[+] SUCCESS: Patch applied using fast LoadTrajectory RPC! Restart Antigravity IDE to view all historical chats.")
        return True
    else:
        print("[!] Integration point not found in extension.js.")
        return False

if __name__ == "__main__":
    fix_antigravity()

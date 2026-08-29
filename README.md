# Antigravity IDE History Restorer & Auto-Preloader 🚀

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-blue.svg)]()
[![Antigravity IDE](https://img.shields.io/badge/Antigravity%20IDE-v0.2%2B-orange.svg)]()

> Permanent fix for disappearing conversation history and lazy-loading dropouts in Google Antigravity IDE.

---

## 📌 The Problem
In **Google Antigravity IDE**, users frequently experience an issue where past conversation histories (often 50+ sessions) disappear from the **"Search all convos..."** quick switcher after restarting the IDE.

### Why does this happen?
1. **Lazy Loading**: The background Go `Language Server` does not load stored `.db` / `.pb` conversation trajectories from `~/.gemini/antigravity-ide/conversations/` on cold boot.
2. **State Sync Overwrite**: When the Language Server initializes, it publishes its empty in-memory state to the Unified State Sync (USS) topic `trajectorySummaries`, replacing the UI cache.
3. **Ghost "Running" Items**: Conversations without a generated title get trapped with `not_fully_idle = true`, causing an invisible button to render in the "Running" section.

---

## ⚡ The Solution
This tool injects a lightweight, non-blocking asynchronous preloader (`__agyAutoPreload`) directly into the Antigravity Extension Host (`extension.js`). 

Upon every IDE startup or Language Server restart, it automatically discovers all saved `.db` and `.pb` sessions and registers them in the Language Server via local ConnectRPC in under **100ms**, keeping all your chat history permanently searchable!

---

## 🚀 1-Step Automatic Installation

### Option A: Via Python (Recommended)
```bash
python fix_antigravity_history.py
```

### Option B: Via PowerShell (Windows)
```powershell
irm https://raw.githubusercontent.com/PyStOspmt/antigravity-chat-history-fix/main/fix.ps1 | iex
```

---

## 🛠️ Technical Deep Dive

```mermaid
sequenceDiagram
    autonumber
    participant IDE as Antigravity IDE
    participant EXT as Extension Host
    participant LS as Language Server
    participant USS as Unified State Sync

    Note over IDE,LS: Startup with Fix
    EXT->>LS: First Heartbeat confirmed (isFirstHeartbeatComplete)
    EXT->>EXT: __agyAutoPreload() scans ~/.gemini/antigravity-ide/conversations/
    EXT-)LS: Async GetCascadeTrajectorySteps(cascadeId)
    LS->>USS: pushUpdate(trajectorySummaries) for all 50+ sessions
    USS-->>IDE: All past sessions instantly populated & searchable!
```

---

## 📜 License
MIT License. Free to use and distribute.

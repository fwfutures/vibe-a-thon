---
name: setup-opencode-remote
description: Create and connect to a cloud workspace for remote AI coding with opencode. Spins up a powerful cloud computer, installs everything needed, and connects your local opencode to it. Use when asked to "setup opencode remote", "create a workspace", "connect to GCE", "remote workspace", "cloud dev environment", "spin up a VM", "opencode remote", or "code in the cloud".
---

# Cloud Workspace for OpenCode

Create a cloud computer and connect the OpenCode desktop app to it for remote AI coding.

Tell the user: "I'll set up a cloud workspace for you — takes about 5 minutes."

Use simple language: say "cloud computer" not "GCE instance", "your files" not "persistent home disk".

## Step 0: Detect OS and load the right reference

Run `uname -s`. If it returns `Darwin` → macOS. If it fails or returns nothing → Windows.

**After detecting the OS, read the appropriate reference file:**
- **macOS/Linux**: Read `references/mac.md` from this skill directory
- **Windows**: Read `references/win.md` from this skill directory

The reference file contains ALL the exact commands for every step. Follow it precisely.

## Critical rules (all platforms)

1. **Never pass `--metadata=` on `gcloud compute instances create` with a template** — it REPLACES all template metadata (including the startup script). Create without `--metadata`, then use `gcloud compute instances add-metadata` after.

2. **Collect email/project AFTER auth** (Step 6, not before). Detect from `gcloud config get-value account`. Don't ask during the auth flow.

3. **Tunnel test expects HTTP 401** (not 200). The server requires auth — a 401 means the tunnel works.

4. **Track state in `devserver.txt`** in the current working directory. Update after every significant step. If it already exists, read it to recover saved values.

5. **The agent runs INSIDE OpenCode desktop.** To connect the app to the cloud server, write a detached reconfig script that quits the app, writes config, and relaunches. See Step 12 in the reference file.

6. **3 failures = stop and tell user.** Don't keep retrying the same failing command.

## Step overview

| Step | What | Key action |
|------|------|------------|
| 1 | Detect OS | `uname -s` → load mac.md or win.md |
| 2 | Python 3.11+ | macOS only — use `uv` if needed |
| 3 | gcloud CLI | Check/install, find full path |
| 4 | OpenCode | Check desktop app / CLI path |
| 5 | Sign in | `gcloud auth login --project=path26-489205` |
| 6 | User info | Email from gcloud, ask project name |
| 7 | Create workspace | Disk + instance + add-metadata |
| 8 | Wait for ready | Poll daemon health on port 8080 |
| 9 | Install opencode server | Install, tmux serve with password |
| 10 | Clone starter repo | Private repo with GH_TOKEN |
| 11 | Port slug | Register for web access |
| 12 | Tunnel + desktop config | Detached reconfig script |
| 13 | Convenience scripts | start/stop/status + tunnel service |

## devserver.txt format

Write/update this after Step 7 and after every subsequent step:

```
My Cloud Workspace
==================
Last updated: 2026-03-19 10:30 AM

Name:           opencode-abc12345
Project:        my-app
Owner:          user@example.com
Password:       XDJUzZACEHue3OqbnSFNYwl5K8R7ktMT

Local Machine
-------------
Tunnel:         Running (SSH on port 4096)
OpenCode URL:   http://localhost:4096
Auto-reconnect: Installed (starts on login)

Remote Machine
--------------
Instance:       Running
OpenCode server: Running (tmux session: oc)
Starter repo:   ~/fv-rome2rio-starter (cloned)
Home directory: /home/user
GH_TOKEN:       Available (baked into template)

Web Access
----------
Port slug:      my-app
Dev server URL: https://my-app.path26.rome2rio.com (port 3000)

Cloud Details
-------------
GCP Project:    path26-489205
Zone:           europe-west1-b
External IP:    None (private instance)
```

## Troubleshooting

- **Startup log**: `gcloud compute ssh INSTANCE --command="sudo journalctl -u google-startup-scripts --no-pager | tail -30"`
- **OpenCode server**: `gcloud compute ssh INSTANCE --command="tmux capture-pane -t oc -p"`
- **SSH directly**: `gcloud compute ssh INSTANCE`
- **"External IP not found; defaulting to IAP tunneling"**: Normal — instances may not have public IPs
- **tmux "no server running"**: No session exists yet — start one
- **IAP/NumPy warnings**: Add `--quiet` to suppress

## Reference sections (in mac.md / win.md)

The OS-specific reference files also contain:
- GH_TOKEN template baking instructions
- Port proxy domain info (`path26.rome2rio.com`)
- Tunnel service removal
- Workspace deletion
- Error recovery rules

---
name: setup-opencode-remote
description: Create and connect to a cloud workspace for remote AI coding with opencode. Spins up a powerful cloud computer, installs everything needed, and connects your local opencode to it. Use when asked to "setup opencode remote", "create a workspace", "connect to GCE", "remote workspace", "cloud dev environment", "spin up a VM", "opencode remote", or "code in the cloud".
---

# Cloud Workspace for OpenCode

Create a cloud computer and connect OpenCode to it for remote AI coding.

Before starting, tell the user:

> "I'll set up a cloud workspace for you — checking tools, creating a cloud machine, and connecting OpenCode. Takes about 5 minutes."

Use simple language: say "cloud computer" not "GCE instance", "your files" not "persistent home disk".

## CRITICAL: Shell execution rules

**Your bash/shell tool runs `cmd.exe` on Windows, NOT PowerShell.** You MUST wrap all PowerShell commands like this:

```
powershell -ExecutionPolicy Bypass -Command "YOUR_COMMAND_HERE"
```

**NEVER** run bare PowerShell syntax (like `$env:OS`, `Get-Command`, `Write-Output`) without the `powershell -Command` wrapper. It will fail silently or echo the literal text.

On macOS/Linux, run bash commands directly.

## CRITICAL: Remote commands via gcloud SSH

When running commands on the remote Linux machine via `gcloud compute ssh --command=`, follow these rules:

1. **Use single quotes** around the `--command=` value: `--command='your command here'`
2. **NEVER use `&&`** — it will be parsed by PowerShell or cmd on Windows before reaching the remote. Use `;` instead.
3. **NEVER use `2>/dev/null` or `|| true`** — these bash-isms break when passed through Windows shells.
4. **Keep commands simple** — run multiple separate SSH invocations rather than one complex compound command.
5. **The tmux command string** must be a single simple command with no special characters. Pass env vars as part of the tmux command directly (no `export`).

## IMPORTANT: Track workspace state in devserver.txt

After every significant step (instance created, server started, tunnel connected, repo cloned, etc.), write/update a `devserver.txt` file in the **current working directory**. This file is the single source of truth for reconnecting later.

**Write this file after Step 6 (instance created) and update it after every subsequent step.**

The file uses a simple, readable format. Non-technical users may open this to find their password or check status.

Example:
```
My Cloud Workspace
==================
Last updated: 2026-03-18 4:30 PM

Name:           opencode-abc12345
Project:        my-app
Owner:          ben@example.com
Password:       XDJUzZACEHue3OqbnSFNYwl5K8R7ktMT

Local Machine
-------------
Tunnel:         Running (IAP on port 4096)
OpenCode URL:   http://localhost:4096
Auto-reconnect: Installed (starts on login)
gcloud path:    C:\Users\ben\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd
OpenCode path:  C:\Users\ben\AppData\Local\OpenCode\opencode-cli.exe

Remote Machine
--------------
Instance:       Running
OpenCode server: Running (tmux session: oc)
Starter repo:   ~/fv-rome2rio-starter (cloned)
Home directory: /home/ben
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

**macOS/Linux — write/update:**
```bash
cat > devserver.txt << EOF
My Cloud Workspace
==================
Last updated: $(date '+%Y-%m-%d %I:%M %p')

Name:           $INSTANCE_ID
Project:        PROJECT_NAME
Owner:          USER_EMAIL
Password:       $OPENCODE_PASSWORD

Local Machine
-------------
Tunnel:         Running (SSH on port 4096)
OpenCode URL:   http://localhost:4096
Auto-reconnect: Not installed

Remote Machine
--------------
Instance:       Running
OpenCode server: Running (tmux session: oc)
Starter repo:   Not cloned yet
Home directory: unknown
GH_TOKEN:       Available (baked into template)

Web Access
----------
Port slug:      Not registered yet
Dev server URL: Not available yet

Cloud Details
-------------
GCP Project:    $PROJECT_ID
Zone:           $ZONE
External IP:    ${EXTERNAL_IP:-None (private instance)}
EOF
```

**Windows:**
```
powershell -Command "
@'
My Cloud Workspace
==================
Last updated: $(Get-Date -Format 'yyyy-MM-dd h:mm tt')

Name:           INSTANCE_ID
Project:        PROJECT_NAME
Owner:          USER_EMAIL
Password:       OPENCODE_PASSWORD

Local Machine
-------------
Tunnel:         Running (IAP on port 4096)
OpenCode URL:   http://localhost:4096
Auto-reconnect: Not installed
gcloud path:    GCLOUD_CMD
OpenCode path:  OPENCODE_CMD

Remote Machine
--------------
Instance:       Running
OpenCode server: Running (tmux session: oc)
Starter repo:   Not cloned yet
Home directory: unknown
GH_TOKEN:       Available (baked into template)

Web Access
----------
Port slug:      Not registered yet
Dev server URL: Not available yet

Cloud Details
-------------
GCP Project:    path26-489205
Zone:           europe-west1-b
External IP:    None (private instance)
'@ | Set-Content devserver.txt
"
```

**Update the file whenever something changes:**
- After registering port slug → change "Port slug: my-app" and "Dev server URL: https://my-app.path26.rome2rio.com (port 3000)"
- After cloning starter repo → change "Starter repo: ~/fv-rome2rio-starter (cloned)"
- After finding remote home dir → update "Home directory: /home/ben"
- After installing persistent tunnel → change "Auto-reconnect: Installed (starts on login)"
- After stopping workspace → change "Instance: Stopped"
- After tunnel drops → change "Tunnel: Not running"
- After killing opencode server → change "OpenCode server: Stopped"
- Always update the "Last updated" line

**If devserver.txt already exists**, read it first to recover saved values (instance name, password, tool paths, etc.) so reconnection works without asking the user again.

---

## CRITICAL: Never pass --metadata on `gcloud compute instances create` with a template

When creating an instance from `--source-instance-template`, passing `--metadata=` **REPLACES** all template metadata (including the startup script!). Instead:
1. Create the instance **without** `--metadata`
2. Add custom metadata **after** creation using `gcloud compute instances add-metadata`

This is the same approach the web app uses (`GcpComputeControl.addMetadata()`).

## CRITICAL: SSH on Windows uses PuTTY (plink.exe)

The Google Cloud SDK on Windows ships with PuTTY (`plink.exe`), NOT OpenSSH. This means:
- `gcloud compute ssh -- -L 4096:localhost:4096 -N -f` **WILL FAIL** with "unknown option" popup
- You MUST use `gcloud compute start-iap-tunnel` for port forwarding on Windows
- Instances may not have external IPs — gcloud auto-falls back to IAP tunneling, which is fine

---

## Step 1: Detect OS

**macOS/Linux:**
```bash
uname -s
```
`Darwin` = macOS, `Linux` = Linux.

**Windows (if uname fails or returns nothing useful):**
```
powershell -Command "Write-Output Windows"
```

---

## Step 2: Ensure Python 3.11+ is available (macOS only)

gcloud requires Python 3.11+. The system Python on older macOS is too old. Check and install if needed.

**NEVER use `sudo` — it requires a terminal password prompt which will fail. Use `uv` instead — it installs Python to the user's home directory without sudo.**

```bash
python3 --version 2>/dev/null || echo "NOT_FOUND"
```

If NOT_FOUND or version is below 3.11:
```bash
# Install uv (fast Python installer — no sudo, no Homebrew needed)
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# Install Python 3.12 via uv (installs to ~/.local/)
uv python install 3.12

# Verify
python3 --version
```

If uv is already installed, just run `uv python install 3.12`.

Skip this step on Windows and Linux (they have Python 3.11+ or gcloud bundles its own).

---

## Step 3: Check and install gcloud CLI

### macOS

```bash
which gcloud && gcloud --version | head -1 || echo "NOT_FOUND"
```

If NOT_FOUND, try Homebrew first, fall back to standalone installer:
```bash
if command -v brew &>/dev/null; then
  brew install --cask google-cloud-sdk
else
  curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="$HOME"
  export PATH="$HOME/google-cloud-sdk/bin:$PATH"
fi
```

### Windows

Check these locations in order. **Save the first found path as GCLOUD_CMD** — you'll use it in ALL subsequent gcloud commands.

```
powershell -Command "
  $locations = @(
    \"$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd\",
    \"$env:ProgramFiles\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd\",
    \"${env:ProgramFiles(x86)}\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd\"
  )
  foreach ($p in $locations) {
    if (Test-Path $p) { Write-Output \"FOUND: $p\"; exit 0 }
  }
  $gcmd = Get-Command gcloud -ErrorAction SilentlyContinue
  if ($gcmd) { Write-Output \"FOUND: $($gcmd.Source)\"; exit 0 }
  Write-Output 'NOT_FOUND'
"
```

If NOT_FOUND, install:
```
powershell -Command "winget install --id Google.CloudSDK -e --accept-package-agreements --accept-source-agreements"
```
Then re-run the check above to find the installed path.

### Linux

```bash
which gcloud && gcloud --version | head -1 || echo "NOT_FOUND"
```

If NOT_FOUND:
```bash
curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="$HOME"
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
```

---

## Step 4: Check and install OpenCode CLI

The desktop app bundles the CLI — do NOT install a separate CLI if the desktop app is present (having two versions causes confusion).

### macOS

Check desktop app first, then PATH:
```bash
if [ -x "/Applications/OpenCode.app/Contents/MacOS/opencode-cli" ]; then
  echo "FOUND: /Applications/OpenCode.app/Contents/MacOS/opencode-cli"
elif command -v opencode &>/dev/null; then
  echo "FOUND: $(which opencode)"
else
  echo "NOT_FOUND"
fi
```

**Save the found path as OPENCODE_CMD.**

If NOT_FOUND (no desktop app AND no CLI):
```bash
curl -fsSL https://opencode.ai/install | bash
export PATH="$HOME/.opencode/bin:$PATH"
opencode --version
```
Or tell the user: "Download OpenCode from https://opencode.ai/download"

### Windows

Check these locations. **Save the found path as OPENCODE_CMD.**

```
powershell -Command "
  $locations = @(
    \"$env:LOCALAPPDATA\OpenCode\opencode-cli.exe\",
    \"$env:LOCALAPPDATA\Programs\opencode\opencode.exe\",
    \"$env:USERPROFILE\.opencode\bin\opencode.exe\"
  )
  foreach ($p in $locations) {
    if (Test-Path $p) { Write-Output \"FOUND: $p\"; exit 0 }
  }
  $oc = Get-Command opencode -ErrorAction SilentlyContinue
  if ($oc) { Write-Output \"FOUND: $($oc.Source)\"; exit 0 }
  $oc2 = Get-Command opencode-cli -ErrorAction SilentlyContinue
  if ($oc2) { Write-Output \"FOUND: $($oc2.Source)\"; exit 0 }
  Write-Output 'NOT_FOUND'
"
```

If NOT_FOUND, tell the user: "Please download OpenCode from https://opencode.ai/download and install it, then we'll continue." Do NOT try `irm https://opencode.ai/install.ps1 | iex` — that URL does not exist.

### Linux

```bash
which opencode && opencode --version || echo "NOT_FOUND"
```

If NOT_FOUND:
```bash
curl -fsSL https://opencode.ai/install | bash
export PATH="$HOME/.opencode/bin:$PATH"
```

---

## Step 5: Sign in to Google Cloud

### macOS/Linux

```bash
gcloud auth login --project=path26-489205
```

### Windows — NEVER run gcloud auth login synchronously (it will time out)

1. Launch in a **separate visible window**:
```
powershell -Command "Start-Process 'GCLOUD_CMD' -ArgumentList 'auth','login','--project=path26-489205'"
```

2. Tell the user: "A browser window should open for Google sign-in. Please complete the sign-in, then tell me when you're done."

3. After user confirms, verify:
```
powershell -Command "& 'GCLOUD_CMD' auth list --format='value(account)' 2>$null"
```

4. Set project:
```
powershell -Command "& 'GCLOUD_CMD' config set project path26-489205"
```

---

## Step 6: Collect user info

Now that gcloud and git are installed and authenticated, detect the user's email and ask for a project name.

Try to detect the email automatically:

**macOS/Linux:**
```bash
gcloud config get-value account 2>/dev/null || git config --global user.email 2>/dev/null || echo "NOT_FOUND"
```

**Windows:**
```
powershell -Command "& 'GCLOUD_CMD' config get-value account 2>$null"
```
If that returns nothing, try git:
```
powershell -Command "git config --global user.email 2>$null"
```

If an email is found, confirm it with the user: "I found your email as user@example.com — is that right, or would you like to use a different one?"

If NOT_FOUND, ask: "What email address should I tag this workspace with? This helps identify your cloud computers later."

Then ask: "What's a short name for your project? (e.g., 'my-app', 'website')"

**Save these as USER_EMAIL and PROJECT_NAME.** Sanitize the project name for use as a GCP label (lowercase, alphanumeric and hyphens only, max 63 chars).

---

## Step 7: Create the cloud workspace

Tell the user: "Creating your cloud workspace now. This takes about 2-3 minutes..."

### Prepare label values

Sanitize USER_EMAIL and PROJECT_NAME for GCP labels:
- Lowercase only
- Replace `@`, `.`, and any non-alphanumeric characters with `-`
- Max 63 characters
- Example: `ben@example.com` → `ben-example-com`

**Save sanitized values as OWNER_LABEL and PROJECT_LABEL.**

### macOS/Linux

```bash
INSTANCE_ID="opencode-$(openssl rand -hex 4)"
PROJECT_ID="${GCP_PROJECT_ID:-path26-489205}"
ZONE="${GCP_GCE_ZONE:-europe-west1-b}"
TEMPLATE="${GCP_GCE_INSTANCE_TEMPLATE:-freshvibe-gce-template}"
DISK_NAME="${INSTANCE_ID}-home"

# Sanitize labels
OWNER_LABEL=$(echo "USER_EMAIL" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | cut -c1-63)
PROJECT_LABEL=$(echo "PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | cut -c1-63)

# Create persistent storage
gcloud compute disks create "$DISK_NAME" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --size=10GB --type=pd-balanced \
  --labels="managed-by=freshvibe,owner=$OWNER_LABEL,project=$PROJECT_LABEL" \
  --quiet

# Create the cloud computer — do NOT pass --metadata here (it would REPLACE the template metadata, wiping the startup script)
gcloud compute instances create "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --source-instance-template="$TEMPLATE" \
  --labels="managed-by=freshvibe,owner=$OWNER_LABEL,project=$PROJECT_LABEL" \
  --disk="name=$DISK_NAME,device-name=freshvibe-home,mode=rw,boot=no,auto-delete=no" \
  --quiet

# Add custom metadata AFTER creation (this MERGES with template metadata, preserving startup-script etc.)
gcloud compute instances add-metadata "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --metadata="freshvibe-owner-email-b64=$(echo -n 'USER_EMAIL' | base64),freshvibe-project-ids-b64=$(echo -n '[\"PROJECT_NAME\"]' | base64)" \
  --quiet

echo "Created: $INSTANCE_ID"
```

### Windows

Generate instance ID:
```
powershell -Command "$id = 'opencode-' + -join((48..57)+(97..102)|Get-Random -Count 8|%%{[char]$_}); Write-Output $id"
```
**Save this output as INSTANCE_ID.**

Encode metadata values:
```
powershell -Command "[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('USER_EMAIL'))"
```
**Save as EMAIL_B64.**
```
powershell -Command "[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('[""PROJECT_NAME""]'))"
```
**Save as PROJECT_B64.**

Create disk:
```
powershell -Command "& 'GCLOUD_CMD' compute disks create 'INSTANCE_ID-home' --project=path26-489205 --zone=europe-west1-b --size=10GB --type=pd-balanced --labels=managed-by=freshvibe,owner=OWNER_LABEL,project=PROJECT_LABEL --quiet"
```

Create instance — do NOT pass `--metadata` here (it replaces the template metadata, wiping the startup script):
```
powershell -Command "& 'GCLOUD_CMD' compute instances create 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --source-instance-template=freshvibe-gce-template --labels=managed-by=freshvibe,owner=OWNER_LABEL,project=PROJECT_LABEL --disk='name=INSTANCE_ID-home,device-name=freshvibe-home,mode=rw,boot=no,auto-delete=no' --quiet"
```

Add custom metadata AFTER creation (merges with template metadata):
```
powershell -Command "& 'GCLOUD_CMD' compute instances add-metadata 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --metadata=freshvibe-owner-email-b64=EMAIL_B64,freshvibe-project-ids-b64=PROJECT_B64 --quiet"
```

### After creation: get the external IP

```bash
gcloud compute instances describe "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --format='value(networkInterfaces[0].accessConfigs[0].natIP)'
```

Windows:
```
powershell -Command "& 'GCLOUD_CMD' compute instances describe 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --format='value(networkInterfaces[0].accessConfigs[0].natIP)'"
```

**Save this as EXTERNAL_IP.** If empty, the instance has no external IP (IAP tunneling will be used instead).

Tell the user:
- If EXTERNAL_IP exists: "Your cloud computer is at EXTERNAL_IP. Once it's running, services on port 3000 will be accessible at http://EXTERNAL_IP:3000 (if you start a dev server)."
- If no external IP: "Your cloud computer doesn't have a public IP. We'll use a secure tunnel to connect."

---

## Step 8: Wait for the cloud computer to be ready

Tell the user: "Waiting for your cloud computer to start (2-4 minutes on first boot)..."

### macOS/Linux

```bash
for i in $(seq 1 60); do
  if gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --command="curl -sf http://localhost:8080/health" --quiet 2>/dev/null; then
    echo "Ready!"; break
  fi
  echo "  Starting... ($((i*5))s)"
  sleep 5
done
```

### Windows

Run this check every 10 seconds, up to 30 times:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='curl -sf http://localhost:8080/health' --quiet 2>$null"
```
If exit code 0 and output is non-empty → ready. Otherwise wait 10 seconds and retry.

---

## Step 9: Install and start OpenCode on the cloud computer

### macOS/Linux

```bash
OPENCODE_PASSWORD="$(openssl rand -hex 16)"

# Install opencode
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='curl -fsSL https://opencode.ai/install | bash'

# Add to PATH
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='grep -q opencode ~/.bashrc || echo "export PATH=\$HOME/.opencode/bin:\$PATH" >> ~/.bashrc'

# Find the remote user's home directory
REMOTE_HOME=$(gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --command='echo $HOME' --quiet 2>/dev/null | tr -d '\r\n')

# Start server in tmux — use bash -c to handle env var correctly
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command="tmux new-session -d -s oc 'bash -c \"OPENCODE_SERVER_PASSWORD=$OPENCODE_PASSWORD ${REMOTE_HOME}/.opencode/bin/opencode serve --port 4096 --hostname 0.0.0.0\"'"

echo "Password: $OPENCODE_PASSWORD"
```

### Windows

Generate password:
```
powershell -Command "$p = -join((48..57)+(65..90)+(97..122)|Get-Random -Count 32|%%{[char]$_}); Write-Output $p"
```
**Save this output as OPENCODE_PASSWORD.**

Install opencode on remote:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='curl -fsSL https://opencode.ai/install | bash'"
```

Find the remote user's home directory first:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='echo $HOME' --quiet"
```
**Save the output as REMOTE_HOME** (e.g., `/home/ben`).

Start the server using `bash -c` to handle the env var correctly:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='tmux new-session -d -s oc ""bash -c \""OPENCODE_SERVER_PASSWORD=OPENCODE_PASSWORD REMOTE_HOME/.opencode/bin/opencode serve --port 4096 --hostname 0.0.0.0\""""'"
```

**IMPORTANT**: Replace `REMOTE_HOME` with the actual path (e.g., `/home/ben`). Replace `OPENCODE_PASSWORD` with the generated password.

Verify it's running:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='tmux has-session -t oc'"
```

If this returns exit code 0 → server is running. If it shows "no server running on /tmp/tmux-..." that means the tmux command above didn't start properly. Check the remote PATH and try again.

---

## Step 10: Clone the starter repo

After OpenCode server is running, clone the starter repo on the remote machine.

The default starter repo is `https://github.com/fwfutures/fv-rome2rio-starter.git`. If it's private, embed the token in the clone URL (same approach the web app uses).

### macOS/Linux

For public repos:
```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='cd ~ ; git clone https://github.com/fwfutures/fv-rome2rio-starter.git'
```

For private repos (embed token in URL, then strip it after):
```bash
GH_TOKEN="${GH_TOKEN:-$(grep "^GH_TOKEN=" .env 2>/dev/null | cut -d= -f2)}"

gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command="cd ~ ; git clone https://x-access-token:${GH_TOKEN}@github.com/fwfutures/fv-rome2rio-starter.git"

# Strip token from git remote so it doesn't persist in .git/config
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='cd ~/fv-rome2rio-starter ; git remote set-url origin https://github.com/fwfutures/fv-rome2rio-starter.git'
```

### Windows

For public repos:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='cd ~ ; git clone https://github.com/fwfutures/fv-rome2rio-starter.git'"
```

For private repos — read token from .env file first:
```
powershell -Command "$token = (Select-String -Path '.env' -Pattern '^GH_TOKEN=(.+)$').Matches.Groups[1].Value; Write-Output $token"
```
**Save as GH_TOKEN_VALUE.** Then clone with embedded token:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='cd ~ ; git clone https://x-access-token:GH_TOKEN_VALUE@github.com/fwfutures/fv-rome2rio-starter.git'"
```
Strip token from remote:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='cd ~/fv-rome2rio-starter ; git remote set-url origin https://github.com/fwfutures/fv-rome2rio-starter.git'"
```

**IMPORTANT**: Always strip the token from the git remote after cloning. The token should NOT persist in `.git/config`.

---

## Step 11: Register port slug for web access

Register a port slug so dev servers running on the cloud computer are accessible via `https://SLUG.path26.rome2rio.com`. The default port is 3000.

Derive the slug from the PROJECT_NAME (sanitized: lowercase, alphanumeric + hyphens only).

### macOS/Linux

```bash
PORT_SLUG=$(echo "PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | cut -c1-63)

gcloud compute instances add-metadata "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --metadata="freshvibe-port-slugs=[\"$PORT_SLUG\"]"

echo "Port slug registered: https://${PORT_SLUG}.path26.rome2rio.com (port 3000)"
```

### Windows

```
powershell -Command "& 'GCLOUD_CMD' compute instances add-metadata 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --metadata='freshvibe-port-slugs=[""PORT_SLUG""]'"
```

Tell the user:
> "When you start a dev server on port 3000, it'll be accessible at https://PORT_SLUG.path26.rome2rio.com"

**Update devserver.txt** with the slug URL.

---

## Step 12: Create tunnel and connect via OpenCode desktop app

### 10a: Start the tunnel (MUST survive OpenCode restart)

The tunnel must run as a fully detached process, because we'll restart OpenCode in step 10c. If the tunnel is a child of the current shell/agent, it dies when OpenCode restarts.

**macOS/Linux — use `nohup` to detach:**
```bash
nohup gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  -- -L 4096:localhost:4096 -N -o ServerAliveInterval=60 \
  > /tmp/opencode-tunnel.log 2>&1 &
echo "Tunnel PID: $!"
```

**Windows — `Start-Process` is already detached from the calling shell:**
```
powershell -Command "Start-Process -FilePath 'GCLOUD_CMD' -ArgumentList 'compute','start-iap-tunnel','INSTANCE_ID','4096','--local-host-port=localhost:4096','--project=path26-489205','--zone=europe-west1-b' -WindowStyle Hidden"
```

Wait and test. **The server requires auth, so expect HTTP 401 (not 200).** A 401 response means the tunnel works. Only a connection error means the tunnel is down.

macOS/Linux:
```bash
sleep 10 && curl -so /dev/null -w '%{http_code}' http://localhost:4096 | grep -q '401' && echo "TUNNEL_OK" || echo "TUNNEL_FAILED"
```

Windows:
```
powershell -Command "Start-Sleep -Seconds 10; try { $null = Invoke-WebRequest -Uri 'http://localhost:4096' -UseBasicParsing -TimeoutSec 5 } catch { if ($_.Exception.Response.StatusCode -eq 401) { Write-Output 'TUNNEL_OK' } else { Write-Output 'TUNNEL_FAILED' } }"
```

If TUNNEL_FAILED, wait longer and retry. If it keeps failing, go back to Step 8 and verify the OpenCode server is running.

### 10b: Add server to OpenCode desktop app (so user just clicks to connect)

The OpenCode desktop app stores its server list in a JSON file. We can inject the remote server with password pre-filled so the user just opens the app and clicks on it.

**macOS:**
```bash
python3 -c "
import json, os, sys

store_path = os.path.expanduser('~/Library/Application Support/ai.opencode.desktop/opencode.global.dat')

# Read existing store
try:
    with open(store_path) as f:
        store = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    store = {}

# Parse server data
try:
    server_data = json.loads(store.get('server', '{}'))
except json.JSONDecodeError:
    server_data = {}

if 'list' not in server_data:
    server_data['list'] = []

# Remove any existing entry for localhost:4096
server_data['list'] = [s for s in server_data['list'] if s.get('http', {}).get('url') != 'http://localhost:4096']

# Add new entry
server_data['list'].append({
    'type': 'http',
    'http': {
        'url': 'http://localhost:4096',
        'username': 'opencode',
        'password': '$OPENCODE_PASSWORD'
    },
    'displayName': 'Cloud: $INSTANCE_ID'
})

store['server'] = json.dumps(server_data)

with open(store_path, 'w') as f:
    json.dump(store, f)

print('Server added to OpenCode desktop app')
"
```

Also set it as the default server:
```bash
python3 -c "
import json, os
store_path = os.path.expanduser('~/Library/Application Support/ai.opencode.desktop/opencode.settings.dat')
try:
    with open(store_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}
settings['defaultServerUrl'] = 'http://localhost:4096'
with open(store_path, 'w') as f:
    json.dump(settings, f)
print('Default server set to http://localhost:4096')
"
```

**Windows:**
```
powershell -Command "
  $storePath = \"$env:APPDATA\ai.opencode.desktop\opencode.global.dat\"
  if (Test-Path $storePath) {
    $store = Get-Content $storePath | ConvertFrom-Json
  } else {
    $store = @{}
  }
  $serverJson = if ($store.server) { $store.server } else { '{}' }
  $serverData = $serverJson | ConvertFrom-Json
  if (-not $serverData.list) { $serverData | Add-Member -NotePropertyName 'list' -NotePropertyValue @() }
  $serverData.list = @($serverData.list | Where-Object { $_.http.url -ne 'http://localhost:4096' })
  $newServer = @{ type='http'; http=@{ url='http://localhost:4096'; username='opencode'; password='OPENCODE_PASSWORD' }; displayName='Cloud: INSTANCE_ID' }
  $serverData.list += $newServer
  $store.server = ($serverData | ConvertTo-Json -Depth 10 -Compress)
  $store | ConvertTo-Json -Depth 10 | Set-Content $storePath
  Write-Output 'Server added to OpenCode desktop app'
"
```

Set as default:
```
powershell -Command "
  $settingsPath = \"$env:APPDATA\ai.opencode.desktop\opencode.settings.dat\"
  if (Test-Path $settingsPath) { $s = Get-Content $settingsPath | ConvertFrom-Json } else { $s = @{} }
  $s | Add-Member -NotePropertyName 'defaultServerUrl' -NotePropertyValue 'http://localhost:4096' -Force
  $s | ConvertTo-Json | Set-Content $settingsPath
  Write-Output 'Default server set'
"
```

### 10c: Open the desktop app

**macOS:**
```bash
open -a OpenCode
```

**Windows:**
```
powershell -Command "Start-Process 'OPENCODE_CMD'"
```

Or if the desktop app is at the default location:
```
powershell -Command "Start-Process '$env:LOCALAPPDATA\OpenCode\OpenCode.exe'"
```

**IMPORTANT**: The app must be restarted (or started fresh) after writing the store file. If it was already running, it will overwrite the changes on its next save. Tell the user to **quit and reopen** the app if it was already open.

### 10d: Alternative — CLI attach (if desktop app isn't available)

```bash
opencode attach http://localhost:4096 --password "$OPENCODE_PASSWORD"
```

Windows:
```
powershell -Command "& 'OPENCODE_CMD' attach http://localhost:4096 --password 'OPENCODE_PASSWORD'"
```

### After connecting, tell the user:

> "You're connected! OpenCode is now running on your cloud computer. The server 'Cloud: INSTANCE_ID' has been added to your OpenCode desktop app — just open the app and it will connect automatically."

If the instance has an external IP, also tell them:

> "Your workspace is tagged with your email (USER_EMAIL) and project (PROJECT_NAME). If you start a dev server on port 3000, it'll be accessible at http://EXTERNAL_IP:3000"

---

## Step 13: Create convenience scripts and install tunnel service

Create simple scripts so the user can start/stop their workspace with one command. Also install the tunnel as a system service so it auto-starts on login and reconnects when the instance wakes up.

Tell the user: "I'm setting up some shortcuts so you can easily start and stop your cloud workspace, and the tunnel will reconnect automatically."

### macOS/Linux — create start/stop scripts

```bash
# Create workspace control script
cat > ~/opencode-workspace.sh << 'SCRIPT'
#!/bin/bash
INSTANCE_ID="INSTANCE_ID_HERE"
PROJECT_ID="path26-489205"
ZONE="europe-west1-b"

case "$1" in
  start)
    echo "Starting your cloud workspace..."
    gcloud compute instances start "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --quiet
    echo "Waiting for it to be ready..."
    for i in $(seq 1 30); do
      gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --command='curl -sf http://localhost:8080/health' --quiet 2>/dev/null && break
      sleep 5
    done
    echo "Workspace is ready! Open OpenCode to connect."
    ;;
  stop)
    echo "Stopping your cloud workspace (files are saved)..."
    gcloud compute instances stop "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --quiet
    echo "Stopped. Start again with: opencode-workspace start"
    ;;
  status)
    STATUS=$(gcloud compute instances describe "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --format='value(status)' 2>/dev/null)
    echo "Workspace: $INSTANCE_ID — $STATUS"
    ;;
  *)
    echo "Usage: opencode-workspace [start|stop|status]"
    ;;
esac
SCRIPT
chmod +x ~/opencode-workspace.sh
ln -sf ~/opencode-workspace.sh /usr/local/bin/opencode-workspace 2>/dev/null || true

echo "Created ~/opencode-workspace.sh"
echo "Usage: opencode-workspace start|stop|status"
```

Replace `INSTANCE_ID_HERE` with the actual instance ID.

### Windows — create start/stop scripts

```
powershell -Command "
@'
param([string]$Action)
$INSTANCE_ID = 'INSTANCE_ID_HERE'
$PROJECT_ID = 'path26-489205'
$ZONE = 'europe-west1-b'
$GCLOUD = 'GCLOUD_CMD'

switch ($Action) {
  'start' {
    Write-Output 'Starting your cloud workspace...'
    & $GCLOUD compute instances start $INSTANCE_ID --project=$PROJECT_ID --zone=$ZONE --quiet
    Write-Output 'Waiting for it to be ready...'
    for ($i=1; $i -le 30; $i++) {
      try { $r = & $GCLOUD compute ssh $INSTANCE_ID --project=$PROJECT_ID --zone=$ZONE --command='curl -sf http://localhost:8080/health' --quiet 2>$null; if ($r) { break } } catch {}
      Start-Sleep 5
    }
    Write-Output 'Workspace is ready! Open OpenCode to connect.'
  }
  'stop' {
    Write-Output 'Stopping your cloud workspace (files are saved)...'
    & $GCLOUD compute instances stop $INSTANCE_ID --project=$PROJECT_ID --zone=$ZONE --quiet
    Write-Output 'Stopped. Start again with: opencode-workspace start'
  }
  'status' {
    $s = & $GCLOUD compute instances describe $INSTANCE_ID --project=$PROJECT_ID --zone=$ZONE --format='value(status)' 2>$null
    Write-Output \"Workspace: $INSTANCE_ID - $s\"
  }
  default { Write-Output 'Usage: opencode-workspace start|stop|status' }
}
'@ | Set-Content '$env:USERPROFILE\opencode-workspace.ps1'
Write-Output 'Created ~/opencode-workspace.ps1'
Write-Output 'Usage: powershell ~/opencode-workspace.ps1 start|stop|status'
"
```

Replace `INSTANCE_ID_HERE` with the actual instance ID and `GCLOUD_CMD` with the gcloud path.

### Install persistent tunnel service (auto-start on login)

### macOS — launchd agent

```bash
INSTANCE_ID="INSTANCE_ID"  # replace with actual
PROJECT_ID="${GCP_PROJECT_ID:-path26-489205}"
ZONE="${GCP_GCE_ZONE:-europe-west1-b}"
GCLOUD_PATH="$(which gcloud)"

cat > ~/Library/LaunchAgents/com.freshvibe.opencode-tunnel.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.freshvibe.opencode-tunnel</string>
    <key>ProgramArguments</key>
    <array>
        <string>${GCLOUD_PATH}</string>
        <string>compute</string>
        <string>ssh</string>
        <string>${INSTANCE_ID}</string>
        <string>--project=${PROJECT_ID}</string>
        <string>--zone=${ZONE}</string>
        <string>--</string>
        <string>-L</string>
        <string>4096:localhost:4096</string>
        <string>-N</string>
        <string>-o</string>
        <string>ServerAliveInterval=60</string>
    </array>
    <key>KeepAlive</key><true/>
    <key>RunAtLoad</key><true/>
    <key>ThrottleInterval</key><integer>10</integer>
    <key>StandardOutPath</key><string>/tmp/opencode-tunnel.log</string>
    <key>StandardErrorPath</key><string>/tmp/opencode-tunnel.log</string>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.freshvibe.opencode-tunnel.plist
echo "Tunnel service installed — starts on login, auto-restarts if it drops"
```

To stop and remove:
```bash
launchctl unload ~/Library/LaunchAgents/com.freshvibe.opencode-tunnel.plist
rm ~/Library/LaunchAgents/com.freshvibe.opencode-tunnel.plist
```

### Windows — Scheduled Task

```
powershell -Command "
  $action = New-ScheduledTaskAction -Execute 'GCLOUD_CMD' -Argument 'compute start-iap-tunnel INSTANCE_ID 4096 --local-host-port=localhost:4096 --project=path26-489205 --zone=europe-west1-b'
  $trigger = New-ScheduledTaskTrigger -AtLogOn
  $settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
  Register-ScheduledTask -TaskName 'OpenCode Cloud Tunnel' -Action $action -Trigger $trigger -Settings $settings -Description 'IAP tunnel to GCE workspace for OpenCode'
  Start-ScheduledTask -TaskName 'OpenCode Cloud Tunnel'
  Write-Output 'Tunnel service installed — starts on login, auto-restarts if it drops'
"
```

To stop and remove:
```
powershell -Command "Stop-ScheduledTask -TaskName 'OpenCode Cloud Tunnel'; Unregister-ScheduledTask -TaskName 'OpenCode Cloud Tunnel' -Confirm:$false"
```

---

## List workspaces

### macOS/Linux
```bash
gcloud compute instances list --project="${GCP_PROJECT_ID:-path26-489205}" --zones="${GCP_GCE_ZONE:-europe-west1-b}" --filter='labels.managed-by=freshvibe' --format='table(name,status,labels.owner,labels.project,networkInterfaces[0].accessConfigs[0].natIP)'
```

### Windows
```
powershell -Command "& 'GCLOUD_CMD' compute instances list --project=path26-489205 --zones=europe-west1-b --filter='labels.managed-by=freshvibe' --format='table(name,status,labels.owner,labels.project,networkInterfaces[0].accessConfigs[0].natIP)'"
```

---

## Stop a workspace

```bash
gcloud compute instances stop "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --quiet
```

Windows: `powershell -Command "& 'GCLOUD_CMD' compute instances stop 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --quiet"`

The machine auto-stops after 15 minutes of inactivity. Your files are saved.

Tell the user: "Your workspace will automatically go to sleep after 15 minutes of no activity to save costs. To wake it up, just run `opencode-workspace start` (or the PowerShell equivalent on Windows). The tunnel service will reconnect automatically."

---

## Remove tunnel service (if installed)

Only run this if the user asks to remove the persistent tunnel service.

**macOS:**
```bash
launchctl unload ~/Library/LaunchAgents/com.freshvibe.opencode-tunnel.plist 2>/dev/null
rm -f ~/Library/LaunchAgents/com.freshvibe.opencode-tunnel.plist
echo "Tunnel service removed"
```

**Windows:**
```
powershell -Command "Stop-ScheduledTask -TaskName 'OpenCode Cloud Tunnel' -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName 'OpenCode Cloud Tunnel' -Confirm:$false -ErrorAction SilentlyContinue; Write-Output 'Tunnel service removed'"
```

---

## Delete a workspace

```bash
gcloud compute instances delete "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --quiet
# To also delete saved files:
gcloud compute disks delete "${INSTANCE_ID}-home" --project="$PROJECT_ID" --zone="$ZONE" --quiet
```

---

## Troubleshooting

Check startup log:
```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --command="sudo journalctl -u google-startup-scripts --no-pager | tail -30"
```

Check OpenCode server:
```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --command="tmux capture-pane -t oc -p"
```

SSH directly:
```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE"
```

**Windows `curl` note**: PowerShell aliases `curl` to `Invoke-WebRequest`. Use `curl.exe` for real curl or use `Invoke-WebRequest -Uri URL -UseBasicParsing`.

**tmux "no server running" error**: This means no tmux session exists. It's normal when first connecting or after `tmux kill-session`. Just start a new session.

**"External IP not found; defaulting to IAP tunneling"**: This is normal — the instance may not have a public IP. IAP tunneling works fine. Do NOT try to fix this.

---

## Baking GH_TOKEN into the instance template

To let GCE instances clone private GitHub repos, add `GH_TOKEN` as an agent env var in the instance template. This only needs to be done once — all new instances created from the template will have it.

**Prerequisite**: You need `gcloud auth login` as a user with `compute.instanceTemplates.create` permission on the project.

```bash
./scripts/gcp-gce-setup.sh \
  --project-id=path26-489205 --zone=europe-west1-b \
  --instance-template=freshvibe-gce-template \
  --no-external-ip \
  --daemon-source-ranges=10.0.0.0/8 \
  --agent-env="CLAUDE_CODE_USE_VERTEX=1" \
  --agent-env="CLOUD_ML_REGION=global" \
  --agent-env="ANTHROPIC_VERTEX_PROJECT_ID=path26-489205" \
  --agent-env="GOOGLE_CLOUD_PROJECT=path26-489205" \
  --agent-env="ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6" \
  --agent-env="ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6" \
  --agent-env="ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5@20251001" \
  --agent-env="GH_TOKEN=YOUR_GITHUB_PAT_HERE" \
  --skip-managed-image-build --skip-web-bootstrap --skip-firewall --set-defaults
```

The startup script writes agent env vars to `/etc/profile.d/freshvibe-runtime.sh`, so `GH_TOKEN` is available in all login shells. Git credential helpers and the `gh` CLI will pick it up automatically.

**Important**: Changing agent env vars requires recreating the template (templates are immutable). Existing running instances keep the old vars until recycled.

If GH_TOKEN is NOT in the template, you can set it ad-hoc on a running instance:
```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='echo "export GH_TOKEN=YOUR_TOKEN" >> ~/.bashrc'
```

---

## Port proxy domain

The R2R deployment uses `PORT_PROXY_DOMAIN=path26.rome2rio.com` to map instance ports to public subdomains. When configured:

- A dev server on port 3000 on instance `opencode-abc12345` would be accessible at `https://opencode-abc12345.path26.rome2rio.com`
- The load balancer URL mask routes `<instance-name>.path26.rome2rio.com` → the instance's port 3000

**Note**: This requires the LB URL mask and serverless NEG to be configured. If the port proxy isn't set up yet, services on the instance are only accessible via IAP tunnel or direct SSH.

---

## Error recovery rules

- If a command fails 3 times with the same error, **stop and tell the user** what's wrong. Do not keep retrying.
- If `gcloud auth login` times out on Windows, use the separate-window approach from Step 5.
- If SSH tunneling fails on Windows with PuTTY errors, use IAP tunnel (Step 9).
- If `gcloud compute ssh --command=` fails with quoting errors:
  - Remove ALL `&&` — use `;` or separate SSH commands
  - Remove ALL `|| true` and `2>/dev/null`
  - Use single quotes around the `--command=` value
  - Run one simple command per SSH invocation
- Never invent gcloud component names or config properties.
- The `tmux new-session -d -s NAME CMD ARGS` syntax passes CMD and ARGS directly. No shell quoting needed for the command — just space-separated values.

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

---

## Step 1: Detect OS

Run this exact command:

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

## Step 2: Check and install gcloud CLI

### macOS

```bash
which gcloud && gcloud --version | head -1 || echo "NOT_FOUND"
```

If NOT_FOUND:
```bash
brew install --cask google-cloud-sdk || echo "Install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
```

### Windows

Check these locations in order. The first one found is your gcloud path. **Save it as GCLOUD_CMD for all later commands.**

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

After install, re-run the check above to find the installed path. **Remember the full path to gcloud.cmd** — you'll use it in all subsequent gcloud commands.

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

## Step 3: Check and install OpenCode CLI

### macOS

```bash
which opencode && opencode --version || echo "NOT_FOUND"
```

If NOT_FOUND:
```bash
curl -fsSL https://opencode.ai/install | bash
export PATH="$HOME/.opencode/bin:$PATH"
opencode --version
```

### Windows

Check these locations in order:

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

If NOT_FOUND, tell the user: "Please download OpenCode from https://opencode.ai/download and install it, then we'll continue." Do NOT try to run `irm https://opencode.ai/install.ps1 | iex` — this URL does not exist.

**Save the found path as OPENCODE_CMD for later.**

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

## Step 4: Sign in to Google Cloud

### CRITICAL: `gcloud auth login` is interactive and blocks for minutes

**macOS/Linux** — run directly (terminal stays open for the callback):
```bash
gcloud auth login --project=path26-489205
```

**Windows** — NEVER run `gcloud auth login` as a synchronous command. It will time out. Instead:

1. Launch gcloud auth in a **separate visible window**:
```
powershell -Command "Start-Process 'GCLOUD_CMD' -ArgumentList 'auth','login','--project=path26-489205'"
```
(Replace `GCLOUD_CMD` with the full path found in Step 2, e.g. `C:\Users\ben\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd`)

2. Tell the user: "A browser window should open for Google sign-in. Please complete the sign-in, then come back and tell me when you're done."

3. After the user confirms, verify auth worked:
```
powershell -Command "& 'GCLOUD_CMD' auth list --format='value(account)' 2>$null"
```

4. Set the project:
```
powershell -Command "& 'GCLOUD_CMD' config set project path26-489205"
```

### Verify auth on all platforms

```bash
gcloud auth list --format='value(account)' | head -1
gcloud config get-value project
```

On Windows, wrap in `powershell -Command "& 'GCLOUD_CMD' ..."` as above.

If no account is shown, repeat the auth flow. If project is wrong, set it with `gcloud config set project path26-489205`.

---

## Step 5: Create the cloud workspace

Tell the user: "Creating your cloud workspace now. This takes about 2-3 minutes..."

### macOS/Linux

```bash
INSTANCE_ID="freshvibe-$(openssl rand -hex 4)"
PROJECT_ID="${GCP_PROJECT_ID:-path26-489205}"
ZONE="${GCP_GCE_ZONE:-europe-west1-b}"
TEMPLATE="${GCP_GCE_INSTANCE_TEMPLATE:-freshvibe-gce-template}"
DISK_NAME="${INSTANCE_ID}-home"

gcloud compute disks create "$DISK_NAME" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --size=10GB --type=pd-balanced \
  --labels=managed-by=freshvibe --quiet

gcloud compute instances create "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --source-instance-template="$TEMPLATE" \
  --labels=managed-by=freshvibe \
  --disk="name=$DISK_NAME,device-name=freshvibe-home,mode=rw,boot=no,auto-delete=no" \
  --quiet

echo "Created: $INSTANCE_ID"
```

### Windows

Run each gcloud command separately using the full path. Replace GCLOUD_CMD with the path found in Step 2.

Generate instance ID:
```
powershell -Command "$id = 'freshvibe-' + -join((48..57)+(97..102)|Get-Random -Count 8|%%{[char]$_}); Write-Output $id"
```
**Save this output as INSTANCE_ID.**

Create disk (replace INSTANCE_ID with the actual value):
```
powershell -Command "& 'GCLOUD_CMD' compute disks create 'INSTANCE_ID-home' --project=path26-489205 --zone=europe-west1-b --size=10GB --type=pd-balanced --labels=managed-by=freshvibe --quiet"
```

Create instance:
```
powershell -Command "& 'GCLOUD_CMD' compute instances create 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --source-instance-template=freshvibe-gce-template --labels=managed-by=freshvibe --disk='name=INSTANCE_ID-home,device-name=freshvibe-home,mode=rw,boot=no,auto-delete=no' --quiet"
```

---

## Step 6: Wait for the cloud computer to be ready

Tell the user: "Waiting for your cloud computer to start (2-4 minutes)..."

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

Run this check repeatedly (every 10 seconds, up to 30 times). Each attempt is a separate command:

```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='curl -sf http://localhost:8080/health' --quiet 2>$null"
```

If exit code is 0 and output is non-empty, the machine is ready. If it fails, wait 10 seconds and try again. After 5 minutes of failures, tell the user something may be wrong and check troubleshooting.

---

## Step 7: Install and start OpenCode on the cloud computer

### macOS/Linux

```bash
OPENCODE_PASSWORD="$(openssl rand -hex 16)"

gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='curl -fsSL https://opencode.ai/install | bash; echo "export PATH=\$HOME/.opencode/bin:\$PATH" >> ~/.bashrc'

gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command="export PATH=\$HOME/.opencode/bin:\$PATH; tmux kill-session -t oc 2>/dev/null; tmux new-session -d -s oc 'OPENCODE_SERVER_PASSWORD=$OPENCODE_PASSWORD opencode serve --port 4096 --hostname 0.0.0.0'"

echo "Password: $OPENCODE_PASSWORD"
```

### Windows

Generate password:
```
powershell -Command "$p = -join((48..57)+(65..90)+(97..122)|Get-Random -Count 32|%%{[char]$_}); Write-Output $p"
```
**Save this output as OPENCODE_PASSWORD.**

Install opencode on remote (single simple command, no special quoting):
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='curl -fsSL https://opencode.ai/install | bash'"
```

Start the server. **IMPORTANT**: Keep the remote command simple — no `||`, no `2>/dev/null`, no nested quotes. Run two separate SSH commands:

Kill any existing session:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='tmux kill-session -t oc'"
```
(This may fail with "no session" — that's fine, ignore the error.)

Start the server:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='export PATH=$HOME/.opencode/bin:$PATH && tmux new-session -d -s oc OPENCODE_SERVER_PASSWORD=OPENCODE_PASSWORD opencode serve --port 4096 --hostname 0.0.0.0'"
```
(Replace OPENCODE_PASSWORD with the actual password value.)

Verify it's running:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='tmux has-session -t oc && echo RUNNING'"
```

---

## Step 8: Create tunnel and connect

### macOS/Linux

```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  -- -L 4096:localhost:4096 -N -f

opencode attach http://localhost:4096 --password "$OPENCODE_PASSWORD"
```

### Windows — use IAP tunnel (avoids PuTTY problems)

**CRITICAL**: On Windows, `gcloud compute ssh -- -L ...` uses PuTTY which does NOT support OpenSSH flags like `-L`, `-N`, `-f`. This will show "unknown option" popup errors. **Use IAP tunnel instead:**

Start IAP tunnel in background:
```
powershell -Command "Start-Process -NoNewWindow -FilePath 'GCLOUD_CMD' -ArgumentList 'compute','start-iap-tunnel','INSTANCE_ID','4096','--local-host-port=localhost:4096','--project=path26-489205','--zone=europe-west1-b'"
```

Wait for tunnel to establish:
```
powershell -Command "Start-Sleep -Seconds 5"
```

Test the tunnel is working:
```
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:4096' -UseBasicParsing -TimeoutSec 5; Write-Output 'TUNNEL_OK' } catch { Write-Output 'TUNNEL_FAILED' }"
```

If TUNNEL_FAILED, wait 5 more seconds and try again. If it keeps failing, the OpenCode server may not have started — go back to Step 7 and verify.

Connect OpenCode (replace OPENCODE_CMD with the path from Step 3):
```
powershell -Command "& 'OPENCODE_CMD' attach http://localhost:4096 --password 'OPENCODE_PASSWORD'"
```

Tell the user: "You're connected! OpenCode is now running on your cloud computer."

---

## List workspaces

### macOS/Linux
```bash
gcloud compute instances list --project="${GCP_PROJECT_ID:-path26-489205}" --zones="${GCP_GCE_ZONE:-europe-west1-b}" --filter='labels.managed-by=freshvibe' --format='table(name,status,creationTimestamp)'
```

### Windows
```
powershell -Command "& 'GCLOUD_CMD' compute instances list --project=path26-489205 --zones=europe-west1-b --filter='labels.managed-by=freshvibe' --format='table(name,status,creationTimestamp)'"
```

---

## Stop a workspace

```bash
gcloud compute instances stop "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --quiet
```

On Windows: `powershell -Command "& 'GCLOUD_CMD' compute instances stop 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --quiet"`

The machine auto-stops after 15 minutes of inactivity. Your files are saved.

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

---

## Error recovery rules

- If a command fails 3 times with the same error, **stop and tell the user** what's wrong. Do not keep retrying.
- If `gcloud auth login` times out, use the separate-window approach from Step 4.
- If SSH tunneling fails on Windows with PuTTY errors, switch to IAP tunnel.
- If quoting is causing errors in `gcloud compute ssh --command=`, simplify: use single quotes, avoid `||`, `&&`, `2>/dev/null`. Run multiple separate SSH commands instead of one complex one.
- Never invent gcloud component names or config properties. If unsure, run `gcloud components list` or `gcloud config list`.

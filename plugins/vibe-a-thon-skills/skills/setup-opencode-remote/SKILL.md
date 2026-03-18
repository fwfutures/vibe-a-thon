---
name: setup-opencode-remote
description: Create and connect to a cloud workspace for remote AI coding with opencode. Spins up a powerful cloud computer, installs everything needed, and connects your local opencode to it. Use when asked to "setup opencode remote", "create a workspace", "connect to GCE", "remote workspace", "cloud dev environment", "spin up a VM", "opencode remote", or "code in the cloud".
---

# Cloud Workspace for OpenCode

This skill creates a cloud computer (GCE instance) and connects your local OpenCode to it so you can code remotely with full cloud power. It handles everything: checking your machine, installing missing tools, creating the cloud workspace, and connecting you.

**Talk to the user in simple, friendly language.** Avoid jargon. Say "cloud computer" not "GCE instance". Say "your files" not "persistent home disk". Say "connecting" not "establishing SSH tunnel".

Before starting, tell the user:

> "I'll set up a cloud workspace for you. This involves checking your computer has the right tools, creating a cloud machine, and connecting OpenCode to it. It takes about 5 minutes. I'll walk you through anything that needs your input."

Then work through each step, reporting progress with friendly updates like "Setting up your cloud computer...", "Almost there...", etc.

---

## Step 1: Detect the operating system

Detect the OS first. All subsequent commands depend on this.

**On macOS/Linux:**
```bash
uname -s
```
Result: `Darwin` = macOS, `Linux` = Linux.

**On Windows:**
```powershell
$env:OS
```
Result: `Windows_NT` = Windows.

Remember the OS for all following steps. Use bash commands for macOS/Linux, PowerShell for Windows.

---

## Step 2: Check and install required tools

Check if each tool is available. If missing, install it automatically. Report progress to the user.

### 2a: Google Cloud CLI (`gcloud`)

**macOS — check:**
```bash
which gcloud 2>/dev/null && gcloud --version | head -1 || echo "NOT_FOUND"
```

**macOS — install if missing:**
```bash
brew install --cask google-cloud-sdk
```
If Homebrew isn't installed either, install it first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
After installing gcloud, the user needs to sign in:
```bash
gcloud auth login
gcloud config set project path26-489205
```
Tell the user: "A browser window will open for you to sign in to Google Cloud. Please sign in with your work account."

**Windows — check:**
```powershell
Get-Command gcloud -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if ($?) { gcloud --version | Select-Object -First 1 } else { Write-Output "NOT_FOUND" }
```

**Windows — install if missing:**
```powershell
winget install --id Google.CloudSDK -e --accept-package-agreements --accept-source-agreements
# Refresh PATH
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
```
After installing, sign in:
```powershell
gcloud auth login
gcloud config set project path26-489205
```

**Linux — install if missing:**
```bash
curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="$HOME"
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
gcloud auth login
gcloud config set project path26-489205
```

### 2b: OpenCode

**macOS — check:**
```bash
which opencode 2>/dev/null && opencode --version 2>/dev/null || echo "NOT_FOUND"
```
Also check if the desktop app exists:
```bash
ls /Applications/OpenCode.app 2>/dev/null && echo "DESKTOP_APP_FOUND" || true
```

**macOS — install if missing:**
```bash
curl -fsSL https://opencode.ai/install | bash
export PATH="$HOME/.opencode/bin:$PATH"
```
Or tell user: "You can also download the OpenCode desktop app from https://opencode.ai/download"

**Windows — check:**
```powershell
Get-Command opencode -ErrorAction SilentlyContinue
if ($?) { opencode --version } else { Write-Output "NOT_FOUND" }
```

**Windows — install if missing:**
```powershell
irm https://opencode.ai/install.ps1 | iex
# Refresh PATH
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
```
Or tell user: "You can also download the OpenCode desktop app from https://opencode.ai/download"

**Linux — install if missing:**
```bash
curl -fsSL https://opencode.ai/install | bash
export PATH="$HOME/.opencode/bin:$PATH"
```

### 2c: OpenSSL (for generating passwords)

**macOS:** Pre-installed. No action needed.

**Windows — check:**
```powershell
Get-Command openssl -ErrorAction SilentlyContinue
if (-not $?) { Write-Output "NOT_FOUND" }
```
If missing, use PowerShell random instead (see Step 7).

**Linux:** Pre-installed on most distros. `apt install openssl` if missing.

---

## Step 3: Verify Google Cloud authentication

Make sure the user is signed in and can access the project.

**macOS/Linux:**
```bash
gcloud auth list --format='value(account)' 2>/dev/null | head -1
gcloud config get-value project 2>/dev/null
```

**Windows:**
```powershell
gcloud auth list --format='value(account)' 2>$null | Select-Object -First 1
gcloud config get-value project 2>$null
```

If no account is shown, tell the user: "You need to sign in to Google Cloud first. A browser window will open." Then run `gcloud auth login`.

If the project isn't set to `path26-489205`, run:
```bash
gcloud config set project path26-489205
```

---

## Step 4: Create the cloud workspace

Tell the user: "Creating your cloud workspace now. This takes about 2-3 minutes..."

### Configuration defaults

These can be overridden with environment variables:

| Setting | Default | Env var |
|---------|---------|---------|
| Project | `path26-489205` | `GCP_PROJECT_ID` |
| Location | `europe-west1-b` | `GCP_GCE_ZONE` |
| Template | `freshvibe-gce-template` | `GCP_GCE_INSTANCE_TEMPLATE` |
| Storage size | `10 GB` | `GCP_GCE_HOME_DISK_SIZE_GB` |

### Create (macOS/Linux)

```bash
# Set up variables
INSTANCE_ID="freshvibe-$(openssl rand -hex 4)"
PROJECT_ID="${GCP_PROJECT_ID:-path26-489205}"
ZONE="${GCP_GCE_ZONE:-europe-west1-b}"
TEMPLATE="${GCP_GCE_INSTANCE_TEMPLATE:-freshvibe-gce-template}"
HOME_DISK_SIZE="${GCP_GCE_HOME_DISK_SIZE_GB:-10}"
DISK_NAME="${INSTANCE_ID}-home"

# Create storage (your files persist even when the machine is off)
gcloud compute disks create "$DISK_NAME" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --size="${HOME_DISK_SIZE}GB" \
  --type=pd-balanced \
  --labels="managed-by=freshvibe" \
  --quiet

# Create the cloud computer
gcloud compute instances create "$INSTANCE_ID" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --source-instance-template="$TEMPLATE" \
  --labels="managed-by=freshvibe" \
  --disk="name=$DISK_NAME,device-name=freshvibe-home,mode=rw,boot=no,auto-delete=no" \
  --quiet

echo "Cloud computer created: $INSTANCE_ID"
```

### Create (Windows)

```powershell
# Set up variables
$INSTANCE_ID = "freshvibe-" + -join ((48..57) + (97..102) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
$PROJECT_ID = if ($env:GCP_PROJECT_ID) { $env:GCP_PROJECT_ID } else { "path26-489205" }
$ZONE = if ($env:GCP_GCE_ZONE) { $env:GCP_GCE_ZONE } else { "europe-west1-b" }
$TEMPLATE = if ($env:GCP_GCE_INSTANCE_TEMPLATE) { $env:GCP_GCE_INSTANCE_TEMPLATE } else { "freshvibe-gce-template" }
$HOME_DISK_SIZE = if ($env:GCP_GCE_HOME_DISK_SIZE_GB) { $env:GCP_GCE_HOME_DISK_SIZE_GB } else { "10" }
$DISK_NAME = "$INSTANCE_ID-home"

# Create storage
gcloud compute disks create $DISK_NAME `
  --project=$PROJECT_ID `
  --zone=$ZONE `
  --size="${HOME_DISK_SIZE}GB" `
  --type=pd-balanced `
  --labels="managed-by=freshvibe" `
  --quiet

# Create the cloud computer
gcloud compute instances create $INSTANCE_ID `
  --project=$PROJECT_ID `
  --zone=$ZONE `
  --source-instance-template=$TEMPLATE `
  --labels="managed-by=freshvibe" `
  --disk="name=$DISK_NAME,device-name=freshvibe-home,mode=rw,boot=no,auto-delete=no" `
  --quiet

Write-Output "Cloud computer created: $INSTANCE_ID"
```

---

## Step 5: Wait for the cloud computer to be ready

Tell the user: "Your cloud computer is starting up. This takes about 2-4 minutes for the first boot..."

**macOS/Linux:**
```bash
echo "Waiting for cloud computer to finish setting up..."
for i in $(seq 1 60); do
  STATUS=$(gcloud compute ssh "$INSTANCE_ID" \
    --project="$PROJECT_ID" --zone="$ZONE" \
    --command="curl -sf http://localhost:8080/health" \
    --quiet 2>/dev/null || true)
  if [ -n "$STATUS" ]; then
    echo "Your cloud computer is ready!"
    break
  fi
  echo "  Still starting up... ($((i * 5)) seconds)"
  sleep 5
done
```

**Windows:**
```powershell
Write-Output "Waiting for cloud computer to finish setting up..."
for ($i = 1; $i -le 60; $i++) {
    try {
        $result = gcloud compute ssh $INSTANCE_ID `
            --project=$PROJECT_ID --zone=$ZONE `
            --command="curl -sf http://localhost:8080/health" `
            --quiet 2>$null
        if ($result) {
            Write-Output "Your cloud computer is ready!"
            break
        }
    } catch {}
    Write-Output "  Still starting up... ($($i * 5) seconds)"
    Start-Sleep -Seconds 5
}
```

---

## Step 6: Install OpenCode on the cloud computer

**All platforms (runs via SSH on the remote Linux machine):**

macOS/Linux:
```bash
gcloud compute ssh "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --command='
    if ! command -v opencode &>/dev/null; then
      echo "Installing OpenCode on the cloud computer..."
      curl -fsSL https://opencode.ai/install | bash
      echo "export PATH=\"\$HOME/.opencode/bin:\$PATH\"" >> ~/.bashrc
      export PATH="$HOME/.opencode/bin:$PATH"
    fi
    echo "OpenCode version: $(opencode --version 2>/dev/null || echo installing...)"
  '
```

Windows:
```powershell
gcloud compute ssh $INSTANCE_ID `
  --project=$PROJECT_ID --zone=$ZONE `
  --command='if ! command -v opencode &>/dev/null; then curl -fsSL https://opencode.ai/install | bash; echo "export PATH=\"\$HOME/.opencode/bin:\$PATH\"" >> ~/.bashrc; export PATH="$HOME/.opencode/bin:$PATH"; fi; echo "OpenCode version: $(opencode --version 2>/dev/null || echo installing...)"'
```

---

## Step 7: Start the OpenCode server on the cloud computer

**macOS/Linux:**
```bash
# Generate a secure password
OPENCODE_PASSWORD="$(openssl rand -hex 16)"

# Start OpenCode server in background (survives SSH disconnection)
gcloud compute ssh "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --command="
    export PATH=\"\$HOME/.opencode/bin:/usr/local/bin:\$PATH\"
    tmux kill-session -t opencode 2>/dev/null || true
    tmux new-session -d -s opencode \"OPENCODE_SERVER_PASSWORD=$OPENCODE_PASSWORD opencode serve --port 4096 --hostname 0.0.0.0\"
    echo 'OpenCode server is running'
  "

echo "Instance: $INSTANCE_ID"
echo "Password: $OPENCODE_PASSWORD"
```

**Windows:**
```powershell
# Generate a secure password
$OPENCODE_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object { [char]$_ })

# Start OpenCode server
gcloud compute ssh $INSTANCE_ID `
  --project=$PROJECT_ID --zone=$ZONE `
  --command="export PATH=`"`$HOME/.opencode/bin:/usr/local/bin:`$PATH`"; tmux kill-session -t opencode 2>/dev/null || true; tmux new-session -d -s opencode `"OPENCODE_SERVER_PASSWORD=$OPENCODE_PASSWORD opencode serve --port 4096 --hostname 0.0.0.0`"; echo 'OpenCode server is running'"

Write-Output "Instance: $INSTANCE_ID"
Write-Output "Password: $OPENCODE_PASSWORD"
```

---

## Step 8: Connect your local OpenCode to the cloud

Tell the user: "Connecting your OpenCode to the cloud workspace now..."

**macOS/Linux:**
```bash
# Create a secure tunnel to the cloud computer
gcloud compute ssh "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  -- -L 4096:localhost:4096 -N -f

# Connect OpenCode
opencode attach http://localhost:4096 --password "$OPENCODE_PASSWORD"
```

**Windows:**
```powershell
# Create a secure tunnel to the cloud computer (runs in background)
Start-Process -NoNewWindow gcloud -ArgumentList "compute", "ssh", $INSTANCE_ID, "--project=$PROJECT_ID", "--zone=$ZONE", "--", "-L", "4096:localhost:4096", "-N"

# Wait a moment for the tunnel to establish
Start-Sleep -Seconds 3

# Connect OpenCode
opencode attach http://localhost:4096 --password $OPENCODE_PASSWORD
```

Tell the user: "You're connected! OpenCode is now running on your cloud computer. Your work is saved to persistent storage, so it'll be there next time."

---

## List your cloud workspaces

**macOS/Linux:**
```bash
PROJECT_ID="${GCP_PROJECT_ID:-path26-489205}"
ZONE="${GCP_GCE_ZONE:-europe-west1-b}"

gcloud compute instances list \
  --project="$PROJECT_ID" \
  --zones="$ZONE" \
  --filter='labels.managed-by=freshvibe' \
  --format='table(name,status,creationTimestamp,networkInterfaces[0].accessConfigs[0].natIP)'
```

**Windows:**
```powershell
$PROJECT_ID = if ($env:GCP_PROJECT_ID) { $env:GCP_PROJECT_ID } else { "path26-489205" }
$ZONE = if ($env:GCP_GCE_ZONE) { $env:GCP_GCE_ZONE } else { "europe-west1-b" }

gcloud compute instances list `
  --project=$PROJECT_ID `
  --zones=$ZONE `
  --filter='labels.managed-by=freshvibe' `
  --format='table(name,status,creationTimestamp,networkInterfaces[0].accessConfigs[0].natIP)'
```

---

## Reconnect to an existing workspace

If the cloud computer is stopped, start it first, wait for it, then reconnect:

**macOS/Linux:**
```bash
INSTANCE_ID="freshvibe-XXXXXXXX"  # replace with your workspace name
PROJECT_ID="${GCP_PROJECT_ID:-path26-489205}"
ZONE="${GCP_GCE_ZONE:-europe-west1-b}"

# Start the machine if it's off
gcloud compute instances start "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" --quiet

# Wait for it to be ready
for i in $(seq 1 30); do
  gcloud compute ssh "$INSTANCE_ID" \
    --project="$PROJECT_ID" --zone="$ZONE" \
    --command="curl -sf http://localhost:8080/health" \
    --quiet 2>/dev/null && break
  sleep 5
done

# Generate a new password and restart the server
OPENCODE_PASSWORD="$(openssl rand -hex 16)"
gcloud compute ssh "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --command="
    export PATH=\"\$HOME/.opencode/bin:/usr/local/bin:\$PATH\"
    tmux kill-session -t opencode 2>/dev/null || true
    tmux new-session -d -s opencode \"OPENCODE_SERVER_PASSWORD=$OPENCODE_PASSWORD opencode serve --port 4096 --hostname 0.0.0.0\"
  "

# Connect
gcloud compute ssh "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  -- -L 4096:localhost:4096 -N -f

opencode attach http://localhost:4096 --password "$OPENCODE_PASSWORD"
```

**Windows:**
```powershell
$INSTANCE_ID = "freshvibe-XXXXXXXX"  # replace with your workspace name
$PROJECT_ID = if ($env:GCP_PROJECT_ID) { $env:GCP_PROJECT_ID } else { "path26-489205" }
$ZONE = if ($env:GCP_GCE_ZONE) { $env:GCP_GCE_ZONE } else { "europe-west1-b" }

# Start the machine if it's off
gcloud compute instances start $INSTANCE_ID --project=$PROJECT_ID --zone=$ZONE --quiet

# Wait for it to be ready
for ($i = 1; $i -le 30; $i++) {
    try {
        $r = gcloud compute ssh $INSTANCE_ID --project=$PROJECT_ID --zone=$ZONE --command="curl -sf http://localhost:8080/health" --quiet 2>$null
        if ($r) { break }
    } catch {}
    Start-Sleep -Seconds 5
}

# Generate a new password and restart the server
$OPENCODE_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
gcloud compute ssh $INSTANCE_ID --project=$PROJECT_ID --zone=$ZONE `
  --command="export PATH=`"`$HOME/.opencode/bin:/usr/local/bin:`$PATH`"; tmux kill-session -t opencode 2>/dev/null || true; tmux new-session -d -s opencode `"OPENCODE_SERVER_PASSWORD=$OPENCODE_PASSWORD opencode serve --port 4096 --hostname 0.0.0.0`""

# Connect
Start-Process -NoNewWindow gcloud -ArgumentList "compute", "ssh", $INSTANCE_ID, "--project=$PROJECT_ID", "--zone=$ZONE", "--", "-L", "4096:localhost:4096", "-N"
Start-Sleep -Seconds 3
opencode attach http://localhost:4096 --password $OPENCODE_PASSWORD
```

---

## Pause a workspace (saves your files, stops billing)

**macOS/Linux:**
```bash
gcloud compute instances stop "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" --quiet
```

**Windows:**
```powershell
gcloud compute instances stop $INSTANCE_ID --project=$PROJECT_ID --zone=$ZONE --quiet
```

Tell the user: "Your workspace is paused. Your files are saved and will be there when you start it again. You won't be charged while it's paused."

Note: The cloud computer also auto-pauses after 15 minutes of no activity.

---

## Delete a workspace

**macOS/Linux:**
```bash
# Remove the cloud computer (your files are kept separately)
gcloud compute instances delete "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" --quiet

# To also remove saved files:
gcloud compute disks delete "${INSTANCE_ID}-home" \
  --project="$PROJECT_ID" --zone="$ZONE" --quiet
```

**Windows:**
```powershell
gcloud compute instances delete $INSTANCE_ID --project=$PROJECT_ID --zone=$ZONE --quiet

# To also remove saved files:
gcloud compute disks delete "$INSTANCE_ID-home" --project=$PROJECT_ID --zone=$ZONE --quiet
```

---

## Troubleshooting

If something goes wrong, run these to see what's happening:

**Check if the cloud computer is healthy:**
```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command="curl -sf http://localhost:8080/health"
```

**See the startup log (if the machine seems stuck):**
```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command="sudo journalctl -u google-startup-scripts --no-pager | tail -30"
```

**Check if OpenCode is running on the cloud:**
```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command="tmux capture-pane -t opencode -p 2>/dev/null || echo 'OpenCode server not running'"
```

**Connect directly for debugging:**
```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE"
```

---

## How it works (for the curious)

- Your cloud workspace is a Linux computer running in Google Cloud (Europe)
- It comes pre-installed with Node.js, git, and developer tools
- Your files are stored on a separate disk that persists even when the computer is off or deleted
- OpenCode runs as a server on the cloud computer, and your local OpenCode connects to it through a secure tunnel
- The machine automatically shuts down after 15 minutes of inactivity to save costs
- Authentication uses a randomly generated password that's unique to each session

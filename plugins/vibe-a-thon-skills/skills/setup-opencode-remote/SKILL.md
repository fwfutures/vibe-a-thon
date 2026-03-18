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

## Step 2: Collect user info

Ask the user for two things:
1. **Their email address** — used to tag the cloud computer so they can find it later
2. **A project name** — a short name for what they're working on (e.g., "my-app", "website-redesign")

Before asking, try to detect the email automatically:

**macOS/Linux:**
```bash
git config --global user.email 2>/dev/null || gcloud config get-value account 2>/dev/null || echo "NOT_FOUND"
```

**Windows:**
```
powershell -Command "git config --global user.email 2>$null; if (-not $?) { & 'GCLOUD_CMD' config get-value account 2>$null }"
```

If an email is found, confirm it with the user: "I found your email as user@example.com — is that right, or would you like to use a different one?"

If NOT_FOUND, ask: "What email address should I tag this workspace with? This helps identify your cloud computers later."

Then ask: "What's a short name for your project? (e.g., 'my-app', 'website')"

**Save these as USER_EMAIL and PROJECT_NAME.** Sanitize the project name for use as a GCP label (lowercase, alphanumeric and hyphens only, max 63 chars).

---

## Step 3: Check and install gcloud CLI

### macOS

```bash
which gcloud && gcloud --version | head -1 || echo "NOT_FOUND"
```

If NOT_FOUND:
```bash
brew install --cask google-cloud-sdk || echo "Install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
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

## Step 6: Create the cloud workspace

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
INSTANCE_ID="freshvibe-$(openssl rand -hex 4)"
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

# Create the cloud computer with labels and metadata
gcloud compute instances create "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --source-instance-template="$TEMPLATE" \
  --labels="managed-by=freshvibe,owner=$OWNER_LABEL,project=$PROJECT_LABEL" \
  --metadata="freshvibe-owner-email-b64=$(echo -n 'USER_EMAIL' | base64),freshvibe-project-ids-b64=$(echo -n '[\"PROJECT_NAME\"]' | base64)" \
  --disk="name=$DISK_NAME,device-name=freshvibe-home,mode=rw,boot=no,auto-delete=no" \
  --quiet

echo "Created: $INSTANCE_ID"
```

### Windows

Generate instance ID:
```
powershell -Command "$id = 'freshvibe-' + -join((48..57)+(97..102)|Get-Random -Count 8|%%{[char]$_}); Write-Output $id"
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

Create instance:
```
powershell -Command "& 'GCLOUD_CMD' compute instances create 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --source-instance-template=freshvibe-gce-template --labels=managed-by=freshvibe,owner=OWNER_LABEL,project=PROJECT_LABEL --metadata=freshvibe-owner-email-b64=EMAIL_B64,freshvibe-project-ids-b64=PROJECT_B64 --disk='name=INSTANCE_ID-home,device-name=freshvibe-home,mode=rw,boot=no,auto-delete=no' --quiet"
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

## Step 7: Wait for the cloud computer to be ready

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

## Step 8: Install and start OpenCode on the cloud computer

### macOS/Linux

```bash
OPENCODE_PASSWORD="$(openssl rand -hex 16)"

# Install opencode
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='curl -fsSL https://opencode.ai/install | bash'

# Add to PATH
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='grep -q opencode ~/.bashrc || echo "export PATH=\$HOME/.opencode/bin:\$PATH" >> ~/.bashrc'

# Start server in tmux (single simple command)
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command="PATH=\$HOME/.opencode/bin:\$PATH tmux new-session -d -s oc 'OPENCODE_SERVER_PASSWORD=$OPENCODE_PASSWORD opencode serve --port 4096 --hostname 0.0.0.0'"

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

Start the server. **Run exactly this command** — note: NO `&&`, NO `||`, NO `2>/dev/null`, NO `export`. The `PATH=...` prefix sets PATH for just this command, and the entire tmux command argument is wrapped in single quotes:

```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='PATH=/home/ben/.opencode/bin:/usr/local/bin:/usr/bin:/bin tmux new-session -d -s oc OPENCODE_SERVER_PASSWORD=OPENCODE_PASSWORD opencode serve --port 4096 --hostname 0.0.0.0'"
```

**IMPORTANT**: In the tmux command above, `OPENCODE_SERVER_PASSWORD=OPENCODE_PASSWORD` is passed as **arguments to tmux**, NOT as a shell export. tmux treats everything after `-s oc` as the command and its arguments. This is intentional — it avoids all quoting problems.

**IMPORTANT**: Replace `/home/ben/` with the actual remote user's home directory. To find it:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='echo $HOME'"
```

Verify it's running:
```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='tmux has-session -t oc'"
```

If this returns exit code 0 → server is running. If it shows "no server running on /tmp/tmux-..." that means the tmux command above didn't start properly. Check the remote PATH and try again.

---

## Step 9: Clone the starter repo

After OpenCode server is running, clone the starter repo on the remote machine so there's a project to work with.

### macOS/Linux

```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='cd ~ ; git clone https://github.com/fwfutures/fv-rome2rio-starter.git 2>/dev/null || echo "Already cloned"'
```

### Windows

```
powershell -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='cd ~ ; git clone https://github.com/fwfutures/fv-rome2rio-starter.git'"
```

If the repo is private and cloning fails with "Authentication failed", the GH_TOKEN env var needs to be set on the instance. See "Baking GH_TOKEN into the instance template" below.

For private repos with GH_TOKEN already baked into the template, git will auto-authenticate via the credential helper.

---

## Step 10: Create tunnel and connect

### macOS/Linux

```bash
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  -- -L 4096:localhost:4096 -N -f

opencode attach http://localhost:4096 --password "$OPENCODE_PASSWORD"
```

### Windows — use IAP tunnel (PuTTY cannot do SSH port forwarding)

Start IAP tunnel in background:
```
powershell -Command "Start-Process -NoNewWindow -FilePath 'GCLOUD_CMD' -ArgumentList 'compute','start-iap-tunnel','INSTANCE_ID','4096','--local-host-port=localhost:4096','--project=path26-489205','--zone=europe-west1-b'"
```

Wait for tunnel:
```
powershell -Command "Start-Sleep -Seconds 5"
```

Test tunnel:
```
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:4096' -UseBasicParsing -TimeoutSec 5; Write-Output 'TUNNEL_OK' } catch { Write-Output 'TUNNEL_FAILED' }"
```

If TUNNEL_FAILED, wait 5 more seconds and retry. If it keeps failing, the OpenCode server may not have started — go back to Step 8.

Connect:
```
powershell -Command "& 'OPENCODE_CMD' attach http://localhost:4096 --password 'OPENCODE_PASSWORD'"
```

### After connecting, tell the user:

> "You're connected! OpenCode is now running on your cloud computer."

If the instance has an external IP, also tell them:

> "Your workspace is tagged with your email (USER_EMAIL) and project (PROJECT_NAME). If you start a dev server on port 3000, it'll be accessible at http://EXTERNAL_IP:3000"

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

- A dev server on port 3000 on instance `freshvibe-abc12345` would be accessible at `https://freshvibe-abc12345.path26.rome2rio.com`
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

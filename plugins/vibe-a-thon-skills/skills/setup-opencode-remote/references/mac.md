# macOS/Linux Commands Reference

Exact commands for each step on macOS (and Linux where noted).

## Step 2: Python 3.11+ (macOS only, skip on Linux)

On fresh macOS, `python3`/`git`/`gcloud` may trigger an Xcode Command Line Tools popup. Tell user: "Click 'Install' on the popup, wait, then tell me when done."

**NEVER use `sudo`.** Use `uv` instead (installs to home dir).

After installing via uv, `python3` may not be on PATH in subsequent commands. Use `uv run python3` or prefix with `export PATH="$HOME/.local/bin:$PATH"`.

```bash
python3 --version 2>/dev/null || echo "NOT_FOUND"
```

If NOT_FOUND or below 3.11:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
uv python install 3.12
python3 --version
```

## Step 3: gcloud CLI

```bash
which gcloud 2>/dev/null && gcloud --version 2>/dev/null | head -1 || echo "NOT_FOUND"
```

If NOT_FOUND:
```bash
if command -v brew &>/dev/null; then
  brew install --cask google-cloud-sdk
else
  curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="$HOME"
  export PATH="$HOME/google-cloud-sdk/bin:$PATH"
fi
```

## Step 4: OpenCode

Check desktop app first:
```bash
if [ -x "/Applications/OpenCode.app/Contents/MacOS/opencode-cli" ]; then
  echo "FOUND: /Applications/OpenCode.app/Contents/MacOS/opencode-cli"
elif command -v opencode &>/dev/null; then
  echo "FOUND: $(which opencode)"
else
  echo "NOT_FOUND"
fi
```
**Save found path as OPENCODE_CMD.**

If NOT_FOUND:
```bash
curl -fsSL https://opencode.ai/install | bash
export PATH="$HOME/.opencode/bin:$PATH"
```
Or tell user: "Download OpenCode from https://opencode.ai/download"

## Step 5: Sign in

Run synchronously. **Do NOT background with `&`. Do NOT manually construct OAuth URLs.**

```bash
gcloud auth login --project=path26-489205
```
Tell user: "A browser window will open for Google sign-in. Complete it there, then come back."

## Step 6: Collect user info

**Do NOT ask until auth is confirmed.**

```bash
gcloud config get-value account 2>/dev/null || git config --global user.email 2>/dev/null || echo "NOT_FOUND"
```
Confirm email with user. Ask for project name.

## Step 7: Create workspace

```bash
INSTANCE_ID="opencode-$(openssl rand -hex 4)"
PROJECT_ID="${GCP_PROJECT_ID:-path26-489205}"
ZONE="${GCP_GCE_ZONE:-europe-west1-b}"
TEMPLATE="${GCP_GCE_INSTANCE_TEMPLATE:-freshvibe-gce-template}"
DISK_NAME="${INSTANCE_ID}-home"
OWNER_LABEL=$(echo "USER_EMAIL" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | cut -c1-63)
PROJECT_LABEL=$(echo "PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | cut -c1-63)

# Create disk
gcloud compute disks create "$DISK_NAME" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --size=10GB --type=pd-balanced \
  --labels="managed-by=freshvibe,owner=$OWNER_LABEL,project=$PROJECT_LABEL" \
  --quiet

# Create instance — NO --metadata (would replace template metadata!)
gcloud compute instances create "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --source-instance-template="$TEMPLATE" \
  --labels="managed-by=freshvibe,owner=$OWNER_LABEL,project=$PROJECT_LABEL" \
  --disk="name=$DISK_NAME,device-name=freshvibe-home,mode=rw,boot=no,auto-delete=no" \
  --quiet

# Add metadata AFTER creation (merges with template metadata)
gcloud compute instances add-metadata "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --metadata="freshvibe-owner-email-b64=$(echo -n 'USER_EMAIL' | base64),freshvibe-project-ids-b64=$(echo -n '[\"PROJECT_NAME\"]' | base64)" \
  --quiet
```

## Step 8: Wait for ready

```bash
for i in $(seq 1 60); do
  if gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --command="curl -sf http://localhost:8080/health" --quiet 2>/dev/null; then
    echo "Ready!"; break
  fi
  echo "  Starting... ($((i*5))s)"
  sleep 5
done
```

## Step 9: Install and start OpenCode server

```bash
OPENCODE_PASSWORD="$(openssl rand -hex 16)"

# Install
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='curl -fsSL https://opencode.ai/install | bash'

# Add to PATH
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='touch ~/.bashrc ; grep -q opencode ~/.bashrc || echo "export PATH=\$HOME/.opencode/bin:\$PATH" >> ~/.bashrc'

# Find remote home
REMOTE_HOME=$(gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --command='echo $HOME' --quiet 2>/dev/null | tr -d '\r\n')

# Start in tmux — bash -lc (login shell) so /etc/profile.d/ env vars (GH_TOKEN, Vertex AI etc.) are loaded
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command="tmux new-session -d -s oc 'bash -lc \"OPENCODE_SERVER_PASSWORD=$OPENCODE_PASSWORD ${REMOTE_HOME}/.opencode/bin/opencode serve --port 4096 --hostname 0.0.0.0\"'"
```

## Step 10: Clone starter repo

**GH_TOKEN sources** (check in order):
1. Local: `grep "^GH_TOKEN=" .env`
2. Env: `echo $GH_TOKEN`
3. Remote: `gcloud compute ssh ... --command='grep GH_TOKEN /etc/profile.d/freshvibe-runtime.sh'`

```bash
# Public repo
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='cd ~ ; git clone https://github.com/fwfutures/fv-rome2rio-starter.git'

# Private repo (embed token, then strip)
GH_TOKEN="${GH_TOKEN:-$(grep "^GH_TOKEN=" .env 2>/dev/null | cut -d= -f2)}"
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command="cd ~ ; git clone https://x-access-token:${GH_TOKEN}@github.com/fwfutures/fv-rome2rio-starter.git"
gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  --command='cd ~/fv-rome2rio-starter ; git remote set-url origin https://github.com/fwfutures/fv-rome2rio-starter.git'
```

## Step 11: Port slug

```bash
PORT_SLUG=$(echo "PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | cut -c1-63)
gcloud compute instances add-metadata "$INSTANCE_ID" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --metadata="freshvibe-port-slugs=[\"$PORT_SLUG\"]"
echo "https://${PORT_SLUG}.path26.rome2rio.com (port 3000)"
```

## Step 12: Tunnel + desktop app config

### 12a: Start tunnel (detached, survives app restart)

```bash
nohup gcloud compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" \
  -- -L 4096:localhost:4096 -N -o ServerAliveInterval=60 \
  > /tmp/opencode-tunnel.log 2>&1 &
echo "Tunnel PID: $!"
```

Test (expect 401 = tunnel works):
```bash
sleep 10 && curl -so /dev/null -w '%{http_code}' http://localhost:4096 | grep -q '401' && echo "TUNNEL_OK" || echo "TUNNEL_FAILED"
```

### 12b: Reconfig desktop app (self-destruct pattern)

The agent runs INSIDE OpenCode. Write a detached script that quits the app, writes config, relaunches.

Tell user: "I'm about to restart OpenCode to connect it to your cloud workspace. It will close and reopen in a few seconds."

```bash
cat > /tmp/opencode-reconfig.sh << 'RECONFIG'
#!/bin/bash
OPENCODE_PASSWORD="REPLACE_PASSWORD"
INSTANCE_ID="REPLACE_INSTANCE_ID"
PYTHON3="REPLACE_PYTHON3_PATH"
SETTINGS_DAT="$HOME/Library/Application Support/ai.opencode.desktop/opencode.settings.dat"
GLOBAL_DAT="$HOME/Library/Application Support/ai.opencode.desktop/opencode.global.dat"

sleep 3
osascript -e 'quit app "OpenCode"' 2>/dev/null
sleep 3
pkill -f "OpenCode" 2>/dev/null
sleep 1

echo '{"defaultServerUrl":"http://localhost:4096"}' > "$SETTINGS_DAT"

"$PYTHON3" -c "
import json, os
path = os.path.expanduser('~/Library/Application Support/ai.opencode.desktop/opencode.global.dat')
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
server = json.loads(data.get('server', '{}'))
if 'list' not in server:
    server['list'] = []
server['list'] = [s for s in server['list'] if s.get('http', {}).get('url') != 'http://localhost:4096']
server['list'].append({
    'type': 'http',
    'http': {'url': 'http://localhost:4096', 'username': 'opencode', 'password': '$OPENCODE_PASSWORD'},
    'displayName': 'Cloud: $INSTANCE_ID'
})
data['server'] = json.dumps(server)
with open(path, 'w') as f:
    json.dump(data, f)
"

open -a OpenCode
RECONFIG
chmod +x /tmp/opencode-reconfig.sh

# Replace placeholders
sed -i '' "s|REPLACE_PASSWORD|$OPENCODE_PASSWORD|" /tmp/opencode-reconfig.sh
sed -i '' "s|REPLACE_INSTANCE_ID|$INSTANCE_ID|" /tmp/opencode-reconfig.sh
sed -i '' "s|REPLACE_PYTHON3_PATH|$(which python3 2>/dev/null || echo python3)|" /tmp/opencode-reconfig.sh

# Launch detached
nohup /tmp/opencode-reconfig.sh > /tmp/opencode-reconfig.log 2>&1 &
disown
```

## Step 13: Convenience scripts + tunnel service

### Start/stop script

```bash
cat > ~/opencode-workspace.sh << 'SCRIPT'
#!/bin/bash
INSTANCE_ID="INSTANCE_ID_HERE"
PROJECT_ID="path26-489205"
ZONE="europe-west1-b"
GCLOUD="GCLOUD_PATH_HERE"

case "$1" in
  start)
    echo "Starting your cloud workspace..."
    "$GCLOUD" compute instances start "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --quiet
    echo "Waiting for it to be ready..."
    for i in $(seq 1 30); do
      "$GCLOUD" compute ssh "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --command='curl -sf http://localhost:8080/health' --quiet 2>/dev/null && break
      sleep 5
    done
    echo "Workspace is ready! Open OpenCode to connect."
    ;;
  stop)
    echo "Stopping your cloud workspace (files are saved)..."
    "$GCLOUD" compute instances stop "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --quiet
    echo "Stopped. Start again with: opencode-workspace start"
    ;;
  status)
    STATUS=$("$GCLOUD" compute instances describe "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --format='value(status)' 2>/dev/null)
    echo "Workspace: $INSTANCE_ID — $STATUS"
    ;;
  *) echo "Usage: opencode-workspace [start|stop|status]" ;;
esac
SCRIPT
chmod +x ~/opencode-workspace.sh

SHELL_RC="$HOME/.zshrc"
[ -f "$HOME/.bashrc" ] && SHELL_RC="$HOME/.bashrc"
touch "$SHELL_RC"
grep -q opencode-workspace "$SHELL_RC" || echo 'alias opencode-workspace="$HOME/opencode-workspace.sh"' >> "$SHELL_RC"
```

Replace `INSTANCE_ID_HERE` and `GCLOUD_PATH_HERE` with actual values.

### Tunnel service (launchd)

```bash
GCLOUD_PATH="$(which gcloud)"
mkdir -p ~/Library/LaunchAgents

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
```

Remove: `launchctl unload ~/Library/LaunchAgents/com.freshvibe.opencode-tunnel.plist && rm ~/Library/LaunchAgents/com.freshvibe.opencode-tunnel.plist`

## Other operations

**List workspaces:**
```bash
gcloud compute instances list --project="${GCP_PROJECT_ID:-path26-489205}" --zones="${GCP_GCE_ZONE:-europe-west1-b}" --filter='labels.managed-by=freshvibe' --format='table(name,status,labels.owner,labels.project)'
```

**Stop:** `gcloud compute instances stop "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --quiet`

**Delete:** `gcloud compute instances delete "$INSTANCE_ID" --project="$PROJECT_ID" --zone="$ZONE" --quiet`

**Delete saved files too:** `gcloud compute disks delete "${INSTANCE_ID}-home" --project="$PROJECT_ID" --zone="$ZONE" --quiet`

## GH_TOKEN in template

One-time setup to bake GH_TOKEN into the instance template:
```bash
./scripts/gcp-gce-setup.sh \
  --project-id=path26-489205 --zone=europe-west1-b \
  --instance-template=freshvibe-gce-template \
  --no-external-ip --daemon-source-ranges=10.0.0.0/8 \
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

Ad-hoc on running instance: `gcloud compute ssh ... --command='echo "export GH_TOKEN=TOKEN" >> ~/.bashrc'`

## Port proxy

Dev servers on port 3000 are accessible at `https://SLUG.path26.rome2rio.com` when a port slug is registered (Step 11). The LB URL mask routes `<slug>.path26.rome2rio.com` to the instance's port 3000.

# Windows Commands Reference

Exact commands for each step on Windows.

**CRITICAL**: Your shell tool runs `cmd.exe`, NOT PowerShell. Wrap ALL PowerShell commands:
```
powershell -ExecutionPolicy Bypass -Command "YOUR_COMMAND"
```
**NEVER** run bare PowerShell syntax without the wrapper.

**CRITICAL**: `gcloud compute ssh` uses PuTTY (plink.exe) on Windows. SSH port forwarding (`-- -L 4096:...`) WILL FAIL. Use `gcloud compute start-iap-tunnel` instead.

**CRITICAL**: For remote SSH commands, NEVER use `&&`, `||`, `2>/dev/null`. Use `;` or separate SSH calls.

## Step 2: Python (skip on Windows)

Windows gcloud bundles its own Python. Skip this step.

## Step 3: gcloud CLI

Check these locations. **Save the first found path as GCLOUD_CMD** — use it in ALL subsequent commands.

```
powershell -ExecutionPolicy Bypass -Command "
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

If NOT_FOUND:
```
powershell -ExecutionPolicy Bypass -Command "winget install --id Google.CloudSDK -e --accept-package-agreements --accept-source-agreements"
```
Then re-run the check to find the installed path.

## Step 4: OpenCode

Check these locations. **Save found path as OPENCODE_CMD.**

```
powershell -ExecutionPolicy Bypass -Command "
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

If NOT_FOUND, tell user: "Please download OpenCode from https://opencode.ai/download and install it." Do NOT try `irm | iex` — that URL doesn't exist.

## Step 5: Sign in

**NEVER run gcloud auth login synchronously on Windows (it will time out).**

1. Launch in a separate window:
```
powershell -ExecutionPolicy Bypass -Command "Start-Process 'GCLOUD_CMD' -ArgumentList 'auth','login','--project=path26-489205'"
```

2. Tell user: "A browser window should open for Google sign-in. Complete it, then tell me when done."

3. After user confirms, verify:
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' auth list --format='value(account)' 2>$null"
```

4. Set project:
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' config set project path26-489205"
```

## Step 6: Collect user info

**Do NOT ask until auth is confirmed.**

```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' config get-value account 2>$null"
```
If empty, try: `powershell -ExecutionPolicy Bypass -Command "git config --global user.email 2>$null"`

## Step 7: Create workspace

Generate instance ID:
```
powershell -ExecutionPolicy Bypass -Command "$id = 'opencode-' + -join((48..57)+(97..102)|Get-Random -Count 8|%%{[char]$_}); Write-Output $id"
```
**Save output as INSTANCE_ID.**

Encode metadata:
```
powershell -ExecutionPolicy Bypass -Command "[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('USER_EMAIL'))"
```
**Save as EMAIL_B64.**
```
powershell -ExecutionPolicy Bypass -Command "[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('[""PROJECT_NAME""]'))"
```
**Save as PROJECT_B64.**

Create disk:
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute disks create 'INSTANCE_ID-home' --project=path26-489205 --zone=europe-west1-b --size=10GB --type=pd-balanced --labels=managed-by=freshvibe,owner=OWNER_LABEL,project=PROJECT_LABEL --quiet"
```

Create instance — **NO `--metadata`** (would replace template metadata!):
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute instances create 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --source-instance-template=freshvibe-gce-template --labels=managed-by=freshvibe,owner=OWNER_LABEL,project=PROJECT_LABEL --disk='name=INSTANCE_ID-home,device-name=freshvibe-home,mode=rw,boot=no,auto-delete=no' --quiet"
```

Add metadata AFTER creation:
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute instances add-metadata 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --metadata=freshvibe-owner-email-b64=EMAIL_B64,freshvibe-project-ids-b64=PROJECT_B64 --quiet"
```

## Step 8: Wait for ready

Run every 10 seconds, up to 30 times:
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='curl -sf http://localhost:8080/health' --quiet 2>$null"
```
Exit code 0 + non-empty output = ready. Otherwise wait 10 seconds and retry.

## Step 9: Install and start OpenCode server

Generate password:
```
powershell -ExecutionPolicy Bypass -Command "$p = -join((48..57)+(65..90)+(97..122)|Get-Random -Count 32|%%{[char]$_}); Write-Output $p"
```
**Save as OPENCODE_PASSWORD.**

Install:
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='curl -fsSL https://opencode.ai/install | bash'"
```

Find remote home:
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='echo $HOME' --quiet"
```
**Save as REMOTE_HOME** (e.g., `/home/ben`).

Start server (bash -lc = login shell so GH_TOKEN, Vertex AI env vars from /etc/profile.d/ are loaded):
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='tmux new-session -d -s oc ""bash -lc \""OPENCODE_SERVER_PASSWORD=OPENCODE_PASSWORD REMOTE_HOME/.opencode/bin/opencode serve --port 4096 --hostname 0.0.0.0\""""'"
```
Replace `REMOTE_HOME` and `OPENCODE_PASSWORD` with actual values.

Verify:
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='tmux has-session -t oc'"
```

## Step 10: Clone starter repo

Read GH_TOKEN from .env:
```
powershell -ExecutionPolicy Bypass -Command "$token = (Select-String -Path '.env' -Pattern '^GH_TOKEN=(.+)$').Matches.Groups[1].Value; Write-Output $token"
```
**Save as GH_TOKEN_VALUE.**

Clone (public):
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='cd ~ ; git clone https://github.com/fwfutures/fv-rome2rio-starter.git'"
```

Clone (private — embed token, then strip):
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='cd ~ ; git clone https://x-access-token:GH_TOKEN_VALUE@github.com/fwfutures/fv-rome2rio-starter.git'"
```
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute ssh 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --command='cd ~/fv-rome2rio-starter ; git remote set-url origin https://github.com/fwfutures/fv-rome2rio-starter.git'"
```

## Step 11: Port slug

```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute instances add-metadata 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --metadata='freshvibe-port-slugs=[""PORT_SLUG""]'"
```

## Step 12: Tunnel + desktop app config

### 12a: Start IAP tunnel (detached)

```
powershell -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'GCLOUD_CMD' -ArgumentList 'compute','start-iap-tunnel','INSTANCE_ID','4096','--local-host-port=localhost:4096','--project=path26-489205','--zone=europe-west1-b' -WindowStyle Hidden"
```

Test (expect 401 = working):
```
powershell -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds 10; try { $null = Invoke-WebRequest -Uri 'http://localhost:4096' -UseBasicParsing -TimeoutSec 5 } catch { if ($_.Exception.Response.StatusCode -eq 401) { Write-Output 'TUNNEL_OK' } else { Write-Output 'TUNNEL_FAILED' } }"
```

### 12b: Reconfig desktop app (self-destruct pattern)

Tell user: "I'm about to restart OpenCode to connect it to your cloud workspace."

Write reconfig script:
```
powershell -ExecutionPolicy Bypass -Command "
@'
Start-Sleep 3
Get-Process OpenCode -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3
'{""defaultServerUrl"":""http://localhost:4096""}' | Set-Content ""$env:APPDATA\ai.opencode.desktop\opencode.settings.dat""
$globalPath = ""$env:APPDATA\ai.opencode.desktop\opencode.global.dat""
if (Test-Path $globalPath) { $data = Get-Content $globalPath | ConvertFrom-Json } else { $data = @{} }
$serverJson = if ($data.server) { $data.server } else { '{}' }
$serverData = $serverJson | ConvertFrom-Json
if (-not $serverData.list) { $serverData | Add-Member -NotePropertyName 'list' -NotePropertyValue @() -Force }
$serverData.list = @($serverData.list | Where-Object { $_.http.url -ne 'http://localhost:4096' })
$newServer = @{ type='http'; http=@{ url='http://localhost:4096'; username='opencode'; password='OPENCODE_PASSWORD' }; displayName='Cloud: INSTANCE_ID' }
$serverData.list += $newServer
$data.server = ($serverData | ConvertTo-Json -Depth 10 -Compress)
$data | ConvertTo-Json -Depth 10 | Set-Content $globalPath
Start-Process ""$env:LOCALAPPDATA\OpenCode\OpenCode.exe""
'@ | Set-Content ""$env:TEMP\opencode-reconfig.ps1""
"
```

Launch detached:
```
powershell -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy','Bypass','-File','$env:TEMP\opencode-reconfig.ps1' -WindowStyle Hidden"
```

Replace `OPENCODE_PASSWORD` and `INSTANCE_ID` with actual values in the script content.

### devserver.txt (Windows format)

```
powershell -ExecutionPolicy Bypass -Command "
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
gcloud path:    GCLOUD_CMD

Remote Machine
--------------
Instance:       Running
OpenCode server: Running (tmux session: oc)

Cloud Details
-------------
GCP Project:    path26-489205
Zone:           europe-west1-b
'@ | Set-Content devserver.txt
"
```

## Step 13: Convenience scripts + tunnel service

### Start/stop script

```
powershell -ExecutionPolicy Bypass -Command "
@'
param([string]`$Action)
`$INSTANCE_ID = 'INSTANCE_ID_HERE'
`$PROJECT_ID = 'path26-489205'
`$ZONE = 'europe-west1-b'
`$GCLOUD = 'GCLOUD_CMD'

switch (`$Action) {
  'start' {
    Write-Output 'Starting your cloud workspace...'
    & `$GCLOUD compute instances start `$INSTANCE_ID --project=`$PROJECT_ID --zone=`$ZONE --quiet
    Write-Output 'Waiting for it to be ready...'
    for (`$i=1; `$i -le 30; `$i++) {
      try { `$r = & `$GCLOUD compute ssh `$INSTANCE_ID --project=`$PROJECT_ID --zone=`$ZONE --command='curl -sf http://localhost:8080/health' --quiet 2>`$null; if (`$r) { break } } catch {}
      Start-Sleep 5
    }
    Write-Output 'Workspace is ready! Open OpenCode to connect.'
  }
  'stop' {
    Write-Output 'Stopping your cloud workspace (files are saved)...'
    & `$GCLOUD compute instances stop `$INSTANCE_ID --project=`$PROJECT_ID --zone=`$ZONE --quiet
    Write-Output 'Stopped.'
  }
  'status' {
    `$s = & `$GCLOUD compute instances describe `$INSTANCE_ID --project=`$PROJECT_ID --zone=`$ZONE --format='value(status)' 2>`$null
    Write-Output `"Workspace: `$INSTANCE_ID - `$s`"
  }
  default { Write-Output 'Usage: opencode-workspace start|stop|status' }
}
'@ | Set-Content `"`$env:USERPROFILE\opencode-workspace.ps1`"
Write-Output 'Created ~/opencode-workspace.ps1'
"
```

### Tunnel service (Scheduled Task)

```
powershell -ExecutionPolicy Bypass -Command "
  `$action = New-ScheduledTaskAction -Execute 'GCLOUD_CMD' -Argument 'compute start-iap-tunnel INSTANCE_ID 4096 --local-host-port=localhost:4096 --project=path26-489205 --zone=europe-west1-b'
  `$trigger = New-ScheduledTaskTrigger -AtLogOn
  `$settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
  Register-ScheduledTask -TaskName 'OpenCode Cloud Tunnel' -Action `$action -Trigger `$trigger -Settings `$settings -Description 'IAP tunnel to GCE workspace'
  Start-ScheduledTask -TaskName 'OpenCode Cloud Tunnel'
  Write-Output 'Tunnel service installed'
"
```

Remove:
```
powershell -ExecutionPolicy Bypass -Command "Stop-ScheduledTask -TaskName 'OpenCode Cloud Tunnel' -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName 'OpenCode Cloud Tunnel' -Confirm:`$false -ErrorAction SilentlyContinue"
```

## Other operations

**List workspaces:**
```
powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute instances list --project=path26-489205 --zones=europe-west1-b --filter='labels.managed-by=freshvibe' --format='table(name,status,labels.owner,labels.project)'"
```

**Stop:** `powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute instances stop 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --quiet"`

**Delete:** `powershell -ExecutionPolicy Bypass -Command "& 'GCLOUD_CMD' compute instances delete 'INSTANCE_ID' --project=path26-489205 --zone=europe-west1-b --quiet"`

## Windows-specific notes

- PowerShell aliases `curl` to `Invoke-WebRequest`. Use `curl.exe` for real curl.
- "External IP not found; defaulting to IAP tunneling" is normal.
- If `gcloud compute ssh --command=` fails with quoting errors: use `;` not `&&`, use separate SSH calls, use single quotes around `--command=` value.

---
name: setup-mac-dev
description: This skill should be used when the user asks to "set up a fresh Mac for development", "install Homebrew and Node on macOS", "prepare a new MacBook for coding", "install uv Python on Mac", or "fix missing node/npm/npx on macOS".
---

# macOS Development Setup

Perform setup directly with tools. Do not offload commands to the user unless a GUI prompt or privileged approval is required.

Before starting, tell the user:

> "Setting up this Mac for development now. This may require command-line tools installation and admin approval prompts."

Then execute each step and report concise progress updates.

## Step 1: Preflight checks

Run checks first and record results.

```bash
uname -sm
which brew || true
which node || true
which npm || true
which npx || true
which uv || true
xcode-select -p || true
```

Interpretation:

- If required tools already exist, skip reinstallation and keep going.
- If `xcode-select -p` fails, treat missing Command Line Tools (CLT) as a likely blocker for `git` and Homebrew.

## Step 2: Ensure Xcode Command Line Tools

If CLT is missing:

```bash
xcode-select --install
```

Notes:

- This may open a system dialog and require user acceptance.
- Continue with user-local installs when CLT remains unavailable.

## Step 3: Install Homebrew when possible

Check whether Homebrew already exists:

```bash
which brew
```

If missing, attempt install:

```bash
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

If Homebrew install fails due missing admin privileges or CLT, continue with no-admin fallback in Step 4.

## Step 4: Install Node.js (preferred: Homebrew, fallback: user-local)

Preferred path when Homebrew is available:

```bash
brew install node
```

Fallback path without Homebrew:

```bash
mkdir -p "$HOME/.local" "$HOME/.local/bin"
curl -fsSL "https://nodejs.org/dist/v22.22.0/node-v22.22.0-darwin-arm64.tar.gz" -o "$HOME/.local/node-v22.22.0-darwin-arm64.tar.gz"
tar -xzf "$HOME/.local/node-v22.22.0-darwin-arm64.tar.gz" -C "$HOME/.local"
ln -sfn "$HOME/.local/node-v22.22.0-darwin-arm64" "$HOME/.local/node"
ln -sfn "$HOME/.local/node/bin/node" "$HOME/.local/bin/node"
ln -sfn "$HOME/.local/node/bin/npm" "$HOME/.local/bin/npm"
ln -sfn "$HOME/.local/node/bin/npx" "$HOME/.local/bin/npx"
```

Add local bin to current shell session when using fallback:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Step 5: Install uv and Python

Install uv:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Ensure uv is on PATH for the current session:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Install a managed Python:

```bash
uv python install
```

## Step 6: Install skills packages

Use `npx skills add` with global scope when not inside a project repository:

```bash
GH_TOKEN=<token> npx skills add fwfutures/rome2rio-skills fwfutures/vibe-a-thon -g -y
```

If clone fails (often due CLT/git or auth issues), fallback to zipball workflow:

1. Download each repository zipball from GitHub API with `GH_TOKEN`.
2. Unzip into a temp folder.
3. Install from local extracted path:

```bash
npx skills add /path/to/extracted/repo -g -y
```

Security note:

- Keep tokens in environment variables.
- Do not echo tokens into logs or summaries.

## Step 7: Verify tooling and skills

Run final verification commands:

```bash
export PATH="$HOME/.local/bin:$PATH"
which brew || true
node -v
npm -v
npx -v
uv --version
uv python list
npx skills list -g
```

## Step 8: Report completion

Provide a concise final report including:

- Installed vs already-present tools (`brew`, `node`, `npm`, `npx`, `uv`, `python`)
- Skills installed successfully
- Any blockers that remain (for example, CLT still pending)
- Exact next command if one manual action is still needed

## Troubleshooting quick guide

- `npx: command not found`: ensure Node is installed and `~/.local/bin` is on PATH.
- `Failed to clone repository` with xcode-select message: complete CLT install or use zipball fallback.
- Homebrew installer asks for sudo/admin: switch to user-local Node path when admin access is unavailable.
- `Agents: not linked` in `npx skills list -g`: installation succeeded; linking depends on host agent runtime.

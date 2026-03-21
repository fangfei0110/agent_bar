# Agent Version Bar

Lightweight macOS menu bar app for tracking installed and latest versions of:

- OpenClaw
- OpenCode
- Claude Code

## What It Shows

- Installed version from the local CLI
- Latest available version from the official package source
- Install source detection (`Homebrew`, `npm`, `pnpm`, `Native Installer`, `Direct Binary`)

## Version Sources

- `OpenClaw`
  - Current: `openclaw status --json` or `openclaw --version`
  - Latest: `npm view openclaw version`
- `OpenCode`
  - Current: `opencode --version`
  - Latest: `npm view opencode-ai version`
  - Homebrew: `brew info --json=v2 anomalyco/tap/opencode`
- `Claude Code`
  - Current: `claude --version`
  - Latest: `npm view @anthropic-ai/claude-code version`
  - Homebrew: `brew info --json=v2 claude-code`

## Run

```bash
swift run AgentVersionBarApp
```

## Test

```bash
swift test
```

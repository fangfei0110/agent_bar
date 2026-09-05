# Agent Bar

Lightweight macOS menu bar app for tracking installed and latest versions of:

- OpenClaw
- OpenCode
- Claude Code
- Codex CLI
- Hermes Agent
- Paperclip

## What It Shows

- Installed version from the local CLI
- Latest available version from the official package source
- Install source detection (`Homebrew`, `npm`, `pnpm`, `Native Installer`, `Direct Binary`)
- Native frosted-glass panels with light, dark, and warm themes; opaque fallback for Reduce Transparency
- Official changelog, original text, and a Chinese summary (requires `summarize`; uses Codex when available)

## Refresh And Updates

New installations check every five minutes. An explicitly saved Off setting stays off.
Manual updates open in Terminal. Automatic updates are opt-in in Settings and only
run for an installed agent with a newer available version and a supported package
manager executable next to that agent's CLI. Native installers and unmanaged
binaries remain manual. Failed automatic updates show an error and are not
repeated for the same version during that app session; manual updates remain available.
Successful automatic updates refresh the installed versions.

Version checks and changelog commands share the same GUI-safe environment,
concurrently drain command input/output, and enforce timeouts.
Changelog summaries use `codex exec` in read-only, ephemeral mode when available,
respecting the model configured in Codex. Without Codex they use `summarize`.

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
- `Codex CLI`
  - Current: `codex --version`
  - Latest: `npm view @openai/codex version`
- `Hermes Agent`
  - Current: `hermes --version`
  - Latest: GitHub latest release for `NousResearch/hermes-agent`
- `Paperclip`
  - Current: `paperclipai --version`
  - Latest: `npm view paperclipai version`

## Run

```bash
swift run AgentVersionBarApp
```

To build a Release bundle, install it in `/Applications`, and relaunch it:

```bash
bash Scripts/install_app_bundle.sh
```

## Test

```bash
swift test
```

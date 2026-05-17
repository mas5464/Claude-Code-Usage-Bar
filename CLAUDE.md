# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Context

**Claude Code Usage Bar** is a macOS menu bar app that displays live Claude Code usage percentages (5h/7d rate limits) and Claude system status, built as a native Swift app with a Claude Code hook for the terminal statusline.

**Tech stack:** Swift (swiftc, no Xcode project file), bash scripts, macOS 13+, Cocoa + UserNotifications frameworks.

**Key files:**
- `src/ClaudeUsageBar.swift` — full native app: menu bar icon, status polling, `--statusline` mode, incident notifications
- `src/IconGenerator.swift` — generates the `.icns` bundle icon at build time
- `hooks/usage-statusline.sh` — Claude Code `statusLine` hook (bash); reads JSON from stdin, emits ANSI badges, writes state file
- `hooks/claude-usage-bar.1m.sh` — SwiftBar/xbar plugin (optional, 1-minute polling)
- `build.sh` — compiles the `.app` and packages a DMG (`dist/`)
- `install.sh` — one-step installer: installs hooks, wires `~/.claude/settings.json`, builds and launches the app
- `uninstall.sh` — removes hooks and statusLine config

**How to build:**
```bash
bash build.sh          # produces dist/ClaudeUsageBar.app + dist/ClaudeUsageBar.dmg
```
Requires Xcode Command Line Tools (`xcode-select --install`). Set `CODE_SIGN_IDENTITY` env var to sign; omit for ad-hoc (local testing).

**How to install from source:**
```bash
bash install.sh
```

**Architecture notes:**
- The app runs in two modes:
  - **Menu bar mode** (default, launched as `.app`): polls `~/.claude/.claude-usage-state.json` every 30s, fetches status.claude.com every 5min, shows menu with usage + system status
  - **Statusline mode** (`--statusline` arg): reads JSON from stdin, writes formatted ANSI to stdout + updates the state file; invoked by the hook after each Claude Code message
- State is shared via `~/.claude/.claude-usage-state.json`
- Caveman mode badge is auto-detected via `~/.claude/.caveman-active`
- The `statusLine` hook in `~/.claude/settings.json` is wired by `install.sh`

**Conventions:**
- All Swift in a single file (`ClaudeUsageBar.swift`) — no Xcode project, compiled directly with `swiftc`
- Bash hooks use `/usr/bin/jq` for JSON parsing (system jq, not Homebrew path)
- ANSI color thresholds: green <70%, orange <70–90%, red ≥90%

---

## Behavioral Guidelines

### 1. Plan Node Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `.claude/memory/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes — don't over-engineer

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user

### Core Principles
- **Simplicity First**: Make every change as simple as possible. Impact minimal code
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards

---

## Workflow Rules
- Before starting any task, check ROADMAP.md and mark it `[-]`
- After completing a task, mark it `[x]` with today's date
- Update TASKS.md at the end of every session with what's done and what's next
- After ANY correction from the user: update `.claude/memory/lessons.md` with the pattern
- Never ask to confirm status updates — just do them

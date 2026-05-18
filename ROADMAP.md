# Roadmap

## Progress Convention
- `[ ]` = Todo
- `[-]` = In Progress
- `[x]` = Completed

## Milestones

### Phase 1 — Foundation (Completed)
- [x] Native Swift menu bar app with usage display
- [x] Claude Code statusLine hook (bash)
- [x] State file sharing between hook and app
- [x] System status polling from status.claude.com
- [x] Incident notifications (macOS UserNotifications)
- [x] Badge icon (red dot on active incident)
- [x] Caveman mode badge integration
- [x] build.sh + DMG packaging
- [x] install.sh one-step installer
- [x] uninstall.sh
- [x] English / Spanish localization in menu
- [x] Weekly reset time display (day + time format)
- [x] Session reset time display (hours + minutes format)

### Phase 2 — Enhanced Display (Completed 2026-05-19)
- [x] Accumulated all-time cost via JSONL scanner (CostScanner)
- [x] Cost shown in dropdown split-panel (left column)
- [x] Current model name in dropdown and widget
- [x] Reset countdowns (5h and 7d) in dropdown and widget
- [x] Progress bars in dropdown and widget
- [x] Widget split-column layout (cost left, usage right)
- [x] Adaptive system colors (readable in light + dark mode)

### Phase 3 — Polish & Distribution
- [ ] Notarized public release on GitHub
- [ ] SwiftBar/xbar plugin parity with native app features
- [ ] Auto-update mechanism or update check notification

### Backlog
- [ ] Support for additional rate limit types as Claude Code adds them
- [ ] Configurable refresh intervals
- [ ] Light/dark mode adaptive icon

# Tasks

## Session — 2026-05-19

### Completed This Session
- Fixed stale indicator (added CLAUDE_USAGE_BAR_PRINT_STATUSLINE env var)
- Extended UsageState with `model` and `total_cost_usd` fields
- Added `formatCountdown()` and `formatCost()` helpers
- Added CostScanner — async JSONL cost accumulator with per-model pricing table
- Split-panel dropdown: cost + model left, 5H/7D progress bars + countdowns right
- Widget split-column layout: CostColumnView + CompactUsageRow
- Fixed ANSI statusline color mismatch after limit reset
- Redesigned to system adaptive colors (labelColor, systemGreen/Orange/Red)
- Simplified menu bar title to usage-only percentage (cost was too wide)

### Next Session
- Phase 3: notarized public release on GitHub
- Auto-update check notification
- Light/dark mode adaptive icon

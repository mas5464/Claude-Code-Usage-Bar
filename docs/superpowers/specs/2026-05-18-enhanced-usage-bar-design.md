# Enhanced Usage Bar — Cost, Countdown, Model, Progress

**Date:** 2026-05-18  
**Status:** Approved

---

## Goal

Bring the best features from `claude-statusbar` (Python) into the native Swift macOS app and WidgetKit widget: accumulated all-time cost, reset countdowns, current model name, and progress bars. The menu bar title becomes cost-forward; the dropdown and widget use a split-panel layout.

---

## What Changes

### 1. Menu Bar Title

```
◆  $14,118  │  11%
```

- Icon unchanged (template image, left of text)
- Accumulated all-time cost in green (`#a0e890` equivalent via NSColor)
- Separator `│`
- Current 5h usage percentage colored by threshold (green <70%, orange 70–90%, red ≥90%)
- Stale indicator `(stale)` appended when `updated_at` is >6 hours old — same as current

### 2. Dropdown Menu (split panel)

Replace current stacked menu rows with a two-column custom `NSView` embedded in a non-clickable `NSMenuItem`:

```
┌─────────────────────────────────────────┐
│  Cost            │  5h Limit             │
│  $14,118         │  11%  ████░░░░  ⏰37m │
│  all-time        │                       │
│                  │  7d Limit             │
│  claude-sonnet   │  2%   █░░░░░░░  ⏰6d  │
├──────────────────┴───────────────────────┤
│  Claude System Status: Online            │
├──────────────────────────────────────────┤
│  Updated 2 min ago    Refresh    Quit    │
└──────────────────────────────────────────┘
```

- Left column: total cost (large green text), "all-time" label, model name below
- Right column: 5h and 7d rows, each showing percentage + `NSProgressIndicator` bar + countdown
- System status and footer rows unchanged from current

### 3. State File Schema

`~/.claude/.claude-usage-state.json` gains two new optional fields:

```json
{
  "updated_at": 1779083842,
  "model": "claude-sonnet-4-6",
  "rate_limits": {
    "five_hour":  { "used_percentage": 11, "resets_at": 1779087600 },
    "seven_day":  { "used_percentage": 2,  "resets_at": 1779674400 }
  },
  "total_cost_usd": 14118.76
}
```

Both `model` and `total_cost_usd` are optional so existing state files continue to parse without errors.

### 4. `--statusline` Mode (Swift binary)

`renderStatusLine()` already decodes `rate_limits` from the hook payload. Add:
- Decode `model.id` from the payload (field: `model` → `{ "id": "...", "display_name": "..." }`)
- Include `model` string when writing the state file

No output changes — the terminal statusline display is unchanged.

### 5. Cost Scanner (`CostScanner`)

New class in `ClaudeUsageBar.swift`:

**Input:** `~/.claude/projects/**/*.jsonl`  
**Output:** writes `total_cost_usd` into the state file

**Algorithm:**
1. Glob all `.jsonl` files under `~/.claude/projects/`
2. For each file, parse each line as JSON
3. For entries with `type == "assistant"`, read `message.usage`:
   - `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens`
4. Read model from `message.model` (falls back to the session's last-seen model)
5. Multiply by pricing table (USD per million tokens):

| Model match    | Input  | Cache create | Cache read | Output |
|---------------|--------|-------------|-----------|--------|
| `opus-4`      | 15.00  | 18.75       | 1.50      | 75.00  |
| `sonnet-4`    | 3.00   | 3.75        | 0.30      | 15.00  |
| `haiku-4`     | 0.80   | 1.00        | 0.08      | 4.00   |
| `opus-3`      | 15.00  | 18.75       | 1.50      | 75.00  |
| `sonnet-3`    | 3.00   | 3.75        | 0.30      | 15.00  |
| `haiku-3`     | 0.25   | 0.30        | 0.03      | 1.25   |
| fallback      | 3.00   | 3.75        | 0.30      | 15.00  |

6. Sum all costs, write `total_cost_usd` atomically to the state file

**Schedule:** runs on a background `DispatchQueue` at app launch and every 10 minutes. Never blocks the main thread. If the scan takes >30s, it is cancelled and retried on the next interval.

**Performance:** ~1,400 files, ~67k lines. Expected scan time: 1–3s on modern hardware. Files are read sequentially; no parallelism needed.

### 6. Reset Countdown Formatting

Computed in `update()` from `resets_at` (unix timestamp in state file):

```
delta = resets_at - now
< 60s      → "< 1m"
< 3600s    → "Xm"          e.g. "37m"
< 86400s   → "Xh Ym"       e.g. "2h 14m"
≥ 86400s   → "Xd Yh"       e.g. "6d 19h"
expired    → ""  (omit)
```

### 7. Widget (`ClaudeUsageBarWidget.swift`)

**Medium widget — split columns:**
- Left: `$14K` (abbreviated), "all-time cost" label, model name
- Right: 5h row (%, bar, countdown) + 7d row (%, bar, countdown)

**Large widget — same as medium + bottom row:**
- Bottom: "Updated X min ago" timestamp

Both sizes read `model` and `total_cost_usd` from the shared state file via `$HOME` env var path (existing sandbox-aware mechanism).

Cost display format: full with commas for amounts under $10,000 (e.g. `$9,999`); abbreviated for ≥$10,000 (e.g. `$14.1K`); `$1.2M` for ≥$1,000,000. Menu bar title uses abbreviated form; dropdown left column uses full form.

---

## What Stays the Same

- Build system (`xcodebuild`, `build.sh`, `install.sh`)
- Single Swift source file (`src/ClaudeUsageBar.swift`) — no file split
- `--statusline` terminal output format (ANSI badges)
- Claude system status polling and incident alerts
- Stale detection threshold (6 hours)
- Setup/onboarding flow
- Caveman mode badge

---

## Out of Scope

- Multiple color themes (not needed given the split-panel design uses system colors)
- Session-only cost (accumulated all-time is the selected scope)
- Cost breakdown by project or model
- `claude-monitor` subprocess dependency (we scan JSONL directly)

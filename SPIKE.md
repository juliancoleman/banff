# Spike checklist (phase 0)

Run this on the MacBook. Record results inline and commit them. Once every row has an answer, PLAN.md is updated, and then this file and `widgets/banff-probe` and `widgets/banff-grow` are deleted.

## Setup

1. `git clone https://github.com/juliancoleman/banff ~/code/banff`
2. `ln -s ~/code/banff ~/.config/omniwm/shell/banff`
3. **Settings > Advanced > Enable IPC** (needed for `omniwmctl` below).
4. In OmniWM, name four workspaces `1`, `2`, `3`, `4`.
5. **Settings > Styles & Widgets**: turn the Workspace Bar on, select **Banff**, then **Use Style**.
6. `omniwmctl query shell-widgets`: note any error on `banff-*` widgets, `shell.toml` or `themes/banff.toml`.

Expected bar (right edge, top to bottom): workspaces, a clock pill, and a 48 pt stethoscope circle.

## Checks

| # | Check | How | Result |
|---|---|---|---|
| 1 | Symlinked profile loads | Banff appears and applies after step 5. If not, replace the symlink with a clone at `~/.config/omniwm/shell/banff` and retry | |
| 2 | 48 pt circle fits a 56 pt bar | The probe circle is round and unclipped | |
| 3 | Hover growth | Hover the clock pill: does it widen leftward from 40 to 160 pt over the desktop, get clipped at the bar edge, or widen the bar? Does the date appear? | |
| 4 | Overflow | Is the small accent dot 80 pt left of the clock pill (outside the bar) visible? | |
| 5 | Burst | Switch 1→2: dots and a longer pill spread along the bar, then collapse after about 0.9 s to the numbered pill. Do they spring or jump? | |
| 6 | Rapid switches | Switch 1→2→3 quickly: it stays expanded, the pill moves, and it collapses once | |
| 7 | Unexpected workspace | Switch to a workspace not named 1–4: a `?` pill appears and the bar collapses to `?` | |
| 8 | Collapse timer | If the bar never collapses, `omniwm.after` from `render` was rejected. Look for `banff-workspaces: collapse timer rejected` in the log (command below) | |
| 9 | Per-display workspaces | With an external display: does each bar's indicator show that display's workspace? Copy `bar.workspaces` and `workspaces` from each probe popout | |
| 10 | Main display | Click the probe on each display and record `bar.monitor` / `bar.monitorId`. Compare with `omniwmctl query displays` (which is main) | |
| 11 | Notifications | Probe `notifications.state` (expect `ready`). Run `osascript -e 'display notification "banff" with title "probe"'`, reopen the probe, and check that `items` went up. Then set Script Editor's alert style to None in System Settings > Notifications, send again, and check `items` | |
| 12 | Weather | Add `[weather]` with `city = "<your city>"` and `units = "fahrenheit"` to `~/.config/omniwm/shell/shell.toml`. Probe `weather`: `access`, `place`, `hours`, `days` and `firstHourRain` | |
| 13 | Menu bar | Did the full-width right bar switch on macOS menu-bar auto-hide? Is that acceptable, or should the bar use `fullWidth = false`? | |
| 14 | Settings writes | Change any Banff bar option in Settings, then run `git -C ~/code/banff status`. Did Settings write into the repo's `shell.toml`? | |
| 15 | Palette | Accent is periwinkle `#B7C1FF`, and there are no theme diagnostics | |

## Paste back

```sh
omniwmctl query shell-widgets
omniwmctl query displays
/usr/bin/log show --last 30m --predicate 'process == "OmniWM" AND category == "shell"' | grep banff
```

Click **Write to log** in each probe popout before running the last command.

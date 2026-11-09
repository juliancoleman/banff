# Banff: qs-style shell for macOS on OmniWM

Status: phase 0 (spike) code is in the repo and has not yet run on the Mac; see `SPIKE.md`. The source shell is `~/code/qs` (52 QML files, 11,637 lines). It carries over as design and theme tokens only; no code is shared. The target is OmniWM v0.8.0 or later with OmniShell, on a single work MacBook. This is personal use, not production. Claims marked `[INFERENCE]` come from reading the docs and have not been tested on a Mac.

## 1. Decisions

| Topic | Decision |
|---|---|
| Runtime | OmniShell style written in Luau. **No Quickshell port to macOS.** |
| Repo | Public GitHub repo `banff`; `style.toml` title "Banff". Installable through **Settings > Styles & Widgets > Get Styles > Add from GitHub…** or symlinked for development |
| Launcher | Raycast. The style ships no launcher and no calculator |
| Multiple displays | The omni cluster (weather, clock/notifications, status) appears on the main display only. Every display shows its own workspace indicator |
| Linux relationship | Design and tokens only. The two shells are maintained independently |
| Weather | Read the host feed `ctx.data.weather`. The style makes no network requests |
| Providers / IPC | None. The style is pure Luau, so it needs no native executable, trust prompts or `omniwmctl` IPC |
| API churn | Accepted risk. Track stable OmniWM releases and fix breakage as it appears |

**Weather source.** macOS has no public weather API for local apps. WeatherKit requires a paid Apple Developer membership and an app signed with the WeatherKit entitlement. Weather.app exposes nothing. The closest thing to "from the system" is OmniWM's own weather feed. It is fetched by the signed OmniWM host and has 24-hour and 7-day data, with location set in `shell.toml [weather]`. Upstream, OmniWM gets that data from Open-Meteo; our style just reads the feed. NWS alerts are dropped because they would need our code to call `api.weather.gov`.

## 2. Feature mapping

| `~/code/qs` feature (PLAN.md §) | OmniShell implementation | Gap / decision |
|---|---|---|
| Bar on any edge, right by default (§5) | The style's own `shell.toml` `[workspaceBar]` sets `position = "right"`, `height = 56`, `fullWidth`, `reserveLayoutSpace`, `transparentBackground`, and turns off item backgrounds. Widgets draw their own islands | A full-width bar at any position except Below Menu Bar switches macOS menu-bar auto-hide on. The spike decides whether that is acceptable or whether to use `fullWidth = false` |
| 4 persistent numbered workspaces, burst, display-only (§6) | The active workspace for a display is the entry in `ctx.data.bar.workspaces` (this display's list) that `ctx.data.workspaces` marks `visible`, falling back to `focused`. The four layers spring between a shared centre and dot/pill positions through `dx`/`dy`/`w`/`h`; the `?` pill uses keyed `appear`/`exit`. Collapse is timed with `omniwm.after` | Configure 4 workspaces named `1`–`4` in OmniWM. Pinning workspaces to displays is undocumented, so the spike checks it |
| Omni cluster on one display (§5) | Render the cluster only when this bar is on the main display. `Bar` has `monitor` and `monitorId` but no main flag, and `system.displays` has no IDs. Candidates: a `monitorId` convention (for example `display:1`), or a widget option naming the cluster display | The spike records `monitorId` per display against `omniwmctl query displays` |
| Clock pill, hover growth, calendar (§7) | `clock`/`date` feeds, `onHover` + spring size, `popout(ctx)` for the 6-week grid (port `MonthGrid`), digit ticker built from clipped digit strips | Bar-slot content is probably clipped to the bar's thickness `[INFERENCE]`. Inward growth may need a thicker bar or an island; the spike checks it |
| Status ring + priority (§8) | `volume, muted, microphone, battery, charging, power, media, wifi, bluetooth`. Ring drawn with `ui.path`/`ui.shape`. Priority logic from `StatusIndicator.qml` moves to `lib/banff/priority.luau` | None |
| Control center (§9) | Popout. Toggles via the `wifi`/`bluetooth` host commands. Audio via `outputs` + `volume`/`microphone`. Brightness via the feed + `brightness`. Hardware monitor via `cpu/memory/gpu/disk/thermal/network`. Power via `session lock|sleep|logout|restart|shutdown` | Wi-Fi scan/join and Bluetooth pairing open System Settings `[INFERENCE]`. **Fans dropped.** The tile-editing transaction is dropped too; order comes from settings |
| Notifications circle + panel (§10) | `ctx.data.notifications` (Full Disk Access); `notifications dismiss/dismiss-all/reply/open`. Water-drop via `appear` + `pulse` | macOS still draws its own banners. The spike checks whether alert style None keeps entries in the feed |
| Weather (§11) | `ctx.data.weather`: `temp, feels, high, low, condition, symbol, place, status, hours[24], days[7]`. Compact widget, panel, and a 24-hour strip from `hours` | Approaching-condition alerts come from `hours[].rain`, which is hourly. "Within 60 minutes" becomes "next hour". No NWS alerts, no automatic location |
| Settings app (§12) | Per-widget `settings.toml` renders native **Options** in OmniWM Settings; values arrive in `ctx.data.settings` | `SettingsWindow.qml` dropped |
| Config + state (§3) | Profile `shell.toml` `profiles.<p>.widgets.<name>`; `omniwm.store` for small durable state | `~/.config/qs/config.json` dropped |
| Shortcuts (`qs-shell ipc call …`) | OmniWM **Keyboard Shortcuts > Toggle <id>** for the panels | None |
| Launcher, calculator, file preview (§1, `Launcher/*`) | Raycast | Dropped from the style |
| Secure prompt, fan helper, `MomentumFlickable`, swaybg, Nix/systemd, GeoClue | Dropped | Use `pinentry-mac` and Touch ID `sudo` (`pam_tid`) |
| Theme (Banff palette, IBM Plex, §4) | `themes/banff.toml` (`[light]`/`[dark]` roles) + `lib/banff/theme.luau` for geometry, motion and non-role colours; IBM Plex in `fonts/` (OFL, ≤16 files) | Tokens copied once from `Common/Theme.qml` (purple accent, as in the code; PLAN.md's amber was never applied) |

## 3. Repo layout

Follows the `styles/` README and TEMPLATE in the OmniWM repo.

```
banff/
  style.toml              # format, name, MAJOR.MINOR.PATCH version, style API, title, summary
  shell.toml              # profile defaults: theme, bar lanes, [workspaceBar]
  README.md               # TEMPLATE sections + development notes
  themes/banff.toml
  fonts/                  # IBM Plex Sans subset (≤16 files), phase 1
  lib/banff/              # pure Luau: theme, motion, digits, ring, priority, calendar, weather-alerts
  widgets/banff-workspaces/  init.luau, settings.toml
  widgets/banff-clock/    init.luau (render + calendar popout), settings.toml
  widgets/banff-status/   init.luau, settings.toml
  widgets/banff-control/  init.luau (popout)
  widgets/banff-notify/   init.luau
  widgets/banff-weather/  init.luau, settings.toml
  scripts/check           # luau-lsp analysis against omniwm.d.luau
  tests/                  # luau CLI unit tests for lib/banff
```

The `banff-` prefix keeps names from colliding with built-ins (`clock`, `workspaces`, …). Widgets load shared code with `require("../lib/banff/<module>")`, the same form the official styles use.

**Type checking.** `scripts/check` runs `luau-lsp analyze` in non-strict mode against `omniwm.d.luau`. That catches syntax errors, unresolved requires and lint findings, but not wrong prop types. Strict mode is unusable against the v0.8.0 definitions: string literals passed to `ui.*` widen to `string`, so every `weight`/`style` value reports a false error. The official styles show the same errors.

Development install: symlink the clone to `~/.config/omniwm/shell/banff` and select it with **Use Style**. OmniShell hot-reloads on save. The repo's `shell.toml` holds the style's defaults; your own changes belong under `profiles.banff` in `~/.config/omniwm/shell/shell.toml`, which wins over it. The spike checks that Settings edits land there rather than in the repo. Add from GitHub only offers an update when the `style.toml` version increases.

## 4. Phases

Every phase ends with a live check on the MacBook.

0. **Spike (about a day).** Code: `widgets/banff-probe` and `widgets/banff-grow` (spike-only) plus the first real widget, `widgets/banff-workspaces`. Checklist and results: `SPIKE.md`. Questions:
   - Does a symlinked profile folder load?
   - Is bar-slot content clipped? Does a 56 pt right-edge bar hold a 48 pt circle?
   - Can hover growth happen in the bar, or does it need an island?
   - Does the burst animate with springs on `dx`/`dy`/`w`/`h`, and does `omniwm.after` called from `render` work?
   - Which workspace does each display's bar report as active?
   - Which field identifies the main display from a bar slot?
   - Does the notifications feed report `ready`, and does it keep entries when banners are set to None?
   - Is the full-width menu-bar auto-hide acceptable?

   Output: go/no-go for each mapping row, then delete the spike-only widgets.
1. **Foundation.** Palette tuning, IBM Plex fonts, final lane layout, README. Finish `banff-workspaces` with a `settings.toml` (collapse delay). Accept: keyboard workspace switches burst and collapse on every display, and tiled windows respect the bar.
2. **Clock + calendar.** Pill, 24-hour default, hover growth, digit ticker, popout grid that resets to the current month. Accept: matches PLAN §7 on the main display only.
3. **Status ring.** Network/battery/audio/mic/media/Bluetooth priority and timers; `priority.luau` unit-tested. Accept: volume keys, unplugging and track changes show the right temporary state and then revert.
4. **Control center.** Grid, toggles, audio, brightness, hardware detail, power. Accept: every tile drives the real system, and unavailable capabilities hide their tiles.
5. **Notifications.** Circle, panel, dismiss/clear, 99+ cap. Accept: `osascript -e 'display notification "x"'` produces the water-drop, and dismissing removes the notification from Notification Center.
6. **Weather.** Compact, panel, 24-hour strip, next-hour rain/dry transition alerts from `hours`; `weather-alerts.luau` unit-tested. Accept: renders from the configured location and makes no requests from the style.
7. **Settings schemas** for every widget. Accept: changing Options in OmniWM Settings updates the live widget.

## 5. Risks

- **Work MacBook management.** OmniWM already has Full Disk Access. MDM could still block OmniShell services through `com.barut.OmniWM` managed preferences (`ShellBlockedServices`); the spike will show this as an `unavailable` or blocked feed.
- **API churn.** Accepted. OmniShell shipped 2026-11-07, and `bar.layout` is still marked unreleased.
- **Clipped bar slots** may push hover growth and the water-drop into islands, which changes PLAN §5/§7 geometry.
- **Duplicate notifications** alongside macOS banners.
- **Coarse weather alerts.** Hourly data replaces minute-level 60-minute prediction.

## 6. Prerequisites

- Apple Silicon MacBook, macOS 26+, OmniWM ≥ 0.8.0, Raycast bound to the launcher hotkey.
- Permissions granted to OmniWM: Full Disk Access (granted; notifications), Accessibility (dismiss/reply), Location (Wi-Fi SSID), Bluetooth, optionally Calendars.
- Weather location set in `shell.toml [weather]`.
- `luau-lsp` for `scripts/check` and the `luau` CLI for unit tests (on Linux: `nix shell nixpkgs#luau nixpkgs#luau-lsp`).

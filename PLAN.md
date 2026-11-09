# Banff: the qs bar for macOS on OmniWM

Status: phases 1–4 (resting housing, calendar, notifications, status temporary states) are done on the Mac; phase 5 (control center) is written and not yet run there. The appearance source is the live qs shell: `~/dotfiles/qs` (QML under `qml/shell`) and `~/.config/qs/config.json`. `~/code/qs` is two months stale and is not a reference. Where the user's stated intent differs from `~/dotfiles/qs`, the user wins, and the difference is recorded here. The two shells share design and tokens only, no code. The target is OmniWM v0.8.0 or later with OmniShell, on a single work MacBook. This is personal use, not production. Claims marked `[INFERENCE]` come from reading docs or source and have not been tested on a Mac.

## 1. Decisions

| Topic | Decision |
|---|---|
| Runtime | OmniShell style written in Luau. **No Quickshell port to macOS.** |
| Goal | The qs bar's appearance: top placement, the docked "notch" housing (weather · clock · status, plus the notification circle) |
| Surface | A Dynamic Island root (`[island] root = "banff"`), not the Workspace Bar. The qs notch hangs from the top edge at screen centre, which is the island's place. Islands get the notch geometry (`ctx.data.island.notch`) and grow panels inside their envelope. The Workspace Bar stays off |
| Displays | `[island] displays = "main"`: the housing appears on the main display only |
| Workspaces | Dropped |
| Repo | Public GitHub repo `banff`; `style.toml` title "Banff". Installable through **Settings > Styles & Widgets > Get Styles > Add from GitHub…** or symlinked for development |
| Launcher | Raycast. The style ships no launcher and no calculator |
| Weather | Read the host feed `ctx.data.weather`. The style makes no network requests |
| Providers / IPC | None. The style is pure Luau |
| API churn | Accepted risk. Track stable OmniWM releases and fix breakage as it appears |

**Weather source.** macOS has no public weather API for local apps. WeatherKit requires a paid Apple Developer membership and an app signed with the WeatherKit entitlement. The closest thing to "from the system" is OmniWM's own feed, fetched by the signed host (from Open-Meteo upstream). NWS alerts are dropped because they would need our code to call `api.weather.gov`.

**Weather settings surface.** OmniWM's Settings shows its weather location editor only for a bar widget or island component named `weather`, `calendar` or `control-center` (`ShellIslandInspectors.swift`, `ShellDesktopWidgetInspector.swift`). So the housing's weather is an island component, `widgets/weather/` (instance `weather` in `shell.toml`), which the root mounts with `ui.component`. Its Enabled switch hides the weather. Lake uses the same component name. The Island tab lists components only for a "composed" island, meaning the root has a `settings.toml` (`ShellDesktopEditor+Island.swift` `islandKind`); without one it shows "This island's content is defined by its style". `widgets/banff/settings.toml` therefore declares the root options.

## 2. Resting appearance (phase 1)

Measured from `~/dotfiles/qs` and a screenshot of the live bar.

| Part | qs source | Banff |
|---|---|---|
| Housing | `ClockWidget.qml`: `Theme.surface` black, flush with the top edge, square top, round bottom, 27 pt tall, 6 pt end pads, 10 pt between parts; `ClockBar.qml` shadow black 0.45, offset 4 | `widgets/banff/init.luau`: a capsule plus a top-half box (`radius` is uniform), shadow on the capsule. With a camera notch the housing wraps it: weather and clock to the left, status to the right, height = notch height |
| Clock | `HorizontalFace.qml`, `DigitTicker.qml`: IBM Plex Sans Medium 13, 12-hour `hh:mm`, no meridiem, leading hour zero in pencil `#AEB5B9`, digits roll 250 ms OutBack | `lib/banff/clock.luau`: fixed-width digit cells with clipped 0–9 strips (the pattern from Lake's `digits.luau`), spring `{0.25, 0.2}`. 12-hour by default; the root's **24-hour clock** option switches it |
| Date on hover | `MonthHeader.qml`: "Mon Nov 9 2026", 10 pt pencil, below the time | Hover grows the housing 18 pt and shows the date under the clock |
| Weather | `WeatherCircle.qml`: 14 pt Lucide glyph, 5 pt gap, whole degrees without a unit; `WeatherService.glyphForCode` | `lib/banff/weather.luau` + `glyphs.luau`: the same Lucide paths and WMO-code mapping, with night variants from `weather.day`, drawn by the `weather` component. Hidden when the feed is off or the component is disabled; "–" when stale |
| Status ring | `StatusIndicator.qml`, `StatusArc.qml`: 27 pt circle, 19 pt ring, 1.9 pt stroke, battery arc filling from 12 o'clock down both sides; paper, charging `#7E9C88` (UPower Charging or PendingCharge), ≤ 20 % `#7A2536`; Wi-Fi glyph with 25/50/75 % bands and 4-point hysteresis | `lib/banff/status.luau`: the same arc geometry as an SVG path. "On AC and not `power.charged`" stands in for PendingCharge, since macOS reports a battery held at its charge limit as not charging `[INFERENCE: what `charged` reports at the limit]`. RSSI mapped to quality as `2·(rssi+100)` %. OmniShell strokes with butt caps, so the Wi-Fi dot is a circle |
| Palette | `Common/Theme.qml` "pens" set (the config's `theme.palette` hex values are not read by the live shell) | `themes/banff.toml` roles + `lib/banff/theme.luau` colours without a role |
| Font | IBM Plex Sans | `fonts/` Regular, Medium, SemiBold (OFL); fonts load after an OmniWM restart |

Not yet ported from rest: the 1.06 hover zoom (scaling about the centre would lift the housing off the top edge), the notification circle (phase 3), and temporary status states (phase 4).

## 3. Later phases

| qs feature | OmniShell implementation | Gap |
|---|---|---|
| Calendar (`Clock/MonthGrid.qml`, `MonthHeader.qml`, `MonthArrow.qml`) | Phase 2, below | None known |
| Notifications circle + panel | Phase 3, below | macOS still draws its own banners |
| Status temporary states (`StatusIndicator.qml`) | Phase 4, below | No wired-network glyph (OmniWM reports Wi-Fi only) |
| Control center | Phase 5, below | No Wi-Fi/Bluetooth power, join or pair; no input-device switching; no fans |
| Weather panel | `ctx.data.weather` `hours`/`days`; next-hour transitions from `hours[].rain` | No NWS alerts, no automatic location |
| Settings | Root `settings.toml`: **24-hour clock** so far, shown in **Settings > Styles & Widgets > Island**; weather on/off is the Weather component's Enabled switch | None |
| Secure prompt, fan helper, launcher, workspaces | Dropped | Raycast; `pinentry-mac`; Touch ID `sudo` |

## 4. Repo layout

```
banff/
  style.toml              # format, name, version, style API, title, summary
  shell.toml              # profile: theme, empty bar lanes, [island]
  README.md
  themes/banff.toml       # pens palette roles
  fonts/                  # IBM Plex Sans + OFL
  lib/banff/              # theme, glyphs, clock, status
  widgets/banff/init.luau # island root
  scripts/check           # luau-lsp analysis against omniwm.d.luau
```

Widgets load shared code with `require("../lib/banff/<module>")`; modules load siblings with `require("./<module>")`, as the official styles do.

**Type checking.** `scripts/check` runs `luau-lsp analyze` in non-strict mode against `omniwm.d.luau`. That catches syntax errors, unresolved requires and lint findings, but not wrong prop types. Strict mode is unusable against the v0.8.0 definitions: string literals passed to `ui.*` widen to `string`, so every `weight`/`style` value reports a false error. The official styles show the same errors.

**Versioning.** Bump `style.toml`'s `version` in every commit. OmniWM manages the installed copy and only offers an update when the version increases. Use the patch number for fixes and docs, and the minor number for each phase.

**Development install.** Install with **Get Styles > Add from GitHub…** (OmniWM manages the installed copy), or symlink a clone to `~/.config/omniwm/shell/banff`. Then choose **Use Style**. OmniShell hot-reloads Luau on save; font changes need an OmniWM restart. User overrides go under `profiles.banff` in `~/.config/omniwm/shell/shell.toml`, which wins over the repo's `shell.toml`.

## 5. Phases

Every phase ends with a live check on the MacBook.

0. **Spike.** Done, results:
   - The symlinked profile loads.
   - The Workspace Bar stayed at the top despite `position = "right"`, and the custom bar widgets (workspaces, hover test) did not render. Neither was investigated: workspaces were dropped and the bar is no longer used.
1. **Resting housing.** Section 2. Done: housing, date on hover, clock roll, ring (green on AC below the charge limit), Wi-Fi glyph, weather once a location is set, and menu-bar clicks through the envelope. Wi-Fi band thresholds are not yet compared against real signal levels.
2. **Calendar.** From the live qs (which differs from `~/code/qs/PLAN.md`: no month/year pickers, and the grid has 4–6 rows rather than a fixed six):
   - A press anywhere on the housing toggles it; opening resets to the current month.
   - The housing grows to fit the calendar plus its 12 pt gutter (`Theme.panelPad`), hanging from the row's centre, or the notch's centre on a notched display.
   - Header: ‹ › arrows (28 × 22, 15 pt, hover white 0.05, press 0.10) around "November 2026" (12 pt Medium), with a hairline rule (`Theme.rule`) below.
   - Grid: S M T W T F S (10 pt pencil), a Sunday-first 24 pt grid with 2 pt gaps and as many rows as the month needs, planner rules between weeks, and adjacent-month days in `statusDim`. Today is marked only by `#8AA5C0` text, with no disc. That departs from `~/dotfiles/qs` `MonthGrid.qml`, which still draws a disc; this is the user's call.
   - Navigation: arrows or Left/Right. Days slide 18 pt in the direction of travel and fade in from 45 % inside a mask, while the rules stay put. Changes in row count resize the housing on its spring.
   - Escape, an outside press or another press on the housing closes it.

   Code: `lib/banff/calendar.luau` (date maths, `grid`, `render`), wired into `widgets/banff/init.luau`. The island envelope grew to 440 × 280 for the tallest month. Done on the Mac: appearance, mouse and keyboard navigation, closing, and click-through on windows under the larger envelope.
3. **Notifications circle + panel.** From `~/dotfiles/qs` `Notifications/NotificationCenter.qml` and `NotificationRow.qml`, fed by `ctx.data.notifications` (OmniWM reads Notification Center's database with Full Disk Access):
   - Circle: a 27 pt slot between weather and the time (contiguous with weather, 10 pt before the time) with a 19 pt `#14181B` disc, a 14 pt Lucide bell, and a 13 pt `#8AA5C0` count pill (9 pt SemiBold `#111922`, capped at 99+) at its top right. For 2.5 s after an arrival the disc shows the sending app's icon. While the panel is open it shows an X and no pill. It appears only while there are notifications.
   - Arrival peek: a new notification shows its row under the time row for 5 s, restarted while hovered, unless a panel is open. An arrival is an id Banff has not seen before. Rows are ordered by when Banff first saw them, newest first, because Notification Center sorts by the sender's own date, which can be in the past. The first snapshot after load keeps Notification Center's order and reports nothing new. Opening the panel asks OmniWM to re-read Notification Center (`notifications refresh`).
   - Panel: a press on the circle toggles it; it replaces the calendar, and a press on the housing replaces it with the calendar. It is 298 pt wide: "Notifications" (13 pt Medium) with the count (11 pt pencil) and a Clear all button (`notifications dismiss-all`), then rows up to 330 pt tall, scrolling past that. It draws the newest 50 rows, with "N more in Notification Center" below; Notification Center can retain 256. Row layouts (text measurement) are cached in `ctx.state` by id. It closes when the last notification goes, on Escape or on an outside press.
   - Row: a 30 pt round app icon, app name (10 pt pencil), title (12 pt Medium), subtitle and body (11 pt pencil, 3 lines, then Show more/Show less in `#8AA5C0`), a 22 pt dismiss X at 55 % opacity (100 % on hover, `notifications dismiss <bundle> <id>`), rules between rows, and hover/press fills. A press dismisses it (when dismissal is possible) and opens its app (`notifications open <bundle>`), like qs's default action closing the notification; in the peek it also ends the peek.
   - Status: failed dismissals and Clear all runs (Accessibility denied, Notification Center unreachable, partial clears, "Close Notification Center to finish") show as a one-line note under the header.
   - Differences from qs, all macOS-imposed: the count is Notification Center's retained list, not live daemon notifications, so items stay until dismissed or cleared; there are no notification actions or urgency (no critical ring); there are no images, so the app icon stands in; Do Not Disturb stays native (macOS Focus, which OmniWM does not expose), so there is no moon.

   Code: `lib/banff/notifications.luau`, wired into `widgets/banff/init.luau` (`state.panel` is now `"calendar"`, `"notifications"` or nil, plus `state.peek`). The island envelope grew to 440 × 440 for the tallest panel.

   On the Mac: the panel opens and closes (X, Escape, clock, outside press). It froze in 0.4.0, which re-measured every row each second; layout caching in 0.4.1 fixed that. Dismissing (×, row click, Clear all) reports "unavailable"; OmniWM's own Notifications widget fails the same way on this Mac, so it is an OmniWM limitation, accepted and not worked around. Phase 3 is otherwise done.
4. **Status temporary states.** From `~/dotfiles/qs` `Status/StatusIndicator.qml`. One glyph slot, held by the highest-priority recent event; lower-priority events are dropped, not queued, and the slot falls back to Wi-Fi when its dwell ends:
   - 4 Bluetooth device connected (a device id becomes connected), 1.6 s. Disconnects are silent. OmniWM lists devices only after macOS grants it Bluetooth access, and reading the feed does not ask, so Banff runs `bluetooth authorize` once (from a timer callback) while access is `notDetermined`.
   - 3 Power connected (`power.source` becomes `ac` and stays 600 ms), Lucide `zap`, 1.6 s, after the startup settle; unplugging clears it at once.
   - 2 Controls: output volume or mute (speaker with near/far waves, or speaker + ×), microphone volume or mute (`mic` / `micOff`), brightness (sun). 1.5 s. The control also takes the ring for its dwell, drawn in paper at that control's level (0 when muted), even when a higher-priority glyph holds the slot.
   - 1 Media play, pause or track change (`media.playing` or bundle/title/artist), play or pause glyph for the resulting state, 1.6 s.
   - No events during the first 3 s while feeds load (qs settles power and Bluetooth the same way; Banff settles everything). A reading missing on either side of a render is not a change. The 0.5.0 version popped the volume glyph on load.
   - The ring fill is always present (hidden when empty) and is not animated. 0.5.0 drew it with SVG arcs, which become different numbers of curves, and its morph showed a white square on every volume change. 0.5.1 used a fixed move plus eight cubic curves, and the square remained. 0.5.2 drops the morph so values snap; if the square persists, the cause is elsewhere and the detail is accepted.
   - A glyph change swaps keyed glyphs: the old one fades and shrinks to 60 % in 150 ms, the new one grows in on the spring. qs's sideways slide for its own next/previous is dropped, because OmniWM does not say who changed the track.
   - At 20 % battery or less (qs `batteryPercentage: "low"`), the percentage sits to the right of the ring (13 pt Medium, 3 pt gap) except while a control holds the ring; the housing widens for it.
   - OmniWM does not watch the brightness keys (`context-data.mdx` "Brightness and system controls"), so the brightness state appears only after Banff's own brightness changes (phase 5). That also avoids qs's AutoBrightness ramp popping the circle.

   Code: `lib/banff/status.luau` (`observe`, `width`, `render`, state in `ctx.state.status`), paths in `lib/banff/glyphs.luau`.
5. **Control center.** From `~/dotfiles/qs` `Control/ControlCenter.qml`, `ToggleTile`, `SliderTile`, `UsageTile`, `ListRow`, `BluetoothPage`, `AudioPage`, `PowerPage`, and `Status/Knob.qml`:
   - A press on the status circle toggles it; while it is open the circle shows an X. It replaces the calendar or notifications panel and closes like them (outside press, Escape); Escape on a page goes back home first.
   - 298 pt wide. Header (27 pt): battery percentage on the left, a power button (24 pt, Lucide `power-off`) on the right. qs's settings gear and Do Not Disturb buttons are dropped: Banff's settings live in OmniWM's Island settings, and Do Not Disturb stays native.
   - Home, 6 pt gaps with rules between groups: Wi-Fi and Bluetooth tiles (half width, divider between), then volume, microphone and brightness sliders (each only when supported), then memory, CPU and disk meters.
   - Tile: 44 pt row, 30 pt knob (filled `#8AA5C0` with dark glyph when on, outlined `stroke` otherwise), title 12 pt Medium, subtitle 11 pt pencil, chevron, hover and press fills. Wi-Fi shows SSID / Not connected / Off and opens Wi-Fi settings. Bluetooth shows the connected device, "N devices", On, Off or "Allow access" and opens the Bluetooth page.
   - Slider: knob (mute for volume and microphone via `volume mute` / `microphone mute`), a 2 pt track with a paper fill and quarter ticks, the value in pencil, and for volume a chevron to the Output page. Dragging goes through a native `ui.slider` laid over the track at 2 % opacity, so the visible track keeps qs's look; it runs `volume set`, `microphone set` or `brightness set`. Brightness changes from here also trigger the status circle's brightness state.
   - Meters: three 30 pt knobs with a level ring and the percentage beneath (`memory`, `cpu`, `disk`).
   - Pages slide in 24 pt from the right with a back button (‹ title):
     - Bluetooth: the tile, then OmniWM's devices with kind glyphs, battery rings, "Connected · 80%" / "Connected" / "Paired" and a check when connected. Rows open Bluetooth settings, since OmniWM cannot connect or disconnect.
     - Output: the volume slider and the output devices (check on the default); a row runs `volume output <id>`.
     - Power: Lock and Sleep act at once; Restart and Shut Down need a second press ("Confirm …", knob turns bordeaux), as in qs, and macOS then asks again. Any action closes the panel.
   - Not ported, because OmniWM has no way to do them: Wi-Fi and Bluetooth power, network list and join, Bluetooth pairing (`context-data.mdx`: power switches use the settings handoffs), the input-device page, the display page (refresh rates), fans, and Ethernet. OmniWM reads CPU and GPU temperatures from the SMC (`ctx.data.thermal`), but no fan speeds; qs's usage tile shows no temperatures, so neither does Banff yet.

   Code: `lib/banff/control.luau`, wired into `widgets/banff/init.luau` (`state.panel = "control"`, `state.controlPage`, `state.armed`).
6. **Weather panel.**
7. **Settings schema.**

## 6. Risks

- **API churn.** Accepted. OmniShell shipped 2026-11-07.
- **Island click-through.** The 440 × 280 envelope passed clicks through to the menu bar and windows. Phase 3 grows it to 440 × 440, so it needs one more check.
- **Notch geometry.** Untested on a notched display. The layout depends on `island.notch` being in envelope coordinates, as the docs state.
- **Duplicate notifications** alongside macOS banners. Notification Center's retained list also counts items the user has already seen as banners, so the count can grow large until cleared.
- **Dismissal depends on Notification Center's own UI.** OmniWM dismisses by finding `com.apple.notificationcenterui` and `com.apple.MenuBarAgent`, pressing the menu bar clock (`com.apple.menuextra.clock`) through Accessibility to open Notification Center, and pressing the item's close control (`ShellNotificationAccessibility.swift`, `ShellNotificationsController+Platform.swift`). It reports `unavailable` when either process is missing, when the clock has no Accessibility element, or when its observer cannot attach. On the work MacBook it fails for OmniWM's own widget too; Banff leaves it to OmniWM.
- **Coarse weather alerts.** Hourly data replaces minute-level prediction.

## 7. Prerequisites

- Apple Silicon MacBook, macOS 26+, OmniWM ≥ 0.8.0, Raycast bound to the launcher hotkey.
- Permissions granted to OmniWM: Full Disk Access (granted), Accessibility (dismiss/reply), Location (Wi-Fi SSID), Bluetooth, optionally Calendars.
- Weather location set on the Island's Weather component.
- `luau-lsp` for `scripts/check` (on Linux: `nix shell nixpkgs#luau-lsp`).

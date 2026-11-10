# Banff

A black notch housing at the top of the screen: weather, a rolling 12-hour clock and a battery/Wi-Fi status ring.

An [OmniShell](https://omniwm.app/omnishell/configuration/islands-components/) style for [OmniWM](https://github.com/OmniNull/OmniWM) ≥ 0.8.0. It brings the look of a personal Linux Quickshell bar to macOS. See [PLAN.md](PLAN.md) for scope and phases.

## Previews

None yet.

## What it changes

Draws a Dynamic Island on the main display. The island is one black housing flush with the top edge: square on top, rounded below, with a soft shadow. Inside, left to right:

- the current weather glyph and whole degrees
- a notification circle with a bell and a count, while Notification Center holds notifications
- the time as 12-hour `hh:mm` with a dimmed leading zero, whose digits roll when they change
- a status circle: a battery ring that fills from the top down both sides (green while charging or plugged in below the charge limit, red at 20 % or below, with the percentage beside it) around a network glyph (Wi-Fi signal, Ethernet, or a slashed Ethernet when offline). For a moment after a change it shows the volume, microphone or brightness level instead, or a glyph for a Bluetooth device connecting, the charger going in, or media playing or pausing

On a display with a camera notch, the housing wraps the notch, with weather, notifications and clock on its left and status on its right. Hovering the housing shows the date. Clicking it opens a month calendar inside the housing: ‹ › or Left/Right change the month, and Escape, a click outside or another click on the housing closes it. Clicking the notification circle opens the notification list instead: click a row to dismiss it and open its app, × to dismiss it, or Clear all. A new notification briefly peeks under the clock. Notifications need OmniWM to have Full Disk Access (to read them) and Accessibility (to dismiss them).

Clicking the status circle opens the control center: battery and a power menu (lock, sleep, restart, shut down), Wi-Fi and Bluetooth tiles (which open their System Settings pages), volume, microphone and brightness sliders, an output-device list, and memory, CPU and disk meters.

Clicking the weather opens the forecast: the place, the temperature with today's condition and range, a 24-hour temperature trace with rain chances and sunrise/sunset, and seven days of ranges on a shared scale. It comes from OmniWM's weather feed, so set a location for the Weather component in **Settings > Styles & Widgets > Island**.

The style puts nothing on the Workspace Bar.

## Controls and commands

- **Settings > Styles & Widgets**: choose **Banff**, then **Use Style**. Open **Island** and turn on **Show Dynamic Island**. Turn the Workspace Bar off.
- Weather location: **Settings > Styles & Widgets > Island**, select the **Weather** component, and set the city or coordinates and units in its location editor. Its **Enabled** switch shows or hides the weather.
- Banff's own options are on the same **Island** page: **Housing** (Notch, flush with the top edge, or Pill, separate capsules floating just below it), **Shadow**, **24-hour clock**, **AM / PM** (12-hour only) and **Battery percentage** (20% and below, or Always).

- IBM Plex Sans ships in `fonts/`; restart OmniWM once after installing so it loads.

## Credits and licences

MIT; see [LICENSE](LICENSE). IBM Plex Sans is © IBM Corp., under the SIL Open Font License 1.1 ([fonts/IBMPlexSans-OFL.txt](fonts/IBMPlexSans-OFL.txt)). The glyphs are [Lucide](https://lucide.dev) paths (ISC).

## Development

```sh
git clone https://github.com/juliancoleman/banff ~/code/banff
ln -s ~/code/banff ~/.config/omniwm/shell/banff
```

OmniShell reloads Luau on save. Check for errors with `omniwmctl query shell-widgets` (needs **Settings > Advanced > Enable IPC**). `scripts/check` runs `luau-lsp` against `omniwm.d.luau` (on Linux: `nix shell nixpkgs#luau-lsp -c ./scripts/check`).

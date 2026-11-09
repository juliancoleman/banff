# Banff

Floating islands on a transparent edge strip: bursting workspaces, a clock pill, and a status ring.

An [OmniShell](https://omniwm.app/omnishell/configuration/bars-drawers/) style for [OmniWM](https://github.com/OmniNull/OmniWM) ≥ 0.8.0. It brings the design of a personal Linux Quickshell setup to macOS. See [PLAN.md](PLAN.md) for scope and phases.

## Previews

None yet.

## What it changes

Puts a 56 pt full-width bar on the right edge with a transparent background, and reserves that space for tiled windows. The bar draws no background of its own; each widget draws its own island. The palette (`themes/banff.toml`) is near-black surfaces, off-white text and a periwinkle accent. One palette serves both light and dark appearance.

Widgets:

| Widget | Status |
|---|---|
| `banff-workspaces` | Four workspaces named `1`–`4`. Collapsed, it shows the numbered active pill; on a switch it bursts into dots and a longer active pill, then collapses. Display-only |
| `banff-grow` | Spike only: hover-growth and overflow test |
| `banff-probe` | Spike only: diagnostics popout |

## Controls and commands

`banff-workspaces` is display-only; switch workspaces with your OmniWM shortcuts. Workspaces must be named `1`, `2`, `3` and `4`. Any other active workspace shows as `?`.

## Credits and licences

MIT; see [LICENSE](LICENSE). Design tokens come from the author's Quickshell configuration.

## Development

```sh
git clone https://github.com/juliancoleman/banff ~/code/banff
ln -s ~/code/banff ~/.config/omniwm/shell/banff
```

Then choose **Settings > Styles & Widgets > Banff > Use Style**, or run `omniwmctl shell profile banff` with IPC enabled. OmniShell reloads widgets on save. Check for widget errors with `omniwmctl query shell-widgets`.

`scripts/check` runs `luau-lsp` against `omniwm.d.luau` (on Linux: `nix shell nixpkgs#luau-lsp -c ./scripts/check`).

# WiFiLab niri integration

WiFiLab uses a normal Quickshell `FloatingWindow`. Under Wayland, niri still decides whether a normal toplevel is tiled or floating, so WiFiLab is matched explicitly by its verified app ID:

```text
io.github.utkarsh56016.wifilab
```

The rule in `wifilab.kdl` provides:

- `open-floating true`
- 1040 x 720 initial geometry
- 24 px rounded geometry
- compositor clipping
- compositor-native background blur/noise/saturation for the translucent QML surface

## Safe validation

Do not edit the active niri config blindly. First identify the active config and niri version:

```bash
niri --version
printf 'NIRI_CONFIG=%s\n' "${NIRI_CONFIG-}"
ls -l ~/.config/niri/config.kdl /etc/niri/config.kdl 2>/dev/null
```

Niri's standard user config is `~/.config/niri/config.kdl` unless `NIRI_CONFIG` overrides it.

Before including the rule, validate the configuration and keep a backup of the active user config. Niri supports:

```bash
niri validate
```

and live reloads configuration after a valid edit.

## Rollback

Remove the `include` line (or copied `window-rule`) for WiFiLab and re-run:

```bash
niri validate
```

No WiFiLab backend or wireless state is changed by this compositor rule.

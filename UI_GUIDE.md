# UI Guide — Clean, Editable, Themeable

The HUD has been refactored into the standard Godot pattern: **structure in
`.tscn`, style in `Theme`, logic in a thin script**.

## File layout

| File | Purpose |
|------|---------|
| `resources/ui/ui_theme.tres` | Every bar colour and style. Edit here to restyle all bars at once. |
| `scenes/ui/hud.tscn` | The HUD layout. Open in the editor to drag widgets around. |
| `scripts/ui/hud.gd` | 150-line controller. Only wires signals + updates values. |
| `scenes/ui/crosshair.tscn` | Reusable crosshair scene. |
| `scripts/ui/crosshair.gd` | Draws itself with `_draw()`, follows player aim. |

## What changed vs. the old HUD

| Old (messy) | New (clean) |
|-------------|-------------|
| ~300 lines of programmatic UI construction | ~150 lines of signal wiring only |
| 20+ inline `StyleBoxFlat` objects in code | All styling in `ui_theme.tres` |
| Hardcoded pixel positions (`Vector2(24, 20)`) | Anchors + offsets in the editor |
| Convoluted `_debug_was_held` flag mid-file | Single `_unhandled_input` handler |
| Reserve ammo appended with string splitting | Formatted once, cleanly |
| `_update_debug_overlay()` runs every frame | Only runs when debug panel is visible |
| Crosshair buried inside HUD script | Separate reusable `Crosshair` scene |

## How to restyle

### Change a bar's colour
Open `resources/ui/ui_theme.tres` → select `hp_fill` (or `stam_fill`, `hung_fill`,
`rel_fill`) → change `bg_color`. Save. Every Health/Stamina/Hunger/Reload bar in
the game updates automatically.

### Change a bar's size
Open `scenes/ui/hud.tscn` → select the bar → change `custom_minimum_size`.
Or select the parent `VBoxContainer` and adjust its `offset_right` for a wider
stack.

### Change a text label's font size / colour
Open `scenes/ui/hud.tscn` → select the label → in the Inspector, expand
`Theme Overrides` → edit `font_color`, `font_size`, `outline_size`.

### Rearrange the HUD
Open `scenes/ui/hud.tscn` → drag the `TopLeft`, `TopRight`, `BottomRight`, or
`BottomCenter` VBox around. The `Root` is anchored to full-rect so its children
follow anchors. Save.

## How to add a new widget

1. Open `scenes/ui/hud.tscn`.
2. Add the widget (e.g. a `Label` or `ProgressBar`) under the appropriate
   `VBoxContainer`.
3. In the Inspector, tick **Access as Unique Name** (the `%` icon) and name it
   e.g. `OxygenBar`.
4. Open `scripts/ui/hud.gd`, add at the top:
   ```gdscript
   @onready var oxygen_bar: ProgressBar = %OxygenBar
```

5. If it needs live data, connect the relevant EventBus signal:

```
EventBus.oxygen_changed.connect(_on_oxygen_changed)
...
func _on_oxygen_changed(current: float, maximum: float) -> void:
    oxygen_bar.max_value = maximum
    oxygen_bar.value = current
```
6. If it's a new bar, add a theme variation in `ui_theme.tres`:

```
OxygenBar/base_type = &"ProgressBar"
OxygenBar/styles/background = SubResource("bar_bg")
OxygenBar/styles/fill = SubResource("oxygen_fill")
```

Then set the new bar's `theme_type_variation = &"OxygenBar"` in the .tscn.

## Debug overlay

Press **F3** (or any action mapped to `debug_toggle` in InputMap) to toggle a
panel in the top-left showing FPS, player position, and zombie count/state.

The panel only refreshes while visible — zero cost when hidden.

## Common gotchas

| Symptom ↕▾ | Fix ↕▾ |
|---|---|
| −HUD doesn't appear | Check that `hud.tscn` is instanced in your main scene (as a child of any node — it's a CanvasLayer, so no parenting requirements). |
| −Bars are grey rectangles | The `Theme` wasn't assigned. Select `Root` in `hud.tscn` and confirm `theme = ui_theme.tres`. |
| −Custom names don't work (`%HealthBar` is null) | In the .tscn, the widget must have **Access as Unique Name** enabled. Tick the `%` icon next to its name. |
| −Debug panel doesn't toggle | Bind `debug_toggle` in Project Settings → Input Map. F3 works out of the box. |
| −Crosshair doesn't follow the player | The player must be in the `player` group and expose `get_aim_screen_position()`. Falls back to raw mouse position otherwise. |
| −Crosshair stays at the raw mouse | That's the fallback when the player isn't found yet. Once the player spawns it tracks properly. |
⚙

## Migrating from the old HUD

The public API is unchanged — no other scripts need updating. `show_message()`
still exists, EventBus signals still do the same thing, and the scene path
`res://scenes/ui/hud.tscn` is the same.


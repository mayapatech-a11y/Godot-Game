# Sigaw sa Negros — Complete project (M0 + M1, rotatable camera + guns)

Standalone **Godot 4.7** project. Open `project.godot` and press F5.

## Requirements

- **Godot 4.7** (stable)

## Open & Run

1. In Godot 4.7, **Import → `project.godot`**.
2. Press **F5**.

## Controls

| Action | Input |
|---|---|
| Move (world-relative) | `W` `A` `S` `D` |
| Sprint | `Shift` |
| Aim | Mouse cursor |
| Fire | Left mouse |
| Orbit camera | Hold middle mouse + drag |
| Zoom | Mouse wheel (6–20 m) |
| Reset camera yaw | `C` |
| Rifle / Pistol / Cycle | `1` / `2` / `Tab` |
| Reload | `R` |
| Toggle cursor | `Esc` |

## Fixes applied in this version

- Added `class_name Gun` to `gun.gd`.
- Changed `_rifle`, `_pistol`, `_current_gun` types to `Gun` in `player.gd`.
- Changed `col.take_damage()` to `col.call("take_damage", ...)` in `player.gd` to satisfy GDScript's strict typing.
- Changed `target.take_damage()` to `target.call("take_damage", ...)` in `zombie.gd`.

## File manifest (all files in this ZIP)

```

project.godot
README.md
scripts/
autoload/bootstrap.gd        # InputMap registration (runs first)
autoload/event_bus.gd        # signal-only hub
autoload/game_state.gd       # day / hour / HP / kills
autoload/time_of_day.gd      # sun + hour/phase signals
main.gd                      # world root, spawns zombies
player/player.gd             # move + orbit camera + weapon swap
player/gun.gd                # reusable gun (ammo, cooldown, recoil, flash)
enemies/zombie.gd            # IDLE → CHASE → ATTACK → STAGGER → DEAD
ui/hud.gd                    # HP / clock / ammo / weapon / messages
ui/crosshair.gd              # custom reticle at cursor
scenes/
main/main.tscn               # world + HUD + crosshair + spawn timer
player/player.tscn           # CharacterBody3D + AimPivot + CameraRig
player/rifle.tscn            # held rifle
player/pistol.tscn           # held pistol
enemies/zombie.tscn

```


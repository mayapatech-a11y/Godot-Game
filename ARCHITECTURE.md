# Architecture — Swappable Characters & Enemies

This document explains how the character system works, how to swap a character's
model and animations **without editing gameplay code**, and how to add new
enemies, mobs, or a different player model later.

## TL;DR — Swapping a model or animation

1. Open `res://resources/characters/<character>.tres`
2. Change the `visual_scene` field to a new scene
3. Save, run. Done.

That's it. Gameplay code (`character_base.gd`, `zombie_ai.gd`, `player.gd`) never
changes when you change a model.

## Directory layout

```

res://
├── resources/
│   └── characters/
│       ├── player_definition.tres     ← data for the player
│       └── zombie_definition.tres     ← data for the zombie
│
├── scenes/
│   ├── character/
│   │   ├── player_visual_01.tscn      ← the player's LOOK (swappable)
│   │   └── zombie_visual_01.tscn      ← the zombie's LOOK (swappable)
│   ├── enemies/
│   │   └── zombie.tscn                ← the zombie's LOGIC body
│   └── ui/
│       └── hud.tscn                   ← the HUD canvas layer
│
└── scripts/
├── character/
│   ├── character_definition.gd    ← Resource: what makes a character unique
│   ├── character_base.gd          ← shared body & state machine
│   ├── character_visual.gd        ← base class for all character "skins"
│   └── placeholder_visual.gd      ← ready-to-run procedural placeholder
├── enemies/
│   ├── zombie_ai.gd               ← zombie-specific behavior
│   └── zombie_spawner.gd          ← keeps a zombie population alive
└── ui/
└── hud.gd                     ← the HUD

```

## The three layers

```

┌───────────────────────┐
│   CharacterDefinition │  ← "What is this character?" (data)
│  (Resources/*.tres)   │
└───────────┬───────────┘
│ referenced by
▼
┌───────────────────────┐
│    CharacterBase      │  ← "How does it move/fight?" (logic)
│   (CharacterBody3D)   │     zombie_ai.gd extends this
└───────────┬───────────┘
│ spawns
▼
┌───────────────────────┐
│   CharacterVisual     │  ← "What does it look like?" (model + anims)
│  (scenes/character/)  │     swap this to change the look
└───────────────────────┘

```

The three layers only talk through the `CharacterDefinition`. That's why you can
swap any one layer without touching the others.

## How to swap a model (step by step)

### Option A — Change the model inside an existing visual scene (fastest)

1. Open `res://scenes/character/zombie_visual_01.tscn` in the editor.
2. Delete the placeholder capsule `MeshInstance3D`.
3. Drag your rigged model (e.g. `zombie.glb`) into the scene as a child.
4. Add an `AnimationPlayer` named **exactly** `AnimationPlayer` and load your
   animation clips into it with the names `idle`, `walk`, `attack`, `death`.
5. Save. Run. Done.

### Option B — Create a brand-new visual scene (cleanest, best for variants)

1. `Scene → New Scene`, root `Node3D`.
2. Add your model as a child.
3. Add an `AnimationPlayer` (auto-named "AnimationPlayer").
4. Add your clips: `idle`, `walk`, `attack`, `death`.
5. Attach a script to the root extending `CharacterVisual`:
   ```gdscript
   extends CharacterVisual
```

6. Save as `res://scenes/character/zombie_visual_02.tscn`.
7. Open `res://resources/characters/zombie_definition.tres` and set
`visual_scene = zombie_visual_02.tscn`.
8. Save. Run. Done.

**No code was touched.**

## How to swap animations only

Animations live entirely inside the visual scene. To change them:

1. Open the character's visual scene (e.g. `zombie_visual_01.tscn`).
2. Select the `AnimationPlayer`.
3. Edit/add/delete animation clips — keep the names `idle`, `walk`, `attack`,
`death`, or the AI won't play them.
4. (Optional) Add extra clips; the AI can request any animation by name via
`_visual.play(&"your_custom_name")`.

## How to add a new enemy type (e.g. "Runner Zombie")

1. Duplicate `res://resources/characters/zombie_definition.tres` as
`runner_zombie_definition.tres`.
2. Open it and change:

- `display_name = "Runner Zombie"`
- `move_speed = 5.0` (faster)
- `max_health = 60` (weaker)
- `attack_damage = 8`
3. (Optional) Give it a new visual: duplicate `zombie_visual_01.tscn`, change the
`base_color` to red, save as `zombie_visual_02.tscn`, then set
`runner_zombie_definition.visual_scene = zombie_visual_02.tscn`.
4. Save. The spawner picks it up automatically if you add it to the spawn list.

**No code was touched.**

## How to add a completely new enemy (Aswang, etc.)

1. `Scene → New Scene`, root `CharacterBody3D`.
2. Attach `zombie_ai.gd` (or a new script extending `CharacterBase`).
3. Assign a new `CharacterDefinition` in the inspector.
4. Save as `res://scenes/enemies/aswang.tscn`.
5. If the AI needs different behavior (flying, night-only, etc.), create
`aswang_ai.gd`:

```
extends CharacterBase
# Override _on_ready_extra, _physics_process, _apply_behavior, ...
```
6. Done.

## Debugging

### 1. Verbose logging

Every `CharacterBase` exposes `debug_verbose: bool`. Toggle it on any zombie
instance (or override the default in the zombie's `.tscn`) and you'll see in the
Output panel:

```
[Zombie] spawned with Standard Zombie [zombie] HP=100 spd=2.5 atk=10 rng=1.8 cd=1.20
[Zombie] WANDER -> CHASE
[Zombie] heard noise at (3.0, 0.0, -8.5)
[Zombie] CHASE -> ATTACK
[Zombie] attacked Player for 10
[Zombie] took 34 from Player (hp=66/100)
[Zombie] DEAD
```

### 2. Floating labels

Set `debug_label = true` on any character and a Label3D will hover above it
showing its name, state, and HP in real time.

### 3. F3 debug overlay

Press **F3** in-game to toggle the debug panel on the HUD. It shows:

- FPS
- Player position
- Number of zombies alive
- Each zombie's current state

### 4. Common gotchas

| Symptom ↕▾ | Fix ↕▾ |
|---|---|
| −Zombie doesn't move | Check `definition.move_speed > 0`; ensure the capsule size and floor collision layers don't trap it. |
| Zombie is a solid grey capsule | The `visual_scene` didn't load. Check the `.tres` path. |
| Zombie plays no animation | The visual scene's root isn't a `CharacterVisual`, or the `AnimationPlayer` isn't named `AnimationPlayer`, or the clip names don't match `idle/walk/attack/death`. |
| Player bullets pass through zombies | The zombie's `collision_layer` (default 3) must be in the gun's `collision_mask`. `player.gd` fires at `(1<<0) | (1<<2)` = world + layer 3. |
| Zombie doesn't hear gunshots | The player must be within `noise_radius` (default 25m). Check `hearing_multiplier` on the zombie. |
⚙

## Migrating the PLAYER to the new system (optional, later)

`player.gd` is deliberately untouched so nothing breaks. When you're ready to
swap the player's model using the same pattern:

1. Add a `Visual` child node to the player's scene.
2. Add this method to `player.gd`:

```
@export var player_definition: CharacterDefinition

func _spawn_visual() -> void:
    if player_definition and player_definition.visual_scene:
        var v = player_definition.visual_scene.instantiate()
        $Visual.add_child(v)
```
3. Call `_spawn_visual()` from `_ready()`.
4. Assign `player_definition.tres` in the inspector.

Now the player's model is swapped by editing `player_definition.tres` — the same
way zombies are.

## Setup checklist (one-time, in your main scene)

- □  
Add the HUD: `CanvasLayer` node with `res://scenes/ui/hud.tscn` (or the
script from `scripts/ui/hud.gd`) as a child of your main scene.
- □  
Add the spawner: `Node3D` with `res://scripts/enemies/zombie_spawner.gd`,
placed near the player. `zombie_scene` auto-loads if left empty.
- □  
Ensure your project has an `EventBus` autoload (the HUD listens to it).
- □  
Ensure your project has an `InputMap` action `debug_toggle` bound to F3.

</BDS:create_file>

<BDS:create_file fileName="README.md">

```markdown
# Zombie Survival — Top-down 3D (Godot 4)

A data-driven zombie survival prototype. Characters, enemies, and mobs are
described by `CharacterDefinition` Resources, so swapping a model or animation
never requires editing gameplay code.

## What's included

| System | Path |
|--------|------|
| Character definition (data) | `scripts/character/character_definition.gd` |
| Character base body + state machine | `scripts/character/character_base.gd` |
| Character visual base class | `scripts/character/character_visual.gd` |
| Procedural placeholder visual | `scripts/character/placeholder_visual.gd` |
| Zombie AI | `scripts/enemies/zombie_ai.gd` |
| Zombie spawner | `scripts/enemies/zombie_spawner.gd` |
| HUD | `scripts/ui/hud.gd` + `scenes/ui/hud.tscn` |
| Zombie definition | `resources/characters/zombie_definition.tres` |
| Player definition (example) | `resources/characters/player_definition.tres` |
| Zombie visual (swappable) | `scenes/character/zombie_visual_01.tscn` |
| Player visual (swappable) | `scenes/character/player_visual_01.tscn` |
| Zombie scene | `scenes/enemies/zombie.tscn` |

## First-run setup

1. **Add the HUD.** In your main scene, add a `CanvasLayer` and attach
   `res://scripts/ui/hud.gd` to it (or instance `scenes/ui/hud.tscn`).
2. **Add the spawner.** In your main scene, add a `Node3D` and attach
   `res://scripts/enemies/zombie_spawner.gd` to it. It auto-loads the zombie
   scene if `zombie_scene` is left empty.
3. **Bind `debug_toggle`** (optional) — add an InputMap action named
   `debug_toggle` bound to `F3` to toggle the HUD's debug overlay.
4. **Run.** Zombies will spawn every few seconds around the player.

## Swapping a model

Edit `resources/characters/zombie_definition.tres` → change `visual_scene` to a
new `.tscn` whose root extends `CharacterVisual` and contains an `AnimationPlayer`
with the clips `idle`, `walk`, `attack`, `death`. Save, run. Done.

See `ARCHITECTURE.md` for the full walkthrough, debug tips, and how to add new
enemy types.

## Debug tips

- Set `debug_verbose = true` on any character to log state changes.
- Set `debug_label = true` for a floating name/state/HP label.
- Press **F3** in-game for the live debug overlay.


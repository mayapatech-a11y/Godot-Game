# CharacterDefinition — the data-driven heart of the character system.
#
# Every character (player, zombie, aswang, future mobs) is described by a
# CharacterDefinition Resource. Swapping a character's model or animation
# means editing its .tres file — no gameplay code changes.
#
# HOW TO USE:
#   1. In the FileSystem dock, right-click → New Resource → CharacterDefinition
#   2. Save it under res://resources/characters/<name>.tres
#   3. Assign it to any CharacterBase scene's `definition` export
#
# See ARCHITECTURE.md for the full "swap a model in 3 clicks" walkthrough.
extends Resource
class_name CharacterDefinition

@export_group("Identity")
## Display name shown in debug overlays and UIs.
@export var display_name: String = "Character"
## Faction string. Player is &"player", zombies are &"zombie".
## The character auto-joins a node group with this name so it can be queried:
##   get_tree().get_nodes_in_group(&"zombie")
@export var faction: StringName = &"neutral"

@export_group("Visuals")
## Scene whose root is (or contains) a CharacterVisual node.
## This is the ONLY thing you swap to change a character's model + animations.
## Contract: the scene root must have a script extending CharacterVisual and
## expose the animations "idle", "walk", "attack", "death" (see CharacterVisual).
@export var visual_scene: PackedScene

@export_group("Stats")
@export var max_health: int = 100
## Horizontal move speed in m/s.
@export var move_speed: float = 3.0
## How fast the visual rotates to face movement direction (higher = snappier).
@export var turn_speed: float = 8.0
@export var attack_damage: int = 10
## Distance at which the character will attack instead of chasing.
@export var attack_range: float = 1.8
## Seconds between attacks (also the "hold attack pose" duration).
@export var attack_cooldown: float = 1.2

@export_group("Physics")
@export var collision_radius: float = 0.4
@export var collision_height: float = 1.8
## Y offset of the capsule's center from the body origin.
@export var collision_offset_y: float = 0.9
## Collision layer the character lives on (1-based). Default = 3 (enemies).
@export_range(1, 32) var collision_layer: int = 3
## Collision layer bitmask the character scans for. Default = world + enemies.
@export_flags_3d_physics var collision_mask: int = 0b101

@export_group("Perception (AI only)")
## How far the character can see. Ignored by non-AI bodies.
@export var vision_range: float = 12.0
## Total vision cone width in degrees (60 = 30° each side).
@export_range(0.0, 360.0) var vision_angle_deg: float = 90.0

func _init() -> void:
	# Fill sane defaults so a fresh "New Resource" is immediately usable.
	pass

## Human-readable summary for debug overlays.
func describe() -> String:
	return "%s [%s] HP=%d spd=%.1f atk=%d rng=%.1f cd=%.2f" % [
		display_name, faction, max_health, move_speed,
		attack_damage, attack_range, attack_cooldown,
	]

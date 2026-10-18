# CharacterBase — the shared body behind every character (player, zombie, mob, ...).
#
# It reads a CharacterDefinition Resource and:
#   * builds the physics capsule from the definition
#   * spawns the swappable visual scene
#   * exposes a tiny state machine (IDLE / WANDER / CHASE / ATTACK / HURT / DEAD)
#   * forwards damage calls, die logic, and state changes
#
# Subclass this to add AI (see zombie_ai.gd) or specific behaviors.
# Subclassing NEVER requires editing this file — override the protected hooks.
#
# DEBUG TIPS:
#   * Set `debug_verbose = true` on any character to log every state transition
#     and damage event in the Output panel.
#   * Press F3 in-game to toggle the on-screen debug overlay (see hud.gd).
extends CharacterBody3D
class_name CharacterBase

enum State { IDLE, WANDER, CHASE, ATTACK, HURT, DEAD }
const STATE_NAMES := ["IDLE", "WANDER", "CHASE", "ATTACK", "HURT", "DEAD"]

@export_group("Definition")
## The data-driven description of this character. Swapping this file swaps
## everything: model, animations, stats, and physics.
@export var definition: CharacterDefinition

@export_group("Debug")
## Print state transitions, damage events, and death to the Output panel.
@export var debug_verbose: bool = false
## Show a floating Label3D above this character with its current state and HP.
@export var debug_label: bool = false

# ---- Runtime state (read-only for subclasses; use the hooks to change) ----
var state: State = State.IDLE
var health: int = 0
var target: Node3D = null

var _visual: CharacterVisual
var _collision: CollisionShape3D
var _visual_holder: Node3D
var _debug_label_node: Label3D
var _state_timer: float = 0.0

func _ready() -> void:
	if definition == null:
		push_error("%s: no CharacterDefinition assigned. Cannot initialize." % name)
		return

	health = definition.max_health
	add_to_group(definition.faction)
	_resolve_nodes()
	_apply_physics_shape()
	_apply_collision_layers()
	_spawn_visual()
	_spawn_debug_label()
	_on_ready_extra()

## Called at the end of _ready(). Override to add AI-specific setup
## (connect signals, initialize wander targets, etc.) without touching super._ready().
func _on_ready_extra() -> void:
	pass

# -------------------------------------------------------------------------
# Setup
# -------------------------------------------------------------------------

func _resolve_nodes() -> void:
	_collision = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = "CollisionShape3D"
		add_child(_collision)

	_visual_holder = get_node_or_null("Visual") as Node3D
	if _visual_holder == null:
		_visual_holder = Node3D.new()
		_visual_holder.name = "Visual"
		add_child(_visual_holder)

func _apply_physics_shape() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = definition.collision_radius
	shape.height = definition.collision_height
	_collision.shape = shape
	_collision.position = Vector3(0.0, definition.collision_offset_y, 0.0)

func _apply_collision_layers() -> void:
	# Godot layers/masks are 1-based bit positions (layer 1 = bit 1).
	collision_layer = 1 << (definition.collision_layer - 1)
	collision_mask = definition.collision_mask

func _spawn_visual() -> void:
	if definition.visual_scene == null:
		push_warning("%s: definition has no visual_scene (placeholder shown)" % name)
		_spawn_fallback_visual()
		return
	var instance := definition.visual_scene.instantiate()
	_visual_holder.add_child(instance)
	if instance is CharacterVisual:
		_visual = instance
	else:
		push_warning(
			"%s: visual_scene root is %s, expected CharacterVisual. Animations disabled."
			% [name, instance.get_class()]
		)

## If no visual_scene is assigned, spawn a plain grey capsule so the character
## is still visible and debuggable.
func _spawn_fallback_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = definition.collision_radius
	capsule.height = definition.collision_height
	mesh_instance.mesh = capsule
	mesh_instance.position.y = definition.collision_offset_y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)
	mesh_instance.material_override = mat
	_visual_holder.add_child(mesh_instance)

func _spawn_debug_label() -> void:
	if not debug_label:
		return
	_debug_label_node = Label3D.new()
	_debug_label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_debug_label_node.no_depth_test = true
	_debug_label_node.font_size = 48
	_debug_label_node.outline_size = 12
	_debug_label_node.position.y = definition.collision_height + 0.4
	add_child(_debug_label_node)
	_update_debug_label()

# -------------------------------------------------------------------------
# State machine
# -------------------------------------------------------------------------

## Change state. Subclasses and the AI call this freely.
## Fires `_on_state_entered` / `_on_state_exited` hooks and logs when verbose.
func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	var old := state
	_on_state_exited(old)
	state = new_state
	_state_timer = 0.0
	if debug_verbose:
		print("[%s] %s -> %s" % [name, STATE_NAMES[old], STATE_NAMES[new_state]])
	_on_state_entered(new_state)
	_update_debug_label()

## Override for per-state entry setup.
func _on_state_entered(_new_state: State) -> void:
	pass

## Override for per-state exit cleanup.
func _on_state_exited(_old_state: State) -> void:
	pass

# -------------------------------------------------------------------------
# Combat
# -------------------------------------------------------------------------

## Standard damage entry point. The player's gun already calls this by name.
func take_damage(amount: int, source: Node = null) -> void:
	if state == State.DEAD:
		return
	health = maxi(health - amount, 0)
	if debug_verbose:
		print("[%s] took %d from %s (hp=%d/%d)" % [
			name, amount, source.name if source else "<none>",
			health, definition.max_health,
		])
	_on_damaged(amount, source)
	_update_debug_label()
	if health <= 0:
		_die()

## Override to react to damage (play a hurt animation, aggro the attacker, ...).
func _on_damaged(_amount: int, _source: Node) -> void:
	pass

func _die() -> void:
	_set_state(State.DEAD)
	if _visual:
		_visual.play(&"death")
	# Remove from combat groups immediately so other AIs stop targeting us.
	remove_from_group(&"combat_target")
	# Stop physics collisions so the corpse doesn't block bullets.
	collision_layer = 0
	collision_mask = 0
	# Freeze in place, then clean up after the death animation plays.
	velocity = Vector3.ZERO
	await get_tree().create_timer(2.0).timeout
	queue_free()

# -------------------------------------------------------------------------
# Visual / debug helpers
# -------------------------------------------------------------------------

func _update_debug_label() -> void:
	if _debug_label_node == null:
		return
	_debug_label_node.text = "%s\n%s\nHP %d/%d" % [
		name, STATE_NAMES[state], health, definition.max_health,
	]

## Convenience so subclasses can request animations without null checks.
func play_anim(anim: StringName) -> void:
	if _visual:
		_visual.play(anim)

func face_toward(point: Vector3, delta: float) -> void:
	if _visual == null:
		return
	var dir := point - global_position
	dir.y = 0.0
	_visual.set_facing(dir, delta)

## True if the definition is hostile toward the given node.
func is_hostile_to(other: Node) -> bool:
	if definition == null or other == null:
		return false
	var other_faction := &""
	if other.has_method(&"get_definition"):
		var d: CharacterDefinition = other.call(&"get_definition")
		if d: other_faction = d.faction
	elif other.is_in_group(&"player"):
		other_faction = &"player"
	# Anything that isn't our own faction is hostile. Refine per-game later.
	return other_faction != &"" and other_faction != definition.faction

## Let other systems read our definition without touching the property.
func get_definition() -> CharacterDefinition:
	return definition

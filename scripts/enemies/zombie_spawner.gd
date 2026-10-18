# ZombieSpawner — keeps a steady population of zombies around the player.
#
# Attach to any Node3D in your main scene. It spawns zombies on a ring around
# the player at a configurable interval, up to `max_alive` at once.
#
# Debug tips:
#   * Set `debug_verbose = true` to log every spawn.
#   * Set `spawn_radius == min_spawn_radius` to spawn at a fixed distance.
extends Node3D

@export_group("Spawn Config")
## Scene to spawn. Defaults to res://scenes/enemies/zombie.tscn.
@export var zombie_scene: PackedScene
@export var max_alive: int = 8
@export var spawn_interval: float = 4.0
@export var min_spawn_radius: float = 10.0
@export var spawn_radius: float = 20.0
## If true, no zombies spawn until the player has moved from origin.
@export var require_player_movement: bool = false

@export_group("Debug")
@export var debug_verbose: bool = false

var _alive: Array[Node] = []
var _spawn_timer: float = 0.0
var _player: Node3D

func _ready() -> void:
	if zombie_scene == null:
		zombie_scene = load("res://scenes/enemies/zombie.tscn") as PackedScene
	if zombie_scene == null:
		push_error("ZombieSpawner: no zombie_scene and default failed to load")
		return
	_spawn_timer = spawn_interval
	_player = get_tree().get_first_node_in_group(&"player") as Node3D

func _process(delta: float) -> void:
	# Clean up dead references.
	_alive = _alive.filter(func(z): return is_instance_valid(z) and not z.is_queued_for_deletion())

	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return

	if _alive.size() >= max_alive:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_one()
		_spawn_timer = spawn_interval

func _spawn_one() -> void:
	if _player == null or zombie_scene == null:
		return
	var angle := randf() * TAU
	var radius := randf_range(min_spawn_radius, spawn_radius)
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * radius
	var spawn_pos := _player.global_position + offset
	# Snap Y to the player's Y so we spawn on the same floor plane.
	spawn_pos.y = _player.global_position.y

	var zombie := zombie_scene.instantiate()
	zombie.global_position = spawn_pos
	get_tree().current_scene.add_child(zombie)
	_alive.append(zombie)

	if debug_verbose:
		print("[Spawner] spawned zombie at %s (%d/%d alive)" % [
			spawn_pos, _alive.size(), max_alive,
		])

## Manually trigger a spawn regardless of the timer (for testing).
func force_spawn() -> void:
	_spawn_one()

## Remove all zombies the spawner currently tracks.
func clear_all() -> void:
	for z in _alive:
		if is_instance_valid(z):
			z.queue_free()
	_alive.clear()

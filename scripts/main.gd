# Main — world root. Bakes navmesh at runtime, spawns zombies/mutants.
extends Node3D

const ZOMBIE_SCENE := preload("res://scenes/enemies/zombie.tscn")
const MUTANT_SCENE := preload("res://scenes/enemies/mutant.tscn")

@export var max_zombies: int = 15
@export var spawn_interval: float = 4.0
@export var spawn_min_dist: float = 15.0
@export var spawn_max_dist: float = 25.0

@onready var sun: DirectionalLight3D = $Sun
@onready var spawn_timer: Timer = $SpawnTimer
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	TimeOfDay.set_sun(sun)
	EventBus.player_died.connect(_on_player_died)
	
	# FAST SETUP: Bake the navmesh dynamically at runtime
	nav_region.bake_navigation_mesh()
	
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()
	EventBus.game_message.emit("Bagong Bukang-Liwayway. Survive.")

func _on_spawn_timer_timeout() -> void:
	if GameState.is_game_over:
		return
	if get_tree().get_nodes_in_group(&"enemies").size() >= max_zombies:
		return
	var players := get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	if player == null:
		return

	var angle := randf() * TAU
	var dist := randf_range(spawn_min_dist, spawn_max_dist)
	var spawn_pos := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * dist
	spawn_pos.y = 0.5

	# 20% chance to spawn a Mutant
	var scene_to_spawn = MUTANT_SCENE if randf() < 0.2 else ZOMBIE_SCENE
	var z := scene_to_spawn.instantiate() as CharacterBody3D
	z.global_position = spawn_pos
	add_child(z)

func _on_player_died() -> void:
	spawn_timer.stop()
	print("[Main] Player died on day %d. Kills: %d" % [GameState.day, GameState.kills])

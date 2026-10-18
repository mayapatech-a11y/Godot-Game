# Zombie — IDLE -> CHASE -> ATTACK -> STAGGER -> DEAD.
# Dynamically creates its own NavigationAgent3D so you don't have to edit the .tscn files.
extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK, STAGGER, DEAD }

@export_group("Stats")
@export var max_hp: float = 100.0
@export var move_speed: float = 2.6
@export var gravity: float = 20.0

@export_group("Combat")
@export var attack_range: float = 1.9
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var aggro_range: float = 25.0

@onready var mesh: MeshInstance3D = $Mesh

var nav_agent: NavigationAgent3D
var hp: float
var state: int = State.IDLE
var target: Node3D

var _attack_timer: float = 0.0
var _stagger_timer: float = 0.0
var _repath_timer: float = 0.0

func _ready() -> void:
	hp = max_hp
	add_to_group(&"enemies")
	
	# FAST SETUP: Dynamically add the NavigationAgent3D in code
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 1.0
	add_child(nav_agent)
	
	# Wait one physics frame for the nav map to sync, then find the player
	await get_tree().physics_frame
	_find_target()

func _find_target() -> void:
	var players := get_tree().get_nodes_in_group(&"player")
	target = players[0] as Node3D if players.size() > 0 else null

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_repath_timer = maxf(_repath_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if target == null or not is_instance_valid(target):
		_find_target()

	match state:
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
			if target and global_position.distance_to(target.global_position) < aggro_range:
				state = State.CHASE

		State.CHASE:
			if target == null:
				state = State.IDLE
			else:
				var dist := global_position.distance_to(target.global_position)
				if dist <= attack_range and _attack_timer <= 0.0:
					state = State.ATTACK
				else:
					# Pathfinding logic
					if _repath_timer <= 0.0:
						nav_agent.target_position = target.global_position
						_repath_timer = 0.2 # update path 5 times a second
					
					if not nav_agent.is_navigation_finished():
						var next_pos := nav_agent.get_next_path_position()
						var dir := (next_pos - global_position).normalized()
						velocity.x = dir.x * move_speed
						velocity.z = dir.z * move_speed
					else:
						# If path is finished but still far, move direct
						var dir := (target.global_position - global_position).normalized()
						velocity.x = dir.x * move_speed
						velocity.z = dir.z * move_speed
					
					var flat := Vector3(target.global_position.x, global_position.y, target.global_position.z)
					if global_position.distance_to(flat) > 0.05:
						look_at(flat, Vector3.UP)

		State.ATTACK:
			velocity.x = 0.0
			velocity.z = 0.0
			_attack_timer = attack_cooldown
			if target and global_position.distance_to(target.global_position) <= attack_range + 0.6:
				if target.has_method(&"take_damage"):
					target.call(&"take_damage", attack_damage)
			state = State.CHASE

		State.STAGGER:
			_stagger_timer -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			if _stagger_timer <= 0.0:
				state = State.CHASE

	move_and_slide()

func take_damage(amount: float, from: Node = null) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	EventBus.enemy_damaged.emit(self, hp)
	if from and from is Node3D and target == null:
		target = from as Node3D
	if hp <= 0.0:
		_die()
	else:
		state = State.STAGGER
		_stagger_timer = 0.22

func _die() -> void:
	state = State.DEAD
	GameState.register_kill()
	EventBus.enemy_died.emit(self, null)
	queue_free()

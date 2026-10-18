# ZombieAI — a CharacterBase subclass that hunts the player.
#
# Perception:
#   * VISION CONE  (angle + raycast line-of-sight)
#   * HEARING      (EventBus.noise_emitted, emitted by the player when shooting)
#
# States: WANDER → CHASE → ATTACK → (DEAD on 0 HP)
#
# Everything is data-driven. To make a "Runner Zombie", duplicate the
# zombie_definition.tres, crank move_speed to 5.0, and assign that definition
# to a new zombie scene (or reuse zombie.tscn and swap the definition in the
# inspector). No code changes.
extends CharacterBase

@export_group("AI Behavior")
## Extra scale on heard noise radius (1.5 = hears 1.5x farther than emitted).
@export var hearing_multiplier: float = 1.5
## How far from spawn the zombie wanders when it has no target.
@export var wander_radius: float = 8.0
@export var wander_interval_min: float = 3.0
@export var wander_interval_max: float = 6.0
## Give up chasing a noise after this many seconds without new sounds.
@export var noise_memory_seconds: float = 8.0

var _wander_target: Vector3
var _wander_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _last_noise_time: float = -999.0
var _last_noise_position: Vector3

func _on_ready_extra() -> void:
	# Listen for gunshots and other noise sources.
	EventBus.noise_emitted.connect(_on_noise_emitted)
	_pick_wander_target()
	if debug_verbose:
		print("[%s] spawned with %s" % [name, definition.describe()])

func _physics_process(delta: float) -> void:
	if definition == null or state == State.DEAD:
		return

	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	_update_perception(delta)
	_update_state_machine(delta)
	_apply_gravity(delta)
	_apply_behavior(delta)
	move_and_slide()

	# Face movement direction (or target when attacking).
	if _visual:
		if state == State.ATTACK and target and is_instance_valid(target):
			face_toward(target.global_position, delta)
		elif velocity.length() > 0.1:
			face_toward(global_position + velocity, delta)

# -------------------------------------------------------------------------
# Perception
# -------------------------------------------------------------------------

func _update_perception(_delta: float) -> void:
	target = null

	# 1. Vision — can we see a hostile player right now?
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player and _can_see(player):
		target = player
		return

	# 2. Hearing — investigate the most recent noise.
	if Time.get_ticks_msec() / 1000.0 - _last_noise_time <= noise_memory_seconds:
		# Fake "target" = the noise location for chase purposes.
		target = null  # we don't attack empty air

func _can_see(node: Node3D) -> bool:
	if definition == null:
		return false
	var to := node.global_position - global_position
	to.y = 0.0
	if to.length() > definition.vision_range:
		return false
	var forward := -global_transform.basis.z
	forward.y = 0.0
	var angle := rad_to_deg(forward.angle_to(to.normalized()))
	if angle > definition.vision_angle_deg * 0.5:
		return false
	return _has_line_of_sight(node)

func _has_line_of_sight(node: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.5
	var dest := node.global_position + Vector3.UP * 1.5
	var q := PhysicsRayQueryParameters3D.create(from, dest)
	q.exclude = [get_rid()]
	q.collision_mask = 1  # world only — don't let enemies block each other's sight
	var hit := space.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == node

func _on_noise_emitted(origin: Vector3, radius: float) -> void:
	if global_position.distance_to(origin) <= radius * hearing_multiplier:
		_last_noise_position = origin
		_last_noise_time = Time.get_ticks_msec() / 1000.0
		if debug_verbose:
			print("[%s] heard noise at %s" % [name, origin])

# -------------------------------------------------------------------------
# State machine
# -------------------------------------------------------------------------

func _update_state_machine(_delta: float) -> void:
	if target and is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		if dist <= definition.attack_range and _attack_cooldown_timer <= 0.0:
			_set_state(State.ATTACK)
		else:
			_set_state(State.CHASE)
	elif _has_recent_noise():
		_set_state(State.CHASE)
	else:
		_set_state(State.WANDER)

func _has_recent_noise() -> bool:
	return Time.get_ticks_msec() / 1000.0 - _last_noise_time <= noise_memory_seconds

# -------------------------------------------------------------------------
# Behavior
# -------------------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

func _apply_behavior(delta: float) -> void:
	match state:
		State.WANDER:
			_do_wander(delta)
		State.CHASE:
			_do_chase(delta)
		State.ATTACK:
			_do_attack(delta)
		_:
			velocity.x = 0.0
			velocity.z = 0.0
			play_anim(&"idle")

func _do_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_target()
		_wander_timer = randf_range(wander_interval_min, wander_interval_max)

	var to := _wander_target - global_position
	to.y = 0.0
	if to.length() < 0.5:
		velocity.x = 0.0
		velocity.z = 0.0
		play_anim(&"idle")
	else:
		var dir := to.normalized()
		var spd := definition.move_speed * 0.3
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		play_anim(&"walk")

func _do_chase(_delta: float) -> void:
	var dest: Vector3
	if target and is_instance_valid(target):
		dest = target.global_position
	elif _has_recent_noise():
		dest = _last_noise_position
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var to := dest - global_position
	to.y = 0.0
	if to.length() > 0.05:
		var dir := to.normalized()
		velocity.x = dir.x * definition.move_speed
		velocity.z = dir.z * definition.move_speed
	play_anim(&"walk")

func _do_attack(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _attack_cooldown_timer > 0.0:
		return  # already mid-swing; keep the pose

	_attack_cooldown_timer = definition.attack_cooldown
	play_anim(&"attack")

	# Apply damage immediately on the swing. For real animation-timed hits,
	# switch to `await _visual.attack_hit_frame` before dealing damage.
	if target and is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		if dist <= definition.attack_range + 0.3:
			target.take_damage(definition.attack_damage, self)
			if debug_verbose:
				print("[%s] attacked %s for %d" % [name, target.name, definition.attack_damage])

func _pick_wander_target() -> void:
	var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	if dir.length_squared() < 0.01:
		dir = Vector3.RIGHT
	dir = dir.normalized()
	_wander_target = global_position + dir * randf_range(2.0, wander_radius)

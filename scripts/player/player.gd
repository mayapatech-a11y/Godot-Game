# Player — top-down 3D CharacterBody3D controller.
extends CharacterBody3D

const RIFLE_SCENE := preload("res://scenes/player/rifle.tscn")
const PISTOL_SCENE := preload("res://scenes/player/pistol.tscn")

@export_group("Movement")
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.5
@export var acceleration: float = 14.0
@export var gravity: float = 20.0

@export_group("Camera")
@export var camera_pitch_degrees: float = 55.0
@export var camera_distance: float = 11.0
@export var camera_min_distance: float = 6.0
@export var camera_max_distance: float = 20.0
@export var orbit_sensitivity: float = 0.005
@export var zoom_step: float = 1.0
@export var show_system_cursor: bool = false

@export_group("Combat")
@export var max_health: int = 100
@export var noise_radius: float = 25.0

@onready var aim_pivot: Node3D = $AimPivot
@onready var gun_mount: Node3D = $AimPivot/GunMount
@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D

var _health: int
var _orbiting: bool = false
var _camera_yaw: float = 0.0
var _rifle: Gun
var _pistol: Gun
var _current_gun: Gun

var _ray_query := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	_health = max_health
	add_to_group(&"player")
	_configure_camera()
	_apply_cursor_mode()
	_spawn_weapons()
	EventBus.player_damaged.emit(_health, max_health)
	EventBus.reserve_ammo_changed.emit(GameState.reserve_ammo)
	EventBus.inventory_changed.emit(GameState.food_count, GameState.water_count, GameState.bandage_count)
	EventBus.stamina_changed.emit(GameState.player_stamina, GameState.player_max_stamina)

func _configure_camera() -> void:
	spring_arm.rotation = Vector3(-deg_to_rad(camera_pitch_degrees), 0.0, 0.0)
	spring_arm.spring_length = camera_distance
	camera_rig.rotation = Vector3.ZERO

func _apply_cursor_mode() -> void:
	Input.mouse_mode = (
		Input.MOUSE_MODE_CONFINED if show_system_cursor
		else Input.MOUSE_MODE_CONFINED_HIDDEN
	)

func _spawn_weapons() -> void:
	_rifle = RIFLE_SCENE.instantiate() as Gun
	_pistol = PISTOL_SCENE.instantiate() as Gun
	gun_mount.add_child(_rifle)
	gun_mount.add_child(_pistol)
	_pistol.visible = false

	for gun in [_rifle, _pistol]:
		gun.fired.connect(_on_gun_fired)
		gun.ammo_changed.connect(_on_gun_ammo_changed)
		gun.reload_started.connect(_on_gun_reload_started)
		gun.reload_finished.connect(_on_gun_reload_finished)

	_equip(_rifle)

func _equip(gun: Gun) -> void:
	if _current_gun == gun:
		return
	for g in [_rifle, _pistol]:
		g.visible = (g == gun)
	_current_gun = gun
	EventBus.weapon_changed.emit(_current_gun.display_name)
	EventBus.ammo_changed.emit(_current_gun.ammo, _current_gun.magazine_size)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_orbiting = event.pressed
				return
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					camera_distance = maxf(camera_distance - zoom_step, camera_min_distance)
					spring_arm.spring_length = camera_distance
					return
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					camera_distance = minf(camera_distance + zoom_step, camera_max_distance)
					spring_arm.spring_length = camera_distance
					return
	elif event is InputEventMouseMotion and _orbiting:
		_camera_yaw -= event.relative.x * orbit_sensitivity
		camera_rig.rotation.y = _camera_yaw
		return

	if event.is_action_pressed(&"pause"):
		show_system_cursor = not show_system_cursor
		_apply_cursor_mode()
	elif event.is_action_pressed(&"reset_camera"):
		_camera_yaw = 0.0
		camera_rig.rotation.y = 0.0
	elif event.is_action_pressed(&"weapon_1"):
		_equip(_rifle)
	elif event.is_action_pressed(&"weapon_2"):
		_equip(_pistol)
	elif event.is_action_pressed(&"swap_weapon"):
		_equip(_pistol if _current_gun == _rifle else _rifle)
	elif event.is_action_pressed(&"reload") and _current_gun:
		_current_gun.reload()
	elif event.is_action_pressed(&"use_item"):
		_consume_food()
	elif event.is_action_pressed(&"use_bandage"):
		_use_bandage()

func _physics_process(delta: float) -> void:
	if GameState.is_game_over:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var cam_basis := camera_rig.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	var dir := right * input.x + forward * -input.y
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.ZERO

	var target_speed := walk_speed
	if Input.is_action_pressed(&"sprint") and dir.length() > 0.0 and GameState.player_stamina > 0.0:
		target_speed = sprint_speed
		GameState.player_stamina = maxf(GameState.player_stamina - (delta * 20.0), 0.0)
	else:
		GameState.player_stamina = minf(GameState.player_stamina + (delta * 15.0), GameState.player_max_stamina)
	EventBus.stamina_changed.emit(GameState.player_stamina, GameState.player_max_stamina)

	var target_vel := dir * target_speed
	var accel := acceleration * maxf(target_speed, 1.0)
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)

	_update_aim()

	if Input.is_action_pressed(&"fire") and _current_gun:
		_current_gun.fire()

	move_and_slide()

func _update_aim() -> void:
	var mouse := get_viewport().get_mouse_position()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var ray_from := cam.project_ray_origin(mouse)
	var ray_dir := cam.project_ray_normal(mouse)
	var ground_hit = Plane(Vector3.UP, 0.0).intersects_ray(ray_from, ray_dir)
	if ground_hit == null:
		return

	var flat_target := Vector3(ground_hit.x, aim_pivot.global_position.y, ground_hit.z)
	if aim_pivot.global_position.distance_to(flat_target) > 0.05:
		aim_pivot.look_at(flat_target, Vector3.UP)
		aim_pivot.rotation.x = 0.0
		aim_pivot.rotation.z = 0.0

func _on_gun_fired(from: Vector3, dir: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var to := from + dir * _current_gun.range_meters

	_ray_query.from = from
	_ray_query.to = to
	_ray_query.exclude = [get_rid()]
	_ray_query.collision_mask = (1 << 0) | (1 << 2)
	var hit := space.intersect_ray(_ray_query)

	EventBus.noise_emitted.emit(global_position, noise_radius)

	var hit_point: Vector3
	if hit.has("collider"):
		hit_point = hit["position"]
		var hit_normal: Vector3 = hit["normal"]
		_spawn_bullet_mark(hit_point, hit_normal)

		var col: Object = hit["collider"]
		if col and col.has_method(&"take_damage"):
			col.call(&"take_damage", _current_gun.damage, self)
	else:
		hit_point = to

	_spawn_bullet_trace(from, hit_point)

func get_aim_screen_position() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _current_gun == null:
		return get_viewport().get_mouse_position()

	var muzzle := gun_mount.global_position
	var aim_dir := -aim_pivot.global_transform.basis.z
	var far_point := muzzle + aim_dir * 50.0
	return cam.unproject_position(far_point)

func _consume_food() -> void:
	if GameState.food_count > 0 and GameState.player_hunger < GameState.player_max_hunger:
		GameState.food_count -= 1
		GameState.player_hunger = minf(GameState.player_hunger + 40.0, GameState.player_max_hunger)
		EventBus.hunger_changed.emit(GameState.player_hunger, GameState.player_max_hunger)
		EventBus.inventory_changed.emit(GameState.food_count, GameState.water_count, GameState.bandage_count)
		EventBus.game_message.emit("Ate Canned Sardines. +40 Hunger.")
	else:
		EventBus.game_message.emit("No food to eat (or not hungry).")

func _use_bandage() -> void:
	if GameState.bandage_count > 0 and GameState.is_bleeding:
		GameState.bandage_count -= 1
		GameState.is_bleeding = false
		EventBus.injury_changed.emit(false)
		EventBus.inventory_changed.emit(GameState.food_count, GameState.water_count, GameState.bandage_count)
		EventBus.game_message.emit("Bandaged wound. Bleeding stopped.")
	else:
		EventBus.game_message.emit("No bandage needed (or out of bandages).")

func _on_gun_ammo_changed(current: int, maximum: int) -> void:
	EventBus.ammo_changed.emit(current, maximum)

func _on_gun_reload_started(duration: float) -> void:
	EventBus.reload_started.emit(duration)

func _on_gun_reload_finished() -> void:
	EventBus.reload_finished.emit()

# FIX: Prefix `source` with an underscore to tell Godot it's intentionally unused.
func take_damage(amount: int, _source: Node = null) -> void:
	if GameState.is_game_over:
		return
	_health = maxi(_health - amount, 0)
	GameState.player_health = _health
	GameState.damage_player(amount)

	if not GameState.is_bleeding and randf() < 0.3:
		GameState.is_bleeding = true
		EventBus.injury_changed.emit(true)
		
	if _health <= 0:
		GameState.is_game_over = true
		EventBus.player_died.emit()

func _spawn_bullet_trace(start: Vector3, end: Vector3) -> void:
	var trace = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.02, 0.02, 1.0)
	trace.mesh = mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.3, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trace.material_override = mat
	trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	get_tree().current_scene.add_child(trace)

	var dist = start.distance_to(end)
	trace.global_position = start + (end - start) * 0.5
	if dist > 0.01:
		trace.look_at(end, Vector3.UP)
		trace.scale = Vector3(1, 1, dist)

	var tw = create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.08)
	tw.tween_callback(trace.queue_free)

func _spawn_bullet_mark(pos: Vector3, normal: Vector3) -> void:
	var mark = MeshInstance3D.new()
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.15, 0.15)
	mark.mesh = mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = mat

	get_tree().current_scene.add_child(mark)

	mark.global_position = pos + normal * 0.02
	mark.look_at(pos + normal, Vector3.UP)

	var tw = create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(mark, "scale", Vector3.ZERO, 0.3)
	tw.tween_callback(mark.queue_free)

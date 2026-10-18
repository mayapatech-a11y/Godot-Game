# Gun — held weapon with magazine, reserve ammo, cooldown, reload, and recoil.
extends Node3D
class_name Gun

signal fired(from: Vector3, dir: Vector3)
signal ammo_changed(current: int, maximum: int)
signal reload_started(duration: float)
signal reload_finished

@export_group("Identity")
@export var display_name: String = "Rifle"

@export_group("Stats")
@export var damage: float = 25.0
@export var fire_rate: float = 0.15
@export var range_meters: float = 60.0
@export var magazine_size: int = 30
@export var reload_time: float = 1.5

@export_group("Feel")
@export var recoil_distance: float = 0.05
@export var flash_duration: float = 0.045

@onready var muzzle: Marker3D = $Muzzle
@onready var muzzle_flash: MeshInstance3D = $MuzzleFlash
@onready var muzzle_light: OmniLight3D = $MuzzleLight

var ammo: int
var is_reloading: bool = false
var _cooldown: float = 0.0
var _rest_position: Vector3

func _ready() -> void:
	ammo = magazine_size
	_rest_position = position
	if muzzle_flash:
		muzzle_flash.visible = false
	if muzzle_light:
		muzzle_light.visible = false
	add_to_group(&"weapons")

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

func can_fire() -> bool:
	return (not is_reloading) and _cooldown <= 0.0 and ammo > 0 and is_visible_in_tree()

func fire() -> void:
	if not can_fire():
		return
	_cooldown = fire_rate
	ammo -= 1
	ammo_changed.emit(ammo, magazine_size)

	var from := muzzle.global_position if muzzle else global_position
	var dir := -muzzle.global_transform.basis.z if muzzle else -global_transform.basis.z
	fired.emit(from, dir)

	_play_recoil()
	_flash_muzzle()

	if ammo == 0:
		reload()

func reload() -> void:
	if is_reloading or ammo == magazine_size or GameState.reserve_ammo <= 0:
		return
	is_reloading = true
	reload_started.emit(reload_time)
	await get_tree().create_timer(reload_time).timeout
	if not is_instance_valid(self):
		return

	# Pull from reserve ammo
	var needed = magazine_size - ammo
	var taken = mini(needed, GameState.reserve_ammo)
	GameState.reserve_ammo -= taken
	ammo += taken

	is_reloading = false
	ammo_changed.emit(ammo, magazine_size)
	EventBus.reserve_ammo_changed.emit(GameState.reserve_ammo)
	reload_finished.emit()

func _play_recoil() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:z", _rest_position.z + recoil_distance, 0.04)
	tw.tween_property(self, "position:z", _rest_position.z, 0.12)

func _flash_muzzle() -> void:
	if muzzle_flash:
		muzzle_flash.visible = true
	if muzzle_light:
		muzzle_light.visible = true
	await get_tree().create_timer(flash_duration).timeout
	if is_instance_valid(self):
		if muzzle_flash:
			muzzle_flash.visible = false
		if muzzle_light:
			muzzle_light.visible = false

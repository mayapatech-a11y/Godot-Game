# Pickup — floating, rotating item that gives ammo, food, water, or bandages.
extends Area3D

enum PickupType { AMMO, FOOD, WATER, BANDAGE }

@export var type: PickupType = PickupType.AMMO

@onready var mesh: MeshInstance3D = $Mesh
@onready var light: OmniLight3D = $OmniLight3D

var _time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_color()

func _process(delta: float) -> void:
	_time += delta
	mesh.position.y = sin(_time * 3.0) * 0.1
	mesh.rotation.y += delta * 2.0

func _apply_color() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match type:
		PickupType.AMMO:
			mat.albedo_color = Color(1.0, 0.9, 0.2) # Yellow
			light.light_color = Color(1.0, 0.9, 0.2)
		PickupType.FOOD:
			mat.albedo_color = Color(1.0, 0.3, 0.3) # Red
			light.light_color = Color(1.0, 0.3, 0.3)
		PickupType.WATER:
			mat.albedo_color = Color(0.3, 0.6, 1.0) # Blue
			light.light_color = Color(0.3, 0.6, 1.0)
		PickupType.BANDAGE:
			mat.albedo_color = Color(0.3, 1.0, 0.3) # Green
			light.light_color = Color(0.3, 1.0, 0.3)
	mesh.material_override = mat

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		match type:
			PickupType.AMMO:
				GameState.add_ammo(30)
			PickupType.FOOD:
				GameState.add_food()
			PickupType.WATER:
				GameState.add_water()
			PickupType.BANDAGE:
				GameState.add_bandage()
		queue_free()

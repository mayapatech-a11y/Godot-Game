# PlaceholderVisual — a fully working CharacterVisual you can run out of the box.
#
# It procedurally builds:
#   * a coloured capsule mesh (recolour via `base_color`)
#   * an AnimationPlayer with idle / walk / attack / death animations
#
# Later, replace it entirely:
#   1. Create a new scene (e.g. `zombie_visual_02.tscn`)
#   2. Add your rigged model + AnimationPlayer + script extending CharacterVisual
#   3. Point the character's CharacterDefinition at the new visual scene
# No gameplay code changes required.
extends CharacterVisual
class_name PlaceholderVisual

@export_group("Placeholder Look")
@export var base_color: Color = Color(0.4, 0.6, 0.4)
@export var body_height: float = 1.8
@export var body_radius: float = 0.4

## Idle bob amplitude in metres (0 disables it).
@export_range(0.0, 0.5) var idle_bob: float = 0.04
## Walk bob amplitude in metres (0 disables it).
@export_range(0.0, 0.5) var walk_bob: float = 0.10

var _mesh: MeshInstance3D
var _anim_player: AnimationPlayer
var _bob_base_y: float

func _ready() -> void:
	_setup_mesh()
	_setup_animation_player()
	# Must call super LAST so super._ready() finds the AnimationPlayer we created.
	super._ready()

func _setup_mesh() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	var capsule := CapsuleMesh.new()
	capsule.radius = body_radius
	capsule.height = body_height
	_mesh.mesh = capsule
	_bob_base_y = body_height * 0.5
	_mesh.position.y = _bob_base_y

	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.85
	_mesh.material_override = mat
	add_child(_mesh)

func _setup_animation_player() -> void:
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	add_child(_anim_player)

	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _make_bob_anim("idle", 1.2, idle_bob))
	lib.add_animation(&"walk", _make_bob_anim("walk", 0.6, walk_bob))
	lib.add_animation(&"attack", _make_attack_anim())
	lib.add_animation(&"death", _make_death_anim())
	_anim_player.add_animation_library(&"", lib)
	_anim_player.play(&"idle")

# -------------------------------------------------------------------------
# Animation builders (procedural — no keyframe data in .tscn)
# -------------------------------------------------------------------------

func _make_bob_anim(_name: StringName, duration: float, amplitude: float) -> Animation:
	var anim := Animation.new()
	anim.length = duration
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("Mesh:position:y"))
	anim.track_insert_key(track, 0.0, _bob_base_y)
	anim.track_insert_key(track, duration * 0.5, _bob_base_y + amplitude)
	anim.track_insert_key(track, duration, _bob_base_y)
	# Add a little sway so idle vs walk are visibly different.
	var sway := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(sway, NodePath("Mesh:rotation:z"))
	anim.track_insert_key(sway, 0.0, 0.0)
	anim.track_insert_key(sway, duration * 0.5, amplitude * 0.5)
	anim.track_insert_key(sway, duration, 0.0)
	return anim

func _make_attack_anim() -> Animation:
	var anim := Animation.new()
	anim.length = 0.45
	anim.loop_mode = Animation.LOOP_NONE

	# Forward lunge.
	var z_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(z_track, NodePath("Mesh:position:z"))
	anim.track_insert_key(z_track, 0.0, 0.0)
	anim.track_insert_key(z_track, 0.15, -0.35)
	anim.track_insert_key(z_track, 0.45, 0.0)

	# Add a method track so attacks can fire `attack_hit_frame` at the peak.
	var method_track := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(method_track, NodePath("."))
	anim.track_insert_key(method_track, 0.15, {
		"method": &"_on_attack_hit_frame",
		"args": [],
	})
	return anim

func _make_death_anim() -> Animation:
	var anim := Animation.new()
	anim.length = 0.8
	anim.loop_mode = Animation.LOOP_NONE

	# Fall forward onto the ground.
	var rot_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot_track, NodePath("Mesh:rotation:x"))
	anim.track_insert_key(rot_track, 0.0, 0.0)
	anim.track_insert_key(rot_track, 0.8, PI * 0.5)

	var y_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(y_track, NodePath("Mesh:position:y"))
	anim.track_insert_key(y_track, 0.0, _bob_base_y)
	anim.track_insert_key(y_track, 0.8, body_radius)
	return anim

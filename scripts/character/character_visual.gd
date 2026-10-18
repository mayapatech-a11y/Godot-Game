# CharacterVisual — base class for every character's visual "skin".
#
# A visual scene is a self-contained Node3D that knows how to:
#   * play a named animation (idle / walk / attack / death / custom)
#   * rotate to face a direction
#   * emit an `attack_hit_frame` signal at the moment damage should be applied
#
# The gameplay code (CharacterBase) NEVER touches a mesh or AnimationPlayer
# directly — it only calls `play()` and listens for signals. That's why you
# can swap a placeholder capsule for a rigged 3D model without editing AI code.
#
# CONTRACT for every visual scene:
#   * Root script extends CharacterVisual (directly or via a subclass)
#   * Root has a child AnimationPlayer named "AnimationPlayer"
#   * The AnimationPlayer contains at least these animations:
#         "idle"   (looping)
#         "walk"   (looping)
#         "attack" (one-shot; if using call tracks, call _on_attack_hit_frame)
#         "death"  (one-shot)
#   * Optional: any other animations the AI may request.
#
# See placeholder_visual.gd for a ready-to-run template.
extends Node3D
class_name CharacterVisual

## Emitted when a non-looping animation (attack, death, hurt) finishes.
signal animation_finished(anim_name: StringName)

## Emitted at the exact moment an attack should deal damage.
## AI code can either:
##   * apply damage immediately when starting the attack, OR
##   * `await visual.attack_hit_frame` for perfectly timed hits.
signal attack_hit_frame

@onready var _anim: AnimationPlayer = get_node_or_null("AnimationPlayer")

func _ready() -> void:
	# Late-resolve in case a subclass created the AnimationPlayer in its own
	# _ready() after this super call... (subclasses should call super LAST).
	if _anim == null:
		_anim = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _anim:
		_anim.animation_finished.connect(_on_internal_animation_finished)

func _on_internal_animation_finished(anim_name: StringName) -> void:
	animation_finished.emit(anim_name)

## Play the named animation. No-op if the clip doesn't exist (safety for
## placeholder/partial visual scenes).
func play(anim: StringName) -> void:
	if _anim == null:
		return
	if not _anim.has_animation(anim):
		# Uncomment when debugging missing clips:
		# push_warning("CharacterVisual: no animation '%s' in %s" % [anim, name])
		return
	if _anim.current_animation != anim:
		_anim.play(anim)

## Force-restart the named animation even if it's already the current one.
## Use for one-shot actions like attack that should re-trigger on each swing.
func restart(anim: StringName) -> void:
	if _anim == null:
		return
	if not _anim.has_animation(anim):
		return
	_anim.stop()
	_anim.play(anim)

## Rotate the visual to face `dir` (horizontal only).
## `delta` is used for smoothing; pass 1.0 for an instant snap.
func set_facing(dir: Vector3, delta: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-flat.x, -flat.z)  # -Z is forward in Godot
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(10.0 * delta, 0.0, 1.0))

## Called by animation method/call tracks. Do not call manually.
## A "Method Track" on the attack animation whose method path is "." and
## method name is "_on_attack_hit_frame" will trigger this at the right moment.
func _on_attack_hit_frame() -> void:
	attack_hit_frame.emit()

## Utility for debug overlays: return every animation name this visual exposes.
func list_animations() -> Array[StringName]:
	var out: Array[StringName] = []
	if _anim == null:
		return out
	for lib_name in _anim.get_animation_library_list():
		var lib := _anim.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			out.append(anim_name)
	return out

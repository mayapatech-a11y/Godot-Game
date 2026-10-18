# TimeOfDay — drives the sun and reports hour/phase changes.
extends Node

const MINUTES_PER_REAL_SECOND := 1.0
const MINUTES_PER_DAY := 24.0 * 60.0

var total_minutes: float = 6.0 * 60.0   # start at 6:00 AM
var sun: DirectionalLight3D

var _last_hour: int = 6
var _last_phase: int = 1

func _process(delta: float) -> void:
	total_minutes += delta * MINUTES_PER_REAL_SECOND
	if total_minutes >= MINUTES_PER_DAY:
		total_minutes -= MINUTES_PER_DAY
		GameState.day += 1
	_update_clock()
	_update_sun()

func _update_clock() -> void:
	var hour := int(total_minutes / 60.0) % 24
	if hour != _last_hour:
		_last_hour = hour
		GameState.hour = hour
		EventBus.hour_changed.emit(hour)
	var phase := _phase_for_hour(hour)
	if phase != _last_phase:
		_last_phase = phase
		EventBus.day_phase_changed.emit(phase)

func _phase_for_hour(hour: int) -> int:
	if hour >= 5 and hour < 7:
		return 0    # dawn
	if hour >= 7 and hour < 17:
		return 1    # day
	if hour >= 17 and hour < 19:
		return 2    # dusk
	return 3        # night

func _update_sun() -> void:
	if sun == null:
		return
	var day_progress := fmod(total_minutes / MINUTES_PER_DAY, 1.0)
	var sun_height := sin((day_progress - 0.25) * TAU)
	sun.rotation_degrees.x = -rad_to_deg(asin(clampf(sun_height, -1.0, 1.0)))
	sun.rotation_degrees.y = -30.0
	sun.light_energy = clampf(sun_height * 1.5, 0.05, 1.2)

func set_sun(node: DirectionalLight3D) -> void:
	sun = node

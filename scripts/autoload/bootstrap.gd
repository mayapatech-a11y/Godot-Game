# Bootstrap autoload — registered FIRST so InputMap actions exist.
extends Node

func _init() -> void:
	_register_movement()
	_register_actions()
	_register_mouse()
	_register_weapon()
	print("[Bootstrap] Input actions registered.")

func _register_movement() -> void:
	_add_key(&"move_forward", KEY_W)
	_add_key(&"move_back", KEY_S)
	_add_key(&"move_left", KEY_A)
	_add_key(&"move_right", KEY_D)
	_add_key(&"sprint", KEY_SHIFT)

func _register_actions() -> void:
	_add_key(&"reload", KEY_R)
	_add_key(&"interact", KEY_E)
	_add_key(&"use_item", KEY_F) # Consume food
	_add_key(&"use_bandage", KEY_G) # NEW: Heal bleeding
	_add_key(&"pause", KEY_ESCAPE)
	_add_key(&"reset_camera", KEY_C)
	_add_key(&"swap_weapon", KEY_TAB)

func _register_mouse() -> void:
	_add_mouse(&"fire", MOUSE_BUTTON_LEFT)
	_add_mouse(&"orbit", MOUSE_BUTTON_MIDDLE)

func _register_weapon() -> void:
	_add_key(&"weapon_1", KEY_1)
	_add_key(&"weapon_2", KEY_2)

func _add_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.keycode == keycode:
			return
	var e := InputEventKey.new()
	e.keycode = keycode
	InputMap.action_add_event(action, e)

func _add_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton and ev.button_index == button:
			return
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)

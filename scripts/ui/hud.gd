# HUD — a self-building heads-up display for the zombie survival prototype.
#
# Attach this script to a CanvasLayer in your main scene. It connects to the
# EventBus signals emitted by player.gd / Gun / GameState and displays:
#   * health bar (top-left)
#   * stamina bar (below health)
#   * hunger bar (top-right)
#   * bleeding warning (top-right)
#   * weapon name + ammo + reserve (bottom-right)
#   * reload progress bar (bottom-center)
#   * crosshair (follows the player's aim)
#   * fading toast messages (bottom-center)
#   * F3 debug overlay (fps, entity counts, player state)
#
# Every widget is exposed via a small API so you can restyle or reposition
# later without touching the signal wiring.
extends CanvasLayer
class_name HUD

# ---- Public widget refs (edit these in your own HUD scene later) ----
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var hunger_bar: ProgressBar
var bleeding_label: Label
var ammo_label: Label
var weapon_label: Label
var reload_bar: ProgressBar
var message_label: Label
var crosshair: Control
var debug_panel: PanelContainer
var debug_text: Label

# ---- Internal ----
var _message_timer: float = 0.0
var _debug_visible: bool = false
var _player: Node
var _root: Control
var _reload_start_time: float = -1.0
var _reload_duration: float = 0.0

func _ready() -> void:
	layer = 100
	_build_ui()
	_connect_signals()
	_player = get_tree().get_first_node_in_group(&"player")

# -------------------------------------------------------------------------
# UI construction (programmatic — replace with .tscn later if you want)
# -------------------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- Top-left: health + stamina stack ---
	var left_box := VBoxContainer.new()
	left_box.position = Vector2(24, 20)
	left_box.custom_minimum_size = Vector2(280, 0)
	left_box.add_theme_constant_override("separation", 6)
	_root.add_child(left_box)

	health_bar = _make_bar("HP", Color(0.85, 0.22, 0.22), 220, 22)
	health_bar.max_value = 100
	left_box.add_child(health_bar)

	stamina_bar = _make_bar("Stamina", Color(0.90, 0.80, 0.25), 180, 12)
	stamina_bar.max_value = 100
	left_box.add_child(stamina_bar)

	# --- Top-right: hunger + bleeding ---
	var right_box := VBoxContainer.new()
	right_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right_box.position = Vector2(-260, 20)
	right_box.custom_minimum_size = Vector2(236, 0)
	right_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	right_box.add_theme_constant_override("separation", 6)
	_root.add_child(right_box)

	hunger_bar = _make_bar("Hunger", Color(0.75, 0.55, 0.30), 220, 14)
	hunger_bar.max_value = 100
	right_box.add_child(hunger_bar)

	bleeding_label = _make_label("⚠ BLEEDING — use a bandage (B)", 16, Color(0.95, 0.35, 0.35))
	bleeding_label.visible = false
	right_box.add_child(bleeding_label)

	# --- Bottom-right: weapon + ammo ---
	var weapon_box := VBoxContainer.new()
	weapon_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_box.position = Vector2(-260, -96)
	weapon_box.custom_minimum_size = Vector2(236, 0)
	weapon_box.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(weapon_box)

	weapon_label = _make_label("—", 18, Color(0.9, 0.9, 0.9))
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_box.add_child(weapon_label)

	ammo_label = _make_label("— / —", 32, Color(0.95, 0.95, 0.95))
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_box.add_child(ammo_label)

	# --- Bottom-center: reload + toast ---
	var bottom_center := VBoxContainer.new()
	bottom_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_center.position = Vector2(0, -100)
	bottom_center.custom_minimum_size = Vector2(360, 0)
	bottom_center.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(bottom_center)

	reload_bar = _make_bar("Reloading", Color(0.4, 0.6, 1.0), 280, 14)
	reload_bar.visible = false
	bottom_center.add_child(reload_bar)

	message_label = _make_label("", 16, Color(1, 1, 1))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.modulate.a = 0.0
	bottom_center.add_child(message_label)

	# --- Crosshair ---
	crosshair = _make_crosshair()
	_root.add_child(crosshair)

	# --- Debug overlay (hidden by default; F3 toggles) ---
	debug_panel = PanelContainer.new()
	debug_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	debug_panel.position = Vector2(24, 90)
	debug_panel.visible = false
	_root.add_child(debug_panel)

	debug_text = Label.new()
	debug_text.text = ""
	debug_text.add_theme_color_override("font_color", Color(0.75, 1, 0.75))
	debug_text.add_theme_font_size_override("font_size", 12)
	debug_panel.add_child(debug_text)

func _make_bar(prefix: String, fill: Color, w: int, h: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(w, h)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)

	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fg)

	bar.tooltip_text = prefix
	return bar

func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	return label

func _make_crosshair() -> Control:
	# A simple 4-line crosshair drawn with ColorRect children.
	var root := Control.new()
	root.custom_minimum_size = Vector2(24, 24)
	root.size = Vector2(24, 24)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := Color(1, 1, 1, 0.95)
	var thickness := 2.0
	var length := 8.0
	for spec in [
		{"pos": Vector2(10, 2), "size": Vector2(thickness, length)},
		{"pos": Vector2(10, 14), "size": Vector2(thickness, length)},
		{"pos": Vector2(2, 10), "size": Vector2(length, thickness)},
		{"pos": Vector2(14, 10), "size": Vector2(length, thickness)},
	]:
		var bar := ColorRect.new()
		bar.color = col
		bar.position = spec["pos"]
		bar.size = spec["size"]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bar)
	return root

# -------------------------------------------------------------------------
# Signal wiring
# -------------------------------------------------------------------------

func _connect_signals() -> void:
	if not has_node("/root/EventBus"):
		push_warning("HUD: EventBus autoload not found — running without live data")
		return
	EventBus.player_damaged.connect(_on_health_changed)
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.hunger_changed.connect(_on_hunger_changed)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.reserve_ammo_changed.connect(_on_reserve_changed)
	EventBus.reload_started.connect(_on_reload_started)
	EventBus.reload_finished.connect(_on_reload_finished)
	EventBus.injury_changed.connect(_on_injury_changed)
	EventBus.game_message.connect(show_message)

# -------------------------------------------------------------------------
# Per-frame update (crosshair + debug + toast fade)
# -------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_crosshair()
	_update_reload_bar()
	_update_message_fade(delta)
	_update_debug_overlay()

	if Input.is_action_just_pressed(&"debug_toggle") or Input.is_key_pressed(KEY_F3):
		if Input.is_key_pressed(KEY_F3) and not _debug_was_held:
			_debug_visible = not _debug_visible
			debug_panel.visible = _debug_visible
			_debug_was_held = true
	elif _debug_was_held and not Input.is_key_pressed(KEY_F3):
		_debug_was_held = false

var _debug_was_held: bool = false

func _update_crosshair() -> void:
	if crosshair == null:
		return
	if _player and is_instance_valid(_player) and _player.has_method(&"get_aim_screen_position"):
		var p: Vector2 = _player.call(&"get_aim_screen_position")
		crosshair.position = p - crosshair.size * 0.5
	else:
		crosshair.position = get_viewport().get_mouse_position() - crosshair.size * 0.5

func _update_reload_bar() -> void:
	if _reload_start_time < 0.0 or reload_bar == null:
		return
	var t := Time.get_ticks_msec() / 1000.0 - _reload_start_time
	reload_bar.value = clampf(t / _reload_duration, 0.0, 1.0) * 100.0

func _update_message_fade(delta: float) -> void:
	if _message_timer <= 0.0:
		return
	_message_timer -= delta
	if _message_timer <= 0.0:
		message_label.modulate.a = 0.0
	elif _message_timer < 0.6:
		message_label.modulate.a = _message_timer / 0.6

func _update_debug_overlay() -> void:
	if not _debug_visible or debug_text == null:
		return
	var lines: Array[String] = []
	lines.append("FPS %d" % Engine.get_frames_per_second())
	if _player and is_instance_valid(_player):
		lines.append("player pos %s" % _player.global_position)
	var zombies := get_tree().get_nodes_in_group(&"zombie")
	lines.append("zombies alive: %d" % zombies.size())
	for i in mini(zombies.size(), 3):
		var z := zombies[i]
		var st := ""
		if z.has_method(&"get_state_name"):
			st = z.call(&"get_state_name")
		elif "state" in z:
			st = str(z.state)
		lines.append("  · %s [%s]" % [z.name, st])
	debug_text.text = "\n".join(lines)

# -------------------------------------------------------------------------
# Signal handlers
# -------------------------------------------------------------------------

func _on_health_changed(current: int, maximum: int) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current

func _on_hunger_changed(current: float, maximum: float) -> void:
	if hunger_bar:
		hunger_bar.max_value = maximum
		hunger_bar.value = current

func _on_weapon_changed(weapon_name: String) -> void:
	if weapon_label:
		weapon_label.text = weapon_name

func _on_ammo_changed(current: int, maximum: int) -> void:
	if ammo_label:
		ammo_label.text = "%d / %d" % [current, maximum]

func _on_reserve_changed(reserve: int) -> void:
	if ammo_label:
		# Append reserve count to the ammo text if we don't already show it.
		var parts := ammo_label.text.split(" ")
		if parts.size() >= 3 and parts[2].begins_with("["):
			return
		ammo_label.text = ammo_label.text + "  [%d]" % reserve

func _on_reload_started(duration: float) -> void:
	_reload_start_time = Time.get_ticks_msec() / 1000.0
	_reload_duration = maxf(duration, 0.01)
	if reload_bar:
		reload_bar.visible = true

func _on_reload_finished() -> void:
	_reload_start_time = -1.0
	if reload_bar:
		reload_bar.visible = false

func _on_injury_changed(is_bleeding: bool) -> void:
	if bleeding_label:
		bleeding_label.visible = is_bleeding

func show_message(text: String) -> void:
	if message_label == null:
		return
	message_label.text = text
	message_label.modulate.a = 1.0
	_message_timer = 3.0

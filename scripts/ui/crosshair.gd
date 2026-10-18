# Crosshair — a self-contained Control that follows the player's aim point.
#
# Extracted from the HUD so it can be reused anywhere (HUD, pause menu previews,
# minimap overlays). Draws 4 line ticks + a center dot. Tracks the player's
# `get_aim_screen_position()` if available, otherwise falls back to the mouse.
extends Control
class_name Crosshair

@export var player_group: StringName = &"player"
@export var color: Color = Color(1, 1, 1, 0.95)
@export var thickness: float = 2.0
@export var gap: float = 4.0
@export var length: float = 8.0
@export var dot_radius: float = 1.0

const SIZE := Vector2(40, 40)

func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(_delta: float) -> void:
	_follow_player_aim()

func _follow_player_aim() -> void:
	var player := get_tree().get_first_node_in_group(player_group)
	if player and player.has_method(&"get_aim_screen_position"):
		global_position = (player.call(&"get_aim_screen_position") as Vector2) - SIZE * 0.5
	else:
		global_position = get_viewport().get_mouse_position() - SIZE * 0.5

func _draw() -> void:
	var c := SIZE * 0.5
	var col := color
	# Four ticks pointing inward toward the centre.
	draw_line(c + Vector2(-gap - length, 0), c + Vector2(-gap, 0), col, thickness)
	draw_line(c + Vector2(gap, 0), c + Vector2(gap + length, 0), col, thickness)
	draw_line(c + Vector2(0, -gap - length), c + Vector2(0, -gap), col, thickness)
	draw_line(c + Vector2(0, gap), c + Vector2(0, gap + length), col, thickness)
	# Centre dot.
	if dot_radius > 0.0:
		draw_circle(c, dot_radius, col)

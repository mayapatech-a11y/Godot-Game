# GameState — the current run's mutable state.
extends Node

var day: int = 1
var hour: int = 6
var player_health: int = 100
var player_max_health: int = 100
var player_hunger: float = 100.0
var player_max_hunger: float = 100.0
var player_stamina: float = 100.0
var player_max_stamina: float = 100.0

# Inventory
var food_count: int = 2
var water_count: int = 2
var bandage_count: int = 1
var reserve_ammo: int = 90

# Status effects
var is_bleeding: bool = false
var _bleed_tick: float = 0.0

var kills: int = 0
var is_game_over: bool = false

func _process(delta: float) -> void:
	if is_game_over:
		return
		
	# Drain hunger
	player_hunger = maxf(player_hunger - (delta * 0.5), 0.0)
	EventBus.hunger_changed.emit(player_hunger, player_max_hunger)
	if player_hunger <= 0.0:
		damage_player(1)
		
	# Bleeding damage (2 HP per second)
	if is_bleeding:
		_bleed_tick += delta
		if _bleed_tick >= 1.0:
			_bleed_tick -= 1.0
			damage_player(2)

func damage_player(amount: int) -> void:
	if is_game_over:
		return
	player_health = maxi(player_health - amount, 0)
	EventBus.player_damaged.emit(player_health, player_max_health)
	if player_health <= 0:
		_game_over()

func add_ammo(amount: int) -> void:
	reserve_ammo += amount
	EventBus.reserve_ammo_changed.emit(reserve_ammo)
	EventBus.game_message.emit("Found %d ammo." % amount)

func add_food() -> void:
	food_count += 1
	EventBus.inventory_changed.emit(food_count, water_count, bandage_count)
	EventBus.game_message.emit("Found Canned Food.")

func add_water() -> void:
	water_count += 1
	EventBus.inventory_changed.emit(food_count, water_count, bandage_count)
	EventBus.game_message.emit("Found Clean Water.")

func add_bandage() -> void:
	bandage_count += 1
	EventBus.inventory_changed.emit(food_count, water_count, bandage_count)
	EventBus.game_message.emit("Found Bandage.")

func register_kill() -> void:
	kills += 1

func _game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	EventBus.player_died.emit()
	EventBus.game_over.emit("You survived %d day(s). Kills: %d." % [day, kills])

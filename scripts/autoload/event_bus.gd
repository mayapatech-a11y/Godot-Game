# EventBus — signal-only global hub.
extends Node

# --- Player ---
@warning_ignore("unused_signal")
signal player_damaged(new_health: int, max_health: int)
@warning_ignore("unused_signal")
signal player_died()
@warning_ignore("unused_signal")
signal hunger_changed(new_hunger: float, max_hunger: float)
@warning_ignore("unused_signal")
signal stamina_changed(new_stamina: float, max_stamina: float)
@warning_ignore("unused_signal")
signal injury_changed(is_bleeding: bool)

# --- Enemies ---
@warning_ignore("unused_signal")
signal enemy_damaged(enemy: Node3D, new_hp: float)
@warning_ignore("unused_signal")
signal enemy_died(enemy: Node3D, killed_by: Node)

# --- Weapons / Combat ---
@warning_ignore("unused_signal")
signal weapon_changed(weapon_name: String)
@warning_ignore("unused_signal")
signal ammo_changed(current: int, maximum: int)
@warning_ignore("unused_signal")
signal reserve_ammo_changed(reserve: int)
@warning_ignore("unused_signal")
signal reload_started(duration: float)
@warning_ignore("unused_signal")
signal reload_finished()
@warning_ignore("unused_signal")
signal noise_emitted(origin: Vector3, radius: float)

# --- Inventory / UI ---
@warning_ignore("unused_signal")
signal inventory_changed(food: int, water: int, bandages: int)
@warning_ignore("unused_signal")
signal game_message(text: String)

# --- Day / Night Cycle ---
@warning_ignore("unused_signal")
signal day_phase_changed(is_night: bool)
@warning_ignore("unused_signal")
signal time_of_day_changed(hour: float)

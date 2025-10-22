## Fog of War System
## Manages enemy visibility based on player's FOV and Line of Sight
## Enemies are ONLY visible when currently seen by a player unit
## No memory - pure real-time visibility!

class_name FogOfWarSystem
extends Node

## Emitted when an enemy becomes visible
signal enemy_revealed(enemy: Merc)

## Emitted when an enemy becomes hidden
signal enemy_hidden(enemy: Merc)

## Tracks which enemies are currently visible to ANY player
var visible_enemies: Dictionary = {}  # Merc -> bool

## All player units tracking
var player_units: Array[Merc] = []

## All enemy units tracking
var enemy_units: Array[Merc] = []

## Debug mode
@export var debug_mode: bool = false


func _ready() -> void:
	if debug_mode:
		print("[FOW] Fog of War System initialized")


## Register a player unit for FOW tracking
func register_player_unit(player: Merc) -> void:
	if not player_units.has(player):
		player_units.append(player)
		if debug_mode:
			print("[FOW] Registered player: %s" % player.merc_data.merc_name)


## Register an enemy unit for FOW tracking
func register_enemy_unit(enemy: Merc) -> void:
	if not enemy_units.has(enemy):
		enemy_units.append(enemy)
		visible_enemies[enemy] = false  # Start hidden
		if debug_mode:
			print("[FOW] Registered enemy: %s (initially hidden)" % enemy.merc_data.merc_name)


## Unregister a unit (when dead/removed)
func unregister_unit(unit: Merc) -> void:
	player_units.erase(unit)
	enemy_units.erase(unit)
	visible_enemies.erase(unit)


## Update visibility for all enemies based on all players
## Call this whenever:
## - A player moves
## - A player rotates
## - A player changes stance
## - An enemy moves
## - An enemy changes stance
func update_visibility() -> void:
	if debug_mode:
		print("\n[FOW] === UPDATING VISIBILITY ===")
	
	var previously_visible = visible_enemies.duplicate()
	
	# Reset all enemies to invisible
	for enemy in enemy_units:
		visible_enemies[enemy] = false
	
	# Check each player's FOV/LoS
	for player in player_units:
		for enemy in enemy_units:
			# Skip if already visible (no need to check again)
			if visible_enemies[enemy]:
				continue
			
			# Check if THIS player can see THIS enemy
			var can_see = player.can_see_enemy(enemy)
			
			if can_see:
				visible_enemies[enemy] = true
				
				if debug_mode:
					print("[FOW] %s can see %s!" % [
						player.merc_data.merc_name,
						enemy.merc_data.merc_name
					])
	
	# Emit signals for changes
	_emit_visibility_changes(previously_visible, visible_enemies)
	
	if debug_mode:
		print("[FOW] === VISIBILITY UPDATE COMPLETE ===\n")


## Check if a specific enemy is visible
func is_enemy_visible(enemy: Merc) -> bool:
	return visible_enemies.get(enemy, false)


## Get all currently visible enemies
func get_visible_enemies() -> Array[Merc]:
	var result: Array[Merc] = []
	for enemy in visible_enemies:
		if visible_enemies[enemy]:
			result.append(enemy)
	return result


## Get all hidden enemies
func get_hidden_enemies() -> Array[Merc]:
	var result: Array[Merc] = []
	for enemy in visible_enemies:
		if not visible_enemies[enemy]:
			result.append(enemy)
	return result


## Apply visibility to scene (show/hide meshes)
func apply_visibility_to_scene() -> void:
	for enemy in enemy_units:
		var should_be_visible = visible_enemies.get(enemy, false)
		
		# Hide/show the mesh
		if enemy.has_node("MeshInstance3D"):
			enemy.get_node("MeshInstance3D").visible = should_be_visible
		
		# Keep CollisionShape always active for physics
		# (so raycasts still work even when invisible)


## Get visibility stats
func get_visibility_stats() -> Dictionary:
	var visible_count = 0
	var hidden_count = 0
	
	for enemy in visible_enemies:
		if visible_enemies[enemy]:
			visible_count += 1
		else:
			hidden_count += 1
	
	return {
		"total_enemies": enemy_units.size(),
		"visible": visible_count,
		"hidden": hidden_count,
		"visibility_rate": float(visible_count) / enemy_units.size() if enemy_units.size() > 0 else 0.0
	}


## Private: Emit signals for visibility changes
func _emit_visibility_changes(old_state: Dictionary, new_state: Dictionary) -> void:
	for enemy in new_state:
		var was_visible = old_state.get(enemy, false)
		var is_visible = new_state[enemy]
		
		if is_visible and not was_visible:
			enemy_revealed.emit(enemy)
			if debug_mode:
				print("[FOW] 🔍 %s REVEALED!" % enemy.merc_data.merc_name)
		
		elif not is_visible and was_visible:
			enemy_hidden.emit(enemy)
			if debug_mode:
				print("[FOW] 🌫️  %s HIDDEN!" % enemy.merc_data.merc_name)


## Debug: Print current visibility state
func debug_print_visibility() -> void:
	print("\n[FOW] === VISIBILITY STATE ===")
	print("Players: %d" % player_units.size())
	print("Enemies: %d" % enemy_units.size())
	
	for enemy in enemy_units:
		var visible = visible_enemies.get(enemy, false)
		print("  %s: %s" % [
			enemy.merc_data.merc_name,
			"VISIBLE ✅" if visible else "HIDDEN ❌"
		])
	
	var stats = get_visibility_stats()
	print("\nStats: %d visible / %d hidden (%.1f%% visible)" % [
		stats.visible,
		stats.hidden,
		stats.visibility_rate * 100.0
	])
	print("===========================\n")

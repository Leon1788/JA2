extends Node
class_name UnitManager

var player_unit: Merc = null
var all_enemies: Array[Merc] = []
var all_units: Array[Merc] = []

var grid_manager_ref: GridManager

const MERC_SCENE = preload("res://scenes/entities/Merc.tscn")
const IVAN_DATA = preload("res://resources/mercs/ivan_dolvich.tres")
const AKM_WEAPON = preload("res://resources/weapons/akm.tres")

func setup_units(grid_manager: GridManager) -> void:
	print("\n" + "=".repeat(100))
	print("UNIT MANAGER SETUP")
	print("=".repeat(100) + "\n")
	
	grid_manager_ref = grid_manager
	
	_create_player_unit()
	_create_enemy_units()
	_initialize_all_units()
	
	print("[UNITS] Setup complete: 1 Player + %d Enemies\n" % all_enemies.size())

func _create_player_unit() -> void:
	print("[UNITS] Creating Player Unit...\n")
	
	player_unit = MERC_SCENE.instantiate()
	player_unit.merc_data = IVAN_DATA
	player_unit.weapon_data = AKM_WEAPON
	player_unit.is_player_unit = true
	player_unit.global_position = Vector3(20.5, 0.0, 20.5)
	player_unit.name = "Player"
	
	get_parent().add_child(player_unit)
	all_units.append(player_unit)
	
	print("  ✓ Player: %s at (%.1f, %.1f, %.1f)\n" % [
		player_unit.merc_data.merc_name,
		player_unit.global_position.x,
		player_unit.global_position.y,
		player_unit.global_position.z
	])

func _create_enemy_units() -> void:
	print("[UNITS] Creating Enemy Units...\n")
	
	var enemy_configs = [
		{"name": "Enemy_Floor1", "floor": 1, "pos": Vector3(5.5, 0, 5.5)},
		{"name": "Enemy_Floor2", "floor": 2, "pos": Vector3(35.5, 0, 5.5)},
		{"name": "Enemy_Floor3", "floor": 3, "pos": Vector3(5.5, 0, 35.5)},
		{"name": "Enemy_Floor4", "floor": 4, "pos": Vector3(35.5, 0, 35.5)},
	]
	
	for config in enemy_configs:
		var enemy = MERC_SCENE.instantiate()
		enemy.merc_data = IVAN_DATA.duplicate()
		enemy.merc_data.merc_name = config.name
		enemy.weapon_data = AKM_WEAPON.duplicate()
		enemy.is_player_unit = false
		enemy.global_position = config.pos
		enemy.name = config.name
		
		get_parent().add_child(enemy)
		all_enemies.append(enemy)
		all_units.append(enemy)
		
		print("  ✓ %s (Floor %d) at (%.1f, %.1f, %.1f)" % [
			config.name,
			config.floor,
			enemy.global_position.x,
			enemy.global_position.y,
			enemy.global_position.z
		])
	
	print()

func _initialize_all_units() -> void:
	print("[UNITS] Initializing all units with GridManager...\n")
	
	# Player
	player_unit.initialize_movement(grid_manager_ref)
	print("  ✓ Player initialized")
	
	# Enemies with floor assignment
	for i in range(all_enemies.size()):
		var enemy = all_enemies[i]
		enemy.initialize_movement(grid_manager_ref)
		enemy.movement_component.current_floor = i + 1
		print("  ✓ %s initialized (Floor %d)" % [enemy.merc_data.merc_name, i + 1])
	
	print()

func get_player_unit() -> Merc:
	return player_unit

func get_all_enemies() -> Array[Merc]:
	return all_enemies

func get_all_units() -> Array[Merc]:
	return all_units

func get_enemy_by_name(name: String) -> Merc:
	for enemy in all_enemies:
		if enemy.merc_data.merc_name == name:
			return enemy
	return null

func get_unit_by_name(name: String) -> Merc:
	for unit in all_units:
		if unit.merc_data.merc_name == name:
			return unit
	return null

func get_alive_enemies() -> Array[Merc]:
	var alive: Array[Merc] = []
	for enemy in all_enemies:
		if enemy.is_alive():
			alive.append(enemy)
	return alive

func get_alive_units() -> Array[Merc]:
	var alive: Array[Merc] = []
	for unit in all_units:
		if unit.is_alive():
			alive.append(unit)
	return alive

func print_unit_status() -> void:
	print("\n" + "=".repeat(100))
	print("UNIT STATUS REPORT")
	print("=".repeat(100) + "\n")
	
	if player_unit:
		print("[PLAYER] %s" % player_unit.merc_data.merc_name)
		if player_unit.health_component:
			print("  Health: Head=%d Thorax=%d Stomach=%d" % [
				player_unit.health_component.current_head,
				player_unit.health_component.current_thorax,
				player_unit.health_component.current_stomach
			])
		if player_unit.action_point_component:
			print("  AP: %d/%d" % [player_unit.action_point_component.current_ap, player_unit.action_point_component.max_ap])
		if player_unit.movement_component:
			print("  Position: %s (Floor %d)" % [player_unit.movement_component.current_grid_pos, player_unit.movement_component.current_floor])
		print()
	
	print("[ENEMIES] %d total, %d alive\n" % [all_enemies.size(), get_alive_enemies().size()])
	for enemy in all_enemies:
		var status = "✓ ALIVE" if enemy.is_alive() else "✗ DEAD"
		print("  [%s] %s" % [status, enemy.merc_data.merc_name])
		if enemy.is_alive():
			if enemy.health_component:
				print("    Health: Head=%d Thorax=%d Stomach=%d" % [
					enemy.health_component.current_head,
					enemy.health_component.current_thorax,
					enemy.health_component.current_stomach
				])
			if enemy.movement_component:
				print("    Position: %s (Floor %d)" % [enemy.movement_component.current_grid_pos, enemy.movement_component.current_floor])
	
	print("\n" + "=".repeat(100) + "\n")

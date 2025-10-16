extends Node3D

var merc: Merc
var enemy: Merc
var grid_manager: GridManager
var turn_manager: TurnManager
var visual_grid: VisualGrid

func _ready() -> void:
	print("=== COMBAT TEST START ===")
	
	# Erstelle Visual Grid
	visual_grid = VisualGrid.new()
	visual_grid.grid_size = Vector2i(10, 10)
	add_child(visual_grid)
	
	# Erstelle Grid Manager
	grid_manager = GridManager.new()
	add_child(grid_manager)
	
	# Erstelle Turn Manager
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	
	# Lade Waffe
	var akm_weapon = load("res://resources/weapons/akm.tres")
	
	# Lade die Merc Scene für Spieler
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	merc = merc_scene.instantiate()
	
	# Lade die Ivan Resource
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	merc.merc_data = ivan_data
	merc.weapon_data = akm_weapon
	merc.global_position = Vector3(0.5, 0, 0.5)
	
	add_child(merc)
	
	# Erstelle Gegner
	enemy = merc_scene.instantiate()
	enemy.merc_data = ivan_data.duplicate()
	enemy.merc_data.merc_name = "Enemy Soldier"
	enemy.weapon_data = akm_weapon.duplicate()
	enemy.global_position = Vector3(5.5, 0, 0.5)
	
	add_child(enemy)
	
	# Warte einen Frame
	await get_tree().process_frame
	
	# Initialisiere Movement
	merc.initialize_movement(grid_manager)
	enemy.initialize_movement(grid_manager)
	
	# Registriere Units im Turn Manager
	turn_manager.register_player_unit(merc)
	turn_manager.register_enemy_unit(enemy)
	
	print("\n--- COMBAT TEST SETUP ---")
	print("Player: ", merc.merc_data.merc_name, " at ", merc.movement_component.current_grid_pos)
	print("  Weapon: ", merc.weapon_data.weapon_name)
	print("  Ammo: ", merc.weapon_data.current_ammo)
	print("Enemy: ", enemy.merc_data.merc_name, " at ", enemy.movement_component.current_grid_pos)
	print("  HP (Head): ", enemy.health_component.current_head)
	print("  HP (Thorax): ", enemy.health_component.current_thorax)
	
	await get_tree().create_timer(1.0).timeout
	
	turn_manager.start_game()
	
	# Test 1: Direkter Schuss ohne Zielen
	await get_tree().create_timer(1.0).timeout
	print("\n--- TEST 1: Direct Shot ---")
	print("Player AP: ", merc.action_point_component.current_ap)
	var shot1 = merc.shoot_at(enemy, "thorax")
	print("Shot Result: Hit=", shot1.hit, " Chance=", shot1.hit_chance, "% Roll=", shot1.roll)
	if shot1.hit:
		print("  Damage: ", shot1.damage, " to ", shot1.body_part)
		print("  Enemy Thorax HP: ", enemy.health_component.current_thorax)
	print("Player AP after shot: ", merc.action_point_component.current_ap)
	print("Ammo left: ", merc.weapon_data.current_ammo)
	
	# Test 2: Zielen und dann schießen
	await get_tree().create_timer(1.0).timeout
	print("\n--- TEST 2: Aimed Shot ---")
	print("Player aims...")
	merc.aim()
	print("Player AP: ", merc.action_point_component.current_ap)
	
	await get_tree().create_timer(0.5).timeout
	var shot2 = merc.shoot_at(enemy, "head")
	print("Shot Result: Hit=", shot2.hit, " Chance=", shot2.hit_chance, "% Roll=", shot2.roll)
	if shot2.hit:
		print("  Damage: ", shot2.damage, " to ", shot2.body_part)
		print("  Enemy Head HP: ", enemy.health_component.current_head)
	print("Player AP after shot: ", merc.action_point_component.current_ap)
	print("Ammo left: ", merc.weapon_data.current_ammo)
	
	# Test 3: Mehrfaches Zielen
	await get_tree().create_timer(1.0).timeout
	print("\n--- TEST 3: Multiple Aims ---")
	merc.aim()
	print("Aimed once, AP: ", merc.action_point_component.current_ap)
	merc.aim()
	print("Aimed twice, AP: ", merc.action_point_component.current_ap)
	
	var shot3 = merc.shoot_at(enemy, "thorax")
	print("Shot Result: Hit=", shot3.hit, " Chance=", shot3.hit_chance, "% Roll=", shot3.roll)
	if shot3.hit:
		print("  Damage: ", shot3.damage)
		print("  Enemy Thorax HP: ", enemy.health_component.current_thorax)
	
	print("\n--- ENEMY STATUS ---")
	print("Head HP: ", enemy.health_component.current_head)
	print("Thorax HP: ", enemy.health_component.current_thorax)
	print("Is Alive: ", enemy.is_alive())
	
	print("\n=== COMBAT TEST END ===")

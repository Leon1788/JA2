extends Node3D

var merc: Merc
var enemy: Merc
var grid_manager: GridManager
var turn_manager: TurnManager
var visual_grid: VisualGrid

func _ready() -> void:
	print("=== STATUS EFFECT AUTO-TEST START ===")
	
	# Erstelle Visual Grid
	visual_grid = VisualGrid.new()
	visual_grid.grid_size = Vector2i(10, 10)
	add_child(visual_grid)
	
	# Erstelle Grid Manager
	grid_manager = GridManager.new()
	grid_manager.set_grid_bounds(Vector2i(0, 0), Vector2i(10, 10))
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
	merc.is_player_unit = true
	merc.global_position = Vector3(0.5, 0, 0.5)
	
	add_child(merc)
	
	# Erstelle Gegner
	enemy = merc_scene.instantiate()
	enemy.merc_data = ivan_data.duplicate()
	enemy.merc_data.merc_name = "Enemy Test Dummy"
	enemy.weapon_data = akm_weapon.duplicate()
	enemy.is_player_unit = false
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
	
	turn_manager.start_game()
	
	print("\n=== AUTO-TEST: Destroying body parts ===\n")
	
	await get_tree().create_timer(1.0).timeout
	
	# Test 1: Zerstöre linken Arm
	print("--- TEST 1: Destroying Left Arm ---")
	enemy.health_component.take_damage("left_arm", 60)
	print("Left Arm HP: ", enemy.health_component.current_left_arm)
	
	await get_tree().create_timer(1.0).timeout
	
	# Test 2: Zerstöre rechten Arm
	print("\n--- TEST 2: Destroying Right Arm ---")
	enemy.health_component.take_damage("right_arm", 60)
	print("Right Arm HP: ", enemy.health_component.current_right_arm)
	print("Accuracy Modifier: ", enemy.status_effect_system.get_accuracy_modifier())
	
	await get_tree().create_timer(1.0).timeout
	
	# Test 3: Zerstöre linkes Bein
	print("\n--- TEST 3: Destroying Left Leg ---")
	enemy.health_component.take_damage("left_leg", 65)
	print("Left Leg HP: ", enemy.health_component.current_left_leg)
	print("Movement AP Modifier: ", enemy.status_effect_system.get_movement_ap_modifier(), "x")
	
	await get_tree().create_timer(1.0).timeout
	
	# Test 4: Zerstöre rechtes Bein
	print("\n--- TEST 4: Destroying Right Leg ---")
	enemy.health_component.take_damage("right_leg", 65)
	print("Right Leg HP: ", enemy.health_component.current_right_leg)
	print("Movement AP Modifier: ", enemy.status_effect_system.get_movement_ap_modifier(), "x")
	
	await get_tree().create_timer(1.0).timeout
	
	# Test 5: Zerstöre Magen (verursacht Blutung)
	print("\n--- TEST 5: Destroying Stomach (causes bleeding) ---")
	enemy.health_component.take_damage("stomach", 70)
	print("Stomach HP: ", enemy.health_component.current_stomach)
	
	await get_tree().create_timer(1.0).timeout
	
	# Test 6: Simuliere mehrere Runden für Blutungs-Effekt
	print("\n--- TEST 6: Simulating turns to show bleeding ---")
	for i in range(5):
		await get_tree().create_timer(1.0).timeout
		print("\n>> Turn ", i + 1)
		turn_manager.end_turn()  # Player end
		await get_tree().create_timer(0.3).timeout
		turn_manager.end_turn()  # Enemy end - hier passiert start_turn und Blutung
		print("Enemy Thorax HP after bleeding: ", enemy.health_component.current_thorax)
		
		if not enemy.is_alive():
			print("*** ENEMY DIED FROM BLEEDING ***")
			break
	
	print("\n=== AUTO-TEST COMPLETE ===")

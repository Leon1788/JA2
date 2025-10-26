extends Node3D
class_name TargetingStateTest

var player: Merc
var enemy: Merc
var grid_manager: GridManager
var turn_manager: TurnManager

func _ready() -> void:
	print("\n" + "=".repeat(100))
	print("TEST: MERC TARGETING STATE FUNCTIONS")
	print("=".repeat(100))
	print("Testing: aimed_state | invested_ap | current_target | targeting logic\n")
	
	setup_scene()
	await get_tree().process_frame
	
	run_tests()

func setup_scene() -> void:
	print("[SETUP] Creating test environment...\n")
	
	# Grid Manager
	grid_manager = GridManager.new()
	grid_manager.set_grid_bounds(Vector2i(0, 0), Vector2i(10, 10))
	add_child(grid_manager)
	
	# Turn Manager
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	
	await get_tree().process_frame
	
	# Load resources
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	var akm_weapon = load("res://resources/weapons/akm.tres")
	
	# Create Player
	player = merc_scene.instantiate()
	player.merc_data = ivan_data
	player.weapon_data = akm_weapon
	player.is_player_unit = true
	player.global_position = Vector3(2.5, 0, 2.5)
	add_child(player)
	
	# Create Enemy
	enemy = merc_scene.instantiate()
	enemy.merc_data = ivan_data.duplicate()
	enemy.merc_data.merc_name = "TestEnemy"
	enemy.weapon_data = akm_weapon.duplicate()
	enemy.is_player_unit = false
	enemy.global_position = Vector3(7.5, 0, 2.5)
	add_child(enemy)
	
	await get_tree().process_frame
	
	# Initialize
	player.initialize_movement(grid_manager)
	enemy.initialize_movement(grid_manager)
	
	turn_manager.register_player_unit(player)
	turn_manager.register_enemy_unit(enemy)
	turn_manager.start_game()
	
	print("[SETUP] Complete!\n")

func run_tests() -> void:
	print("=".repeat(100))
	print("TEST 1: Initial State")
	print("=".repeat(100))
	test_initial_state()
	
	await get_tree().create_timer(0.3).timeout
	
	print("\n" + "=".repeat(100))
	print("TEST 2: Set Targeting Target")
	print("=".repeat(100))
	test_set_targeting_target()
	
	await get_tree().create_timer(0.3).timeout
	
	print("\n" + "=".repeat(100))
	print("TEST 3: Add Invested AP (0 -> 10)")
	print("=".repeat(100))
	test_add_invested_ap()
	
	await get_tree().create_timer(0.3).timeout
	
	print("\n" + "=".repeat(100))
	print("TEST 4: Set Aimed State")
	print("=".repeat(100))
	test_set_aimed_state()
	
	await get_tree().create_timer(0.3).timeout
	
	print("\n" + "=".repeat(100))
	print("TEST 5: Target Switching")
	print("=".repeat(100))
	test_target_switching()
	
	await get_tree().create_timer(0.3).timeout
	
	print("\n" + "=".repeat(100))
	print("TEST 6: Reset Targeting State")
	print("=".repeat(100))
	test_reset_targeting_state()
	
	await get_tree().create_timer(0.3).timeout
	
	print_final_report()

func test_initial_state() -> void:
	print("\n[TEST 1] Checking initial state of player...\n")
	
	var aimed = player.get_aimed_state()
	var invested = player.get_invested_ap()
	var target = player.current_target
	
	print("  is_already_aimed: %s (expected: false)" % aimed)
	print("  invested_ap: %d (expected: 0)" % invested)
	print("  current_target: %s (expected: null)" % ("null" if target == null else target.merc_data.merc_name))
	
	assert(aimed == false, "Initial aimed state should be false")
	assert(invested == 0, "Initial invested AP should be 0")
	assert(target == null, "Initial target should be null")
	
	print("\n  ✅ All initial state checks PASSED")

func test_set_targeting_target() -> void:
	print("\n[TEST 2] Setting targeting target...\n")
	
	print("  Before: current_target = %s" % ("null" if player.current_target == null else player.current_target.merc_data.merc_name))
	
	player.set_targeting_target(enemy)
	
	print("  After: current_target = %s" % player.current_target.merc_data.merc_name)
	print("  After: invested_ap = %d (should be 1 on first target)" % player.get_invested_ap())
	
	assert(player.current_target == enemy, "Target should be set to enemy")
	assert(player.get_invested_ap() == 1, "First AP investment should be 1")
	
	print("\n  ✅ Target setting PASSED")

func test_add_invested_ap() -> void:
	print("\n[TEST 3] Adding invested AP (loop 1->10)...\n")
	
	# Reset to 1
	player.invested_ap = 1
	
	for i in range(9):
		var success = player.add_invested_ap()
		var success_str = "true" if success else "false"
		var current_ap = player.get_invested_ap()
		print("  Add #" + str(i+1) + ": success=" + success_str + ", invested_ap=" + str(current_ap))
	
	print("\n  AP Progression: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10")
	
	# Try to add when already at max
	var overflow_success = player.add_invested_ap()
	var overflow_str = "true" if overflow_success else "false"
	print("  Overflow attempt (at max=10): success=" + overflow_str)
	
	assert(player.get_invested_ap() == 10, "Should be at max 10")
	assert(overflow_success == false, "Should fail when adding at max")
	
	print("\n  ✅ AP progression PASSED (0->10 clamped)")

func test_set_aimed_state() -> void:
	print("\n[TEST 4] Setting aimed state...\n")
	
	print("  Before: is_already_aimed = %s" % player.get_aimed_state())
	
	player.set_aimed_state(true)
	print("  After set_aimed_state(true): is_already_aimed = %s" % player.get_aimed_state())
	
	assert(player.get_aimed_state() == true, "Aimed state should be true")
	
	player.set_aimed_state(false)
	print("  After set_aimed_state(false): is_already_aimed = %s" % player.get_aimed_state())
	
	assert(player.get_aimed_state() == false, "Aimed state should be false")
	
	print("\n  ✅ Aimed state toggle PASSED")

func test_target_switching() -> void:
	print("\n[TEST 5] Testing target switching...\n")
	
	# Set first target
	player.set_targeting_target(enemy)
	var first_check = player.is_currently_targeting(enemy)
	print("  After set_targeting_target(enemy): is_currently_targeting(enemy) = %s" % first_check)
	assert(first_check == true, "Should be targeting enemy")
	
	# Create second enemy
	var enemy2 = preload("res://scenes/entities/Merc.tscn").instantiate()
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	var akm_weapon = load("res://resources/weapons/akm.tres")
	enemy2.merc_data = ivan_data.duplicate()
	enemy2.merc_data.merc_name = "TestEnemy2"
	enemy2.weapon_data = akm_weapon.duplicate()
	enemy2.is_player_unit = false
	enemy2.global_position = Vector3(8.5, 0, 3.5)
	add_child(enemy2)
	await get_tree().process_frame
	enemy2.initialize_movement(grid_manager)
	
	# Switch target
	player.set_targeting_target(enemy2)
	var second_check = player.is_currently_targeting(enemy2)
	var first_check_after = player.is_currently_targeting(enemy)
	
	print("  After set_targeting_target(enemy2): is_currently_targeting(enemy2) = %s" % second_check)
	print("  After switch: is_currently_targeting(enemy) = %s (should be false)" % first_check_after)
	
	assert(second_check == true, "Should now target enemy2")
	assert(first_check_after == false, "Should no longer target enemy1")
	
	print("\n  ✅ Target switching PASSED")

func test_reset_targeting_state() -> void:
	print("\n[TEST 6] Resetting targeting state...\n")
	
	# Setup state
	player.set_targeting_target(enemy)
	player.add_invested_ap()
	player.add_invested_ap()
	player.set_aimed_state(true)
	
	print("  Before reset:")
	print("    is_already_aimed: %s" % player.get_aimed_state())
	print("    invested_ap: %d" % player.get_invested_ap())
	print("    current_target: %s" % player.current_target.merc_data.merc_name)
	
	# Reset
	player.reset_targeting_state()
	
	print("\n  After reset:")
	print("    is_already_aimed: %s (expected: false)" % player.get_aimed_state())
	print("    invested_ap: %d (expected: 0)" % player.get_invested_ap())
	print("    current_target: %s (expected: null)" % ("null" if player.current_target == null else player.current_target.merc_data.merc_name))
	
	assert(player.get_aimed_state() == false, "Aimed state should be reset to false")
	assert(player.get_invested_ap() == 0, "Invested AP should be reset to 0")
	assert(player.current_target == null, "Current target should be reset to null")
	
	print("\n  ✅ Reset targeting state PASSED")

func print_final_report() -> void:
	print("\n" + "=".repeat(100))
	print("ALL TESTS COMPLETED SUCCESSFULLY ✅")
	print("=".repeat(100))
	print("\n[SUMMARY]")
	print("  ✅ Test 1: Initial state verification")
	print("  ✅ Test 2: Target setting")
	print("  ✅ Test 3: AP investment (0->10 clamping)")
	print("  ✅ Test 4: Aimed state toggle")
	print("  ✅ Test 5: Target switching")
	print("  ✅ Test 6: State reset")
	print("\n[NEXT STEPS]")
	print("  - GameSceneManager.gd")
	print("  - UnitManager.gd")
	print("  - TargetingSystem.gd")
	print("  - CombatSystem.gd")
	print("  - UIManager.gd")
	print("\n" + "=".repeat(100) + "\n")

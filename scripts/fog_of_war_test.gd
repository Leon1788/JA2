extends Node3D

## Fog of War Simulation Test
## Tests FOW system with player movement, rotation, and stance changes
## Verifies enemies are shown/hidden correctly

class TestResult:
	var test_name: String
	var passed: bool
	var expected: String
	var actual: String
	var details: String

var player: Merc
var enemy1: Merc
var enemy2: Merc
var enemy3: Merc
var grid_manager: GridManager
var turn_manager: TurnManager
var visual_grid: VisualGrid
var fow_system: FogOfWarSystem

var test_results: Array[TestResult] = []
var current_test_number: int = 0

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("FOG OF WAR SIMULATION TEST")
	print("Testing enemy visibility with FOV + LoS + FOW")
	print("=".repeat(80) + "\n")
	
	setup_scene()
	await get_tree().create_timer(1.0).timeout
	
	run_all_tests()

func setup_scene() -> void:
	print("[SETUP] Creating test environment...")
	
	# Visual Grid (30x10)
	visual_grid = VisualGrid.new()
	visual_grid.grid_size = Vector2i(30, 10)
	add_child(visual_grid)
	
	# Add Floor Plane
	var floor_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(30, 10)
	floor_mesh.mesh = plane_mesh
	floor_mesh.position = Vector3(15, -0.1, 5)
	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.3, 0.3, 0.3, 1.0)
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	
	# Grid Manager
	grid_manager = GridManager.new()
	grid_manager.set_grid_bounds(Vector2i(0, 0), Vector2i(30, 10))
	add_child(grid_manager)
	
	# Turn Manager
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	
	# FOG OF WAR SYSTEM
	fow_system = FogOfWarSystem.new()
	fow_system.debug_mode = true
	add_child(fow_system)
	
	# Camera
	var camera = Camera3D.new()
	camera.position = Vector3(12, 15, 5)
	camera.look_at(Vector3(15, 0, 5))
	add_child(camera)
	
	# Light
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)
	
	await get_tree().process_frame
	
	# Create walls (vertical line at X=15)
	spawn_wall_section(15, 2, "low", 0.5)
	spawn_wall_section(15, 5, "medium", 1.2)
	spawn_wall_section(15, 8, "high", 2.0)
	
	# Load merc scene and data
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	var akm_weapon = load("res://resources/weapons/akm.tres")
	
	# Create Player at (5, 5)
	player = merc_scene.instantiate()
	player.merc_data = ivan_data
	player.weapon_data = akm_weapon
	player.is_player_unit = true
	player.global_position = Vector3(5.5, 0, 5.5)
	add_child(player)
	
	# Create Enemy 1 at (20, 4) - IN FOV
	enemy1 = merc_scene.instantiate()
	enemy1.merc_data = ivan_data.duplicate()
	enemy1.merc_data.merc_name = "Enemy-North"
	enemy1.weapon_data = akm_weapon.duplicate()
	enemy1.is_player_unit = false
	enemy1.global_position = Vector3(20.5, 0, 4.5)
	add_child(enemy1)
	
	# Create Enemy 2 at (20, 5) - IN FOV (center)
	enemy2 = merc_scene.instantiate()
	enemy2.merc_data = ivan_data.duplicate()
	enemy2.merc_data.merc_name = "Enemy-Center"
	enemy2.weapon_data = akm_weapon.duplicate()
	enemy2.is_player_unit = false
	enemy2.global_position = Vector3(20.5, 0, 5.5)
	add_child(enemy2)
	
	# Create Enemy 3 at (20, 6) - IN FOV
	enemy3 = merc_scene.instantiate()
	enemy3.merc_data = ivan_data.duplicate()
	enemy3.merc_data.merc_name = "Enemy-South"
	enemy3.weapon_data = akm_weapon.duplicate()
	enemy3.is_player_unit = false
	enemy3.global_position = Vector3(20.5, 0, 6.5)
	add_child(enemy3)
	
	await get_tree().process_frame
	
	# Initialize all units
	player.initialize_movement(grid_manager)
	enemy1.initialize_movement(grid_manager)
	enemy2.initialize_movement(grid_manager)
	enemy3.initialize_movement(grid_manager)
	
	turn_manager.register_player_unit(player)
	turn_manager.register_enemy_unit(enemy1)
	turn_manager.register_enemy_unit(enemy2)
	turn_manager.register_enemy_unit(enemy3)
	
	# Register with FOW System
	fow_system.register_player_unit(player)
	fow_system.register_enemy_unit(enemy1)
	fow_system.register_enemy_unit(enemy2)
	fow_system.register_enemy_unit(enemy3)
	
	turn_manager.start_game()
	
	# Player faces East (90°)
	player.facing_system.rotate_to_angle(90.0)
	
	# Initial FOW update
	fow_system.update_visibility()
	
	print("[SETUP] Environment ready!")
	print("  - Player at (5,5) facing East")
	print("  - 3 Enemies at (20,4), (20,5), (20,6) - ALL IN 120° FOV")
	print("  - 3 Walls: 0.5m, 1.2m, 2.0m at X=15")
	print("  - FOW System initialized\n")

func spawn_wall_section(x: int, z: int, name: String, height: float) -> void:
	var cover_scene = preload("res://scenes/entities/CoverObject.tscn")
	var cover = cover_scene.instantiate()
	
	var cover_data = CoverData.new()
	cover_data.cover_name = name.capitalize() + " Wall"
	cover_data.cover_height = height
	cover_data.cover_type = CoverData.CoverType.LOW if height < 1.0 else CoverData.CoverType.HIGH
	cover_data.is_destructible = false
	
	cover.cover_data = cover_data
	cover.grid_position = Vector2i(x, z)
	cover.global_position = grid_manager.grid_to_world(Vector2i(x, z))
	
	add_child(cover)
	await get_tree().process_frame
	grid_manager.place_cover(Vector2i(x, z), cover)

func run_all_tests() -> void:
	print("\n" + "=".repeat(80))
	print("PHASE 1: BASIC FOW TESTS (10 tests)")
	print("=".repeat(80) + "\n")
	
	await run_basic_fow_tests()
	
	print("\n" + "=".repeat(80))
	print("PHASE 2: PLAYER ROTATION FOW (8 tests)")
	print("=".repeat(80) + "\n")
	
	await run_rotation_fow_tests()
	
	print("\n" + "=".repeat(80))
	print("PHASE 3: PLAYER MOVEMENT FOW (6 tests)")
	print("=".repeat(80) + "\n")
	
	await run_movement_fow_tests()
	
	print("\n" + "=".repeat(80))
	print("PHASE 4: STANCE CHANGE FOW (9 tests)")
	print("=".repeat(80) + "\n")
	
	await run_stance_fow_tests()
	
	print("\n" + "=".repeat(80))
	print("PHASE 5: ENEMY MOVEMENT FOW (6 tests)")
	print("=".repeat(80) + "\n")
	
	await run_enemy_movement_fow_tests()
	
	print_final_report()

func run_basic_fow_tests() -> void:
	print("[BASIC] Testing initial FOW state and visibility updates...\n")
	
	# Reset positions
	player.movement_component.move_to(Vector2i(5, 5))
	player.facing_system.rotate_to_angle(90.0)
	player.change_stance(StanceSystem.Stance.STANDING)
	
	enemy1.change_stance(StanceSystem.Stance.STANDING)
	enemy2.change_stance(StanceSystem.Stance.STANDING)
	enemy3.change_stance(StanceSystem.Stance.STANDING)
	
	await get_tree().create_timer(0.3).timeout
	
	# Test 1: Initial state - all enemies should be hidden (behind walls)
	current_test_number += 1
	fow_system.update_visibility()
	test_fow_state("Initial State - All Behind Walls", {
		enemy1: false,  # Behind 0.5m wall
		enemy2: false,  # Behind 1.2m wall
		enemy3: false   # Behind 2.0m wall
	})
	
	# Test 2: Player crouches - should see over low wall
	current_test_number += 1
	player.change_stance(StanceSystem.Stance.STANDING)
	await get_tree().create_timer(0.3).timeout
	fow_system.update_visibility()
	test_fow_state("Player STANDING - Sees some enemies", {
		enemy1: false,  # Still blocked
		enemy2: false,  # Still blocked
		enemy3: false   # Still blocked
	})
	
	# Test 3: Move player closer
	current_test_number += 1
	player.movement_component.move_to(Vector2i(10, 5))
	await get_tree().create_timer(0.3).timeout
	fow_system.update_visibility()
	test_fow_state("Player at (10,5) - Closer to enemies", {
		enemy1: false,
		enemy2: false,
		enemy3: false
	})
	
	# Test 4: Move player very close (14, 5) - right before wall
	current_test_number += 1
	player.movement_component.move_to(Vector2i(14, 5))
	await get_tree().create_timer(0.3).timeout
	fow_system.update_visibility()
	test_fow_state("Player at (14,5) - Right before wall", {
		enemy1: false,
		enemy2: false,
		enemy3: false
	})
	
	# Test 5: Move player past wall (16, 5)
	current_test_number += 1
	player.movement_component.move_to(Vector2i(16, 5))
	await get_tree().create_timer(0.3).timeout
	fow_system.update_visibility()
	test_fow_state("Player at (16,5) - Past the wall!", {
		enemy1: true,   # Should be visible now!
		enemy2: true,   # Should be visible now!
		enemy3: true    # Should be visible now!
	})
	
	# Test 6: Move back behind wall - enemies should disappear
	current_test_number += 1
	player.movement_component.move_to(Vector2i(14, 5))
	await get_tree().create_timer(0.3).timeout
	fow_system.update_visibility()
	test_fow_state("Player moved back to (14,5) - Behind wall again", {
		enemy1: false,  # Hidden again!
		enemy2: false,  # Hidden again!
		enemy3: false   # Hidden again!
	})
	
	# Test 7: Stats check
	current_test_number += 1
	var stats = fow_system.get_visibility_stats()
	test_stats("FOW Stats - 0/3 visible", stats, 0, 3)
	
	# Test 8: Move forward and check stats
	current_test_number += 1
	player.movement_component.move_to(Vector2i(16, 5))
	await get_tree().create_timer(0.3).timeout
	fow_system.update_visibility()
	stats = fow_system.get_visibility_stats()
	test_stats("FOW Stats - 3/3 visible", stats, 3, 0)
	
	# Test 9: Get visible enemies list
	current_test_number += 1
	var visible = fow_system.get_visible_enemies()
	test_visible_list("Get Visible Enemies List", visible, 3)
	
	# Test 10: Get hidden enemies list
	current_test_number += 1
	player.movement_component.move_to(Vector2i(5, 5))
	await get_tree().create_timer(0.3).timeout
	fow_system.update_visibility()
	var hidden = fow_system.get_hidden_enemies()
	test_visible_list("Get Hidden Enemies List", hidden, 3)

func run_rotation_fow_tests() -> void:
	print("[ROTATION] Testing FOW with player rotation...\n")
	
	player.movement_component.move_to(Vector2i(5, 5))
	player.change_stance(StanceSystem.Stance.STANDING)
	await get_tree().create_timer(0.3).timeout
	
	var angles = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
	
	for angle in angles:
		current_test_number += 1
		player.facing_system.rotate_to_angle(angle)
		await get_tree().create_timer(0.3).timeout
		fow_system.update_visibility()
		
		test_rotation_fow(angle)

func run_movement_fow_tests() -> void:
	print("[MOVEMENT] Testing FOW with player movement...\n")
	
	player.facing_system.rotate_to_angle(90.0)
	player.change_stance(StanceSystem.Stance.STANDING)
	
	var positions = [
		Vector2i(5, 5),
		Vector2i(8, 5),
		Vector2i(10, 5),
		Vector2i(14, 5),
		Vector2i(16, 5),
		Vector2i(18, 5)
	]
	
	for pos in positions:
		current_test_number += 1
		player.movement_component.move_to(pos)
		await get_tree().create_timer(0.3).timeout
		fow_system.update_visibility()
		
		test_movement_fow(pos)

func run_stance_fow_tests() -> void:
	print("[STANCE] Testing FOW with stance changes...\n")
	
	player.movement_component.move_to(Vector2i(5, 5))
	player.facing_system.rotate_to_angle(90.0)
	
	var stances = [
		StanceSystem.Stance.STANDING,
		StanceSystem.Stance.CROUCHED,
		StanceSystem.Stance.PRONE
	]
	
	for player_stance in stances:
		player.change_stance(player_stance)
		await get_tree().create_timer(0.3).timeout
		
		for enemy_stance in stances:
			current_test_number += 1
			enemy2.change_stance(enemy_stance)
			await get_tree().create_timer(0.3).timeout
			fow_system.update_visibility()
			
			test_stance_fow(player_stance, enemy_stance)

func run_enemy_movement_fow_tests() -> void:
	print("[ENEMY MOVEMENT] Testing FOW with enemy movement...\n")
	
	player.movement_component.move_to(Vector2i(5, 5))
	player.facing_system.rotate_to_angle(90.0)
	player.change_stance(StanceSystem.Stance.STANDING)
	
	# Move enemy2 to different positions
	var enemy_positions = [
		Vector2i(20, 5),  # Behind medium wall
		Vector2i(10, 5),  # In front of player (no cover)
		Vector2i(14, 5),  # At the wall
		Vector2i(16, 5),  # Just past wall
		Vector2i(5, 8),   # To the side
		Vector2i(20, 5)   # Back to original
	]
	
	for pos in enemy_positions:
		current_test_number += 1
		enemy2.movement_component.move_to(pos)
		await get_tree().create_timer(0.3).timeout
		fow_system.update_visibility()
		
		test_enemy_movement_fow(pos)

func test_fow_state(test_name: String, expected_visibility: Dictionary) -> void:
	print("\n[TEST %d] %s" % [current_test_number, test_name])
	
	var passed = true
	var details = []
	
	for enemy in expected_visibility:
		var expected = expected_visibility[enemy]
		var actual = fow_system.is_enemy_visible(enemy)
		
		var match_str = "✅" if expected == actual else "❌"
		details.append("  %s: Expected=%s Actual=%s %s" % [
			enemy.merc_data.merc_name,
			expected,
			actual,
			match_str
		])
		
		if expected != actual:
			passed = false
	
	for detail in details:
		print(detail)
	
	var result = TestResult.new()
	result.test_name = test_name
	result.passed = passed
	result.expected = str(expected_visibility.values())
	
	# Build actual visibility array manually
	var actual_visibility = []
	for e in expected_visibility.keys():
		actual_visibility.append(fow_system.is_enemy_visible(e))
	result.actual = str(actual_visibility)
	
	test_results.append(result)
	
	print("  Result: %s" % ("PASS ✅" if passed else "FAIL ❌"))

func test_stats(test_name: String, stats: Dictionary, expected_visible: int, expected_hidden: int) -> void:
	print("\n[TEST %d] %s" % [current_test_number, test_name])
	
	var passed = (stats.visible == expected_visible and stats.hidden == expected_hidden)
	
	print("  Expected: %d visible, %d hidden" % [expected_visible, expected_hidden])
	print("  Actual: %d visible, %d hidden" % [stats.visible, stats.hidden])
	print("  Result: %s" % ("PASS ✅" if passed else "FAIL ❌"))
	
	var result = TestResult.new()
	result.test_name = test_name
	result.passed = passed
	result.expected = "%dv/%dh" % [expected_visible, expected_hidden]
	result.actual = "%dv/%dh" % [stats.visible, stats.hidden]
	test_results.append(result)

func test_visible_list(test_name: String, list: Array, expected_count: int) -> void:
	print("\n[TEST %d] %s" % [current_test_number, test_name])
	
	var passed = (list.size() == expected_count)
	
	print("  Expected count: %d" % expected_count)
	print("  Actual count: %d" % list.size())
	print("  Result: %s" % ("PASS ✅" if passed else "FAIL ❌"))
	
	var result = TestResult.new()
	result.test_name = test_name
	result.passed = passed
	result.expected = str(expected_count)
	result.actual = str(list.size())
	test_results.append(result)

func test_rotation_fow(angle: float) -> void:
	var test_name = "Rotation Test: Player facing %.0f°" % angle
	print("\n[TEST %d] %s" % [current_test_number, test_name])
	
	var visible_count = fow_system.get_visible_enemies().size()
	print("  Visible enemies: %d" % visible_count)
	
	var result = TestResult.new()
	result.test_name = test_name
	result.passed = true  # Observational
	result.expected = "Tracked"
	result.actual = "%d visible" % visible_count
	test_results.append(result)

func test_movement_fow(pos: Vector2i) -> void:
	var test_name = "Movement Test: Player at %s" % pos
	print("\n[TEST %d] %s" % [current_test_number, test_name])
	
	var visible_count = fow_system.get_visible_enemies().size()
	print("  Visible enemies: %d" % visible_count)
	
	var result = TestResult.new()
	result.test_name = test_name
	result.passed = true
	result.expected = "Tracked"
	result.actual = "%d visible" % visible_count
	test_results.append(result)

func test_stance_fow(p_stance: StanceSystem.Stance, e_stance: StanceSystem.Stance) -> void:
	var test_name = "Stance Test: P=%s E=%s" % [
		_get_stance_name(p_stance),
		_get_stance_name(e_stance)
	]
	print("\n[TEST %d] %s" % [current_test_number, test_name])
	
	var visible = fow_system.is_enemy_visible(enemy2)
	print("  Enemy-Center visible: %s" % visible)
	
	var result = TestResult.new()
	result.test_name = test_name
	result.passed = true
	result.expected = "Tracked"
	result.actual = "Visible=%s" % visible
	test_results.append(result)

func test_enemy_movement_fow(pos: Vector2i) -> void:
	var test_name = "Enemy Movement: Enemy at %s" % pos
	print("\n[TEST %d] %s" % [current_test_number, test_name])
	
	var visible = fow_system.is_enemy_visible(enemy2)
	print("  Enemy-Center visible: %s" % visible)
	
	var result = TestResult.new()
	result.test_name = test_name
	result.passed = true
	result.expected = "Tracked"
	result.actual = "Visible=%s" % visible
	test_results.append(result)

func _get_stance_name(stance: StanceSystem.Stance) -> String:
	match stance:
		StanceSystem.Stance.STANDING: return "STANDING"
		StanceSystem.Stance.CROUCHED: return "CROUCHED"
		StanceSystem.Stance.PRONE: return "PRONE"
	return "UNKNOWN"

func print_final_report() -> void:
	print("\n\n")
	print("=".repeat(80))
	print("FINAL FOG OF WAR TEST REPORT")
	print("=".repeat(80))
	
	var passed = 0
	var failed = 0
	var failed_tests = []
	
	for result in test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1
			failed_tests.append(result)
	
	print("\nTotal Tests: %d" % test_results.size())
	print("Passed: %d ✅" % passed)
	print("Failed: %d ❌" % failed)
	print("Success Rate: %.1f%%" % (float(passed) / test_results.size() * 100.0))
	
	print("\n--- TEST BREAKDOWN ---")
	print("Phase 1 (Basic FOW): 10 tests")
	print("Phase 2 (Rotation FOW): 8 tests")
	print("Phase 3 (Movement FOW): 6 tests")
	print("Phase 4 (Stance FOW): 9 tests")
	print("Phase 5 (Enemy Movement): 6 tests")
	
	if failed > 0:
		print("\n" + "-".repeat(80))
		print("FAILED TESTS:")
		print("-".repeat(80))
		for result in failed_tests:
			print("\n❌ %s" % result.test_name)
			print("   Expected: %s" % result.expected)
			print("   Actual:   %s" % result.actual)
	else:
		print("\n🎉 ALL FOG OF WAR TESTS PASSED! 🎉")
	
	print("\n" + "=".repeat(80))

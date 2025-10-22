extends Node3D

## FOV GRID DEBUG TEST
## Finds out why enemies are not in FOV grid

var player: Merc
var enemy: Merc
var grid_manager: GridManager
var turn_manager: TurnManager

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("FOV GRID DEBUG TEST")
	print("Finding out why enemies are not visible in FOV")
	print("=".repeat(80) + "\n")
	
	setup_scene()
	await get_tree().create_timer(1.0).timeout
	
	run_debug_tests()

func setup_scene() -> void:
	print("[SETUP] Creating minimal test environment...\n")
	
	# Grid Manager
	grid_manager = GridManager.new()
	grid_manager.set_grid_bounds(Vector2i(0, 0), Vector2i(30, 10))
	add_child(grid_manager)
	
	# Turn Manager
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	
	await get_tree().process_frame
	
	# Create ONE wall at (15, 5)
	spawn_wall(15, 5, 1.2)
	
	# Load merc scene
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
	
	# Create Enemy at (20, 5) - directly in front
	enemy = merc_scene.instantiate()
	enemy.merc_data = ivan_data.duplicate()
	enemy.merc_data.merc_name = "TestEnemy"
	enemy.weapon_data = akm_weapon.duplicate()
	enemy.is_player_unit = false
	enemy.global_position = Vector3(20.5, 0, 5.5)
	add_child(enemy)
	
	await get_tree().process_frame
	
	# Initialize
	player.initialize_movement(grid_manager)
	enemy.initialize_movement(grid_manager)
	
	turn_manager.register_player_unit(player)
	turn_manager.register_enemy_unit(enemy)
	turn_manager.start_game()
	
	# Player faces East
	player.facing_system.rotate_to_angle(90.0)
	
	print("[SETUP] Complete!\n")

func spawn_wall(x: int, z: int, height: float) -> void:
	var cover_scene = preload("res://scenes/entities/CoverObject.tscn")
	var cover = cover_scene.instantiate()
	
	var cover_data = CoverData.new()
	cover_data.cover_name = "Test Wall"
	cover_data.cover_height = height
	cover_data.cover_type = CoverData.CoverType.HIGH
	cover_data.is_destructible = false
	
	cover.cover_data = cover_data
	cover.grid_position = Vector2i(x, z)
	cover.global_position = grid_manager.grid_to_world(Vector2i(x, z))
	
	add_child(cover)
	await get_tree().process_frame
	grid_manager.place_cover(Vector2i(x, z), cover)
	
	print("[SETUP] Wall placed at (%d, %d) with height %.1fm" % [x, z, height])

func run_debug_tests() -> void:
	print("=".repeat(80))
	print("DEBUG TEST 1: Basic FOV Check")
	print("=".repeat(80) + "\n")
	
	print("Player Position: %s" % player.movement_component.current_grid_pos)
	print("Player Facing: %.1f°" % player.facing_system.get_facing_angle())
	print("Enemy Position: %s" % enemy.movement_component.current_grid_pos)
	
	print("\n--- MANUAL FOV CALCULATION ---")
	
	# Get player's facing direction
	var player_pos = player.movement_component.current_grid_pos
	var enemy_pos = enemy.movement_component.current_grid_pos
	var player_angle = player.facing_system.get_facing_angle()
	
	# Calculate angle to enemy
	var dx = enemy_pos.x - player_pos.x
	var dz = enemy_pos.y - player_pos.y  # Grid uses y for Z
	var angle_to_enemy = rad_to_deg(atan2(dz, dx))
	if angle_to_enemy < 0:
		angle_to_enemy += 360
	
	print("Angle to enemy: %.1f°" % angle_to_enemy)
	
	# Calculate angle difference
	var angle_diff = abs(angle_to_enemy - player_angle)
	if angle_diff > 180:
		angle_diff = 360 - angle_diff
	
	print("Angle difference: %.1f°" % angle_diff)
	print("FOV Half-angle: 60° (120° total FOV)")
	print("Should be in FOV: %s" % ("YES" if angle_diff <= 60 else "NO"))
	
	# Calculate distance
	var distance = player_pos.distance_to(enemy_pos)
	print("\nDistance to enemy: %.1f tiles" % distance)
	print("Max FOV distance: 15 tiles")
	print("Within range: %s" % ("YES" if distance <= 15 else "NO"))
	
	print("\n--- CHECKING PLAYER'S FOV GRID ---")
	
	# Check if player has FOV grid
	if player.has_method("can_see_position"):
		var can_see = player.can_see_position(enemy_pos)
		print("player.can_see_position(%s): %s" % [enemy_pos, can_see])
	else:
		print("ERROR: Player has no can_see_position method!")
	
	# Try to access FOV grid directly
	print("\n--- ACCESSING FOV GRID SYSTEM ---")
	
	# Check if FOVGridSystem exists
	var fov_grid_system = get_node_or_null("/root/FOVGridSystem")
	if fov_grid_system:
		print("FOVGridSystem found as autoload")
	else:
		print("FOVGridSystem NOT found as autoload")
	
	# Try calculating FOV manually
	print("\n--- MANUAL FOV CALCULATION ---")
	var test_fov_grid = FOVGridSystem.calculate_fov_grid(player, grid_manager)
	
	if test_fov_grid.has(enemy_pos):
		var tile_state = test_fov_grid[enemy_pos]
		var state_name = "CLEAR" if tile_state == 0 else "BLOCKED"
		print("Enemy tile (%s) in FOV grid: %s" % [enemy_pos, state_name])
	else:
		print("Enemy tile (%s) NOT in FOV grid!" % enemy_pos)
	
	print("\n--- FOV GRID CONTENTS ---")
	print("Total visible tiles: %d" % test_fov_grid.size())
	
	# Show tiles around enemy
	print("\nTiles around enemy position:")
	for offset_x in range(-2, 3):
		for offset_z in range(-2, 3):
			var check_pos = enemy_pos + Vector2i(offset_x, offset_z)
			if test_fov_grid.has(check_pos):
				var state = test_fov_grid[check_pos]
				var state_name = "CLEAR" if state == 0 else "BLOCKED"
				print("  (%d, %d): %s" % [
					check_pos.x,
					check_pos.y,
					state_name
				])
	
	# Check shadow map
	print("\n--- CHECKING SHADOW MAP ---")
	
	# We need to look at the actual FOV calculation
	print("Checking if cover blocks line of sight...")
	
	var cover_pos = Vector2i(15, 5)
	var cover = grid_manager.get_cover_at(cover_pos)
	var has_cover = cover != null
	print("Cover at (%d, %d): %s" % [cover_pos.x, cover_pos.y, has_cover])
	
	if has_cover:
		print("Cover height: %.1fm" % cover.cover_data.cover_height)
	
	# Calculate if cover should block view
	print("\nDoes cover block view?")
	print("Player: (%d,%d) → Cover: (%d,%d) → Enemy: (%d,%d)" % [
		player_pos.x, player_pos.y,
		cover_pos.x, cover_pos.y,
		enemy_pos.x, enemy_pos.y
	])
	
	var player_to_cover_dist = player_pos.distance_to(cover_pos)
	var cover_to_enemy_dist = cover_pos.distance_to(enemy_pos)
	var total_dist = player_pos.distance_to(enemy_pos)
	
	print("Player→Cover: %.1f tiles" % player_to_cover_dist)
	print("Cover→Enemy: %.1f tiles" % cover_to_enemy_dist)
	print("Player→Enemy: %.1f tiles" % total_dist)
	
	# Check if cover is on the line
	var is_on_line = abs((player_to_cover_dist + cover_to_enemy_dist) - total_dist) < 0.1
	print("Cover is on line: %s" % is_on_line)
	
	print("\n" + "=".repeat(80))
	print("DEBUG TEST 2: Testing Different Player Positions")
	print("=".repeat(80) + "\n")
	
	# Test different positions
	var test_positions = [
		Vector2i(5, 5),   # Original
		Vector2i(10, 5),  # Closer
		Vector2i(14, 5),  # Before wall
		Vector2i(16, 5),  # After wall
		Vector2i(19, 5)   # Very close
	]
	
	for test_pos in test_positions:
		player.movement_component.move_to(test_pos)
		await get_tree().create_timer(0.2).timeout
		
		var fov = FOVGridSystem.calculate_fov_grid(player, grid_manager)
		var enemy_visible = fov.has(enemy_pos) and fov[enemy_pos] == 0  # 0 = CLEAR
		
		print("Player at %s: Enemy %s" % [
			test_pos,
			"VISIBLE ✅" if enemy_visible else "HIDDEN ❌"
		])
	
	print("\n" + "=".repeat(80))
	print("DEBUG COMPLETE")
	print("=".repeat(80))

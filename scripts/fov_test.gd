extends Node3D

# Managers
var grid_manager: GridManager
var game_scene_manager: GameSceneManager
var unit_manager: UnitManager
var turn_manager: TurnManager
var fow_system: FogOfWarSystem
var ui_manager: UIManager
var targeting_system: TargetingSystem
var combat_system: CombatSystem
var input_manager: InputManager

# Visual
var camera: Camera3D

# State
var selected_unit: Merc

func _ready() -> void:
	print("[ORCHESTRATOR] Initializing...")
	
	# Get Camera from Scene
	camera = $Camera3D
	if not camera:
		push_error("[ORCHESTRATOR] Camera3D not found in scene!")
		return
	
	# Initialize InputManager FIRST
	input_manager = InputManager.new()
	add_child(input_manager)
	print("[ORCHESTRATOR] InputManager ready")
	
	# Connect InputManager Signals
	_connect_input_signals()
	
	# Initialize Managers (Order matters!)
	grid_manager = GridManager.new()
	add_child(grid_manager)
	print("[ORCHESTRATOR] GridManager ready")
	
	game_scene_manager = GameSceneManager.new()
	add_child(game_scene_manager)
	print("[ORCHESTRATOR] GameSceneManager ready")
	
	unit_manager = UnitManager.new()
	add_child(unit_manager)
	print("[ORCHESTRATOR] UnitManager ready")
	
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	print("[ORCHESTRATOR] TurnManager ready")
	
	fow_system = FogOfWarSystem.new()
	add_child(fow_system)
	print("[ORCHESTRATOR] FogOfWarSystem ready")
	
	ui_manager = UIManager.new()
	add_child(ui_manager)
	print("[ORCHESTRATOR] UIManager ready")
	
	targeting_system = TargetingSystem.new()
	add_child(targeting_system)
	print("[ORCHESTRATOR] TargetingSystem ready")
	
	combat_system = CombatSystem.new()
	add_child(combat_system)
	print("[ORCHESTRATOR] CombatSystem ready")
	
	# Setup Game (wait for scene tree)
	await get_tree().process_frame
	
	# Setup Scene (creates visual grids)
	game_scene_manager.setup_scene(grid_manager)
	
	# Setup Units
	unit_manager.setup_units(grid_manager)
	
	# Set Manager References
	targeting_system.unit_manager = unit_manager
	combat_system.unit_manager = unit_manager
	combat_system.targeting_system = targeting_system
	combat_system.fow_system = fow_system
	
	# Register Units in TurnManager
	turn_manager.register_player_unit(unit_manager.get_player_unit())
	for enemy in unit_manager.get_all_enemies():
		turn_manager.register_enemy_unit(enemy)
	
	# Register Units in FOW System
	fow_system.register_player_unit(unit_manager.get_player_unit())
	for enemy in unit_manager.get_all_enemies():
		fow_system.register_enemy_unit(enemy)
	
	# Set player as selected
	selected_unit = unit_manager.get_player_unit()
	
	# Initialize FOW
	fow_system.update_visibility()
	
	print("[ORCHESTRATOR] Game ready!")

func _connect_input_signals() -> void:
	input_manager.rotation_left.connect(_on_rotation_left)
	input_manager.rotation_right.connect(_on_rotation_right)
	input_manager.stance_standing.connect(_on_stance_standing)
	input_manager.stance_crouched.connect(_on_stance_crouched)
	input_manager.stance_prone.connect(_on_stance_prone)
	input_manager.left_click.connect(_on_left_click)
	input_manager.right_click.connect(_on_right_click)
	input_manager.toggle_fov_visualizer.connect(_on_toggle_fov_visualizer)
	input_manager.toggle_floor.connect(_on_toggle_floor)
	input_manager.line_of_sight_test.connect(_on_line_of_sight_test)
	input_manager.fow_debug.connect(_on_fow_debug)
	input_manager.debug_report.connect(_on_debug_report)
	input_manager.show_help.connect(_on_show_help)
	input_manager.end_turn.connect(_on_end_turn)

func _on_rotation_left() -> void:
	var angle = selected_unit.facing_system.get_facing_angle() - 45.0
	selected_unit.facing_system.rotate_to_angle(angle)
	print("[INPUT] Rotated LEFT. Facing: " + str(selected_unit.facing_system.get_facing_angle()) + "°")

func _on_rotation_right() -> void:
	var angle = selected_unit.facing_system.get_facing_angle() + 45.0
	selected_unit.facing_system.rotate_to_angle(angle)
	print("[INPUT] Rotated RIGHT. Facing: " + str(selected_unit.facing_system.get_facing_angle()) + "°")

func _on_stance_standing() -> void:
	selected_unit.stance_system.change_stance(0)  # STANDING
	print("[INPUT] Stance: STANDING")

func _on_stance_crouched() -> void:
	selected_unit.stance_system.change_stance(1)  # CROUCHED
	print("[INPUT] Stance: CROUCHED")

func _on_stance_prone() -> void:
	selected_unit.stance_system.change_stance(2)  # PRONE
	print("[INPUT] Stance: PRONE")

func _on_left_click(mouse_pos: Vector2) -> void:
	var camera_ray = camera.project_ray_from_screen(mouse_pos)
	var space_state = get_world_3d().direct_space_state
	
	var query = PhysicsRayQueryParameters3D.create(camera_ray.origin, camera_ray.origin + camera_ray.normal * 1000)
	var result = space_state.intersect_ray(query)
	
	if result:
		var clicked_pos = result.position
		var grid_pos = grid_manager.world_to_grid(clicked_pos)
		print("[MOVEMENT] Clicked grid pos: " + str(grid_pos))

func _on_right_click(mouse_pos: Vector2) -> void:
	targeting_system.handle_right_click(camera, mouse_pos)

func _on_toggle_fov_visualizer() -> void:
	print("[INPUT] FOV Visualizer toggled")

func _on_toggle_floor() -> void:
	print("[INPUT] Floor switched")

func _on_line_of_sight_test() -> void:
	print("\n[LoS TEST] Testing Line of Sight from Player to all Enemies...")
	for enemy in unit_manager.get_all_enemies():
		var can_see = selected_unit.can_see_enemy(enemy)
		var result = "YES" if can_see else "NO"
		print("[LoS] Can player see " + enemy.merc_data.merc_name + "? " + result)

func _on_fow_debug() -> void:
	fow_system.debug_print_visibility()

func _on_debug_report() -> void:
	print("\n============================================================")
	print("[DEBUG] FULL COMBAT REPORT")
	print("============================================================")
	
	print("\n--- PLAYER ---")
	print("Name: " + selected_unit.merc_data.merc_name)
	print("Position: " + str(selected_unit.global_position))
	print("Stance: " + str(selected_unit.stance_system.current_stance))
	print("AP: " + str(selected_unit.action_point_component.current_ap) + "/" + str(selected_unit.action_point_component.max_ap))
	print("Health: Head=" + str(selected_unit.health_component.current_head) + " Thorax=" + str(selected_unit.health_component.current_thorax))
	
	var target_name = selected_unit.current_target.merc_data.merc_name if selected_unit.current_target else "None"
	print("Targeting: " + target_name)
	print("Invested AP: " + str(selected_unit.get_invested_ap()))
	print("Already Aimed: " + str(selected_unit.get_aimed_state()))
	
	print("\n--- ENEMIES ---")
	for i in range(unit_manager.get_all_enemies().size()):
		var enemy = unit_manager.get_all_enemies()[i]
		print("Enemy " + str(i) + ": " + enemy.merc_data.merc_name)
		print("  Pos: " + str(enemy.global_position))
		print("  HP: Head=" + str(enemy.health_component.current_head) + " Thorax=" + str(enemy.health_component.current_thorax))
		print("  Alive: " + str(enemy.is_alive()))
	
	print("\n============================================================\n")

func _on_show_help() -> void:
	print("\n============================================================")
	print("CONTROLS")
	print("============================================================")
	print("Q/E - Rotate Left/Right")
	print("1/2/3 - Stance (Standing/Crouched/Prone)")
	print("Left-Click - Move")
	print("Right-Click - Target & Aim")
	print("V - Toggle FOV Visualizer")
	print("TAB - Switch Floor")
	print("T - Line of Sight Test")
	print("F - FOW Debug")
	print("D - Full Debug Report")
	print("Space - End Turn")
	print("H - Show Help")
	print("============================================================\n")

func _on_end_turn() -> void:
	turn_manager.end_turn()

extends Node3D

var merc: Merc
var enemy: Merc
var grid_manager: GridManager
var turn_manager: TurnManager
var visual_grid: VisualGrid
var ui_panel: UnitInfoPanel
var target_ui: TargetSelectionPanel
var fov_visualizer: FOVVisualizer

var selected_unit: Merc = null

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("FOV GRID SYSTEM TEST")
	print("=".repeat(60))
	
	setup_scene()
	setup_units()
	start_game()
	print_controls()
	
	# Initial FOV Test
	await get_tree().create_timer(0.5).timeout
	test_fov_system()

func setup_scene() -> void:
	visual_grid = VisualGrid.new()
	visual_grid.grid_size = Vector2i(10, 10)
	add_child(visual_grid)
	
	fov_visualizer = FOVVisualizer.new()
	add_child(fov_visualizer)
	
	grid_manager = GridManager.new()
	grid_manager.set_grid_bounds(Vector2i(0, 0), Vector2i(10, 10))
	add_child(grid_manager)
	
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	
	var ui_scene = preload("res://scenes/ui/unit_info_panel.tscn")
	ui_panel = ui_scene.instantiate()
	add_child(ui_panel)
	
	var target_ui_scene = preload("res://scenes/ui/target_selection_panel.tscn")
	target_ui = target_ui_scene.instantiate()
	target_ui.body_part_selected.connect(_on_body_part_selected)
	add_child(target_ui)
	
	# NUR 1 hohe Wand in der Mitte
	spawn_cover(Vector2i(5, 5), "high")

func setup_units() -> void:
	var akm_weapon = load("res://resources/weapons/akm.tres")
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	
	# Nur 1 Spieler - kein Enemy!
	merc = merc_scene.instantiate()
	merc.merc_data = ivan_data
	merc.weapon_data = akm_weapon
	merc.is_player_unit = true
	merc.global_position = Vector3(0.5, 0, 0.5)
	add_child(merc)

func start_game() -> void:
	await get_tree().process_frame
	
	merc.initialize_movement(grid_manager)
	
	turn_manager.register_player_unit(merc)
	
	turn_manager.start_game()
	selected_unit = merc
	ui_panel.update_display(selected_unit)
	
	# Update FOV visualizer und aktiviere sofort
	fov_visualizer.set_visibility(true)
	fov_visualizer.update_fov_display(merc.fov_grid, grid_manager)

func spawn_cover(grid_pos: Vector2i, type: String) -> void:
	var cover_scene = preload("res://scenes/entities/CoverObject.tscn")
	var cover = cover_scene.instantiate()
	
	if type == "low":
		cover.cover_data = load("res://resources/cover/crate_low.tres")
	else:
		cover.cover_data = load("res://resources/cover/wall_high.tres")
	
	cover.grid_position = grid_pos
	cover.global_position = grid_manager.grid_to_world(grid_pos)
	
	add_child(cover)
	await get_tree().process_frame
	grid_manager.place_cover(grid_pos, cover)

func test_fov_system() -> void:
	print("\n" + "=".repeat(60))
	print("FOV SYSTEM TEST - SINGLE WALL SETUP")
	print("=".repeat(60))
	
	print("\n--- Player FOV Grid ---")
	print("Player position: ", merc.movement_component.current_grid_pos)
	print("Player facing: ", merc.facing_system.get_facing_angle(), "°")
	print("Player eye height: ", merc.stance_system.get_eye_height())
	print("Total visible tiles: ", merc.fov_grid.size())
	print("Wall position: (5, 5)")
	
	print("\n--- Visible Tiles (CLEAR & PARTIAL only) ---")
	var clear_count = 0
	var partial_count = 0
	var sample_clear = []
	var sample_partial = []
	
	for pos in merc.fov_grid:
		var level = merc.fov_grid[pos]
		if level == FOVGridSystem.VisibilityLevel.CLEAR:
			clear_count += 1
			if sample_clear.size() < 15:
				sample_clear.append(pos)
		elif level == FOVGridSystem.VisibilityLevel.PARTIAL:
			partial_count += 1
			if sample_partial.size() < 10:
				sample_partial.append(pos)
	
	print("  CLEAR tiles: ", clear_count)
	for pos in sample_clear:
		print("    ", pos)
	
	print("  PARTIAL tiles: ", partial_count)
	for pos in sample_partial:
		print("    ", pos)
	
	print("\n" + "=".repeat(60))
	print("FOV SYSTEM TEST COMPLETE")
	print("=".repeat(60) + "\n")

func print_controls() -> void:
	print("\n=== CONTROLS ===")
	print("MOVEMENT: Left Click")
	print("ROTATION: Q (Left 45°) | E (Right 45°) | R (Face Enemy)")
	print("STANCE: 1 (Stand) | 2 (Crouch) | 3 (Prone)")
	print("COMBAT: A (Aim) | F (Shoot)")
	print("DEBUG: T (Test FOV) | V (Toggle FOV Visualizer)")
	print("TURN: Space (End Turn)")
	print("=".repeat(60) + "\n")

func _input(event: InputEvent) -> void:
	if turn_manager.current_phase != TurnManager.TurnPhase.PLAYER:
		return
	
	if target_ui.visible:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click()
	
	if event is InputEventKey and event.pressed:
		handle_key_input(event.keycode)

func handle_key_input(key: int) -> void:
	match key:
		KEY_Q:
			if merc.rotate_to_angle(merc.facing_system.get_facing_angle() - 45.0):
				print("\n>>> ROTATED LEFT <<<")
				print("New facing: ", merc.facing_system.get_facing_angle(), "°")
				print("FOV updated: ", merc.fov_grid.size(), " tiles visible")
				fov_visualizer.update_fov_display(merc.fov_grid, grid_manager)
				ui_panel.update_display(merc)
		KEY_E:
			if merc.rotate_to_angle(merc.facing_system.get_facing_angle() + 45.0):
				print("\n>>> ROTATED RIGHT <<<")
				print("New facing: ", merc.facing_system.get_facing_angle(), "°")
				print("FOV updated: ", merc.fov_grid.size(), " tiles visible")
				fov_visualizer.update_fov_display(merc.fov_grid, grid_manager)
				ui_panel.update_display(merc)
		KEY_R:
			if merc.rotate_towards(enemy):
				print("\n>>> FACING ENEMY <<<")
				print("New facing: ", merc.facing_system.get_facing_angle(), "°")
				print("FOV updated: ", merc.fov_grid.size(), " tiles visible")
				fov_visualizer.update_fov_display(merc.fov_grid, grid_manager)
				ui_panel.update_display(merc)
		KEY_1:
			if merc.change_stance(StanceSystem.Stance.STANDING):
				print("\n>>> STANCE: STANDING <<<")
				print("Eye height: ", merc.stance_system.get_eye_height())
				print("FOV updated: ", merc.fov_grid.size(), " tiles visible")
				fov_visualizer.update_fov_display(merc.fov_grid, grid_manager)
				ui_panel.update_display(merc)
		KEY_2:
			if merc.change_stance(StanceSystem.Stance.CROUCHED):
				print("\n>>> STANCE: CROUCHED <<<")
				print("Eye height: ", merc.stance_system.get_eye_height())
				print("FOV updated: ", merc.fov_grid.size(), " tiles visible")
				fov_visualizer.update_fov_display(merc.fov_grid, grid_manager)
				ui_panel.update_display(merc)
		KEY_3:
			if merc.change_stance(StanceSystem.Stance.PRONE):
				print("\n>>> STANCE: PRONE <<<")
				print("Eye height: ", merc.stance_system.get_eye_height())
				print("FOV updated: ", merc.fov_grid.size(), " tiles visible")
				fov_visualizer.update_fov_display(merc.fov_grid, grid_manager)
				ui_panel.update_display(merc)
		KEY_A:
			if merc.aim():
				print("\n>>> AIMED <<<")
				ui_panel.update_display(merc)
		KEY_F:
			print("\n>>> F-KEY (Shoot disabled - no enemy) <<<")
		KEY_T:
			print("\n>>> MANUAL FOV TEST <<<")
			test_fov_system()
		KEY_V:
			fov_visualizer.toggle_visibility()
			if fov_visualizer.is_visible:
				fov_visualizer.update_fov_display(merc.fov_grid, grid_manager)
		KEY_SPACE:
			print("\n>>> END TURN <<<")
			turn_manager.end_turn()
			await get_tree().create_timer(0.5).timeout
			turn_manager.end_turn()
			ui_panel.update_display(merc)

func _on_body_part_selected(body_part: TargetingSystem.BodyPart) -> void:
	if merc.can_shoot(enemy):
		print("\n>>> SHOOTING <<<")
		var result = merc.shoot_at(enemy, body_part)
		print("Target: ", TargetingSystem.get_display_name(body_part))
		print("Hit: ", result.hit)
		print("Hit chance: ", result.hit_chance, "%")
		if result.hit:
			print("Damage: ", result.damage)
			if result.target_killed:
				print("*** ENEMY KILLED ***")
		ui_panel.update_display(merc)

func handle_click() -> void:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var plane = Plane(Vector3.UP, 0)
	var intersection = plane.intersects_ray(from, camera.project_ray_normal(mouse_pos))
	
	if intersection:
		var grid_pos = grid_manager.world_to_grid(intersection)
		if merc.can_move_to_grid(grid_pos) and merc.move_to_grid(grid_pos):
			print("\n>>> MOVED <<<")
			print("New position: ", grid_pos)
			print("FOV updated: ", merc.fov_grid.size(), " tiles visible")
			fov_visualizer.update_fov_display(merc.fov_grid, grid_manager)
			ui_panel.update_display(merc)

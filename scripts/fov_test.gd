extends Node3D

var merc: Merc
var enemy1: Merc
var enemy2: Merc
var enemy3: Merc
var enemy4: Merc
var all_enemies: Array[Merc] = []

var grid_manager: GridManager
var turn_manager: TurnManager
var visual_grids: Array[VisualGrid] = []
var ui_panel: UnitInfoPanel
var fov_visualizer: FOVVisualizer
var fow_system: FogOfWarSystem

func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("FOV TEST - CLEAN LAYOUT (5x 10x10 Grids - Floors 0-4)")
	print("=".repeat(70))
	
	var camera = get_node("Camera3D")
	if camera:
		camera.position = Vector3(5, 20, 20)
		camera.look_at(Vector3(5, 5, 5))
	
	setup_scene()
	setup_units()
	start_game()
	print_controls()
	
	await get_tree().create_timer(0.5).timeout
	test_los_system()

func _process(_delta: float) -> void:
	update_hover_highlight()

func update_hover_highlight() -> void:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var normal = camera.project_ray_normal(mouse_pos)
	
	# Clear alle anderen Floors
	for i in range(visual_grids.size()):
		if i != merc.viewing_floor:
			visual_grids[i].clear_highlight()
	
	# Plane auf aktueller viewing_floor Höhe
	var floor_height = merc.viewing_floor * grid_manager.FLOOR_HEIGHT
	var plane = Plane(Vector3.UP, floor_height)
	var intersection = plane.intersects_ray(from, normal)
	
	if intersection:
		# Grid-Position mit Floor-Offset (nutze GridManager Funktion!)
		var relative_grid_pos = grid_manager.world_to_grid_floor_relative(intersection, merc.viewing_floor)
		
		if grid_manager.is_grid_pos_in_floor(relative_grid_pos, merc.viewing_floor):
			var player_pos = merc.movement_component.current_grid_pos
			
			var dx = abs(relative_grid_pos.x - player_pos.x)
			var dy = abs(relative_grid_pos.y - player_pos.y)
			var distance = min(dx, dy) + abs(dx - dy)
			var ap_cost = distance * 2
			var ap_sufficient = merc.action_point_component.has_ap(ap_cost)
			
			visual_grids[merc.viewing_floor].update_highlight(relative_grid_pos, ap_sufficient)
		else:
			visual_grids[merc.viewing_floor].clear_highlight()
	else:
		visual_grids[merc.viewing_floor].clear_highlight()

func setup_scene() -> void:
	print("\n[SETUP] Creating 5x 10x10 Grids (Floors 0-4) NEBENEINANDER...")
	
	var grid_configs = [
		{"floor": 0, "pos": Vector2i(0, 0), "desc": "CENTER"},
		{"floor": 1, "pos": Vector2i(12, 0), "desc": "RECHTS"},
		{"floor": 2, "pos": Vector2i(0, 12), "desc": "OBEN"},
		{"floor": 3, "pos": Vector2i(-12, 0), "desc": "LINKS"},
		{"floor": 4, "pos": Vector2i(0, -12), "desc": "UNTEN"}
	]
	
	print("\n[SETUP] Creating Visual Grids (nebeneinander):")
	for config in grid_configs:
		var visual_grid = VisualGrid.new()
		visual_grid.grid_size = Vector2i(10, 10)
		visual_grid.floor = config.floor
		visual_grid.grid_position = config.pos
		visual_grid.tile_size = 1.0
		add_child(visual_grid)
		visual_grids.append(visual_grid)
		
		var floor_height = config.floor * 3.0
		print("  %s: 10x10 Grid at (%d,%d) Height: %.1fm" % [config.desc, config.pos.x, config.pos.y, floor_height])
	
	await get_tree().process_frame
	
	fov_visualizer = FOVVisualizer.new()
	add_child(fov_visualizer)
	
	grid_manager = GridManager.new()
	grid_manager.auto_calculate_bounds_from_grids(visual_grids, 5)
	add_child(grid_manager)
	
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	
	fow_system = FogOfWarSystem.new()
	fow_system.debug_mode = true
	add_child(fow_system)
	
	fow_system.enemy_revealed.connect(_on_enemy_revealed)
	fow_system.enemy_hidden.connect(_on_enemy_hidden)
	
	var ui_scene = preload("res://scenes/ui/unit_info_panel.tscn")
	ui_panel = ui_scene.instantiate()
	add_child(ui_panel)
	
	print("\n[SETUP] Scene ready - 5 Grids 10x10, Spieler Mitte (5,5) Floor 0, Gegner am Rand (0 oder 9) pro Floor")

func setup_units() -> void:
	var akm_weapon = load("res://resources/weapons/akm.tres")
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	
	merc = merc_scene.instantiate()
	merc.merc_data = ivan_data
	merc.weapon_data = akm_weapon
	merc.is_player_unit = true
	merc.global_position = Vector3(5.5, 0.0, 5.5)
	add_child(merc)
	
	enemy1 = merc_scene.instantiate()
	enemy1.merc_data = ivan_data.duplicate()
	enemy1.merc_data.merc_name = "Enemy 1 (Floor 1)"
	enemy1.weapon_data = akm_weapon.duplicate()
	enemy1.is_player_unit = false
	enemy1.global_position = Vector3(21.5, 3.0, 5.5)
	add_child(enemy1)
	
	enemy2 = merc_scene.instantiate()
	enemy2.merc_data = ivan_data.duplicate()
	enemy2.merc_data.merc_name = "Enemy 2 (Floor 2)"
	enemy2.weapon_data = akm_weapon.duplicate()
	enemy2.is_player_unit = false
	enemy2.global_position = Vector3(5.5, 6.0, 21.5)
	add_child(enemy2)
	
	enemy3 = merc_scene.instantiate()
	enemy3.merc_data = ivan_data.duplicate()
	enemy3.merc_data.merc_name = "Enemy 3 (Floor 3)"
	enemy3.weapon_data = akm_weapon.duplicate()
	enemy3.is_player_unit = false
	enemy3.global_position = Vector3(-10.5, 9.0, 5.5)
	add_child(enemy3)
	
	enemy4 = merc_scene.instantiate()
	enemy4.merc_data = ivan_data.duplicate()
	enemy4.merc_data.merc_name = "Enemy 4 (Floor 4)"
	enemy4.weapon_data = akm_weapon.duplicate()
	enemy4.is_player_unit = false
	enemy4.global_position = Vector3(5.5, 12.0, -10.5)
	add_child(enemy4)
	
	all_enemies = [enemy1, enemy2, enemy3, enemy4]
	
	print("\n>>> SETUP UNITS <<<")
	print("Player: Floor 0 CENTER at Grid(5,5)")
	print("Enemy 1: Floor 1 RECHTS at Grid(9,5)")
	print("Enemy 2: Floor 2 OBEN at Grid(5,9)")
	print("Enemy 3: Floor 3 LINKS at Grid(0,5)")
	print("Enemy 4: Floor 4 UNTEN at Grid(5,0)")
	print(">>> END SETUP <<<\n")

func start_game() -> void:
	await get_tree().process_frame
	
	merc.initialize_movement(grid_manager)
	turn_manager.register_player_unit(merc)
	fow_system.register_player_unit(merc)
	
	for enemy_unit in all_enemies:
		enemy_unit.initialize_movement(grid_manager)
		match all_enemies.find(enemy_unit):
			0: enemy_unit.movement_component.current_floor = 1
			1: enemy_unit.movement_component.current_floor = 2
			2: enemy_unit.movement_component.current_floor = 3
			3: enemy_unit.movement_component.current_floor = 4
		
		turn_manager.register_enemy_unit(enemy_unit)
		fow_system.register_enemy_unit(enemy_unit)
	
	turn_manager.start_game()
	ui_panel.update_display(merc)
	update_fov_visualization()
	update_fog_of_war()

func update_fog_of_war() -> void:
	fow_system.update_visibility()
	fow_system.apply_visibility_to_scene()
	
	print("\n[FOW UPDATE]")
	var stats = fow_system.get_visibility_stats()
	print("  Stats: %d/%d enemies visible (%.0f%%)" % [
		stats.visible,
		stats.total_enemies,
		stats.visibility_rate * 100.0
	])

func test_los_system() -> void:
	print("\n" + "=".repeat(70))
	print("LINE OF SIGHT TEST - ALL ENEMIES")
	print("=".repeat(70))
	
	for enemy in all_enemies:
		var enemy_floor = enemy.movement_component.current_floor
		var player_stance_name = _get_stance_name(merc.stance_system.current_stance)
		var enemy_stance_name = _get_stance_name(enemy.stance_system.current_stance)
		
		print("\n>>> Enemy: %s (Floor %d) <<<" % [enemy.merc_data.merc_name, enemy_floor])
		print("Player: %s (Stance: %s)" % [merc.movement_component.current_grid_pos, player_stance_name])
		print("Enemy: %s (Stance: %s)" % [enemy.movement_component.current_grid_pos, enemy_stance_name])
		print("Player Eye Height: %.2fm | Enemy Eye Height: %.2fm" % [
			merc.stance_system.get_eye_height(),
			enemy.stance_system.get_eye_height()
		])
		
		var can_see = merc.can_see_enemy(enemy)
		print("Can player see enemy? %s" % ("✅ YES" if can_see else "❌ NO"))
		
		if can_see:
			var visible_parts = merc.get_visible_body_parts(enemy)
			print("Visible body parts:")
			print("  HEAD: %s" % ("✅" if (visible_parts & LineOfSightSystem.BodyPartVisibility.HEAD) != 0 else "❌"))
			print("  TORSO: %s" % ("✅" if (visible_parts & LineOfSightSystem.BodyPartVisibility.TORSO) != 0 else "❌"))
			print("  LEGS: %s" % ("✅" if (visible_parts & LineOfSightSystem.BodyPartVisibility.LEGS) != 0 else "❌"))
		
		print("FOW Status: %s" % ("VISIBLE" if fow_system.is_enemy_visible(enemy) else "HIDDEN"))
	
	print("\n" + "=".repeat(70) + "\n")

func _get_stance_name(stance: StanceSystem.Stance) -> String:
	match stance:
		StanceSystem.Stance.STANDING:
			return "STANDING"
		StanceSystem.Stance.CROUCHED:
			return "CROUCHED"
		StanceSystem.Stance.PRONE:
			return "PRONE"
	return "UNKNOWN"

func print_controls() -> void:
	print("\n=== CONTROLS ===")
	print("MOVE: Left Click")
	print("ROTATE: Q (Left) | E (Right)")
	print("STANCE: 1 (Stand) | 2 (Crouch) | 3 (Prone)")
	print("TEST: T (Test all LoS) | F (FOW Debug)")
	print("=".repeat(70) + "\n")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click()
	
	if event is InputEventKey and event.pressed:
		handle_key_input(event.keycode)
	
	if event is InputEventKey and not event.echo:
		var camera = get_node("Camera3D")
		if camera:
			var move_speed = 0.5
			match event.keycode:
				KEY_UP:
					camera.position.z -= move_speed
					get_tree().root.set_input_as_handled()
				KEY_DOWN:
					camera.position.z += move_speed
					get_tree().root.set_input_as_handled()
				KEY_LEFT:
					camera.position.x -= move_speed
					get_tree().root.set_input_as_handled()
				KEY_RIGHT:
					camera.position.x += move_speed
					get_tree().root.set_input_as_handled()
				KEY_PAGEUP:
					camera.position.y += move_speed
					get_tree().root.set_input_as_handled()
				KEY_PAGEDOWN:
					camera.position.y -= move_speed
					get_tree().root.set_input_as_handled()

func handle_key_input(key: int) -> void:
	match key:
		KEY_TAB:
			merc.viewing_floor = (merc.viewing_floor + 1) % grid_manager.max_floors
			print("[FLOOR] Switched to Floor: %d" % merc.viewing_floor)
			get_tree().root.set_input_as_handled()
		KEY_Q:
			if merc.rotate_to_angle(merc.facing_system.get_facing_angle() - 45.0):
				print("PLAYER ROTATED LEFT")
				update_fov_visualization()
				update_fog_of_war()
				ui_panel.update_display(merc)
		KEY_E:
			if merc.rotate_to_angle(merc.facing_system.get_facing_angle() + 45.0):
				print("PLAYER ROTATED RIGHT")
				update_fov_visualization()
				update_fog_of_war()
				ui_panel.update_display(merc)
		KEY_1:
			if merc.change_stance(StanceSystem.Stance.STANDING):
				print("PLAYER STANCE: STANDING")
				update_fov_visualization()
				update_fog_of_war()
				ui_panel.update_display(merc)
				test_los_system()
		KEY_2:
			if merc.change_stance(StanceSystem.Stance.CROUCHED):
				print("PLAYER STANCE: CROUCHED")
				update_fov_visualization()
				update_fog_of_war()
				ui_panel.update_display(merc)
				test_los_system()
		KEY_3:
			if merc.change_stance(StanceSystem.Stance.PRONE):
				print("PLAYER STANCE: PRONE")
				update_fov_visualization()
				update_fog_of_war()
				ui_panel.update_display(merc)
				test_los_system()
		KEY_T:
			test_los_system()
		KEY_F:
			fow_system.debug_print_visibility()
		KEY_SPACE:
			turn_manager.end_turn()
			await get_tree().create_timer(0.5).timeout
			turn_manager.end_turn()
			ui_panel.update_display(merc)

func handle_click() -> void:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var normal = camera.project_ray_normal(mouse_pos)
	
	# Plane auf aktueller viewing_floor Höhe
	var floor_height = merc.viewing_floor * grid_manager.FLOOR_HEIGHT
	var plane = Plane(Vector3.UP, floor_height)
	var intersection = plane.intersects_ray(from, normal)
	
	if intersection:
		# Grid-Position mit Floor-Offset (relativ)
		var relative_grid_pos = grid_manager.world_to_grid_floor_relative(intersection, merc.viewing_floor)
		
		if grid_manager.is_grid_pos_in_floor(relative_grid_pos, merc.viewing_floor):
			# Berechne ABSOLUTE Grid-Position
			var floor_offset = visual_grids[merc.viewing_floor].grid_position
			var absolute_grid_pos = relative_grid_pos + floor_offset
			
			if merc.move_to_grid_absolute(absolute_grid_pos, merc.viewing_floor):
				print("PLAYER MOVED: %s (Floor %d)" % [absolute_grid_pos, merc.viewing_floor])
				update_fog_of_war()
				ui_panel.update_display(merc)
				test_los_system()

func update_fov_visualization() -> void:
	fov_visualizer.update_fov_display(merc, grid_manager)

func _on_enemy_revealed(enemy_unit: Merc) -> void:
	print("\n🔍 ENEMY REVEALED: %s" % enemy_unit.merc_data.merc_name)

func _on_enemy_hidden(enemy_unit: Merc) -> void:
	print("\n🌫️  ENEMY HIDDEN: %s" % enemy_unit.merc_data.merc_name)

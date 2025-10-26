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
var target_selection_ui: TargetSelectionPanel

func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("FOV TEST - NEW MAP STRUCTURE WITH FLOOR OBJECTS")
	print("Floor 0: 40x40 CENTER | Floors 1-4: 10x10 in CORNERS")
	print("=".repeat(70))
	
	var camera = get_node("Camera3D")
	if camera:
		camera.position = Vector3(5, 20, 20)
		camera.look_at(Vector3(5, 5, 5))
	
	setup_scene()
	setup_units()
	start_game()
	
	await get_tree().process_frame
	spawn_test_wall()
	
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
	
	for i in range(visual_grids.size()):
		if i != merc.viewing_floor:
			visual_grids[i].clear_highlight()
	
	var floor_height = merc.viewing_floor * grid_manager.FLOOR_HEIGHT
	var plane = Plane(Vector3.UP, floor_height)
	var intersection = plane.intersects_ray(from, normal)
	
	if intersection:
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
	print("\n[SETUP] NEW MAP STRUCTURE:")
	print("  Floor 0: 40x40 CENTER (gives bounds for all floors)")
	print("  Floors 1-4: 10x10 in CORNERS (no overlap with Floor 0)\n")
	
	var grid_configs = [
		{"floor": 0, "pos": Vector2i(0, 0), "size": Vector2i(40, 40), "desc": "CENTER 40x40", "floor_res": "Floor0_Grass"},
		{"floor": 1, "pos": Vector2i(0, 0), "size": Vector2i(10, 10), "desc": "TOP-LEFT 10x10 (ABOVE Floor 0)", "floor_res": "Floor1_Metal"},
		{"floor": 2, "pos": Vector2i(30, 0), "size": Vector2i(10, 10), "desc": "TOP-RIGHT 10x10 (ABOVE Floor 0)", "floor_res": "Floor2_Stone"},
		{"floor": 3, "pos": Vector2i(30, 30), "size": Vector2i(10, 10), "desc": "BOTTOM-RIGHT 10x10 (ABOVE Floor 0)", "floor_res": "Floor3_Wood"},
		{"floor": 4, "pos": Vector2i(0, 30), "size": Vector2i(10, 10), "desc": "BOTTOM-LEFT 10x10 (ABOVE Floor 0)", "floor_res": "Floor4_Ice"}
	]
	
	print("[SETUP] Creating Visual Grids with Floor Objects:")
	for config in grid_configs:
		var visual_grid = VisualGrid.new()
		visual_grid.grid_size = config.size
		visual_grid.floor = config.floor
		visual_grid.grid_position = config.pos
		visual_grid.tile_size = 1.0
		
		var floor_data_path = "res://resources/floors/%s.tres" % config.floor_res
		var floor_data = load(floor_data_path)
		if floor_data:
			visual_grid.floor_data = floor_data
			print("  [✓] %s: FloorData loaded from %s" % [config.desc, floor_data_path])
		else:
			print("  [✗] %s: WARNING - FloorData not found at %s" % [config.desc, floor_data_path])
		
		add_child(visual_grid)
		visual_grids.append(visual_grid)
		
		var floor_height = config.floor * 3.0
		print("  %s: %dx%d Grid at (%d,%d) Height: %.1fm" % [
			config.desc,
			config.size.x,
			config.size.y,
			config.pos.x,
			config.pos.y,
			floor_height
		])
	
	await get_tree().process_frame
	
	fov_visualizer = FOVVisualizer.new()
	add_child(fov_visualizer)
	print("[SETUP] FOVVisualizer created")
	
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
	
	# Target Selection UI
	var target_ui_scene = preload("res://scenes/ui/target_selection_panel.tscn")
	target_selection_ui = target_ui_scene.instantiate()
	add_child(target_selection_ui)
	target_selection_ui.body_part_selected.connect(_on_body_part_selected)
	target_selection_ui.hide()
	
	print("\n[SETUP] Map ready - 5 Floor Objects created with colored surfaces")

func setup_units() -> void:
	var akm_weapon = load("res://resources/weapons/akm.tres")
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	
	merc = merc_scene.instantiate()
	merc.merc_data = ivan_data
	merc.weapon_data = akm_weapon
	merc.is_player_unit = true
	merc.global_position = Vector3(20.5, 0.0, 20.5)
	add_child(merc)
	
	enemy1 = merc_scene.instantiate()
	enemy1.merc_data = ivan_data.duplicate()
	enemy1.merc_data.merc_name = "Enemy 1 (Floor 1 - AT WINDOW)"
	enemy1.weapon_data = akm_weapon.duplicate()
	enemy1.is_player_unit = false
	enemy1.global_position = Vector3(5.5, 3.0, 8.5)
	add_child(enemy1)
	
	enemy2 = merc_scene.instantiate()
	enemy2.merc_data = ivan_data.duplicate()
	enemy2.merc_data.merc_name = "Enemy 2 (Floor 2 - AT WINDOW)"
	enemy2.weapon_data = akm_weapon.duplicate()
	enemy2.is_player_unit = false
	enemy2.global_position = Vector3(30.5, 6.0, 5.5)
	add_child(enemy2)
	
	enemy3 = merc_scene.instantiate()
	enemy3.merc_data = ivan_data.duplicate()
	enemy3.merc_data.merc_name = "Enemy 3 (Floor 3 - AT WINDOW)"
	enemy3.weapon_data = akm_weapon.duplicate()
	enemy3.is_player_unit = false
	enemy3.global_position = Vector3(35.5, 9.0, 30.5)
	add_child(enemy3)
	
	enemy4 = merc_scene.instantiate()
	enemy4.merc_data = ivan_data.duplicate()
	enemy4.merc_data.merc_name = "Enemy 4 (Floor 4 - AT WINDOW)"
	enemy4.weapon_data = akm_weapon.duplicate()
	enemy4.is_player_unit = false
	enemy4.global_position = Vector3(9.5, 12.0, 35.5)
	add_child(enemy4)
	
	all_enemies = [enemy1, enemy2, enemy3, enemy4]
	
	print("\n>>> SETUP UNITS <<<")
	print("Player: Floor 0 CENTER at Grid(20,20) World(20.5, 0, 20.5)")
	print("Enemy 1: Floor 1 AT WINDOW Grid(5,9) World(5.5, 3, 9.5)")
	print("Enemy 2: Floor 2 AT WINDOW Grid(30,5) World(30.5, 6, 5.5)")
	print("Enemy 3: Floor 3 AT WINDOW Grid(35,30) World(35.5, 9, 30.5)")
	print("Enemy 4: Floor 4 AT WINDOW Grid(9,35) World(9.5, 12, 35.5)")
	print(">>> END SETUP <<<\n")

func spawn_test_wall() -> void:
	print("\n=== SPAWN COVER OBJECTS ===")
	
	var wall_cover_data = load("res://resources/cover/wall_high.tres")
	if not wall_cover_data:
		print("ERROR: wall_high.tres not found!")
		return
	
	var window_cover_data = load("res://resources/cover/crate_low.tres")
	if not window_cover_data:
		print("ERROR: crate_low.tres not found!")
		return
	
	print("  wall_high.tres loaded: Height=", wall_cover_data.cover_height, "m")
	print("  crate_low.tres loaded: Height=", window_cover_data.cover_height, "m (WINDOW)")
	
	var cover_scene = load("res://scenes/entities/CoverObject.tscn")
	if not cover_scene:
		print("ERROR: CoverObject.tscn not found!")
		return
	
	# Walls on Floor 0
	await spawn_house_walls_floor_0(cover_scene, wall_cover_data)
	
	# Windows on Floors 1-4
	print("\n>>> SPAWNING WINDOW RINGS ON FLOORS 1-4 <<<")
	
	print("\n[FLOOR 1] Spawning window ring...")
	spawn_window_ring(cover_scene, window_cover_data.duplicate(), 1, Vector2i(0, 0), 10, Color.RED)
	
	print("\n[FLOOR 2] Spawning window ring...")
	spawn_window_ring(cover_scene, window_cover_data.duplicate(), 2, Vector2i(30, 0), 10, Color.GREEN)
	
	print("\n[FLOOR 3] Spawning window ring...")
	spawn_window_ring(cover_scene, window_cover_data.duplicate(), 3, Vector2i(30, 30), 10, Color.YELLOW)
	
	print("\n[FLOOR 4] Spawning window ring...")
	spawn_window_ring(cover_scene, window_cover_data.duplicate(), 4, Vector2i(0, 30), 10, Color.MAGENTA)

func spawn_house_walls_floor_0(cover_scene: PackedScene, wall_cover_data: CoverData) -> void:
	print("\n>>> SPAWNING HIGH WALLS ON FLOOR 0 <<<")
	
	var wall_positions = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0),
		Vector2i(0, 1), Vector2i(9, 1),
		Vector2i(0, 2), Vector2i(9, 2),
		Vector2i(0, 3), Vector2i(9, 3),
		Vector2i(0, 4), Vector2i(9, 4),
		Vector2i(0, 5), Vector2i(9, 5),
		Vector2i(0, 6), Vector2i(9, 6),
		Vector2i(0, 7), Vector2i(9, 7),
		Vector2i(0, 8), Vector2i(9, 8),
		Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9), Vector2i(3, 9), Vector2i(4, 9),
		Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9)
	]
	
	print("  Spawning %d wall segments..." % wall_positions.size())
	
	for grid_pos in wall_positions:
		var wall = cover_scene.instantiate()
		wall.cover_data = wall_cover_data.duplicate()
		wall.grid_position = grid_pos
		
		var world_pos = grid_manager.grid_to_world_3d(grid_pos, 0)
		wall.global_position = world_pos
		add_child(wall)
		
		if wall.mesh_instance:
			wall.mesh_instance.mesh = wall.mesh_instance.mesh.duplicate()
		if wall.collision_shape:
			wall.collision_shape.shape = wall.collision_shape.shape.duplicate()
		
		if wall.mesh_instance:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color.GREEN
			wall.mesh_instance.material_override = mat
		
		grid_manager.place_cover_3d(grid_pos, 0, wall)
	
	print("  Floor 0: %d walls spawned" % wall_positions.size())

func spawn_window_ring(cover_scene: PackedScene, window_cover_data: CoverData, floor: int, offset: Vector2i, size: int, color: Color) -> void:
	var window_positions = []
	
	for x in range(size):
		window_positions.append(Vector2i(x, 0))
		window_positions.append(Vector2i(x, size - 1))
	for y in range(1, size - 1):
		window_positions.append(Vector2i(0, y))
		window_positions.append(Vector2i(size - 1, y))
	
	for grid_pos in window_positions:
		var absolute_pos = grid_pos + offset
		var window = cover_scene.instantiate()
		window.cover_data = window_cover_data.duplicate()
		window.grid_position = absolute_pos
		
		var world_pos = grid_manager.grid_to_world_3d(absolute_pos, floor)
		window.global_position = world_pos
		add_child(window)
		
		if window.mesh_instance:
			window.mesh_instance.mesh = window.mesh_instance.mesh.duplicate()
		if window.collision_shape:
			window.collision_shape.shape = window.collision_shape.shape.duplicate()
		
		if window.mesh_instance:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.5
			window.mesh_instance.material_override = mat
		
		grid_manager.place_cover_3d(absolute_pos, floor, window)
	
	print("  Floor %d: %d windows spawned" % [floor, window_positions.size()])

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
	print("[START_GAME] Calling update_fov_visualization()...")
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
	print("SHOOT: Right Click on Enemy")
	print("ROTATE: Q (Left) | E (Right)")
	print("STANCE: 1 (Stand) | 2 (Crouch) | 3 (Prone)")
	print("FOV VIS: V (Toggle FOV Visualizer)")
	print("FLOOR: TAB (Switch viewing floor)")
	print("TEST: T (Test all LoS) | F (FOW Debug)")
	print("=".repeat(70) + "\n")

func _input(event: InputEvent) -> void:
	# Wenn UI offen: Blockiere nur Movement/Camera Controls, NICHT Button Clicks
	if target_selection_ui and target_selection_ui.visible:
		# NICHT blocken: Button Clicks sollten durchkommen!
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			return
		
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			return
		
		# Blocke nur Keyboard für Movement
		if event is InputEventKey:
			get_tree().root.set_input_as_handled()
			return
		
		return
	
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				handle_click()
			MOUSE_BUTTON_RIGHT:
				handle_right_click()
	
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
			merc.update_fov_grids_3d()
			update_fov_visualization()
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
				print("[STANCE] Accuracy Bonus: 0%")
				update_fov_visualization()
				update_fog_of_war()
				ui_panel.update_display(merc)
				test_los_system()
		KEY_2:
			if merc.change_stance(StanceSystem.Stance.CROUCHED):
				print("PLAYER STANCE: CROUCHED")
				print("[STANCE] Accuracy Bonus: +20%")
				update_fov_visualization()
				update_fog_of_war()
				ui_panel.update_display(merc)
				test_los_system()
		KEY_3:
			if merc.change_stance(StanceSystem.Stance.PRONE):
				print("PLAYER STANCE: PRONE")
				print("[STANCE] Accuracy Bonus: +40%")
				update_fov_visualization()
				update_fog_of_war()
				ui_panel.update_display(merc)
				test_los_system()
		KEY_V:
			print("[KEY_V] Toggling FOV Visualizer...")
			fov_visualizer.toggle_visibility()
			update_fov_visualization()
			print("[KEY_V] FOV Visualizer toggle complete")
		KEY_T:
			test_los_system()
		KEY_F:
			fow_system.debug_print_visibility()
		KEY_SPACE:
			turn_manager.end_turn()
			await get_tree().create_timer(0.5).timeout
			turn_manager.end_turn()
			ui_panel.update_display(merc)
		KEY_D:
			# Test: Schuss im aktuellen Stance anschauen
			print("\n" + "=".repeat(70))
			print("STANCE ACCURACY TEST - Current Stance")
			print("=".repeat(70))
			for enemy in all_enemies:
				if merc.can_see_enemy(enemy):
					var chance = merc.combat_component.get_hit_chance_for_part(enemy, TargetingSystem.BodyPart.THORAX)
					print("vs %s: %.0f%% chance to hit THORAX" % [enemy.merc_data.merc_name, chance])
			print("=".repeat(70) + "\n")

func handle_click() -> void:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var normal = camera.project_ray_normal(mouse_pos)
	
	var floor_height = merc.viewing_floor * grid_manager.FLOOR_HEIGHT
	var plane = Plane(Vector3.UP, floor_height)
	var intersection = plane.intersects_ray(from, normal)
	
	if intersection:
		var relative_grid_pos = grid_manager.world_to_grid_floor_relative(intersection, merc.viewing_floor)
		
		if grid_manager.is_grid_pos_in_floor(relative_grid_pos, merc.viewing_floor):
			var floor_offset = visual_grids[merc.viewing_floor].grid_position
			var absolute_grid_pos = relative_grid_pos + floor_offset
			
			if merc.move_to_grid_absolute(absolute_grid_pos, merc.viewing_floor):
				print("PLAYER MOVED: %s (Floor %d)" % [absolute_grid_pos, merc.viewing_floor])
				update_fog_of_war()
				ui_panel.update_display(merc)
				test_los_system()
				update_fov_visualization()

func handle_right_click() -> void:
	"""Rechtsklick: Raycast auf Enemy, wenn sichtbar → Shooting Menu"""
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b10  # Layer 2 = Units
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		print("[RIGHT_CLICK] Nothing hit")
		return
	
	var collider = result.collider
	if not collider:
		return
	
	# Ist es ein Enemy?
	var target_enemy = null
	for enemy in all_enemies:
		if enemy.get_child(0) == collider or enemy == collider or enemy.is_ancestor_of(collider):
			target_enemy = enemy
			break
	
	if not target_enemy:
		print("[RIGHT_CLICK] Hit something but not an enemy")
		return
	
	print("[RIGHT_CLICK] Clicked on: %s" % target_enemy.merc_data.merc_name)
	
	# Prüfe: Can shoot?
	if not merc.can_shoot(target_enemy):
		print("[RIGHT_CLICK] Cannot shoot this target!")
		return
	
	# Öffne Shooting Menu
	target_selection_ui.show_target_selection(merc, target_enemy)

func _on_body_part_selected(body_part: TargetingSystem.BodyPart, target: Merc) -> void:
	"""UI: Body Part ausgewählt + Target übergeben → Schuss abfeuern"""
	print("\n[BODY_PART_SELECTED] Signal received!")
	print("  body_part: %s" % TargetingSystem.get_display_name(body_part))
	print("  target: %s" % (target.merc_data.merc_name if target else "NULL"))
	
	if not target:
		print("[BODY_PART_SELECTED] [✗] No target!")
		return
	
	if not merc.can_shoot(target):
		print("[BODY_PART_SELECTED] [✗] Cannot shoot!")
		return
	
	print("[BODY_PART_SELECTED] [✓] Shooting at: %s - %s" % [target.merc_data.merc_name, TargetingSystem.get_display_name(body_part)])
	
	var result = merc.shoot_at(target, body_part)
	print("[BODY_PART_SELECTED] Hit: %s | Damage: %d | Target Dead: %s" % [result.hit, result.damage, result.target_killed])
	
	ui_panel.update_display(merc)
	update_fog_of_war()
	print("[BODY_PART_SELECTED] Done\n")

func update_fov_visualization() -> void:
	print("[fov_test] === CALLING update_fov_visualization() ===")
	print("[fov_test] fov_visualizer is_visible: ", fov_visualizer.is_visible)
	print("[fov_test] merc: ", merc.merc_data.merc_name)
	print("[fov_test] merc.viewing_floor: ", merc.viewing_floor)
	print("[fov_test] merc.fov_grids.size(): ", merc.fov_grids.size())
	fov_visualizer.update_fov_display(merc, grid_manager)
	print("[fov_test] === END update_fov_visualization() ===\n")

func _on_enemy_revealed(enemy_unit: Merc) -> void:
	print("\n🔍 ENEMY REVEALED: %s" % enemy_unit.merc_data.merc_name)

func _on_enemy_hidden(enemy_unit: Merc) -> void:
	print("\n🌫️  ENEMY HIDDEN: %s" % enemy_unit.merc_data.merc_name)

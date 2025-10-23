extends Node3D

var merc: Merc
var enemy1: Merc
var enemy2: Merc
var enemy3: Merc
var enemy4: Merc
var all_enemies: Array[Merc] = []

var grid_manager: GridManager
var turn_manager: TurnManager
var visual_grid: VisualGrid
var ui_panel: UnitInfoPanel
var fov_visualizer: Node3D
var fow_system: FogOfWarSystem

func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("FOV TEST - CROSS LAYOUT (Floor 0 Center + 4 Etagen am Rand)")
	print("=".repeat(70))
	
	var camera = get_node("Camera3D")
	if camera:
		# Isometrische 2.5D Perspektive - höher und weiter weg um Floor 4 zu sehen
		camera.position = Vector3(10, 22, 22)
		camera.look_at(Vector3(10, 6, 10))
	
	setup_scene()
	setup_units()
	start_game()
	print_controls()
	
	await get_tree().create_timer(0.5).timeout
	test_los_system()

func setup_scene() -> void:
	# Cross Layout: Floor 0 Center (10x10) + 4 Etagen rundherum
	var grid_s = 20
	visual_grid = VisualGrid.new()
	visual_grid.grid_size = Vector2i(grid_s, grid_s)
	add_child(visual_grid)
	
	await get_tree().process_frame
	if visual_grid.mesh_instance and visual_grid.mesh_instance.material_override:
		visual_grid.mesh_instance.material_override.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	
	fov_visualizer = Node3D.new()
	add_child(fov_visualizer)
	
	grid_manager = GridManager.new()
	grid_manager.set_grid_bounds_3d(Vector2i(0, 0), Vector2i(grid_s, grid_s), 5)
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
	
	print("[SETUP] Cross Layout Map created (20x20 Grid, 5 Floors)")
	print("[SETUP] Floor 0: Center (spielbar)")
	print("[SETUP] Floor 1: Rechts (Enemies)")
	print("[SETUP] Floor 2: Unten (Enemies)")
	print("[SETUP] Floor 3: Links (Enemies)")
	print("[SETUP] Floor 4: Oben (Enemies)")

func setup_units() -> void:
	var akm_weapon = load("res://resources/weapons/akm.tres")
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	
	# Player auf Floor 0 Center
	merc = merc_scene.instantiate()
	merc.merc_data = ivan_data
	merc.weapon_data = akm_weapon
	merc.is_player_unit = true
	merc.global_position = Vector3(10.5, 0, 10.5)
	add_child(merc)
	
	# === ENEMIES AM RAND DER ETAGEN ===
	# Pro Floor: +3m Höhe
	
	# Enemy 1 - Floor 1 (RECHTS) am Rand - Höhe: 3m
	enemy1 = merc_scene.instantiate()
	enemy1.merc_data = ivan_data.duplicate()
	enemy1.merc_data.merc_name = "Enemy 1 (Floor 1 Right)"
	enemy1.weapon_data = akm_weapon.duplicate()
	enemy1.is_player_unit = false
	enemy1.global_position = Vector3(19.5, 3.0, 10.5)  # Floor 1 = +3m Höhe
	add_child(enemy1)
	
	# Enemy 2 - Floor 2 (UNTEN) am Rand - Höhe: 6m
	enemy2 = merc_scene.instantiate()
	enemy2.merc_data = ivan_data.duplicate()
	enemy2.merc_data.merc_name = "Enemy 2 (Floor 2 Bottom)"
	enemy2.weapon_data = akm_weapon.duplicate()
	enemy2.is_player_unit = false
	enemy2.global_position = Vector3(10.5, 6.0, 19.5)  # Floor 2 = +6m Höhe
	add_child(enemy2)
	
	# Enemy 3 - Floor 3 (LINKS) am Rand - Höhe: 9m
	enemy3 = merc_scene.instantiate()
	enemy3.merc_data = ivan_data.duplicate()
	enemy3.merc_data.merc_name = "Enemy 3 (Floor 3 Left)"
	enemy3.weapon_data = akm_weapon.duplicate()
	enemy3.is_player_unit = false
	enemy3.global_position = Vector3(0.5, 9.0, 10.5)  # Floor 3 = +9m Höhe
	add_child(enemy3)
	
	# Enemy 4 - Floor 4 (OBEN) am Rand - Höhe: 12m
	enemy4 = merc_scene.instantiate()
	enemy4.merc_data = ivan_data.duplicate()
	enemy4.merc_data.merc_name = "Enemy 4 (Floor 4 Top)"
	enemy4.weapon_data = akm_weapon.duplicate()
	enemy4.is_player_unit = false
	enemy4.global_position = Vector3(10.5, 12.0, 0.5)  # Floor 4 = +12m Höhe
	add_child(enemy4)
	
	all_enemies = [enemy1, enemy2, enemy3, enemy4]
	
	print("\n>>> SETUP <<<")
	print("Player: Floor 0 Center at (10, 10)")
	print("Enemy 1: Floor 1 (RIGHT) at (19, 10)")
	print("Enemy 2: Floor 2 (BOTTOM) at (10, 19)")
	print("Enemy 3: Floor 3 (LEFT) at (0, 10)")
	print("Enemy 4: Floor 4 (TOP) at (10, 0)")
	print(">>> END SETUP <<<\n")

func start_game() -> void:
	await get_tree().process_frame
	
	merc.initialize_movement(grid_manager)
	turn_manager.register_player_unit(merc)
	fow_system.register_player_unit(merc)
	
	for enemy_unit in all_enemies:
		enemy_unit.initialize_movement(grid_manager)
		# Setze Etagen
		match all_enemies.find(enemy_unit):
			0: enemy_unit.movement_component.current_floor = 1  # Enemy 1 = Floor 1
			1: enemy_unit.movement_component.current_floor = 2  # Enemy 2 = Floor 2
			2: enemy_unit.movement_component.current_floor = 3  # Enemy 3 = Floor 3
			3: enemy_unit.movement_component.current_floor = 4  # Enemy 4 = Floor 4
		
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
	if not turn_manager or turn_manager.current_phase != TurnManager.TurnPhase.PLAYER:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click()
	
	if event is InputEventKey and event.pressed:
		handle_key_input(event.keycode)

func handle_key_input(key: int) -> void:
	match key:
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
	var plane = Plane(Vector3.UP, 0)
	var intersection = plane.intersects_ray(from, camera.project_ray_normal(mouse_pos))
	
	if intersection:
		var grid_pos = grid_manager.world_to_grid(intersection)
		if merc.can_move_to_grid(grid_pos) and merc.move_to_grid(grid_pos):
			print("PLAYER MOVED: %s" % grid_pos)
			update_fov_visualization()
			update_fog_of_war()
			ui_panel.update_display(merc)
			test_los_system()

func update_fov_visualization() -> void:
	for child in fov_visualizer.get_children():
		child.queue_free()
	
	var mesh_instance = MeshInstance3D.new()
	fov_visualizer.add_child(mesh_instance)
	
	var immediate_mesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh
	
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	const BLOCKED = 0
	const PARTIAL = 1
	const CLEAR = 2
	
	for pos in merc.fov_grid:
		var visibility = merc.fov_grid[pos]
		var color: Color
		
		match visibility:
			BLOCKED:
				continue
			PARTIAL:
				color = Color(1.0, 1.0, 0.0, 0.4)
			CLEAR:
				color = Color(0.0, 1.0, 0.0, 0.4)
		
		_draw_tile(immediate_mesh, pos, color)
	
	immediate_mesh.surface_end()

func _draw_tile(mesh: ImmediateMesh, grid_pos: Vector2i, color: Color) -> void:
	var world_pos = grid_manager.grid_to_world(grid_pos)
	var tile_size = grid_manager.TILE_SIZE
	var height = 0.01
	
	var tl = Vector3(world_pos.x - tile_size * 0.5, height, world_pos.z - tile_size * 0.5)
	var tr = Vector3(world_pos.x + tile_size * 0.5, height, world_pos.z - tile_size * 0.5)
	var bl = Vector3(world_pos.x - tile_size * 0.5, height, world_pos.z + tile_size * 0.5)
	var br = Vector3(world_pos.x + tile_size * 0.5, height, world_pos.z + tile_size * 0.5)
	
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tl)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tr)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(bl)
	
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tr)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(br)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(bl)

func _on_enemy_revealed(enemy_unit: Merc) -> void:
	print("\n🔍 ENEMY REVEALED: %s" % enemy_unit.merc_data.merc_name)

func _on_enemy_hidden(enemy_unit: Merc) -> void:
	print("\n🌫️  ENEMY HIDDEN: %s" % enemy_unit.merc_data.merc_name)

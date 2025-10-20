extends Node3D

var merc: Merc
var grid_manager: GridManager
var turn_manager: TurnManager
var visual_grid: VisualGrid
var ui_panel: UnitInfoPanel
var fov_visualizer: Node3D  # Wird manuell erstellt

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("FOV GRID SYSTEM TEST - 21x21 Grid")
	print("=".repeat(60))
	
	# Kamera anpassen für 21x21 Grid (Mitte = 10,10)
	var camera = get_node("Camera3D")
	if camera:
		camera.position = Vector3(10.5, 20, 20)
		camera.look_at(Vector3(10.5, 0, 10.5))
	
	setup_scene()
	setup_units()
	start_game()
	print_controls()
	
	await get_tree().create_timer(0.5).timeout
	test_fov_system()

func setup_scene() -> void:
	visual_grid = VisualGrid.new()
	visual_grid.grid_size = Vector2i(21, 21)  # 21x21 für echte Mitte bei (10,10)
	add_child(visual_grid)
	
	# Ändere Grid-Farbe zu schwarz
	await get_tree().process_frame
	if visual_grid.mesh_instance and visual_grid.mesh_instance.material_override:
		visual_grid.mesh_instance.material_override.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	
	# Erstelle einfachen FOV Visualizer
	fov_visualizer = Node3D.new()
	add_child(fov_visualizer)
	
	grid_manager = GridManager.new()
	grid_manager.set_grid_bounds(Vector2i(0, 0), Vector2i(21, 21))
	add_child(grid_manager)
	
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	
	var ui_scene = preload("res://scenes/ui/unit_info_panel.tscn")
	ui_panel = ui_scene.instantiate()
	add_child(ui_panel)
	
	spawn_cover(Vector2i(10, 10), "high")  # Mitte bei (10,10)

func setup_units() -> void:
	var akm_weapon = load("res://resources/weapons/akm.tres")
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	
	merc = merc_scene.instantiate()
	merc.merc_data = ivan_data
	merc.weapon_data = akm_weapon
	merc.is_player_unit = true
	merc.global_position = Vector3(1.5, 0, 8.5)
	add_child(merc)

func start_game() -> void:
	await get_tree().process_frame
	
	merc.initialize_movement(grid_manager)
	turn_manager.register_player_unit(merc)
	turn_manager.start_game()
	
	ui_panel.update_display(merc)
	update_fov_visualization()

func spawn_cover(grid_pos: Vector2i, type: String) -> void:
	var cover_scene = preload("res://scenes/entities/CoverObject.tscn")
	var cover = cover_scene.instantiate()
	
	cover.cover_data = load("res://resources/cover/wall_high.tres")
	cover.grid_position = grid_pos
	cover.global_position = grid_manager.grid_to_world(grid_pos)
	
	add_child(cover)
	await get_tree().process_frame
	grid_manager.place_cover(grid_pos, cover)
	
	print("Cover placed at CENTER: ", grid_pos)

func test_fov_system() -> void:
	print("\n" + "=".repeat(60))
	print("FOV TEST - Single Wall at (10,10)")
	print("=".repeat(60))
	
	print("\nPlayer: ", merc.movement_component.current_grid_pos)
	print("Facing: ", merc.facing_system.get_facing_angle(), "°")
	print("Wall: (10,10)")
	
	print("\n>>> FORCING FOV RECALCULATION WITH DEBUG <<<")
	merc.update_fov_grid()
	
	var clear_tiles = []
	var partial_tiles = []
	var blocked_tiles = []
	
	const BLOCKED = 0
	const PARTIAL = 1
	const CLEAR = 2
	
	for pos in merc.fov_grid:
		var level = merc.fov_grid[pos]
		match level:
			CLEAR:
				clear_tiles.append(pos)
			PARTIAL:
				partial_tiles.append(pos)
			BLOCKED:
				blocked_tiles.append(pos)
	
	clear_tiles.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	partial_tiles.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	
	print("\nTotal visible tiles: ", merc.fov_grid.size())
	print("  CLEAR (GELB): ", clear_tiles.size())
	print("  PARTIAL (GRÜN): ", partial_tiles.size())
	print("  BLOCKED (ROT): ", blocked_tiles.size())
	
	print("\n--- CLEAR tiles (free sight) ---")
	_print_tile_list(clear_tiles)
	
	print("\n--- PARTIAL tiles (through cover) ---")
	_print_tile_list(partial_tiles)
	
	if blocked_tiles.size() > 0:
		print("\n--- BLOCKED tiles ---")
		_print_tile_list(blocked_tiles)
	
	print("\n" + "=".repeat(60) + "\n")

func _print_tile_list(tiles: Array) -> void:
	if tiles.size() == 0:
		print("  (none)")
		return
	
	var line = "  "
	for i in range(tiles.size()):
		line += str(tiles[i])
		if i < tiles.size() - 1:
			line += ", "
		
		if (i + 1) % 10 == 0 and i < tiles.size() - 1:
			print(line)
			line = "  "
	
	if line != "  ":
		print(line)

func print_controls() -> void:
	print("\n=== CONTROLS ===")
	print("MOVE: Left Click")
	print("ROTATE: Q (Left) | E (Right)")
	print("STANCE: 1 (Stand) | 2 (Crouch) | 3 (Prone)")
	print("DEBUG: T (Test FOV)")
	print("=".repeat(60) + "\n")

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
				print("ROTATED LEFT: ", merc.facing_system.get_facing_angle(), "°")
				update_fov_visualization()
				ui_panel.update_display(merc)
		KEY_E:
			if merc.rotate_to_angle(merc.facing_system.get_facing_angle() + 45.0):
				print("ROTATED RIGHT: ", merc.facing_system.get_facing_angle(), "°")
				update_fov_visualization()
				ui_panel.update_display(merc)
		KEY_1:
			if merc.change_stance(StanceSystem.Stance.STANDING):
				print("STANCE: STANDING")
				update_fov_visualization()
				ui_panel.update_display(merc)
		KEY_2:
			if merc.change_stance(StanceSystem.Stance.CROUCHED):
				print("STANCE: CROUCHED")
				update_fov_visualization()
				ui_panel.update_display(merc)
		KEY_3:
			if merc.change_stance(StanceSystem.Stance.PRONE):
				print("STANCE: PRONE")
				update_fov_visualization()
				ui_panel.update_display(merc)
		KEY_T:
			test_fov_system()
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
			print("MOVED: ", grid_pos)
			update_fov_visualization()
			ui_panel.update_display(merc)

func update_fov_visualization() -> void:
	# Lösche alte Visualisierung
	for child in fov_visualizer.get_children():
		child.queue_free()
	
	# Erstelle neue Visualisierung
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
				continue  # Skip blocked tiles
			PARTIAL:
				color = Color(0.0, 1.0, 0.0, 0.4)  # GRÜN = durch Deckung
			CLEAR:
				color = Color(1.0, 1.0, 0.0, 0.4)  # GELB = frei sichtbar
		
		_draw_tile(immediate_mesh, pos, color)
	
	immediate_mesh.surface_end()

func _draw_tile(mesh: ImmediateMesh, grid_pos: Vector2i, color: Color) -> void:
	var world_pos = grid_manager.grid_to_world(grid_pos)
	var tile_size = grid_manager.TILE_SIZE
	var height = 0.01  # Unter dem Grid (Grid ist bei 0.05)
	
	var tl = Vector3(world_pos.x - tile_size * 0.5, height, world_pos.z - tile_size * 0.5)
	var tr = Vector3(world_pos.x + tile_size * 0.5, height, world_pos.z - tile_size * 0.5)
	var bl = Vector3(world_pos.x - tile_size * 0.5, height, world_pos.z + tile_size * 0.5)
	var br = Vector3(world_pos.x + tile_size * 0.5, height, world_pos.z + tile_size * 0.5)
	
	# Triangle 1
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tl)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tr)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(bl)
	
	# Triangle 2
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tr)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(br)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(bl)

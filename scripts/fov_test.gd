extends Node3D

var merc: Merc
# var enemy: Merc # Ersetzt durch mehrere Gegner
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
var fow_system: FogOfWarSystem  # ← NEU: FOW System

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("FOW LABYRINTH TEST")
	print("Testing FOW/LoS with multiple enemies and complex cover")
	print("=".repeat(60))
	
	var camera = get_node("Camera3D")
	if camera:
		camera.position = Vector3(10.5, 25, 25)
		camera.look_at(Vector3(10.5, 0, 10.5))
	
	setup_scene()
	setup_units()
	start_game()
	print_controls()
	
	await get_tree().create_timer(0.5).timeout
	test_los_system() # Testet jetzt gegen Enemy1

func setup_scene() -> void:
	# Grid vergrößert, um Platz für Labyrinth zu schaffen
	var grid_s = 21
	visual_grid = VisualGrid.new()
	visual_grid.grid_size = Vector2i(grid_s, grid_s)
	add_child(visual_grid)
	
	await get_tree().process_frame
	if visual_grid.mesh_instance and visual_grid.mesh_instance.material_override:
		visual_grid.mesh_instance.material_override.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	
	fov_visualizer = Node3D.new()
	add_child(fov_visualizer)
	
	grid_manager = GridManager.new()
	grid_manager.set_grid_bounds(Vector2i(0, 0), Vector2i(grid_s, grid_s))
	add_child(grid_manager)
	
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	
	# ← NEU: FOW System initialisieren
	fow_system = FogOfWarSystem.new()
	fow_system.debug_mode = true
	add_child(fow_system)
	
	# ← NEU: FOW Signals verbinden
	fow_system.enemy_revealed.connect(_on_enemy_revealed)
	fow_system.enemy_hidden.connect(_on_enemy_hidden)
	
	var ui_scene = preload("res://scenes/ui/unit_info_panel.tscn")
	ui_panel = ui_scene.instantiate()
	add_child(ui_panel)
	
	# --- Labyrinth Setup ---
	print("Building labyrinth...")
	
	# Lange vertikale Wand (HOCH)
	for i in range(2, 16):
		spawn_cover(Vector2i(7, i), "high")
		
	# Lange horizontale Wand (HOCH)
	for i in range(8, 16):
		spawn_cover(Vector2i(i, 15), "high")

	# Untere horizontale Wand (NIEDRIG)
	for i in range(2, 10):
		spawn_cover(Vector2i(i, 8), "low")
		
	# Mittlere Box (NIEDRIG)
	spawn_cover(Vector2i(10, 12), "low")

	# Obere Gasse (NIEDRIG)
	spawn_cover(Vector2i(13, 18), "low")
	spawn_cover(Vector2i(15, 18), "low")
	spawn_cover(Vector2i(16, 18), "low")

	# Gegner-Nest 1 (HOCH)
	spawn_cover(Vector2i(10, 4), "high")
	spawn_cover(Vector2i(11, 4), "high")
	spawn_cover(Vector2i(10, 5), "high")
	
	# Gegner-Nest 2 (NIEDRIG)
	spawn_cover(Vector2i(17, 3), "low")
	spawn_cover(Vector2i(18, 3), "high") # Eine hohe Wand
	spawn_cover(Vector2i(17, 4), "low")
	
	print("Labyrinth built.")
	# --- Ende Labyrinth ---


func setup_units() -> void:
	var akm_weapon = load("res://resources/weapons/akm.tres")
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	
	# Player bei (2, 18) - Start-Ecke
	merc = merc_scene.instantiate()
	merc.merc_data = ivan_data
	merc.weapon_data = akm_weapon
	merc.is_player_unit = true
	merc.global_position = Vector3(2.5, 0, 18.5)
	add_child(merc)
	
	# --- Gegner Setup ---
	
	# Enemy 1 bei (10, 10) - HINTER NIEDRIGER DECKUNG (HOCKEND)
	enemy1 = merc_scene.instantiate()
	enemy1.merc_data = ivan_data.duplicate()
	enemy1.merc_data.merc_name = "Enemy 1 (Crouched)"
	enemy1.weapon_data = akm_weapon.duplicate()
	enemy1.is_player_unit = false
	enemy1.global_position = Vector3(10.5, 0, 10.5)
	add_child(enemy1)
	
	# Enemy 2 bei (17, 3) - IM NEST (LIEGEND)
	enemy2 = merc_scene.instantiate()
	enemy2.merc_data = ivan_data.duplicate()
	enemy2.merc_data.merc_name = "Enemy 2 (Prone)"
	enemy2.weapon_data = akm_weapon.duplicate()
	enemy2.is_player_unit = false
	enemy2.global_position = Vector3(17.5, 0, 3.5) # In der 17,3 / 17,4 Deckung
	add_child(enemy2)
	
	# Enemy 3 bei (19, 19) - OBEN RECHTS (STEHEND)
	enemy3 = merc_scene.instantiate()
	enemy3.merc_data = ivan_data.duplicate()
	enemy3.merc_data.merc_name = "Enemy 3 (Standing)"
	enemy3.weapon_data = akm_weapon.duplicate()
	enemy3.is_player_unit = false
	enemy3.global_position = Vector3(19.5, 0, 19.5)
	add_child(enemy3)
	
	# Enemy 4 bei (10, 5) - IM HOHEN NEST (STEHEND)
	enemy4 = merc_scene.instantiate()
	enemy4.merc_data = ivan_data.duplicate()
	enemy4.merc_data.merc_name = "Enemy 4 (High Cover)"
	enemy4.weapon_data = akm_weapon.duplicate()
	enemy4.is_player_unit = false
	enemy4.global_position = Vector3(10.5, 0, 5.5) # In der 10,5 Deckung
	add_child(enemy4)
	
	# Sammeln für einfaches Management
	all_enemies = [enemy1, enemy2, enemy3, enemy4]
	
	print("\n>>> SETUP <<<")
	print("Player: ", merc.merc_data.merc_name, " at (2, 18)")
	print("Enemy 1: ", enemy1.merc_data.merc_name, " at (10, 10) [CROUCHED]")
	print("Enemy 2: ", enemy2.merc_data.merc_name, " at (17, 3) [PRONE]")
	print("Enemy 3: ", enemy3.merc_data.merc_name, " at (19, 19) [STANDING]")
	print("Enemy 4: ", enemy4.merc_data.merc_name, " at (10, 5) [STANDING]")
	print(">>> END SETUP <<<\n")

func start_game() -> void:
	await get_tree().process_frame
	
	merc.initialize_movement(grid_manager)
	turn_manager.register_player_unit(merc)
	fow_system.register_player_unit(merc)
	
	# Alle Gegner initialisieren und registrieren
	for enemy_unit in all_enemies:
		enemy_unit.initialize_movement(grid_manager)
		turn_manager.register_enemy_unit(enemy_unit)
		fow_system.register_enemy_unit(enemy_unit)
	
	# Setze Stances NACH dem Initialisieren
	enemy1.change_stance(StanceSystem.Stance.CROUCHED)
	enemy2.change_stance(StanceSystem.Stance.PRONE)
	
	turn_manager.start_game()
	ui_panel.update_display(merc)
	update_fov_visualization()
	
	# ← NEU: Initiales FOW Update
	update_fog_of_war()

func spawn_cover(grid_pos: Vector2i, type: String) -> void:
	var cover_scene = preload("res://scenes/entities/CoverObject.tscn")
	var cover = cover_scene.instantiate()
	
	var cover_resource_path = "res://resources/cover/crate_low.tres" if type == "low" else "res://resources/cover/wall_high.tres"
	cover.cover_data = load(cover_resource_path)
	
	cover.grid_position = grid_pos
	
	# ===== KORREKTUR =====
	# 1. ERST HINZUFÜGEN
	add_child(cover)
	
	# 2. DANN GLOBALE POSITION SETZEN
	cover.global_position = grid_manager.grid_to_world(grid_pos)
	# =====================
	
	await get_tree().process_frame
	grid_manager.place_cover(grid_pos, cover)
	
	# Mache den Output leiser, damit wir die FOW-Tests sehen
	# var type_name = "LOW (0.8m)" if type == "low" else "HIGH (2.5m)"
	# print(type_name, " wall placed at: ", grid_pos)

# ← NEU: FOW Update Funktion
func update_fog_of_war() -> void:
	"""Update FOW and apply visibility to enemies"""
	fow_system.update_visibility()
	fow_system.apply_visibility_to_scene()
	
	# Debug output
	print("\n[FOW UPDATE]")
	# print("  Enemy visible: %s" % fow_system.is_enemy_visible(enemy1)) # Veraltet
	
	var stats = fow_system.get_visibility_stats()
	print("  Stats: %d/%d enemies visible (%.0f%%)" % [
		stats.visible,
		stats.total_enemies,
		stats.visibility_rate * 100.0
	])

func test_los_system() -> void:
	print("\n" + "=".repeat(60))
	print("LINE OF SIGHT TEST - (Testing vs Enemy 1)")
	print("=".repeat(60))
	
	var player_stance_name = _get_stance_name(merc.stance_system.current_stance)
	var enemy_stance_name = _get_stance_name(enemy1.stance_system.current_stance) # Testet gegen Enemy1
	
	print("\nPlayer: ", merc.movement_component.current_grid_pos, " (Stance: ", player_stance_name, ")")
	print("Enemy 1: ", enemy1.movement_component.current_grid_pos, " (Stance: ", enemy_stance_name, ")")
	# print("Wall: (10,10) - Height: 0.8m") # Veraltet
	print("Player Eye Height: ", merc.stance_system.get_eye_height(), "m")
	print("Enemy 1 Eye Height: ", enemy1.stance_system.get_eye_height(), "m")
	
	print("\n>>> TESTING VISIBILITY <<<")
	var can_see = merc.can_see_enemy(enemy1) # Testet gegen Enemy1
	print("Can player see enemy 1? ", can_see)
	
	if can_see:
		var visible_parts = merc.get_visible_body_parts(enemy1) # Testet gegen Enemy1
		print("Visible body parts (bitflags): ", visible_parts)
		print("  HEAD visible: ", (visible_parts & LineOfSightSystem.BodyPartVisibility.HEAD) != 0)
		print("  TORSO visible: ", (visible_parts & LineOfSightSystem.BodyPartVisibility.TORSO) != 0)
		print("  LEGS visible: ", (visible_parts & LineOfSightSystem.BodyPartVisibility.LEGS) != 0)
	
	# ← NEU: FOW Status anzeigen
	print("\n>>> FOG OF WAR STATUS (Enemy 1) <<<")
	print("Enemy 1 is %s in FOW" % ("VISIBLE" if fow_system.is_enemy_visible(enemy1) else "HIDDEN"))
	
	print(">>> END TEST <<<\n")
	print("=".repeat(60) + "\n")

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
	print("ENEMY 1 STANCE: 7 (Stand) | 8 (Crouch) | 9 (Prone)") # Aktualisiert
	print("DEBUG: T (Test LoS vs Enemy 1) | F (FOW Debug)")  # ← NEU: F für FOW Debug
	print("\nNOTE: Enemy capsules will be HIDDEN when not visible!")  # ← NEU
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
				print("PLAYER ROTATED LEFT: ", merc.facing_system.get_facing_angle(), "°")
				update_fov_visualization()
				update_fog_of_war()  # ← NEU: FOW Update
				ui_panel.update_display(merc)
		KEY_E:
			if merc.rotate_to_angle(merc.facing_system.get_facing_angle() + 45.0):
				print("PLAYER ROTATED RIGHT: ", merc.facing_system.get_facing_angle(), "°")
				update_fov_visualization()
				update_fog_of_war()  # ← NEU: FOW Update
				ui_panel.update_display(merc)
		KEY_1:
			if merc.change_stance(StanceSystem.Stance.STANDING):
				print("PLAYER STANCE: STANDING")
				update_fov_visualization()
				update_fog_of_war()  # ← NEU: FOW Update
				ui_panel.update_display(merc)
				test_los_system()
		KEY_2:
			if merc.change_stance(StanceSystem.Stance.CROUCHED):
				print("PLAYER STANCE: CROUCHED")
				update_fov_visualization()
				update_fog_of_war()  # ← NEU: FOW Update
				ui_panel.update_display(merc)
				test_los_system()
		KEY_3:
			if merc.change_stance(StanceSystem.Stance.PRONE):
				print("PLAYER STANCE: PRONE")
				update_fov_visualization()
				update_fog_of_war()  # ← NEU: FOW Update
				ui_panel.update_display(merc)
				test_los_system()
		KEY_7:
			if enemy1.change_stance(StanceSystem.Stance.STANDING): # Steuert Enemy1
				print("ENEMY 1 STANCE: STANDING")
				update_fog_of_war()  # ← NEU: FOW Update
				test_los_system()
		KEY_8:
			if enemy1.change_stance(StanceSystem.Stance.CROUCHED): # Steuert Enemy1
				print("ENEMY 1 STANCE: CROUCHED")
				update_fog_of_war()  # ← NEU: FOW Update
				test_los_system()
		KEY_9:
			if enemy1.change_stance(StanceSystem.Stance.PRONE): # Steuert Enemy1
				print("ENEMY 1 STANCE: PRONE")
				update_fog_of_war()  # ← NEU: FOW Update
				test_los_system()
		KEY_T:
			test_los_system()
		KEY_F:  # ← NEU: FOW Debug
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
			print("PLAYER MOVED: ", grid_pos)
			update_fov_visualization()
			update_fog_of_war()  # ← NEU: FOW Update
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
				# color = Color(0.0, 1.0, 0.0, 0.4) # Original Grün
				color = Color(1.0, 1.0, 0.0, 0.4) # Gelb für PARTIAL
			CLEAR:
				# color = Color(1.0, 1.0, 0.0, 0.4) # Original Gelb
				color = Color(0.0, 1.0, 0.0, 0.4) # Grün für CLEAR
		
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

# ← NEU: FOW Signal Callbacks
func _on_enemy_revealed(enemy_unit: Merc) -> void:
	print("\n🔍 ENEMY REVEALED: %s" % enemy_unit.merc_data.merc_name)

func _on_enemy_hidden(enemy_unit: Merc) -> void:
	print("\n🌫️  ENEMY HIDDEN: %s" % enemy_unit.merc_data.merc_name)

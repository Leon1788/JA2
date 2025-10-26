extends Node
class_name GameSceneManager

var visual_grids: Array[VisualGrid] = []
var grid_manager: GridManager
var fov_visualizer: FOVVisualizer

func setup_scene(grid_mgr: GridManager) -> void:
	print("\n" + "=".repeat(100))
	print("GAME SCENE SETUP")
	print("=".repeat(100) + "\n")
	
	grid_manager = grid_mgr
	
	_create_visual_grids()
	_create_fov_visualizer()
	_setup_lighting()
	_setup_camera()

func _setup_camera() -> void:
	"""Erstellt & positioniert Camera"""
	print("[SCENE] Setting up Camera...\n")
	
	var parent = get_parent()
	var existing_camera = parent.get_node_or_null("Camera3D")
	
	if not existing_camera:
		var camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.position = Vector3(20, 30, 20)
		camera.look_at(Vector3(20, 0, 20), Vector3.UP)
		camera.current = true
		parent.add_child(camera)
		print("[SCENE] Camera3D created at (20, 30, 20)\n")
	else:
		print("[SCENE] Camera3D already exists\n")

func _create_visual_grids() -> void:
	print("[SCENE] Creating Visual Grids...\n")
	
	var grid_configs = [
		{"desc": "Floor 0 - Main", "floor": 0, "pos": Vector2i(0, 0), "size": Vector2i(40, 40)},
		{"desc": "Floor 1 - NW", "floor": 1, "pos": Vector2i(0, 0), "size": Vector2i(10, 10)},
		{"desc": "Floor 2 - NE", "floor": 2, "pos": Vector2i(30, 0), "size": Vector2i(10, 10)},
		{"desc": "Floor 3 - SW", "floor": 3, "pos": Vector2i(0, 30), "size": Vector2i(10, 10)},
		{"desc": "Floor 4 - SE", "floor": 4, "pos": Vector2i(30, 30), "size": Vector2i(10, 10)},
	]
	
	for config in grid_configs:
		var visual_grid = VisualGrid.new()
		visual_grid.name = config.desc
		visual_grid.grid_size = config.size
		
		var floor_data_path = "res://resources/floors/floor_%d.tres" % config.floor
		var floor_data = load(floor_data_path)
		
		if floor_data:
			visual_grid.floor_data = floor_data
			print("  [✓] %s: %dx%d at (%d,%d) - FloorData loaded" % [
				config.desc, config.size.x, config.size.y, config.pos.x, config.pos.y])
		else:
			print("  [⚠] %s: %dx%d at (%d,%d) - WARNING: FloorData not found at %s" % [
				config.desc, config.size.x, config.size.y, config.pos.x, config.pos.y, floor_data_path])
		
		get_parent().add_child(visual_grid)
		visual_grids.append(visual_grid)
		
		var floor_height = config.floor * 3.0
		print("    Height: %.1fm\n" % floor_height)
	
	print("[SCENE] Visual Grids complete\n")

func _create_fov_visualizer() -> void:
	print("[SCENE] Creating FOV Visualizer...\n")
	
	fov_visualizer = FOVVisualizer.new()
	fov_visualizer.name = "FOVVisualizer"
	get_parent().add_child(fov_visualizer)
	
	print("[SCENE] FOV Visualizer created\n")

func _setup_lighting() -> void:
	print("[SCENE] Setting up Lighting...\n")
	
	# Prüfe ob bereits Light existiert
	var parent = get_parent()
	var existing_light = parent.get_node_or_null("DirectionalLight3D")
	
	if not existing_light:
		var light = DirectionalLight3D.new()
		light.name = "DirectionalLight3D"
		light.rotation = Vector3(-45, 45, 0) * PI / 180.0
		light.energy_multiplier = 1.5
		parent.add_child(light)
		print("[SCENE] DirectionalLight3D created\n")
	else:
		print("[SCENE] DirectionalLight3D already exists\n")

func get_visual_grids() -> Array[VisualGrid]:
	return visual_grids

func get_fov_visualizer() -> FOVVisualizer:
	return fov_visualizer

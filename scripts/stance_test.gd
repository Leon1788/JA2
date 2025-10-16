extends Node3D

var merc: Merc
var grid_manager: GridManager
var turn_manager: TurnManager
var visual_grid: VisualGrid
var ui_panel: UnitInfoPanel

func _ready() -> void:
	print("=== STANCE SYSTEM TEST START ===")
	
	# Erstelle Visual Grid
	visual_grid = VisualGrid.new()
	visual_grid.grid_size = Vector2i(10, 10)
	add_child(visual_grid)
	
	# Erstelle Grid Manager
	grid_manager = GridManager.new()
	grid_manager.set_grid_bounds(Vector2i(0, 0), Vector2i(10, 10))
	add_child(grid_manager)
	
	# Erstelle Turn Manager
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	
	# Lade UI
	var ui_scene = preload("res://scenes/ui/unit_info_panel.tscn")
	ui_panel = ui_scene.instantiate()
	add_child(ui_panel)
	
	# Lade Waffe
	var akm_weapon = load("res://resources/weapons/akm.tres")
	
	# Lade die Merc Scene für Spieler
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	merc = merc_scene.instantiate()
	
	# Lade die Ivan Resource
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	merc.merc_data = ivan_data
	merc.weapon_data = akm_weapon
	merc.is_player_unit = true
	merc.global_position = Vector3(5.5, 0, 5.5)
	
	add_child(merc)
	
	# Warte einen Frame
	await get_tree().process_frame
	
	# Initialisiere Movement
	merc.initialize_movement(grid_manager)
	
	# Registriere Units im Turn Manager
	turn_manager.register_player_unit(merc)
	
	# Start game
	turn_manager.start_game()
	ui_panel.update_display(merc)
	
	print("\n=== CONTROLS ===")
	print("LEFT CLICK: Move to tile")
	print("1: Stand")
	print("2: Crouch")
	print("3: Prone")
	print("SPACE: End turn")
	print("\nWatch the capsule height change!")

func _input(event: InputEvent) -> void:
	if turn_manager.current_phase != TurnManager.TurnPhase.PLAYER:
		return
	
	# Mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click()
	
	# Keyboard
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				if merc.change_stance(StanceSystem.Stance.STANDING):
					print("Changed to STANDING")
					ui_panel.update_display(merc)
			KEY_2:
				if merc.change_stance(StanceSystem.Stance.CROUCHED):
					print("Changed to CROUCHED")
					ui_panel.update_display(merc)
			KEY_3:
				if merc.change_stance(StanceSystem.Stance.PRONE):
					print("Changed to PRONE")
					ui_panel.update_display(merc)
			KEY_SPACE:
				print("End turn")
				turn_manager.end_turn()
				ui_panel.update_display(merc)

func handle_click() -> void:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		return
	
	# Check ground click for movement
	var plane = Plane(Vector3.UP, 0)
	var intersection = plane.intersects_ray(from, camera.project_ray_normal(mouse_pos))
	
	if intersection:
		var grid_pos = grid_manager.world_to_grid(intersection)
		print("Clicked grid: ", grid_pos)
		
		if merc and merc.is_alive():
			if merc.can_move_to_grid(grid_pos):
				if merc.move_to_grid(grid_pos):
					print("Moved to ", grid_pos)
					ui_panel.update_display(merc)
			else:
				print("Cannot move there")

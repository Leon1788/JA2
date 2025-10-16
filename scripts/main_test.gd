extends Node3D

var merc: Merc
var enemy: Merc
var grid_manager: GridManager
var turn_manager: TurnManager
var visual_grid: VisualGrid
var ui_panel: UnitInfoPanel
var target_ui: TargetSelectionPanel

var selected_unit: Merc = null

func _ready() -> void:
	print("=== MAIN TEST LEVEL ===")
	print("All features combined\n")
	
	setup_scene()
	setup_units()
	start_game()
	
	print_controls()

func setup_scene() -> void:
	# Visual Grid
	visual_grid = VisualGrid.new()
	visual_grid.grid_size = Vector2i(10, 10)
	add_child(visual_grid)
	
	# Grid Manager
	grid_manager = GridManager.new()
	grid_manager.set_grid_bounds(Vector2i(0, 0), Vector2i(10, 10))
	add_child(grid_manager)
	
	# Turn Manager
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	
	# UI
	var ui_scene = preload("res://scenes/ui/unit_info_panel.tscn")
	ui_panel = ui_scene.instantiate()
	add_child(ui_panel)
	
	var target_ui_scene = preload("res://scenes/ui/target_selection_panel.tscn")
	target_ui = target_ui_scene.instantiate()
	target_ui.body_part_selected.connect(_on_body_part_selected)
	add_child(target_ui)
	
	# Spawn Cover
	spawn_cover(Vector2i(3, 0), "low")
	spawn_cover(Vector2i(5, 2), "high")
	spawn_cover(Vector2i(2, 4), "low")

func setup_units() -> void:
	var akm_weapon = load("res://resources/weapons/akm.tres")
	var merc_scene = preload("res://scenes/entities/Merc.tscn")
	var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")
	
	# Player
	merc = merc_scene.instantiate()
	merc.merc_data = ivan_data
	merc.weapon_data = akm_weapon
	merc.is_player_unit = true
	merc.global_position = Vector3(0.5, 0, 0.5)
	add_child(merc)
	
	# Enemy
	enemy = merc_scene.instantiate()
	enemy.merc_data = ivan_data.duplicate()
	enemy.merc_data.merc_name = "Enemy Soldier"
	enemy.weapon_data = akm_weapon.duplicate()
	enemy.is_player_unit = false
	enemy.global_position = Vector3(7.5, 0, 0.5)
	add_child(enemy)

func start_game() -> void:
	await get_tree().process_frame
	
	merc.initialize_movement(grid_manager)
	enemy.initialize_movement(grid_manager)
	
	turn_manager.register_player_unit(merc)
	turn_manager.register_enemy_unit(enemy)
	
	turn_manager.start_game()
	selected_unit = merc
	ui_panel.update_display(selected_unit)

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

func print_controls() -> void:
	print("\n=== CONTROLS ===")
	print("MOVEMENT: Left Click")
	print("ROTATION: Q (Left 45°) | E (Right 45°) | R (Face Enemy)")
	print("STANCE: 1 (Stand) | 2 (Crouch) | 3 (Prone)")
	print("COMBAT: A (Aim) | F (Shoot)")
	print("TURN: Space (End Turn)")

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
			if merc.facing_system.rotate_to_angle(merc.facing_system.get_facing_angle() - 45.0):
				print("Rotated LEFT")
				ui_panel.update_display(merc)
		KEY_E:
			if merc.facing_system.rotate_to_angle(merc.facing_system.get_facing_angle() + 45.0):
				print("Rotated RIGHT")
				ui_panel.update_display(merc)
		KEY_R:
			if merc.facing_system.rotate_towards_target(enemy):
				print("Facing enemy")
				ui_panel.update_display(merc)
		KEY_1:
			if merc.change_stance(StanceSystem.Stance.STANDING):
				print("STANDING")
				ui_panel.update_display(merc)
		KEY_2:
			if merc.change_stance(StanceSystem.Stance.CROUCHED):
				print("CROUCHED")
				ui_panel.update_display(merc)
		KEY_3:
			if merc.change_stance(StanceSystem.Stance.PRONE):
				print("PRONE")
				ui_panel.update_display(merc)
		KEY_A:
			if merc.aim():
				print("Aimed!")
				ui_panel.update_display(merc)
		KEY_F:
			if merc.can_shoot(enemy):
				target_ui.show_target_selection(merc, enemy)
		KEY_SPACE:
			print("End turn")
			turn_manager.end_turn()
			await get_tree().create_timer(0.5).timeout
			turn_manager.end_turn()
			ui_panel.update_display(merc)

func _on_body_part_selected(body_part: TargetingSystem.BodyPart) -> void:
	if merc.can_shoot(enemy):
		var result = merc.shoot_at(enemy, body_part)
		print("Shot! Hit=", result.hit, " Chance=", result.hit_chance, "%")
		if result.hit and result.target_killed:
			print("ENEMY KILLED!")
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
			print("Moved to ", grid_pos)
			ui_panel.update_display(merc)

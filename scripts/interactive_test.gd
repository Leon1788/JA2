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
	print("=== INTERACTIVE TEST START (PHASE 1.5 - TARGETING) ===")
	
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
	
	# Lade Target Selection UI
	var target_ui_scene = preload("res://scenes/ui/target_selection_panel.tscn")
	target_ui = target_ui_scene.instantiate()
	target_ui.body_part_selected.connect(_on_body_part_selected)
	add_child(target_ui)
	
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
	merc.global_position = Vector3(0.5, 0, 0.5)
	
	add_child(merc)
	
	# Erstelle Gegner
	enemy = merc_scene.instantiate()
	enemy.merc_data = ivan_data.duplicate()
	enemy.merc_data.merc_name = "Enemy Soldier"
	enemy.weapon_data = akm_weapon.duplicate()
	enemy.is_player_unit = false
	enemy.global_position = Vector3(5.5, 0, 0.5)
	
	add_child(enemy)
	
	# Warte einen Frame
	await get_tree().process_frame
	
	# Initialisiere Movement
	merc.initialize_movement(grid_manager)
	enemy.initialize_movement(grid_manager)
	
	# Registriere Units im Turn Manager
	turn_manager.register_player_unit(merc)
	turn_manager.register_enemy_unit(enemy)
	
	# Start game
	turn_manager.start_game()
	selected_unit = merc
	ui_panel.update_display(selected_unit)
	
	print("\n=== CONTROLS ===")
	print("LEFT CLICK: Select unit / Move to tile")
	print("A: Aim")
	print("F: Shoot at enemy (opens target selection)")
	print("SPACE: End turn")
	print("TAB: Switch selected unit")
	print("\nNOTE: Player is BLUE, Enemy is RED")

func _input(event: InputEvent) -> void:
	if turn_manager.current_phase != TurnManager.TurnPhase.PLAYER:
		return
	
	# Block input wenn Target Selection UI offen ist
	if target_ui.visible:
		return
	
	# Mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click()
	
	# Keyboard
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_A:
				if selected_unit and selected_unit.is_alive():
					if selected_unit.aim():
						print("Aimed! Bonus: +10")
						ui_panel.update_display(selected_unit)
			KEY_F:
				if selected_unit and selected_unit.is_alive() and selected_unit.can_shoot(enemy):
					# Open target selection UI
					target_ui.show_target_selection(selected_unit, enemy)
				elif not enemy.is_alive():
					print("Enemy is already dead!")
			KEY_SPACE:
				print("End turn")
				turn_manager.end_turn()
				await get_tree().create_timer(0.5).timeout
				turn_manager.end_turn()  # Skip enemy turn
				ui_panel.update_display(selected_unit)
			KEY_TAB:
				if selected_unit == merc:
					selected_unit = enemy
				else:
					selected_unit = merc
				ui_panel.update_display(selected_unit)
				print("Selected: ", selected_unit.merc_data.merc_name, " (Alive: ", selected_unit.is_alive(), ")")

func _on_body_part_selected(body_part: TargetingSystem.BodyPart) -> void:
	if selected_unit and selected_unit.can_shoot(enemy):
		var part_name = TargetingSystem.get_display_name(body_part)
		print("\nShooting at: ", part_name)
		
		var result = selected_unit.shoot_at(enemy, body_part)
		print("Shot! Hit=", result.hit, " Chance=", result.hit_chance, "%")
		if result.hit:
			print("  Damage: ", result.damage, " to ", result.body_part)
			print("  Enemy ", result.body_part, " HP: ", _get_body_part_hp(enemy, result.body_part))
			if result.target_killed:
				print("  *** ENEMY KILLED ***")
		ui_panel.update_display(selected_unit)

func _get_body_part_hp(unit: Merc, part_name: String) -> int:
	match part_name:
		"head": return unit.health_component.current_head
		"thorax": return unit.health_component.current_thorax
		"stomach": return unit.health_component.current_stomach
		"left_arm": return unit.health_component.current_left_arm
		"right_arm": return unit.health_component.current_right_arm
		"left_leg": return unit.health_component.current_left_leg
		"right_leg": return unit.health_component.current_right_leg
	return 0

func handle_click() -> void:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		return  # Hit something, ignore for now
	
	# Check ground click for movement
	var plane = Plane(Vector3.UP, 0)
	var intersection = plane.intersects_ray(from, camera.project_ray_normal(mouse_pos))
	
	if intersection:
		var grid_pos = grid_manager.world_to_grid(intersection)
		print("Clicked grid: ", grid_pos)
		
		if selected_unit and selected_unit == merc and selected_unit.is_alive():
			if selected_unit.can_move_to_grid(grid_pos):
				if selected_unit.move_to_grid(grid_pos):
					print("Moved to ", grid_pos)
					ui_panel.update_display(selected_unit)
			else:
				print("Cannot move there")

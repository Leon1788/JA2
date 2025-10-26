extends Node
class_name UIManager

# Component References
var unit_manager: UnitManager
var grid_manager: GridManager
var fow_system: Node = null
var fov_visualizer: FOVVisualizer = null
var ui_panel: Node = null

func _ready() -> void:
	print("[UIManager] Initialized\n")

func initialize_ui() -> void:
	"""Initialisiert UI Components"""
	print("[UIManager] Initializing UI...\n")
	
	_setup_unit_info_panel()
	
	print("[UIManager] UI initialization complete\n")

func _setup_unit_info_panel() -> void:
	"""Lädt & erstellt Unit Info Panel"""
	var ui_scene = preload("res://scenes/ui/unit_info_panel.tscn")
	
	if ui_scene:
		ui_panel = ui_scene.instantiate()
		ui_panel.name = "UnitInfoPanel"
		get_parent().add_child(ui_panel)
		print("  ✓ UnitInfoPanel created\n")
	else:
		print("  ⚠ UnitInfoPanel scene not found\n")

# ===== MAIN UPDATE FUNCTIONS =====

func update_all() -> void:
	"""Master update: Alles updaten"""
	update_unit_info()
	update_fov_visualization()
	update_fog_of_war()

func update_unit_info() -> void:
	"""Updated Unit Info Panel mit aktuellem Player"""
	if not unit_manager:
		return
	
	var player = unit_manager.get_player_unit()
	if player and ui_panel:
		ui_panel.update_display(player)

func update_fov_visualization() -> void:
	"""Updated FOV Visualizer für Current Floor"""
	if not fov_visualizer or not unit_manager or not grid_manager:
		return
	
	var player = unit_manager.get_player_unit()
	if player:
		fov_visualizer.update_fov_display(player, grid_manager)

func update_fog_of_war() -> void:
	"""Updated FOW System & Visibility"""
	if not fow_system:
		return
	
	print("[FOW] Updating Fog of War...")
	fow_system.update_visibility()
	fow_system.apply_visibility_to_scene()
	
	var stats = fow_system.get_visibility_stats()
	print("[FOW] %d/%d enemies visible (%.0f%%)" % [
		stats.visible,
		stats.total_enemies,
		stats.visibility_rate * 100.0
	])

# ===== DEBUG & TESTING =====

func test_los_system() -> void:
	"""Debug: Test Line of Sight für alle Enemies"""
	if not unit_manager:
		return
	
	var player = unit_manager.get_player_unit()
	var enemies = unit_manager.get_all_enemies()
	
	if not player:
		print("[UIManager] No player unit!")
		return
	
	print("\n" + "=".repeat(100))
	print("LINE OF SIGHT TEST - ALL ENEMIES")
	print("=".repeat(100) + "\n")
	
	for enemy in enemies:
		var enemy_floor = enemy.movement_component.current_floor
		var player_stance_name = _get_stance_name(player.stance_system.current_stance)
		var enemy_stance_name = _get_stance_name(enemy.stance_system.current_stance)
		
		print(">>> Enemy: %s (Floor %d) <<<" % [enemy.merc_data.merc_name, enemy_floor])
		print("  Player: %s (Stance: %s)" % [player.movement_component.current_grid_pos, player_stance_name])
		print("  Enemy: %s (Stance: %s)" % [enemy.movement_component.current_grid_pos, enemy_stance_name])
		print("  Player Eye Height: %.2fm | Enemy Eye Height: %.2fm" % [
			player.stance_system.get_eye_height(),
			enemy.stance_system.get_eye_height()
		])
		
		var can_see = player.can_see_enemy(enemy)
		print("  Can player see enemy? %s" % ("✅ YES" if can_see else "❌ NO"))
		
		if can_see:
			var visible_parts = player.get_visible_body_parts(enemy)
			print("  Visible body parts:")
			print("    HEAD: %s" % ("✅" if (visible_parts & 1) != 0 else "❌"))
			print("    TORSO: %s" % ("✅" if (visible_parts & 2) != 0 else "❌"))
			print("    LEGS: %s" % ("✅" if (visible_parts & 4) != 0 else "❌"))
		
		var fow_visible = "VISIBLE" if fow_system and fow_system.is_enemy_visible(enemy) else "HIDDEN"
		print("  FOW Status: %s" % fow_visible)
		print()
	
	print("=".repeat(100) + "\n")

func print_ui_status() -> void:
	"""Debug: Print UI Status"""
	print("\n" + "=".repeat(100))
	print("UI STATUS REPORT")
	print("=".repeat(100) + "\n")
	
	print("[COMPONENTS]")
	print("  UI Panel: %s" % ("✓ Loaded" if ui_panel else "✗ Not Loaded"))
	print("  FOV Visualizer: %s" % ("✓ Loaded" if fov_visualizer else "✗ Not Loaded"))
	print("  FOW System: %s" % ("✓ Loaded" if fow_system else "✗ Not Loaded"))
	print("  Grid Manager: %s" % ("✓ Loaded" if grid_manager else "✗ Not Loaded"))
	print("  Unit Manager: %s" % ("✓ Loaded" if unit_manager else "✗ Not Loaded"))
	
	if unit_manager:
		var player = unit_manager.get_player_unit()
		var enemies = unit_manager.get_all_enemies()
		
		print("\n[UNITS]")
		print("  Player: %s" % ("✓ Present" if player else "✗ Missing"))
		print("  Enemies: %d total" % enemies.size())
		
		if player:
			print("\n[PLAYER STATUS]")
			print("  Name: %s" % player.merc_data.merc_name)
			if player.health_component:
				print("  Health: Head=%d Thorax=%d Stomach=%d" % [
					player.health_component.current_head,
					player.health_component.current_thorax,
					player.health_component.current_stomach
				])
			if player.action_point_component:
				print("  AP: %d/%d" % [player.action_point_component.current_ap, player.action_point_component.max_ap])
			if player.movement_component:
				print("  Position: %s (Floor %d)" % [player.movement_component.current_grid_pos, player.movement_component.current_floor])
			if player.stance_system:
				print("  Stance: %s" % _get_stance_name(player.stance_system.current_stance))
			if player.facing_system:
				print("  Facing: %.0f°" % player.facing_system.get_facing_angle())
	
	if fow_system:
		print("\n[FOW]")
		var stats = fow_system.get_visibility_stats()
		print("  Enemies Visible: %d/%d (%.0f%%)" % [
			stats.visible,
			stats.total_enemies,
			stats.visibility_rate * 100.0
		])
	
	print("\n" + "=".repeat(100) + "\n")

# ===== UTILITY FUNCTIONS =====

func _get_stance_name(stance: int) -> String:
	"""Debug Helper"""
	match stance:
		0:
			return "STANDING"
		1:
			return "CROUCHED"
		2:
			return "PRONE"
	return "UNKNOWN"

func toggle_fov_visualizer() -> void:
	"""Toggle FOV Visualizer Visibility"""
	if fov_visualizer:
		fov_visualizer.toggle_visibility()
		print("[UI] FOV Visualizer toggled")

func toggle_fow_debug_mode() -> void:
	"""Toggle FOW Debug Mode"""
	if fow_system:
		fow_system.debug_mode = !fow_system.debug_mode
		print("[UI] FOW Debug Mode: %s" % ("ON" if fow_system.debug_mode else "OFF"))

func print_fov_debug_info() -> void:
	"""Debug: Print FOV Information für aktuellem Floor"""
	if not unit_manager or not grid_manager:
		return
	
	var player = unit_manager.get_player_unit()
	if not player:
		return
	
	print("\n" + "=".repeat(100))
	print("FOV DEBUG INFO - Player Floor %d" % player.viewing_floor)
	print("=".repeat(100) + "\n")
	
	var fov_for_floor = player.get_fov_for_viewing_floor()
	
	print("  Current Floor: %d" % player.viewing_floor)
	print("  FOV Tiles on Floor: %d" % fov_for_floor.size())
	print("  Player Position: %s" % player.movement_component.current_grid_pos)
	print("  Player Facing: %.0f°" % player.facing_system.get_facing_angle())
	print("  Player Stance: %s" % _get_stance_name(player.stance_system.current_stance))
	
	print("\n[VISIBLE ENEMIES ON THIS FLOOR]")
	var visible_count = 0
	for enemy in unit_manager.get_all_enemies():
		if enemy.movement_component.current_floor == player.viewing_floor:
			var can_see = player.can_see_enemy(enemy)
			if can_see:
				visible_count += 1
				print("  ✓ %s at %s" % [enemy.merc_data.merc_name, enemy.movement_component.current_grid_pos])
			else:
				print("  ✗ %s at %s (blocked)" % [enemy.merc_data.merc_name, enemy.movement_component.current_grid_pos])
	
	print("\n  Total Visible: %d" % visible_count)
	print("\n" + "=".repeat(100) + "\n")

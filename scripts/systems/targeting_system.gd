extends Node
class_name TargetingSystem

# Constants - Body Parts
enum BodyPart {
	HEAD,
	THORAX,
	STOMACH,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG
}

# Component References
var unit_manager: UnitManager
var targeting_panel: Node = null
var combat_system: Node = null

# Targeting State
var current_shooter: Merc = null
var current_target: Merc = null
var is_ui_open: bool = false

# Signal
signal body_part_selected(body_part: BodyPart, target: Merc)

func _ready() -> void:
	print("[TargetingSystem] Initialized\n")

func handle_right_click(camera: Camera3D, mouse_pos: Vector2) -> void:
	"""Haupteingabe für Right-Click"""
	if not unit_manager:
		print("[TargetingSystem] ERROR: unit_manager not set!")
		return
	
	var shooter = unit_manager.get_player_unit()
	if not shooter:
		print("[TargetingSystem] ERROR: No player unit!")
		return
	
	# Raycast auf 3D-Raum
	var from = camera.project_ray_origin(mouse_pos)
	var normal = camera.project_ray_normal(mouse_pos)
	
	var target = _raycast_for_enemy(from, normal, shooter)
	
	if target == null:
		print("[TargetingSystem] No enemy clicked")
		close_targeting_ui()
		return
	
	# Prüfe ob Enemy sichtbar
	if not shooter.can_see_enemy(target):
		print("[TargetingSystem] Target not visible!")
		close_targeting_ui()
		return
	
	# Same target = add AP
	if shooter.is_currently_targeting(target):
		_add_invested_ap(shooter)
		return
	
	# New target
	_open_targeting_ui(shooter, target)

func _raycast_for_enemy(from: Vector3, normal: Vector3, shooter: Merc) -> Merc:
	"""Raycast um Enemy zu finden"""
	var space_state = shooter.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, from + normal * 1000.0)
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return null
	
	var collider = result.get("collider")
	if collider and collider is Merc:
		return collider
	
	return null

func _open_targeting_ui(shooter: Merc, target: Merc) -> void:
	"""Öffnet Targeting UI für neues Target"""
	print("[TargetingSystem] Opening targeting UI for %s targeting %s" % [
		shooter.merc_data.merc_name,
		target.merc_data.merc_name
	])
	
	shooter.set_targeting_target(target)
	current_shooter = shooter
	current_target = target
	is_ui_open = true
	
	_show_targeting_panel(shooter, target)

func _add_invested_ap(shooter: Merc) -> void:
	"""Addiert 1 AP zum Investment"""
	if shooter.add_invested_ap():
		print("[TargetingSystem] AP Investment: %d/10" % shooter.get_invested_ap())
		_update_targeting_panel(shooter, shooter.current_target)
	else:
		print("[TargetingSystem] Already at max AP (10)")

func _show_targeting_panel(shooter: Merc, target: Merc) -> void:
	"""Zeigt Targeting Panel UI"""
	print("[TargetingSystem] Showing targeting panel\n")
	
	if targeting_panel:
		targeting_panel.show_target_selection(shooter, target)

func _update_targeting_panel(shooter: Merc, target: Merc) -> void:
	"""Updated Targeting Panel mit neuen Werten"""
	if targeting_panel:
		targeting_panel.update_display(shooter, target)

func close_targeting_ui() -> void:
	"""Schließt Targeting UI"""
	if targeting_panel:
		targeting_panel.hide()
	
	is_ui_open = false
	current_shooter = null
	current_target = null

# ===== COST CALCULATION SYSTEM =====

func calculate_total_cost(shooter: Merc, target: Merc, invested_ap: int) -> Dictionary:
	"""Berechnet totale AP-Kosten für Shot"""
	var rotation_cost = _get_rotation_cost(shooter, target)
	var aiming_cost = _get_aiming_cost(shooter)
	var shot_cost = invested_ap
	
	var total = rotation_cost + aiming_cost + shot_cost
	
	return {
		"rotation": rotation_cost,
		"aiming": aiming_cost,
		"shot": shot_cost,
		"total": total,
		"has_rotation": rotation_cost > 0,
		"has_aiming": aiming_cost > 0
	}

func _get_rotation_cost(shooter: Merc, target: Merc) -> int:
	"""Rotation-Kosten basierend auf Stance"""
	if shooter.facing_system.is_facing(target):
		return 0
	
	match shooter.stance_system.current_stance:
		shooter.stance_system.Stance.STANDING:
			return 1
		shooter.stance_system.Stance.CROUCHED:
			return 2
		shooter.stance_system.Stance.PRONE:
			return 3
	
	return 0

func _get_aiming_cost(shooter: Merc) -> int:
	"""Aiming-Kosten: 1 wenn nicht pre-aimed, sonst 0"""
	if shooter.get_aimed_state():
		return 0
	return 1

# ===== ACCURACY CALCULATION SYSTEM =====

func get_hit_chance_with_investment(shooter: Merc, target: Merc, body_part: BodyPart, invested_ap: int) -> float:
	"""Berechnet Hit-Chance mit AP-Investment Bonus"""
	
	# Base Accuracy von Weapon
	var base_accuracy = shooter.weapon_data.base_accuracy if shooter.weapon_data else 70.0
	
	# Marksmanship Bonus
	var marksmanship = shooter.merc_data.marksmanship if shooter.merc_data else 50
	var marksmanship_bonus = marksmanship * 0.5
	
	# Distance Penalty (in Grid-Tiles)
	var distance = shooter.movement_component.current_grid_pos.distance_to(target.movement_component.current_grid_pos)
	var distance_penalty = distance * 2.0
	
	# Stance Bonus
	var stance_bonus = _get_stance_accuracy_bonus(shooter.stance_system.current_stance)
	
	# Body Part Modifier
	var body_part_modifier = _get_body_part_accuracy_modifier(body_part)
	
	# Target Stance Penalty
	var target_stance_penalty = _get_target_stance_accuracy_penalty(target.stance_system.current_stance)
	
	# Weapon Modifier
	var weapon_modifier = (shooter.weapon_data.base_accuracy / 100.0) if shooter.weapon_data else 0.7
	
	# NEW: AP Investment Bonus
	var ap_investment_bonus = _get_ap_investment_bonus(invested_ap)
	
	# Berechne finale Chance
	var chance = base_accuracy
	chance += marksmanship_bonus
	chance -= distance_penalty
	chance += stance_bonus
	chance += ap_investment_bonus
	chance += body_part_modifier
	chance -= target_stance_penalty
	chance *= weapon_modifier
	
	return clamp(chance, 5.0, 95.0)

func _get_ap_investment_bonus(invested_ap: int) -> float:
	"""AP Investment Bonus Table"""
	return clamp(invested_ap * 5.0 - 5.0, 0.0, 50.0)

func _get_stance_accuracy_bonus(stance: int) -> float:
	"""Stance-basierte Accuracy Bonusse"""
	match stance:
		0:  # STANDING
			return 0.0
		1:  # CROUCHED
			return 20.0
		2:  # PRONE
			return 40.0
	return 0.0

func _get_target_stance_accuracy_penalty(stance: int) -> float:
	"""Ziel-Stance Penalty"""
	match stance:
		0:  # STANDING
			return 0.0
		1:  # CROUCHED
			return 15.0
		2:  # PRONE
			return 30.0
	return 0.0

func _get_body_part_accuracy_modifier(body_part: BodyPart) -> float:
	"""Body Part Accuracy Modifiers"""
	match body_part:
		BodyPart.HEAD:
			return -20.0
		BodyPart.THORAX:
			return 0.0
		BodyPart.STOMACH:
			return -10.0
		BodyPart.LEFT_ARM:
			return -15.0
		BodyPart.RIGHT_ARM:
			return -15.0
		BodyPart.LEFT_LEG:
			return -20.0
		BodyPart.RIGHT_LEG:
			return -20.0
	return 0.0

# ===== UTILITY FUNCTIONS =====

static func get_display_name(body_part: BodyPart) -> String:
	"""Display Name für Body Parts"""
	match body_part:
		BodyPart.HEAD:
			return "HEAD"
		BodyPart.THORAX:
			return "THORAX"
		BodyPart.STOMACH:
			return "STOMACH"
		BodyPart.LEFT_ARM:
			return "L-ARM"
		BodyPart.RIGHT_ARM:
			return "R-ARM"
		BodyPart.LEFT_LEG:
			return "L-LEG"
		BodyPart.RIGHT_LEG:
			return "R-LEG"
	return "UNKNOWN"

func print_targeting_info(shooter: Merc, target: Merc) -> void:
	"""Debug: Print Targeting Information"""
	print("\n" + "=".repeat(80))
	print("TARGETING INFO")
	print("=".repeat(80))
	
	print("\n[SHOOTER] %s" % shooter.merc_data.merc_name)
	print("  Position: %s (Floor %d)" % [shooter.movement_component.current_grid_pos, shooter.movement_component.current_floor])
	print("  Stance: %s" % _get_stance_name(shooter.stance_system.current_stance))
	print("  Faced Direction: %.0f°" % shooter.facing_system.get_facing_angle())
	print("  Aimed: %s" % ("YES" if shooter.get_aimed_state() else "NO"))
	print("  Current AP: %d/%d" % [shooter.action_point_component.current_ap, shooter.action_point_component.max_ap])
	
	print("\n[TARGET] %s" % target.merc_data.merc_name)
	print("  Position: %s (Floor %d)" % [target.movement_component.current_grid_pos, target.movement_component.current_floor])
	print("  Stance: %s" % _get_stance_name(target.stance_system.current_stance))
	print("  Can See: %s" % ("YES" if shooter.can_see_enemy(target) else "NO"))
	
	var distance = shooter.movement_component.current_grid_pos.distance_to(target.movement_component.current_grid_pos)
	print("  Distance: %.1f tiles" % distance)
	
	var invested_ap = shooter.get_invested_ap()
	print("\n[INVESTMENT]")
	print("  Invested AP: %d/10" % invested_ap)
	
	var cost_breakdown = calculate_total_cost(shooter, target, invested_ap)
	print("\n[COST BREAKDOWN]")
	print("  Rotation: %d AP" % cost_breakdown.rotation)
	print("  Aiming: %d AP" % cost_breakdown.aiming)
	print("  Shot: %d AP" % cost_breakdown.shot)
	print("  TOTAL: %d AP" % cost_breakdown.total)
	
	print("\n[ACCURACY - per Body Part]")
	var body_parts = [
		BodyPart.HEAD,
		BodyPart.THORAX,
		BodyPart.STOMACH,
		BodyPart.LEFT_ARM,
		BodyPart.RIGHT_ARM,
		BodyPart.LEFT_LEG,
		BodyPart.RIGHT_LEG
	]
	
	for body_part in body_parts:
		var chance = get_hit_chance_with_investment(shooter, target, body_part, invested_ap)
		print("  %s: %.0f%%" % [get_display_name(body_part), chance])
	
	print("\n" + "=".repeat(80) + "\n")

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

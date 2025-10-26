extends Node
class_name CombatSystem

# Component References
var unit_manager: UnitManager
var targeting_system: TargetingSystem
var ui_manager: Node = null
var fow_system: Node = null

func _ready() -> void:
	print("[CombatSystem] Initialized\n")

func execute_shot(shooter: Merc, target: Merc, body_part: TargetingSystem.BodyPart) -> Dictionary:
	"""Führt Schuss aus: Hit/Miss, Damage, Targeting Reset"""
	print("\n" + "=".repeat(100))
	print("COMBAT - EXECUTE SHOT")
	print("=".repeat(100) + "\n")
	
	print("[COMBAT] %s shoots %s at %s" % [
		shooter.merc_data.merc_name,
		target.merc_data.merc_name,
		TargetingSystem.get_display_name(body_part)
	])
	
	var invested_ap = shooter.get_invested_ap()
	print("[COMBAT] Invested AP: %d/10" % invested_ap)
	
	# Calculate Hit Chance
	var hit_chance = targeting_system.get_hit_chance_with_investment(
		shooter, target, body_part, invested_ap
	)
	
	print("[COMBAT] Hit Chance: %.0f%%" % hit_chance)
	
	# Roll for Hit
	var roll = randf() * 100.0
	var is_hit = roll <= hit_chance
	
	print("[COMBAT] Roll: %.1f | Result: %s" % [roll, "HIT ✓" if is_hit else "MISS ✗"])
	
	# Process Damage if Hit
	var damage = 0
	var target_killed = false
	
	if is_hit:
		damage = _calculate_damage(shooter, target, body_part)
		print("[COMBAT] Damage: %d" % damage)
		
		target_killed = _apply_damage(target, body_part, damage)
		
		if target_killed:
			print("[COMBAT] %s is DEAD!" % target.merc_data.merc_name)
	
	# Spend AP
	var ap_spent = targeting_system.calculate_total_cost(shooter, target, invested_ap).total
	shooter.action_point_component.spend_ap(ap_spent)
	print("[COMBAT] AP Spent: %d (Total: %d)" % [ap_spent, ap_spent])
	print("[COMBAT] AP Remaining: %d/%d" % [
		shooter.action_point_component.current_ap,
		shooter.action_point_component.max_ap
	])
	
	# Reset Targeting State
	shooter.reset_targeting_state()
	if targeting_system:
		targeting_system.close_targeting_ui()
	
	# Update UI & FOW
	_update_systems_after_shot(shooter)
	
	print("\n" + "=".repeat(100) + "\n")
	
	# Return Result Dictionary
	return {
		"shooter": shooter,
		"target": target,
		"body_part": body_part,
		"hit": is_hit,
		"hit_chance": hit_chance,
		"roll": roll,
		"damage": damage,
		"target_killed": target_killed,
		"ap_spent": ap_spent
	}

func _calculate_damage(shooter: Merc, target: Merc, body_part: TargetingSystem.BodyPart) -> int:
	"""Berechnet Schaden basierend auf Waffe & Body Part"""
	
	# Base Damage von Waffe
	var base_damage = shooter.weapon_data.damage if shooter.weapon_data else 10
	
	# Body Part Multiplier
	var body_part_multiplier = _get_body_part_damage_multiplier(body_part)
	
	# Ammo Multiplier
	var ammo_multiplier = _get_ammo_damage_multiplier(shooter.weapon_data.ammo_type if shooter.weapon_data else "standard")
	
	# Weapon Skill Bonus
	var weapon_skill_bonus = 1.0 + (shooter.merc_data.marksmanship * 0.01) if shooter.merc_data else 1.0
	
	# Final Damage
	var final_damage = base_damage * body_part_multiplier * ammo_multiplier * weapon_skill_bonus
	
	print("[DAMAGE] Base: %d | Part Mult: %.1fx | Ammo: %.1fx | Skill: %.1fx = %.0f" % [
		base_damage,
		body_part_multiplier,
		ammo_multiplier,
		weapon_skill_bonus,
		final_damage
	])
	
	return int(final_damage)

func _apply_damage(target: Merc, body_part: TargetingSystem.BodyPart, damage: int) -> bool:
	"""Appliziert Schaden auf Target Body Part - Returns: true wenn tot"""
	
	if not target.is_alive():
		print("[DAMAGE] Target already dead!")
		return false
	
	# Convert BodyPart enum to string for take_damage
	var body_part_str = ""
	match body_part:
		TargetingSystem.BodyPart.HEAD:
			body_part_str = "head"
		TargetingSystem.BodyPart.THORAX:
			body_part_str = "thorax"
		TargetingSystem.BodyPart.STOMACH:
			body_part_str = "stomach"
		TargetingSystem.BodyPart.LEFT_ARM:
			body_part_str = "left_arm"
		TargetingSystem.BodyPart.RIGHT_ARM:
			body_part_str = "right_arm"
		TargetingSystem.BodyPart.LEFT_LEG:
			body_part_str = "left_leg"
		TargetingSystem.BodyPart.RIGHT_LEG:
			body_part_str = "right_leg"
	
	# Apply damage
	target.health_component.take_damage(body_part_str, damage)
	
	print("[DAMAGE] Applied %d to %s | %s Health: %d" % [
		damage,
		TargetingSystem.get_display_name(body_part),
		target.merc_data.merc_name,
		target.health_component._get_body_part_hp(body_part_str)
	])
	
	if not target.is_alive():
		target.on_death()
		return true
	
	return false

func _get_body_part_damage_multiplier(body_part: TargetingSystem.BodyPart) -> float:
	"""Body Part Damage Multipliers"""
	match body_part:
		TargetingSystem.BodyPart.HEAD:
			return 1.5  # Critical
		TargetingSystem.BodyPart.THORAX:
			return 1.2  # Vital
		TargetingSystem.BodyPart.STOMACH:
			return 1.0  # Normal
		TargetingSystem.BodyPart.LEFT_ARM:
			return 0.8  # Reduced
		TargetingSystem.BodyPart.RIGHT_ARM:
			return 0.8  # Reduced
		TargetingSystem.BodyPart.LEFT_LEG:
			return 0.9  # Reduced
		TargetingSystem.BodyPart.RIGHT_LEG:
			return 0.9  # Reduced
	return 1.0

func _get_ammo_damage_multiplier(ammo_type: String) -> float:
	"""Ammo Type Damage Multipliers"""
	match ammo_type:
		"standard":
			return 1.0
		"armor_piercing":
			return 1.2
		"explosive":
			return 1.5
		"incendiary":
			return 0.9
	return 1.0

func _update_systems_after_shot(shooter: Merc) -> void:
	"""Update UI & FOW nach Schuss"""
	
	if ui_manager:
		print("[COMBAT] Updating UI...")
		ui_manager.update_all()
	
	if fow_system:
		print("[COMBAT] Updating Fog of War...")
		fow_system.update_visibility()
	
	shooter.update_fov_grid()
	shooter.update_fov_grids_3d()

# ===== DEBUG & REPORTING =====

func print_shot_report(result: Dictionary) -> void:
	"""Debug: Print Shot Report"""
	print("\n" + "=".repeat(100))
	print("SHOT REPORT")
	print("=".repeat(100))
	
	var shooter = result.shooter as Merc
	var target = result.target as Merc
	var body_part = result.body_part as int
	
	print("\n[SHOOTER] %s" % shooter.merc_data.merc_name)
	print("[TARGET] %s" % target.merc_data.merc_name)
	print("[BODY PART] %s" % TargetingSystem.get_display_name(body_part))
	
	print("\n[RESULT]")
	print("  Hit Chance: %.0f%%" % result.hit_chance)
	print("  Roll: %.1f" % result.roll)
	print("  Hit: %s" % ("YES ✓" if result.hit else "NO ✗"))
	
	if result.hit:
		print("  Damage: %d" % result.damage)
		print("  Target Killed: %s" % ("YES" if result.target_killed else "NO"))
	
	print("  AP Spent: %d" % result.ap_spent)
	
	print("\n[STATUS]")
	print("  Shooter AP: %d/%d" % [
		shooter.action_point_component.current_ap,
		shooter.action_point_component.max_ap
	])
	
	if target.is_alive():
		print("  Target Health: %d/%d" % [
			target.health_component.current_health,
			target.health_component.max_health
		])
	else:
		print("  Target: DEAD")
	
	print("\n" + "=".repeat(100) + "\n")

func get_viable_body_parts(target: Merc) -> Array[TargetingSystem.BodyPart]:
	"""Gibt alle sichtbaren Body Parts zurück"""
	var visible_parts = target.get_visible_body_parts(target)
	var viable = []
	
	if (visible_parts & 1) != 0:  # HEAD
		viable.append(TargetingSystem.BodyPart.HEAD)
	if (visible_parts & 2) != 0:  # TORSO
		viable.append(TargetingSystem.BodyPart.THORAX)
	if (visible_parts & 4) != 0:  # LEGS
		viable.append(TargetingSystem.BodyPart.LEFT_LEG)
		viable.append(TargetingSystem.BodyPart.RIGHT_LEG)
	
	return viable

extends Node
class_name CombatComponent

var owner_merc: Merc
var equipped_weapon: WeaponData
var action_point_component: ActionPointComponent
var grid_manager: GridManager

var aim_bonus: int = 0

func initialize(merc: Merc, weapon: WeaponData, ap_component: ActionPointComponent, grid_mgr: GridManager = null) -> void:
	owner_merc = merc
	equipped_weapon = weapon
	action_point_component = ap_component
	grid_manager = grid_mgr

func can_shoot(target: Merc) -> bool:
	if not equipped_weapon:
		return false
	
	if not target.is_alive():
		return false
	
	# Check if target position is visible in FOV Grid
	var target_pos = target.movement_component.current_grid_pos
	if not owner_merc.can_see_position(target_pos):
		return false
	
	if equipped_weapon.current_ammo <= 0:
		return false
	
	var total_ap_cost = equipped_weapon.ap_cost_shoot
	if not action_point_component.has_ap(total_ap_cost):
		return false
	
	return true

func shoot(target: Merc, body_part: TargetingSystem.BodyPart) -> Dictionary:
	if not can_shoot(target):
		return {"success": false, "reason": "Cannot shoot"}
	
	action_point_component.spend_ap(equipped_weapon.ap_cost_shoot)
	equipped_weapon.current_ammo -= 1
	
	var hit_chance = get_hit_chance_for_part(target, body_part)
	var roll = randf() * 100.0
	
	var body_part_name = TargetingSystem.get_body_part_name(body_part)
	
	var result = {
		"success": true,
		"hit": roll <= hit_chance,
		"hit_chance": hit_chance,
		"roll": roll,
		"damage": 0,
		"body_part": body_part_name,
		"body_part_enum": body_part,
		"target_killed": false
	}
	
	if result.hit:
		var base_damage = equipped_weapon.base_damage
		var damage_multiplier = TargetingSystem.get_damage_multiplier(body_part)
		var final_damage = int(base_damage * damage_multiplier)
		
		target.health_component.take_damage(body_part_name, final_damage)
		result.damage = final_damage
		result.target_killed = not target.is_alive()
	
	aim_bonus = 0
	
	return result

func aim() -> bool:
	if not equipped_weapon:
		return false
	
	if not action_point_component.spend_ap(equipped_weapon.ap_cost_aim):
		return false
	
	aim_bonus += 10
	return true

func get_current_aim_bonus() -> int:
	return aim_bonus

func get_hit_chance_for_part(target: Merc, body_part: TargetingSystem.BodyPart) -> float:
	var base_chance = float(owner_merc.merc_data.marksmanship)
	
	var distance = owner_merc.movement_component.current_grid_pos.distance_to(target.movement_component.current_grid_pos)
	var distance_penalty = distance * 2.0
	
	var weapon_accuracy = float(equipped_weapon.base_accuracy) / 100.0
	var size_modifier = TargetingSystem.get_size_modifier(body_part)
	var accuracy_modifier = owner_merc.status_effect_system.get_accuracy_modifier()
	
	# Cover penalty based on visibility level
	var cover_penalty = 0.0
	var target_pos = target.movement_component.current_grid_pos
	var visibility = owner_merc.get_visibility_level(target_pos)
	
	if visibility == FOVGridSystem.VisibilityLevel.PARTIAL:
		cover_penalty = 25.0  # GRÜN = durch Deckung
	elif visibility == FOVGridSystem.VisibilityLevel.BLOCKED:
		cover_penalty = 100.0  # Sollte nie passieren da can_shoot() bereits prüft
	
	var final_chance = (base_chance + aim_bonus + accuracy_modifier - distance_penalty + size_modifier - cover_penalty) * weapon_accuracy
	
	return clamp(final_chance, 5.0, 95.0)

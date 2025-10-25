extends Node
class_name CombatComponent

@export var marksmanship: int = 50
@export var aim_level: int = 1

var shooter: Merc
var ammo: int = 30
var base_accuracy: float = 70.0
var los_system: LineOfSightSystem
var grid_manager: GridManager

func _ready() -> void:
	pass

func initialize(merc: Merc, weapon: WeaponData, ap_component: ActionPointComponent) -> void:
	shooter = merc
	ammo = weapon.magazine_size if weapon else 30
	base_accuracy = float(weapon.base_accuracy) if weapon else 70.0
	los_system = LineOfSightSystem.new()
	print("[COMBAT] Initialized for %s with %d ammo, %.0f%% accuracy" % [merc.merc_data.merc_name, ammo, base_accuracy])

func can_shoot(target: Merc) -> bool:
	"""Prüfe: Ammo? Target sichtbar? AP?"""
	if ammo <= 0:
		print("[COMBAT] No ammo!")
		return false
	
	if not shooter.can_see_enemy(target):
		print("[COMBAT] Cannot see target!")
		return false
	
	var ap_cost = 10
	if not shooter.action_point_component.has_ap(ap_cost):
		print("[COMBAT] Not enough AP!")
		return false
	
	return true

func get_available_body_parts(target: Merc) -> Array:
	"""Nur sichtbare Body Parts (LoS Check)"""
	var visible_parts = shooter.get_visible_body_parts(target)
	var available: Array = []
	
	if visible_parts & LineOfSightSystem.BodyPartVisibility.HEAD:
		available.append(TargetingSystem.BodyPart.HEAD)
	
	if visible_parts & LineOfSightSystem.BodyPartVisibility.TORSO:
		available.append(TargetingSystem.BodyPart.THORAX)
		available.append(TargetingSystem.BodyPart.STOMACH)
		available.append(TargetingSystem.BodyPart.LEFT_ARM)
		available.append(TargetingSystem.BodyPart.RIGHT_ARM)
	
	if visible_parts & LineOfSightSystem.BodyPartVisibility.LEGS:
		available.append(TargetingSystem.BodyPart.LEFT_LEG)
		available.append(TargetingSystem.BodyPart.RIGHT_LEG)
	
	return available

func get_hit_chance_for_part(target: Merc, body_part: TargetingSystem.BodyPart) -> float:
	"""Berechne Hit Chance mit Stance Bonus"""
	
	# Base Accuracy
	var chance = base_accuracy
	print("[ACCURACY] Base: %.0f%%" % chance)
	
	# Marksmanship Bonus
	var skill_bonus = marksmanship * 0.5
	chance += skill_bonus
	print("[ACCURACY] + Marksmanship: %.0f%% → %.0f%%" % [skill_bonus, chance])
	
	# Distance Penalty
	var player_pos = shooter.movement_component.current_grid_pos
	var target_pos = target.movement_component.current_grid_pos
	var dx = abs(player_pos.x - target_pos.x)
	var dy = abs(player_pos.y - target_pos.y)
	var distance = max(dx, dy)
	var distance_penalty = distance * 2.0
	chance -= distance_penalty
	print("[ACCURACY] - Distance (%d tiles): %.0f%% → %.0f%%" % [distance, distance_penalty, chance])
	
	# Aim Bonus
	var aim_bonus = aim_level * 5.0
	chance += aim_bonus
	print("[ACCURACY] + Aim Level %d: %.0f%% → %.0f%%" % [aim_level, aim_bonus, chance])
	
	# STANCE BONUS
	var stance_bonus = _get_stance_bonus()
	chance += stance_bonus
	var stance_name = _get_stance_name(shooter.stance_system.current_stance)
	print("[ACCURACY] + Stance (%s): %.0f%% → %.0f%%" % [stance_name, stance_bonus, chance])
	
	# Body Part Modifier
	var part_modifier = _get_body_part_modifier(body_part)
	chance += part_modifier
	var part_name = TargetingSystem.get_display_name(body_part)
	print("[ACCURACY] + Body Part (%s): %.0f%% → %.0f%%" % [part_name, part_modifier, chance])
	
	# Target Stance Penalty
	var target_stance_penalty = _get_target_stance_penalty(target)
	chance -= target_stance_penalty
	var target_stance_name = _get_stance_name(target.stance_system.current_stance)
	print("[ACCURACY] - Target Stance (%s): %.0f%% → %.0f%%" % [target_stance_name, target_stance_penalty, chance])
	
	# Weapon Accuracy Modifier
	var weapon_modifier = (float(shooter.weapon_data.base_accuracy) / 100.0) if shooter.weapon_data else 1.0
	chance *= weapon_modifier
	print("[ACCURACY] × Weapon: %.0f%% → %.0f%%" % [weapon_modifier * 100, chance])
	
	# Clamp 5-95%
	chance = clamp(chance, 5.0, 95.0)
	print("[ACCURACY] FINAL: %.0f%%\n" % chance)
	
	return chance

func _get_stance_bonus() -> float:
	"""Stance Accuracy Bonus"""
	match shooter.stance_system.current_stance:
		StanceSystem.Stance.STANDING:
			return 0.0
		StanceSystem.Stance.CROUCHED:
			return 20.0
		StanceSystem.Stance.PRONE:
			return 40.0
	return 0.0

func _get_stance_name(stance: StanceSystem.Stance) -> String:
	match stance:
		StanceSystem.Stance.STANDING:
			return "STANDING"
		StanceSystem.Stance.CROUCHED:
			return "CROUCHED"
		StanceSystem.Stance.PRONE:
			return "PRONE"
	return "UNKNOWN"

func _get_target_stance_penalty(target: Merc) -> float:
	"""Je niedriger Target, desto schwerer zu treffen"""
	match target.stance_system.current_stance:
		StanceSystem.Stance.STANDING:
			return 0.0
		StanceSystem.Stance.CROUCHED:
			return 10.0
		StanceSystem.Stance.PRONE:
			return 25.0
	return 0.0

func _get_body_part_modifier(body_part: TargetingSystem.BodyPart) -> float:
	match body_part:
		TargetingSystem.BodyPart.HEAD:
			return -20.0
		TargetingSystem.BodyPart.THORAX:
			return 0.0
		TargetingSystem.BodyPart.STOMACH:
			return -5.0
		TargetingSystem.BodyPart.LEFT_ARM:
			return -15.0
		TargetingSystem.BodyPart.RIGHT_ARM:
			return -15.0
		TargetingSystem.BodyPart.LEFT_LEG:
			return -10.0
		TargetingSystem.BodyPart.RIGHT_LEG:
			return -10.0
	return 0.0

func shoot(target: Merc, body_part: TargetingSystem.BodyPart) -> Dictionary:
	"""Fire shot"""
	if not can_shoot(target):
		return {"hit": false, "damage": 0, "body_part": body_part, "target_killed": false}
	
	# Consume Ammo + AP
	ammo -= 1
	shooter.action_point_component.spend_ap(10)
	
	# Get Hit Chance
	var hit_chance = get_hit_chance_for_part(target, body_part)
	var roll = randf() * 100.0
	var hit = roll < hit_chance
	
	print("[SHOOT] Roll: %.1f%% vs Chance: %.0f%% = %s" % [roll, hit_chance, "HIT" if hit else "MISS"])
	
	var damage = 0
	var target_killed = false
	
	if hit:
		damage = _calculate_damage(body_part)
		print("[SHOOT] Damage: %d" % damage)
		
		# Convert body_part zu String
		var part_string = TargetingSystem.get_display_name(body_part).to_lower()
		target.health_component.take_damage(part_string, damage)
		
		target_killed = not target.health_component.is_alive()
		print("[SHOOT] Target Health: Head=%d | Thorax=%d | Killed: %s" % [
			target.health_component.current_head,
			target.health_component.current_thorax,
			target_killed
		])
	else:
		print("[SHOOT] MISS!")
	
	return {
		"hit": hit,
		"damage": damage,
		"body_part": body_part,
		"target_killed": target_killed
	}

func _calculate_damage(body_part: TargetingSystem.BodyPart) -> int:
	"""Damage varies by body part"""
	var base_damage = 25
	
	match body_part:
		TargetingSystem.BodyPart.HEAD:
			return int(base_damage * 2.0)
		TargetingSystem.BodyPart.THORAX:
			return int(base_damage * 1.5)
		TargetingSystem.BodyPart.STOMACH:
			return int(base_damage * 1.3)
		TargetingSystem.BodyPart.LEFT_ARM:
			return int(base_damage * 0.8)
		TargetingSystem.BodyPart.RIGHT_ARM:
			return int(base_damage * 0.8)
		TargetingSystem.BodyPart.LEFT_LEG:
			return int(base_damage * 1.0)
		TargetingSystem.BodyPart.RIGHT_LEG:
			return int(base_damage * 1.0)
	
	return base_damage

func aim() -> bool:
	"""Erhöhe Aim Level"""
	if aim_level < 3:
		aim_level += 1
		print("[COMBAT] Aimed to level %d" % aim_level)
		return true
	return false

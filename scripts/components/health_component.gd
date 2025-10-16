extends Node
class_name HealthComponent

# Current health values for each body part
var current_head: int
var current_thorax: int
var current_stomach: int
var current_left_arm: int
var current_right_arm: int
var current_left_leg: int
var current_right_leg: int

var merc_data: MercData
var status_effect_system: StatusEffectSystem

func initialize(data: MercData) -> void:
	merc_data = data
	current_head = data.health_head
	current_thorax = data.health_thorax
	current_stomach = data.health_stomach
	current_left_arm = data.health_left_arm
	current_right_arm = data.health_right_arm
	current_left_leg = data.health_left_leg
	current_right_leg = data.health_right_leg

func set_status_effect_system(system: StatusEffectSystem) -> void:
	status_effect_system = system

func take_damage(body_part: String, damage: int) -> void:
	var was_alive = is_alive()
	var old_hp = _get_body_part_hp(body_part)
	
	match body_part:
		"head":
			current_head = max(0, current_head - damage)
		"thorax":
			current_thorax = max(0, current_thorax - damage)
		"stomach":
			current_stomach = max(0, current_stomach - damage)
		"left_arm":
			current_left_arm = max(0, current_left_arm - damage)
		"right_arm":
			current_right_arm = max(0, current_right_arm - damage)
		"left_leg":
			current_left_leg = max(0, current_left_leg - damage)
		"right_leg":
			current_right_leg = max(0, current_right_leg - damage)
	
	var new_hp = _get_body_part_hp(body_part)
	
	# Check if body part was destroyed
	if old_hp > 0 and new_hp <= 0:
		_on_body_part_destroyed(body_part)
	
	check_death()

func _get_body_part_hp(body_part: String) -> int:
	match body_part:
		"head": return current_head
		"thorax": return current_thorax
		"stomach": return current_stomach
		"left_arm": return current_left_arm
		"right_arm": return current_right_arm
		"left_leg": return current_left_leg
		"right_leg": return current_right_leg
	return 0

func _on_body_part_destroyed(body_part: String) -> void:
	if not status_effect_system:
		return
	
	print(">>> ", body_part.to_upper(), " DESTROYED! <<<")
	
	match body_part:
		"left_arm", "right_arm":
			status_effect_system.add_effect(StatusEffectSystem.StatusEffect.ARM_DESTROYED, body_part)
		"left_leg", "right_leg":
			status_effect_system.add_effect(StatusEffectSystem.StatusEffect.LEG_DESTROYED, body_part)
		"stomach":
			# Magen zerstört = Blutung
			status_effect_system.add_effect(StatusEffectSystem.StatusEffect.BLEEDING, body_part, -1, 2)

func check_death() -> bool:
	if current_head <= 0 or current_thorax <= 0:
		return true
	return false

func is_alive() -> bool:
	return not check_death()

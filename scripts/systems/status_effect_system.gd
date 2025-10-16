extends Node
class_name StatusEffectSystem

enum StatusEffect {
	NONE,
	ARM_DESTROYED,      # Waffe unbrauchbar / sehr ungenau
	LEG_DESTROYED,      # Bewegung kostet mehr AP
	BLEEDING,           # Verliert HP pro Runde
	FRACTURE,           # Körperteil funktioniert schlecht
	PAIN               # Zittrige Hände, unscharfe Sicht
}

class ActiveEffect:
	var effect_type: StatusEffect
	var body_part: String
	var duration: int = -1  # -1 = permanent
	var severity: int = 1
	
	func _init(type: StatusEffect, part: String = "", dur: int = -1, sev: int = 1):
		effect_type = type
		body_part = part
		duration = dur
		severity = sev

var active_effects: Array[ActiveEffect] = []
var owner_merc: Merc

func initialize(merc: Merc) -> void:
	owner_merc = merc

func add_effect(effect_type: StatusEffect, body_part: String = "", duration: int = -1, severity: int = 1) -> void:
	var new_effect = ActiveEffect.new(effect_type, body_part, duration, severity)
	active_effects.append(new_effect)
	print(owner_merc.merc_data.merc_name, " gained effect: ", _get_effect_name(effect_type), " on ", body_part)

func has_effect(effect_type: StatusEffect) -> bool:
	for effect in active_effects:
		if effect.effect_type == effect_type:
			return true
	return false

func has_effect_on_part(effect_type: StatusEffect, body_part: String) -> bool:
	for effect in active_effects:
		if effect.effect_type == effect_type and effect.body_part == body_part:
			return true
	return false

func get_accuracy_modifier() -> int:
	var modifier = 0
	
	# Zerstörte Arme reduzieren Genauigkeit massiv
	if has_effect_on_part(StatusEffect.ARM_DESTROYED, "right_arm"):
		modifier -= 40
	if has_effect_on_part(StatusEffect.ARM_DESTROYED, "left_arm"):
		modifier -= 20  # Weniger Einfluss bei linkem Arm
	
	return modifier

func get_movement_ap_modifier() -> float:
	var modifier = 1.0
	
	# Zerstörte Beine erhöhen AP-Kosten
	if has_effect_on_part(StatusEffect.LEG_DESTROYED, "left_leg"):
		modifier += 0.5
	if has_effect_on_part(StatusEffect.LEG_DESTROYED, "right_leg"):
		modifier += 0.5
	
	# Beide Beine zerstört = kann kaum noch laufen
	if has_effect_on_part(StatusEffect.LEG_DESTROYED, "left_leg") and has_effect_on_part(StatusEffect.LEG_DESTROYED, "right_leg"):
		modifier = 3.0
	
	return modifier

func process_turn_effects() -> void:
	# Blutungen verursachen Schaden
	for effect in active_effects:
		if effect.effect_type == StatusEffect.BLEEDING:
			var bleed_damage = 5 * effect.severity
			owner_merc.health_component.take_damage("thorax", bleed_damage)
			print(owner_merc.merc_data.merc_name, " bleeds for ", bleed_damage, " damage")
	
	# Reduziere Duration
	var to_remove = []
	for i in range(active_effects.size()):
		var effect = active_effects[i]
		if effect.duration > 0:
			effect.duration -= 1
			if effect.duration <= 0:
				to_remove.append(i)
	
	# Entferne abgelaufene Effekte (rückwärts)
	for i in range(to_remove.size() - 1, -1, -1):
		active_effects.remove_at(to_remove[i])

func _get_effect_name(effect_type: StatusEffect) -> String:
	match effect_type:
		StatusEffect.ARM_DESTROYED: return "ARM DESTROYED"
		StatusEffect.LEG_DESTROYED: return "LEG DESTROYED"
		StatusEffect.BLEEDING: return "BLEEDING"
		StatusEffect.FRACTURE: return "FRACTURE"
		StatusEffect.PAIN: return "PAIN"
	return "UNKNOWN"

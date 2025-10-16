extends Node
class_name StanceSystem

enum Stance {
	PRONE,      # Liegend - niedrigste Höhe, schwer zu treffen
	CROUCHED,   # Hockend - mittlere Höhe, hinter Low Cover
	STANDING    # Stehend - normale Höhe
}

# Höhen für jede Stance (Augenhöhe des Söldners)
const STANCE_EYE_HEIGHT = {
	Stance.PRONE: 0.3,
	Stance.CROUCHED: 1.0,
	Stance.STANDING: 1.6
}

# Capsule-Höhen für visuelle Darstellung
const STANCE_CAPSULE_HEIGHT = {
	Stance.PRONE: 0.5,
	Stance.CROUCHED: 1.2,
	Stance.STANDING: 1.8
}

# AP-Kosten um Stance zu wechseln
const STANCE_CHANGE_AP_COST = {
	Stance.PRONE: {Stance.CROUCHED: 3, Stance.STANDING: 5},
	Stance.CROUCHED: {Stance.PRONE: 2, Stance.STANDING: 2},
	Stance.STANDING: {Stance.PRONE: 4, Stance.CROUCHED: 2}
}

# Accuracy Modifier pro Stance
const STANCE_ACCURACY_MODIFIER = {
	Stance.PRONE: 10,      # +10% accuracy (stabil)
	Stance.CROUCHED: 0,    # neutral
	Stance.STANDING: -5    # -5% accuracy (weniger stabil)
}

var current_stance: Stance = Stance.STANDING
var owner_merc: Merc

func initialize(merc: Merc) -> void:
	owner_merc = merc
	current_stance = Stance.STANDING

func get_eye_height() -> float:
	return STANCE_EYE_HEIGHT[current_stance]

func get_capsule_height() -> float:
	return STANCE_CAPSULE_HEIGHT[current_stance]

func get_accuracy_modifier() -> int:
	return STANCE_ACCURACY_MODIFIER[current_stance]

func can_change_stance(new_stance: Stance) -> bool:
	if current_stance == new_stance:
		return false
	
	var ap_cost = STANCE_CHANGE_AP_COST[current_stance][new_stance]
	return owner_merc.action_point_component.has_ap(ap_cost)

func change_stance(new_stance: Stance) -> bool:
	if not can_change_stance(new_stance):
		return false
	
	var ap_cost = STANCE_CHANGE_AP_COST[current_stance][new_stance]
	if not owner_merc.action_point_component.spend_ap(ap_cost):
		return false
	
	var old_stance = current_stance
	current_stance = new_stance
	
	print(owner_merc.merc_data.merc_name, " changed stance: ", _get_stance_name(old_stance), " -> ", _get_stance_name(new_stance))
	
	# Update visuals
	_update_visual()
	
	return true

func _update_visual() -> void:
	if not owner_merc.visual_component or not owner_merc.visual_component.model_mesh:
		return
	
	var mesh = owner_merc.visual_component.model_mesh.mesh as CapsuleMesh
	if mesh:
		mesh.height = get_capsule_height()
		# Adjust position
		owner_merc.visual_component.model_mesh.position.y = get_capsule_height() / 2.0

func _get_stance_name(stance: Stance) -> String:
	match stance:
		Stance.PRONE: return "PRONE"
		Stance.CROUCHED: return "CROUCHED"
		Stance.STANDING: return "STANDING"
	return "UNKNOWN"

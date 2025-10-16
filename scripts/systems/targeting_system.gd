extends Node
class_name TargetingSystem

enum BodyPart {
	HEAD,
	THORAX,
	STOMACH,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG
}

# Mapping von BodyPart zu String für Health Component
const BODY_PART_NAMES = {
	BodyPart.HEAD: "head",
	BodyPart.THORAX: "thorax",
	BodyPart.STOMACH: "stomach",
	BodyPart.LEFT_ARM: "left_arm",
	BodyPart.RIGHT_ARM: "right_arm",
	BodyPart.LEFT_LEG: "left_leg",
	BodyPart.RIGHT_LEG: "right_leg"
}

# Hit Chance Modifiers pro Körperteil (basierend auf Größe)
const BODY_PART_SIZE_MODIFIER = {
	BodyPart.HEAD: -20.0,        # Klein, schwer zu treffen
	BodyPart.THORAX: 0.0,        # Groß, Standard
	BodyPart.STOMACH: -5.0,      # Mittelgroß
	BodyPart.LEFT_ARM: -15.0,    # Schmal
	BodyPart.RIGHT_ARM: -15.0,   # Schmal
	BodyPart.LEFT_LEG: -10.0,    # Mittel
	BodyPart.RIGHT_LEG: -10.0    # Mittel
}

# Damage Multiplier pro Körperteil
const BODY_PART_DAMAGE_MULTIPLIER = {
	BodyPart.HEAD: 1.5,          # Kritisch
	BodyPart.THORAX: 1.0,        # Normal
	BodyPart.STOMACH: 0.9,       # Etwas weniger
	BodyPart.LEFT_ARM: 0.7,      # Wenig
	BodyPart.RIGHT_ARM: 0.7,     # Wenig
	BodyPart.LEFT_LEG: 0.8,      # Wenig
	BodyPart.RIGHT_LEG: 0.8      # Wenig
}

static func get_body_part_name(part: BodyPart) -> String:
	return BODY_PART_NAMES[part]

static func get_size_modifier(part: BodyPart) -> float:
	return BODY_PART_SIZE_MODIFIER[part]

static func get_damage_multiplier(part: BodyPart) -> float:
	return BODY_PART_DAMAGE_MULTIPLIER[part]

static func get_display_name(part: BodyPart) -> String:
	match part:
		BodyPart.HEAD: return "Head"
		BodyPart.THORAX: return "Thorax"
		BodyPart.STOMACH: return "Stomach"
		BodyPart.LEFT_ARM: return "Left Arm"
		BodyPart.RIGHT_ARM: return "Right Arm"
		BodyPart.LEFT_LEG: return "Left Leg"
		BodyPart.RIGHT_LEG: return "Right Leg"
	return "Unknown"

static func calculate_hit_chance(shooter: Merc, target: Merc, body_part: BodyPart, aim_bonus: int) -> float:
	var base_chance = float(shooter.merc_data.marksmanship)
	
	# Distance penalty
	var distance = shooter.movement_component.current_grid_pos.distance_to(target.movement_component.current_grid_pos)
	var distance_penalty = distance * 2.0
	
	# Weapon accuracy
	var weapon_accuracy = float(shooter.weapon_data.base_accuracy) / 100.0
	
	# Body part size modifier
	var size_modifier = get_size_modifier(body_part)
	
	# Cover penalty
	var cover_penalty = 0.0
	if shooter.get_parent() and shooter.get_parent().has_node("GridManager"):
		var grid_manager = shooter.get_parent().get_node("GridManager") as GridManager
		if grid_manager:
			var cover = grid_manager.get_cover_between(shooter.movement_component.current_grid_pos, target.movement_component.current_grid_pos)
			if cover:
				cover_penalty = cover.get_hit_penalty()
	
	# Final calculation
	var final_chance = (base_chance + aim_bonus - distance_penalty + size_modifier - cover_penalty) * weapon_accuracy
	
	return clamp(final_chance, 5.0, 95.0)

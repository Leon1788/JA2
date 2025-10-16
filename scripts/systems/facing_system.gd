extends Node
class_name FacingSystem

# Rotation in Grad (0 = Nord, 90 = Ost, 180 = Süd, 270 = West)
var current_rotation: float = 0.0

# Field of View in Grad (wie breit der Sichtkegel ist)
var fov_angle: float = 120.0

# AP Kosten für Rotation
const ROTATION_AP_COST_PER_45_DEG: int = 1

var owner_merc: Merc

func initialize(merc: Merc) -> void:
	owner_merc = merc
	current_rotation = 0.0  # Start facing North

func get_facing_direction() -> Vector3:
	# Berechne Richtungsvektor basierend auf Rotation
	var rad = deg_to_rad(current_rotation)
	return Vector3(sin(rad), 0, cos(rad)).normalized()

func get_facing_angle() -> float:
	return current_rotation

func is_in_field_of_view(target_position: Vector3) -> bool:
	var to_target = (target_position - owner_merc.global_position).normalized()
	to_target.y = 0  # Ignoriere Y für 2D facing
	
	var facing_dir = get_facing_direction()
	
	# Berechne Winkel zwischen Facing und Target
	var angle_to_target = rad_to_deg(acos(facing_dir.dot(to_target)))
	
	# In FOV wenn Winkel kleiner als halber FOV
	return angle_to_target <= (fov_angle / 2.0)

func can_rotate_to_angle(target_angle: float) -> bool:
	var angle_diff = _calculate_rotation_difference(current_rotation, target_angle)
	var ap_cost = _calculate_rotation_ap_cost(angle_diff)
	
	return owner_merc.action_point_component.has_ap(ap_cost)

func rotate_to_angle(target_angle: float) -> bool:
	var angle_diff = _calculate_rotation_difference(current_rotation, target_angle)
	var ap_cost = _calculate_rotation_ap_cost(angle_diff)
	
	if not owner_merc.action_point_component.spend_ap(ap_cost):
		return false
	
	current_rotation = fmod(target_angle, 360.0)
	if current_rotation < 0:
		current_rotation += 360.0
	
	# Update visual
	_update_visual_rotation()
	
	print(owner_merc.merc_data.merc_name, " rotated to ", current_rotation, "° (cost: ", ap_cost, " AP)")
	return true

func rotate_towards_target(target: Merc) -> bool:
	var to_target = target.global_position - owner_merc.global_position
	var target_angle = rad_to_deg(atan2(to_target.x, to_target.z))
	
	return rotate_to_angle(target_angle)

func _calculate_rotation_difference(from_angle: float, to_angle: float) -> float:
	var diff = to_angle - from_angle
	
	# Normalize to -180 to 180
	while diff > 180:
		diff -= 360
	while diff < -180:
		diff += 360
	
	return abs(diff)

func _calculate_rotation_ap_cost(angle_diff: float) -> int:
	var segments = ceil(angle_diff / 45.0)
	return int(segments * ROTATION_AP_COST_PER_45_DEG)

func _update_visual_rotation() -> void:
	if owner_merc:
		owner_merc.rotation.y = deg_to_rad(-current_rotation)  # Negativ wegen Godot's Koordinatensystem

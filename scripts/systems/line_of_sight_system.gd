extends Node
class_name LineOfSightSystem

enum BodyPartVisibility {
	NONE = 0,
	HEAD = 1,
	TORSO = 2,
	LEGS = 4
}

var owner_merc: Merc

func initialize(merc: Merc) -> void:
	owner_merc = merc
	print("[LoS] %s initialized" % owner_merc.merc_data.merc_name)

func invalidate_cache() -> void:
	pass

func can_see_enemy(target: Merc) -> bool:
	if not target:
		return false
	
	if target.movement_component == null:
		return false
	
	var target_grid_pos = target.movement_component.current_grid_pos
	var target_floor = target.movement_component.current_floor
	
	# STAGE 1: FOV Cone Check
	if not owner_merc.can_see_position_3d(target_grid_pos, target_floor):
		return false
	
	# STAGE 2: Check ANY body part visible
	var parts = get_visible_body_parts(target)
	if parts == BodyPartVisibility.NONE:
		return false
	
	print("[LoS] %s CAN SEE %s ✅" % [owner_merc.merc_data.merc_name, target.merc_data.merc_name])
	return true

func get_visible_body_parts(target: Merc) -> int:
	"""
	Prüft 3x Rays (HEAD/TORSO/LEGS) und gibt Bitfield zurück
	"""
	if not target:
		return BodyPartVisibility.NONE
	
	var player_eye = owner_merc.global_position + Vector3(0, owner_merc.stance_system.get_eye_height(), 0)
	var target_pos = target.global_position
	var target_eye_height = target.stance_system.get_eye_height()
	
	var visible_parts = BodyPartVisibility.NONE
	
	# HEAD: Eye Height * 1.0 = 1.6m
	var head_pos = target_pos + Vector3(0, target_eye_height, 0)
	if _is_ray_unblocked(player_eye, head_pos, target):
		visible_parts |= BodyPartVisibility.HEAD
	
	# TORSO: Eye Height * 0.6 = 0.96m
	var torso_pos = target_pos + Vector3(0, target_eye_height * 0.6, 0)
	if _is_ray_unblocked(player_eye, torso_pos, target):
		visible_parts |= BodyPartVisibility.TORSO
	
	# LEGS: Eye Height * 0.3 = 0.48m
	var legs_pos = target_pos + Vector3(0, target_eye_height * 0.3, 0)
	if _is_ray_unblocked(player_eye, legs_pos, target):
		visible_parts |= BodyPartVisibility.LEGS
	
	return visible_parts

func get_available_body_parts(target: Merc) -> Array[TargetingSystem.BodyPart]:
	"""
	Konvertiert Bitfield zu sichtbaren Body Parts
	Die Logik:
	- HEAD sichtbar? → HEAD Button
	- TORSO sichtbar? → TORSO + BOTH ARMS
	- LEGS sichtbar? → BOTH LEGS
	"""
	var visible_parts = get_visible_body_parts(target)
	var available: Array[TargetingSystem.BodyPart] = []
	
	if visible_parts == BodyPartVisibility.NONE:
		return available  # Nichts sichtbar
	
	# HEAD
	if visible_parts & BodyPartVisibility.HEAD:
		available.append(TargetingSystem.BodyPart.HEAD)
	
	# TORSO + ARME
	if visible_parts & BodyPartVisibility.TORSO:
		available.append(TargetingSystem.BodyPart.THORAX)
		available.append(TargetingSystem.BodyPart.STOMACH)
		available.append(TargetingSystem.BodyPart.LEFT_ARM)
		available.append(TargetingSystem.BodyPart.RIGHT_ARM)
	
	# BEINE
	if visible_parts & BodyPartVisibility.LEGS:
		available.append(TargetingSystem.BodyPart.LEFT_LEG)
		available.append(TargetingSystem.BodyPart.RIGHT_LEG)
	
	return available

func _is_ray_unblocked(from: Vector3, to: Vector3, exclude_target: Node = null) -> bool:
	"""
	Physics RayCast: Prüft ob direkte Sichtlinie frei ist
	ALLES blockiert (Cover, Floors, andere Units)
	"""
	var space_state = owner_merc.get_world_3d().direct_space_state
	if not space_state:
		return true
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b111  # All layers
	
	var exclude_list = [owner_merc]
	if exclude_target:
		exclude_list.append(exclude_target)
	query.exclude = exclude_list
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return true  # Freie Sicht
	
	return false  # Blockiert

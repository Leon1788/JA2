extends Node
class_name LineOfSightSystem

enum BodyPartVisibility {
	NONE = 0,
	HEAD = 1,
	TORSO = 2,
	LEGS = 4
}

var owner_merc: Merc
var visible_body_parts_cache: Dictionary = {}
var cache_dirty: bool = true

func initialize(merc: Merc) -> void:
	owner_merc = merc
	print("[LoS] %s initialized" % owner_merc.merc_data.merc_name)

func invalidate_cache() -> void:
	cache_dirty = true

func can_see_enemy(target: Merc) -> bool:
	if not target:
		return false
	
	# Nicht is_alive() aufrufen!
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
	if not target:
		return BodyPartVisibility.NONE
	
	var player_eye = owner_merc.global_position + Vector3(0, owner_merc.stance_system.get_eye_height(), 0)
	var target_pos = target.global_position
	var target_eye_height = target.stance_system.get_eye_height()
	
	var visible_parts = BodyPartVisibility.NONE
	
	# HEAD
	var head_pos = target_pos + Vector3(0, target_eye_height, 0)
	if _is_ray_unblocked(player_eye, head_pos, target):
		visible_parts |= BodyPartVisibility.HEAD
	
	# TORSO
	var torso_pos = target_pos + Vector3(0, target_eye_height * 0.6, 0)
	if _is_ray_unblocked(player_eye, torso_pos, target):
		visible_parts |= BodyPartVisibility.TORSO
	
	# LEGS
	var legs_pos = target_pos + Vector3(0, target_eye_height * 0.3, 0)
	if _is_ray_unblocked(player_eye, legs_pos, target):
		visible_parts |= BodyPartVisibility.LEGS
	
	return visible_parts

func _is_ray_unblocked(from: Vector3, to: Vector3, exclude_target: Node = null) -> bool:
	"""
	EINFACHER RAY: Schießt gerade vom Eye zum Enemy.
	ALLES dazwischen blockiert - egal ob Cover oder Floor!
	"""
	var space_state = owner_merc.get_world_3d().direct_space_state
	if not space_state:
		return true
	
	# Ray Cast
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b111  # Check all layers
	
	# Exclude player selbst
	var exclude_list = [owner_merc]
	if exclude_target:
		exclude_list.append(exclude_target)
	query.exclude = exclude_list
	
	var result = space_state.intersect_ray(query)
	
	# Kein Hit = freie Sichtlinie
	if result.is_empty():
		return true
	
	# Hit something = blockiert (alles!)
	var collider = result.collider
	var collider_name = collider.name if collider else "Unknown"
	print("[LoS]   Ray blocked by: %s" % collider_name)
	return false

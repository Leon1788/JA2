extends Node
class_name LineOfSightSystem

# Körperteil-Höhen (relativ zur Basis des Söldners)
const BODY_PART_HEIGHTS = {
	"head": 1.7,
	"thorax": 1.2,
	"stomach": 0.9,
	"left_arm": 1.1,
	"right_arm": 1.1,
	"left_leg": 0.4,
	"right_leg": 0.4
}

class LOSResult:
	var can_see: bool = false
	var blocked_by_cover: CoverObject = null
	var visible_body_parts: Array[String] = []
	var blocked_body_parts: Array[String] = []

static func check_line_of_sight(shooter: Merc, target: Merc, grid_manager: GridManager, world: World3D) -> LOSResult:
	var result = LOSResult.new()
	
	var shooter_eye = shooter.get_eye_position()
	var target_base = target.global_position
	
	# Prüfe jedes Körperteil einzeln
	for body_part in BODY_PART_HEIGHTS.keys():
		var target_part_height = BODY_PART_HEIGHTS[body_part]
		var target_part_pos = target_base + Vector3(0, target_part_height, 0)
		
		# 3D Raycast von Schütze zu diesem Körperteil
		var can_see_part = _raycast_to_body_part(shooter_eye, target_part_pos, grid_manager, world)
		
		if can_see_part:
			result.visible_body_parts.append(body_part)
			result.can_see = true
		else:
			result.blocked_body_parts.append(body_part)
	
	return result

static func _raycast_to_body_part(from: Vector3, to: Vector3, grid_manager: GridManager, world: World3D) -> bool:
	# Einfache Grid-basierte Prüfung für jetzt
	# Später: Echte 3D Raycasts
	
	var from_grid = grid_manager.world_to_grid(from)
	var to_grid = grid_manager.world_to_grid(to)
	
	# Prüfe ob Cover in der Linie ist
	var cover = grid_manager.get_cover_between(from_grid, to_grid)
	if not cover:
		return true  # Keine Blockierung
	
	# Prüfe ob Cover hoch genug ist um zu blockieren
	var ray_height = (from.y + to.y) / 2.0  # Durchschnittliche Höhe des Rays
	
	if cover.cover_data.blocks_line_of_sight(ray_height):
		return false  # Blockiert
	
	return true  # Cover zu niedrig, Ray geht drüber

static func get_visible_body_parts_for_ui(shooter: Merc, target: Merc, grid_manager: GridManager, world: World3D) -> Dictionary:
	var result = check_line_of_sight(shooter, target, grid_manager, world)
	
	# Mapping von String zu BodyPart Enum
	var visible_parts = {}
	
	if "head" in result.visible_body_parts:
		visible_parts[TargetingSystem.BodyPart.HEAD] = true
	if "thorax" in result.visible_body_parts:
		visible_parts[TargetingSystem.BodyPart.THORAX] = true
	if "stomach" in result.visible_body_parts:
		visible_parts[TargetingSystem.BodyPart.STOMACH] = true
	if "left_arm" in result.visible_body_parts:
		visible_parts[TargetingSystem.BodyPart.LEFT_ARM] = true
	if "right_arm" in result.visible_body_parts:
		visible_parts[TargetingSystem.BodyPart.RIGHT_ARM] = true
	if "left_leg" in result.visible_body_parts:
		visible_parts[TargetingSystem.BodyPart.LEFT_LEG] = true
	if "right_leg" in result.visible_body_parts:
		visible_parts[TargetingSystem.BodyPart.RIGHT_LEG] = true
	
	return visible_parts

extends Node
class_name MovementComponent

const AP_COST_PER_TILE: int = 2

var owner_entity: Node3D
var grid_manager: GridManager
var action_point_component: ActionPointComponent

var current_grid_pos: Vector2i

func initialize(entity: Node3D, grid_mgr: GridManager, ap_component: ActionPointComponent) -> void:
	owner_entity = entity
	grid_manager = grid_mgr
	action_point_component = ap_component
	
	# Setze initiale Grid-Position basierend auf World-Position
	current_grid_pos = grid_manager.world_to_grid(owner_entity.global_position)
	grid_manager.occupy_tile(current_grid_pos, owner_entity)

func can_move_to(target_grid_pos: Vector2i) -> bool:
	# Prüfe ob Ziel begehbar ist
	if not grid_manager.is_tile_walkable(target_grid_pos):
		return false
	
	# Prüfe ob genug AP vorhanden
	var distance = _calculate_distance(current_grid_pos, target_grid_pos)
	var ap_cost = distance * AP_COST_PER_TILE
	
	return action_point_component.has_ap(ap_cost)

func move_to(target_grid_pos: Vector2i) -> bool:
	if not can_move_to(target_grid_pos):
		return false
	
	var distance = _calculate_distance(current_grid_pos, target_grid_pos)
	
	# Apply status effect modifier
	var ap_modifier = 1.0
	if owner_entity.has_node("StatusEffectSystem"):
		var status_system = owner_entity.get_node("StatusEffectSystem")
		ap_modifier = status_system.get_movement_ap_modifier()
	
	var ap_cost = int(distance * AP_COST_PER_TILE * ap_modifier)
	
	# Spend AP
	if not action_point_component.spend_ap(ap_cost):
		return false
	
	# Update grid
	grid_manager.free_tile(current_grid_pos)
	current_grid_pos = target_grid_pos
	grid_manager.occupy_tile(current_grid_pos, owner_entity)
	
	# Move entity in world
	owner_entity.global_position = grid_manager.grid_to_world(target_grid_pos)
	
	return true

func _calculate_distance(from: Vector2i, to: Vector2i) -> int:
	# Manhattan distance
	return abs(to.x - from.x) + abs(to.y - from.y)

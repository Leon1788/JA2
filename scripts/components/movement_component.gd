extends Node
class_name MovementComponent

const AP_COST_PER_TILE: int = 2

var owner_entity: Node3D
var grid_manager: GridManager
var action_point_component: ActionPointComponent

# ===== ALTE 2D-SYSTEM (UNVERÄNDERT) =====
var current_grid_pos: Vector2i

# ===== NEUE 3D-SYSTEM =====
var current_floor: int = 0  # Welche Etage

# ===== ALTE FUNKTIONEN (UNVERÄNDERT) =====

func initialize(entity: Node3D, grid_mgr: GridManager, ap_component: ActionPointComponent) -> void:
	owner_entity = entity
	grid_manager = grid_mgr
	action_point_component = ap_component
	
	# Setze initiale Grid-Position basierend auf World-Position
	current_grid_pos = grid_manager.world_to_grid(owner_entity.global_position)
	grid_manager.occupy_tile(current_grid_pos, owner_entity)

func can_move_to(target_grid_pos: Vector2i) -> bool:
	if not grid_manager.is_tile_walkable(target_grid_pos):
		return false
	
	var distance = _calculate_distance(current_grid_pos, target_grid_pos)
	var ap_cost = distance * AP_COST_PER_TILE
	
	return action_point_component.has_ap(ap_cost)

func move_to(target_grid_pos: Vector2i) -> bool:
	if not can_move_to(target_grid_pos):
		return false
	
	var distance = _calculate_distance(current_grid_pos, target_grid_pos)
	
	var ap_modifier = 1.0
	if owner_entity.has_node("StatusEffectSystem"):
		var status_system = owner_entity.get_node("StatusEffectSystem")
		ap_modifier = status_system.get_movement_ap_modifier()
	
	var ap_cost = int(distance * AP_COST_PER_TILE * ap_modifier)
	
	if not action_point_component.spend_ap(ap_cost):
		return false
	
	grid_manager.free_tile(current_grid_pos)
	current_grid_pos = target_grid_pos
	grid_manager.occupy_tile(current_grid_pos, owner_entity)
	
	owner_entity.global_position = grid_manager.grid_to_world(target_grid_pos)
	
	return true

func _calculate_distance(from: Vector2i, to: Vector2i) -> int:
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	# Hybrid Distance: min(dx,dy) diagonale Schritte + abs(dx-dy) gerade Schritte
	return min(dx, dy) + abs(dx - dy)

# ===== NEUE 3D-FUNKTIONEN (ABSOLUT) =====

func can_move_to_grid_absolute(target_grid_pos: Vector2i, target_floor: int) -> bool:
	"""Prüft ob man zu absoluter Grid-Position auf Floor gehen kann"""
	if not grid_manager.is_within_bounds(target_grid_pos):
		return false
	
	var distance = _calculate_distance(current_grid_pos, target_grid_pos)
	
	var ap_modifier = 1.0
	if owner_entity.has_node("StatusEffectSystem"):
		var status_system = owner_entity.get_node("StatusEffectSystem")
		ap_modifier = status_system.get_movement_ap_modifier()
	
	var ap_cost = int(distance * AP_COST_PER_TILE * ap_modifier)
	
	return action_point_component.has_ap(ap_cost)

func move_to_grid_absolute(target_grid_pos: Vector2i, target_floor: int) -> bool:
	"""Bewegt Unit zu absoluter Grid-Position auf Floor"""
	if not can_move_to_grid_absolute(target_grid_pos, target_floor):
		return false
	
	var distance = _calculate_distance(current_grid_pos, target_grid_pos)
	
	var ap_modifier = 1.0
	if owner_entity.has_node("StatusEffectSystem"):
		var status_system = owner_entity.get_node("StatusEffectSystem")
		ap_modifier = status_system.get_movement_ap_modifier()
	
	var ap_cost = int(distance * AP_COST_PER_TILE * ap_modifier)
	
	if not action_point_component.spend_ap(ap_cost):
		return false
	
	# Update Position
	grid_manager.free_tile(current_grid_pos)
	current_grid_pos = target_grid_pos
	current_floor = target_floor
	grid_manager.occupy_tile(current_grid_pos, owner_entity)
	
	# Setze World-Position
	owner_entity.global_position = grid_manager.grid_to_world(current_grid_pos)
	# Y-Höhe nach Floor
	owner_entity.global_position.y = target_floor * 3.0
	
	return true

# ===== NEUE 3D-FUNKTIONEN =====

func initialize_3d(entity: Node3D, grid_mgr: GridManager, ap_component: ActionPointComponent) -> void:
	owner_entity = entity
	grid_manager = grid_mgr
	action_point_component = ap_component
	
	# Berechne 3D-Position
	var grid_3d = grid_manager.world_to_grid_3d(owner_entity.global_position)
	current_grid_pos = grid_3d["pos"]
	current_floor = grid_3d["floor"]
	
	grid_manager.occupy_tile_3d(current_grid_pos, current_floor, owner_entity)
	
	print("[Movement] Unit initialized at ", current_grid_pos, " floor ", current_floor)

func can_move_to_3d(target_grid_pos: Vector2i, target_floor: int) -> bool:
	# Prüfe ob Ziel begehbar
	if not grid_manager.is_tile_walkable_3d(target_grid_pos, target_floor):
		return false
	
	# Prüfe ob Ebenenwechsel (später: Treppen-Check)
	if target_floor != current_floor:
		print("[Movement] Ebenenwechsel noch nicht implementiert")
		return false
	
	# Berechne AP-Kosten (nur horizontal, da gleiche Etage)
	var distance = _calculate_distance(current_grid_pos, target_grid_pos)
	
	var ap_modifier = 1.0
	if owner_entity.has_node("StatusEffectSystem"):
		var status_system = owner_entity.get_node("StatusEffectSystem")
		ap_modifier = status_system.get_movement_ap_modifier()
	
	var ap_cost = int(distance * AP_COST_PER_TILE * ap_modifier)
	
	return action_point_component.has_ap(ap_cost)

func move_to_3d(target_grid_pos: Vector2i, target_floor: int) -> bool:
	if not can_move_to_3d(target_grid_pos, target_floor):
		return false
	
	var distance = _calculate_distance(current_grid_pos, target_grid_pos)
	
	var ap_modifier = 1.0
	if owner_entity.has_node("StatusEffectSystem"):
		var status_system = owner_entity.get_node("StatusEffectSystem")
		ap_modifier = status_system.get_movement_ap_modifier()
	
	var ap_cost = int(distance * AP_COST_PER_TILE * ap_modifier)
	
	if not action_point_component.spend_ap(ap_cost):
		return false
	
	# Update 3D grid
	grid_manager.free_tile_3d(current_grid_pos, current_floor)
	current_grid_pos = target_grid_pos
	current_floor = target_floor
	grid_manager.occupy_tile_3d(current_grid_pos, current_floor, owner_entity)
	
	# Move entity in 3D world
	owner_entity.global_position = grid_manager.grid_to_world_3d(target_grid_pos, target_floor)
	
	return true

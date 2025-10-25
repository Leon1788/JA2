extends Node
class_name MovementComponent

const AP_COST_PER_TILE: int = 2

var owner_entity: Node3D
var grid_manager: GridManager
var action_point_component: ActionPointComponent

# ===== ALTE 2D-SYSTEM (UNVERÄNDERT) =====
var current_grid_pos: Vector2i

# ===== NEUE 3D-SYSTEM =====
var current_floor: int = 0

# ===== ALTE FUNKTIONEN =====

func initialize(entity: Node3D, grid_mgr: GridManager, ap_component: ActionPointComponent) -> void:
	owner_entity = entity
	grid_manager = grid_mgr
	action_point_component = ap_component
	
	current_grid_pos = grid_manager.world_to_grid(owner_entity.global_position)
	grid_manager.occupy_tile(current_grid_pos, owner_entity)

func can_move_to(target_grid_pos: Vector2i) -> bool:
	if not grid_manager.is_within_bounds(target_grid_pos):
		return false
	
	if grid_manager.get_cover_at(target_grid_pos) != null:
		print("[Movement] Cannot move to ", target_grid_pos, " - COVER BLOCKING!")
		return false
	
	if grid_manager.grid_data.has(target_grid_pos):
		print("[Movement] Cannot move to ", target_grid_pos, " - OCCUPIED!")
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
	
	print("[Movement] Moved to ", target_grid_pos)
	return true

func _calculate_distance(from: Vector2i, to: Vector2i) -> int:
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	return min(dx, dy) + abs(dx - dy)

# ===== NEUE 3D-FUNKTIONEN =====

func initialize_3d(entity: Node3D, grid_mgr: GridManager, ap_component: ActionPointComponent) -> void:
	owner_entity = entity
	grid_manager = grid_mgr
	action_point_component = ap_component
	
	var grid_3d = grid_manager.world_to_grid_3d(owner_entity.global_position)
	current_grid_pos = grid_3d["pos"]
	current_floor = grid_3d["floor"]
	
	grid_manager.occupy_tile_3d(current_grid_pos, current_floor, owner_entity)
	
	print("[Movement] Unit initialized at ", current_grid_pos, " floor ", current_floor)

func can_move_to_3d(target_grid_pos: Vector2i, target_floor: int) -> bool:
	# PRÜFUNG 1: GridManager - ist Tile begehbar?
	if not grid_manager.is_tile_walkable_3d(target_grid_pos, target_floor):
		print("[Movement] Cannot move to ", target_grid_pos, " floor ", target_floor, " - NOT WALKABLE (Cover/Floor blocking)")
		return false
	
	# PRÜFUNG 2: Ist jemand dort?
	if grid_manager.floor_data.has(target_floor) and grid_manager.floor_data[target_floor].has(target_grid_pos):
		print("[Movement] Cannot move to ", target_grid_pos, " floor ", target_floor, " - OCCUPIED!")
		return false
	
	# PRÜFUNG 3: PHYSICS COLLISION CHECK - Kann Capsule dort hin ohne durch Cover zu gehen?
	if not _can_physically_move_to(target_grid_pos, target_floor):
		print("[Movement] Cannot move to ", target_grid_pos, " floor ", target_floor, " - COLLISION BLOCKED!")
		return false
	
	# PRÜFUNG 4: Habe ich AP?
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
	
	grid_manager.free_tile_3d(current_grid_pos, current_floor)
	current_grid_pos = target_grid_pos
	current_floor = target_floor
	grid_manager.occupy_tile_3d(current_grid_pos, current_floor, owner_entity)
	
	owner_entity.global_position = grid_manager.grid_to_world_3d(target_grid_pos, target_floor)
	
	print("[Movement] Moved to ", target_grid_pos, " floor ", target_floor)
	return true

# ===== PHYSICS COLLISION CHECK (NEU) =====

func _can_physically_move_to(target_grid_pos: Vector2i, target_floor: int) -> bool:
	"""Macht einen Raycast/Shape-Cast um zu prüfen ob Capsule dort passen würde"""
	
	var space_state = owner_entity.get_world_3d().direct_space_state
	if not space_state:
		print("[Movement] WARNING: No physics space state!")
		return true
	
	# Aktuelle und Ziel-Position
	var from_pos = owner_entity.global_position
	var to_world = grid_manager.grid_to_world_3d(target_grid_pos, target_floor)
	
	# Shape Cast: Prüfe ob Capsule des Mercs dort passen würde
	var shape = owner_entity.get_node_or_null("CollisionShape3D")
	if not shape or not shape.shape:
		print("[Movement] WARNING: No CollisionShape3D found on ", owner_entity.name)
		return true
	
	# Erstelle ShapecastQuery
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = Transform3D(Basis.IDENTITY, to_world)
	query.collision_mask = 0b111  # Check all layers
	
	# Exclude self
	query.exclude = [owner_entity]
	
	var result = space_state.intersect_shape(query)
	
	if result.size() > 0:
		# Collision found - aber nur wenn es NICHT der Boden selbst ist!
		var blocked = false
		var exclude_list = []
		
		for collision in result:
			var collider = collision.collider
			
			# WICHTIG: FloorObject/FloorTile sind OK - das ist der Boden!
			if collider is FloorObject or collider is FloorTile:
				exclude_list.append(collider.name)
				continue
			
			# ALLES ANDERE blockiert (Cover, andere Units, etc.)
			blocked = true
			print("[Movement] Physics collision detected at ", target_grid_pos)
			print("  - Collides with: ", collider.name, " (", collider.get_class(), ")")
		
		if exclude_list.size() > 0:
			print("[Movement] Floor collisions ignored: ", exclude_list)
		
		if blocked:
			return false
	
	# No collision - kann dorthin
	return true

# ===== KOMPATIBILITÄTS-FUNKTIONEN =====

func can_move_to_grid_absolute(target_grid_pos: Vector2i, target_floor: int) -> bool:
	return can_move_to_3d(target_grid_pos, target_floor)

func move_to_grid_absolute(target_grid_pos: Vector2i, target_floor: int) -> bool:
	return move_to_3d(target_grid_pos, target_floor)

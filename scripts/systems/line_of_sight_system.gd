extends Node
class_name LineOfSightSystem

enum BodyPartVisibility {
	NONE = 0,
	HEAD = 1,
	TORSO = 2,
	LEGS = 4
}

var owner_merc: Merc
var visible_body_parts_cache: Dictionary = {}  # target Merc -> int (Bitflags)
var cache_dirty: bool = true

func initialize(merc: Merc) -> void:
	owner_merc = merc
	print("[LoS] ", owner_merc.merc_data.merc_name, " LineOfSightSystem initialized")

func invalidate_cache() -> void:
	cache_dirty = true
	print("[LoS] ", owner_merc.merc_data.merc_name, " cache invalidated")

func can_see_enemy(target: Merc) -> bool:
	if not target or not target.is_alive():
		return false
	
	# Stage 1: FOV Grid Check
	var target_grid_pos = target.movement_component.current_grid_pos
	if not owner_merc.can_see_position(target_grid_pos):
		print("[LoS] ", owner_merc.merc_data.merc_name, " cannot see ", target.merc_data.merc_name, " - NOT IN FOV GRID")
		return false
	
	print("[LoS] ", owner_merc.merc_data.merc_name, " checking ", target.merc_data.merc_name, " - IN FOV GRID, doing raycast check...")
	
	# Stage 2: Physical Raycast Check
	# WICHTIG: Erst Raycasts machen, dann Cache nutzen!
	if cache_dirty:
		_recalculate_visible_enemies()
	
	var visible_parts = 0
	if visible_body_parts_cache.has(target):
		visible_parts = visible_body_parts_cache[target]
	
	var can_see = visible_parts > 0
	
	print("[LoS] ", owner_merc.merc_data.merc_name, " can see ", target.merc_data.merc_name, ": ", can_see, " (parts: ", visible_parts, ")")
	return can_see

func get_visible_body_parts(target: Merc) -> int:
	if cache_dirty:
		_recalculate_visible_enemies()
	
	if visible_body_parts_cache.has(target):
		return visible_body_parts_cache[target]
	return BodyPartVisibility.NONE

func _recalculate_visible_enemies() -> void:
	print("\n[LoS] === RECALCULATING VISIBLE ENEMIES for ", owner_merc.merc_data.merc_name, " ===")
	visible_body_parts_cache.clear()
	
	var all_enemies = _get_all_enemies()
	print("[LoS] Checking ", all_enemies.size(), " potential enemies")
	
	for enemy in all_enemies:
		if not enemy.is_alive():
			continue
		
		# Stage 1: FOV Grid Check
		var target_grid_pos = enemy.movement_component.current_grid_pos
		if not owner_merc.can_see_position(target_grid_pos):
			print("[LoS]   ", enemy.merc_data.merc_name, " at ", target_grid_pos, " - NOT IN FOV GRID")
			continue
		
		print("[LoS]   ", enemy.merc_data.merc_name, " at ", target_grid_pos, " - IN FOV GRID, checking raycasts...")
		
		var visible_parts = 0
		
		# Ray 1: Head
		if _check_raycast(enemy, "head"):
			visible_parts |= BodyPartVisibility.HEAD
			print("[LoS]     HEAD: VISIBLE")
		else:
			print("[LoS]     HEAD: BLOCKED")
		
		# Ray 2: Torso
		if _check_raycast(enemy, "torso"):
			visible_parts |= BodyPartVisibility.TORSO
			print("[LoS]     TORSO: VISIBLE")
		else:
			print("[LoS]     TORSO: BLOCKED")
		
		# Ray 3: Legs
		if _check_raycast(enemy, "legs"):
			visible_parts |= BodyPartVisibility.LEGS
			print("[LoS]     LEGS: VISIBLE")
		else:
			print("[LoS]     LEGS: BLOCKED")
		
		if visible_parts > 0:
			visible_body_parts_cache[enemy] = visible_parts
			print("[LoS]   RESULT: ", enemy.merc_data.merc_name, " visible with parts: ", visible_parts)
		else:
			print("[LoS]   RESULT: ", enemy.merc_data.merc_name, " NOT VISIBLE (all parts blocked)")
	
	cache_dirty = false
	print("[LoS] === RECALCULATION COMPLETE ===\n")

func _check_raycast(target: Merc, body_part: String) -> bool:
	var from = owner_merc.get_eye_position()
	var to = _get_target_position(target, body_part)
	
	var space_state = owner_merc.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# WICHTIG: Ignoriere Shooter UND Target!
	# Wenn der Ray irgendwas trifft = Hindernis dazwischen = blockiert
	# Wenn der Ray nichts trifft = freie Sicht
	query.exclude = [owner_merc, target]
	
	# Collision Mask: Check Layers 1 (Environment) + 2 (Units) + 3 (Cover)
	# Layer 1 = bit 0 (value 1)
	# Layer 2 = bit 1 (value 2)  
	# Layer 3 = bit 2 (value 4)
	# Total: 1 + 2 + 4 = 7
	query.collision_mask = 7
	
	var result = space_state.intersect_ray(query)
	
	# ZUSÄTZLICHER CHECK: Manuelle Höhen-Prüfung für Cover
	var manual_cover_check = _manual_cover_height_check(from, to)
	if manual_cover_check:
		print("[LoS]       Ray ", body_part, ": ", from, " -> ", to, " = BLOCKED by cover height check")
		return false
	
	if not result:
		# No collision = free line of sight
		print("[LoS]       Ray ", body_part, ": ", from, " -> ", to, " = CLEAR (no obstruction)")
		return true
	
	# Hit something = blocked by obstacle
	var collider_name = result.collider.name if result.collider else "Unknown"
	var hit_point = result.position
	print("[LoS]       Ray ", body_part, ": ", from, " -> ", to, " = BLOCKED by ", collider_name, " at ", hit_point)
	
	return false

func _manual_cover_height_check(from: Vector3, to: Vector3) -> bool:
	# Hole Grid Manager
	if not owner_merc.grid_manager_ref:
		return false
	
	var grid_manager = owner_merc.grid_manager_ref
	
	# Berechne Ray-Linie (Bresenham auf Grid)
	var from_grid = grid_manager.world_to_grid(from)
	var to_grid = grid_manager.world_to_grid(to)
	var line_tiles = _bresenham_line(from_grid, to_grid)
	
	# Prüfe jeden Tile auf der Linie
	for tile_pos in line_tiles:
		# Skip Start und Ziel
		if tile_pos == from_grid or tile_pos == to_grid:
			continue
		
		# Gibt es Cover an dieser Position?
		var cover = grid_manager.get_cover_at(tile_pos)
		if not cover or not cover.cover_data:
			continue
		
		# Berechne Ray-Höhe an dieser Grid-Position
		var ray_height_at_tile = _calculate_ray_height_at_position(from, to, tile_pos, grid_manager)
		var cover_height = cover.cover_data.cover_height
		
		# Blockiert wenn Ray unter Cover-Höhe ist
		if ray_height_at_tile < cover_height:
			print("[LoS]         Manual check: Ray at height ", ray_height_at_tile, "m hits cover (", cover_height, "m) at tile ", tile_pos)
			return true
	
	return false

func _calculate_ray_height_at_position(from: Vector3, to: Vector3, grid_pos: Vector2i, grid_manager: GridManager) -> float:
	# Konvertiere Grid-Position zu World-Position
	var tile_world = grid_manager.grid_to_world(grid_pos)
	
	# Berechne Distanz von "from" zu dieser Tile
	var total_distance = Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	var distance_to_tile = Vector2(from.x, from.z).distance_to(Vector2(tile_world.x, tile_world.z))
	
	if total_distance == 0:
		return from.y
	
	# Interpoliere Höhe basierend auf Distanz
	var t = distance_to_tile / total_distance
	var ray_height = lerp(from.y, to.y, t)
	
	return ray_height

func _bresenham_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx = abs(to.x - from.x)
	var dy = -abs(to.y - from.y)
	var x = from.x
	var y = from.y
	var x_inc = 1 if to.x > from.x else -1
	var y_inc = 1 if to.y > from.y else -1
	var error = dx + dy
	
	while true:
		points.append(Vector2i(x, y))
		
		if x == to.x and y == to.y:
			break
		
		var e2 = 2 * error
		if e2 >= dy:
			if x == to.x: break
			error += dy
			x += x_inc
		if e2 <= dx:
			if y == to.y: break
			error += dx
			y += y_inc
	
	return points

func _is_part_of_target(collider: Node, target: Merc) -> bool:
	# Check if collider is a child of target (e.g. VisualRoot)
	var parent = collider.get_parent()
	while parent:
		if parent == target:
			return true
		parent = parent.get_parent()
	return false

func _get_target_position(target: Merc, body_part: String) -> Vector3:
	var stance_height = target.stance_system.get_eye_height()
	
	match body_part:
		"head":
			return target.global_position + Vector3(0, stance_height, 0)
		"torso":
			return target.global_position + Vector3(0, stance_height * 0.6, 0)
		"legs":
			return target.global_position + Vector3(0, stance_height * 0.3, 0)
	
	return target.global_position

func _get_all_enemies() -> Array[Merc]:
	var enemies: Array[Merc] = []
	
	# Get turn manager - it's in the same scene as the merc
	if not owner_merc:
		print("[LoS] WARNING: owner_merc is null!")
		return enemies
	
	var scene_root = owner_merc.get_parent()
	if not scene_root:
		print("[LoS] WARNING: Cannot get parent scene!")
		return enemies
	
	# Try to find TurnManager in scene
	var turn_manager = scene_root.get_node_or_null("TurnManager")
	if not turn_manager:
		# Try alternative: maybe it's a child of scene root
		for child in scene_root.get_children():
			if child is TurnManager:
				turn_manager = child
				break
	
	if not turn_manager:
		print("[LoS] WARNING: TurnManager not found in scene!")
		print("[LoS] Scene root: ", scene_root.name)
		print("[LoS] Children: ", scene_root.get_child_count())
		for child in scene_root.get_children():
			print("[LoS]   - ", child.name, " (", child.get_class(), ")")
		return enemies
	
	# If we're player, get enemies; if enemy, get players
	if owner_merc.is_player_unit:
		enemies.assign(turn_manager.enemy_units)
		print("[LoS] Found ", enemies.size(), " enemies for player")
	else:
		enemies.assign(turn_manager.player_units)
		print("[LoS] Found ", enemies.size(), " players for enemy")
	
	return enemies

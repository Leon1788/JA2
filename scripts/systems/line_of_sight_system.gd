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

# ===== ALTE 2D-FUNKTIONEN (UNVERÄNDERT) =====

func can_see_enemy(target: Merc) -> bool:
	if not target or not target.is_alive():
		return false
	
	var target_grid_pos = target.movement_component.current_grid_pos
	var target_floor = target.movement_component.current_floor
	
	# Stage 1: FOV Grid Check (NEUE 3D-Version!)
	if not owner_merc.can_see_position_3d(target_grid_pos, target_floor):
		print("[LoS] ", owner_merc.merc_data.merc_name, " cannot see ", target.merc_data.merc_name, 
			  " at Floor ", target_floor, " - NOT IN FOV GRID")
		return false
	
	print("[LoS] ", owner_merc.merc_data.merc_name, " checking ", target.merc_data.merc_name, 
		  " (Floor ", target_floor, ") - IN FOV GRID, doing raycast check...")
	
	# Stage 2: 3D Raycast Check (Code-based, keine Collider!)
	var visible_parts = _check_visible_parts_3d(target)
	var can_see = visible_parts > 0
	
	if can_see:
		print("[LoS] ", owner_merc.merc_data.merc_name, " can see ", target.merc_data.merc_name, ": TRUE (parts: ", visible_parts, ")")
	else:
		print("[LoS] ", owner_merc.merc_data.merc_name, " can see ", target.merc_data.merc_name, ": FALSE (blocked)")
	
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
		
		# Stage 1: FOV Grid Check (ALTE 2D-Version für gleiche Etage)
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
	query.exclude = [owner_merc, target]
	
	# Collision Mask: Check Layers 1 (Environment) + 2 (Units) + 3 (Cover)
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

# ===== NEUE 3D-FUNKTIONEN =====

func can_see_enemy_3d(target: Merc) -> bool:
	"""
	Neue 3D-Version die auch andere Etagen berücksichtigt
	"""
	if not target or not target.is_alive():
		return false
	
	# Stage 1: FOV Grid Check (NEUE 3D-Version)
	var target_grid_pos = target.movement_component.current_grid_pos
	var target_floor = target.movement_component.current_floor
	
	if not owner_merc.can_see_position_3d(target_grid_pos, target_floor):
		print("[LoS] ", owner_merc.merc_data.merc_name, " cannot see ", target.merc_data.merc_name, 
			  " at Floor ", target_floor, " - NOT IN FOV GRID")
		return false
	
	print("[LoS] ", owner_merc.merc_data.merc_name, " checking ", target.merc_data.merc_name, 
		  " (Floor ", target_floor, ") - IN FOV GRID, doing raycast check...")
	
	# Stage 2: 3D Raycast Check
	var visible_parts = 0
	
	# Ray 1: Head
	if _check_raycast_3d(target, "head"):
		visible_parts |= BodyPartVisibility.HEAD
		print("[LoS]     HEAD: VISIBLE")
	else:
		print("[LoS]     HEAD: BLOCKED")
	
	# Ray 2: Torso
	if _check_raycast_3d(target, "torso"):
		visible_parts |= BodyPartVisibility.TORSO
		print("[LoS]     TORSO: VISIBLE")
	else:
		print("[LoS]     TORSO: BLOCKED")
	
	# Ray 3: Legs
	if _check_raycast_3d(target, "legs"):
		visible_parts |= BodyPartVisibility.LEGS
		print("[LoS]     LEGS: VISIBLE")
	else:
		print("[LoS]     LEGS: BLOCKED")
	
	var can_see = visible_parts > 0
	
	if can_see:
		print("[LoS] RESULT 3D: ", target.merc_data.merc_name, " visible with parts: ", visible_parts)
	else:
		print("[LoS] RESULT 3D: ", target.merc_data.merc_name, " NOT VISIBLE")
	
	return can_see

func _check_raycast_3d(target: Merc, body_part: String) -> bool:
	"""
	3D Raycast mit korrekten Höhen für verschiedene Etagen
	"""
	# Berechne Start-Position (Augenhöhe des Schützen mit Etagen-Offset)
	var shooter_floor = owner_merc.movement_component.current_floor
	var shooter_eye_height = owner_merc.stance_system.get_eye_height()
	var shooter_floor_base = shooter_floor * GridManager.FLOOR_HEIGHT
	var from = owner_merc.global_position + Vector3(0, shooter_floor_base + shooter_eye_height, 0)
	
	# Berechne Ziel-Position (Körperteil mit Etagen-Offset)
	var target_floor = target.movement_component.current_floor
	var target_floor_base = target_floor * GridManager.FLOOR_HEIGHT
	var to = _get_target_position_3d(target, body_part, target_floor_base)
	
	print("[LoS]     Raycast 3D ", body_part, ": from (floor ", shooter_floor, " height ", from.y, "m) to (floor ", 
		  target_floor, " height ", to.y, "m)")
	
	var space_state = owner_merc.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# Ignoriere Shooter und Target
	query.exclude = [owner_merc, target]
	
	# Collision Mask: 7 (Environment + Units + Cover)
	query.collision_mask = 7
	
	var result = space_state.intersect_ray(query)
	
	# ZUSÄTZLICHER CHECK: Manuelle Höhen-Prüfung für Cover (auch 3D)
	var manual_cover_check = _manual_cover_height_check(from, to)
	if manual_cover_check:
		print("[LoS]       → BLOCKED by cover height check")
		return false
	
	if not result:
		print("[LoS]       → CLEAR (no obstruction)")
		return true
	
	var collider_name = result.collider.name if result.collider else "Unknown"
	print("[LoS]       → BLOCKED by ", collider_name)
	
	return false

func _get_target_position_3d(target: Merc, body_part: String, floor_base_height: float) -> Vector3:
	"""Alte Funktion - wird nicht mehr gebraucht"""
	var stance_height = target.stance_system.get_eye_height()
	
	match body_part:
		"head":
			return target.global_position + Vector3(0, floor_base_height + stance_height, 0)
		"torso":
			return target.global_position + Vector3(0, floor_base_height + stance_height * 0.6, 0)
		"legs":
			return target.global_position + Vector3(0, floor_base_height + stance_height * 0.3, 0)
	
	return target.global_position + Vector3(0, floor_base_height, 0)

# ===== NEUE CODE-BASIERTE 3D RAYCAST FUNKTIONEN =====

func _check_visible_parts_3d(target: Merc) -> int:
	"""
	Code-basierte Raycast-Simulation (KEINE Godot Collider nötig!)
	Prüft ob Head/Torso/Legs sichtbar sind mit Cover-Blöcken
	"""
	var visible_parts = 0
	
	# Ray 1: Head
	if _raycast_3d_code(target, "head"):
		visible_parts |= BodyPartVisibility.HEAD
		print("[LoS]     HEAD: VISIBLE")
	else:
		print("[LoS]     HEAD: BLOCKED")
	
	# Ray 2: Torso
	if _raycast_3d_code(target, "torso"):
		visible_parts |= BodyPartVisibility.TORSO
		print("[LoS]     TORSO: VISIBLE")
	else:
		print("[LoS]     TORSO: BLOCKED")
	
	# Ray 3: Legs
	if _raycast_3d_code(target, "legs"):
		visible_parts |= BodyPartVisibility.LEGS
		print("[LoS]     LEGS: VISIBLE")
	else:
		print("[LoS]     LEGS: BLOCKED")
	
	return visible_parts

func _raycast_3d_code(target: Merc, body_part: String) -> bool:
	"""
	Simuliert einen Raycast mit CODE statt Godot Physics!
	Prüft Cover-Blöcke auf der Ray-Linie
	"""
	# Berechne Start (Augenhöhe Schütze) - KORREKT!
	var from = owner_merc.get_eye_position()
	var shooter_floor = owner_merc.movement_component.current_floor
	
	# Berechne Ziel (Körperteil Ziel) - KORREKT!
	var target_floor = target.movement_component.current_floor
	var target_floor_base = target_floor * GridManager.FLOOR_HEIGHT
	var target_stance_height = target.stance_system.get_eye_height()
	
	var to: Vector3
	match body_part:
		"head":
			to = target.global_position + Vector3(0, target_stance_height, 0)
		"torso":
			to = target.global_position + Vector3(0, target_stance_height * 0.6, 0)
		"legs":
			to = target.global_position + Vector3(0, target_stance_height * 0.3, 0)
		_:
			to = target.global_position
	
	print("[LoS]     Ray %s: from (%.2f, %.2f, %.2f) [Floor %d] to (%.2f, %.2f, %.2f) [Floor %d]" % [
		body_part,
		from.x, from.y, from.z,
		shooter_floor,
		to.x, to.y, to.z,
		target_floor
	])
	
	# Prüfe Cover entlang der Ray-Linie (mit target_floor!)
	var is_blocked = _check_cover_along_ray_3d(from, to, target_floor)
	
	if is_blocked:
		print("[LoS]       → BLOCKED by cover")
		return false
	
	print("[LoS]       → CLEAR")
	return true

func _check_cover_along_ray_3d(from: Vector3, to: Vector3, target_floor: int) -> bool:
	"""
	Code-basiert: Prüfe ob ECHTES COVER die Ray blockiert (Wände, Kisten etc.)
	Floors werden separat geprüft! get_cover_at_3d() gibt nur CoverObject zurück.
	"""
	if not owner_merc.grid_manager_ref:
		return false
	
	var grid_manager = owner_merc.grid_manager_ref
	
	# Nutze current_floor!
	var from_floor = owner_merc.movement_component.current_floor
	var to_floor = target_floor
	
	print("[LoS]         Checking REAL covers from Floor %d to Floor %d" % [from_floor, to_floor])
	
	# Bresenham-Linie auf Grid-Ebene
	var from_grid = grid_manager.world_to_grid(from)
	var to_grid = grid_manager.world_to_grid(to)
	var line_tiles = _bresenham_line(from_grid, to_grid)
	
	print("[LoS]         Ray line: %d tiles from %s to %s" % [line_tiles.size(), from_grid, to_grid])
	
	# Prüfe jeden Tile
	for tile_pos in line_tiles:
		if tile_pos == from_grid or tile_pos == to_grid:
			continue
		
		# Prüfe ALLE Floors zwischen from_floor und to_floor
		var min_floor = min(from_floor, to_floor)
		var max_floor = max(from_floor, to_floor)
		
		for check_floor in range(min_floor, max_floor + 1):
			# Gibt es ECHTES Cover (nicht Floor!)
			var cover = grid_manager.get_cover_at_3d(tile_pos, check_floor)
			
			if not cover:
				continue
			
			# get_cover_at_3d() gibt nur CoverObject zurück (Floors sind rausgefiltert!)
			print("[LoS]         Tile %s Floor %d: REAL cover found (height=%.2fm)" % [tile_pos, check_floor, cover.cover_data.cover_height])
			
			# Berechne Ray-Höhe an diesem Tile
			var ray_height = _lerp_3d_height(from, to, tile_pos, grid_manager)
			var cover_base = check_floor * GridManager.FLOOR_HEIGHT
			var cover_top = cover_base + cover.cover_data.cover_height
			
			print("[LoS]           Ray height at tile: %.2fm" % ray_height)
			print("[LoS]           Cover range: %.2fm to %.2fm" % [cover_base, cover_top])
			print("[LoS]           Ray >= base? %s (%.2f >= %.2f)" % [ray_height >= cover_base, ray_height, cover_base])
			print("[LoS]           Ray <= top? %s (%.2f <= %.2f)" % [ray_height <= cover_top, ray_height, cover_top])
			
			# Ray blockiert wenn in Cover-Höhenbereich?
			if ray_height >= cover_base and ray_height <= cover_top:
				print("[LoS]         Cover at %s (Floor %d): ray_height=%.2fm in range [%.2fm-%.2fm] → BLOCKED" % 
					[tile_pos, check_floor, ray_height, cover_base, cover_top])
				return true
	
	# Prüfe Floor-Crossing separat (nur wenn zwischen verschiedenen Etagen!)
	if from_floor != to_floor:
		if _check_floor_crossing(from, to, from_floor, to_floor, grid_manager):
			return true
	
	return false

func _check_floor_crossing(from: Vector3, to: Vector3, from_floor: int, to_floor: int, grid_manager: GridManager) -> bool:
	"""
	Prüft ob Ray eine Floor-Ebene kreuzt (zwischen verschiedenen Etagen)
	Floors blockieren NUR vertikal, nicht horizontal!
	"""
	print("[LoS]         Checking floor crossing between Floor %d and %d" % [from_floor, to_floor])
	
	var min_floor = mini(from_floor, to_floor)
	var max_floor = maxi(from_floor, to_floor)
	
	# Prüfe jede Floor-Ebene zwischen from und to
	for floor_check in range(min_floor + 1, max_floor + 1):
		var floor_y = floor_check * GridManager.FLOOR_HEIGHT
		
		# Ray geht vertikal? (from.y != to.y)
		if abs(to.y - from.y) < 0.01:
			continue  # Horizontaler Ray, kreuzt keine Floor-Ebene
		
		# Berechne wo Ray die Floor-Ebene kreuzt
		var t = (floor_y - from.y) / (to.y - from.y)
		
		# Crossing liegt auf dem Ray? (t zwischen 0 und 1)
		if t >= 0.0 and t <= 1.0:
			var crossing_x = lerp(from.x, to.x, t)
			var crossing_z = lerp(from.z, to.z, t)
			var crossing_pos = Vector3(crossing_x, floor_y, crossing_z)
			var crossing_grid = grid_manager.world_to_grid(crossing_pos)
			
			# Gibt es einen Floor an dieser Position?
			if grid_manager.has_floor_at(crossing_grid, floor_check):
				print("[LoS]           Floor-Crossing: Ray kreuzt Floor %d bei Y=%.2fm → BLOCKED" % [floor_check, floor_y])
				return true
	
	return false

func _lerp_3d_height(from: Vector3, to: Vector3, grid_pos: Vector2i, grid_manager: GridManager) -> float:
	"""
	Interpoliere Ray-Höhe an einer bestimmten Grid-Position
	"""
	var tile_world = grid_manager.grid_to_world(grid_pos)
	
	# 2D Distanz (nur X-Z)
	var total_dist_2d = Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	var dist_to_tile_2d = Vector2(from.x, from.z).distance_to(Vector2(tile_world.x, tile_world.z))
	
	if total_dist_2d == 0:
		return from.y
	
	# Interpoliere Y basierend auf 2D-Distanz
	var t = dist_to_tile_2d / total_dist_2d
	var ray_height = lerp(from.y, to.y, t)
	
	return ray_height

# ===== HELPER FUNKTIONEN (UNVERÄNDERT) =====

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
	"""Alte 2D-Version ohne Etagen-Offset"""
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

extends Node
class_name FOVGridSystem

enum VisibilityLevel {
	BLOCKED = 0,
	PARTIAL = 1,  # Wird nicht mehr genutzt, aber bleibt für Kompatibilität
	CLEAR = 2
}

const MAX_SIGHT_RANGE: int = 15

static func calculate_fov_grid(soldier: Merc, grid_manager: GridManager) -> Dictionary:
	var fov_grid: Dictionary = {}
	var soldier_pos = soldier.movement_component.current_grid_pos
	var soldier_eye_height = soldier.stance_system.get_eye_height()
	var facing_angle = soldier.facing_system.get_facing_angle()
	var fov_angle = soldier.facing_system.fov_angle
	
	for x in range(soldier_pos.x - MAX_SIGHT_RANGE, soldier_pos.x + MAX_SIGHT_RANGE + 1):
		for y in range(soldier_pos.y - MAX_SIGHT_RANGE, soldier_pos.y + MAX_SIGHT_RANGE + 1):
			var target_pos = Vector2i(x, y)
			
			if not grid_manager.is_within_bounds(target_pos):
				continue
			
			var distance = soldier_pos.distance_to(target_pos)
			if distance > MAX_SIGHT_RANGE:
				continue
			
			if target_pos == soldier_pos:
				fov_grid[target_pos] = VisibilityLevel.CLEAR
				continue
			
			if not _is_in_fov_cone(soldier_pos, target_pos, facing_angle, fov_angle):
				fov_grid[target_pos] = VisibilityLevel.BLOCKED
				continue
			
			var visibility = _check_line_of_sight(soldier_pos, target_pos, soldier_eye_height, grid_manager)
			fov_grid[target_pos] = visibility
	
	return fov_grid

static func _is_in_fov_cone(from: Vector2i, to: Vector2i, facing_angle: float, fov_angle: float) -> bool:
	if from == to:
		return true
	
	var dx = float(to.x - from.x)
	var dy = float(to.y - from.y)
	
	var angle_to_target_rad = atan2(dx, -dy)
	var angle_to_target_deg = fmod(rad_to_deg(angle_to_target_rad) + 360.0, 360.0)
	
	var angle_diff = angle_to_target_deg - facing_angle
	
	while angle_diff > 180.0:
		angle_diff -= 360.0
	while angle_diff < -180.0:
		angle_diff += 360.0
	
	return abs(angle_diff) <= (fov_angle / 2.0)

static func _check_line_of_sight(from: Vector2i, to: Vector2i, eye_height: float, grid_manager: GridManager) -> int:
	var line = _bresenham_line(from, to)
	
	if line.size() <= 2:
		return VisibilityLevel.CLEAR
	
	# Prüfe alle Zellen zwischen Start und Ziel
	var highest_cover_height = 0.0
	var closest_cover_distance = 999.0
	var cover_found = false
	
	for i in range(1, line.size() - 1):
		var cell = line[i]
		var cover = grid_manager.get_cover_at(cell)
		
		if cover:
			cover_found = true
			var distance_to_cover = from.distance_to(cell)
			var cover_height = cover.cover_data.cover_height
			
			if cover_height > highest_cover_height:
				highest_cover_height = cover_height
				closest_cover_distance = distance_to_cover
	
	if not cover_found:
		return VisibilityLevel.CLEAR
	
	# Berechne Distanz vom Cover zum Ziel
	var total_distance = from.distance_to(to)
	var distance_beyond_cover = total_distance - closest_cover_distance
	
	# BINÄRES SYSTEM: Nur CLEAR oder BLOCKED
	
	# REGEL 1: Sehr nah am Cover (1-2 Tiles)
	if closest_cover_distance <= 2.0:
		# Hohe Wand = blockiert
		if highest_cover_height >= eye_height * 0.7:
			return VisibilityLevel.BLOCKED
		else:
			return VisibilityLevel.CLEAR
	
	# REGEL 2: Mittlere Distanz zum Cover (3-5 Tiles)
	elif closest_cover_distance <= 5.0:
		# Ziel NAH hinter Cover (1-3 Tiles)
		if distance_beyond_cover <= 3.0:
			if highest_cover_height >= 1.5:
				return VisibilityLevel.BLOCKED
			else:
				return VisibilityLevel.CLEAR
		# Ziel WEIT hinter Cover
		else:
			if highest_cover_height >= 2.5:
				return VisibilityLevel.BLOCKED
			else:
				return VisibilityLevel.CLEAR
	
	# REGEL 3: Weit weg vom Cover (6+ Tiles)
	else:
		# Ziel NAH hinter Cover
		if distance_beyond_cover <= 2.0:
			if highest_cover_height >= 2.0:
				return VisibilityLevel.BLOCKED
			else:
				return VisibilityLevel.CLEAR
		# Ziel WEIT hinter Cover
		else:
			# Aus der Ferne ist fast alles sichtbar
			return VisibilityLevel.CLEAR

static func _bresenham_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var x = from.x
	var y = from.y
	var x_inc = 1 if to.x > from.x else -1
	var y_inc = 1 if to.y > from.y else -1
	var error = dx - dy
	
	dx *= 2
	dy *= 2
	
	while true:
		points.append(Vector2i(x, y))
		
		if x == to.x and y == to.y:
			break
		
		# SYMMETRIE-FIX: Bei gleichem error, bevorzuge DIAGONALE
		if error == 0:
			x += x_inc
			y += y_inc
			error += dx - dy
		elif error > 0:
			x += x_inc
			error -= dy
		else:
			y += y_inc
			error += dx
	
	return points

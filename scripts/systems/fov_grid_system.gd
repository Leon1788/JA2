extends Node
class_name FOVGridSystem

enum VisibilityLevel {
	BLOCKED = 0,
	PARTIAL = 1,
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
	
	# Berechne Richtungsvektor (Grid-Space)
	var dx = float(to.x - from.x)
	var dy = float(to.y - from.y)
	
	# Grid: +X = Rechts (Ost), +Y = Runter (Süd)
	# Facing: 0° = Nord, 90° = Ost, 180° = Süd, 270° = West
	
	# Berechne Winkel zum Ziel in Godot-Koordinaten
	# atan2 gibt: 0° = +X (Ost), 90° = -Y (Nord in Godot), 180° = -X (West), -90° = +Y (Süd)
	# ABER: Grid +Y = Süd (nicht Nord!), also Y invertieren
	var angle_to_target_rad = atan2(dx, -dy)  # -dy weil Grid +Y = Süd
	var angle_to_target_deg = fmod(rad_to_deg(angle_to_target_rad) + 360.0, 360.0)
	
	# Berechne Differenz zwischen Facing und Target
	var angle_diff = angle_to_target_deg - facing_angle
	
	# Normalisiere auf -180 bis +180
	while angle_diff > 180.0:
		angle_diff -= 360.0
	while angle_diff < -180.0:
		angle_diff += 360.0
	
	var in_cone = abs(angle_diff) <= (fov_angle / 2.0)
	
	# DEBUG für kritische Tiles
	if from == Vector2i(5, 6) and (to.x == 5 and to.y < 5):
		print("DEBUG FOV_CONE: from=", from, " to=", to)
		print("  dx=", dx, " dy=", dy)
		print("  angle_to_target=", angle_to_target_deg, "°")
		print("  facing_angle=", facing_angle, "°")
		print("  angle_diff=", angle_diff, "°")
		print("  fov_angle/2=", fov_angle/2.0, "°")
		print("  IN_CONE=", in_cone)
	
	return in_cone

static func _check_line_of_sight(from: Vector2i, to: Vector2i, eye_height: float, grid_manager: GridManager) -> int:
	var line = _bresenham_line(from, to)
	
	# DEBUG für Tiles nach Norden von (5,6)
	var should_debug = (from == Vector2i(5, 6) and to.x == 5 and to.y < 6)
	
	if should_debug:
		print("\nDEBUG LoS: from=", from, " to=", to)
		print("  Line length: ", line.size())
		print("  Line: ", line)
	
	if line.size() <= 2:
		if should_debug:
			print("  >>> Result: CLEAR (line too short)")
		return VisibilityLevel.CLEAR
	
	var highest_cover_height = 0.0
	var closest_blocking_distance = 999.0
	
	for i in range(1, line.size() - 1):
		var cell = line[i]
		var cover = grid_manager.get_cover_at(cell)
		
		if should_debug:
			if cover:
				print("  [", i, "] Cover at ", cell, " height=", cover.cover_data.cover_height)
			else:
				print("  [", i, "] No cover at ", cell)
		
		if cover:
			var distance_to_cover = from.distance_to(cell)
			var cover_height = cover.cover_data.cover_height
			
			if cover_height > highest_cover_height:
				highest_cover_height = cover_height
				closest_blocking_distance = distance_to_cover
	
	if highest_cover_height == 0.0:
		if should_debug:
			print("  >>> Result: CLEAR (no cover)")
		return VisibilityLevel.CLEAR
	
	var distance = closest_blocking_distance
	
	if should_debug:
		print("  Highest cover: ", highest_cover_height, "m at distance ", distance)
		print("  Eye height: ", eye_height, "m")
	
	if distance <= 2:
		if highest_cover_height >= eye_height * 0.7:
			if should_debug:
				print("  >>> Result: BLOCKED (close + high)")
			return VisibilityLevel.BLOCKED
		else:
			if should_debug:
				print("  >>> Result: PARTIAL (close + low)")
			return VisibilityLevel.PARTIAL
	elif distance > 5:
		if highest_cover_height >= 2.5:
			if should_debug:
				print("  >>> Result: BLOCKED (far + very high)")
			return VisibilityLevel.BLOCKED
		else:
			if should_debug:
				print("  >>> Result: CLEAR (far + ok)")
			return VisibilityLevel.CLEAR
	else:
		if highest_cover_height >= 1.5:
			if should_debug:
				print("  >>> Result: BLOCKED (medium + high)")
			return VisibilityLevel.BLOCKED
		else:
			if should_debug:
				print("  >>> Result: PARTIAL (medium + medium)")
			return VisibilityLevel.PARTIAL

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
		
		if error > 0:
			x += x_inc
			error -= dy
		else:
			y += y_inc
			error += dx
	
	return points

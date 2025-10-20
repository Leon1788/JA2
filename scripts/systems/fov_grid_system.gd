extends Node
class_name FOVGridSystem

enum VisibilityLevel {
	BLOCKED = 0,    # ROT - nicht sichtbar
	PARTIAL = 1,    # GRÜN - durch Deckung sichtbar
	CLEAR = 2       # GELB - frei sichtbar
}

const MAX_SIGHT_RANGE: int = 15

# Berechnet FOV Grid für einen Soldaten
static func calculate_fov_grid(soldier: Merc, grid_manager: GridManager) -> Dictionary:
	var fov_grid: Dictionary = {}
	var soldier_pos = soldier.movement_component.current_grid_pos
	var soldier_eye_height = soldier.stance_system.get_eye_height()
	
	# WICHTIG: Visual Rotation ist negiert, also müssen wir auch negieren
	var facing_angle = soldier.facing_system.get_facing_angle()
	var visual_rotation_deg = rad_to_deg(soldier.rotation.y)
	
	# Debug
	print("FOV Calculate: logical_facing=", facing_angle, " visual_rotation=", visual_rotation_deg)
	
	# Nutze die visuelle Rotation statt der logischen!
	# Aber: Godot rotation.y ist clockwise, wir wollen counter-clockwise
	# Und: rotation.y = 0 ist -Z (Nord in Godot), aber wir wollen dass 0° = Nord
	var corrected_facing = fmod(-visual_rotation_deg + 360.0, 360.0)
	
	print("FOV Calculate: corrected_facing=", corrected_facing)
	
	var fov_angle = soldier.facing_system.fov_angle
	
	# Durchlaufe alle Tiles in Sichtweite
	for x in range(soldier_pos.x - MAX_SIGHT_RANGE, soldier_pos.x + MAX_SIGHT_RANGE + 1):
		for y in range(soldier_pos.y - MAX_SIGHT_RANGE, soldier_pos.y + MAX_SIGHT_RANGE + 1):
			var target_pos = Vector2i(x, y)
			
			# Skip wenn außerhalb Grid
			if not grid_manager.is_within_bounds(target_pos):
				continue
			
			# Skip wenn zu weit weg
			var distance = soldier_pos.distance_to(target_pos)
			if distance > MAX_SIGHT_RANGE:
				continue
			
			# Skip wenn selbst
			if target_pos == soldier_pos:
				fov_grid[target_pos] = VisibilityLevel.CLEAR
				continue
			
			# Prüfe ob im FOV Winkel
			if not _is_in_fov_cone(soldier_pos, target_pos, facing_angle, fov_angle):
				fov_grid[target_pos] = VisibilityLevel.BLOCKED
				continue
			
			# Prüfe Sichtlinie mit Höhen-Logik
			var visibility = _check_line_of_sight(soldier_pos, target_pos, soldier_eye_height, grid_manager)
			fov_grid[target_pos] = visibility
	
	return fov_grid

static func _is_in_fov_cone(from: Vector2i, to: Vector2i, facing_angle: float, fov_angle: float) -> bool:
	# Skip wenn gleiche Position
	if from == to:
		return true
	
	# Vector vom Soldaten zum Ziel (in Grid-Koordinaten)
	# Grid: +X = Rechts, +Y = Runter (WICHTIG!)
	var dx = float(to.x - from.x)
	var dy = float(to.y - from.y)
	
	# INVERTIERE Y weil Grid +Y = Süd, aber wir wollen +Y = Nord
	dy = -dy
	
	# Berechne Winkel in Grid-Koordinaten
	# atan2(dy, dx): 0° = Rechts/Ost, 90° = Hoch/Nord, 180° = Links/West, 270° = Runter/Süd
	var grid_angle = rad_to_deg(atan2(dy, dx))
	
	# Konvertiere zu unserem Facing-System
	# Facing: 0° = Nord, 90° = Ost, 180° = Süd, 270° = West
	# Grid nach Facing: facing = 90 - grid_angle
	var target_facing = fmod(90.0 - grid_angle + 360.0, 360.0)
	
	# Berechne Differenz
	var angle_diff = abs(target_facing - facing_angle)
	if angle_diff > 180:
		angle_diff = 360 - angle_diff
	
	var in_cone = angle_diff <= (fov_angle / 2.0)
	
	# Extended Debug
	if from == Vector2i(5, 3) and (to.y == 2 or to.y == 1):
		print("DEBUG FOV: from=", from, " to=", to)
		print("  dx=", dx, " dy(inverted)=", dy)
		print("  grid_angle=", grid_angle)
		print("  target_facing=", target_facing)
		print("  soldier_facing=", facing_angle)
		print("  angle_diff=", angle_diff)
		print("  IN_CONE=", in_cone)
	
	return in_cone

static func _check_line_of_sight(from: Vector2i, to: Vector2i, eye_height: float, grid_manager: GridManager) -> int:
	var line = _bresenham_line(from, to)
	
	# Skip wenn nur 2 Tiles (from + to, nichts dazwischen)
	if line.size() <= 2:
		return VisibilityLevel.CLEAR
	
	var worst_visibility = VisibilityLevel.CLEAR
	var highest_cover_height = 0.0
	var closest_blocking_distance = 999.0
	
	# Prüfe nur Zellen ZWISCHEN from und to (skip erste UND letzte!)
	for i in range(1, line.size() - 1):
		var cell = line[i]
		var cover = grid_manager.get_cover_at(cell)
		
		if cover:
			var distance_to_cover = from.distance_to(cell)
			var cover_height = cover.cover_data.cover_height
			
			# Track höchstes Cover
			if cover_height > highest_cover_height:
				highest_cover_height = cover_height
				closest_blocking_distance = distance_to_cover
	
	# Wenn kein Cover gefunden, freie Sicht
	if highest_cover_height == 0.0:
		return VisibilityLevel.CLEAR
	
	# Jetzt bewerten basierend auf höchstem Cover
	var distance = closest_blocking_distance
	
	# Vereinfachte Höhen-Regeln mit höchstem Cover
	if distance <= 2:
		# Nah an Deckung
		if highest_cover_height >= eye_height * 0.7:
			return VisibilityLevel.BLOCKED
		else:
			return VisibilityLevel.PARTIAL
	elif distance > 5:
		# Weit weg von Deckung
		if highest_cover_height >= 2.5:
			return VisibilityLevel.BLOCKED
		else:
			return VisibilityLevel.CLEAR
	else:
		# Mittlere Distanz
		if highest_cover_height >= 1.5:
			return VisibilityLevel.BLOCKED
		else:
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

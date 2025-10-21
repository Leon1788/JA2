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
	
	# Track blocked directions for shadow cones
	var shadow_blocked: Dictionary = {}  # angle -> distance where blocked
	
	# DEBUG: Zähle Shadow-Blockierungen
	var debug_shadow_blocks = 0
	var debug_wall_angle = 0.0
	var debug_wall_distance = 0.0
	
	# WICHTIG: Sortiere Tiles nach Distanz (nah → fern)
	# So werden nahe Wände zuerst verarbeitet!
	var tiles_to_check: Array = []
	
	for x in range(soldier_pos.x - MAX_SIGHT_RANGE, soldier_pos.x + MAX_SIGHT_RANGE + 1):
		for y in range(soldier_pos.y - MAX_SIGHT_RANGE, soldier_pos.y + MAX_SIGHT_RANGE + 1):
			var target_pos = Vector2i(x, y)
			
			if not grid_manager.is_within_bounds(target_pos):
				continue
			
			var distance = soldier_pos.distance_to(target_pos)
			if distance > MAX_SIGHT_RANGE:
				continue
			
			tiles_to_check.append({"pos": target_pos, "dist": distance})
	
	# Sortiere nach Distanz (nah zuerst)
	tiles_to_check.sort_custom(func(a, b): return a.dist < b.dist)
	
	# Jetzt verarbeite alle Tiles in richtiger Reihenfolge
	for tile_data in tiles_to_check:
		var target_pos = tile_data.pos
		var distance = tile_data.dist
		
		if target_pos == soldier_pos:
			fov_grid[target_pos] = VisibilityLevel.CLEAR
			continue
		
		if not _is_in_fov_cone(soldier_pos, target_pos, facing_angle, fov_angle):
			fov_grid[target_pos] = VisibilityLevel.BLOCKED
			continue
		
		# Calculate angle to this tile
		var angle_to_tile = _calculate_angle_to_target(soldier_pos, target_pos)
		
		# SCHRITT 1: Ist es im Schatten einer Wand, die wir SCHON gefunden haben?
		if _is_in_shadow(target_pos, soldier_pos, angle_to_tile, distance, shadow_blocked):
			fov_grid[target_pos] = VisibilityLevel.BLOCKED
			debug_shadow_blocks += 1
			continue
		
		# SCHRITT 2: Wenn nicht im Schatten, prüfe LoS (Sichtlinie)
		var visibility = _check_line_of_sight(soldier_pos, target_pos, soldier_eye_height, grid_manager)
		
		
		# --- (V14 LOGIK - Nur echtes Cover wirft Schatten) ---
		
		# SCHRITT 3: Prüfe, ob DIESES TILE (target_pos) SELBST Cover ist.
		var is_actual_cover = grid_manager.get_cover_at(target_pos) != null
		
		# Wenn es echtes Cover IST (z.B. (10,10)) UND die LoS es blockiert:
		if is_actual_cover and visibility == VisibilityLevel.BLOCKED:
			# Füge es zur Schattenkarte hinzu, damit es zukünftige Tiles blockiert.
			_add_to_shadow_map(shadow_blocked, angle_to_tile, distance)
			
			# (Nur Debug-Code für die Wand selbst)
			if target_pos == Vector2i(10, 10):
				debug_wall_angle = angle_to_tile
				debug_wall_distance = distance
		
		# WICHTIG: Setze die Sichtbarkeit für das Tile.
		# (Tiles wie (10,11) werden als BLOCKED markiert, aber NICHT zur shadow_map hinzugefügt)
		fov_grid[target_pos] = visibility
		
		# --- ENDE V14 LOGIK ---
		
		
		# DEBUG: Log Wand-Prüfung
		if target_pos == Vector2i(10, 10):
			print(">>> WALL CHECK (10,10) <<<")
			print("  Position: ", soldier_pos)
			print("  Angle: ", angle_to_tile, "°")
			print("  Distance: ", distance)
			print("  LoS Result: ", "BLOCKED" if visibility == VisibilityLevel.BLOCKED else "CLEAR")
			print(">>> END WALL CHECK <<<")
	
	# DEBUG OUTPUT
	# (Wir fügen (3,3) und (4,4) zur Debug-Liste hinzu)
	if soldier_pos == Vector2i(3, 3) or soldier_pos == Vector2i(4, 4) or soldier_pos == Vector2i(5, 5) or soldier_pos == Vector2i(6, 6) or soldier_pos == Vector2i(7, 7) or soldier_pos == Vector2i(8, 8):
		print("\n=== FOV DEBUG ===")
		print("Position: ", soldier_pos)
		print("Wall (10,10) angle: ", debug_wall_angle, "° distance: ", debug_wall_distance)
		print("Shadow blocked tiles: ", debug_shadow_blocks)
		print("Shadow map entries: ", shadow_blocked.size())
		print("=================\n")
	
	return fov_grid

static func _calculate_angle_to_target(from: Vector2i, to: Vector2i) -> float:
	var dx = float(to.x - from.x)
	var dy = float(to.y - from.y)
	var angle_rad = atan2(dx, -dy)
	var angle_deg = fmod(rad_to_deg(angle_rad) + 360.0, 360.0)
	return angle_deg

static func _is_in_shadow(target_pos: Vector2i, soldier_pos: Vector2i, angle: float, distance: float, shadow_map: Dictionary) -> bool:
	# Check if this angle has a shadow
	for shadow_angle in shadow_map:
		var angle_diff = abs(angle - shadow_angle)
		if angle_diff > 180.0:
			angle_diff = 360.0 - angle_diff
		
		var wall_distance = shadow_map[shadow_angle]
		
		
		# --- ÄNDERUNG HIER (V19) ---
		# Deckel die Distanz bei 8.0, damit der Schatten nicht zu schmal wird.
		var effective_distance = min(wall_distance, 8.0)
		
		# Benutze effective_distance in der Formel (Basis V17)
		var shadow_cone_width = 10.0 - (effective_distance * 0.8)
		shadow_cone_width = max(shadow_cone_width, 2.0)  # Mindestens 2° breit
		shadow_cone_width += 1.0 # Der Puffer von V17 bleibt
		# --- ENDE ÄNDERUNG ---
		

		# Shadow nur wenn:
		# 1. Im Schatten-Winkel (dynamische Breite)
		# 2. Weiter weg als die Wand
		# 3. UND Wand ist mindestens 3 Tiles entfernt
		if angle_diff < shadow_cone_width and distance > wall_distance and wall_distance >= 3.0:
			return true
	
	return false

static func _add_to_shadow_map(shadow_map: Dictionary, angle: float, distance: float) -> void:
	# KEIN Runden mehr! Speichere exakten Winkel
	if not shadow_map.has(angle):
		shadow_map[angle] = distance
	elif distance < shadow_map[angle]:
		shadow_map[angle] = distance

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
	
	var highest_cover_height = 0.0
	var closest_cover_distance = 999.0
	var cover_found = false
	
	# WICHTIG: Prüfe auch das ZIEL selbst! (size() - 1 inkludiert letztes Element)
	for i in range(1, line.size()):
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
	
	var total_distance = from.distance_to(to)
	var distance_beyond_cover = total_distance - closest_cover_distance
	
	# BINÄRES SYSTEM: Nur CLEAR oder BLOCKED
	
	# REGEL 1: Sehr nah am Cover (1-2 Tiles)
	if closest_cover_distance <= 2.0:
		if highest_cover_height >= eye_height * 0.7:
			return VisibilityLevel.BLOCKED
		else:
			return VisibilityLevel.CLEAR
	
	# REGEL 2: Mittlere Distanz zum Cover (3-5 Tiles)
	elif closest_cover_distance <= 5.0:
		if distance_beyond_cover <= 3.0:
			if highest_cover_height >= 1.5:
				return VisibilityLevel.BLOCKED
			else:
				return VisibilityLevel.CLEAR
		else:
			if highest_cover_height >= 2.5:
				return VisibilityLevel.BLOCKED
			else:
				return VisibilityLevel.CLEAR
	
	# REGEL 3: Weit weg vom Cover (6+ Tiles)
	else:
		if distance_beyond_cover <= 2.0:
			if highest_cover_height >= 2.0:
				return VisibilityLevel.BLOCKED
			else:
				return VisibilityLevel.CLEAR
		else:
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

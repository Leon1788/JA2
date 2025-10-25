extends Node
class_name FOVGridSystem

enum VisibilityLevel {
	BLOCKED = 0,
	PARTIAL = 1, # Obwohl nicht genutzt, lassen wir es vorerst drin
	CLEAR = 2
}

const MAX_SIGHT_RANGE: int = 15

# ===== ALTE 2D-FUNKTIONEN (MIT 3D COVER FIX) =====

static func calculate_fov_grid(soldier: Merc, grid_manager: GridManager) -> Dictionary:
	var fov_grid: Dictionary = {}
	var soldier_pos = soldier.movement_component.current_grid_pos
	var soldier_floor = soldier.movement_component.current_floor  # Nutze Floor!
	var soldier_eye_height = soldier.stance_system.get_eye_height()
	var facing_angle = soldier.facing_system.get_facing_angle()
	var fov_angle = soldier.facing_system.fov_angle

	var shadow_blocked: Dictionary = {}
	var debug_shadow_blocks = 0
	var debug_wall_angle = 0.0
	var debug_wall_distance = 0.0

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

	tiles_to_check.sort_custom(func(a, b): return a.dist < b.dist)

	for tile_data in tiles_to_check:
		var target_pos = tile_data.pos
		var distance = tile_data.dist

		if target_pos == soldier_pos:
			fov_grid[target_pos] = VisibilityLevel.CLEAR
			continue

		if not _is_in_fov_cone(soldier_pos, target_pos, facing_angle, fov_angle):
			fov_grid[target_pos] = VisibilityLevel.BLOCKED
			continue

		var angle_to_tile = _calculate_angle_to_target(soldier_pos, target_pos)

		if _is_in_shadow(target_pos, soldier_pos, angle_to_tile, distance, shadow_blocked):
			fov_grid[target_pos] = VisibilityLevel.BLOCKED
			debug_shadow_blocks += 1
			continue

		var visibility = _check_line_of_sight_3d_wrapper(soldier_pos, target_pos, soldier_eye_height, soldier_floor, grid_manager)

		# --- (V14 LOGIK - Nur echtes Cover wirft Schatten) ---
		# WICHTIG: FloorObject (Böden) sollen KEINE Schatten werfen auf gleichem Floor!
		var cover_at_pos = grid_manager.get_cover_at_3d(target_pos, soldier_floor)
		var is_actual_cover = cover_at_pos != null and not cover_at_pos is FloorObject
		
		if is_actual_cover and visibility == VisibilityLevel.BLOCKED:
			_add_to_shadow_map(shadow_blocked, angle_to_tile, distance)
			# Prüfe auf die spezifischen Cover-Positionen für Debugging
			if target_pos == Vector2i(10, 10) or target_pos == Vector2i(31, 10):
				debug_wall_angle = angle_to_tile
				debug_wall_distance = distance
		fov_grid[target_pos] = visibility
		# --- ENDE V14 LOGIK ---

		# DEBUG: Log Wand-Prüfung (nur für die 10,10 Kachel, anpassbar)
		if target_pos == Vector2i(10, 10) or target_pos == Vector2i(31, 10): # Prüft beide Cover Positionen
			var cover_obj = grid_manager.get_cover_at_3d(target_pos, soldier_floor)
			var cover_name = cover_obj.cover_data.cover_name if cover_obj and cover_obj.cover_data else "Unknown Cover"
			print(">>> COVER CHECK ((%s)) <<<" % target_pos) # Extra Klammern zur Identifizierung
			print("  Cover Type: ", cover_name)
			print("  Position: ", soldier_pos)
			print("  Angle: ", angle_to_tile, "°")
			print("  Distance: ", distance)
			print("  LoS Result: ", "BLOCKED" if visibility == VisibilityLevel.BLOCKED else "CLEAR")
			print(">>> END COVER CHECK <<<")

	# DEBUG OUTPUT (nur für die speziellen Diagonalpositionen)
	if soldier_pos == Vector2i(3, 3) or soldier_pos == Vector2i(4, 4) or soldier_pos == Vector2i(5, 5) or soldier_pos == Vector2i(6, 6) or soldier_pos == Vector2i(7, 7) or soldier_pos == Vector2i(8, 8):
		print("\n=== FOV DEBUG ===")
		print("Position: ", soldier_pos)
		# Angepasst, um die Distanz zur korrekten Wand anzuzeigen (falls sie blockiert)
		print("Cover (10,10) angle: ", debug_wall_angle if debug_wall_distance > 0 else "N/A", "° distance: ", debug_wall_distance if debug_wall_distance > 0 else "N/A")
		print("Shadow blocked tiles: ", debug_shadow_blocks)
		print("Shadow map entries: ", shadow_blocked.size())
		print("=================\n")

	return fov_grid

static func _check_line_of_sight_3d_wrapper(from: Vector2i, to: Vector2i, eye_height: float, floor: int, grid_manager: GridManager) -> int:
	"""Wrapper für _check_line_of_sight mit 3D Cover Support"""
	return _check_line_of_sight(from, to, eye_height, floor, grid_manager)

# ===== NEUE 3D-FUNKTIONEN =====

static func calculate_fov_grid_3d(soldier: Merc, grid_manager: GridManager, target_floor: int) -> Dictionary:
	"""
	Berechnet FOV-Grid für eine bestimmte Etage mit vollem Shadow-Casting
	Funktioniert FLEXIBEL mit beliebig vielen Floors!
	
	WICHTIG: FOV Grid simuliert "als ob Player auf target_floor steht"!
	Rays für LineOfSight nutzen ECHTE Position (current_floor)!
	"""
	print("[FOV-3D] === calculate_fov_grid_3d CALLED ===")
	print("[FOV-3D]   Soldier Physical Floor: %d" % soldier.movement_component.current_floor)
	print("[FOV-3D]   Target Floor (for FOV Grid): %d" % target_floor)
	
	var fov_grid: Dictionary = {}
	var soldier_pos = soldier.movement_component.current_grid_pos
	
	# WICHTIG: Für FOV Grid nutze target_floor als "soldier_floor"!
	# Das simuliert "als ob Player auf diesem Floor steht"
	var soldier_floor = target_floor  # ✅ NICHT current_floor!
	
	var soldier_eye_height = soldier.stance_system.get_eye_height()
	var facing_angle = soldier.facing_system.get_facing_angle()
	var fov_angle = soldier.facing_system.fov_angle

	var shadow_blocked: Dictionary = {}
	var debug_shadow_blocks = 0

	var tiles_to_check: Array = []

	# Sammele alle Tiles auf dieser Etage innerhalb des Sichtradius
	for x in range(soldier_pos.x - MAX_SIGHT_RANGE, soldier_pos.x + MAX_SIGHT_RANGE + 1):
		for y in range(soldier_pos.y - MAX_SIGHT_RANGE, soldier_pos.y + MAX_SIGHT_RANGE + 1):
			var target_pos = Vector2i(x, y)

			if not grid_manager.is_within_bounds(target_pos):
				continue

			var distance = soldier_pos.distance_to(target_pos)
			if distance > MAX_SIGHT_RANGE:
				continue

			tiles_to_check.append({"pos": target_pos, "dist": distance})

	# Sortiere nach Distanz (näher = zuerst)
	tiles_to_check.sort_custom(func(a, b): return a.dist < b.dist)

	print("[FOV-3D] Floor %d: checking %d tiles" % [target_floor, tiles_to_check.size()])

	for tile_data in tiles_to_check:
		var target_pos = tile_data.pos
		var distance = tile_data.dist

		if target_pos == soldier_pos:
			fov_grid[target_pos] = VisibilityLevel.CLEAR
			continue

		# Prüfe ob im FOV-Kegel (120°)
		if not _is_in_fov_cone(soldier_pos, target_pos, facing_angle, fov_angle):
			fov_grid[target_pos] = VisibilityLevel.BLOCKED
			continue

		var angle_to_tile = _calculate_angle_to_target(soldier_pos, target_pos)

		# Prüfe ob im Shadow (von Cover blockiert)
		if _is_in_shadow(target_pos, soldier_pos, angle_to_tile, distance, shadow_blocked):
			fov_grid[target_pos] = VisibilityLevel.BLOCKED
			debug_shadow_blocks += 1
			continue

		# Prüfe Line-of-Sight (mit 3D-Höhen wenn andere Etage!)
		var visibility: int
		if target_floor == soldier_floor:
			# Gleiche Etage: normale 2D LoS mit 3D Cover!
			visibility = _check_line_of_sight(soldier_pos, target_pos, soldier_eye_height, soldier_floor, grid_manager)
		else:
			# Andere Etage: 3D LoS mit Höhen-Check - FLEXIBEL FÜR BELIEBIG VIELE FLOORS
			visibility = _check_line_of_sight_3d(soldier_pos, target_pos, soldier_eye_height, soldier_floor, target_floor, grid_manager)

		# Nur echtes Cover wirft Schatten - WICHTIG: Prüfe auf target_floor, nicht soldier_floor!
		# WICHTIG: FloorObject (Böden) sollen KEINE Schatten werfen!
		var cover_at_pos = grid_manager.get_cover_at_3d(target_pos, target_floor)
		var is_actual_cover = cover_at_pos != null and not cover_at_pos is FloorObject
		
		# DEBUG
		if is_actual_cover:
			print("[FOV-3D] Cover found at %s on Floor %d (soldier on Floor %d)" % [target_pos, target_floor, soldier_floor])
		
		if is_actual_cover and visibility == VisibilityLevel.BLOCKED:
			_add_to_shadow_map(shadow_blocked, angle_to_tile, distance)

		fov_grid[target_pos] = visibility

	print("[FOV-3D] Floor %d: %d visible tiles" % [target_floor, fov_grid.size()])

	return fov_grid

static func _check_line_of_sight_3d(from_pos: Vector2i, to_pos: Vector2i, eye_height: float, from_floor: int, to_floor: int, grid_manager: GridManager) -> int:
	"""
	Line-of-Sight Check mit 3D-Höhen für verschiedene Etagen
	ÄNDERUNG: Prüft Cover auf ALLEN Floors zwischen from_floor und to_floor!
	"""
	# Bresenham-Linie zwischen Positionen
	var line = _bresenham_line(from_pos, to_pos)
	
	# Linie zu kurz oder nur Start/Endpunkt -> immer sichtbar
	if line.size() <= 2:
		return VisibilityLevel.CLEAR
	
	var highest_cover_height = 0.0
	var closest_cover_distance = 999.0
	var cover_found = false
	
	# Prüfe alle Floors zwischen from und to
	var min_floor = min(from_floor, to_floor)
	var max_floor = max(from_floor, to_floor)
	
	# Prüfe alle Zellen auf der Linie auf ALLEN Floors dazwischen
	for check_floor in range(min_floor, max_floor + 1):
		for i in range(1, line.size()):
			var cell = line[i]
			var cover = grid_manager.get_cover_at_3d(cell, check_floor)
			
			if cover:
				# Cover kann CoverObject ODER FloorObject sein - beide haben cover_data!
				if not cover.get("cover_data"):
					continue  # Kein cover_data? Überspringe
				
				# WICHTIG: Böden blockieren NUR zwischen verschiedenen Floors!
				# FloorObject vom EIGENEN Floor (from_floor) ignorieren!
				# Nur FloorObject von ANDEREN Floors blockieren
				if cover is FloorObject and check_floor == from_floor:
					continue  # Eigener Floor blockiert nicht!
				
				# WICHTIG: Low Cover (<2.0m) wie Fenster ignorieren bei Multi-Floor!
				# Von anderem Floor kann man über/unter Low Cover schauen
				var cover_height = cover.cover_data.cover_height
				if cover_height < 2.0:
					continue  # Low Cover ignorieren bei Multi-Floor!
				
				cover_found = true
				var distance_to_cover = from_pos.distance_to(cell)
				
				# Merke dir die höchste Deckung
				if cover_height > highest_cover_height:
					highest_cover_height = cover_height
					closest_cover_distance = distance_to_cover
				elif cover_height == highest_cover_height and distance_to_cover < closest_cover_distance:
					closest_cover_distance = distance_to_cover
	
	# Keine Deckung gefunden -> freie Sicht
	if not cover_found:
		return VisibilityLevel.CLEAR
	
	# Bei Multi-Floor: Nur HIGH Cover (>= 2.0m) blockiert
	# Low Cover (Fenster 0.8m) blockiert NICHT wenn Player von anderem Floor schaut!
	# (Realistische Rays werden in LineOfSightSystem berechnet)
	if highest_cover_height >= 2.0:
		return VisibilityLevel.BLOCKED
	
	# Low Cover blockiert nicht bei Multi-Floor
	return VisibilityLevel.CLEAR

# ===== HELPER FUNKTIONEN (UNVERÄNDERT) =====

static func _calculate_angle_to_target(from: Vector2i, to: Vector2i) -> float:
	var dx = float(to.x - from.x)
	var dy = float(to.y - from.y) # dy ist negativ, wenn 'to' weiter oben (kleinere Y-Koordinate) ist
	# atan2(y, x) -> atan2(dx, -dy) um 0 Grad nach Norden auszurichten
	var angle_rad = atan2(dx, -dy)
	# Konvertiere in Grad und normalisiere auf 0-360
	var angle_deg = fmod(rad_to_deg(angle_rad) + 360.0, 360.0)
	return angle_deg

static func _is_in_shadow(target_pos: Vector2i, soldier_pos: Vector2i, angle: float, distance: float, shadow_map: Dictionary) -> bool:
	for shadow_angle in shadow_map:
		# Berechne die kürzeste Winkeldifferenz (zwischen 0 und 180)
		var angle_diff = abs(angle - shadow_angle)
		if angle_diff > 180.0:
			angle_diff = 360.0 - angle_diff

		var wall_distance = shadow_map[shadow_angle]

		# --- (V19 LOGIK mit Distanz-Deckelung) ---
		var effective_distance = min(wall_distance, 8.0)
		var shadow_cone_width = 10.0 - (effective_distance * 0.8)
		shadow_cone_width = max(shadow_cone_width, 2.0)
		shadow_cone_width += 1.0 # Puffer
		# --- ENDE V19 LOGIK ---

		# Shadow nur wenn: Winkel passt, Ziel weiter weg als Wand, Wand nicht zu nah
		# Mindestdistanz wieder auf 2.5 gesetzt für Diagonalen
		if angle_diff < shadow_cone_width and distance > wall_distance and wall_distance >= 2.5:
			return true

	return false

static func _add_to_shadow_map(shadow_map: Dictionary, angle: float, distance: float) -> void:
	# Speichere nur die *nächste* Blockierung für einen Winkel
	if not shadow_map.has(angle) or distance < shadow_map[angle]:
		shadow_map[angle] = distance

static func _is_in_fov_cone(from: Vector2i, to: Vector2i, facing_angle: float, fov_angle: float) -> bool:
	if from == to:
		return true # Man sieht immer das eigene Feld

	var angle_to_target_deg = _calculate_angle_to_target(from, to)

	# Berechne die Differenz zur Blickrichtung
	var angle_diff = angle_to_target_deg - facing_angle

	# Normalisiere die Differenz auf -180 bis +180 Grad
	while angle_diff > 180.0:
		angle_diff -= 360.0
	while angle_diff < -180.0:
		angle_diff += 360.0

	# Ist die absolute Differenz kleiner/gleich dem halben FOV-Winkel?
	return abs(angle_diff) <= (fov_angle / 2.0)

static func _check_line_of_sight(from: Vector2i, to: Vector2i, eye_height: float, floor: int, grid_manager: GridManager) -> int:
	var line = _bresenham_line(from, to)

	# Linie zu kurz oder nur Start/Endpunkt -> immer sichtbar
	if line.size() <= 2:
		return VisibilityLevel.CLEAR

	var highest_cover_height = 0.0
	var closest_cover_distance = 999.0
	var cover_found = false

	# Prüfe alle Zellen auf der Linie, AUCH die Zielzelle 'to'
	for i in range(1, line.size()):
		var cell = line[i]
		var cover = grid_manager.get_cover_at_3d(cell, floor)  # 3D Version mit Floor!

		if cover:
			# Cover kann CoverObject ODER FloorObject sein - beide haben cover_data!
			if not cover.get("cover_data"):
				continue  # Kein cover_data? Überspringe
			
			# WICHTIG: Böden (FloorObject) blockieren NUR zwischen verschiedenen Floors!
			# Auf gleichem Floor: Ignoriere Floor-Cover (sonst blockiert sich alles selbst!)
			if cover is FloorObject:
				continue  # Floor-Cover auf gleichem Floor ignorieren!
			
			cover_found = true
			var distance_to_cover = from.distance_to(cell) # Euklidische Distanz
			var cover_height = cover.cover_data.cover_height

			# Merke dir die höchste Deckung, die am nächsten zum Startpunkt 'from' ist
			if cover_height > highest_cover_height:
				highest_cover_height = cover_height
				closest_cover_distance = distance_to_cover
			elif cover_height == highest_cover_height and distance_to_cover < closest_cover_distance:
				closest_cover_distance = distance_to_cover

	# Keine Deckung gefunden -> freie Sicht
	if not cover_found:
		return VisibilityLevel.CLEAR

	var total_distance = from.distance_to(to)
	# Wie weit ist das Ziel 'to' von der blockierenden Deckung entfernt?
	var distance_beyond_cover = total_distance - closest_cover_distance

	# BINÄRES SYSTEM (CLEAR / BLOCKED) basierend auf Distanz zur Deckung

	# REGEL 1: Sehr nah an der Deckung (Distanz <= 2.0)
	if closest_cover_distance <= 2.0:
		# Multiplikator 0.9 (aus V20)
		if highest_cover_height >= eye_height * 0.9:
			return VisibilityLevel.BLOCKED
		else:
			return VisibilityLevel.CLEAR

	# REGEL 2: Mittlere Distanz zur Deckung (Distanz > 2.0 und <= 5.0)
	elif closest_cover_distance <= 5.0:
		# Ist das Ziel direkt HINTER der Deckung (<= 3.0 Einheiten dahinter)?
		if distance_beyond_cover <= 3.0:
			# --- (V25 LOGIK) ---
			# Blockiert, wenn Höhe >= 1.5 ODER Höhe >= eye_height * 1.8 ODER (NEU) Prone-Regel
			if highest_cover_height >= 1.5 or highest_cover_height >= eye_height * 1.8 or (highest_cover_height >= eye_height * 0.9):
				return VisibilityLevel.BLOCKED
			else:
				return VisibilityLevel.CLEAR
		# Ist das Ziel weiter weg (> 3.0 Einheiten hinter der Deckung)?
		else:
			# Blockiert erst bei hoher Deckung (>= 2.5m)
			if highest_cover_height >= 2.5:
				return VisibilityLevel.BLOCKED
			else:
				return VisibilityLevel.CLEAR

	# REGEL 3: Weit weg von der Deckung (Distanz > 5.0)
	else:
		# --- (V24b LOGIK) ---
		# Fall 3a: Direkt hinter der weit entfernten Deckung (<= 2.0 Einheiten dahinter)
		if distance_beyond_cover <= 2.0:
			# Blockiere bei >= 2.0m Höhe ODER wenn Deckung höher als Augenhöhe
			if highest_cover_height >= 2.0 or highest_cover_height >= eye_height:
				return VisibilityLevel.BLOCKED
			else:
				return VisibilityLevel.CLEAR
		# Fall 3b: Weiter weg hinter der weit entfernten Deckung (> 2.0 Einheiten dahinter)
		else:
			# Blockiere nur bei sehr hoher Deckung (>= 2.5m)
			if highest_cover_height >= 2.5:
				return VisibilityLevel.BLOCKED
			else:
				return VisibilityLevel.CLEAR
		# --- ENDE V24b LOGIK ---

# Bresenham-Algorithmus zur Rasterisierung einer Linie zwischen zwei Punkten
static func _bresenham_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx = abs(to.x - from.x)
	var dy = -abs(to.y - from.y) # Multipliziere dy mit -1 für Bresenham
	var x = from.x
	var y = from.y
	var x_inc = 1 if to.x > from.x else -1
	var y_inc = 1 if to.y > from.y else -1
	var error = dx + dy # Fehlerterm initialisieren

	while true:
		points.append(Vector2i(x, y))

		if x == to.x and y == to.y: # Ziel erreicht
			break

		var e2 = 2 * error
		if e2 >= dy: # Fehler >= dy -> Schritt in x-Richtung
			if x == to.x: break # Verhindere Überschreiten bei vertikalen Linien
			error += dy
			x += x_inc
		if e2 <= dx: # Fehler <= dx -> Schritt in y-Richtung
			if y == to.y: break # Verhindere Überschreiten bei horizontalen Linien
			error += dx
			y += y_inc

	return points

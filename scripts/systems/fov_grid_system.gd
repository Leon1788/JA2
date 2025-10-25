extends Node
class_name FOVGridSystem

enum VisibilityLevel {
	BLOCKED = 0,
	CLEAR = 2
}

const MAX_SIGHT_RANGE: int = 15

# ===== VEREINFACHTE 3D-FOV-BERECHNUNG =====

static func calculate_fov_grid_3d(soldier: Merc, grid_manager: GridManager, target_floor: int) -> Dictionary:
	"""
	Berechnet FOV-Grid für eine bestimmte Etage
	VEREINFACHT: Cone ist IMMER TRANSPARENT
	Nur geometrische Sichtlinie (120° Cone), keine Shadow-Casting-Logik
	"""
	var fov_grid: Dictionary = {}
	var soldier_pos = soldier.movement_component.current_grid_pos
	var soldier_eye_height = soldier.stance_system.get_eye_height()
	var facing_angle = soldier.facing_system.get_facing_angle()
	var fov_angle = soldier.facing_system.fov_angle

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

	# Sortiere nach Distanz
	tiles_to_check.sort_custom(func(a, b): return a.dist < b.dist)

	for tile_data in tiles_to_check:
		var target_pos = tile_data.pos

		if target_pos == soldier_pos:
			fov_grid[target_pos] = VisibilityLevel.CLEAR
			continue

		# CONE CHECK: Ist Position im 120° Sichtwinkel?
		if not _is_in_fov_cone(soldier_pos, target_pos, facing_angle, fov_angle):
			fov_grid[target_pos] = VisibilityLevel.BLOCKED
			continue

		# CONE IMMER TRANSPARENT - Tile ist sichtbar für die FOV-Grid!
		# Raycast entscheidet später in LineOfSightSystem über echte Blockierungen
		fov_grid[target_pos] = VisibilityLevel.CLEAR

	return fov_grid

# ===== ALTE 2D-FOV (KOMPATIBILITÄT) =====

static func calculate_fov_grid(soldier: Merc, grid_manager: GridManager) -> Dictionary:
	"""Alte 2D-Version für Rückwärtskompatibilität"""
	var fov_grid: Dictionary = {}
	var soldier_pos = soldier.movement_component.current_grid_pos
	var soldier_eye_height = soldier.stance_system.get_eye_height()
	var facing_angle = soldier.facing_system.get_facing_angle()
	var fov_angle = soldier.facing_system.fov_angle

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

		if target_pos == soldier_pos:
			fov_grid[target_pos] = VisibilityLevel.CLEAR
			continue

		if not _is_in_fov_cone(soldier_pos, target_pos, facing_angle, fov_angle):
			fov_grid[target_pos] = VisibilityLevel.BLOCKED
			continue

		fov_grid[target_pos] = VisibilityLevel.CLEAR

	return fov_grid

# ===== HELPER FUNKTIONEN =====

static func _is_in_fov_cone(from: Vector2i, to: Vector2i, facing_angle: float, fov_angle: float) -> bool:
	if from == to:
		return true

	var angle_to_target_deg = _calculate_angle_to_target(from, to)
	var angle_diff = angle_to_target_deg - facing_angle

	while angle_diff > 180.0:
		angle_diff -= 360.0
	while angle_diff < -180.0:
		angle_diff += 360.0

	return abs(angle_diff) <= (fov_angle / 2.0)

static func _calculate_angle_to_target(from: Vector2i, to: Vector2i) -> float:
	var dx = float(to.x - from.x)
	var dy = float(to.y - from.y)
	var angle_rad = atan2(dx, -dy)
	var angle_deg = fmod(rad_to_deg(angle_rad) + 360.0, 360.0)
	return angle_deg

extends Node
class_name GridManager

const TILE_SIZE: float = 1.0
const FLOOR_HEIGHT: float = 3.0  # NEU: Höhe einer Etage

# ===== ALTE 2D-SYSTEME (UNVERÄNDERT) =====
var grid_data: Dictionary = {}  # Vector2i -> Occupant
var cover_data: Dictionary = {}  # Vector2i -> CoverObject

var grid_min: Vector2i = Vector2i(0, 0)
var grid_max: Vector2i = Vector2i(10, 10)

# ===== NEUE 3D-SYSTEME =====
var max_floors: int = 1  # Anzahl Etagen (flexibel pro Map)
var floor_data: Dictionary = {}  # floor (int) -> Dictionary(Vector2i -> Occupant)
var floor_cover_data: Dictionary = {}  # floor (int) -> Dictionary(Vector2i -> CoverObject)

# ===== NEUE HELPER FUNKTIONEN FÜR FLEXIBLE FLOOR-VALIDIERUNG =====
func set_max_floors(count: int) -> void:
	"""Setzt die Anzahl der Etagen mit Validierung"""
	if count < 1:
		push_error("[GridManager] max_floors muss >= 1 sein! Setze auf 1.")
		count = 1
	
	max_floors = count
	
	# Initialisiere floor_data und floor_cover_data für alle Etagen
	for floor in range(max_floors):
		if not floor_data.has(floor):
			floor_data[floor] = {}
		if not floor_cover_data.has(floor):
			floor_cover_data[floor] = {}
	
	print("[GridManager] max_floors set to ", max_floors)

func is_valid_floor(floor: int) -> bool:
	"""Prüft ob eine Etage im gültigen Bereich ist"""
	return floor >= 0 and floor < max_floors

func clamp_floor(floor: int) -> int:
	"""Klemmt eine Etage auf den gültigen Bereich"""
	return clamp(floor, 0, max_floors - 1)

# ===== ALTE FUNKTIONEN (UNVERÄNDERT) =====

func set_grid_bounds(min_pos: Vector2i, max_pos: Vector2i) -> void:
	grid_min = min_pos
	grid_max = max_pos

func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / TILE_SIZE)),
		int(floor(world_pos.z / TILE_SIZE))
	)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		grid_pos.x * TILE_SIZE + TILE_SIZE * 0.5,
		0.0,
		grid_pos.y * TILE_SIZE + TILE_SIZE * 0.5
	)

func is_within_bounds(grid_pos: Vector2i) -> bool:
	return (grid_pos.x >= grid_min.x and grid_pos.x < grid_max.x and
			grid_pos.y >= grid_min.y and grid_pos.y < grid_max.y)

func is_tile_walkable(grid_pos: Vector2i) -> bool:
	if not is_within_bounds(grid_pos):
		return false
	if cover_data.has(grid_pos):
		return false
	return not grid_data.has(grid_pos)

func occupy_tile(grid_pos: Vector2i, occupant: Node) -> void:
	grid_data[grid_pos] = occupant

func free_tile(grid_pos: Vector2i) -> void:
	grid_data.erase(grid_pos)

func place_cover(grid_pos: Vector2i, cover: CoverObject) -> void:
	cover_data[grid_pos] = cover
	print("Cover placed at ", grid_pos)

func remove_cover(grid_pos: Vector2i) -> void:
	cover_data.erase(grid_pos)

func get_cover_at(grid_pos: Vector2i) -> CoverObject:
	if cover_data.has(grid_pos):
		return cover_data[grid_pos]
	return null

func has_cover_between(from: Vector2i, to: Vector2i) -> bool:
	var line = _get_line_positions(from, to)
	for pos in line:
		if cover_data.has(pos):
			return true
	return false

func get_cover_between(from: Vector2i, to: Vector2i) -> CoverObject:
	var line = _get_line_positions(from, to)
	for pos in line:
		if cover_data.has(pos):
			return cover_data[pos]
	return null

func _get_line_positions(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var x = from.x
	var y = from.y
	var x_inc = 1 if to.x > from.x else -1
	var y_inc = 1 if to.y > from.y else -1
	var error = dx - dy
	
	dx *= 2
	dy *= 2
	
	while x != to.x or y != to.y:
		positions.append(Vector2i(x, y))
		
		if error > 0:
			x += x_inc
			error -= dy
		else:
			y += y_inc
			error += dx
	
	return positions

func get_neighbors(grid_pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	
	for dir in directions:
		var neighbor = grid_pos + dir
		if is_tile_walkable(neighbor):
			neighbors.append(neighbor)
	
	return neighbors

# ===== NEUE 3D-FUNKTIONEN =====

func set_grid_bounds_3d(min_pos: Vector2i, max_pos: Vector2i, floors: int) -> void:
	grid_min = min_pos
	grid_max = max_pos
	set_max_floors(floors)
	print("[GridManager] 3D Grid: ", max_pos, " with ", max_floors, " floors")

func world_to_grid_3d(world_pos: Vector3) -> Dictionary:
	var floor = int(floor(world_pos.y / FLOOR_HEIGHT))
	floor = clamp_floor(floor)
	
	return {
		"pos": Vector2i(
			int(floor(world_pos.x / TILE_SIZE)),
			int(floor(world_pos.z / TILE_SIZE))
		),
		"floor": floor
	}

func grid_to_world_3d(grid_pos: Vector2i, floor: int) -> Vector3:
	if not is_valid_floor(floor):
		push_warning("[GridManager] Invalid floor ", floor, " (max: ", max_floors - 1, ") - clamping")
		floor = clamp_floor(floor)
	
	return Vector3(
		grid_pos.x * TILE_SIZE + TILE_SIZE * 0.5,
		floor * FLOOR_HEIGHT,
		grid_pos.y * TILE_SIZE + TILE_SIZE * 0.5
	)

func is_tile_walkable_3d(grid_pos: Vector2i, floor: int) -> bool:
	if not is_within_bounds(grid_pos):
		return false
	if not is_valid_floor(floor):
		return false
	
	# Prüfe floor_cover_data
	if floor_cover_data.has(floor) and floor_cover_data[floor].has(grid_pos):
		return false
	
	# Prüfe floor_data
	if floor_data.has(floor) and floor_data[floor].has(grid_pos):
		return false
	
	return true

func occupy_tile_3d(grid_pos: Vector2i, floor: int, occupant: Node) -> void:
	if not is_valid_floor(floor):
		push_error("[GridManager] Cannot occupy tile on invalid floor ", floor)
		return
	
	if not floor_data.has(floor):
		floor_data[floor] = {}
	floor_data[floor][grid_pos] = occupant

func free_tile_3d(grid_pos: Vector2i, floor: int) -> void:
	if floor_data.has(floor) and floor_data[floor].has(grid_pos):
		floor_data[floor].erase(grid_pos)

func place_cover_3d(grid_pos: Vector2i, floor: int, cover: CoverObject) -> void:
	if not is_valid_floor(floor):
		push_error("[GridManager] Cannot place cover on invalid floor ", floor)
		return
	
	if not floor_cover_data.has(floor):
		floor_cover_data[floor] = {}
	floor_cover_data[floor][grid_pos] = cover
	print("Cover placed at ", grid_pos, " floor ", floor)

func remove_cover_3d(grid_pos: Vector2i, floor: int) -> void:
	if floor_cover_data.has(floor) and floor_cover_data[floor].has(grid_pos):
		floor_cover_data[floor].erase(grid_pos)

func get_cover_at_3d(grid_pos: Vector2i, floor: int) -> CoverObject:
	if not is_valid_floor(floor):
		return null
	
	if floor_cover_data.has(floor) and floor_cover_data[floor].has(grid_pos):
		return floor_cover_data[floor][grid_pos]
	return null

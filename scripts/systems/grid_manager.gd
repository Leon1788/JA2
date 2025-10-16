extends Node
class_name GridManager

const TILE_SIZE: float = 1.0

# Grid-Daten: Position -> was ist dort (null = frei, Objekt = belegt)
var grid_data: Dictionary = {}
var cover_data: Dictionary = {}  # Position -> CoverObject

# Grid bounds
var grid_min: Vector2i = Vector2i(0, 0)
var grid_max: Vector2i = Vector2i(10, 10)

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
	# Tile mit Cover ist nicht begehbar
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
	# Simple check: ist Cover direkt in der Linie?
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
		Vector2i(1, 0),   # right
		Vector2i(-1, 0),  # left
		Vector2i(0, 1),   # down
		Vector2i(0, -1),  # up
	]
	
	for dir in directions:
		var neighbor = grid_pos + dir
		if is_tile_walkable(neighbor):
			neighbors.append(neighbor)
	
	return neighbors

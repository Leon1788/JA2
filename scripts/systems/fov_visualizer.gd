extends Node3D
class_name FOVVisualizer

var mesh_instance: MeshInstance3D
var is_visible: bool = false

func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

func update_fov_display(merc: Merc, grid_manager: GridManager) -> void:
	"""Visualisiert FOV des Players auf aktuellem Floor"""
	if not is_visible:
		mesh_instance.visible = false
		return
	
	for child in get_children():
		child.queue_free()
	
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	var immediate_mesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh
	
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	const BLOCKED = 0
	const PARTIAL = 1
	const CLEAR = 2
	
	# Nutze aktuellen Floor des Players
	var player_floor = merc.movement_component.current_floor
	var fov_to_display = merc.fov_grids.get(player_floor, {})
	
	for pos in fov_to_display:
		var visibility = fov_to_display[pos]
		var color: Color
		
		match visibility:
			BLOCKED:
				continue
			PARTIAL:
				color = Color(1.0, 1.0, 0.0, 0.4)
			CLEAR:
				color = Color(0.0, 1.0, 0.0, 0.4)
		
		_draw_tile(immediate_mesh, pos, color, grid_manager, player_floor)
	
	immediate_mesh.surface_end()
	mesh_instance.visible = true
	
	print("FOV Visualizer updated: ", fov_to_display.size(), " tiles on Floor ", player_floor)

func _draw_tile(mesh: ImmediateMesh, grid_pos: Vector2i, color: Color, grid_manager: GridManager, player_floor: int) -> void:
	"""Zeichnet ein einzelnes Tile als 2 Dreiecke"""
	var world_pos = grid_manager.grid_to_world(grid_pos)
	var tile_size = grid_manager.TILE_SIZE
	var height = player_floor * grid_manager.FLOOR_HEIGHT + 0.01
	
	var tl = Vector3(world_pos.x - tile_size * 0.5, height, world_pos.z - tile_size * 0.5)
	var tr = Vector3(world_pos.x + tile_size * 0.5, height, world_pos.z - tile_size * 0.5)
	var bl = Vector3(world_pos.x - tile_size * 0.5, height, world_pos.z + tile_size * 0.5)
	var br = Vector3(world_pos.x + tile_size * 0.5, height, world_pos.z + tile_size * 0.5)
	
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tl)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tr)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(bl)
	
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(tr)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(br)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(bl)

func toggle_visibility() -> void:
	is_visible = not is_visible
	mesh_instance.visible = is_visible
	print("FOV Visualizer: ", "ON" if is_visible else "OFF")

func set_visibility(visible: bool) -> void:
	is_visible = visible
	mesh_instance.visible = visible

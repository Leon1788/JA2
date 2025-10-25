extends Node3D
class_name VisualGrid

@export var grid_size: Vector2i = Vector2i(10, 10)
@export var tile_size: float = 1.0
@export var floor: int = 0
@export var grid_position: Vector2i = Vector2i(0, 0)
@export var floor_data: FloorData

var mesh_instance: MeshInstance3D
var floor_height: float = 3.0
var highlight_mesh: MeshInstance3D
var current_highlight_pos: Vector2i = Vector2i(-999, -999)
var highlight_ap_sufficient: bool = false

# NEU: Speichere FloorObject Referenz für GridManager
var floor_object: FloorObject = null

func _ready() -> void:
	if not floor_data:
		print("[VisualGrid] WARNING: floor_data is null! Skipping floor object creation.")
		return
	
	create_floor_object()
	create_grid_lines()
	create_highlight_mesh()

func create_floor_object() -> void:
	if not floor_data:
		print("[VisualGrid] WARNING: floor_data not set!")
		return
	
	floor_object = FloorObject.new()  # Speichere Referenz!
	floor_object.floor_data = floor_data
	floor_object.width = grid_size.x
	floor_object.length = grid_size.y
	
	var x_offset = grid_position.x * tile_size
	var z_offset = grid_position.y * tile_size
	var y_height = floor * floor_height - 0.02
	
	var center_x = x_offset + (grid_size.x * tile_size) * 0.5
	var center_z = z_offset + (grid_size.y * tile_size) * 0.5
	
	floor_object.position = Vector3(center_x, y_height, center_z)
	
	add_child(floor_object)
	
	print("[VisualGrid] Floor %d: FloorObject created - Size: %dx%d at (%.1f, %.2f, %.1f)" % [
		floor, grid_size.x, grid_size.y, center_x, y_height, center_z
	])

func create_grid_lines() -> void:
	if not floor_data:
		print("[VisualGrid] WARNING: floor_data is null in create_grid_lines!")
		return
	
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	var immediate_mesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.no_depth_test = false
	material.render_priority = 1
	mesh_instance.material_override = material
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var y_height = floor * floor_height + 0.0
	var x_offset = grid_position.x * tile_size
	var z_offset = grid_position.y * tile_size
	
	for x in range(grid_size.x + 1):
		var start = Vector3(x_offset + x * tile_size, y_height, z_offset)
		var end = Vector3(x_offset + x * tile_size, y_height, z_offset + grid_size.y * tile_size)
		immediate_mesh.surface_add_vertex(start)
		immediate_mesh.surface_add_vertex(end)
	
	for z in range(grid_size.y + 1):
		var start = Vector3(x_offset, y_height, z_offset + z * tile_size)
		var end = Vector3(x_offset + grid_size.x * tile_size, y_height, z_offset + z * tile_size)
		immediate_mesh.surface_add_vertex(start)
		immediate_mesh.surface_add_vertex(end)
	
	immediate_mesh.surface_end()
	
	print("[VisualGrid] Floor %d: Grid lines created at height %.1fm" % [floor, y_height])

func create_highlight_mesh() -> void:
	highlight_mesh = MeshInstance3D.new()
	add_child(highlight_mesh)
	
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 127
	highlight_mesh.material_override = material

func update_highlight(grid_pos: Vector2i, ap_sufficient: bool) -> void:
	current_highlight_pos = grid_pos
	highlight_ap_sufficient = ap_sufficient
	render_highlight()

func render_highlight() -> void:
	if current_highlight_pos.x == -999:
		highlight_mesh.mesh = null
		return
	
	var immediate_mesh = ImmediateMesh.new()
	highlight_mesh.mesh = immediate_mesh
	
	var color = Color(0.0, 1.0, 0.0, 0.6) if highlight_ap_sufficient else Color(1.0, 0.0, 0.0, 0.6)
	
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	highlight_mesh.material_override = material
	
	var y_height = floor * floor_height + 0.1
	var x_offset = grid_position.x * tile_size
	var z_offset = grid_position.y * tile_size
	
	var tile_world_x = x_offset + current_highlight_pos.x * tile_size
	var tile_world_z = z_offset + current_highlight_pos.y * tile_size
	
	var tl = Vector3(tile_world_x, y_height, tile_world_z)
	var tr = Vector3(tile_world_x + tile_size, y_height, tile_world_z)
	var bl = Vector3(tile_world_x, y_height, tile_world_z + tile_size)
	var br = Vector3(tile_world_x + tile_size, y_height, tile_world_z + tile_size)
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	immediate_mesh.surface_set_color(color)
	immediate_mesh.surface_add_vertex(tl)
	immediate_mesh.surface_set_color(color)
	immediate_mesh.surface_add_vertex(tr)
	immediate_mesh.surface_set_color(color)
	immediate_mesh.surface_add_vertex(bl)
	
	immediate_mesh.surface_set_color(color)
	immediate_mesh.surface_add_vertex(tr)
	immediate_mesh.surface_set_color(color)
	immediate_mesh.surface_add_vertex(br)
	immediate_mesh.surface_set_color(color)
	immediate_mesh.surface_add_vertex(bl)
	
	immediate_mesh.surface_end()

func clear_highlight() -> void:
	current_highlight_pos = Vector2i(-999, -999)
	highlight_mesh.mesh = null

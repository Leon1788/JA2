extends Node3D
class_name VisualGrid

@export var grid_size: Vector2i = Vector2i(10, 10)
@export var tile_size: float = 1.0
@export var floor: int = 0  # Etage (0-4)
@export var grid_position: Vector2i = Vector2i(0, 0)  # Grid-Position (Offset)

var mesh_instance: MeshInstance3D
var floor_height: float = 3.0

func _ready() -> void:
	create_grid_visual()

func create_grid_visual() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	var immediate_mesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh
	
	# Material für das Grid - hell und sichtbar
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 1.0, 0.0, 1.0)  # Grün
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mesh_instance.material_override = material
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Berechne Positionen
	var y_height = floor * floor_height + 0.05
	var x_offset = grid_position.x * tile_size
	var z_offset = grid_position.y * tile_size
	
	# Vertikale Linien (X-Richtung)
	for x in range(grid_size.x + 1):
		var start = Vector3(x_offset + x * tile_size, y_height, z_offset)
		var end = Vector3(x_offset + x * tile_size, y_height, z_offset + grid_size.y * tile_size)
		immediate_mesh.surface_add_vertex(start)
		immediate_mesh.surface_add_vertex(end)
	
	# Horizontale Linien (Z-Richtung)
	for z in range(grid_size.y + 1):
		var start = Vector3(x_offset, y_height, z_offset + z * tile_size)
		var end = Vector3(x_offset + grid_size.x * tile_size, y_height, z_offset + z * tile_size)
		immediate_mesh.surface_add_vertex(start)
		immediate_mesh.surface_add_vertex(end)
	
	immediate_mesh.surface_end()
	
	print("[VisualGrid] Floor %d: %dx%d Grid at (%d,%d) Height: %.1fm" % [
		floor, grid_size.x, grid_size.y, grid_position.x, grid_position.y, y_height
	])

extends Node3D
class_name VisualGrid

@export var grid_size: Vector2i = Vector2i(10, 10)
@export var tile_size: float = 1.0

var mesh_instance: MeshInstance3D

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
	
	# Vertikale Linien
	for x in range(grid_size.x + 1):
		var start = Vector3(x * tile_size, 0.05, 0)
		var end = Vector3(x * tile_size, 0.05, grid_size.y * tile_size)
		immediate_mesh.surface_add_vertex(start)
		immediate_mesh.surface_add_vertex(end)
	
	# Horizontale Linien
	for y in range(grid_size.y + 1):
		var start = Vector3(0, 0.05, y * tile_size)
		var end = Vector3(grid_size.x * tile_size, 0.05, y * tile_size)
		immediate_mesh.surface_add_vertex(start)
		immediate_mesh.surface_add_vertex(end)
	
	immediate_mesh.surface_end()
	
	print("Visual Grid created: ", grid_size.x, "x", grid_size.y)

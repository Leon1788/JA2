extends StaticBody3D
class_name FloorObject

@export var floor_data: FloorData
@export var width: int = 40
@export var length: int = 40

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	if floor_data:
		initialize()

func initialize() -> void:
	collision_layer = 1
	collision_mask = 0
	_create_mesh()
	_create_collision_shape()

func _create_mesh() -> void:
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(float(width), floor_data.floor_height, float(length))
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = floor_data.floor_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh_instance.material_override = material
	
	mesh_instance.position.y = -floor_data.floor_height * 0.5

func _create_collision_shape() -> void:
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		add_child(collision_shape)
	
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(float(width), floor_data.floor_height, float(length))
	collision_shape.shape = box_shape
	
	collision_shape.position.y = -floor_data.floor_height * 0.5
	
	print("[FloorObject] Shape Y: %.2f, Size: %.2fx%.2f" % [
		collision_shape.global_position.y,
		box_shape.size.x,
		box_shape.size.y
	])

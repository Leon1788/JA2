extends StaticBody3D
class_name FloorTile

@export var floor_data: FloorData

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	if floor_data:
		initialize()

func initialize() -> void:
	_create_mesh()
	_create_collision_shape()

func _create_mesh() -> void:
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	
	# Erstelle BoxMesh für Bodentile
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, floor_data.floor_height, 1.0)
	mesh_instance.mesh = box_mesh
	
	# Setze Material mit Farbe
	var material = StandardMaterial3D.new()
	material.albedo_color = floor_data.floor_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh_instance.material_override = material
	
	# Position anpassen (Mesh-Mitte bei halber Höhe)
	mesh_instance.position.y = floor_data.floor_height / 2.0
	
	print("[FloorTile] Mesh created - Color: ", floor_data.floor_color, " Height: ", floor_data.floor_height, "m")

func _create_collision_shape() -> void:
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		add_child(collision_shape)
	
	# Erstelle BoxShape3D für Collider
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, floor_data.floor_height, 1.0)
	collision_shape.shape = box_shape
	
	# Position anpassen (Shape-Mitte bei halber Höhe)
	collision_shape.position.y = floor_data.floor_height / 2.0
	
	print("[FloorTile] CollisionShape created - Height: ", floor_data.floor_height, "m")

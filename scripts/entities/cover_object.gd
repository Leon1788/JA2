extends StaticBody3D
class_name CoverObject

@export var cover_data: CoverData

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var grid_position: Vector2i = Vector2i(0, 0)
var current_health: int

func _ready() -> void:
	if cover_data:
		initialize()

func initialize() -> void:
	current_health = cover_data.health
	
	# Passe Mesh-Höhe an cover_height an
	_update_mesh_height()
	
	# Passe CollisionShape-Höhe an cover_height an
	_update_collision_shape_height()

func _update_mesh_height() -> void:
	if not mesh_instance or not mesh_instance.mesh:
		return
	
	var box_mesh = mesh_instance.mesh as BoxMesh
	if box_mesh:
		box_mesh.size.y = cover_data.cover_height
		# Position anpassen (Mesh-Mitte bei halber Höhe)
		mesh_instance.position.y = cover_data.cover_height / 2.0
		print("[Cover] ", cover_data.cover_name, " - Mesh height set to ", cover_data.cover_height, "m")

func _update_collision_shape_height() -> void:
	if not collision_shape or not collision_shape.shape:
		return
	
	var box_shape = collision_shape.shape as BoxShape3D
	if box_shape:
		box_shape.size.y = cover_data.cover_height
		# Position anpassen (Shape-Mitte bei halber Höhe)
		collision_shape.position.y = cover_data.cover_height / 2.0
		print("[Cover] ", cover_data.cover_name, " - CollisionShape height set to ", cover_data.cover_height, "m at Y=", collision_shape.position.y)

func get_cover_type() -> CoverData.CoverType:
	if not cover_data:
		return CoverData.CoverType.NONE
	return cover_data.cover_type

func get_hit_penalty() -> float:
	if not cover_data:
		return 0.0
	return cover_data.hit_chance_penalty

func take_damage(damage: int) -> void:
	if not cover_data.is_destructible:
		return
	
	current_health -= damage
	print(cover_data.cover_name, " took ", damage, " damage. HP: ", current_health)
	
	if current_health <= 0:
		destroy()

func destroy() -> void:
	print(cover_data.cover_name, " destroyed!")
	queue_free()

func is_destroyed() -> bool:
	return current_health <= 0

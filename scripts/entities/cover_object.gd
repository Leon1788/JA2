extends Node3D
class_name CoverObject

@export var cover_data: CoverData

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var grid_position: Vector2i = Vector2i(0, 0)
var current_health: int

func _ready() -> void:
	if cover_data:
		initialize()

func initialize() -> void:
	current_health = cover_data.health

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

extends Node
class_name VisualComponent

@export var player_material: Material
@export var enemy_material: Material
@export var dead_material: Material

var visual_root: Node3D
var model_mesh: MeshInstance3D
var weapon_attach_point: Node3D
var muzzle_flash_point: Node3D

func initialize(root: Node3D) -> void:
	visual_root = root.get_node_or_null("VisualRoot")
	if visual_root:
		model_mesh = visual_root.get_node_or_null("Model")
		weapon_attach_point = visual_root.get_node_or_null("WeaponAttachPoint")
		muzzle_flash_point = visual_root.get_node_or_null("MuzzleFlashPoint")

func set_team_color(is_player: bool) -> void:
	if not model_mesh:
		return
	
	var mat = player_material if is_player else enemy_material
	if mat:
		model_mesh.set_surface_override_material(0, mat)

func set_dead_visual() -> void:
	if not model_mesh:
		return
	
	if dead_material:
		model_mesh.set_surface_override_material(0, dead_material)

func play_muzzle_flash() -> void:
	# Placeholder - später Partikel-Effekt
	if muzzle_flash_point:
		print("MUZZLE FLASH at ", muzzle_flash_point.global_position)

func play_hit_effect(hit_position: Vector3, body_part: String) -> void:
	# Placeholder - später Blut/Treffer-Effekt
	print("HIT EFFECT at ", hit_position, " on ", body_part)

func set_visibility(visible: bool) -> void:
	if visual_root:
		visual_root.visible = visible
	else:
		# Fallback, falls nur das Modell gefunden wird (sollte aber nicht passieren)
		if model_mesh:
			model_mesh.visible = visible

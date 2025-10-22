extends Node3D
class_name Merc

@export var merc_data: MercData
@export var weapon_data: WeaponData
@export var is_player_unit: bool = true

@onready var health_component: HealthComponent = $HealthComponent
@onready var action_point_component: ActionPointComponent = $ActionPointComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var combat_component: CombatComponent = $CombatComponent
@onready var visual_component: VisualComponent = $VisualComponent
@onready var animation_component: AnimationComponent = $AnimationComponent
@onready var status_effect_system: StatusEffectSystem = $StatusEffectSystem
@onready var stance_system: StanceSystem = $StanceSystem
@onready var facing_system: FacingSystem = $FacingSystem
@onready var line_of_sight_system: LineOfSightSystem = $LineOfSightSystem

const FOVGridSystem = preload("res://scripts/systems/fov_grid_system.gd")

var grid_position: Vector2i = Vector2i(0, 0)
var grid_manager_ref: GridManager

# FOV Grid: Welche Tiles sieht dieser Soldat?
var fov_grid: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	
	if merc_data:
		initialize()

func initialize() -> void:
	health_component.initialize(merc_data)
	action_point_component.initialize(merc_data.base_agility)
	visual_component.initialize(self)
	animation_component.initialize(self)
	status_effect_system.initialize(self)
	stance_system.initialize(self)
	facing_system.initialize(self)
	line_of_sight_system.initialize(self)
	
	health_component.set_status_effect_system(status_effect_system)
	visual_component.set_team_color(is_player_unit)
	
	# WICHTIG: Dupliziere Mesh für jede Unit-Instanz!
	_duplicate_mesh()
	
	if weapon_data:
		combat_component.initialize(self, weapon_data, action_point_component)

func _duplicate_mesh() -> void:
	# Hole Model MeshInstance
	var visual_root = get_node_or_null("VisualRoot")
	if not visual_root:
		print("[Merc] WARNING: VisualRoot not found!")
		return
	
	var model_mesh = visual_root.get_node_or_null("Model")
	if not model_mesh or not model_mesh is MeshInstance3D:
		print("[Merc] WARNING: Model MeshInstance3D not found!")
		return
	
	# Dupliziere die Mesh Resource
	if model_mesh.mesh:
		model_mesh.mesh = model_mesh.mesh.duplicate()
		print("[Merc] ", merc_data.merc_name, " - Mesh duplicated successfully")
	else:
		print("[Merc] WARNING: Model has no mesh!")
	
	# Dupliziere auch die CollisionShape
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
		print("[Merc] ", merc_data.merc_name, " - CollisionShape duplicated successfully")
	else:
		print("[Merc] WARNING: CollisionShape3D not found!")

func initialize_movement(grid_manager: GridManager) -> void:
	grid_manager_ref = grid_manager
	movement_component.initialize(self, grid_manager, action_point_component)
	combat_component.grid_manager = grid_manager
	
	# Berechne initiales FOV Grid
	update_fov_grid()

func update_fov_grid() -> void:
	if grid_manager_ref:
		fov_grid = FOVGridSystem.calculate_fov_grid(self, grid_manager_ref)
		print(merc_data.merc_name, " FOV updated. Visible tiles: ", fov_grid.size())
		
		# Invalidate LoS cache when FOV changes
		line_of_sight_system.invalidate_cache()
		
		# WICHTIG: Invalidiere ALLE anderen Mercs' LoS-Caches!
		_invalidate_all_los_caches()

func _invalidate_all_los_caches() -> void:
	# Wenn sich DIESE Unit ändert, müssen alle anderen Units
	# ihre LoS-Caches neu berechnen, weil DIESE Unit jetzt woanders ist!
	var scene_root = get_parent()
	if not scene_root:
		return
	
	for node in scene_root.get_children():
		if node is Merc and node != self:
			node.line_of_sight_system.invalidate_cache()

func can_see_position(target_pos: Vector2i) -> bool:
	if not fov_grid.has(target_pos):
		return false
	return fov_grid[target_pos] > FOVGridSystem.VisibilityLevel.BLOCKED

func get_visibility_level(target_pos: Vector2i) -> int:
	if not fov_grid.has(target_pos):
		return FOVGridSystem.VisibilityLevel.BLOCKED
	return fov_grid[target_pos]

func can_see_enemy(target: Merc) -> bool:
	return line_of_sight_system.can_see_enemy(target)

func get_visible_body_parts(target: Merc) -> int:
	return line_of_sight_system.get_visible_body_parts(target)

func start_turn() -> void:
	action_point_component.reset_ap()
	animation_component.play_idle()
	status_effect_system.process_turn_effects()
	update_fov_grid()

func end_turn() -> void:
	pass

func is_alive() -> bool:
	return health_component.is_alive()

func move_to_grid(target_pos: Vector2i) -> bool:
	animation_component.play_move()
	var success = movement_component.move_to(target_pos)
	if success:
		animation_component.play_idle()
		update_fov_grid()  # Update nach Bewegung
	return success

func can_move_to_grid(target_pos: Vector2i) -> bool:
	return movement_component.can_move_to(target_pos)

func shoot_at(target: Merc, body_part: TargetingSystem.BodyPart = TargetingSystem.BodyPart.THORAX) -> Dictionary:
	animation_component.play_shoot()
	visual_component.play_muzzle_flash()
	
	var result = combat_component.shoot(target, body_part)
	
	if result.hit:
		var hit_pos = target.global_position + Vector3(0, 1, 0)
		visual_component.play_hit_effect(hit_pos, result.body_part)
		
		if result.target_killed:
			target.on_death()
	
	animation_component.play_idle()
	return result

func aim() -> bool:
	var success = combat_component.aim()
	if success:
		animation_component.play_aim()
	return success

func can_shoot(target: Merc) -> bool:
	return combat_component.can_shoot(target)

func change_stance(new_stance: StanceSystem.Stance) -> bool:
	var success = stance_system.change_stance(new_stance)
	if success:
		update_fov_grid()  # Update nach Stance-Wechsel
	return success

func get_eye_position() -> Vector3:
	return global_position + Vector3(0, stance_system.get_eye_height(), 0)

func rotate_towards(target: Merc) -> bool:
	var success = facing_system.rotate_towards_target(target)
	if success:
		update_fov_grid()  # Update nach Rotation
	return success

func rotate_to_angle(angle: float) -> bool:
	var success = facing_system.rotate_to_angle(angle)
	if success:
		update_fov_grid()  # Update nach Rotation
	return success

func on_death() -> void:
	visual_component.set_dead_visual()
	animation_component.play_death()
	print(merc_data.merc_name, " has died!")

func set_dead_visual() -> void:
	visual_component.set_dead_visual()

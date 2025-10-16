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

var grid_position: Vector2i = Vector2i(0, 0)
var grid_manager_ref: GridManager

func _ready() -> void:
	# Warte bis alle Nodes bereit sind
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
	
	# Connect systems
	health_component.set_status_effect_system(status_effect_system)
	
	# Set team color
	visual_component.set_team_color(is_player_unit)
	
	if weapon_data:
		combat_component.initialize(self, weapon_data, action_point_component)

func initialize_movement(grid_manager: GridManager) -> void:
	grid_manager_ref = grid_manager
	movement_component.initialize(self, grid_manager, action_point_component)
	
	# Update combat component mit grid manager
	combat_component.grid_manager = grid_manager

func start_turn() -> void:
	action_point_component.reset_ap()
	animation_component.play_idle()
	
	# Process status effects at turn start
	status_effect_system.process_turn_effects()

func end_turn() -> void:
	pass

func is_alive() -> bool:
	return health_component.is_alive()

func move_to_grid(target_pos: Vector2i) -> bool:
	animation_component.play_move()
	var success = movement_component.move_to(target_pos)
	if success:
		animation_component.play_idle()
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
	return stance_system.change_stance(new_stance)

func get_eye_position() -> Vector3:
	return global_position + Vector3(0, stance_system.get_eye_height(), 0)

func rotate_towards(target: Merc) -> bool:
	return facing_system.rotate_towards_target(target)

func rotate_to_angle(angle: float) -> bool:
	return facing_system.rotate_to_angle(angle)

func on_death() -> void:
	visual_component.set_dead_visual()
	animation_component.play_death()
	print(merc_data.merc_name, " has died!")

func set_dead_visual() -> void:
	visual_component.set_dead_visual()

extends Resource
class_name WeaponData

@export var weapon_name: String = "Unknown Weapon"
@export var caliber: String = "7.62x39mm"

# Weapon Stats
@export var base_damage: int = 30
@export var base_accuracy: int = 70
@export var base_recoil: int = 50
@export var base_range: int = 30

# AP Costs
@export var ap_cost_aim: int = 2
@export var ap_cost_shoot: int = 4

# Ammo
@export var magazine_size: int = 30
@export var current_ammo: int = 30

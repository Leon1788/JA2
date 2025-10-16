extends Resource
class_name MercData

# Base Stats
@export var merc_name: String = "Unknown"
@export var portrait: Texture2D

# Attributes
@export var base_health: int = 100
@export var base_agility: int = 50
@export var base_strength: int = 50
@export var base_wisdom: int = 50
@export var base_leadership: int = 50

# Skills
@export var marksmanship: int = 50
@export var mechanical: int = 50
@export var explosives: int = 50
@export var medical: int = 50

# Body Part Health (Tarkov-style)
@export var health_head: int = 35
@export var health_thorax: int = 85
@export var health_stomach: int = 70
@export var health_left_arm: int = 60
@export var health_right_arm: int = 60
@export var health_left_leg: int = 65
@export var health_right_leg: int = 65

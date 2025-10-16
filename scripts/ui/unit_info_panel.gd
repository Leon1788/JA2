extends Control
class_name UnitInfoPanel

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var hp_label: Label = $VBoxContainer/HPLabel
@onready var ap_label: Label = $VBoxContainer/APLabel
@onready var weapon_label: Label = $VBoxContainer/WeaponLabel
@onready var ammo_label: Label = $VBoxContainer/AmmoLabel

func update_display(unit: Merc) -> void:
	if not unit:
		visible = false
		return
	
	visible = true
	name_label.text = unit.merc_data.merc_name
	
	# Health
	var thorax_hp = unit.health_component.current_thorax
	var head_hp = unit.health_component.current_head
	hp_label.text = "HP: Head=%d Thorax=%d" % [head_hp, thorax_hp]
	
	# Action Points
	var current_ap = unit.action_point_component.current_ap
	var max_ap = unit.action_point_component.max_ap
	ap_label.text = "AP: %d/%d" % [current_ap, max_ap]
	
	# Weapon
	if unit.weapon_data:
		weapon_label.text = "Weapon: " + unit.weapon_data.weapon_name
		ammo_label.text = "Ammo: %d/%d" % [unit.weapon_data.current_ammo, unit.weapon_data.magazine_size]
	else:
		weapon_label.text = "Weapon: None"
		ammo_label.text = "Ammo: -"

func hide_panel() -> void:
	visible = false

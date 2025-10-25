extends Control
class_name TargetSelectionPanel

signal body_part_selected(body_part: TargetingSystem.BodyPart, target: Merc)

@onready var cover_label: Label = $PanelContainer/VBoxContainer/CoverLabel
@onready var head_button: Button = $PanelContainer/VBoxContainer/GridContainer/HeadButton
@onready var thorax_button: Button = $PanelContainer/VBoxContainer/GridContainer/ThoraxButton
@onready var stomach_button: Button = $PanelContainer/VBoxContainer/GridContainer/StomachButton
@onready var left_arm_button: Button = $PanelContainer/VBoxContainer/GridContainer/LeftArmButton
@onready var right_arm_button: Button = $PanelContainer/VBoxContainer/GridContainer/RightArmButton
@onready var left_leg_button: Button = $PanelContainer/VBoxContainer/GridContainer/LeftLegButton
@onready var right_leg_button: Button = $PanelContainer/VBoxContainer/GridContainer/RightLegButton
@onready var cancel_button: Button = $PanelContainer/VBoxContainer/CancelButton

var current_target: Merc = null

func _ready() -> void:
	if head_button:
		head_button.pressed.connect(_on_head_pressed)
	if thorax_button:
		thorax_button.pressed.connect(_on_thorax_pressed)
	if stomach_button:
		stomach_button.pressed.connect(_on_stomach_pressed)
	if left_arm_button:
		left_arm_button.pressed.connect(_on_left_arm_pressed)
	if right_arm_button:
		right_arm_button.pressed.connect(_on_right_arm_pressed)
	if left_leg_button:
		left_leg_button.pressed.connect(_on_left_leg_pressed)
	if right_leg_button:
		right_leg_button.pressed.connect(_on_right_leg_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

func show_target_selection(shooter: Merc, target: Merc) -> void:
	if not shooter or not target:
		return
	
	current_target = target
	
	if not shooter.can_see_enemy(target):
		cover_label.text = "NO LINE OF SIGHT!"
		cover_label.add_theme_color_override("font_color", Color.RED)
		_disable_all_buttons()
		show()
		return
	
	var available_parts = shooter.combat_component.get_available_body_parts(target)
	
	if available_parts.is_empty():
		cover_label.text = "NO BODY PARTS VISIBLE!"
		cover_label.add_theme_color_override("font_color", Color.RED)
		_disable_all_buttons()
		show()
		return
	
	cover_label.text = "Select Target"
	cover_label.add_theme_color_override("font_color", Color.GREEN)
	
	_disable_all_buttons()
	
	for part in available_parts:
		var button = _get_button_for_part(part)
		if button:
			var chance = shooter.combat_component.get_hit_chance_for_part(target, part)
			var part_name = TargetingSystem.get_display_name(part)
			button.text = "%s: %.0f%%" % [part_name, chance]
			button.disabled = false
	
	show()

func _get_button_for_part(part: TargetingSystem.BodyPart) -> Button:
	match part:
		TargetingSystem.BodyPart.HEAD:
			return head_button
		TargetingSystem.BodyPart.THORAX:
			return thorax_button
		TargetingSystem.BodyPart.STOMACH:
			return stomach_button
		TargetingSystem.BodyPart.LEFT_ARM:
			return left_arm_button
		TargetingSystem.BodyPart.RIGHT_ARM:
			return right_arm_button
		TargetingSystem.BodyPart.LEFT_LEG:
			return left_leg_button
		TargetingSystem.BodyPart.RIGHT_LEG:
			return right_leg_button
	return null

func _disable_all_buttons() -> void:
	for button in [head_button, thorax_button, stomach_button, left_arm_button, right_arm_button, left_leg_button, right_leg_button]:
		if button:
			button.disabled = true

func _on_head_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.HEAD, current_target)
	hide()

func _on_thorax_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.THORAX, current_target)
	hide()

func _on_stomach_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.STOMACH, current_target)
	hide()

func _on_left_arm_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.LEFT_ARM, current_target)
	hide()

func _on_right_arm_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.RIGHT_ARM, current_target)
	hide()

func _on_left_leg_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.LEFT_LEG, current_target)
	hide()

func _on_right_leg_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.RIGHT_LEG, current_target)
	hide()

func _on_cancel_pressed() -> void:
	current_target = null
	hide()

extends Control
class_name TargetSelectionPanel

signal body_part_selected(body_part: TargetingSystem.BodyPart)

var head_button: Button
var thorax_button: Button
var stomach_button: Button
var left_arm_button: Button
var right_arm_button: Button
var left_leg_button: Button
var right_leg_button: Button
var cover_label: Label
var cancel_button: Button

var shooter: Merc
var target: Merc

func _ready() -> void:
	head_button = $VBoxContainer/HeadButton
	thorax_button = $VBoxContainer/ThoraxButton
	stomach_button = $VBoxContainer/StomachButton
	left_arm_button = $VBoxContainer/LeftArmButton
	right_arm_button = $VBoxContainer/RightArmButton
	left_leg_button = $VBoxContainer/LeftLegButton
	right_leg_button = $VBoxContainer/RightLegButton
	cover_label = $VBoxContainer/CoverLabel
	cancel_button = $VBoxContainer/CancelButton
	
	head_button.pressed.connect(_on_head_pressed)
	thorax_button.pressed.connect(_on_thorax_pressed)
	stomach_button.pressed.connect(_on_stomach_pressed)
	left_arm_button.pressed.connect(_on_left_arm_pressed)
	right_arm_button.pressed.connect(_on_right_arm_pressed)
	left_leg_button.pressed.connect(_on_left_leg_pressed)
	right_leg_button.pressed.connect(_on_right_leg_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	hide()

func show_target_selection(from_shooter: Merc, to_target: Merc) -> void:
	shooter = from_shooter
	target = to_target
	
	show()
	update_button_texts()

func update_button_texts() -> void:
	if not shooter or not target:
		print("ERROR: No shooter or target!")
		return
	
	if not cover_label:
		print("ERROR: cover_label not found!")
		return
	
	print("\n=== TARGET SELECTION UI UPDATE ===")
	print("Shooter: ", shooter.merc_data.merc_name)
	print("Target: ", target.merc_data.merc_name)
	
	var target_pos = target.movement_component.current_grid_pos
	var visibility = shooter.get_visibility_level(target_pos)
	
	print("Target position: ", target_pos)
	print("Visibility level: ", visibility)
	
	# Update Cover Label
	match visibility:
		FOVGridSystem.VisibilityLevel.BLOCKED:
			cover_label.text = "NO LINE OF SIGHT!"
			cover_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
		FOVGridSystem.VisibilityLevel.PARTIAL:
			cover_label.text = "TARGET IN COVER!\n(-25% hit chance)"
			cover_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
		FOVGridSystem.VisibilityLevel.CLEAR:
			cover_label.text = "Clear Shot"
			cover_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	
	print("Cover label set to: ", cover_label.text)
	
	# Update body part buttons
	var parts = [
		TargetingSystem.BodyPart.HEAD,
		TargetingSystem.BodyPart.THORAX,
		TargetingSystem.BodyPart.STOMACH,
		TargetingSystem.BodyPart.LEFT_ARM,
		TargetingSystem.BodyPart.RIGHT_ARM,
		TargetingSystem.BodyPart.LEFT_LEG,
		TargetingSystem.BodyPart.RIGHT_LEG
	]
	
	var buttons = [
		head_button,
		thorax_button,
		stomach_button,
		left_arm_button,
		right_arm_button,
		left_leg_button,
		right_leg_button
	]
	
	for i in range(parts.size()):
		var part = parts[i]
		var button = buttons[i]
		var name = TargetingSystem.get_display_name(part)
		
		# Alle Körperteile sichtbar wenn Target sichtbar
		if visibility > FOVGridSystem.VisibilityLevel.BLOCKED:
			var chance = shooter.combat_component.get_hit_chance_for_part(target, part)
			button.text = "%s: %.1f%%" % [name, chance]
			button.disabled = false
			print("  ", name, ": ", chance, "%")
		else:
			button.text = "%s: BLOCKED" % name
			button.disabled = true
			print("  ", name, ": BLOCKED")
	
	print("=== END UI UPDATE ===\n")

func _on_head_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.HEAD)
	hide()

func _on_thorax_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.THORAX)
	hide()

func _on_stomach_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.STOMACH)
	hide()

func _on_left_arm_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.LEFT_ARM)
	hide()

func _on_right_arm_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.RIGHT_ARM)
	hide()

func _on_left_leg_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.LEFT_LEG)
	hide()

func _on_right_leg_pressed() -> void:
	body_part_selected.emit(TargetingSystem.BodyPart.RIGHT_LEG)
	hide()

func _on_cancel_pressed() -> void:
	hide()

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
	# Finde alle Nodes manuell
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
	
	print("\n=== UI UPDATE ===")
	print("Updating target selection UI")
	
	# Check for cover using shooter's grid manager reference
	var has_cover = false
	var cover_info = ""
	
	if shooter.grid_manager_ref:
		print("Grid manager found")
		var cover = shooter.grid_manager_ref.get_cover_between(shooter.movement_component.current_grid_pos, target.movement_component.current_grid_pos)
		if cover:
			has_cover = true
			cover_info = "TARGET IN COVER!\n%s (-%d%%)" % [cover.cover_data.cover_name, int(cover.get_hit_penalty())]
			print("UI: Cover detected - ", cover.cover_data.cover_name)
		else:
			print("UI: No cover found")
	else:
		print("ERROR: No grid_manager_ref on shooter!")
	
	if has_cover:
		cover_label.text = cover_info
		cover_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		print("Set label to: ", cover_info)
	else:
		cover_label.text = "Clear Shot"
		cover_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		print("Set label to: Clear Shot")
	
	print("=== END UI UPDATE ===\n")
	
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
	
	# Get visible body parts
	var visible_parts = {}
	if shooter.grid_manager_ref:
		visible_parts = LineOfSightSystem.get_visible_body_parts_for_ui(shooter, target, shooter.grid_manager_ref, shooter.get_world_3d())
	
	for i in range(parts.size()):
		var part = parts[i]
		var button = buttons[i]
		var name = TargetingSystem.get_display_name(part)
		
		# Check if this part is visible
		var is_visible = visible_parts.has(part)
		
		if is_visible:
			var chance = shooter.combat_component.get_hit_chance_for_part(target, part)
			button.text = "%s: %.1f%%" % [name, chance]
			button.disabled = false
		else:
			button.text = "%s: BLOCKED" % name
			button.disabled = true

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

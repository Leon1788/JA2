extends Node
class_name InputManager

# Signals
signal rotation_left
signal rotation_right
signal stance_standing
signal stance_crouched
signal stance_prone
signal left_click(mouse_pos: Vector2)
signal right_click(mouse_pos: Vector2)
signal toggle_fov_visualizer
signal toggle_floor
signal line_of_sight_test
signal fow_debug
signal debug_report
signal show_help
signal end_turn

func _ready() -> void:
	_setup_input_actions()
	print("[InputManager] Initialized")

func _setup_input_actions() -> void:
	# Rotation
	if not InputMap.has_action("rotate_left"):
		InputMap.add_action("rotate_left")
		var ev = InputEventKey.new()
		ev.keycode = KEY_Q
		InputMap.action_add_event("rotate_left", ev)
	
	if not InputMap.has_action("rotate_right"):
		InputMap.add_action("rotate_right")
		var ev = InputEventKey.new()
		ev.keycode = KEY_E
		InputMap.action_add_event("rotate_right", ev)
	
	# Stance
	if not InputMap.has_action("stance_standing"):
		InputMap.add_action("stance_standing")
		var ev = InputEventKey.new()
		ev.keycode = KEY_1
		InputMap.action_add_event("stance_standing", ev)
	
	if not InputMap.has_action("stance_crouched"):
		InputMap.add_action("stance_crouched")
		var ev = InputEventKey.new()
		ev.keycode = KEY_2
		InputMap.action_add_event("stance_crouched", ev)
	
	if not InputMap.has_action("stance_prone"):
		InputMap.add_action("stance_prone")
		var ev = InputEventKey.new()
		ev.keycode = KEY_3
		InputMap.action_add_event("stance_prone", ev)
	
	# Visualization
	if not InputMap.has_action("toggle_fov_viz"):
		InputMap.add_action("toggle_fov_viz")
		var ev = InputEventKey.new()
		ev.keycode = KEY_V
		InputMap.action_add_event("toggle_fov_viz", ev)
	
	if not InputMap.has_action("toggle_floor"):
		InputMap.add_action("toggle_floor")
		var ev = InputEventKey.new()
		ev.keycode = KEY_TAB
		InputMap.action_add_event("toggle_floor", ev)
	
	# Debug
	if not InputMap.has_action("los_test"):
		InputMap.add_action("los_test")
		var ev = InputEventKey.new()
		ev.keycode = KEY_T
		InputMap.action_add_event("los_test", ev)
	
	if not InputMap.has_action("fow_debug_info"):
		InputMap.add_action("fow_debug_info")
		var ev = InputEventKey.new()
		ev.keycode = KEY_F
		InputMap.action_add_event("fow_debug_info", ev)
	
	if not InputMap.has_action("debug_report"):
		InputMap.add_action("debug_report")
		var ev = InputEventKey.new()
		ev.keycode = KEY_D
		InputMap.action_add_event("debug_report", ev)
	
	if not InputMap.has_action("show_help"):
		InputMap.add_action("show_help")
		var ev = InputEventKey.new()
		ev.keycode = KEY_H
		InputMap.action_add_event("show_help", ev)
	
	# Turn
	if not InputMap.has_action("end_turn"):
		InputMap.add_action("end_turn")
		var ev = InputEventKey.new()
		ev.keycode = KEY_SPACE
		InputMap.action_add_event("end_turn", ev)

func _input(event: InputEvent) -> void:
	# Rotation
	if Input.is_action_just_pressed("rotate_left"):
		rotation_left.emit()
	
	if Input.is_action_just_pressed("rotate_right"):
		rotation_right.emit()
	
	# Stance
	if Input.is_action_just_pressed("stance_standing"):
		stance_standing.emit()
	
	if Input.is_action_just_pressed("stance_crouched"):
		stance_crouched.emit()
	
	if Input.is_action_just_pressed("stance_prone"):
		stance_prone.emit()
	
	# Mouse
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			left_click.emit(event.position)
		
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			right_click.emit(event.position)
	
	# Visualization
	if Input.is_action_just_pressed("toggle_fov_viz"):
		toggle_fov_visualizer.emit()
	
	if Input.is_action_just_pressed("toggle_floor"):
		toggle_floor.emit()
	
	# Debug
	if Input.is_action_just_pressed("los_test"):
		line_of_sight_test.emit()
	
	if Input.is_action_just_pressed("fow_debug_info"):
		fow_debug.emit()
	
	if Input.is_action_just_pressed("debug_report"):
		debug_report.emit()
	
	if Input.is_action_just_pressed("show_help"):
		show_help.emit()
	
	# Turn
	if Input.is_action_just_pressed("end_turn"):
		end_turn.emit()

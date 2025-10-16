extends Node
class_name AnimationComponent

var animation_player: AnimationPlayer

func initialize(root: Node3D) -> void:
	animation_player = root.get_node_or_null("AnimationPlayer")

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	else:
		# Placeholder - keine Animation vorhanden
		pass

func play_idle() -> void:
	play_animation("idle")

func play_move() -> void:
	play_animation("move")

func play_shoot() -> void:
	play_animation("shoot")

func play_death() -> void:
	play_animation("death")

func play_aim() -> void:
	play_animation("aim")

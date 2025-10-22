extends Control
class_name SubMenuBase

# Signal, das dem Hauptmenü sagt: "Ich bin fertig, schließe mich"
signal back_requested

@onready var back_button: Button = $Panel/VBoxContainer/BackButton

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		print("FEHLER: BackButton nicht in SubMenuBase gefunden!")

func _on_back_pressed() -> void:
	# Sende das Signal und entferne die Szene
	back_requested.emit()
	queue_free()

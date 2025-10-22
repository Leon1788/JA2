extends Control
class_name MainMenu

# Pfade zu den Szenen
const GAME_SCENE_PATH = "res://scenes/levels/fov_test.tscn"
const OPTIONS_SCENE_PATH = "res://scenes/ui/OptionsScreen.tscn"
const LOAD_SCENE_PATH = "res://scenes/ui/LoadScreen.tscn"

# Szenen vorladen
var options_scene = preload(OPTIONS_SCENE_PATH)
var load_scene = preload(LOAD_SCENE_PATH)

# Referenzen auf die Nodes in der Szene
# Diese Pfade stimmen jetzt mit der .tscn-Datei überein:
@onready var button_container: VBoxContainer = $Panel/VBoxContainer
@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var load_button: Button = $Panel/VBoxContainer/LoadButton
@onready var options_button: Button = $Panel/VBoxContainer/OptionsButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

func _ready() -> void:
	# Bessere Fehlerprüfung
	if not start_button or not load_button or not options_button or not quit_button:
		print("FEHLER: Ein oder mehrere Buttons wurden in main_menu.gd nicht gefunden!")
		print("  Pfad erwartet: $Panel/VBoxContainer/StartButton")
		print("  StartButton gefunden: ", start_button)
		print("  QuitButton gefunden: ", quit_button)
		
		print("\n=== AKTUELLE SZENENSTRUKTUR (FEHLER) ===")
		_debug_print_tree(self, 0)
		print("=======================================\n")
		return

	# Signale verbinden
	print("Hauptmenü initialisiert. Alle Buttons gefunden. Verbinde Signale...")
	start_button.pressed.connect(_on_start_pressed)
	load_button.pressed.connect(_on_load_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

# 1. Spiel starten
func _on_start_pressed() -> void:
	print("Starte Spiel...")
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

# 2. Lade-Menü öffnen
func _on_load_pressed() -> void:
	print("Öffne Lade-Menü...")
	var load_menu = load_scene.instantiate()
	load_menu.back_requested.connect(_on_submenu_closed)
	add_child(load_menu)
	button_container.visible = false

# 3. Optionen-Menü öffnen
func _on_options_pressed() -> void:
	print("Öffne Optionen...")
	var options_menu = options_scene.instantiate()
	options_menu.back_requested.connect(_on_submenu_closed)
	add_child(options_menu)
	button_container.visible = false

# 4. Spiel beenden
func _on_quit_pressed() -> void:
	print("Beende Spiel.")
	get_tree().quit()

# Wird aufgerufen, wenn ein Sub-Menü (Laden, Optionen) "back_requested" sendet
func _on_submenu_closed() -> void:
	print("Zurück zum Hauptmenü.")
	button_container.visible = true

# Debug-Funktion (mit dem lpad-Workaround)
func _debug_print_tree(node: Node, level: int) -> void:
	var indent = "".lpad(level * 2, " ")
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		_debug_print_tree(child, level + 1)

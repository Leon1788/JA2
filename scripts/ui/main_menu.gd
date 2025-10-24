extends Control
class_name MainMenu

# Pfade zu den Szenen
const GAME_SCENE_PATH = "res://scenes/levels/fov_test.tscn"
const OPTIONS_SCENE_PATH = "res://scenes/ui/OptionsScreen.tscn"
const LOAD_SCENE_PATH = "res://scenes/ui/LoadScreen.tscn"
# Pfad zur Musikdatei
const MUSIC_PATH = "res://assets/music/Shadow.mp3" # <-- Überprüfe diesen Pfad SEHR GENAU!

# Szenen vorladen
var options_scene = preload(OPTIONS_SCENE_PATH)
var load_scene = preload(LOAD_SCENE_PATH)
# Musik versuchen zu laden
var music_stream: AudioStream = load(MUSIC_PATH) # Expliziter Typ

# Referenzen auf die Nodes in der Szene
@onready var button_container: VBoxContainer = $Panel/VBoxContainer
@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var load_button: Button = $Panel/VBoxContainer/LoadButton
@onready var options_button: Button = $Panel/VBoxContainer/OptionsButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton
@onready var title_image: TextureRect = $TitleImage
@onready var music_player: AudioStreamPlayer = $MusicPlayer

func _ready() -> void:
	print("\n--- MainMenu _ready() START ---")

	# --- Button-Prüfung ---
	if not start_button or not load_button or not options_button or not quit_button:
		print("FEHLER: Ein oder mehrere Buttons wurden nicht gefunden!")
		print("  Pfad erwartet: $Panel/VBoxContainer/StartButton")
		_debug_print_tree(self, 0) # Zeige Struktur bei Fehler
		return # Beende _ready() hier, da UI kaputt ist

	print("[INFO] Buttons gefunden.")

	# --- Musik-Prüfung (SEHR DETAILLIERT) ---
	print("\n[DEBUG] Prüfe Musik...")
	if not music_player:
		print("  - FEHLER: AudioStreamPlayer Node ($MusicPlayer) NICHT GEFUNDEN!")
		_debug_print_tree(self, 0) # Zeige Struktur bei Fehler
	else:
		print("  - AudioStreamPlayer Node ($MusicPlayer) GEFUNDEN.")
		if not music_stream:
			print("  - FEHLER: Musikdatei konnte NICHT geladen werden unter Pfad:", MUSIC_PATH)
			print("    -> Prüfe, ob die Datei existiert und der Pfad exakt stimmt (Groß/Kleinschreibung!).")
			print("    -> Prüfe das Godot 'Ausgabe'-Panel auf IMPORT-FEHLER für diese Datei!")
		else:
			print("  - Musikdatei erfolgreich geladen:", music_stream.resource_path)
			print("    -> Typ:", music_stream.get_class()) # Welcher Typ wurde geladen? AudioStreamMP3?
			print("    -> Länge (Sekunden):", music_stream.get_length() if music_stream.has_method("get_length") else "N/A")

			# Versuche, den Stream zuzuweisen und abzuspielen
			print("  - Weise Stream dem Player zu...")
			music_player.stream = music_stream
			if music_player.stream == music_stream:
				print("  - Stream erfolgreich zugewiesen.")
				print("  - Rufe music_player.play() auf...")
				music_player.play()

				# Kurze Verzögerung, um zu sehen, ob das Abspielen startet
				await get_tree().create_timer(0.1).timeout
				if music_player.is_playing():
					print("  - Player meldet: SPIELT JETZT.")
					# Optional: Musik loopen lassen
					if not music_player.finished.is_connected(_on_music_finished): # Nur verbinden, falls noch nicht geschehen
						music_player.finished.connect(_on_music_finished)
					print("  - Loop-Signal verbunden.")
				else:
					print("  - FEHLER: Player meldet nach play(): SPIELT NICHT.")
					print("    -> Prüfe Godot Audio-Einstellungen (Master-Bus Lautstärke).")
					print("    -> Prüfe Systemlautstärke.")
					print("    -> Ist die MP3-Datei möglicherweise leer oder beschädigt?")
			else:
				print("  - FEHLER: Stream konnte dem Player NICHT zugewiesen werden!")


	# --- Signale verbinden ---
	print("\n[INFO] Verbinde Button-Signale...")
	start_button.pressed.connect(_on_start_pressed)
	load_button.pressed.connect(_on_load_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	print("[INFO] Hauptmenü initialisiert.")

	print("\n--- MainMenu _ready() ENDE ---\n")

# --- Signal-Handler ---
func _on_start_pressed() -> void:
	print("Starte Spiel...")
	if music_player and music_player.is_playing(): music_player.stop() # Musik stoppen
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_load_pressed() -> void:
	print("Öffne Lade-Menü...")
	var load_menu = load_scene.instantiate()
	load_menu.back_requested.connect(_on_submenu_closed)
	add_child(load_menu)
	if button_container: button_container.visible = false

func _on_options_pressed() -> void:
	print("Öffne Optionen...")
	var options_menu = options_scene.instantiate()
	options_menu.back_requested.connect(_on_submenu_closed)
	add_child(options_menu)
	if button_container: button_container.visible = false

func _on_quit_pressed() -> void:
	print("Beende Spiel.")
	if music_player and music_player.is_playing(): music_player.stop() # Musik stoppen
	get_tree().quit()

func _on_submenu_closed() -> void:
	print("Zurück zum Hauptmenü.")
	if button_container: button_container.visible = true

# Funktion für Musik-Loop
func _on_music_finished():
	if music_player and music_stream: # Nur neustarten, wenn Stream gültig ist
		print("[DEBUG] Musik beendet, starte Loop...")
		music_player.play() # Erneut abspielen

# Debug-Funktion (mit dem lpad-Workaround)
func _debug_print_tree(node: Node, level: int) -> void:
	var indent = "".lpad(level * 2, " ")
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_debug_print_tree(child, level + 1)

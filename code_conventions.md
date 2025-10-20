# Code Conventions & Entwicklungsregeln

## Projekt-Philosophie

### 1. Code-First
- **ALLES** wird im Code erstellt, nicht im Godot Editor
- `.tscn` Dateien werden als Code geschrieben
- Kein manuelles Drag&Drop im Editor (außer beim Testen)
- **Warum:** Reproduzierbarkeit, Versionskontrolle, KI-freundlich

### 2. Datengetrieben (Data-Driven)
- Neue Inhalte durch `.tres` Resource-Dateien, nicht durch Code-Änderungen
- Beispiel: Neuer Söldner = neue `.tres` Datei, keine neue Klasse
- **Warum:** Designer können ohne Programmierer arbeiten

### 3. Modular (ERC-System)
- Jedes System ist ein unabhängiges Component
- Keine monolithischen "GodClasses"
- Components kommunizieren über klare Interfaces
- **Warum:** Wiederverwendbarkeit, Testbarkeit

---

## ERC-System im Detail

### Entity (Szene)
```
Merc.tscn
  └─ Merc (Node3D) + merc.gd
      ├─ VisualRoot (Node3D)
      │   ├─ Model (MeshInstance3D)
      │   ├─ WeaponAttachPoint (Node3D)
      │   └─ MuzzleFlashPoint (Node3D)
      └─ Components (Node)
          ├─ HealthComponent
          ├─ MovementComponent
          ├─ CombatComponent
          ├─ StanceSystem
          └─ FacingSystem
```

**Regeln:**
- Entity-Script (`merc.gd`) ist der **Coordinator**
- Entity hat **keine Business-Logic**, nur Delegation
- Alle Logik liegt in Components

### Resource (Daten)
```gdscript
extends Resource
class_name MercData

@export var merc_name: String = "Unknown"
@export var base_health: int = 100
@export var base_agility: int = 50
# ... etc
```

**Regeln:**
- Nur `@export` Variablen, keine Funktionen
- Keine Logik in Resources
- Resources sind **pure Daten**

### Component (Verhalten)
```gdscript
extends Node
class_name HealthComponent

var current_head: int
var merc_data: MercData

func initialize(data: MercData) -> void:
    merc_data = data
    current_head = data.health_head

func take_damage(body_part: String, damage: int) -> void:
    # Logic here
```

**Regeln:**
- Ein Component = eine Verantwortung
- Components kennen ihre Owner-Entity
- Components kommunizieren über Owner (nicht direkt untereinander)

---

## Naming Conventions

### Dateien
```
snake_case.gd         # Scripts
PascalCase.tscn       # Scenes
snake_case.tres       # Resources
```

### Code
```gdscript
# Variablen & Funktionen: snake_case
var current_health: int
func take_damage(amount: int) -> void:

# Konstanten: SCREAMING_SNAKE_CASE
const MAX_HEALTH: int = 100

# Klassen: PascalCase
class_name HealthComponent

# Enums: PascalCase für Typ, SCREAMING für Werte
enum Stance {
    STANDING,
    CROUCHED,
    PRONE
}

# Private Variablen/Funktionen: _underscore_prefix
var _internal_state: int
func _calculate_bonus() -> int:
```

### Nodes in Szenen
```
PascalCase ohne Spaces
Beispiele: HealthComponent, MeshInstance3D, WeaponAttachPoint
```

---

## Script-Struktur

### Reihenfolge in .gd Dateien
```gdscript
extends Node
class_name MyComponent

# 1. Signale
signal health_changed(new_value: int)

# 2. Enums
enum Status { ALIVE, DEAD }

# 3. Konstanten
const MAX_VALUE: int = 100

# 4. @export Variablen
@export var data: MercData

# 5. Public Variablen
var current_value: int

# 6. Private Variablen
var _internal_state: bool

# 7. @onready Variablen
@onready var mesh: MeshInstance3D = $Mesh

# 8. Lifecycle Funktionen (_ready, _process)
func _ready() -> void:
    pass

# 9. Public Funktionen (alphabetisch)
func calculate_total() -> int:
    pass

func initialize(data: MercData) -> void:
    pass

# 10. Private Funktionen (alphabetisch)
func _internal_helper() -> void:
    pass
```

---

## Type Hints

### Immer verwenden!
```gdscript
# ✅ GUT
func get_health() -> int:
    return current_health

var position: Vector3 = Vector3.ZERO
var items: Array[String] = []

# ❌ SCHLECHT
func get_health():
    return current_health

var position = Vector3.ZERO
var items = []
```

### Warum?
- Editor-Autocomplete
- Frühe Fehler-Erkennung
- Code ist selbst-dokumentierend

---

## Component-Patterns

### Initialization Pattern
```gdscript
class_name MyComponent

var owner_entity: Merc
var dependency: OtherComponent

# Immer initialize() statt _ready()
func initialize(entity: Merc, dep: OtherComponent) -> void:
    owner_entity = entity
    dependency = dep
    _setup()

func _setup() -> void:
    # Internal setup logic
```

**Warum?**
- `_ready()` Reihenfolge ist nicht garantiert
- Explizite Dependencies
- Testbar (ohne Godot-Lifecycle)

### Communication Pattern
```gdscript
# ❌ SCHLECHT: Components sprechen direkt
class_name CombatComponent
func shoot():
    owner_entity.movement_component.reduce_ap(4)  # BAD!

# ✅ GUT: Über Owner kommunizieren
class_name CombatComponent
func shoot():
    owner_entity.spend_action_points(4)  # Owner delegiert
```

---

## Resource-Patterns

### Erstellen
```gdscript
# ivan_dolvich.tres
[gd_resource type="Resource" script_class="MercData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/merc_data.gd" id="1"]

[resource]
script = ExtResource("1")
merc_name = "Ivan Dolvich"
base_health = 100
# ... etc
```

### Laden & Nutzen
```gdscript
# Laden
var ivan_data = load("res://resources/mercs/ivan_dolvich.tres")

# Nutzen
merc.merc_data = ivan_data

# Duplizieren (für Gegner)
enemy.merc_data = ivan_data.duplicate()
enemy.merc_data.merc_name = "Enemy Clone"
```

---

## Scene-Patterns (.tscn als Code)

### Minimale Scene
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/entities/merc.gd" id="1"]

[node name="Merc" type="Node3D"]
script = ExtResource("1")
```

### Mit Mesh
```
[sub_resource type="CapsuleMesh" id="CapsuleMesh_1"]
radius = 0.3
height = 1.8

[node name="Model" type="MeshInstance3D" parent="."]
mesh = SubResource("CapsuleMesh_1")
```

**Wichtig:**
- Keine hardcoded Paths zu Assets (die kommen später)
- Alles parametrisierbar über @export

---

## Debug & Testing

### Print Guidelines
```gdscript
# ✅ Strukturiertes Debugging
print("=== SYSTEM START ===")
print("Value: ", some_value)
print("=== SYSTEM END ===")

# ❌ Chaos
print(some_value)
print("test")
```

### Debug-Funktionen
```gdscript
# Für Development
func _debug_print_state() -> void:
    if OS.is_debug_build():
        print("Health: ", current_health)
```

### Test-Szenen
- Jedes neue Feature bekommt Test-Output in Console
- Test-Szenen in `scenes/levels/` mit Prefix `test_`
- Beispiel: `main_test.tscn`, `stance_test.tscn`

---

## Performance-Guidelines

### Vermeiden
```gdscript
# ❌ In _process() / _physics_process()
func _process(delta):
    var expensive = some_heavy_calculation()  # BAD!

# ✅ Cache Ergebnisse
var _cached_result: int

func _ready():
    _cached_result = some_heavy_calculation()
```

### Grid-Operationen
```gdscript
# ✅ Grid-Operationen sind O(1)
grid_manager.is_tile_walkable(Vector2i(5, 5))

# ❌ Nicht über alle Tiles loopen
for x in range(grid_size.x):
    for y in range(grid_size.y):
        check_tile(x, y)  # BAD! O(n²)
```

---

## Godot-Spezifika

### @onready
```gdscript
# ✅ Verwende @onready für Node-Referenzen
@onready var mesh: MeshInstance3D = $MeshInstance3D

# ❌ Nicht in _ready()
var mesh: MeshInstance3D
func _ready():
    mesh = $MeshInstance3D  # Unnötig verbose
```

### Signale
```gdscript
# Deklaration
signal health_changed(new_health: int)

# Emittieren
health_changed.emit(current_health)

# Verbinden
health_component.health_changed.connect(_on_health_changed)
```

---

## Git-Workflow (Empfohlen)

### Branch-Struktur
```
main              # Stable, spielbar
├─ dev            # Development
   ├─ feature/inventory
   ├─ feature/ai
   └─ bugfix/cover-height
```

### Commit-Messages
```
[FEATURE] Add inventory grid system
[FIX] Cover height calculation for prone stance
[REFACTOR] Split CombatComponent into smaller pieces
[TEST] Add stance switching test scene
[DOCS] Update PROJECT_SUMMARY with FOV system
```

---

## Häufige Fehler vermeiden

### 1. Keine Null-Checks
```gdscript
# ❌
func use_component():
    component.do_thing()  # Crash if null!

# ✅
func use_component():
    if component:
        component.do_thing()
```

### 2. Float-Vergleiche
```gdscript
# ❌
if position.x == 5.0:  # Float precision!

# ✅
if is_equal_approx(position.x, 5.0):
```

### 3. Resource-Sharing
```gdscript
# ❌ Beide Mercs ändern die GLEICHE Resource
merc1.weapon_data = akm
merc2.weapon_data = akm
merc2.weapon_data.current_ammo = 0  # Auch merc1 hat jetzt 0!

# ✅ Duplizieren
merc2.weapon_data = akm.duplicate()
```

---

## Erweiterung des Projekts

### Neues System hinzufügen
1. **Data:** Erstelle `my_data.gd` in `scripts/data/`
2. **Component:** Erstelle `my_component.gd` in `scripts/components/`
3. **Test:** Erstelle Test-Scene in `scenes/levels/test_my_system.tscn`
4. **Integration:** Füge Component zu `Merc.tscn` hinzu
5. **Doku:** Update `CURRENT_STATE.md`

### Neuen Merc hinzufügen
1. Erstelle `new_merc.tres` in `resources/mercs/`
2. Setze alle @export Variablen
3. Fertig! Keine Code-Änderung nötig

### Neue Waffe hinzufügen
1. Erstelle `new_weapon.tres` in `resources/weapons/`
2. Setze Damage, Accuracy, etc.
3. Fertig!

---

## Tools & Setup

### Empfohlener Editor
- **Visual Studio Code** mit Godot Extension
- Oder Godot's integrierter Editor

### Extensions (VS Code)
- `godot-tools` (Syntax Highlighting)
- `gdformat` (Auto-Formatting)

### Godot Project Settings
```
Display/Window/Size/Width: 1920
Display/Window/Size/Height: 1080
Rendering/Renderer: Forward+
```

---

## Zusammenfassung: Die 10 Gebote

1. **Code-First:** Alles im Code, nicht im Editor klicken
2. **ERC-System:** Entity = Coordinator, Component = Logic, Resource = Data
3. **Type Hints:** Immer und überall
4. **Naming:** snake_case, PascalCase, SCREAMING_CASE konsistent
5. **Initialize:** Nicht _ready(), sondern initialize()
6. **Null-Safe:** Immer prüfen
7. **Duplicate Resources:** Nie sharen zwischen Instanzen
8. **Modular:** Kleine Components > große Klassen
9. **Debug-Output:** Strukturiert mit === Markers
10. **Test:** Jedes Feature sofort testen

---

**Wenn du diese Conventions befolgst, bleibt das Projekt sauber, erweiterbar und wartbar.**

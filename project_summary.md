# Broken Spear - Taktisches Rundenkampfspiel

## Projektvision
Ein taktisches Rundenkampfspiel inspiriert von **Jagged Alliance 2 (1.13)** mit der Ausrüstungstiefe von **Escape from Tarkov**, entwickelt in **Godot 4.4** mit einem **Code-First** Ansatz.

## Setting
- **Zeitraum:** Kalter Krieg (späte 70er / frühe 80er Jahre)
- **Perspektive:** Feste 2.5D isometrische Ansicht (keine Kameradrehung)
- **Gameplay:** Söldner-Taktik mit Solo- und Squad-Modus

---

## Kern-Architektur: ERC-System

Alle Spielobjekte nutzen ein **Entity-Resource-Component** System:

### Entity (Die Szene)
- Leere Container-Nodes (z.B. `Merc.tscn`)
- Keine Logik, nur Struktur

### Resource (Die Daten)
- `.tres` Dateien mit allen Variablen
- Beispiel: `ivan_dolvich.tres` (MercData), `akm.tres` (WeaponData)
- **Vorteil:** Neue Einheiten/Waffen ohne Code-Änderung

### Component (Das Verhalten)
- Modulare Scripts für spezifische Aufgaben
- Beispiel: `HealthComponent`, `MovementComponent`, `CombatComponent`
- **Vorteil:** Wiederverwendbar, erweiterbar

---

## Ordnerstruktur

```
res://
├── scenes/
│   ├── entities/          # Merc.tscn, CoverObject.tscn
│   ├── levels/            # main_test.tscn, etc.
│   └── ui/                # target_selection_panel.tscn, unit_info_panel.tscn
├── scripts/
│   ├── components/        # health_component.gd, combat_component.gd, etc.
│   ├── systems/           # grid_manager.gd, turn_manager.gd, facing_system.gd
│   ├── data/              # merc_data.gd, weapon_data.gd, cover_data.gd
│   └── entities/          # merc.gd, cover_object.gd
├── resources/
│   ├── mercs/             # ivan_dolvich.tres
│   ├── weapons/           # akm.tres
│   ├── gear/              # (geplant)
│   ├── cover/             # crate_low.tres, wall_high.tres
│   └── materials/         # merc_player.tres, merc_enemy.tres, merc_dead.tres
└── assets/
    ├── models/            # (Placeholder - später 3D Assets)
    ├── textures/
    └── audio/
```

---

## Implementierte Systeme (Phase 1.5)

### ✅ 1. Grid-System
- **Grid Manager** (`grid_manager.gd`)
- 10x10 Tile-basiertes Grid
- Grid-Grenzen (nicht außerhalb laufen)
- Cover-Tracking (welche Tiles blockiert)
- Pfadfindung (Nachbar-Tiles)

### ✅ 2. Bewegungs-System
- **Movement Component** (`movement_component.gd`)
- AP-basierte Bewegung (2 AP pro Tile)
- Manhattan-Distanz Berechnung
- Bewegung blockiert von Cover und anderen Einheiten
- Modifiziert durch Status-Effekte (zerstörte Beine = mehr AP)

### ✅ 3. Turn-System
- **Turn Manager** (`turn_manager.gd`)
- Spieler-Phase / Gegner-Phase
- AP-Reset bei Turn-Start
- Status-Effekte werden pro Turn verarbeitet

### ✅ 4. Gesundheits-System (Tarkov-Style)
- **Health Component** (`health_component.gd`)
- 7 Körperteile: Kopf, Thorax, Magen, Linker/Rechter Arm, Linkes/Rechtes Bein
- Jedes Körperteil hat eigene HP
- Tod bei Kopf = 0 oder Thorax = 0
- Zerstörte Körperteile lösen Status-Effekte aus

### ✅ 5. Status-Effekte
- **Status Effect System** (`status_effect_system.gd`)
- **ARM_DESTROYED:** -40% Accuracy (rechter Arm), -20% (linker Arm)
- **LEG_DESTROYED:** +50% AP-Kosten für Bewegung pro Bein (beide = 3x Kosten)
- **BLEEDING:** -10 HP pro Runde am Thorax
- **FRACTURE/PAIN:** (vorbereitet, nicht implementiert)

### ✅ 6. Targeting-System
- **Targeting System** (`targeting_system.gd`)
- Körperteil-Auswahl beim Schießen
- Unterschiedliche Trefferchancen pro Körperteil (Kopf -20%, Beine -10%)
- Unterschiedlicher Schaden-Multiplier (Kopf 1.5x, Arme 0.7x)
- UI zeigt Trefferchance für jedes Körperteil

### ✅ 7. Deckungssystem
- **Cover Objects** (`cover_object.gd`, `cover_data.gd`)
- **Low Cover** (Kiste): Höhe 1.0m, -20% Trefferchance
- **High Cover** (Wand): Höhe 2.5m, -40% Trefferchance
- Cover blockiert Bewegung
- Zerstörbare/Unzerstörbare Cover

### ✅ 8. Line of Sight (LoS)
- **LoS System** (`line_of_sight_system.gd`)
- 3D Sichtlinien von Schützen-Auge zu Ziel-Körperteilen
- Cover blockiert basierend auf Höhe
- Blockierte Körperteile werden im UI ausgegraut ("BLOCKED")
- Berücksichtigt Stance (liegend sieht weniger)

### ✅ 9. Stance-System
- **Stance System** (`stance_system.gd`)
- 3 Stances: **STANDING** (1.6m Augenhöhe), **CROUCHED** (1.0m), **PRONE** (0.3m)
- AP-Kosten für Stance-Wechsel (2-5 AP je nach Wechsel)
- Accuracy-Modifier (Prone = +10%, Standing = -5%)
- Visuelle Capsule-Höhe ändert sich

### ✅ 10. Facing & Field of View (FOV)
- **Facing System** (`facing_system.gd`)
- 360° Rotation (0° = Nord)
- AP-Kosten: 1 AP pro 45° Rotation
- **FOV:** 120° Sichtkegel
- Kann nur schießen wenn Ziel im FOV
- Rotation zu Ziel automatisch (R-Taste)

### ✅ 11. Kampf-System
- **Combat Component** (`combat_component.gd`)
- Zielen (+10% Accuracy pro Aim-Aktion, stapelbar)
- Schuss-Berechnung: Marksmanship + Aim Bonus - Distanz - Cover - Körperteil-Modifier
- Munitionsverwaltung (Magazine leer = Nachladen nötig)
- Waffen-Stats (Damage, Accuracy, Recoil, Range)

### ✅ 12. Visuals (Asset-Ready)
- **Visual Component** (`visual_component.gd`)
- Team-Farben (Blau = Spieler, Rot = Gegner, Grau = Tot)
- Material-System über Resources
- Placeholder für VFX (Muzzle Flash, Hit Effects)
- Placeholder für Animationen

### ✅ 13. UI-System
- **Unit Info Panel:** Name, HP, AP, Waffe, Munition
- **Target Selection Panel:** Körperteil-Auswahl mit Trefferchancen, Cover-Warnung
- Blockierte Körperteile werden ausgegraut

---

## Test-Szenen

### `main_test.tscn` (Haupt-Test-Level)
Kombiniert alle Features:
- Movement, Rotation, Stance, Combat
- Cover-Objekte platziert
- Vollständige Controls

**Controls:**
- **MOVEMENT:** Left Click
- **ROTATION:** Q (Links 45°) | E (Rechts 45°) | R (Zum Gegner)
- **STANCE:** 1 (Stehen) | 2 (Hocken) | 3 (Liegen)
- **COMBAT:** A (Zielen) | F (Schießen)
- **TURN:** Space (Zug beenden)

---

## Geplante Features (Nicht implementiert)

### Phase 2: Squad-Management
- Inventar-System (Grid-basiert, Tetris-Style)
- Waffen-Modding (Tarkov-Style Attachments)
- Munitionstypen (FMJ, HP, AP)
- Magazin-System (Nachladen, leere Magazine)
- Ausrüstungs-Slots (Helm, Weste, Rucksack)

### Phase 2: Erweiterte Taktik
- Einfache KI (Gegner bewegt sich, schießt zurück)
- Fog of War (Gegner nur sichtbar wenn in LoS + FOV)
- Visueller Sichtkegel (grüner Overlay auf Grid)
- Overwatch-Modus (Interrupt bei Gegnerbewegung)

### Phase 3: Kampagne
- Strategische Weltkarte (Sektoren erobern)
- Söldner rekrutieren
- Missions-System
- Basis-Upgrade
- Fortschritt & Progression

### Phase 4: Spezialmechaniken
- Sniper/Spotter-Team (asymmetrische Taktik)
- Erhöhte Positionen (Dächer, 2. Etage)
- Zerstörbare Umgebung

---

## Technische Details

### Godot Version
- **Godot 4.4.1** (Forward+ Renderer)

### Code-Konventionen
- **Sprache:** GDScript
- **Naming:** snake_case für Variablen/Funktionen, PascalCase für Klassen
- **class_name:** Alle wichtigen Scripts haben class_name für globale Verwendung
- **@export:** Für Designer-zugängliche Variablen
- **@onready:** Für Node-Referenzen

### Performance-Überlegungen
- Feste Kamera = keine Rotation-Performance-Kosten
- Grid-basiert = effiziente Kollisionsprüfung
- Material-System = einfache Asset-Substitution

---

## Nächste Schritte

1. **LoS + FOV kombinieren:** Aktuell prüft FOV nur ob Gegner im Sichtkegel ist, aber LoS ignoriert Facing-Richtung. Diese müssen kombiniert werden.

2. **Visueller Sichtkegel:** Grüner Overlay auf dem Grid der zeigt wohin der Söldner schaut.

3. **Fog of War:** Gegner werden nur gerendert wenn sie in LoS + FOV sind.

4. **Einfache KI:** Gegner führt automatisch Aktionen aus (bewegen, drehen, schießen).

5. **Inventar-System:** Grid-basiertes Inventar mit Drag&Drop.

---

## Entwicklungs-Philosophie

- **Code-First:** Alles im Code, kein manuelles Klicken im Editor
- **Datengetrieben:** Neue Inhalte durch .tres Dateien, nicht durch Code-Änderungen
- **Modular:** Jedes System unabhängig, wiederverwendbar
- **Asset-Ready:** Placeholder-Visuals können jederzeit durch echte 3D-Models ersetzt werden
- **Test-First:** Jedes Feature wird sofort getestet mit Debug-Output

---

**Projekt-Status:** Phase 1.5 abgeschlossen, bereit für Phase 2 (Squad-Management) oder Phase 2+ (KI & Fog of War)

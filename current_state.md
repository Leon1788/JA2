# Aktueller Projekt-Stand

## Was funktioniert ✅

### Kern-Gameplay
- [x] Grid-basierte Bewegung (10x10, erweiterbar)
- [x] AP-basiertes Aktionssystem
- [x] Turn-basiertes Spielprinzip (Spieler/Gegner)
- [x] Rundenkampf mit Körperteil-Targeting

### Combat-Systeme
- [x] Schießen auf 7 verschiedene Körperteile
- [x] Trefferchance-Berechnung (Skills, Distanz, Körperteil, Cover)
- [x] Zielen für Accuracy-Bonus (stapelbar)
- [x] Munitionsverwaltung (Magazine leeren sich)
- [x] Waffen-Stats (Damage, Accuracy, Range)

### Taktische Tiefe
- [x] **Deckungssystem:** Low/High Cover mit unterschiedlichen Penalties
- [x] **Stance-System:** Stehen/Hocken/Liegen mit AP-Kosten
- [x] **Facing-System:** 360° Rotation, FOV 120°
- [x] **Line of Sight:** 3D-Raycasts prüfen sichtbare Körperteile
- [x] **Status-Effekte:** Zerstörte Gliedmaßen, Blutung

### Visual-Systeme
- [x] Grid-Visualisierung (grüne Linien)
- [x] Team-Farben (Blau/Rot/Grau)
- [x] Material-System für Asset-Austausch vorbereitet
- [x] Capsule-Größe ändert sich mit Stance
- [x] Rotation sichtbar

### UI
- [x] Unit Info Panel (HP, AP, Waffe, Munition)
- [x] Target Selection mit Trefferchancen pro Körperteil
- [x] Cover-Warnung im UI ("TARGET IN COVER!")
- [x] Blockierte Körperteile werden ausgegraut

---

## Bekannte Probleme / Bugs 🐛

### Kritisch
- **Gegner ändert auch Stance:** Wenn Spieler 1/2/3 drückt, ändert sich auch Gegner-Stance (gleiche Mesh-Instanz)
  - **Ursache:** Beide Units nutzen die gleiche Resource und Godot teilt die Mesh-Referenz
  - **Fix:** Separate Mesh-Instanzen oder Visual Component besser isolieren

### Minor
- **Keine visuelle Facing-Anzeige:** Man sieht nicht wohin die Unit schaut (außer Rotation)
  - **Lösung:** Pfeil oder Kegel-Overlay auf Grid

### Design-Entscheidungen
- **Cover-Check ist simpel:** Aktuell nur Grid-basiert, nicht echter 3D-Raycast
  - **Verbesserung:** Godot's PhysicsRaycast verwenden für präzisere LoS

---

## Offene TODOs 📋

### Sofort (Kritisch für Spielbarkeit)
1. **LoS + FOV kombinieren**
   - Aktuell: FOV prüft nur ob Gegner im Sichtkegel
   - Fehlt: LoS sollte auch Facing-Richtung berücksichtigen
   - **Wo:** `line_of_sight_system.gd` + `combat_component.gd`

2. **Einfache KI implementieren**
   - Gegner bewegt sich automatisch
   - Gegner dreht sich zum Spieler
   - Gegner schießt zurück
   - **Neu:** `ai_component.gd` oder `enemy_ai_system.gd`

3. **Visueller Sichtkegel**
   - Grüner Overlay zeigt FOV auf Grid
   - **Neu:** `fov_visualizer.gd` als Component

### Kurzfristig (Phase 2)
4. **Fog of War**
   - Gegner nur sichtbar wenn in LoS + FOV
   - Dunkel/ausgegraut wenn außerhalb
   - "Letzte bekannte Position" Marker

5. **Inventar-System**
   - Grid-basiert (Tetris-Style)
   - Drag & Drop
   - Container (Weste, Rucksack, Taschen)
   - **Neu:** `inventory_component.gd`, `inventory_ui.tscn`

6. **Magazin-System**
   - Nachladen (kostet AP)
   - Leere Magazine behalten oder wegwerfen
   - Magazine manuell auffüllen nach Kampf
   - **Erweitern:** `combat_component.gd`

7. **Waffen-Modding (Basis)**
   - Einfache Slots (Muzzle, Optic, Stock)
   - Stat-Modifikation
   - **Neu:** `attachment_component.gd`, `attachment_data.gd`

### Mittelfristig (Phase 2+)
8. **Erhöhte Positionen**
   - Multi-Level Grid (Y-Ebenen)
   - Dächer, 2. Etage
   - Höhenvorteil (+Accuracy von oben)

9. **Munitionstypen**
   - FMJ, Hollow Point, Armor Piercing
   - Unterschiedliche Penetration
   - **Erweitern:** `weapon_data.gd`, `combat_component.gd`

10. **Overwatch-Modus**
    - Reserviere AP für Reaktions-Schuss
    - Interrupt wenn Gegner in Sichtfeld bewegt
    - **Neu:** `overwatch_component.gd`

### Langfristig (Phase 3+)
11. **Weltkarte & Kampagne**
    - Strategische Übersicht
    - Sektoren erobern
    - Missionen akzeptieren

12. **Söldner-Rekrutierung**
    - Verschiedene Mercs mit Stats
    - Kosten für Anstellung
    - Moral & Erfahrung

---

## Test-Status

### Was getestet wurde
- ✅ Movement (AP-Kosten, Grid-Grenzen, Blockierung)
- ✅ Combat (Schießen, Zielen, Treffer-Berechnung)
- ✅ Status-Effekte (Arm/Bein zerstört, Blutung)
- ✅ Stance-Wechsel (Capsule-Höhe, AP-Kosten)
- ✅ Rotation (Q/E/R, AP-Kosten, visuelle Drehung)
- ✅ FOV (kann nur schießen wenn Ziel im Sichtkegel)
- ✅ LoS mit Stance (Liegen hinter Cover = weniger sichtbar)
- ✅ Cover (Trefferchance-Reduktion, UI-Anzeige)

### Was NICHT getestet wurde
- ❌ High Cover vollständige Blockierung (sollte 0% Treffer sein, nicht nur -40%)
- ❌ Mehrere Söldner gleichzeitig
- ❌ Gegner-KI
- ❌ Lange Kämpfe (Performance)
- ❌ Speichern/Laden

---

## Performance

### Aktuell
- **Grid:** 10x10 = 100 Tiles, sehr performant
- **Units:** 2 aktive Mercs (Spieler + Gegner)
- **FPS:** Stabil 60 FPS in Tests

### Skalierbarkeit
- **Grid:** Kann auf 50x50+ skalieren ohne Performance-Probleme
- **Units:** Ungetestet mit 10+ Units
- **LoS-Raycasts:** Aktuell simpel, könnte bei vielen Units langsam werden
  - **Lösung:** Spatial Hashing oder Octree für LoS-Checks

---

## Code-Qualität

### Gut ✅
- ERC-Architektur sauber umgesetzt
- Komponenten sind modular und wiederverwendbar
- Datengetriebenes Design (Resources)
- Klare Trennung (Logic vs Data vs Visuals)

### Verbesserungswürdig ⚠️
- **Test-Szenen sind chaotisch:** 4 verschiedene Test-Levels (cover_test, stance_test, status_effect_test, main_test)
  - **Lösung:** Nur main_test behalten, Rest löschen
- **Keine Unit-Tests:** Alles wird manuell getestet
  - **Lösung:** GUT (Godot Unit Testing) einbinden
- **Wenig Kommentare:** Code ist selbsterklärend, aber komplexe Teile (LoS) brauchen Doku

---

## Asset-Status

### Aktuell (Placeholder)
- Capsules für Söldner
- Box-Meshes für Cover
- Einfarbige Materialien

### Benötigt (Für Production)
- 3D-Models: Söldner (rigged, animiert)
- 3D-Models: Waffen (AKM, M16, etc.)
- 3D-Models: Cover-Objekte (Kisten, Sandsäcke, Mauern)
- VFX: Muzzle Flash, Blut-Spritzer, Treffer-Partikel
- Audio: Schüsse, Nachladen, Schritte, UI-Sounds
- UI: Icons für Körperteile, Waffen, Items

---

## Nächster Meilenstein

### Ziel: "Spielbares Demo"
**Was fehlt:**
1. Einfache KI (Gegner schießt zurück)
2. Visueller Sichtkegel (weiß wohin ich schaue)
3. Win/Loss Condition (alle tot = Game Over)
4. Restart-Button

**Geschätzter Aufwand:** 4-6 Stunden Entwicklung

**Danach ist das Projekt:**
- ✅ Spielbar von Anfang bis Ende
- ✅ Zeigbar als Proof of Concept
- ✅ Bereit für Asset-Integration
- ✅ Bereit für weiteres Feature-Development

---

## Setup für weiteren Chat

**Um an diesem Projekt weiterzuarbeiten:**

1. **GitHub Repository:** Lade alle Dateien hoch
2. **In neuem Chat:** Gib Link zum Repo oder poste die 3 Summary-Dateien
3. **Sage:** "Wir arbeiten an Broken Spear weiter, lies PROJECT_SUMMARY.md"
4. **Ich lese mich ein** und wir machen genau da weiter wo wir aufgehört haben

**Wichtige Dateien zum Hochladen:**
- Alle `.gd` Scripts
- Alle `.tscn` Scenes
- Alle `.tres` Resources
- `PROJECT_SUMMARY.md`
- `CURRENT_STATE.md`
- `CODE_CONVENTIONS.md` (kommt als nächstes)

---

**Letzter Stand:** Phase 1.5 abgeschlossen, FOV + LoS funktionieren, bereit für KI-Implementation

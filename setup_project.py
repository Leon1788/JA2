import os

# Verwende das aktuelle Verzeichnis als Basispfad
BASE_PATH = os.getcwd()

# Ordnerstruktur Definition
FOLDER_STRUCTURE = [
    # Scenes
    "scenes",
    "scenes/entities",
    "scenes/levels",
    "scenes/ui",
    
    # Scripts
    "scripts",
    "scripts/components",
    "scripts/systems",
    "scripts/data",
    
    # Resources
    "resources",
    "resources/mercs",
    "resources/weapons",
    "resources/gear",
    "resources/enemies",
    
    # Assets
    "assets",
    "assets/models",
    "assets/textures",
    "assets/audio"
]

def create_project_structure():
    """Erstellt die komplette Ordnerstruktur für das Godot-Projekt"""
    
    print("=" * 60)
    print("BROKEN SPEAR - Project Structure Setup")
    print("=" * 60)
    print()
    
    # Prüfe ob Basispfad existiert
    if not os.path.exists(BASE_PATH):
        print(f"⚠️  WARNUNG: Basispfad existiert nicht: {BASE_PATH}")
        print("Erstelle Basispfad...")
        os.makedirs(BASE_PATH)
        print("✓ Basispfad erstellt")
        print()
    
    created_count = 0
    skipped_count = 0
    
    # Erstelle alle Ordner
    for folder in FOLDER_STRUCTURE:
        full_path = os.path.join(BASE_PATH, folder)
        
        if os.path.exists(full_path):
            print(f"⊘ Übersprungen (existiert bereits): {folder}")
            skipped_count += 1
        else:
            os.makedirs(full_path)
            print(f"✓ Erstellt: {folder}")
            created_count += 1
    
    print()
    print("=" * 60)
    print(f"Setup abgeschlossen!")
    print(f"✓ {created_count} Ordner erstellt")
    print(f"⊘ {skipped_count} Ordner übersprungen (existierten bereits)")
    print("=" * 60)
    print()
    print("Nächster Schritt: Öffne das Projekt in Godot!")
    print(f"Projektpfad: {BASE_PATH}")

if __name__ == "__main__":
    create_project_structure()
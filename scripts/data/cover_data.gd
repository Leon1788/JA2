extends Resource
class_name CoverData

enum CoverType {
	NONE,
	LOW,      # Halbe Deckung (Kiste, niedriger Wall)
	HIGH      # Volle Deckung (Wand, hohe Barrikade)
}

@export var cover_name: String = "Cover Object"
@export var cover_type: CoverType = CoverType.LOW
@export var cover_height: float = 1.0  # Höhe in Metern
@export var hit_chance_penalty: float = 20.0  # LOW = -20%, HIGH = -40%
@export var is_destructible: bool = true
@export var health: int = 100

func blocks_line_of_sight(ray_height: float) -> bool:
	# Blockiert die Sichtlinie wenn Ray unter Cover-Höhe ist
	return ray_height <= cover_height

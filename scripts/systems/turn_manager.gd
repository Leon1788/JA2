extends Node
class_name TurnManager

enum TurnPhase { PLAYER, ENEMY }

signal turn_changed(phase: TurnPhase)
signal turn_started(phase: TurnPhase)
signal turn_ended(phase: TurnPhase)

var current_phase: TurnPhase = TurnPhase.PLAYER
var turn_number: int = 1

var player_units: Array[Merc] = []
var enemy_units: Array[Merc] = []

func register_player_unit(unit: Merc) -> void:
	player_units.append(unit)

func register_enemy_unit(unit: Merc) -> void:
	enemy_units.append(unit)

func start_game() -> void:
	print("\n=== GAME START ===")
	print("Turn ", turn_number)
	start_turn(TurnPhase.PLAYER)

func start_turn(phase: TurnPhase) -> void:
	current_phase = phase
	
	var units = player_units if phase == TurnPhase.PLAYER else enemy_units
	var phase_name = "PLAYER" if phase == TurnPhase.PLAYER else "ENEMY"
	
	print("\n--- ", phase_name, " TURN START ---")
	
	# Reset AP für alle Units dieser Phase
	for unit in units:
		if unit.is_alive():
			unit.start_turn()
			print(unit.merc_data.merc_name, " AP reset to: ", unit.action_point_component.current_ap)
	
	turn_started.emit(phase)

func end_turn() -> void:
	var phase_name = "PLAYER" if current_phase == TurnPhase.PLAYER else "ENEMY"
	print("--- ", phase_name, " TURN END ---")
	
	var units = player_units if current_phase == TurnPhase.PLAYER else enemy_units
	
	for unit in units:
		if unit.is_alive():
			unit.end_turn()
	
	turn_ended.emit(current_phase)
	
	# Switch phase
	if current_phase == TurnPhase.PLAYER:
		start_turn(TurnPhase.ENEMY)
	else:
		turn_number += 1
		print("\n=== TURN ", turn_number, " ===")
		start_turn(TurnPhase.PLAYER)
	
	turn_changed.emit(current_phase)

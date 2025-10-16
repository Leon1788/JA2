extends Node
class_name ActionPointComponent

var max_ap: int = 20
var current_ap: int = 20

func initialize(agility: int) -> void:
	max_ap = 10 + (agility / 10)
	current_ap = max_ap

func spend_ap(amount: int) -> bool:
	if current_ap >= amount:
		current_ap -= amount
		return true
	return false

func has_ap(amount: int) -> bool:
	return current_ap >= amount

func reset_ap() -> void:
	current_ap = max_ap

func get_current_ap() -> int:
	return current_ap

extends RefCounted

const ACTIONS_PER_TURN := 2
const ENERGY_REGEN_PER_TURN := 1

var max_movement: int
var max_energy: int
var energy: int:
	set(value):
		energy = clampi(value, 0, max_energy)
var movement_left := 0
var actions_left := 0
var active := false

var turns_started := 0
var ability_ready_turns: Dictionary[StringName, int] = {}


func _init(movement_allowance: int, starting_energy: int, energy_limit: int) -> void:
	max_movement = maxi(0, movement_allowance)
	max_energy = maxi(0, energy_limit)
	energy = starting_energy


func begin_turn() -> void:
	active = true
	turns_started += 1
	movement_left = max_movement
	actions_left = ACTIONS_PER_TURN
	energy += ENERGY_REGEN_PER_TURN


func end_turn() -> void:
	active = false
	movement_left = 0
	actions_left = 0


func spend_movement(points: int) -> bool:
	if not active or points <= 0 or points > movement_left:
		return false
	movement_left -= points
	return true


func spend_action() -> bool:
	if not active or actions_left == 0:
		return false
	actions_left -= 1
	return true


# Call only after an implemented ability has validated its target and effect.
func spend_active_ability(definition: Dictionary) -> bool:
	if not active or not definition["ability_implemented"] or definition["ability_passive"]:
		return false
	var energy_cost: int = definition["ability_energy"]
	var action_cost: int = definition["ability_actions"]
	if energy_cost < 0 or action_cost < 0 or energy_cost > energy or action_cost > actions_left:
		return false
	var ability_id: StringName = definition["ability_id"]
	if turns_started < ability_ready_turns.get(ability_id, 0):
		return false
	energy -= energy_cost
	actions_left -= action_cost
	var cooldown: int = definition["ability_cooldown"]
	ability_ready_turns[ability_id] = turns_started + maxi(0, cooldown) + 1 if cooldown > 0 else turns_started
	return true

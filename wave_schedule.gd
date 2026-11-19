extends RefCounted

const CONFIG := [
	{"number": 1, "rounds": 4, "base": 3, "per_extra_player": 1, "weights": [85, 10, 5], "boss": false},
	{"number": 2, "rounds": 4, "base": 5, "per_extra_player": 2, "weights": [65, 25, 10], "boss": false},
	{"number": 3, "rounds": 4, "base": 7, "per_extra_player": 3, "weights": [50, 30, 20], "boss": false},
	{"number": 4, "rounds": 4, "base": 9, "per_extra_player": 4, "weights": [35, 35, 30], "boss": false},
	{"number": 5, "rounds": 4, "base": 12, "per_extra_player": 5, "weights": [20, 35, 45], "boss": true},
]
const ORDINARY_TYPES := ["Grunt", "Runner", "Brute"]
const BOSS_TYPE := "Boss"

class Spawn:
	var wave: int
	var due_turn: int
	var kind: String

var rng := RandomNumberGenerator.new()
var pending: Array[Spawn] = []
var first_turns: Dictionary[int, int] = {}
var current_wave := 1
var wave_round := 1
var completed_turns := 0
var round_override := 0


func reset(players: int, seed_value: int, start_wave: int = 1) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	current_wave = clampi(start_wave, 1, CONFIG.size())
	wave_round = 1
	completed_turns = 0
	pending.clear()
	first_turns.clear()
	var first_turn := 1
	for number in range(current_wave, CONFIG.size() + 1):
		first_turns[number] = first_turn
		var data: Dictionary = CONFIG[number - 1]
		var rounds := duration(number)
		var count := ordinary_count(number, players)
		@warning_ignore("integer_division")
		var per_round := count / rounds
		for offset in range(rounds):
			if offset == 0 and data.boss:
				queue_spawn(number, first_turn, BOSS_TYPE)
			var batch := per_round + (1 if offset < count % rounds else 0)
			for _index in range(batch):
				queue_spawn(number, first_turn + offset, roll_kind(number))
		first_turn += rounds


func duration(number: int) -> int:
	return round_override if round_override > 0 else maxi(1, CONFIG[number - 1].rounds)


func ordinary_count(number: int, players: int) -> int:
	var data: Dictionary = CONFIG[number - 1]
	return maxi(0, data.base + maxi(0, players - 1) * data.per_extra_player)


func roll_kind(number: int) -> String:
	var weights: Array = CONFIG[number - 1].weights
	var total := 0
	for weight: int in weights:
		total += maxi(0, weight)
	if total == 0:
		return ORDINARY_TYPES[0]
	var roll := rng.randi_range(1, total)
	for index in range(weights.size()):
		roll -= maxi(0, weights[index])
		if roll <= 0:
			return ORDINARY_TYPES[index]
	return ORDINARY_TYPES[0]


func queue_spawn(number: int, turn: int, kind: String) -> void:
	var entry := Spawn.new()
	entry.wave = number
	entry.due_turn = turn
	entry.kind = kind
	pending.append(entry)


func due_spawns() -> Array[Spawn]:
	var due: Array[Spawn] = []
	for entry in pending:
		if entry.due_turn <= completed_turns + 1:
			due.append(entry)
	return due


func add_reinforcements(amount: int) -> bool:
	for number in range(current_wave, CONFIG.size() + 1):
		if first_turns[number] > completed_turns:
			for _extra in range(amount):
				queue_spawn(number, first_turns[number], ORDINARY_TYPES[0])
			return true
	return false


func remaining_spawns(number: int) -> int:
	var remaining := 0
	for entry in pending:
		if entry.wave == number:
			remaining += 1
	return remaining


func complete_turn() -> bool:
	completed_turns += 1
	if current_wave < CONFIG.size() and wave_round == duration(current_wave):
		current_wave += 1
		wave_round = 1
		return true
	wave_round += 1
	return false


func rounds_until_next_wave() -> int:
	return duration(current_wave) - wave_round + 1 if current_wave < CONFIG.size() else 0

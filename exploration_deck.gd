extends RefCounted

const HAND_LIMIT := 3
const DEFINITIONS := {
	&"tar_pit": {"name": "Tar Pit", "description": "Stop one monster from moving on its next Enemy Turn.", "positive": true, "held": true, "copies": 4, "effect": &"freeze", "amount": 1, "target": &"enemy"},
	&"burst": {"name": "Burst Movement", "description": "Double your remaining movement this turn.", "positive": true, "held": true, "copies": 4, "effect": &"burst", "amount": 2, "target": &""},
	&"lane_dash": {"name": "Lane Dash", "description": "Dash to an empty revealed road space in your current lane.", "positive": true, "held": true, "copies": 4, "effect": &"dash", "amount": 0, "target": &"space"},
	&"build_tower": {"name": "Build Extra Tower", "description": "Place a temporary tower on an eligible tile.", "positive": true, "held": true, "copies": 0, "effect": &"build_tower", "amount": 0, "target": &"tile"},
	&"empower_tower": {"name": "Empower Tower", "description": "Allow a tower to attack two different targets in its next firing phase.", "positive": true, "held": true, "copies": 0, "effect": &"empower_tower", "amount": 2, "target": &"tower"},
	&"super_shot": {"name": "Super Shot", "description": "Double a tower's next attack against one enemy.", "positive": true, "held": true, "copies": 0, "effect": &"super_shot", "amount": 2, "target": &"tower"},
	&"tile_swap": {"name": "Tile Swap", "description": "Swap two compatible unoccupied tiles while keeping roads connected.", "positive": true, "held": true, "copies": 0, "effect": &"tile_swap", "amount": 0, "target": &"tiles"},
	&"cache": {"name": "Supply Cache", "description": "Draw another exploration card.", "positive": true, "held": false, "copies": 1, "effect": &"draw", "amount": 1},
	&"energy": {"name": "Energy Discovery", "description": "Restore up to 2 Energy.", "positive": true, "held": false, "copies": 2, "effect": &"energy", "amount": 2},
	&"repairs": {"name": "Fortress Repairs", "description": "Restore up to 2 fortress HP.", "positive": true, "held": false, "copies": 1, "effect": &"repair", "amount": 2},
	&"lucky": {"name": "Lucky Find", "description": "Gain one additional reveal this turn. Placement still costs an action.", "positive": true, "held": false, "copies": 1, "effect": &"reveal", "amount": 1},
	&"reinforced": {"name": "Reinforced Defenses", "description": "Prevent the next 2 points of fortress damage.", "positive": true, "held": false, "copies": 1, "effect": &"shield", "amount": 2},
	&"ambush": {"name": "Monster Ambush", "description": "Spawn a Grunt on a random lane.", "positive": false, "held": false, "copies": 2, "effect": &"ambush", "amount": 1},
	&"structural": {"name": "Structural Damage", "description": "Take 2 fortress damage, reduced by protection.", "positive": false, "held": false, "copies": 1, "effect": &"damage", "amount": 2},
	&"broken": {"name": "Broken Supplies", "description": "Discard one randomly selected card from your hand.", "positive": false, "held": false, "copies": 1, "effect": &"discard", "amount": 1},
	&"reinforcements": {"name": "Reinforcements", "description": "Add a Grunt to the next wave that has not spawned.", "positive": false, "held": false, "copies": 1, "effect": &"reinforce", "amount": 1},
	&"exhaustion": {"name": "Exhaustion", "description": "Lose 2 movement at the beginning of your next turn.", "positive": false, "held": false, "copies": 1, "effect": &"exhaust", "amount": 2},
}

var deck: Array[StringName] = []
var discard: Array[StringName] = []
var rng := RandomNumberGenerator.new()


func reset(deck_seed: int = 0) -> void:
	if deck_seed == 0:
		rng.randomize()
	else:
		rng.seed = deck_seed
	deck.clear()
	discard.clear()
	for id: StringName in DEFINITIONS:
		for _copy in range(DEFINITIONS[id].copies):
			deck.append(id)
	shuffle_deck()


func shuffle_deck() -> void:
	for index in range(deck.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var value := deck[index]
		deck[index] = deck[other]
		deck[other] = value


func draw_card() -> StringName:
	if deck.is_empty():
		deck.assign(discard)
		discard.clear()
		shuffle_deck()
	return &"" if deck.is_empty() else deck.pop_back()


static func description(id: StringName) -> String:
	var card: Dictionary = DEFINITIONS[id]
	return "%s · %s · %s\n%s" % [card.name, "Reward" if card.positive else "Risk", "Held" if card.held else "Immediate", card.description]

extends RefCounted

const DEFINITIONS := {
	&"road": {"name": "Normal Road", "description": "Ordinary road. Eligible for tower construction.", "spaces": [1, 2, 3, 4], "shapes": [0, 1, 2, 3], "tower_allowed": true, "effect": &"", "parameters": {}, "card_reward": false, "color": Color("#92724f")},
	&"water_bridge": {"name": "Water Bridge", "description": "Cross the water at normal cost. Towers cannot be built here.", "spaces": [2, 3], "shapes": [0], "tower_allowed": false, "effect": &"", "parameters": {}, "card_reward": false, "color": Color("#2c718d")},
	&"lava_bridge": {"name": "Lava Bridge", "description": "Cross the lava at normal cost. Towers cannot be built here.", "spaces": [2, 3], "shapes": [0], "tower_allowed": false, "effect": &"", "parameters": {}, "card_reward": false, "color": Color("#ba4826")},
	&"exploding": {"name": "Exploding Tile", "description": "The second enemy to enter triggers a one-use trap.", "spaces": [2, 3], "shapes": [0, 1], "tower_allowed": false, "effect": &"explosion", "parameters": {"threshold": 2, "damage": 0}, "card_reward": false, "color": Color("#a95f46")},
	&"fork": {"name": "Fork of Fate", "description": "Enemies roll between viable branches of different lengths.", "spaces": [4], "shapes": [2], "tower_allowed": true, "effect": &"fork", "parameters": {"first_branch_probability": 0.5}, "card_reward": false, "color": Color("#776099")},
	&"damaged": {"name": "Damaged Road", "description": "The revealing hero loses 1 remaining movement point.", "spaces": [1, 2], "shapes": [0, 1], "tower_allowed": true, "effect": &"movement_loss", "parameters": {"amount": 1}, "card_reward": false, "color": Color("#685c55")},
	&"supply": {"name": "Supply Road", "description": "Restore 1 Energy. Eligible for an exploration card in Stage 5.", "spaces": [2, 3], "shapes": [0, 1], "tower_allowed": true, "effect": &"energy_gain", "parameters": {"amount": 1}, "card_reward": true, "color": Color("#527747")},
}

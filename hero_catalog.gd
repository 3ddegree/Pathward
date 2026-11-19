extends RefCounted

const DEFINITIONS := [
	{"id": &"warden", "name": "Warden", "role": "Fortress protection",
		"description": "Protects the fortress and fights at close range.",
		"movement": 4, "attack_damage": 1, "attack_range": 1,
		"health": 5, "starting_energy": 3, "max_energy": 5, "color": Color("#4de1d1"),
		"ability_id": &"last_stand", "ability_name": "Last Stand", "ability_energy": 2,
		"ability_implemented": true, "ability_passive": true, "ability_actions": 0, "ability_cooldown": 0,
		"ability_description": "Prevent one fortress breach or a configurable amount of fortress damage.",
		"ability_status": "Active: blocks one breach per wave while stationed at the fortress."},
	{"id": &"scout", "name": "Scout", "role": "Exploration and mobility",
		"description": "A mobile ranged hero who specializes in exploring roads.",
		"movement": 6, "attack_damage": 1, "attack_range": 3,
		"health": 4, "starting_energy": 3, "max_energy": 5, "color": Color("#a8ef85"),
		"ability_id": &"advanced_exploration", "ability_name": "Advanced Exploration", "ability_energy": 2,
		"ability_implemented": false, "ability_passive": false, "ability_actions": 0, "ability_cooldown": 0,
		"ability_description": "Spend Energy to reveal additional road tiles during a turn.",
		"ability_status": "Planned"},
	{"id": &"healer", "name": "Healer", "role": "Restoration and support",
		"description": "Supports the party and tends to damaged defenses.",
		"movement": 4, "attack_damage": 1, "attack_range": 1,
		"health": 4, "starting_energy": 3, "max_energy": 5, "color": Color("#efd782"),
		"ability_id": &"restoration", "ability_name": "Restoration", "ability_energy": 2,
		"ability_implemented": false, "ability_passive": false, "ability_actions": 1, "ability_cooldown": 0,
		"ability_description": "Spend Energy to restore health to heroes, the fortress, or repairable traps.",
		"ability_status": "Planned"},
	{"id": &"striker", "name": "Striker", "role": "Direct combat",
		"description": "Deals the most damage with a basic attack.",
		"movement": 4, "attack_damage": 2, "attack_range": 1,
		"health": 5, "starting_energy": 3, "max_energy": 5, "color": Color("#ff806a"),
		"ability_id": &"power_strike", "ability_name": "Power Strike", "ability_energy": 2,
		"ability_implemented": false, "ability_passive": false, "ability_actions": 0, "ability_cooldown": 0,
		"ability_description": "Spend Energy to increase damage dealt by an attack.",
		"ability_status": "Planned"},
	{"id": &"engineer", "name": "Engineer", "role": "Tower construction and upgrades",
		"description": "Specializes in building and improving defenses.",
		"movement": 4, "attack_damage": 1, "attack_range": 1,
		"health": 5, "starting_energy": 3, "max_energy": 5, "color": Color("#86b8ff"),
		"ability_id": &"tower_engineering", "ability_name": "Tower Engineering", "ability_energy": 3,
		"ability_implemented": false, "ability_passive": false, "ability_actions": 1, "ability_cooldown": 0,
		"ability_description": "Spend Energy to construct or upgrade defensive towers.",
		"ability_status": "Planned"},
	{"id": &"architect", "name": "Architect", "role": "Tile and road manipulation",
		"description": "Specializes in reshaping connected roads.",
		"movement": 4, "attack_damage": 1, "attack_range": 1,
		"health": 4, "starting_energy": 3, "max_energy": 5, "color": Color("#d8a2ed"),
		"ability_id": &"tile_manipulation", "ability_name": "Tile Manipulation", "ability_energy": 2,
		"ability_implemented": false, "ability_passive": false, "ability_actions": 1, "ability_cooldown": 0,
		"ability_description": "Spend Energy to swap compatible, unoccupied road tiles while maintaining valid connections.",
		"ability_status": "Planned"},
]


static func summary(index: int) -> String:
	var hero: Dictionary = DEFINITIONS[index]
	var stats := "%s · Base movement %d · Attack %d damage · Range %d" % [
		hero.role, hero.movement, hero.attack_damage, hero.attack_range,
	]
	return "%s\n%s — %s (proposed cost: %d Energy)\n%s" % [
		stats, hero.ability_name, hero.ability_description, hero.ability_energy, hero.ability_status,
	]

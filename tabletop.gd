extends Node3D

const RoadNetwork := preload("res://road_network.gd")
const TerrainCatalog := preload("res://terrain_catalog.gd")
const LANE_NAMES := ["1 North", "2 East", "3 South", "4 West"]
const TILE_PORTS := [[0, 2], [0, 1], [0, 1, 3], [0, 1, 2, 3]]
const TILE_NAMES := ["Straight", "Curve", "T-junction", "Four-way crossing"]
const MAX_INTEGRITY := 5
const FORTRESS := 0
const START_VIEW := Vector3(0.38, 0.87, 23.0)
const HeroCatalog := preload("res://hero_catalog.gd")
const HeroTurn := preload("res://hero_turn.gd")
const MAX_PLAYERS := 5
const ENEMY_TYPES := {
	"Grunt": {"stride": 1, "breach_damage": 1, "attack_damage": 1, "health": 1, "color": Color("#ff865e")},
	"Runner": {"stride": 2, "breach_damage": 1, "attack_damage": 1, "health": 1, "color": Color("#f4ce63")},
	"Brute": {"stride": 1, "breach_damage": 2, "attack_damage": 1, "health": 2, "color": Color("#f46ea5")},
	"Boss": {"stride": 1, "breach_damage": 2, "attack_damage": 1, "health": 3, "color": Color("#be8cff"), "remove_on_breach": true},
}
const WAVE_PLANS := [
	[
		["Grunt", "Grunt"],
		["Grunt", "Runner", "Brute"],
		["Grunt", "Runner", "Brute", "Boss"],
	],
	[
		["Grunt", "Grunt", "Grunt"],
		["Grunt", "Grunt", "Runner", "Brute"],
		["Grunt", "Grunt", "Runner", "Brute", "Brute"],
		["Grunt", "Grunt", "Runner", "Brute", "Brute", "Boss"],
	],
]

enum Phase { TITLE, SETUP, PLAYER, ENEMY, COMPLETE }

class Hero:
	var id: StringName
	var attack_damage: int
	var title: String
	var budget: HeroTurn
	var max_health: int
	var health: int
	var location: int
	var attack_range: int
	var piece: Node3D
	var health_label: Label3D
	var figure: Node3D
	var damage_indicator: Label3D
	var damage_feedback: Tween
	var damage_this_turn := 0
	var base: MeshInstance3D

class Enemy:
	var location: int
	var visited: Dictionary = {}
	var title: String
	var stride: int
	var breach_damage: int
	var attack_damage: int
	var remove_on_breach: bool
	var blocked_destination := -1
	var attack_animation: Tween
	var health: int
	var max_health: int
	var health_label: Label3D
	var piece: Node3D
	var target_marker: MeshInstance3D

var network := RoadNetwork.new()
var markers: Array[MeshInstance3D] = []
var enemies: Array[Enemy] = []
var legal_moves: Dictionary[int, int] = {}
var attack_targets: Array[Enemy] = []
var aiming := false
var reveal_markers: Dictionary = {}
var placement_target := Vector2i.ZERO
var drawn_tile := -1
var drawn_terrain: StringName
var drawn_spaces := 0
var exploration_cells: Array[Vector2i] = []
var trap_labels: Dictionary[Vector2i, Label3D] = {}
var rotation_steps := 0
var preview: Node3D
var wave_waiting := true
var dice_result := ""
var fork_rolls: Array[String] = []
var round_number := 1
var phase := Phase.TITLE
var active_player := 0
var wave := 0
var wave_plan: Array = []
var integrity := MAX_INTEGRITY
var heroes: Array[Hero] = []
var warden_defended := false
var fortress_marker: MeshInstance3D
var fortress_health: Label3D
var camera: Camera3D
var orbit := START_VIEW
var health_status: Label
var turn_status: Label
var dice_status: Label
var tile_card: PanelContainer
var drawn_tile_label: Label
var terrain_description: Label
var reveal_button: Button
var endpoint_material: StandardMaterial3D
var tile_diagram: Control
var rotate_button: Button
var place_button: Button
var phase_button: Button
var attack_button: Button
var attack_material: StandardMaterial3D
var setup_controls: VBoxContainer
var roster_picker: OptionButton
var hero_details: Label
var player_count: OptionButton
var character_pickers: Array[OptionButton] = []
var status: Label
var instructions: Label
var active_material: StandardMaterial3D
var idle_material: StandardMaterial3D


func _ready() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 47
	reset_view()
	camera.make_current()

	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#151d26")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#d7e3f3")
	world.environment.ambient_light_energy = 0.65
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-57, -31, 0)
	sun.shadow_enabled = true
	add_child(sun)

	block(Vector3(0, -0.28, 0), Vector3(20, 0.4, 20), Color("#38534c"))
	block(Vector3(0, 0.22, 0), Vector3(1.85, 0.6, 1.85), Color("#8b9aab"))
	for x: float in [-0.75, 0.75]:
		for z: float in [-0.75, 0.75]:
			block(Vector3(x, 0.58, z), Vector3(0.38, 1.3, 0.38), Color("#b9c5ce"))
			block(Vector3(x, 1.22, z), Vector3(0.49, 0.17, 0.49), Color("#d9e4eb"))
	block(Vector3(0, 0.28, 0.94), Vector3(0.52, 0.49, 0.12), Color("#514139"))

	active_material = make_material(Color("#77ffe0"), true)
	idle_material = make_material(Color("#f0d6a7"))
	attack_material = make_material(Color("#ff9b66"), true)
	endpoint_material = make_material(Color("#ffd16c"), true)
	fortress_marker = block(network.positions[FORTRESS], Vector3(0.38, 0.07, 0.38), idle_material.albedo_color)
	markers.append(fortress_marker)
	build_fortress_health()
	for lane in range(4):
		var cell: Vector2i = RoadNetwork.DIRECTIONS[lane]
		var ports: Array[int] = [network.opposite(lane), lane]
		lay_tile(cell, ports, lane + 1)
		add_lane_label(lane, cell)
	build_controls()
	refresh("")


func build_fortress_health() -> void:
	fortress_health = Label3D.new()
	fortress_health.position = Vector3.UP * 1.92
	fortress_health.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fortress_health.pixel_size = 0.006
	fortress_health.font_size = 50
	fortress_health.outline_size = 12
	add_child(fortress_health)


func make_material(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = glow
	material.emission = color
	return material


func block(at: Vector3, dimensions: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = dimensions
	var piece := MeshInstance3D.new()
	piece.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	piece.material_override = material
	if parent == null:
		parent = self
	parent.add_child(piece)
	piece.position = at
	return piece


func miniature(title: String, color: Color) -> Node3D:
	var piece := Node3D.new()
	add_child(piece)
	var armor := color.darkened(0.32)
	var boots := Color("#29333e")
	var face := Color("#cba185")
	block(Vector3(-0.09, 0.13, 0), Vector3(0.11, 0.22, 0.15), boots, piece)
	block(Vector3(0.09, 0.13, 0), Vector3(0.11, 0.22, 0.15), boots, piece)
	block(Vector3(0, 0.38, 0), Vector3(0.32, 0.32, 0.23), armor, piece)
	block(Vector3(-0.20, 0.36, 0), Vector3(0.09, 0.25, 0.12), color, piece)
	block(Vector3(0.20, 0.36, 0), Vector3(0.09, 0.25, 0.12), color, piece)
	block(Vector3(0, 0.62, 0), Vector3(0.20, 0.20, 0.18), face, piece)
	block(Vector3(0, 0.71, -0.015), Vector3(0.23, 0.09, 0.23), color, piece)

	match title:
		"Warden":
			block(Vector3(-0.22, 0.35, 0.12), Vector3(0.26, 0.36, 0.06), color, piece)
			block(Vector3(-0.22, 0.35, 0.16), Vector3(0.09, 0.18, 0.025), Color("#e0e8ed"), piece)
		"Scout":
			block(Vector3(0, 0.54, 0), Vector3(0.24, 0.08, 0.26), color, piece)
			var cape := block(Vector3(0, 0.35, -0.16), Vector3(0.26, 0.37, 0.045), color, piece)
			cape.rotation_degrees.x = 19
		"Grunt":
			block(Vector3(0, 0.45, 0.13), Vector3(0.22, 0.17, 0.04), color, piece)
		"Runner":
			piece.scale = Vector3(0.83, 0.88, 0.83)
			block(Vector3(0, 0.57, -0.16), Vector3(0.13, 0.08, 0.22), color, piece)
		"Brute":
			piece.scale = Vector3(1.26, 1.21, 1.26)
			block(Vector3(-0.20, 0.48, 0), Vector3(0.17, 0.15, 0.20), color, piece)
			block(Vector3(0.20, 0.48, 0), Vector3(0.17, 0.15, 0.20), color, piece)
		"Boss":
			piece.scale = Vector3(1.46, 1.42, 1.46)
			block(Vector3(0, 0.78, 0), Vector3(0.28, 0.10, 0.24), color, piece)
			block(Vector3(-0.12, 0.86, 0), Vector3(0.06, 0.14, 0.19), color, piece)
			block(Vector3(0.12, 0.86, 0), Vector3(0.06, 0.14, 0.19), color, piece)
	return piece


func build_heroes() -> void:
	for index in range(player_count.selected + 1):
		var entry: Dictionary = HeroCatalog.DEFINITIONS[character_pickers[index].selected]
		var hero := Hero.new()
		hero.id = entry["id"]
		hero.title = entry["name"]
		hero.budget = HeroTurn.new(entry["movement"], entry["starting_energy"], entry["max_energy"])
		hero.attack_damage = entry["attack_damage"]
		hero.attack_range = entry["attack_range"]
		hero.max_health = entry["health"]
		hero.health = hero.max_health
		hero.location = FORTRESS
		hero.piece = Node3D.new()
		add_child(hero.piece)
		hero.figure = miniature(hero.title, entry["color"])
		hero.figure.reparent(hero.piece, false)
		hero.base = block(Vector3(0, 0.02, 0), Vector3(0.38, 0.04, 0.38), entry["color"], hero.piece)
		hero.health_label = Label3D.new()
		hero.health_label.position = Vector3.UP * 0.91
		hero.health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hero.health_label.pixel_size = 0.004
		hero.health_label.font_size = 44
		hero.health_label.outline_size = 12
		hero.piece.add_child(hero.health_label)
		hero.damage_indicator = Label3D.new()
		hero.damage_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hero.damage_indicator.font_size = 52
		hero.damage_indicator.pixel_size = 0.005
		hero.damage_indicator.outline_size = 12
		hero.damage_indicator.modulate = Color("#ff826d")
		hero.damage_indicator.hide()
		hero.piece.add_child(hero.damage_indicator)
		heroes.append(hero)


func draw_tile(parent: Node3D, cell: Vector2i, ports: Array[int], terrain: Dictionary) -> void:
	var center := network.center(cell)
	var tint: Color = terrain.color
	block(center, Vector3(1.96, 0.13, 1.96), tint, parent)
	var road_color := tint.lightened(0.26)
	if terrain.name.ends_with("Bridge"):
		var axis := network.port(cell, ports[0]) - center
		var side := Vector3(-axis.z, 0, axis.x) * 0.33
		for offset: Vector3 in [side, -side]:
			var rail := block(center + offset + Vector3.UP * 0.13, Vector3(0.08, 0.16, 1.94), Color("#c6a478"), parent)
			rail.rotation.y = atan2(axis.x, axis.z)
		road_color = Color("#b18d5b")
	if ports.size() == 2:
		var previous := network.road_point(cell, ports, 0.0)
		for segment in range(1, 13):
			var next := network.road_point(cell, ports, segment / 12.0)
			draw_road_segment(parent, previous, next, road_color)
			previous = next
	else:
		for direction in ports:
			draw_road_segment(parent, center, network.port(cell, direction), road_color)


func draw_road_segment(parent: Node3D, start: Vector3, finish: Vector3, color: Color) -> void:
	var difference := finish - start
	var position := (start + finish) * 0.5 + Vector3.UP * 0.078
	var piece := block(position, Vector3(0.45, 0.028, difference.length() + 0.12), color, parent)
	piece.rotation.y = atan2(difference.x, difference.z)


func lay_tile(cell: Vector2i, ports: Array[int], count: int, terrain_id: StringName = &"road") -> bool:
	var nodes := network.add_tile(cell, ports, count, terrain_id)
	if nodes.is_empty():
		return false
	var terrain: Dictionary = TerrainCatalog.DEFINITIONS[terrain_id]
	draw_tile(self, cell, ports, terrain)
	for id in nodes:
		markers.append(block(network.positions[id], Vector3(0.32, 0.045, 0.32), idle_material.albedo_color))
	if terrain.effect == &"explosion":
		var label := Label3D.new()
		label.position = network.center(cell) + Vector3.UP * 0.49
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.004
		label.font_size = 32
		label.outline_size = 12
		label.text = "Trap armed"
		add_child(label)
		trap_labels[cell] = label
	return true


func add_lane_label(lane: int, cell: Vector2i) -> void:
	var label := Label3D.new()
	label.text = LANE_NAMES[lane]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.005
	label.font_size = 36
	label.outline_size = 10
	add_child(label)
	var ground := network.center(cell)
	label.position = ground + Vector3(-ground.z, 0, ground.x).normalized() * 0.76 + Vector3.UP * 0.16


func build_controls() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var heading := Label.new()
	heading.position = Vector2(22, 14)
	heading.text = "Pathward: Roads to Ruin"
	heading.add_theme_font_size_override("font_size", 29)
	overlay.add_child(heading)
	var camera_hint := Label.new()
	camera_hint.position = Vector2(23, 51)
	camera_hint.text = "Right-drag to orbit  ·  Scroll to zoom"
	overlay.add_child(camera_hint)

	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = -130
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -14
	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(rows)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(controls)
	place_button = action(controls, "Place tile", place_tile)
	rotate_button = action(controls, "Rotate", rotate_tile)
	reveal_button = action(controls, "Reveal tile", toggle_reveal)
	attack_button = action(controls, "Attack", toggle_attack)
	phase_button = action(controls, "Start game", advance_phase)
	action(controls, "Reset view", reset_view)
	action(controls, "Restart", restart)

	health_status = centered_label(rows)
	turn_status = centered_label(rows)
	dice_status = centered_label(rows)
	status = centered_label(rows)
	instructions = centered_label(rows)

	build_setup_controls(rows)

	tile_card = PanelContainer.new()
	tile_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(tile_card)
	tile_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tile_card.offset_left = -166
	tile_card.offset_right = -16
	tile_card.offset_top = 82
	tile_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var card_content := VBoxContainer.new()
	card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_card.add_child(card_content)
	drawn_tile_label = centered_label(card_content)
	drawn_tile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain_description = centered_label(card_content)
	terrain_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_diagram = Control.new()
	tile_diagram.custom_minimum_size = Vector2(108, 108)
	tile_diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile_diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_diagram.draw.connect(draw_tile_diagram)
	card_content.add_child(tile_diagram)


func build_setup_controls(parent: VBoxContainer) -> void:
	setup_controls = VBoxContainer.new()
	parent.add_child(setup_controls)
	var roster_controls := HBoxContainer.new()
	roster_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	setup_controls.add_child(roster_controls)
	player_count = OptionButton.new()
	player_count.add_item("1 player")
	for count in range(2, MAX_PLAYERS + 1):
		player_count.add_item("%d players" % count)
	player_count.select(1)
	player_count.item_selected.connect(update_player_count)
	roster_controls.add_child(player_count)

	var roster_label := Label.new()
	roster_label.text = "Hero reference"
	roster_controls.add_child(roster_label)
	roster_picker = OptionButton.new()
	for entry: Dictionary in HeroCatalog.DEFINITIONS:
		roster_picker.add_item(entry["name"])
	roster_picker.item_selected.connect(show_hero_details)
	roster_controls.add_child(roster_picker)
	hero_details = centered_label(setup_controls)
	hero_details.add_theme_constant_override("line_spacing", 4)

	var assignments := HFlowContainer.new()
	assignments.alignment = FlowContainer.ALIGNMENT_CENTER
	setup_controls.add_child(assignments)
	for index in range(MAX_PLAYERS):
		var picker := OptionButton.new()
		for hero_index in range(HeroCatalog.DEFINITIONS.size()):
			var entry: Dictionary = HeroCatalog.DEFINITIONS[hero_index]
			picker.add_item("P%d  %s" % [index + 1, entry["name"]])
			picker.get_popup().set_item_tooltip(hero_index, HeroCatalog.summary(hero_index))
		picker.select(index)
		picker.item_selected.connect(select_character)
		character_pickers.append(picker)
		assignments.add_child(picker)
	update_player_count(player_count.selected)
	show_hero_details(0)


func centered_label(parent: BoxContainer) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func action(parent: HBoxContainer, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func restart() -> void:
	get_tree().reload_current_scene.call_deferred()


func update_player_count(index: int) -> void:
	var assigned: Array[int] = []
	for player in range(character_pickers.size()):
		var picker := character_pickers[player]
		picker.visible = player <= index
		if not picker.visible:
			continue
		if picker.selected in assigned:
			for hero_index in range(HeroCatalog.DEFINITIONS.size()):
				if hero_index not in assigned:
					picker.select(hero_index)
					break
		assigned.append(picker.selected)
	for player in range(index + 1):
		var picker := character_pickers[player]
		for hero_index in range(HeroCatalog.DEFINITIONS.size()):
			picker.set_item_disabled(hero_index, hero_index != picker.selected and hero_index in assigned)


func show_hero_details(index: int) -> void:
	roster_picker.select(index)
	hero_details.text = HeroCatalog.summary(index)


func select_character(character_index: int) -> void:
	update_player_count(player_count.selected)
	show_hero_details(character_index)


func advance_phase() -> void:
	match phase:
		Phase.TITLE:
			phase = Phase.SETUP
			refresh("")
		Phase.SETUP:
			update_player_count(player_count.selected)
			build_heroes()
			wave_plan = WAVE_PLANS[mini(heroes.size(), WAVE_PLANS.size()) - 1]
			begin_player_turn(0, "")
		Phase.PLAYER:
			begin_player_turn(active_player + 1, "")
		Phase.ENEMY:
			if wave_waiting:
				roll_wave()
				begin_next_round("Enemies entered their rolled lanes.")
			else:
				resolve_enemies()


func begin_player_turn(index: int, message: String) -> void:
	if phase == Phase.PLAYER:
		heroes[active_player].budget.end_turn()
	aiming = false
	drawn_tile = -1
	placement_target = Vector2i.ZERO
	while index < heroes.size() and heroes[index].health == 0:
		index += 1
	active_player = index
	phase = Phase.PLAYER if index < heroes.size() else Phase.ENEMY
	if phase == Phase.PLAYER:
		heroes[active_player].budget.begin_turn()
	refresh(message)


func begin_next_round(message: String) -> void:
	round_number += 1
	begin_player_turn(0, message)


func can_reveal() -> bool:
	if phase != Phase.PLAYER:
		return false
	var hero := heroes[active_player]
	return hero.health > 0 and hero.budget.actions_left > 0 and hero.budget.reveals_left > 0


func reveal_options() -> Dictionary:
	var options := {}
	if not can_reveal():
		return options
	for cell in network.expansion_cells(heroes[active_player].location):
		for kind in range(TILE_PORTS.size()):
			if not fitting_rotations(cell, kind).is_empty():
				if not options.has(kind):
					options[kind] = []
				options[kind].append(cell)
	return options


func toggle_reveal() -> void:
	if drawn_tile >= 0:
		drawn_tile = -1
		placement_target = Vector2i.ZERO
		refresh("Placement canceled.")
		return
	var options := reveal_options()
	if options.is_empty():
		return
	var terrains: Array[StringName] = []
	for id: StringName in TerrainCatalog.DEFINITIONS:
		var terrain: Dictionary = TerrainCatalog.DEFINITIONS[id]
		if terrain.shapes.any(func(shape: int) -> bool: return options.has(shape)):
			terrains.append(id)
	drawn_terrain = terrains.pick_random()
	var definition: Dictionary = TerrainCatalog.DEFINITIONS[drawn_terrain]
	var shapes: Array = definition.shapes.filter(func(shape: int) -> bool: return options.has(shape))
	drawn_tile = shapes.pick_random()
	drawn_spaces = definition.spaces.pick_random()
	rotation_steps = 0
	aiming = false
	refresh("")


func rotate_tile() -> void:
	if not tile_fits():
		return
	var rotations := fitting_rotations(placement_target, drawn_tile)
	rotation_steps = rotations[(rotations.find(rotation_steps) + 1) % rotations.size()]
	refresh("")


func oriented_ports(kind: int, rotation: int) -> Array[int]:
	var ports: Array[int] = []
	for direction: int in TILE_PORTS[kind]:
		ports.append((direction + rotation) % 4)
	return ports


func tile_fits() -> bool:
	return drawn_tile >= 0 and placement_target in exploration_cells and network.fitting_lane(
		placement_target, oriented_ports(drawn_tile, rotation_steps)
	) >= 0


func fitting_rotations(cell: Vector2i, kind: int) -> Array[int]:
	var rotations: Array[int] = []
	var orientations := [2, 4, 4, 1]
	for rotation in range(orientations[kind]):
		if network.fitting_lane(cell, oriented_ports(kind, rotation)) >= 0:
			rotations.append(rotation)
	return rotations


func select_tile_location(cell: Vector2i) -> void:
	if not can_reveal() or drawn_tile < 0 or cell not in exploration_cells:
		return
	var rotations := fitting_rotations(cell, drawn_tile)
	if rotations.is_empty():
		return
	placement_target = cell
	rotation_steps = rotations[0]
	refresh("")


func draw_tile_diagram() -> void:
	if drawn_tile < 0:
		return
	var center := tile_diagram.size * 0.5
	tile_diagram.draw_rect(Rect2(Vector2.ZERO, tile_diagram.size), TerrainCatalog.DEFINITIONS[drawn_terrain].color)
	var road := Color("#e8c99a")
	var ports := oriented_ports(drawn_tile, rotation_steps)
	if drawn_tile == 1:
		var first: Vector2i = RoadNetwork.DIRECTIONS[ports[0]]
		var last: Vector2i = RoadNetwork.DIRECTIONS[ports[1]]
		var start := center + Vector2(first) * center
		var finish := center + Vector2(last) * center
		var curve := PackedVector2Array()
		for step in range(13):
			var progress := step / 12.0
			curve.append(start.lerp(center, progress).lerp(center.lerp(finish, progress), progress))
		tile_diagram.draw_polyline(curve, road, 17.0, true)
		return
	for direction in ports:
		var port: Vector2i = RoadNetwork.DIRECTIONS[direction]
		var end := center + Vector2(port) * center
		tile_diagram.draw_line(center, end, road, 17.0, true)
	tile_diagram.draw_circle(center, 8.5, road)


func place_tile() -> void:
	if not can_reveal() or not tile_fits():
		return
	var ports := oriented_ports(drawn_tile, rotation_steps)
	if not lay_tile(placement_target, ports, drawn_spaces, drawn_terrain):
		return
	var hero := heroes[active_player]
	hero.budget.spend_action()
	hero.budget.reveals_left -= 1
	var terrain: Dictionary = TerrainCatalog.DEFINITIONS[drawn_terrain]
	var message := "%s placed." % terrain.name
	match terrain.effect:
		&"movement_loss":
			var loss := mini(hero.budget.movement_left, terrain.parameters.amount)
			hero.budget.movement_left -= loss
			message += " Lost %d movement." % loss
		&"energy_gain":
			var before := hero.budget.energy
			hero.budget.energy += int(terrain.parameters.amount)
			message += " Restored %d Energy." % (hero.budget.energy - before)
	if terrain.card_reward:
		message += " Exploration card available in Stage 5."
	drawn_tile = -1
	placement_target = Vector2i.ZERO
	refresh(message)


func update_placement() -> void:
	for marker: MeshInstance3D in reveal_markers.values():
		marker.queue_free()
	reveal_markers.clear()
	if is_instance_valid(preview):
		preview.queue_free()
		preview = null
	exploration_cells.clear()
	if drawn_tile < 0 or not can_reveal():
		return
	for cell in network.expansion_cells(heroes[active_player].location):
		if fitting_rotations(cell, drawn_tile).is_empty():
			continue
		exploration_cells.append(cell)
		if cell != placement_target:
			reveal_markers[cell] = block(network.center(cell) + Vector3.UP * 0.10, Vector3(0.48, 0.07, 0.48), Color("#ffd16c"))
	if tile_fits():
		preview = Node3D.new()
		add_child(preview)
		draw_tile(preview, placement_target, oriented_ports(drawn_tile, rotation_steps), TerrainCatalog.DEFINITIONS[drawn_terrain])


func reset_view() -> void:
	orbit = START_VIEW
	update_camera()


func update_camera() -> void:
	var horizontal := orbit.z * cos(orbit.y)
	camera.position = Vector3(sin(orbit.x) * horizontal, sin(orbit.y) * orbit.z, cos(orbit.x) * horizontal)
	camera.look_at(Vector3.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := event as InputEventMouseMotion
		orbit.x -= motion.relative.x * 0.008
		orbit.y = clampf(orbit.y + motion.relative.y * 0.008, 0.38, 1.39)
		update_camera()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var factor := 0.88 if click.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14
		orbit.z = clampf(orbit.z * factor, 11.0, 36.0)
		update_camera()
		get_viewport().set_input_as_handled()
		return
	if click.button_index != MOUSE_BUTTON_LEFT or phase != Phase.PLAYER:
		return

	if drawn_tile >= 0:
		for cell: Vector2i in reveal_markers:
			var marker: MeshInstance3D = reveal_markers[cell]
			if camera.unproject_position(marker.position).distance_to(click.position) <= 21.0:
				select_tile_location(cell)
				get_viewport().set_input_as_handled()
				return
		return

	if aiming:
		click_attack_target(click.position)
		return

	var destination := -1
	var nearest := 18.0
	for node in range(network.positions.size()):
		var distance := camera.unproject_position(network.positions[node]).distance_to(click.position)
		if distance < nearest:
			destination = node
			nearest = distance
	if destination in legal_moves:
		move_hero(destination)
		get_viewport().set_input_as_handled()


func find_moves() -> Dictionary[int, int]:
	var destinations: Dictionary[int, int] = {}
	if phase != Phase.PLAYER:
		return destinations
	var hero := heroes[active_player]
	if hero.health == 0:
		return destinations
	var frontier: Array[int] = [hero.location]
	for distance in range(1, hero.budget.movement_left + 1):
		var next_frontier: Array[int] = []
		for node in frontier:
			for next: int in network.links[node]:
				if next == hero.location or destinations.has(next) or hero_at(next) != null:
					continue
				destinations[next] = distance
				if next != FORTRESS and enemy_at(next) == null:
					next_frontier.append(next)
		frontier = next_frontier
		if frontier.is_empty():
			break
	return destinations


func enemy_at(location: int) -> Enemy:
	for enemy in enemies:
		if enemy.location == location:
			return enemy
	return null


func hero_at(location: int) -> Hero:
	if location != FORTRESS:
		for hero in heroes:
			if hero.health > 0 and hero.location == location:
				return hero
	return null


func find_attack_targets() -> Array[Enemy]:
	var targets: Array[Enemy] = []
	if phase != Phase.PLAYER:
		return targets
	var hero := heroes[active_player]
	if hero.health == 0 or hero.budget.actions_left == 0:
		return targets
	var frontier: Array[int] = [hero.location]
	var reachable := {hero.location: true}
	for _step in range(hero.attack_range):
		var next_frontier: Array[int] = []
		for node in frontier:
			for next: int in network.links[node]:
				if not reachable.has(next):
					reachable[next] = true
					next_frontier.append(next)
		frontier = next_frontier
	for enemy in enemies:
		if reachable.has(enemy.location):
			targets.append(enemy)
	return targets


func toggle_attack() -> void:
	if phase == Phase.PLAYER and drawn_tile < 0 and not attack_targets.is_empty():
		aiming = not aiming
		refresh("")


func click_attack_target(click: Vector2) -> void:
	if phase != Phase.PLAYER or not aiming:
		return
	var nearest: Enemy
	var distance_limit := 21.0
	for enemy in enemies:
		var body := enemy.piece.position + Vector3.UP * (0.38 * enemy.piece.scale.y)
		var distance := camera.unproject_position(body).distance_to(click)
		if distance < distance_limit:
			nearest = enemy
			distance_limit = distance
	if nearest in attack_targets:
		var hero := heroes[active_player]
		if not hero.budget.spend_action():
			return
		aiming = false
		nearest.health = maxi(0, nearest.health - hero.attack_damage)
		if nearest.health == 0:
			remove_enemy(nearest)
			refresh("%s defeated a %s." % [hero.title, nearest.title])
		else:
			refresh("%s hit a %s. %d HP left." % [hero.title, nearest.title, nearest.health])
		get_viewport().set_input_as_handled()


func monster_attack(hero: Hero, enemy: Enemy) -> String:
	var lost_hp := mini(hero.health, enemy.attack_damage)
	hero.health -= lost_hp
	hero.damage_this_turn += lost_hp
	if hero.damage_feedback != null and hero.damage_feedback.is_valid():
		hero.damage_feedback.kill()
	hero.damage_indicator.text = "−%d HP" % hero.damage_this_turn
	hero.damage_indicator.position = Vector3.UP * 1.25
	hero.damage_indicator.show()
	hero.damage_feedback = hero.damage_indicator.create_tween()
	hero.damage_feedback.tween_property(hero.damage_indicator, "position:y", 1.70, 0.8)
	hero.damage_feedback.tween_callback(hero.damage_indicator.hide)

	if enemy.attack_animation != null and enemy.attack_animation.is_valid():
		enemy.attack_animation.kill()
	enemy.piece.rotation.x = 0.0
	enemy.attack_animation = enemy.piece.create_tween()
	enemy.attack_animation.tween_property(enemy.piece, "rotation:x", 0.27, 0.08)
	enemy.attack_animation.tween_property(enemy.piece, "rotation:x", 0.0, 0.15)

	var message := "A %s attacked %s for %d HP." % [enemy.title, hero.title, lost_hp]
	if hero.health == 0:
		message += " %s is incapacitated." % hero.title
	return message


func move_hero(destination: int) -> void:
	if phase != Phase.PLAYER or aiming or drawn_tile >= 0 or not legal_moves.has(destination):
		return
	var hero := heroes[active_player]
	var cost: int = legal_moves[destination]
	if hero.budget.spend_movement(cost):
		hero.location = destination
		refresh("%s moved %d %s." % [hero.title, cost, "space" if cost == 1 else "spaces"])


func roll_wave() -> void:
	if not wave_waiting or phase != Phase.ENEMY:
		return
	wave_waiting = false
	fork_rolls.clear()
	warden_defended = false
	var rolls: Array[String] = []
	var composition: Array = wave_plan[wave]
	for title: String in composition:
		var lane := randi_range(0, 3)
		var entry: Dictionary = ENEMY_TYPES[title]
		var enemy := Enemy.new()
		enemy.title = title
		enemy.stride = entry["stride"]
		enemy.breach_damage = entry["breach_damage"]
		enemy.attack_damage = entry.get("attack_damage", 1)
		enemy.remove_on_breach = entry.get("remove_on_breach", true)
		enemy.max_health = entry["health"]
		enemy.health = enemy.max_health
		enemy.location = network.entry_for_lane(lane)
		enemy.visited[enemy.location] = true
		enemy.piece = miniature(title, entry["color"])
		if enemy.max_health > 1:
			enemy.health_label = Label3D.new()
			enemy.health_label.position = Vector3.UP * 1.03
			enemy.health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			enemy.health_label.pixel_size = 0.004
			enemy.health_label.font_size = 36
			enemy.health_label.outline_size = 10
			enemy.health_label.modulate = Color("#ffc692")
			enemy.piece.add_child(enemy.health_label)
		enemy.target_marker = block(Vector3.ZERO, Vector3(0.45, 0.045, 0.45), Color.WHITE, enemy.piece)
		enemy.target_marker.material_override = attack_material
		enemies.append(enemy)
		rolls.append("%s → %s" % [title, LANE_NAMES[lane]])
	dice_result = "Lane d4   " + "  ·  ".join(rolls)


func layout_enemies() -> void:
	var stacks: Dictionary = {}
	for enemy in enemies:
		var slot: int = stacks.get(enemy.location, 0)
		stacks[enemy.location] = slot + 1
		var offset := Vector3(0.27 * (slot % 2), 0, 0.27 * floorf(slot / 2.0))
		if hero_at(enemy.location) != null:
			offset.x += 0.34
		enemy.piece.position = network.positions[enemy.location] + offset
		enemy.target_marker.visible = aiming and enemy in attack_targets
		if enemy.health_label != null:
			enemy.health_label.text = "%d/%d" % [enemy.health, enemy.max_health]


func remove_enemy(enemy: Enemy) -> void:
	enemies.erase(enemy)
	enemy.piece.queue_free()


func trigger_entry_trap(enemy: Enemy, from: int) -> String:
	var tile := network.tile_at(enemy.location)
	if tile == null or tile == network.tile_at(from) or tile.trap_spent or tile.terrain.effect != &"explosion":
		return ""
	tile.enemy_entries += 1
	if tile.enemy_entries < int(tile.terrain.parameters.threshold):
		return ""
	tile.trap_spent = true
	var cell: Vector2i = network.cells_by_space[enemy.location]
	trap_labels[cell].text = "Trap spent"
	var blast: int = tile.terrain.parameters.damage
	var defeated := 0
	var occupants: Array[Enemy] = enemies.duplicate()
	for target in occupants:
		if network.tile_at(target.location) == tile:
			target.health = 0 if blast == 0 else maxi(0, target.health - blast)
			if target.health == 0:
				remove_enemy(target)
				defeated += 1
	return "Trap detonated and defeated %d enemies." % defeated


func resolve_enemies() -> void:
	if phase != Phase.ENEMY or wave_waiting:
		return
	var damage := 0
	var report: Array[String] = []
	fork_rolls.clear()
	var warden: Hero
	for hero in heroes:
		hero.damage_this_turn = 0
		if hero.id == &"warden":
			warden = hero
	var marching: Array[Enemy] = enemies.duplicate()
	for enemy in marching:
		if enemy not in enemies:
			continue
		var defender := hero_at(enemy.location)
		if defender != null:
			report.append(monster_attack(defender, enemy))
			continue
		for _step in range(enemy.stride):
			var routes := network.routes_from(enemy.location, enemy.visited)
			if routes.is_empty():
				break
			var choice := routes.find(enemy.blocked_destination)
			if choice < 0:
				choice = 0
				if routes.size() > 1:
					var current_tile := network.tile_at(enemy.location)
					if routes.size() == 2 and current_tile != null and current_tile.terrain.effect == &"fork":
						choice = 0 if randf() < float(current_tile.terrain.parameters.first_branch_probability) else 1
					else:
						choice = randi_range(0, routes.size() - 1)
					fork_rolls.append("%s d%d → %d" % [enemy.title, routes.size(), choice + 1])
			var destination := routes[choice]
			if destination == FORTRESS:
				if warden != null and warden.health > 0 and warden.location == FORTRESS and not warden_defended:
					warden_defended = true
					report.append("Warden blocked a breach.")
				else:
					var lost_hp := mini(integrity, enemy.breach_damage)
					integrity -= lost_hp
					damage += lost_hp
				if enemy.remove_on_breach:
					remove_enemy(enemy)
				break
			var heading := network.positions[destination] - network.positions[enemy.location]
			enemy.piece.rotation.y = atan2(heading.x, heading.z)
			defender = hero_at(destination)
			if defender != null:
				enemy.blocked_destination = destination
				report.append(monster_attack(defender, enemy))
				break
			enemy.blocked_destination = -1
			var previous := enemy.location
			enemy.location = destination
			enemy.visited[destination] = true
			var trap_message := trigger_entry_trap(enemy, previous)
			if not trap_message.is_empty():
				report.append(trap_message)
			if enemy not in enemies:
				break

		if integrity == 0:
			break

	if damage > 0:
		report.append("Fortress lost %d HP." % damage)
	if integrity == 0:
		phase = Phase.COMPLETE
		report.append("The base was destroyed.")
	elif enemies.is_empty():
		if wave == wave_plan.size() - 1:
			phase = Phase.COMPLETE
			report.append("The fortress held through all %d waves." % wave_plan.size())
		else:
			wave += 1
			wave_waiting = true
			report.append("Ready to roll the next wave.")
	if report.is_empty():
		report.append("Enemies advanced.")
	var message := " ".join(report)
	if phase == Phase.COMPLETE:
		refresh(message)
	else:
		begin_next_round(message)


func refresh(message: String) -> void:
	var health_readout: Array[String] = ["Fortress %d/%d HP" % [integrity, MAX_INTEGRITY]]
	for index in range(heroes.size()):
		var hero := heroes[index]
		hero.piece.position = network.positions[hero.location]
		if hero.location == FORTRESS:
			if heroes.size() <= 2:
				hero.piece.position.x += -0.36 if index == 0 else 0.36
			else:
				var angle := TAU * index / heroes.size()
				hero.piece.position += Vector3(sin(angle), 0, cos(angle)) * 0.58
		var incapacitated := hero.health == 0
		hero.figure.rotation.z = PI * 0.5 if incapacitated else 0.0
		hero.figure.position.y = 0.20 if incapacitated else 0.0
		hero.base.material_override = active_material if phase == Phase.PLAYER and index == active_player else idle_material
		hero.health_label.text = "%d/%d" % [hero.health, hero.max_health]
		hero.health_label.modulate = Color("#ff826d") if incapacitated else Color.WHITE
		if incapacitated:
			hero.health_label.text += " · Down"
		health_readout.append("%s %d/%d HP%s" % [hero.title, hero.health, hero.max_health, " (Incapacitated)" if incapacitated else ""])
	health_status.text = "    ·    ".join(health_readout)
	legal_moves = find_moves()
	attack_targets = find_attack_targets()
	var options := reveal_options()
	for node in range(markers.size()):
		markers[node].material_override = idle_material
		if drawn_tile < 0 and not aiming and node in legal_moves:
			markers[node].material_override = active_material
	if not options.is_empty() and not aiming:
		markers[heroes[active_player].location].material_override = endpoint_material
	layout_enemies()
	update_placement()
	dice_status.text = dice_result
	if not fork_rolls.is_empty():
		dice_status.text = "Fork rolls   " + "  ·  ".join(fork_rolls)
	elif wave_waiting and not wave_plan.is_empty() and (phase == Phase.ENEMY or dice_result.is_empty()):
		var incoming: Array = wave_plan[wave]
		dice_status.text = "Incoming (%d)   " % incoming.size() + "  ·  ".join(incoming)



	var in_game := phase != Phase.TITLE and phase != Phase.SETUP
	setup_controls.visible = phase == Phase.SETUP
	health_status.visible = in_game
	turn_status.visible = phase == Phase.PLAYER
	fortress_health.visible = in_game
	fortress_health.text = "■".repeat(integrity) + "□".repeat(MAX_INTEGRITY - integrity)
	fortress_health.modulate = Color("#9df4b7") if integrity > 2 else Color("#ff826d")
	dice_status.visible = in_game
	tile_card.visible = phase == Phase.PLAYER and drawn_tile >= 0
	reveal_button.visible = phase == Phase.PLAYER
	reveal_button.text = "Cancel reveal" if tile_card.visible else "Reveal tile"
	reveal_button.disabled = aiming or (not tile_card.visible and options.is_empty())
	place_button.visible = tile_card.visible
	rotate_button.visible = tile_card.visible
	if tile_card.visible:
		var terrain: Dictionary = TerrainCatalog.DEFINITIONS[drawn_terrain]
		drawn_tile_label.text = "%s\n%s" % [terrain.name, TILE_NAMES[drawn_tile]]
		terrain_description.text = terrain.description
	tile_diagram.queue_redraw()
	rotate_button.disabled = drawn_tile < 0 or fitting_rotations(placement_target, drawn_tile).size() < 2
	place_button.disabled = not tile_fits()
	phase_button.visible = phase != Phase.COMPLETE
	attack_button.visible = phase == Phase.PLAYER
	attack_button.disabled = tile_card.visible or attack_targets.is_empty()
	attack_button.text = "Cancel attack" if aiming else "Attack"
	status.text = message

	match phase:
		Phase.TITLE:
			instructions.text = "Start a local game."
			phase_button.text = "Start game"
		Phase.SETUP:
			status.text = "Game setup"
			instructions.text = "Choose one distinct hero per player."
			phase_button.text = "Begin game"
		Phase.PLAYER:
			var player := heroes[active_player]
			var budget := player.budget
			turn_status.text = "Movement %d/%d   ·   Actions %d/%d   ·   Energy %d/%d   ·   Reveals %d/%d   ·   Attack %d damage, range %d" % [
				budget.movement_left, budget.max_movement, budget.actions_left, HeroTurn.ACTIONS_PER_TURN,
				budget.energy, budget.max_energy, budget.reveals_left, HeroTurn.REVEALS_PER_TURN,
				player.attack_damage, player.attack_range,
			]
			phase_button.text = "End Player %d’s turn" % (active_player + 1)
			if player.health == 0:
				instructions.text = "Your hero was defeated. End your turn to continue."
			elif tile_card.visible:
				instructions.text = "Choose a gold space, then rotate or place the tile."
			elif aiming:
				instructions.text = "Click an orange-marked monster to attack."
			else:
				var move_status := "Click a glowing space to move"
				if budget.movement_left == 0:
					move_status = "No movement points left"
				elif legal_moves.is_empty():
					move_status = "No reachable spaces"
				var attack_status := "Attack available"
				if budget.actions_left == 0:
					attack_status = "No actions left"
				elif attack_targets.is_empty():
					attack_status = "No monsters in range"
				var reveal_status := "Reach an open road endpoint to reveal a tile"
				if budget.reveals_left == 0:
					reveal_status = "Reveal used"
				elif not options.is_empty():
					reveal_status = "Reveal tile for 1 action"
				instructions.text = "%s   ·   %s   ·   %s" % [move_status, attack_status, reveal_status]
		Phase.ENEMY:
			phase_button.text = "Enemy Turn"
			if wave_waiting:
				instructions.text = "Roll starting lanes for the incoming enemies."
			else:
				instructions.text = "Resolve enemy movement, attacks, and breaches."
		Phase.COMPLETE:
			instructions.text = "Choose Restart to start a new game."

	if in_game:
		var phase_title := ""
		match phase:
			Phase.PLAYER:
				phase_title = "Player %d’s turn · %s" % [active_player + 1, heroes[active_player].title]
			Phase.ENEMY:
				phase_title = "Enemy phase"
			Phase.COMPLETE:
				phase_title = "Defeat" if integrity == 0 else "Victory"
		status.text = "Round %d   ·   Wave %d/%d   ·   %s%s" % [
			round_number, wave + 1, wave_plan.size(), phase_title,
			"   ·   " + message if not message.is_empty() else "",
		]

extends Node3D

const RoadNetwork := preload("res://road_network.gd")
const LANE_NAMES := ["1 North", "2 East", "3 South", "4 West"]
const TILE_PORTS := [[0, 2], [0, 1], [0, 1, 3], [0, 1, 2, 3]]
const TILE_NAMES := ["Straight", "Curve", "T-junction", "Four-way crossing"]
const MAX_INTEGRITY := 5
const FORTRESS := 0
const START_VIEW := Vector3(0.38, 0.87, 23.0)
const HEROES := [
	{"name": "Warden", "color": Color("#4de1d1"), "stride": 1, "range": 1, "health": 5},
	{"name": "Scout", "color": Color("#a8ef85"), "stride": 2, "range": 3, "health": 4},
]
const ENEMY_TYPES := {
	"Grunt": {"stride": 1, "damage": 1, "health": 1, "color": Color("#ff865e")},
	"Runner": {"stride": 2, "damage": 1, "health": 1, "color": Color("#f4ce63")},
	"Brute": {"stride": 1, "damage": 2, "health": 2, "color": Color("#f46ea5")},
	"Boss": {"stride": 1, "damage": 2, "health": 3, "color": Color("#be8cff")},
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

enum Phase { TITLE, SETUP, REVEAL, PLAYER, ENEMY, COMPLETE }

class Hero:
	var title: String
	var stride: int
	var max_health: int
	var health: int
	var location: int
	var moved := false
	var attacked := false
	var attack_range: int
	var piece: Node3D
	var health_label: Label3D
	var base: MeshInstance3D

class Enemy:
	var location: int
	var visited: Dictionary = {}
	var title: String
	var stride: int
	var damage: int
	var health: int
	var max_health: int
	var health_label: Label3D
	var piece: Node3D
	var target_marker: MeshInstance3D

var network := RoadNetwork.new()
var markers: Array[MeshInstance3D] = []
var enemies: Array[Enemy] = []
var legal_moves: Array[int] = []
var attack_targets: Array[Enemy] = []
var aiming := false
var reveal_markers: Dictionary = {}
var placement_target := Vector2i.ZERO
var drawn_tile := -1
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
var dice_status: Label
var tile_card: PanelContainer
var drawn_tile_label: Label
var tile_diagram: Control
var rotate_button: Button
var place_button: Button
var phase_button: Button
var attack_button: Button
var attack_material: StandardMaterial3D
var setup_controls: HBoxContainer
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
		var entry: Dictionary = HEROES[character_pickers[index].selected]
		var hero := Hero.new()
		hero.title = entry["name"]
		hero.stride = entry["stride"]
		hero.attack_range = entry["range"]
		hero.max_health = entry["health"]
		hero.health = hero.max_health
		hero.location = FORTRESS
		hero.piece = miniature(hero.title, entry["color"])
		hero.base = block(Vector3(0, 0.02, 0), Vector3(0.38, 0.04, 0.38), entry["color"], hero.piece)
		hero.health_label = Label3D.new()
		hero.health_label.position = Vector3.UP * 0.91
		hero.health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hero.health_label.pixel_size = 0.004
		hero.health_label.font_size = 44
		hero.health_label.outline_size = 12
		hero.piece.add_child(hero.health_label)
		heroes.append(hero)


func draw_tile(parent: Node3D, cell: Vector2i, ports: Array[int], tint: Color) -> void:
	var center := network.center(cell)
	block(center, Vector3(1.96, 0.13, 1.96), tint, parent)
	var road_color := tint.lightened(0.26)
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


func lay_tile(cell: Vector2i, ports: Array[int], count: int) -> void:
	var nodes := network.add_tile(cell, ports, count)
	if nodes.is_empty():
		return
	draw_tile(self, cell, ports, Color("#92724f"))
	for id in nodes:
		markers.append(block(network.positions[id], Vector3(0.32, 0.045, 0.32), idle_material.albedo_color))


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
	attack_button = action(controls, "Attack", toggle_attack)
	phase_button = action(controls, "Start game", advance_phase)
	action(controls, "Reset view", reset_view)
	action(controls, "Restart", restart)

	health_status = centered_label(rows)
	dice_status = centered_label(rows)
	status = centered_label(rows)
	instructions = centered_label(rows)

	setup_controls = HBoxContainer.new()
	setup_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(setup_controls)
	player_count = OptionButton.new()
	player_count.add_item("1 player")
	player_count.add_item("2 players")
	player_count.select(1)
	player_count.item_selected.connect(update_player_count)
	setup_controls.add_child(player_count)
	for index in range(2):
		var picker := OptionButton.new()
		for entry: Dictionary in HEROES:
			picker.add_item("P%d  %s" % [index + 1, entry["name"]])
		picker.select(index)
		picker.item_selected.connect(select_character.bind(index))
		character_pickers.append(picker)
		setup_controls.add_child(picker)


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
	tile_diagram = Control.new()
	tile_diagram.custom_minimum_size = Vector2(108, 108)
	tile_diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile_diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_diagram.draw.connect(draw_tile_diagram)
	card_content.add_child(tile_diagram)


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
	character_pickers[1].visible = index == 1
	if index == 1:
		select_character(character_pickers[0].selected, 0)


func select_character(character_index: int, player_index: int) -> void:
	if player_count.selected == 1:
		var other := character_pickers[1 - player_index]
		if other.selected == character_index:
			other.select(1 - character_index)


func advance_phase() -> void:
	match phase:
		Phase.TITLE:
			phase = Phase.SETUP
			refresh("")
		Phase.SETUP:
			build_heroes()
			wave_plan = WAVE_PLANS[heroes.size() - 1]
			begin_tile_reveal("")
		Phase.REVEAL:
			begin_player_turn(0, "Tile placement skipped.")
		Phase.PLAYER:
			begin_player_turn(active_player + 1, "")
		Phase.ENEMY:
			if wave_waiting:
				roll_wave()
				begin_next_round("Enemies entered their rolled lanes.")
			else:
				resolve_enemies()


func begin_player_turn(index: int, message: String) -> void:
	aiming = false
	drawn_tile = -1
	placement_target = Vector2i.ZERO
	while index < heroes.size() and heroes[index].health == 0:
		index += 1
	active_player = index
	phase = Phase.PLAYER if index < heroes.size() else Phase.ENEMY
	refresh(message)


func begin_next_round(message: String) -> void:
	round_number += 1
	for hero in heroes:
		hero.moved = false
		hero.attacked = false
	begin_tile_reveal(message)


func begin_tile_reveal(message: String) -> void:
	phase = Phase.REVEAL
	drawn_tile = -1
	placement_target = Vector2i.ZERO
	rotation_steps = 0
	var candidates: Array[int] = []
	var cells := network.open_cells()
	for kind in range(TILE_PORTS.size()):
		for cell in cells:
			if not fitting_rotations(cell, kind).is_empty():
				candidates.append(kind)
				break
	if not candidates.is_empty():
		drawn_tile = candidates[randi_range(0, candidates.size() - 1)]
	refresh(message)


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
	return drawn_tile >= 0 and network.fitting_lane(
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
	tile_diagram.draw_rect(Rect2(Vector2.ZERO, tile_diagram.size), Color("#73593f"))
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
	if phase != Phase.REVEAL or not tile_fits():
		return
	var ports := oriented_ports(drawn_tile, rotation_steps)
	var count := (network.tiles.size() % 4) + 1
	lay_tile(placement_target, ports, count)
	begin_player_turn(0, "Road tile placed.")


func update_placement() -> void:
	for marker: MeshInstance3D in reveal_markers.values():
		marker.queue_free()
	reveal_markers.clear()
	if is_instance_valid(preview):
		preview.queue_free()
		preview = null
	if phase != Phase.REVEAL or drawn_tile == -1:
		return
	if placement_target != Vector2i.ZERO:
		preview = Node3D.new()
		add_child(preview)
		draw_tile(preview, placement_target, oriented_ports(drawn_tile, rotation_steps), Color("#477b67"))
	for cell in network.open_cells():
		if cell != placement_target and not fitting_rotations(cell, drawn_tile).is_empty():
			reveal_markers[cell] = block(network.center(cell) + Vector3.UP * 0.10, Vector3(0.48, 0.07, 0.48), Color("#ffd16c"))


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
	if click.button_index != MOUSE_BUTTON_LEFT or (phase != Phase.REVEAL and phase != Phase.PLAYER):
		return

	if phase == Phase.REVEAL:
		for cell: Vector2i in reveal_markers:
			var marker: MeshInstance3D = reveal_markers[cell]
			if camera.unproject_position(marker.position).distance_to(click.position) <= 21.0:
				select_tile_location(cell)
				get_viewport().set_input_as_handled()
				return
		return

	if phase != Phase.PLAYER:
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


func find_moves() -> Array[int]:
	var result: Array[int] = []
	if phase != Phase.PLAYER:
		return result
	var hero := heroes[active_player]
	if hero.moved or hero.health == 0:
		return result
	var frontier: Array[int] = [hero.location]
	var seen := {hero.location: true}
	for _step in range(hero.stride):
		var next_frontier: Array[int] = []
		for node in frontier:
			for next: int in network.links[node]:
				if seen.has(next) or hero_at(next) != null:
					continue
				seen[next] = true
				result.append(next)
				if next != FORTRESS and enemy_at(next) == null:
					next_frontier.append(next)
		frontier = next_frontier
	return result


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
	if hero.health == 0 or hero.attacked:
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
	if phase == Phase.PLAYER and not attack_targets.is_empty():
		aiming = not aiming
		refresh("")


func click_attack_target(click: Vector2) -> void:
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
		hero.attacked = true
		aiming = false
		nearest.health -= 1
		if nearest.health == 0:
			remove_enemy(nearest)
			refresh("%s defeated a %s." % [hero.title, nearest.title])
		else:
			refresh("%s hit a %s. %d HP left." % [hero.title, nearest.title, nearest.health])
		get_viewport().set_input_as_handled()


func monster_attack(hero: Hero, enemy: Enemy) -> String:
	var lost_hp := mini(hero.health, enemy.damage)
	hero.health -= lost_hp
	if hero.health == 0:
		return "A %s defeated %s." % [enemy.title, hero.title]
	return "A %s attacked %s for %d HP." % [enemy.title, hero.title, lost_hp]


func move_hero(destination: int) -> void:
	var hero := heroes[active_player]
	hero.location = destination
	hero.moved = true
	refresh("%s moved." % hero.title)


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
		enemy.damage = entry["damage"]
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


func resolve_enemies() -> void:
	var damage := 0
	var report: Array[String] = []
	fork_rolls.clear()
	var warden: Hero
	for hero in heroes:
		if hero.title == "Warden":
			warden = hero
			break
	var marching: Array[Enemy] = enemies.duplicate()
	for enemy in marching:
		var defender := hero_at(enemy.location)
		if defender != null:
			report.append(monster_attack(defender, enemy))
			continue
		for _step in range(enemy.stride):
			var routes := network.routes_from(enemy.location, enemy.visited)
			if routes.is_empty():
				break
			var choice := 0
			if routes.size() > 1:
				choice = randi_range(0, routes.size() - 1)
				fork_rolls.append("%s d%d → %d" % [enemy.title, routes.size(), choice + 1])
			var destination := routes[choice]
			if destination == FORTRESS:
				if warden != null and warden.health > 0 and warden.location == FORTRESS and not warden_defended:
					warden_defended = true
					report.append("Warden blocked a breach.")
				else:
					var lost_hp := mini(integrity, enemy.damage)
					integrity -= lost_hp
					damage += lost_hp
				remove_enemy(enemy)
				break
			var heading := network.positions[destination] - network.positions[enemy.location]
			enemy.piece.rotation.y = atan2(heading.x, heading.z)
			enemy.location = destination
			enemy.visited[destination] = true
			if hero_at(destination) != null:
				report.append("A %s moved into a hero’s space." % enemy.title)
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
			hero.piece.position.x += -0.36 if index == 0 else 0.36
		hero.piece.visible = hero.health > 0
		hero.base.material_override = active_material if phase == Phase.PLAYER and index == active_player else idle_material
		hero.health_label.text = "%d/%d" % [hero.health, hero.max_health]
		health_readout.append("%s %d/%d HP" % [hero.title, hero.health, hero.max_health])
	health_status.text = "    ·    ".join(health_readout)
	legal_moves = find_moves()
	attack_targets = find_attack_targets()
	for node in range(markers.size()):
		markers[node].material_override = active_material if not aiming and node in legal_moves else idle_material
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
	fortress_health.visible = in_game
	fortress_health.text = "■".repeat(integrity) + "□".repeat(MAX_INTEGRITY - integrity)
	fortress_health.modulate = Color("#9df4b7") if integrity > 2 else Color("#ff826d")
	dice_status.visible = in_game
	tile_card.visible = phase == Phase.REVEAL and drawn_tile >= 0
	place_button.visible = tile_card.visible
	rotate_button.visible = tile_card.visible
	drawn_tile_label.text = TILE_NAMES[drawn_tile] if drawn_tile >= 0 else ""
	tile_diagram.queue_redraw()
	rotate_button.disabled = drawn_tile < 0 or fitting_rotations(placement_target, drawn_tile).size() < 2
	place_button.disabled = not tile_fits()
	phase_button.visible = phase != Phase.COMPLETE
	attack_button.visible = phase == Phase.PLAYER
	attack_button.disabled = attack_targets.is_empty()
	attack_button.text = "Cancel attack" if aiming else "Attack"
	status.text = message

	match phase:
		Phase.TITLE:
			instructions.text = "Start a local game."
			phase_button.text = "Start game"
		Phase.SETUP:
			status.text = "Game setup"
			instructions.text = "Choose your players. Warden uses melee (1 space). Scout attacks at range (3 spaces)."
			phase_button.text = "Begin game"
		Phase.REVEAL:
			phase_button.text = "Skip tile" if drawn_tile >= 0 else "Continue"
			if drawn_tile == -1:
				instructions.text = "No road tile fits. Continue to the player turns."
			elif placement_target == Vector2i.ZERO:
				instructions.text = "Choose a gold space for the revealed tile."
			else:
				instructions.text = "Place the tile, or choose another gold space." if rotate_button.disabled else "Rotate, place, or choose another gold space."
		Phase.PLAYER:
			var player := heroes[active_player]
			phase_button.text = "End Player %d’s turn" % (active_player + 1)
			if player.health == 0:
				instructions.text = "Your hero was defeated. End your turn to continue."
			elif aiming:
				instructions.text = "Click an orange-marked monster to attack."
			else:
				var move_status := "Move used" if player.moved else "Click a glowing space to move"
				var attack_status := "Attack used" if player.attacked else "No monsters in range"
				if not attack_targets.is_empty():
					attack_status = "Attack available (%d-space range)" % player.attack_range
				instructions.text = "%s   ·   %s" % [move_status, attack_status]
		Phase.ENEMY:
			if wave_waiting:
				phase_button.text = "Roll wave · d4"
				instructions.text = "Roll starting lanes for the incoming enemies."
			else:
				phase_button.text = "Advance enemies" if not enemies.is_empty() else "Finish wave"
				instructions.text = "Resolve the enemy phase to continue."
		Phase.COMPLETE:
			instructions.text = "Choose Restart to start a new game."

	if in_game:
		var phase_title := "Reveal tile phase"
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

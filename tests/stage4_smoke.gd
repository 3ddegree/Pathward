extends SceneTree

func _initialize() -> void:
	run.call_deferred()

const Tabletop := preload("res://tabletop.gd")

func make_board(count: int) -> Tabletop:
	var board := load("res://tabletop.tscn").instantiate() as Tabletop
	root.add_child(board)
	board.advance_phase()
	board.player_count.select(count - 1)
	board.advance_phase()
	return board

func force_terrain(board, terrain: StringName, kind: int, spaces: int) -> void:
	board.drawn_terrain = terrain
	board.drawn_tile = kind
	board.drawn_spaces = spaces
	board.refresh("")

func run() -> void:
	for count in range(1, 6):
		var board = make_board(count)
		assert(board.reveal_button.disabled)
		board.toggle_reveal()
		assert(board.drawn_tile < 0)
		for player in range(count):
			assert(board.active_player == player)
			var hero = board.heroes[player]
			assert(hero.budget.reveals_left == 1)
			var first: int = board.network.links[0][player % 4]
			var endpoint := first + (player % 4)
			if player == 4:
				endpoint = board.network.tiles[Vector2i(0, -2)].endpoints.values()[0]
			board.move_hero(endpoint)
			assert(hero.location == endpoint and not board.reveal_button.disabled)
			var movement: int = hero.budget.movement_left
			hero.budget.actions_left = 0
			board.refresh("")
			assert(board.reveal_button.disabled and "Reveal needs 1 action" in board.instructions.text)
			board.toggle_reveal()
			assert(board.drawn_tile < 0)
			hero.budget.actions_left = 2
			board.refresh("")
			board.toggle_reveal()
			assert(board.drawn_tile >= 0)
			board.place_tile()
			assert(hero.budget.actions_left == 2 and hero.budget.reveals_left == 1)
			board.toggle_reveal()
			assert(hero.budget.actions_left == 2 and hero.budget.reveals_left == 1)
			board.toggle_reveal()
			force_terrain(board, &"road", 1, 1)
			var cell: Vector2i = board.exploration_cells[0]
			board.select_tile_location(Vector2i.ZERO)
			board.place_tile()
			assert(board.placement_target == Vector2i.ZERO)
			assert(hero.budget.actions_left == 2 and hero.budget.reveals_left == 1)
			board.select_tile_location(cell)
			assert(board.tile_fits())
			var old_rotation: int = board.rotation_steps
			board.rotate_tile()
			assert(board.tile_fits() and board.rotation_steps != old_rotation)
			board.place_tile()
			assert(hero.budget.actions_left == 1 and hero.budget.reveals_left == 0)
			assert(hero.budget.movement_left == movement)
			assert(board.network.distances_to_fortress().size() == board.network.positions.size())
			board.toggle_reveal()
			assert(board.drawn_tile < 0)
			if movement > 0:
				var new_space: int = board.network.positions.size() - 1
				board.move_hero(new_space)
				assert(hero.location == new_space and hero.budget.movement_left == movement - 1)
			if player == 0 and count == 5:
				board.move_hero(0)
				assert(hero.location == 0)
			board.advance_phase()
		board.advance_phase()
		assert(board.enemies.size() == (1 if count <= 2 else 2))
		assert(board.heroes[0].budget.reveals_left == 1)
		board.free()

	var terrain_board = make_board(1)
	var hero = terrain_board.heroes[0]
	terrain_board.move_hero(terrain_board.network.links[0][0])
	hero.budget.energy = 2
	terrain_board.toggle_reveal()
	force_terrain(terrain_board, &"supply", 0, 2)
	terrain_board.select_tile_location(Vector2i(0, -2))
	terrain_board.cards.deck.assign([&"burst"])
	terrain_board.place_tile()
	assert(hero.budget.energy == 3 and hero.hand == [&"burst"])
	assert(terrain_board.cards.deck.is_empty())
	assert(terrain_board.network.tiles[Vector2i(0, -2)].terrain.card_reward)
	terrain_board.free()

	var damaged = make_board(1)
	var traveler = damaged.heroes[0]
	damaged.move_hero(damaged.network.links[0][0])
	damaged.toggle_reveal()
	force_terrain(damaged, &"damaged", 0, 1)
	damaged.select_tile_location(Vector2i(0, -2))
	var budget: int = traveler.budget.movement_left
	damaged.place_tile()
	assert(traveler.budget.movement_left == budget - 1)
	damaged.free()

	var traps = make_board(1)
	assert(traps.lay_tile(Vector2i(2, 0), [1, 3], 2, &"exploding"))
	assert(traps.lay_tile(Vector2i(3, 0), [1, 3], 2, &"water_bridge"))
	assert(not traps.network.tiles[Vector2i(3, 0)].terrain.tower_allowed)
	assert(not load("res://terrain_catalog.gd").DEFINITIONS[&"lava_bridge"].tower_allowed)
	traps.advance_phase()
	traps.advance_phase()
	traps.waves.pending.clear()
	traps.spawn_enemy("Grunt")
	var from: int = traps.network.tiles[Vector2i(3, 0)].endpoints[3]
	for enemy in traps.enemies:
		enemy.stride = 1
		enemy.attack_damage = 1
		enemy.location = from
		enemy.visited = {from: true}
	var tile = traps.network.tiles[Vector2i(2, 0)]
	var blocker = traps.heroes[0]
	blocker.location = tile.endpoints[1]
	traps.refresh("")
	traps.advance_phase()
	traps.advance_phase()
	assert(tile.enemy_entries == 0 and not tile.trap_spent)
	assert(traps.enemies.all(func(enemy: Tabletop.Enemy) -> bool: return enemy.location == from))
	assert(blocker.health == blocker.max_health - 2 and traps.integrity == 5)
	var health_after_attacks: int = blocker.health
	traps.move_hero(tile.endpoints[3])
	assert(blocker.location == tile.endpoints[3])
	traps.advance_phase()
	traps.advance_phase()
	assert(tile.enemy_entries == 2 and tile.trap_spent and traps.enemies.is_empty())
	assert(traps.trap_labels[Vector2i(2, 0)].text == "Trap spent")
	assert(traps.integrity == 5 and blocker.health == health_after_attacks)
	traps.free()

	var fork = make_board(1)
	assert(fork.lay_tile(Vector2i(2, 0), [3, 0], 1))
	assert(fork.lay_tile(Vector2i(2, -1), [0, 2], 1))
	assert(fork.lay_tile(Vector2i(2, -2), [2, 3], 1))
	assert(fork.lay_tile(Vector2i(1, -2), [1, 3], 1))
	assert(fork.lay_tile(Vector2i(0, -2), [0, 1, 2], 4, &"fork"))
	var fork_tile = fork.network.tiles[Vector2i(0, -2)]
	var hub: int = fork_tile.endpoints[0]
	var branch_a: int = fork_tile.endpoints[1]
	var branch_b: int = fork_tile.endpoints[2]
	var routes: Array[int] = fork.network.routes_from(hub, {hub: true})
	assert(routes.size() == 2 and branch_a in routes and branch_b not in routes)
	for branch in routes:
		assert(fork.network.routes_from(branch, {hub: true, branch: true}).size() == 1)
	assert(fork.network.distances_to_fortress().size() == fork.network.positions.size())
	fork.free()
	print("STAGE_4_OK")
	quit()

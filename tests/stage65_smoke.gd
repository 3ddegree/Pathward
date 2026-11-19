extends SceneTree

const Board := preload("res://tabletop.gd")
const Schedule := preload("res://wave_schedule.gd")
const Catalog := preload("res://hero_catalog.gd")


func _initialize() -> void:
	run.call_deferred()


func make_board(players: int, start_wave: int = 1) -> Board:
	var board := load("res://tabletop.tscn").instantiate() as Board
	board.wave_seed = 3016
	root.add_child(board)
	board.advance_phase()
	board.player_count.select(players - 1)
	if board.wave_debug_enabled:
		board.debug_wave_picker.select(start_wave - 1)
		board.debug_test_dice()
		assert("rolled" in board.card_notice.dialog_text)
		board.debug_simulate_dice()
		assert("100 simulated events" in board.card_notice.dialog_text)
	board.advance_phase()
	if start_wave > 1 and not board.wave_debug_enabled:
		board.waves.reset(players, board.wave_seed, start_wave)
		board.refresh("")
	return board


func enter_enemy_turn(board: Board) -> void:
	while board.phase == Board.Phase.PLAYER or board.phase == Board.Phase.ROUND_START:
		board.advance_phase()
	assert(board.phase == Board.Phase.ENEMY)
	board.advance_phase()


func roll_all(board: Board) -> void:
	while board.phase == Board.Phase.SPAWN_DICE:
		board.roll_spawn_die(0)
		board.roll_spawn_die(1)
		board.roll_spawn_die(2)


func verify_configuration() -> void:
	var types := [[5, 1, 0], [4, 2, 0], [3, 2, 1], [2, 2, 2], [1, 2, 3]]
	var quantities := [[1, 1, 2, 2, 3, 3], [1, 2, 2, 3, 3, 4], [1, 2, 3, 3, 4, 5], [2, 3, 3, 4, 4, 5], [2, 3, 4, 4, 5, 6]]
	var schedule := Schedule.new()
	for number in range(1, 6):
		var data: Dictionary = Schedule.CONFIG[number - 1]
		assert(data.type_faces.size() == 6 and data.quantity_faces == quantities[number - 1])
		for type_index in range(3):
			assert(data.type_faces.count(Schedule.ORDINARY_TYPES[type_index]) == types[number - 1][type_index])
		var reference := RandomNumberGenerator.new()
		reference.seed = number
		schedule.rng.seed = number
		var seen := {}
		for _sample in range(100):
			assert(schedule.roll_die(number, 0) == reference.randi_range(0, 3))
			assert(schedule.roll_die(number, 1) == data.type_faces[reference.randi_range(0, 5)])
			var quantity: int = schedule.roll_die(number, 2)
			assert(quantity == data.quantity_faces[reference.randi_range(0, 5)])
			seen[quantity] = true
		assert(seen.size() > 1)
	for players in range(1, 6):
		schedule.reset(players, 2)
		for number in range(1, 6):
			var expected: int = players + [0, 0, 1, 1, 2][number - 1]
			assert(schedule.remaining_events(number) == expected)
			var batches := [0, 0, 0, 0]
			var first := schedule.first_turns[number]
			for entry in schedule.pending:
				if entry.wave == number and entry.event_number > 0:
					assert(entry.kind == "")
					batches[entry.due_turn - first] += 1
			assert(batches.max() - batches.min() <= 1 and batches[0] == ceili(expected / 4.0))


func run() -> void:
	verify_configuration()
	for players in range(1, 6):
		var board := make_board(players)
		assert(board.party_panel.rows.get_child_count() == players)
		for index in range(players):
			var hero := board.heroes[index]
			assert(board.active_hero_heading.text == "Player %d — %s" % [index + 1, hero.title])
			assert("HP %d/%d" % [hero.health, hero.max_health] in board.turn_status.text)
			assert("Movement %d/%d" % [hero.budget.movement_left, hero.budget.movement_limit] in board.turn_status.text)
			assert("Actions 2/2" in board.turn_status.text and "Energy 4/5" in board.turn_status.text)
			assert(Catalog.DEFINITIONS[index].ability_name in board.turn_status.text)
			var row := board.party_panel.rows.get_child(index) as Label
			assert(hero.title in row.text and row.modulate == Color("#9df4b7"))
			board.advance_phase()
		board.free()

	var board := make_board(5)
	board.draw_exploration_card(board.heroes[0], &"ambush")
	assert(board.enemies.size() == 1 and board.waves.remaining_events(1) == 5)
	var survivor := board.enemies[0]
	assert(survivor.spawn_lane in board.valid_spawn_lanes())
	survivor.stride = 0
	enter_enemy_turn(board)
	assert(board.phase == Board.Phase.SPAWN_DICE and board.next_spawn_die() == 0)
	assert(board.spawn_dice.buttons[0].disabled == false and board.spawn_dice.buttons[1].disabled)
	board.advance_phase()
	board.resolve_enemies()
	board.roll_spawn_die(1)
	assert(board.waves.completed_turns == 0 and board.next_spawn_die() == 0)
	board.spawn_dice.animate_roll(0)
	board.spawn_dice.animate_roll(0)
	assert(board.spawn_dice.animating and board.next_spawn_die() == 0)
	await create_timer(0.40).timeout
	assert(not board.spawn_dice.animating and board.next_spawn_die() == 1)
	var event := board.active_spawn
	var lane := event.lane
	board.roll_spawn_die(0)
	assert(event.lane == lane and board.next_spawn_die() == 1)
	board.roll_spawn_die(1)
	var kind := event.rolled_kind
	board.roll_spawn_die(2)
	assert(board.waves.completed_turns == 0 and board.phase == Board.Phase.SPAWN_DICE)
	assert(board.enemies.size() == 1 + event.quantity)
	for enemy in board.enemies:
		if enemy != survivor:
			assert(enemy.title == kind and enemy.spawn_lane == lane and enemy.visited.size() == 1)
	assert(board.spawn_history.size() == 1)
	board.roll_spawn_die(2)
	assert(board.spawn_history.size() == 1)
	roll_all(board)
	assert(board.waves.completed_turns == 1 and board.spawn_history.size() == 2)
	for enemy in board.enemies.duplicate():
		if enemy != survivor:
			board.remove_enemy(enemy)
	for turn in range(2, 18):
		enter_enemy_turn(board)
		if turn < 17:
			assert(not board.boss_spawned)
		else:
			assert(board.boss_spawned and board.final_boss.visited.size() == 1)
			assert(board.waves.remaining_events(5) == 7)
		roll_all(board)
		assert(board.waves.completed_turns == turn and board.enemies.has(survivor))
		if turn == 4 or turn == 8 or turn == 12 or turn == 16:
			assert(board.waves.wave_round == 1)
		for enemy in board.enemies.duplicate():
			if enemy != survivor:
				assert(enemy.visited.size() == 1)
				board.remove_enemy(enemy)
	assert(board.spawn_history.size() == 24)
	board.free()

	var fallback := make_board(1)
	var rng_state := fallback.waves.rng.state
	var requested: int = fallback.waves.roll_die(1, 0)
	fallback.waves.rng.state = rng_state
	var only_lane := (requested + 1) % 4
	fallback.network.links[0] = [fallback.network.links[0][only_lane]]
	enter_enemy_turn(fallback)
	roll_all(fallback)
	assert(not fallback.enemies.is_empty() and "unavailable" in fallback.last_spawn_result)
	for enemy in fallback.enemies:
		assert(enemy.spawn_lane == only_lane)
	fallback.free()

	var deferred := make_board(1)
	var connected: Array = deferred.network.links[0]
	deferred.network.links[0] = []
	enter_enemy_turn(deferred)
	assert(deferred.waves.completed_turns == 1 and deferred.waves.remaining_events(1) == 1)
	assert("deferred" in deferred.status.text and deferred.spawn_history.is_empty())
	deferred.network.links[0] = connected
	enter_enemy_turn(deferred)
	roll_all(deferred)
	assert(deferred.waves.completed_turns == 2 and deferred.waves.remaining_events(1) == 0)
	deferred.free()

	var boss_test := make_board(1, 5)
	enter_enemy_turn(boss_test)
	assert(boss_test.final_boss != null and boss_test.waves.remaining_events(5) == 3)
	roll_all(boss_test)
	assert(boss_test.spawn_history.size() == 1 and boss_test.waves.remaining_events(5) == 2)
	boss_test.free()
	print("STAGE_65_OK")
	quit()

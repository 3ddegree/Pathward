extends SceneTree

const Tabletop := preload("res://tabletop.gd")
const Schedule := preload("res://wave_schedule.gd")


func _initialize() -> void:
	run.call_deferred()


func make_board(count: int, seed_value: int = 466) -> Tabletop:
	var board := load("res://tabletop.tscn").instantiate() as Tabletop
	board.wave_seed = seed_value
	root.add_child(board)
	board.advance_phase()
	board.player_count.select(count - 1)
	board.advance_phase()
	return board


func finish_round(board: Tabletop) -> void:
	while board.phase == Tabletop.Phase.PLAYER or board.phase == Tabletop.Phase.ROUND_START:
		board.advance_phase()
	assert(board.phase == Tabletop.Phase.ENEMY)
	board.advance_phase()


func run() -> void:
	for players in range(1, 6):
		var schedule := Schedule.new()
		schedule.reset(players, 128)
		for number in range(1, 6):
			var expected: int = [3, 5, 7, 9, 12][number - 1] + (players - 1) * number
			var first := schedule.first_turns[number]
			var batches := [0, 0, 0, 0]
			var bosses := 0
			for entry in schedule.pending:
				if entry.wave != number:
					continue
				if entry.kind == "Boss":
					assert(number == 5 and entry.due_turn == first)
					bosses += 1
				else:
					assert(entry.kind in Schedule.ORDINARY_TYPES)
					batches[entry.due_turn - first] += 1
			assert(batches.reduce(func(total, count): return total + count, 0) == expected)
			assert(batches.max() - batches.min() <= 1)
			assert(bosses == (1 if number == 5 else 0))
	var weights := Schedule.new()
	var expected_rng := RandomNumberGenerator.new()
	weights.rng.seed = 29
	expected_rng.seed = 29
	for number in range(1, 6):
		var data: Dictionary = Schedule.CONFIG[number - 1]
		for _sample in range(100):
			var roll := expected_rng.randi_range(1, 100)
			var expected := "Grunt" if roll <= int(data.weights[0]) else "Runner" if roll <= int(data.weights[0]) + int(data.weights[1]) else "Brute"
			assert(weights.roll_kind(number) == expected)

	var board := make_board(5)
	if board.wave_debug_enabled:
		assert(board.wave_debug_live.visible)
		board.debug_view_schedule()
		assert("Wave 5" in board.card_notice.dialog_text)
	else:
		assert(board.wave_debug_live == null)
	assert(board.spawn_enemy("Boss") == -1)
	var survivor: Tabletop.Enemy
	for turn in range(1, 21):
		var before := board.waves.completed_turns
		board.resolve_enemies()
		assert(board.waves.completed_turns == before)
		var expected_batch := board.waves.due_spawns().size()
		var expected_wave := board.waves.current_wave
		finish_round(board)
		assert(board.waves.completed_turns == turn)
		assert(board.enemies.size() == expected_batch + (0 if turn == 1 else 1))
		for enemy in board.enemies.duplicate():
			if enemy == survivor:
				continue
			assert(enemy.visited.size() == 1)
			assert(enemy.location == board.network.entry_for_lane(enemy.spawn_lane))
			if enemy.title == "Boss":
				assert(expected_wave == 5 and turn == 17 and enemy == board.final_boss)
			if turn == 1 and survivor == null:
				survivor = enemy
				survivor.stride = 0
			else:
				board.remove_enemy(enemy)
		assert(board.enemies.has(survivor))
		if turn < 17:
			assert(not board.boss_spawned)
		if turn == 4 or turn == 8 or turn == 12 or turn == 16:
			assert(board.waves.current_wave == expected_wave + 1 and board.waves.wave_round == 1)
			assert("begins" in board.status.text)
			if turn == 16:
				assert("Boss incoming" in board.status.text)
	assert(board.waves.pending.is_empty() and board.boss_defeated and board.boss_spawned)
	board.remove_enemy(survivor)
	finish_round(board)
	assert(board.phase == Tabletop.Phase.COMPLETE and board.integrity == 5)
	board.free()

	var deferred := make_board(1)
	deferred.waves.round_override = 1
	deferred.waves.reset(1, 12)
	var connected: Array = deferred.network.links[0]
	deferred.network.links[0] = []
	finish_round(deferred)
	assert(deferred.waves.current_wave == 2 and deferred.enemies.is_empty())
	assert(deferred.waves.remaining_spawns(1) == 3 and "3 spawns deferred" in deferred.status.text)
	deferred.network.links[0] = [connected[2]]
	finish_round(deferred)
	assert(deferred.enemies.size() == 8 and deferred.waves.remaining_spawns(1) == 0)
	for enemy in deferred.enemies:
		assert(enemy.spawn_lane == 2 and deferred.network.distances_to_fortress().has(enemy.location))
	deferred.free()

	var seeded_a := make_board(3, 801)
	var seeded_b := make_board(3, 801)
	finish_round(seeded_a)
	finish_round(seeded_b)
	assert(seeded_a.dice_result == seeded_b.dice_result)
	seeded_a.free()
	seeded_b.free()
	print("STAGE_6_OK")
	quit()

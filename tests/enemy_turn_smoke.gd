extends SceneTree

const Tabletop := preload("res://tabletop.gd")
const Catalog := preload("res://hero_catalog.gd")


func _initialize() -> void:
	run.call_deferred()


func make_board(count: int) -> Tabletop:
	var board := load("res://tabletop.tscn").instantiate() as Tabletop
	root.add_child(board)
	board.advance_phase()
	board.player_count.select(count - 1)
	board.advance_phase()
	return board


func end_player_turns(board: Tabletop) -> void:
	while board.phase == Tabletop.Phase.PLAYER:
		board.advance_phase()
	assert(board.phase == Tabletop.Phase.ENEMY)
	assert(board.phase_button.text == "Enemy Turn")


func set_location(enemy: Tabletop.Enemy, space: int) -> void:
	enemy.location = space
	enemy.visited = {space: true}


func run() -> void:
	var health: Array[int] = []
	for entry: Dictionary in Catalog.DEFINITIONS:
		health.append(entry.health)
	assert(health == [6, 4, 4, 5, 4, 4])

	for count in range(1, 6):
		var board := make_board(count)
		for player in range(count):
			assert(board.phase == Tabletop.Phase.PLAYER and board.active_player == player)
			board.resolve_enemies()
			assert(board.round_number == 1)
			board.advance_phase()
		assert(board.phase_button.text == "Enemy Turn")
		board.advance_phase()
		assert(board.round_number == 2 and board.wave == 0 and not board.wave_waiting)
		assert(board.active_player == 0 and board.phase == Tabletop.Phase.PLAYER)
		assert(board.enemies.size() == (2 if count == 1 else 3))
		board.free()

	var battle := make_board(1)
	end_player_turns(battle)
	battle.advance_phase()
	var hero := battle.heroes[0]
	var west: int = battle.network.links[0][3]
	battle.move_hero(west + 1)
	assert(hero.location == west + 1)
	var runner := battle.enemies[0]
	var follower := battle.enemies[1]
	set_location(runner, west + 3)
	set_location(follower, west + 2)
	runner.stride = 3
	runner.title = "Runner"
	follower.attack_damage = 2
	end_player_turns(battle)
	battle.advance_phase()
	assert(runner.location == west + 2 and follower.location == west + 2)
	assert(runner.blocked_destination == hero.location and follower.blocked_destination == hero.location)
	assert(hero.health == 3 and hero.damage_indicator.text == "−3 HP")
	assert("Runner attacked Warden for 1 HP" in battle.status.text)
	assert("Grunt attacked Warden for 2 HP" in battle.status.text)
	assert(battle.phase == Tabletop.Phase.PLAYER)
	assert(hero.health == 3 and runner in battle.attack_targets)
	battle.toggle_attack()
	var body := runner.piece.position + Vector3.UP * (0.38 * runner.piece.scale.y)
	battle.click_attack_target(battle.camera.unproject_position(body))
	assert(runner not in battle.enemies and hero.budget.actions_left == 1)

	hero.health = 1
	end_player_turns(battle)
	battle.advance_phase()
	assert(hero.health == 0 and hero.piece.visible and hero.figure.rotation.z > 1.0)
	assert("incapacitated" in battle.status.text and "Down" in hero.health_label.text)
	assert(battle.hero_at(hero.location) == null and battle.phase == Tabletop.Phase.ENEMY)
	assert(battle.legal_moves.is_empty() and battle.attack_targets.is_empty() and not battle.can_reveal())
	assert(follower.location == west + 2)
	follower.stride = 4
	var previous_round := battle.round_number
	battle.advance_phase()
	assert(follower not in battle.enemies and battle.integrity == 4)
	assert(battle.round_number == previous_round + 1 and battle.wave == 1 and battle.wave_waiting)
	battle.free()

	var defense := make_board(1)
	end_player_turns(defense)
	defense.advance_phase()
	var breach := defense.enemies[0]
	defense.remove_enemy(defense.enemies[1])
	set_location(breach, defense.network.links[0][0])
	end_player_turns(defense)
	defense.advance_phase()
	assert(defense.warden_defended and defense.integrity == 5 and breach not in defense.enemies)
	assert(defense.wave == 1 and defense.wave_waiting)
	defense.free()
	print("ENEMY_TURN_OK")
	quit()

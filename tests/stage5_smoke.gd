extends SceneTree

const Tabletop := preload("res://tabletop.gd")
const Deck := preload("res://exploration_deck.gd")


func _initialize() -> void:
	run.call_deferred()


func make_board(count: int) -> Tabletop:
	var board := load("res://tabletop.tscn").instantiate() as Tabletop
	board.exploration_seed = 501
	root.add_child(board)
	board.advance_phase()
	board.player_count.select(count - 1)
	board.advance_phase()
	return board


func run() -> void:
	var a := Deck.new()
	var b := Deck.new()
	a.reset(7)
	b.reset(7)
	assert(a.deck == b.deck and a.deck.size() == 24)
	assert(not a.deck.has(&"tile_swap") and not a.deck.has(&"build_tower"))
	a.deck.clear()
	a.discard.assign([&"energy"])
	assert(a.draw_card() == &"energy" and a.discard.is_empty())
	assert(a.draw_card() == &"")

	for count in range(1, 6):
		var board := make_board(count)
		var hero := board.heroes[0]
		var endpoint: int = board.network.links[0][0]
		board.move_hero(endpoint)
		board.toggle_reveal()
		board.drawn_tile = 0
		board.drawn_terrain = &"road"
		board.drawn_spaces = 1
		board.refresh("")
		board.cards.deck.assign([&"burst"])
		board.place_tile()
		assert(board.cards.deck.size() == 1 and hero.hand.is_empty())
		board.select_tile_location(Vector2i(0, -2))
		board.place_tile()
		assert(board.cards.deck.size() == 1 and hero.hand.is_empty())
		board.draw_exploration_card(hero)
		assert(hero.hand == [&"burst"])
		board.advance_phase()
		assert(hero.hand == [&"burst"])
		if count > 1:
			assert(board.heroes[1].hand.is_empty())
		board.free()

	var board := make_board(2)
	var scout := board.heroes[1]
	var hero := board.heroes[0]
	board.draw_exploration_card(hero, &"energy")
	assert(hero.budget.energy == 5 and hero.hand.is_empty() and hero.budget.actions_left == 2)
	board.integrity = 4
	board.draw_exploration_card(hero, &"repairs")
	assert(board.integrity == 5)
	board.draw_exploration_card(hero, &"reinforced")
	board.draw_exploration_card(hero, &"structural")
	assert(board.integrity == 5 and board.shield_hp == 0)
	board.draw_exploration_card(hero, &"structural")
	assert(board.integrity == 3)
	board.draw_exploration_card(hero, &"lucky")
	assert(hero.budget.reveals_left == 2 and hero.budget.reveal_limit == 2)
	board.draw_exploration_card(hero, &"exhaustion")
	assert(hero.budget.movement_left == 4 and hero.budget.next_movement_penalty == 2)
	board.draw_exploration_card(hero, &"ambush")
	assert(board.enemies.size() == 1 and board.network.distances_to_fortress().has(board.enemies[0].location))
	board.draw_exploration_card(hero, &"reinforcements")
	assert(board.extra_grunts == 1)
	board.cards.deck.assign([&"burst", &"cache"])
	board.draw_exploration_card(hero)
	assert(hero.hand == [&"burst"])
	assert("Supply Cache" in board.last_card_effect and "Burst Movement" in board.last_card_effect)
	board.draw_exploration_card(hero, &"broken")
	assert(hero.hand.is_empty() and &"burst" in board.cards.discard)
	board.cards.deck.clear()
	board.cards.discard.assign([&"cache"])
	board.draw_exploration_card(hero)
	assert(board.cards.discard == [&"cache"] and "No additional cards" in board.last_card_effect)

	for id: StringName in [&"burst", &"tar_pit", &"lane_dash", &"burst"]:
		board.draw_exploration_card(hero, id)
	board.refresh("")
	assert(hero.hand.size() == 3 and board.pending_owner == hero and board.phase_button.disabled)
	board.advance_phase()
	assert(board.active_player == 0)
	board.discard_from_full_hand(0)
	assert(hero.hand == [&"burst", &"tar_pit", &"lane_dash"] and board.pending_owner == null)
	board.draw_exploration_card(hero, &"tar_pit")
	board.discard_from_full_hand(3)
	assert(hero.hand == [&"burst", &"tar_pit", &"lane_dash"])
	board.choose_hand_card(0)
	board.cancel_card()
	assert(hero.hand.size() == 3 and hero.budget.actions_left == 2)
	board.choose_hand_card(0)
	board.play_selected_card()
	assert(hero.budget.movement_left == 8 and hero.budget.actions_left == 1 and hero.hand.size() == 2)
	board.choose_hand_card(0)
	board.play_selected_card()
	assert(hero.budget.actions_left == 1 and hero.hand.size() == 2)
	var ambush := board.enemies[0]
	var west: int = board.network.links[0][3]
	ambush.location = west + 3
	ambush.visited = {ambush.location: true}
	board.refresh("")
	var body := ambush.piece.position + Vector3.UP * (0.38 * ambush.piece.scale.y)
	board.handle_card_target(board.camera.unproject_position(body))
	board.play_selected_card()
	assert(ambush.skip_movement == 1 and hero.budget.actions_left == 0 and hero.hand == [&"lane_dash"])
	board.advance_phase()
	assert(scout.hand.is_empty())
	board.advance_phase()
	board.advance_phase()
	assert(board.extra_grunts == 0 and board.enemies.size() == 5)
	assert(hero.budget.movement_left == 2 and hero.budget.next_movement_penalty == 0)
	board.move_hero(west)
	board.choose_hand_card(0)
	assert(board.card_can_target_space(west + 2))
	assert(not board.card_can_target_space(board.network.links[0][0]))
	board.handle_card_target(board.camera.unproject_position(board.network.positions[west + 2]))
	board.play_selected_card()
	assert(hero.location == west + 2 and hero.budget.movement_left == 1 and hero.budget.actions_left == 1)
	hero.location = 0
	board.advance_phase()
	board.advance_phase()
	board.advance_phase()
	assert(ambush.skip_movement == 0 and ambush.location == west + 3)
	if board.card_debug_enabled:
		assert(board.debug_controls.visible)
		board.debug_give_card()
		assert(hero.hand == [&"tar_pit"])
		board.debug_clear_hand()
		assert(hero.hand.is_empty())
	else:
		assert(board.debug_controls == null)
	board.integrity = 1
	board.draw_exploration_card(hero, &"structural")
	assert(board.integrity == 0 and board.phase == Tabletop.Phase.COMPLETE)
	board.free()
	print("STAGE_5_OK")
	quit()

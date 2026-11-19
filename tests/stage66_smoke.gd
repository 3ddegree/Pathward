extends SceneTree

const Board := preload("res://tabletop.gd")


func _initialize() -> void:
	run.call_deferred()


func settle_layout() -> void:
	await process_frame
	await process_frame


func run() -> void:
	root.size = Vector2i(1152, 648)
	var board := load("res://tabletop.tscn").instantiate() as Board
	board.wave_seed = 18
	root.add_child(board)
	assert(board.lobby.visible and not board.player_dock.visible and not board.wave_dock.visible)
	board.advance_phase()
	board.player_count.select(4)
	board.advance_phase()
	await settle_layout()
	assert(not board.lobby.visible and board.player_dock.visible and board.wave_dock.visible)
	assert(board.party_panel.rows.get_child_count() == 5)
	assert(board.phase_button.get_parent() == board.player_dock.pinned and board.phase_button.text == "End Turn")
	assert(board.instructions.get_parent() == board.player_messages)
	assert(board.status.get_parent() == board.wave_messages)
	var viewport := root.get_visible_rect()
	var center := viewport.get_center()
	var left := board.player_dock.get_global_rect()
	var right := board.wave_dock.get_global_rect()
	assert(not left.has_point(center) and not right.has_point(center))
	assert(left.end.x < center.x and right.position.x > center.x)
	assert(left.position.x >= 0 and right.end.x <= viewport.end.x)
	assert(board.phase_button.get_global_rect().end.y < left.end.y)

	board.player_dock.header.set_pressed_no_signal(false)
	board.player_dock.set_expanded(false)
	await settle_layout()
	assert(not board.player_dock.scroll.visible and board.phase_button.is_visible_in_tree())
	assert(board.player_dock.get_global_rect().end.y < left.end.y)
	board.player_dock.header.set_pressed_no_signal(true)
	board.player_dock.set_expanded(true)

	var first := board.heroes[0]
	first.hand.assign([&"tar_pit", &"burst", &"lane_dash"])
	board.player_dock.set_expanded(false)
	board.draw_exploration_card(first, &"burst")
	board.refresh("")
	assert(board.player_dock.expanded and board.hand_buttons[3].is_visible_in_tree())
	assert(board.phase_button.disabled)
	board.discard_from_full_hand(3)
	while board.phase == Board.Phase.PLAYER:
		board.advance_phase()
	assert(board.phase_button.get_parent() == board.wave_dock.pinned and board.phase_button.text == "Enemy Turn")
	assert(board.instructions.get_parent() == board.wave_messages)
	board.advance_phase()
	await settle_layout()
	assert(board.spawn_dice.is_visible_in_tree() and board.wave_dock.is_ancestor_of(board.spawn_dice))
	assert(not board.phase_button.is_visible_in_tree())
	assert(not board.wave_dock.get_global_rect().has_point(center))
	for button in board.spawn_dice.buttons:
		assert(button.get_global_rect().end.x <= board.wave_dock.get_global_rect().end.x)
	while board.phase == Board.Phase.SPAWN_DICE:
		for die in range(3):
			board.roll_spawn_die(die)
	assert(board.phase == Board.Phase.PLAYER and board.phase_button.get_parent() == board.player_dock.pinned)
	board.free()
	print("STAGE_66_OK")
	quit()

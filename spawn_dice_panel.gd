extends HFlowContainer

signal rolled(die: int)

const LABELS := ["△ Lane D4", "▣ Monster D6", "▣ Quantity D6"]
var buttons: Array[Button] = []
var expected := -1
var animating := false


func _ready() -> void:
	alignment = FlowContainer.ALIGNMENT_CENTER
	for die in range(LABELS.size()):
		var button := Button.new()
		button.text = LABELS[die]
		button.custom_minimum_size = Vector2(156, 38)
		button.pressed.connect(animate_roll.bind(die))
		add_child(button)
		buttons.append(button)


func show_rolls(lane: String, kind: String, quantity: int, next_die: int) -> void:
	expected = next_die
	var results := [lane, kind, str(quantity) if quantity > 0 else ""]
	for die in range(buttons.size()):
		buttons[die].text = LABELS[die] if results[die].is_empty() else "%s · %s" % [LABELS[die], results[die]]
		buttons[die].disabled = die != next_die or animating


func animate_roll(die: int) -> void:
	if animating or die != expected:
		return
	animating = true
	var button := buttons[die]
	button.disabled = true
	button.text = "Rolling…"
	button.modulate = Color("#ffd16c")
	var animation := create_tween()
	animation.tween_property(button, "modulate", Color.WHITE, 0.28)
	await animation.finished
	animating = false
	rolled.emit(die)

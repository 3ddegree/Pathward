extends PanelContainer

var rows: VBoxContainer
var toggle: Button


func _ready() -> void:
	var content := VBoxContainer.new()
	add_child(content)
	toggle = Button.new()
	toggle.text = "Party ▾"
	toggle.toggle_mode = true
	toggle.set_pressed_no_signal(true)
	toggle.toggled.connect(toggle_party)
	content.add_child(toggle)
	rows = VBoxContainer.new()
	content.add_child(rows)


func toggle_party(expanded: bool) -> void:
	rows.visible = expanded
	toggle.text = "Party ▾" if expanded else "Party ▸"
	if not expanded:
		size = get_combined_minimum_size()


func show_party(entries: Array[String], active: int) -> void:
	while rows.get_child_count() < entries.size():
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13)
		rows.add_child(label)
	for index in range(rows.get_child_count()):
		var label := rows.get_child(index) as Label
		label.visible = index < entries.size()
		if label.visible:
			label.text = entries[index]
			label.modulate = Color("#9df4b7") if index == active else Color.WHITE

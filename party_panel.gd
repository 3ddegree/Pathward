extends VBoxContainer

var rows: VBoxContainer


func _ready() -> void:
	rows = self
	add_theme_constant_override("separation", 6)


func show_party(entries: Array[String], active: int) -> void:
	while rows.get_child_count() < entries.size():
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(label)
	for index in range(rows.get_child_count()):
		var label := rows.get_child(index) as Label
		label.visible = index < entries.size()
		if label.visible:
			label.text = entries[index]
			label.modulate = Color("#9df4b7") if index == active else Color.WHITE

extends PanelContainer

var header: Button
var pinned: VBoxContainer
var scroll: ScrollContainer
var body: VBoxContainer
var on_right := false
var expanded := true


func _ready() -> void:
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("#18222d")
	surface.border_color = Color("#3b4e5e")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(10)
	surface.content_margin_left = 10
	surface.content_margin_right = 10
	surface.content_margin_top = 9
	surface.content_margin_bottom = 9
	add_theme_stylebox_override("panel", surface)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	add_child(stack)
	header = Button.new()
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	stack.add_child(header)
	pinned = VBoxContainer.new()
	pinned.visible = false
	stack.add_child(pinned)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)


func configure(title: String, right_side: bool, collapsible: bool) -> void:
	on_right = right_side
	header.text = title
	if collapsible:
		header.toggle_mode = true
		header.set_pressed_no_signal(true)
		header.toggled.connect(set_expanded.bind(title))
		header.text += " ▾"
	else:
		header.flat = true
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE if on_right else Control.PRESET_LEFT_WIDE)
	get_viewport().size_changed.connect(update_bounds)
	update_bounds()


func set_expanded(value: bool, title: String = "Party") -> void:
	expanded = value
	header.text = title + (" ▾" if value else " ▸")
	scroll.visible = value
	update_bounds()


func update_bounds() -> void:
	var width := get_viewport_rect().size.x
	var dock_width := clampf(width * 0.23, 180.0, 278.0) if on_right else clampf(width * 0.21, 170.0, 250.0)
	if not expanded:
		dock_width = minf(dock_width, 155.0)
	offset_left = -dock_width - 12.0 if on_right else 12.0
	offset_right = -12.0 if on_right else dock_width + 12.0
	offset_top = 12.0
	set_anchor(SIDE_BOTTOM, 1.0 if expanded else 0.0)
	offset_bottom = -12.0 if expanded else 118.0

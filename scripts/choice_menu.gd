extends CanvasLayer

signal selected(id: String)

var shade: ColorRect
var panel: PanelContainer
var heading: Label
var body: RichTextLabel
var buttons: VBoxContainer
var scroll: ScrollContainer

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	shade = ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.07, 0.83)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("172533")
	box.border_color = Color("c89d52")
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("f5cc7e"))
	column.add_child(heading)
	body = RichTextLabel.new()
	body.custom_minimum_size = Vector2(700, 140)
	body.add_theme_font_size_override("normal_font_size", 19)
	body.add_theme_color_override("default_color", Color("f0e8d7"))
	body.bbcode_enabled = true
	body.scroll_active = true
	column.add_child(body)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 210)
	column.add_child(scroll)
	buttons = VBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 7)
	scroll.add_child(buttons)
	hide()

func present(title: String, text: String, options: Array) -> void:
	heading.text = title
	body.text = text
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	var first_button: Button = null
	for option in options:
		var button := Button.new()
		button.text = str(option.label)
		button.custom_minimum_size.y = 42
		button.add_theme_font_size_override("font_size", 18)
		button.disabled = bool(option.get("disabled", false))
		button.pressed.connect(_choose.bind(str(option.id)))
		buttons.add_child(button)
		if first_button == null and not button.disabled:
			first_button = button
	scroll.custom_minimum_size.y = clampf(options.size() * 49.0 - 7.0, 42.0, 280.0)
	scroll.scroll_vertical = 0
	show()
	if first_button != null:
		first_button.grab_focus()

func _choose(id: String) -> void:
	get_viewport().set_input_as_handled()
	selected.emit(id)

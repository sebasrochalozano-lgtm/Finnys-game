extends Control

signal selected(id: String)
const PixelFont = preload("res://assets/fonts/PressStart2P-Regular.ttf")
var dragon: AnimatedSprite2D
var coin: Sprite2D
var heading: Label
var subtitle: Label
var clock: float = 0.0
var continue_button: Button
var multiplayer_button: Button
var frame: VBoxContainer
var footer: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.texture = preload("res://assets/passage_interior.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.10, 0.22)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	heading = Label.new()
	heading.text = "FINNY THE\nDRAGON"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", PixelFont)
	heading.add_theme_font_size_override("font_size", 42)
	heading.add_theme_color_override("font_color", Color("acfa13"))
	heading.add_theme_color_override("font_outline_color", Color("10130d"))
	heading.add_theme_constant_override("outline_size", 12)
	add_child(heading)
	subtitle = Label.new()
	subtitle.text = "A little dragon. A big adventure."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_shadow_color", Color.BLACK)
	subtitle.add_theme_constant_override("shadow_outline_size", 5)
	add_child(subtitle)
	dragon = AnimatedSprite2D.new()
	dragon.sprite_frames = preload("res://assets/animations/finny.tres")
	dragon.play("idle")
	add_child(dragon)
	coin = Sprite2D.new()
	coin.texture = preload("res://assets/menu_coin.svg")
	add_child(coin)
	frame = VBoxContainer.new()
	frame.add_theme_constant_override("separation", 12)
	add_child(frame)
	for entry in [["new", "New Game"], ["continue", "Continue"], ["multiplayer", "Multiplayer Mode"], ["quit", "Quit"]]:
		var button := Button.new()
		button.text = entry[1]
		button.custom_minimum_size = Vector2(362, 52)
		button.add_theme_font_override("font", PixelFont)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("f8ffe8"))
		button.add_theme_color_override("font_disabled_color", Color("8b988d"))
		for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("456e16")
			if style_name == "hover": style.bg_color = Color("648e22")
			if style_name == "pressed": style.bg_color = Color("2b4b0e")
			if style_name == "disabled": style.bg_color = Color("28362b")
			if style_name == "focus": style.bg_color = Color.TRANSPARENT
			style.border_color = Color("c5f580") if style_name != "disabled" else Color("526151")
			style.set_border_width_all(3)
			style.shadow_color = Color("11152b")
			style.shadow_size = 4
			style.shadow_offset = Vector2(4, 4)
			button.add_theme_stylebox_override(style_name, style)
		button.pressed.connect(func(): selected.emit(entry[0]))
		frame.add_child(button)
		if entry[0] == "continue": continue_button = button
		if entry[0] == "multiplayer": multiplayer_button = button
	footer = Label.new()
	footer.text = "SOLO CAMPAIGN  /  LOCAL CO-OP    •    F11: Fullscreen"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 17)
	footer.add_theme_color_override("font_shadow_color", Color.BLACK)
	footer.add_theme_constant_override("shadow_outline_size", 5)
	add_child(footer)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if frame == null: return
	heading.position = Vector2(0, size.y * 0.085)
	heading.size = Vector2(size.x, 115)
	subtitle.position = Vector2(0, size.y * 0.085 + 120)
	subtitle.size = Vector2(size.x, 30)
	frame.position = Vector2(size.x * 0.52, size.y * 0.40)
	frame.size = Vector2(minf(390, size.x * 0.39), 244)
	footer.position = Vector2(0, size.y - 34)
	footer.size = Vector2(size.x, 26)

func _process(delta: float) -> void:
	if not visible: return
	clock += delta
	var breath := sin(clock * 2.0)
	dragon.position = Vector2(size.x * 0.275, size.y * 0.70 - breath * 4)
	dragon.scale = Vector2(1.20 - breath * 0.012, 1.20 + breath * 0.018)
	coin.position = Vector2(size.x * 0.29, size.y * 0.39 + sin(clock * 2.5) * 10)
	coin.scale = Vector2(maxf(absf(cos(clock * 2.2)), 0.12), 1)

func refresh(has_save: bool) -> void:
	continue_button.disabled = not has_save
	continue_button.tooltip_text = "Load your saved campaign" if has_save else "No saved campaign yet"

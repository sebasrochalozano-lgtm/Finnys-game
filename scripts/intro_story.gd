extends Control

signal finished

# Forty seconds of reading, plus brief fades. Continue never opens this scene.
const SLIDES = [
	{"image": preload("res://assets/story/grandfather.jpg"), "duration": 9.0,
	"title": "A MILLION COINS",
	"body": 'Grandfather leaves Finny the family cave.\n\n"The cave holds a family treasure of [color=#ffd47d]one million coins[/color]..."\n\nFinny can hardly believe his luck.\n\n[color=#b9ef71][b]"I\'m rich!"[/b][/color]', "cue": &"treasure"},
	{"image": preload("res://assets/story/empty_chest.jpg"), "duration": 11.0,
	"title": "AN EMPTY PROMISE",
	"body": 'Inside the chest: no gold. Just a note.\n\n"I spent it all on shiny armor. Sorry.\nYou owe the King [color=#ffd47d]5,000 coins[/color].\n\nLove, Grandfather."\n\nFinny has inherited a debt.', "cue": &"chest"},
	{"image": preload("res://assets/story/king.jpg"), "duration": 9.0,
	"title": "SEVEN DAYS",
	"body": 'The King arrives with his guards.\n\n[color=#ffd47d][b]"Pay in 7 days or I take the cave."[/b][/color]\n\nFive thousand coins. Seven days.\nAnd not a single coin in the chest.', "cue": &"royal"},
	{"image": preload("res://assets/story/idea.png"), "duration": 11.0,
	"title": "BOSS FIGHT INC.",
	"body": 'Outside, knights are looking for a dragon to fight. Finny has an idea.\n\n[color=#b9ef71][b]"What if I charge them to beat me?"[/b][/color]\n\nA goblin peeks into the cave:\n"Boss, I need a job."\n\n[color=#ffd47d]Time to open for business.[/color]\nPay 1,200 coins by the end of day 3.', "cue": &"idea"}
]

var slide_index: int = -1
var elapsed: float = 0.0
var changing: bool = false
var completed: bool = false
var second_cue_played: bool = false
var content: Control
var picture_frame: Panel
var picture: TextureRect
var chapter: Label
var heading: Label
var narration: RichTextLabel
var brand: Label
var counter: Label
var progress: ProgressBar
var next_button: Button
var skip_button: Button
var transition: Tween
var motion: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("101322")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	brand = _label(17, Color("d4b979"))
	brand.text = "FINNY THE DRAGON  /  BOSS FIGHT INC."
	add_child(brand)
	content = Control.new()
	add_child(content)
	picture_frame = Panel.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("272437")
	frame_style.border_color = Color("c5a96d")
	frame_style.set_border_width_all(2)
	frame_style.shadow_color = Color(0, 0, 0, 0.5)
	frame_style.shadow_size = 12
	picture_frame.add_theme_stylebox_override("panel", frame_style)
	content.add_child(picture_frame)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture_frame.add_child(picture)
	chapter = _label(16, Color("d4b979"))
	heading = _label(32, Color("fff0ca"))
	narration = RichTextLabel.new()
	narration.bbcode_enabled = true
	narration.scroll_active = false
	narration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narration.add_theme_font_size_override("normal_font_size", 22)
	narration.add_theme_font_size_override("bold_font_size", 22)
	narration.add_theme_color_override("default_color", Color("e6e4ef"))
	for item in [chapter, heading, narration]: content.add_child(item)
	counter = _label(16, Color("c6c4d5"))
	add_child(counter)
	progress = ProgressBar.new()
	progress.max_value = 1.0
	progress.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("d4b979")
	var track := StyleBoxFlat.new()
	track.bg_color = Color("373446")
	progress.add_theme_stylebox_override("fill", fill)
	progress.add_theme_stylebox_override("background", track)
	add_child(progress)
	next_button = _button("Next [Space]")
	next_button.pressed.connect(next_slide)
	skip_button = _button("Skip Story [Esc]")
	skip_button.pressed.connect(finish)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_slide(0)

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("383447") if state == "hover" else Color("242333")
		style.border_color = Color("c5a96d")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)
	add_child(button)
	return button

func _layout() -> void:
	var extent := get_viewport_rect().size
	var side := minf(extent.y - 144, extent.x * 0.46)
	var top := (extent.y - side) / 2.0 - 4
	var text_x := side + 82
	brand.position = Vector2(36, 20)
	content.size = extent
	picture_frame.position = Vector2(36, top)
	picture_frame.size = Vector2.ONE * side
	picture_frame.pivot_offset = picture_frame.size / 2
	picture.position = Vector2(7, 7)
	picture.size = picture_frame.size - Vector2(14, 14)
	chapter.position = Vector2(text_x, top + 8)
	heading.position = Vector2(text_x, top + 42)
	narration.position = Vector2(text_x, top + 108)
	narration.size = Vector2(extent.x - text_x - 38, side - 100)
	counter.position = Vector2(36, extent.y - 45)
	progress.position = Vector2(176, extent.y - 36)
	progress.size = Vector2(extent.x - 660, 5)
	skip_button.position = Vector2(extent.x - 438, extent.y - 60)
	skip_button.size = Vector2(196, 40)
	next_button.position = Vector2(extent.x - 226, extent.y - 60)
	next_button.size = Vector2(190, 40)

func _show_slide(index: int) -> void:
	if completed: return
	slide_index = index
	elapsed = 0
	second_cue_played = false
	var slide: Dictionary = SLIDES[index]
	picture.texture = slide.image
	chapter.text = "THE STORY  /  %02d" % (index + 1)
	heading.text = slide.title
	narration.text = slide.body
	counter.text = "CHAPTER %d / %d" % [index + 1, SLIDES.size()]
	next_button.text = "Start Playing [Space]" if index == SLIDES.size() - 1 else "Next [Space]"
	if is_instance_valid(motion): motion.kill()
	picture_frame.scale = Vector2.ONE * 0.975
	motion = create_tween()
	motion.tween_property(picture_frame, "scale", Vector2.ONE, float(slide.duration)).set_trans(Tween.TRANS_SINE)
	content.modulate.a = 0
	transition = create_tween()
	transition.tween_property(content, "modulate:a", 1.0, 0.35)
	transition.tween_callback(func(): changing = false)
	SoundFX.play_cue(slide.cue)

func _process(delta: float) -> void:
	if completed or changing or slide_index < 0: return
	elapsed += delta
	progress.value = elapsed / float(SLIDES[slide_index].duration)
	if slide_index == 1 and elapsed >= 1.6 and not second_cue_played:
		second_cue_played = true
		SoundFX.play_cue(&"disappointment")
	if elapsed >= float(SLIDES[slide_index].duration): next_slide()

func next_slide() -> void:
	if changing or completed: return
	if slide_index + 1 >= SLIDES.size():
		finish()
		return
	changing = true
	SoundFX.stop_story()
	if is_instance_valid(transition): transition.kill()
	transition = create_tween()
	transition.tween_property(content, "modulate:a", 0.0, 0.25)
	transition.tween_callback(_show_slide.bind(slide_index + 1))

func finish() -> void:
	if completed: return
	completed = true
	if is_instance_valid(transition): transition.kill()
	if is_instance_valid(motion): motion.kill()
	SoundFX.stop_story()
	finished.emit()

func _input(event: InputEvent) -> void:
	if completed or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE, KEY_ENTER:
			get_viewport().set_input_as_handled()
			next_slide()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			finish()

func _exit_tree() -> void:
	SoundFX.stop_story()

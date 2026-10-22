extends Node2D

enum Flow { TITLE, SAVED, PLAYING, PAUSED, GAME_OVER }

const SAVE_PATH := "user://finny_save.cfg"
const START_IMAGE := "res://assets/inicio_juego.png"
const SAVE_IMAGE := "res://assets/partida_guardada.png"
const PAUSE_IMAGE := "res://assets/juego_pausado.png"
const GAME_OVER_IMAGE := "res://assets/juego_finalizado.png"

@onready var level: Node2D = $Level01
@onready var hud: CanvasLayer = $UI
@onready var screen: TextureRect = $MenuLayer/Screen
@onready var result_label: Label = $MenuLayer/ResultLabel

var flow: Flow = Flow.TITLE
var music: AudioStreamPlayer
var day_label: Label
var save_day: int = 1
var save_customers_spawned: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level.visible = false
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.visible = false
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	$MenuLayer.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.gui_input.connect(_on_screen_input)
	level.day_started.connect(_on_day_started)
	level.night_started.connect(_on_night_started)
	level.game_finished.connect(_on_game_finished)
	$UI/PanelContainer/Controls.text = "Mover: WASD/flechas  |  A: abrir pasillo (al cerrar)  |  W: entrar al cuarto  |  S: volver\nE: atender/guardar  |  R: atacar  |  Backspace: pausa"
	day_label = Label.new()
	day_label.position = Vector2(396, 8)
	day_label.size = Vector2(360, 28)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62))
	day_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	day_label.add_theme_constant_override("shadow_offset_x", 2)
	day_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(day_label)
	_create_music()

	if Economy.start_new_on_load:
		Economy.start_new_on_load = false
		_start_new_game()
	elif _has_save():
		_show_screen(SAVE_IMAGE, Flow.SAVED)
	else:
		_show_screen(START_IMAGE, Flow.TITLE)

func _process(_delta: float) -> void:
	if flow == Flow.PLAYING and level.game_has_ended():
		_end_game(false)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_BACKSPACE:
		return
	if flow == Flow.PLAYING:
		_pause_game()
		get_viewport().set_input_as_handled()
	elif flow == Flow.PAUSED:
		_resume_game()
		get_viewport().set_input_as_handled()

func _create_music() -> void:
	var audio_bytes := FileAccess.get_file_as_bytes("res://assets/musi_juego.mpeg")
	if audio_bytes.is_empty():
		push_warning("No se pudo leer assets/musi_juego.mpeg")
		return
	var stream := AudioStreamMP3.new()
	stream.data = audio_bytes
	stream.loop = true
	music = AudioStreamPlayer.new()
	music.name = "BackgroundMusic"
	music.stream = stream
	music.volume_db = -12.0
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	music.play()

func _on_screen_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var size := screen.size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var point := screen.get_local_mouse_position() / size
	match flow:
		Flow.TITLE:
			if _inside(point, Rect2(0.35, 0.65, 0.30, 0.23)):
				_start_new_game()
		Flow.SAVED:
			if _inside(point, Rect2(0.34, 0.49, 0.33, 0.21)):
				_start_new_game()
			elif _inside(point, Rect2(0.34, 0.69, 0.33, 0.22)):
				_continue_saved_game()
		Flow.PAUSED:
			if _inside(point, Rect2(0.39, 0.36, 0.22, 0.14)):
				_resume_game()
			elif _inside(point, Rect2(0.39, 0.49, 0.22, 0.14)):
				_save_game()
			elif _inside(point, Rect2(0.39, 0.62, 0.22, 0.14)):
				_return_to_title()
		Flow.GAME_OVER:
			if _inside(point, Rect2(0.38, 0.56, 0.30, 0.25)):
				Economy.reset()
				Economy.start_new_on_load = true
				get_tree().paused = false
				get_tree().reload_current_scene()
	get_viewport().set_input_as_handled()

func _inside(point: Vector2, rect: Rect2) -> bool:
	return rect.has_point(point)

func _show_screen(image_path: String, next_flow: Flow) -> void:
	flow = next_flow
	screen.texture = load(image_path) as Texture2D
	screen.visible = true
	result_label.visible = false

func _show_title() -> void:
	level.stop_game()
	level.visible = false
	hud.visible = false
	get_tree().paused = false
	if music != null:
		music.stream_paused = false
	_show_screen(SAVE_IMAGE if _has_save() else START_IMAGE, Flow.SAVED if _has_save() else Flow.TITLE)

func _start_new_game() -> void:
	Economy.reset()
	_remove_save()
	_begin_game(1, 0)

func _continue_saved_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		_start_new_game()
		return
	Economy.wallet = int(config.get_value("money", "wallet", 0))
	Economy.business_box = int(config.get_value("money", "business", 0))
	Economy.king_chest = int(config.get_value("money", "king", 0))
	save_day = int(config.get_value("progress", "day", 1))
	save_customers_spawned = int(config.get_value("progress", "customers_spawned", 0))
	Economy.money_changed.emit(Economy.wallet, Economy.business_box, Economy.king_chest)
	_begin_game(save_day, save_customers_spawned)

func _begin_game(start_day: int, customers_spawned: int) -> void:
	get_tree().paused = false
	flow = Flow.PLAYING
	result_label.visible = false
	screen.visible = false
	level.visible = true
	hud.visible = true
	if music != null:
		music.stream_paused = false
	level.start_game(start_day, customers_spawned)

func _pause_game() -> void:
	if flow != Flow.PLAYING:
		return
	flow = Flow.PAUSED
	get_tree().paused = true
	if music != null:
		music.stream_paused = true
	_show_screen(PAUSE_IMAGE, Flow.PAUSED)

func _resume_game() -> void:
	get_tree().paused = false
	flow = Flow.PLAYING
	screen.visible = false
	result_label.visible = false
	if music != null:
		music.stream_paused = false

func _save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("money", "wallet", Economy.wallet)
	config.set_value("money", "business", Economy.business_box)
	config.set_value("money", "king", Economy.king_chest)
	var progress: Dictionary = level.get_save_progress()
	config.set_value("progress", "day", progress.day)
	config.set_value("progress", "customers_spawned", progress.customers_spawned)
	var error := config.save(SAVE_PATH)
	if error == OK:
		result_label.text = "GAME SAVED"
		result_label.position = Vector2(430, 565)
		result_label.size = Vector2(290, 40)
		result_label.visible = true

func _return_to_title() -> void:
	get_tree().paused = false
	_show_title()

func _has_save() -> bool:
	var config := ConfigFile.new()
	return config.load(SAVE_PATH) == OK

func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _on_day_started(day_number: int) -> void:
	day_label.text = "DAY %d  |  OPEN" % day_number
	if music != null:
		music.volume_db = -12.0

func _on_night_started(day_number: int) -> void:
	day_label.text = "DAY %d  |  NIGHT • A: PASILLO  |  W: CUARTO" % day_number
	if music != null:
		music.volume_db = -18.0

func _on_game_finished(victory: bool) -> void:
	_end_game(victory)

func _end_game(victory: bool) -> void:
	if flow == Flow.GAME_OVER:
		return
	level.stop_game()
	flow = Flow.GAME_OVER
	get_tree().paused = true
	if music != null:
		music.stream_paused = false
	_show_screen(GAME_OVER_IMAGE, Flow.GAME_OVER)
	if victory:
		result_label.text = "VICTORY! REY'S DEBT PAID"
	else:
		result_label.text = "THE CAVE IS IN DANGER"
	result_label.position = Vector2(365, 540)
	result_label.size = Vector2(425, 44)
	result_label.add_theme_color_override("font_color", Color(0.10, 0.10, 0.10))
	result_label.add_theme_font_size_override("font_size", 25)
	result_label.visible = true

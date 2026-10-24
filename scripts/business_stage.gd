extends Node2D

var workers: Array[AnimatedSprite2D] = []
var sign: Label
var clock: float = 0.0

func _ready() -> void:
	z_index = -1
	sign = Label.new()
	sign.position = Vector2(-145, -122)
	sign.size = Vector2(290, 30)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_theme_color_override("font_color", Color("ffe7ac"))
	sign.add_theme_color_override("font_shadow_color", Color.BLACK)
	sign.add_theme_font_size_override("font_size", 17)
	add_child(sign)
	var goblin_scene := preload("res://level/costumers/goblin.tscn").instantiate()
	var frames: SpriteFrames = goblin_scene.get_node("AnimatedSprite2D").sprite_frames
	for i in range(2):
		var worker := AnimatedSprite2D.new()
		worker.sprite_frames = frames
		worker.scale = Vector2(0.22, 0.22)
		worker.modulate = Color(0.7, 1.0, 0.85)
		add_child(worker)
		workers.append(worker)
	goblin_scene.free()

func _process(delta: float) -> void:
	clock += delta
	for i in range(workers.size()):
		var worker := workers[i]
		worker.visible = i < Economy.employees
		worker.position = Vector2(sin(clock * 1.3 + i * PI) * 80, 8 + i * 25)
		worker.flip_h = cos(clock * 1.3 + i * PI) < 0
		worker.play("idle" if Economy.stage_broken else "walk")
	sign.text = "STAGE DAMAGED - REPAIR" if Economy.stage_broken else ("STAGE 2  |  +120 / SHOW" if Economy.second_stage else "EXPAND HERE  |  PRESS B")
	queue_redraw()

func _draw() -> void:
	var color := Color(0.5, 0.15, 0.12, 0.65) if Economy.stage_broken else Color(0.55, 0.38, 0.19, 0.65)
	if not Economy.second_stage:
		color = Color(0.3, 0.55, 0.6, 0.18)
	_draw_stage_ellipse(Vector2.ZERO, Vector2(135, 52), color)
	for y in range(-30, 40, 14):
		draw_line(Vector2(-110, y), Vector2(110, y), Color(0.95, 0.75, 0.4, 0.35), 2)
	for x in [-125, 125]:
		draw_line(Vector2(x, 22), Vector2(x, -80), Color("715137"), 8)
		draw_circle(Vector2(x, -82), 8, Color("ffc568"))
	if Economy.stage_broken:
		draw_line(Vector2(-70, -35), Vector2(65, 42), Color("ff774f"), 5)
		draw_line(Vector2(70, -35), Vector2(-65, 42), Color("ff774f"), 5)

func _draw_stage_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(40):
		var angle := TAU * i / 40.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

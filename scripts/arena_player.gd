extends CharacterBody2D

signal health_changed
signal defeated

@export var player_number: int = 1
var arena: Node2D
var sprite: AnimatedSprite2D
var health_bar: ProgressBar
var name_label: Label
var health: int = 100
var is_dead: bool = false
var is_attacking: bool = false
var hit_done: bool = false
var hurt_time: float = 0.0
var dash_time: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction := Vector2.RIGHT
var facing := Vector2.RIGHT
var clock: float = 0.0
var swing_time: float = 0.0
var prefix: String
var player_color: Color
var fall_tween: Tween
const SPEED := 220.0
const ATTACK_DAMAGE := 30
const ATTACK_RANGE := 145.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 0
	prefix = "p%d_" % player_number
	player_color = Color("a9ee54") if player_number == 1 else Color("63baff")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = preload("res://assets/animations/finny.tres")
	sprite.scale = Vector2.ONE * 0.52
	sprite.position.y = -62
	if player_number == 2:
		var blue := ShaderMaterial.new()
		blue.shader = preload("res://assets/blue_finny.gdshader")
		sprite.material = blue
	add_child(sprite)
	sprite.frame_changed.connect(_on_attack_frame)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(-32, -103)
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("fill", arena.bar_style(player_color))
	health_bar.add_theme_stylebox_override("background", arena.bar_style(Color("17202b")))
	add_child(health_bar)
	health_bar.size = Vector2(64, 7)
	name_label = Label.new()
	name_label.position = Vector2(-55, -130)
	name_label.size = Vector2(110, 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", player_color)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 5)
	add_child(name_label)
	_update_health()

func _physics_process(delta: float) -> void:
	clock += delta
	hurt_time = maxf(0, hurt_time - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	swing_time = maxf(0, swing_time - delta)
	sprite.modulate = Color(1, 0.55, 0.55) if hurt_time > 0 and fmod(hurt_time, 0.15) > 0.075 else Color.WHITE
	if is_dead:
		velocity = Vector2.ZERO
		return
	if not arena.players_can_move():
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	if not is_attacking and direction != Vector2.ZERO:
		facing = direction.normalized()
		if absf(direction.x) > 0.05: sprite.flip_h = direction.x < 0
	if Input.is_action_just_pressed(prefix + "dash") and dash_cooldown <= 0 and not is_attacking:
		dash_direction = direction.normalized() if direction != Vector2.ZERO else facing
		dash_time = 0.18
		dash_cooldown = 1.2
	if dash_time > 0:
		dash_time = maxf(0, dash_time - delta)
		velocity = dash_direction * 630.0
		sprite.play("walk")
	elif is_attacking:
		velocity = Vector2.ZERO
	else:
		velocity = velocity.move_toward(direction * SPEED, 1800 * delta)
		if Input.is_action_pressed(prefix + "attack"):
			attack()
		else:
			sprite.speed_scale = 1.0
			sprite.play("walk" if velocity.length() > 8 else "idle")
	move_and_slide()
	arena.clamp_actor(self)
	if not is_attacking:
		sprite.scale.y = 0.52 + sin(clock * 2) * 0.006
	queue_redraw()

func attack() -> void:
	if is_dead or is_attacking or dash_time > 0 or not arena.players_can_move(): return
	is_attacking = true
	hit_done = false
	velocity = Vector2.ZERO
	sprite.speed_scale = 1.65
	sprite.play("show")
	sprite.set_frame_and_progress(0, 0)

func _on_attack_frame() -> void:
	if not is_attacking or is_dead or hit_done or sprite.frame != 2: return
	hit_done = true
	SoundFX.play_fire(player_number)
	swing_time = 0.18
	for enemy in arena.living_enemies():
		var offset: Vector2 = enemy.position - position
		if offset.length() <= ATTACK_RANGE and (offset.length() < 35 or offset.normalized().dot(facing) >= 0.15):
			enemy.take_damage(ATTACK_DAMAGE, facing)
	queue_redraw()

func _on_animation_finished() -> void:
	if sprite.animation == &"show" and not is_dead:
		is_attacking = false
		sprite.speed_scale = 1.0
		sprite.play("idle")

func take_damage(amount: int) -> void:
	if is_dead or hurt_time > 0 or dash_time > 0 or arena.state != arena.State.FIGHT: return
	health = maxi(0, health - amount)
	hurt_time = 0.6
	_update_health()
	if health == 0:
		is_dead = true
		is_attacking = false
		velocity = Vector2.ZERO
		sprite.stop()
		fall_tween = create_tween()
		fall_tween.tween_property(sprite, "rotation", 1.35, 0.25)
		_update_health()
		defeated.emit()

func recover_between_waves() -> void:
	if fall_tween != null and fall_tween.is_valid(): fall_tween.kill()
	if is_dead:
		health = 60
		is_dead = false
		sprite.rotation = 0
		sprite.play("idle")
	else:
		health = mini(100, health + 30)
	hurt_time = 0
	dash_time = 0
	is_attacking = false
	_update_health()

func _update_health() -> void:
	health_bar.value = health
	name_label.text = "P%d  DOWN" % player_number if is_dead else "P%d" % player_number
	health_changed.emit()

func _draw() -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var a := TAU * i / 32.0
		points.append(Vector2(cos(a) * 29, sin(a) * 9))
	draw_colored_polygon(points, Color(0.015, 0.01, 0.04, 0.55))
	draw_arc(Vector2.ZERO, 25, 0, TAU, 32, Color(player_color, 0.75), 2, true)
	if swing_time > 0:
		draw_arc(Vector2(0, -24), 100, facing.angle() - 1.2, facing.angle() + 1.2, 24, Color(player_color, swing_time / 0.18), 7, true)

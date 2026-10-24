extends CharacterBody2D

enum State { CHASE, WINDUP, RECOVER, DEAD }
@export_enum("Goblin", "Ogre", "Boss") var kind: int = 0
@export_range(1, 5) var raid_number: int = 1
var arena: Node2D
var sprite: AnimatedSprite2D
var health_bar: ProgressBar
var state: State = State.CHASE
var health: int = 50
var max_health: int = 50
var damage: int = 8
var speed: float = 105.0
var reach: float = 60.0
var windup: float = 0.55
var recovery: float = 0.7
var timer: float = 0.0
var hurt_time: float = 0.0
var knockback := Vector2.ZERO
var strike_position := Vector2.ZERO
var target: Node2D
var base_color := Color.WHITE
var is_dead: bool = false

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 0
	sprite = AnimatedSprite2D.new()
	var difficulty := clampi(raid_number - 1, 0, 4)
	max_health = 80 + 10 * difficulty
	damage = 10 + difficulty
	speed = 145.0 + 5.0 * difficulty
	windup = 0.48 - 0.02 * difficulty
	recovery = 0.45 - 0.025 * difficulty
	if kind == 0:
		var source := preload("res://level/costumers/goblin.tscn").instantiate()
		sprite.sprite_frames = source.get_node("AnimatedSprite2D").sprite_frames
		source.free()
		sprite.scale = Vector2.ONE * 0.21
	else:
		sprite.sprite_frames = preload("res://assets/animations/golem.tres")
		max_health = 220 + 20 * difficulty if kind == 1 else 1600
		damage = 22 + 2 * difficulty if kind == 1 else 44
		speed = 95 + 4 * difficulty if kind == 1 else 95
		reach = 78 if kind == 1 else 115
		windup = 0.75 - 0.025 * difficulty if kind == 1 else 0.85
		recovery = 0.75 - 0.04 * difficulty if kind == 1 else 0.7
		sprite.scale = Vector2.ONE * (0.55 if kind == 1 else 0.88)
		if kind == 2: base_color = Color("ffbd91")
	health = max_health
	add_child(sprite)
	sprite.play("idle")
	var texture := sprite.sprite_frames.get_frame_texture("idle", 0)
	sprite.position.y = -texture.get_height() * sprite.scale.y * 0.46875
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(-30, -65 if kind == 0 else -115)
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.add_theme_stylebox_override("background", arena.bar_style(Color("241727")))
	health_bar.add_theme_stylebox_override("fill", arena.bar_style(Color("ff8164")))
	add_child(health_bar)
	health_bar.size = Vector2(60, 6)
	if kind == 2:
		health_bar.hide()
	state = State.RECOVER
	timer = 1.0

func _physics_process(delta: float) -> void:
	if is_dead or arena.state != arena.State.FIGHT: return
	hurt_time = maxf(0, hurt_time - delta)
	sprite.modulate = Color(1.0, 0.4, 0.4) if hurt_time > 0 else base_color
	velocity = Vector2.ZERO
	match state:
		State.CHASE:
			target = find_target()
			if target == null: return
			var direction: Vector2 = target.position - position
			if direction.length() <= reach:
				_begin_attack()
			else:
				var separation := Vector2.ZERO
				for other in arena.living_enemies():
					if other == self: continue
					var offset: Vector2 = position - other.position
					if offset.length() < 45 and offset.length() > 0.1:
						separation += offset.normalized() * (45 - offset.length()) * 3
				velocity = direction.normalized() * speed + separation.limit_length(70)
				if absf(direction.x) > 1: sprite.flip_h = direction.x < 0
				sprite.speed_scale = 1.0
				sprite.play("run" if kind == 0 else "costumer1_walk")
		State.WINDUP:
			timer -= delta
			if timer <= 0:
				for player in arena.living_players():
					if player.position.distance_to(strike_position) <= reach:
						player.take_damage(damage)
				state = State.RECOVER
				timer = recovery
				sprite.speed_scale = 1.0
				sprite.play("idle" if kind == 0 else "recover")
		State.RECOVER:
			timer -= delta
			if timer <= 0: state = State.CHASE
	velocity += knockback
	knockback = knockback.move_toward(Vector2.ZERO, 650 * delta)
	move_and_slide()
	arena.clamp_actor(self)
	queue_redraw()

func find_target() -> Node2D:
	var nearest: Node2D
	var distance := INF
	for player in arena.living_players():
		var d: float = position.distance_squared_to(player.position)
		if d < distance:
			distance = d
			nearest = player
	return nearest

func _begin_attack() -> void:
	state = State.WINDUP
	timer = windup
	strike_position = target.position
	sprite.flip_h = target.position.x < position.x
	var animation: StringName = &"attack" if kind == 0 else &"upset"
	sprite.play(animation)
	sprite.set_frame_and_progress(0, 0)
	sprite.speed_scale = 4.0 / (windup * sprite.sprite_frames.get_animation_speed(animation))

func take_damage(amount: int, direction: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0: return
	health = maxi(0, health - amount)
	health_bar.value = health
	hurt_time = 0.16
	knockback = direction * (110 if kind != 2 else 25)
	if health == 0:
		is_dead = true
		state = State.DEAD
		velocity = Vector2.ZERO
		sprite.stop()
		health_bar.hide()
		queue_redraw()
		var fade := create_tween().set_parallel(true)
		fade.tween_property(sprite, "rotation", -1.2, 0.3)
		fade.tween_property(self, "modulate:a", 0.0, 0.4)
		fade.chain().tween_callback(queue_free)

func _draw() -> void:
	var points := PackedVector2Array()
	var width := 22.0 if kind == 0 else (35.0 if kind == 1 else 54.0)
	for i in range(32):
		var angle := TAU * i / 32.0
		points.append(Vector2(cos(angle) * width, sin(angle) * width * 0.27))
	draw_colored_polygon(points, Color(0.015, 0.01, 0.04, 0.6))
	if state == State.WINDUP:
		var local_center := strike_position - position
		draw_circle(local_center, reach, Color(1.0, 0.16, 0.1, 0.13))
		draw_arc(local_center, reach, 0, TAU, 48, Color("ffb279"), 2, true)
		draw_arc(local_center, reach - 4, -PI / 2, -PI / 2 + TAU * clampf(1 - timer / windup, 0, 1), 48, Color("ff5947"), 5, true)

extends CharacterBody2D

signal show_finished

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var game_over_label: Label = get_node_or_null("../UI/GameOverLabel")

@export var speed: float = 200.0
@export var acceleration: float = 1400.0
@export var friction: float = 1800.0

var is_doing_show: bool = false
var is_dead: bool = false
var health: int = 100
var hurt_time: float = 0.0


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")

	health_bar.max_value = 100
	health_bar.value = health

	if game_over_label != null:
		game_over_label.hide()

	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	hurt_time = maxf(0.0, hurt_time - delta)

	if not is_dead and hurt_time <= 0.0:
		sprite.modulate = Color.WHITE

	if is_doing_show or is_dead:
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	var change := friction if direction == Vector2.ZERO else acceleration

	velocity = velocity.move_toward(
		direction * speed,
		change * delta
	)

	move_and_slide()

	if absf(direction.x) > 0.1:
		sprite.flip_h = direction.x < 0

	animate_walk()


func animate_walk() -> void:
	if velocity.length() > 8.0:
		sprite.speed_scale = clampf(
			velocity.length() / speed,
			0.65,
			1.0
		)
		sprite.play("walk")
	else:
		sprite.speed_scale = 1.0
		sprite.play("idle")


func do_show() -> void:
	if is_doing_show or is_dead:
		return

	is_doing_show = true
	velocity = Vector2.ZERO

	sprite.speed_scale = 1.0
	sprite.play("show")

	await show_finished


func _on_animation_finished() -> void:
	if sprite.animation == &"show" and is_doing_show:
		is_doing_show = false
		sprite.play("idle")
		show_finished.emit()


func get_hit_position() -> Vector2:
	return $CollisionShape2D.global_position


func take_damage(amount: int) -> void:
	if is_dead or hurt_time > 0.0:
		return

	health = maxi(health - amount, 0)
	health_bar.value = health
	hurt_time = 0.25

	sprite.modulate = Color(1.0, 0.4, 0.4)

	if health == 0:
		is_dead = true
		velocity = Vector2.ZERO
		remove_from_group("damageable")

		get_tree().call_group("customer", "stop_for_game_over")
		get_tree().call_group("chest", "stop_for_game_over")

		if is_doing_show:
			is_doing_show = false
			show_finished.emit()

		sprite.stop()

		var fall := create_tween()
		fall.tween_property(sprite, "rotation_degrees", 80.0, 0.4)

		if game_over_label != null:
			game_over_label.text = "GAME OVER\nPress R to restart"
			game_over_label.show()


func interact() -> void:
	if is_dead or is_doing_show:
		return

	var nearby_customer: Node2D = null
	var nearest_distance: float = INF

	for customer in get_tree().get_nodes_in_group("customer"):
		if customer.current_state != customer.State.WAITING:
			continue

		if customer.finny != self:
			continue

		var distance := get_hit_position().distance_to(
			customer.body_shape.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearby_customer = customer

	if nearby_customer != null:
		nearby_customer.call("start_show")
		return

	var nearby_chest: Node2D = null
	nearest_distance = INF

	for chest in get_tree().get_nodes_in_group("chest"):
		if not chest.player_inside:
			continue

		if chest.is_broken or chest.game_over or chest.is_opening:
			continue

		var distance := get_hit_position().distance_to(
			chest.get_hit_position()
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearby_chest = chest

	if nearby_chest != null:
		nearby_chest.call("deposit")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if is_dead:
		if event.keycode == KEY_R:
			Economy.wallet = 0
			Economy.business_box = 0
			Economy.king_chest = 0
			get_tree().reload_current_scene()

	elif event.is_action_pressed("deposit"):
		interact()
		get_viewport().set_input_as_handled()

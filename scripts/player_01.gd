extends CharacterBody2D

signal show_finished

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var game_over_label: Label = get_node_or_null(
	"../../UI/GameOverLabel"
)

@export var speed: float = 200.0
@export var acceleration: float = 1400.0
@export var friction: float = 1800.0
@export var attack_damage: int = 25
@export var attack_range: float = 130.0

var is_doing_show: bool = false
var is_doing_action: bool = false
var is_sleeping: bool = false
var is_attacking: bool = false
var attack_hit_done: bool = false
var is_dead: bool = false
var health: int = 100
var hurt_time: float = 0.0
var initial_sprite_scale: Vector2


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")

	health_bar.max_value = 100
	health_bar.value = health

	if game_over_label != null:
		game_over_label.hide()

	initial_sprite_scale = sprite.scale
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_attack_frame_changed)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	hurt_time = maxf(0.0, hurt_time - delta)

	if not is_dead and hurt_time <= 0.0:
		sprite.modulate = Color.WHITE

	if is_doing_show or is_doing_action or is_attacking or is_dead or is_sleeping:
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
		sprite.flip_h = direction.x < 0.0

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


func attack() -> void:
	if is_dead or is_doing_show or is_doing_action or is_attacking or is_sleeping:
		return

	is_attacking = true
	attack_hit_done = false
	velocity = Vector2.ZERO

	# Usamos la animación existente para el ataque.
	sprite.speed_scale = 1.5
	sprite.play("show")


func _on_attack_frame_changed() -> void:
	if not is_attacking or is_dead or attack_hit_done:
		return

	if sprite.animation != &"show" or sprite.frame != 2:
		return

	attack_hit_done = true

	var facing := Vector2.LEFT if sprite.flip_h else Vector2.RIGHT

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue

		if enemy.is_queued_for_deletion():
			continue

		if not enemy.has_method("take_damage"):
			continue

		var shape := enemy.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D

		if shape == null:
			continue

		var direction := shape.global_position - get_hit_position()

		if direction.length() > attack_range:
			continue

		# Solo golpea a los enemigos que están delante.
		if direction.dot(facing) < 0.0:
			continue

		enemy.call("take_damage", attack_damage)


func play_collect_animation() -> void:
	await _play_action_animation("collect")

func _play_action_animation(animation_name: String) -> void:
	if is_dead or not sprite.sprite_frames.has_animation(animation_name):
		return
	is_doing_action = true
	velocity = Vector2.ZERO
	sprite.speed_scale = 1.0
	sprite.play(animation_name)
	await sprite.animation_finished
	if is_dead:
		return
	is_doing_action = false
	sprite.play("idle")

func walk_to_position(destination: Vector2) -> void:
	if is_dead:
		return
	is_sleeping = false
	is_doing_action = true
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.scale = initial_sprite_scale
	if absf(destination.x - global_position.x) > 1.0:
		sprite.flip_h = destination.x < global_position.x
	var distance := global_position.distance_to(destination)
	sprite.speed_scale = 1.0
	sprite.play("walk")
	var walk_tween := create_tween()
	walk_tween.tween_property(self, "global_position", destination, distance / 320.0)
	await walk_tween.finished
	if is_dead:
		return
	velocity = Vector2.ZERO
	is_doing_action = false
	sprite.speed_scale = 1.0
	sprite.play("idle")

func go_to_sleep() -> void:
	if is_dead:
		return
	is_sleeping = true
	velocity = Vector2.ZERO
	sprite.play("idle")
	sprite.rotation_degrees = 0.0
	sprite.modulate = Color(0.62, 0.74, 1.0)
	sprite.scale.y = initial_sprite_scale.y * 0.78

func wake_up() -> void:
	if is_dead:
		return
	is_sleeping = false
	sprite.rotation_degrees = 0.0
	sprite.modulate = Color.WHITE
	sprite.scale = initial_sprite_scale
	sprite.play("idle")

func do_show() -> void:
	if is_doing_show or is_doing_action or is_attacking or is_dead or is_sleeping:
		return

	is_doing_show = true
	velocity = Vector2.ZERO

	sprite.speed_scale = 1.0
	sprite.play("show")

	await show_finished


func _on_animation_finished() -> void:
	if is_dead or sprite.animation != &"show":
		return

	if is_attacking:
		is_attacking = false
		sprite.speed_scale = 1.0
		sprite.play("idle")
		return

	if is_doing_show:
		is_doing_show = false
		sprite.play("idle")
		show_finished.emit()


func get_hit_position() -> Vector2:
	return body_shape.global_position


func take_damage(amount: int) -> void:
	if is_dead or hurt_time > 0.0 or amount <= 0:
		return

	health = maxi(health - amount, 0)
	health_bar.value = health
	hurt_time = 0.25

	sprite.modulate = Color(1.0, 0.4, 0.4)

	if health == 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	velocity = Vector2.ZERO
	remove_from_group("damageable")

	get_tree().call_group("customer", "stop_for_game_over")
	get_tree().call_group("chest", "stop_for_game_over")
	get_tree().call_group("bandit", "stop_for_game_over")

	if is_doing_show:
		is_doing_show = false
		show_finished.emit()

	sprite.stop()

	var fall := create_tween()
	fall.tween_property(sprite, "rotation_degrees", 80.0, 0.4)

	if game_over_label != null:
		game_over_label.hide()


func interact() -> void:
	if is_dead or is_doing_show or is_doing_action or is_attacking or is_sleeping:
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
		do_deposit(nearby_chest)


func do_deposit(chest: Node) -> void:
	await _play_action_animation("deposit")
	if is_instance_valid(chest) and not is_dead:
		chest.call("deposit")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if is_dead:
		if event.keycode == KEY_R:
			get_viewport().set_input_as_handled()
			restart_game()
		return

	if event.is_action_pressed("Attack"):
		attack()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("deposit"):
		interact()
		get_viewport().set_input_as_handled()


func restart_game() -> void:
	Economy.wallet = 0
	Economy.business_box = 0
	Economy.king_chest = 0

	get_tree().reload_current_scene()

extends CharacterBody2D

signal paid(amount)
signal patience_changed(current, maximum)
signal left_without_paying

const CombatRange = preload("res://scripts/combat_range.gd")

const WITCH = preload("res://assets/animations/witch.tres")
const SKELETON = preload("res://assets/animations/skeleton.tres")
const GOLEM = preload("res://assets/animations/golem.tres")

const HELLO = [
	"Hi, Finny! Show me some magic!",
	"Make it quick!",
	"Entertain me. NOW!"
]

const THANKS = [
	"That was wonderful!",
	"Not bad. Here's your money.",
	"Good show. Take your money."
]

enum State {
	ARRIVING,
	SHOWING,
	WAITING,
	LEAVING,
	UPSET,
	CHASING,
	ATTACKING,
	RESTING,
	STOPPED
}

@export_enum("Witch", "Skeleton", "Golem") var customer_type: int = 0
@export var speed: float = 100.0
@export var acceleration: float = 650.0
@export var price: int = 100
@export var max_patience: float = 10.0
@export var wait_point: Vector2 = Vector2(500, 300)
@export var attack_cooldown: float = 0.8

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var patience_bar: ProgressBar = $PatienceBar
@onready var time_label: Label = $PatienceBar/TimeLabel
@onready var dialogue_panel: PanelContainer = $PanelContainer
@onready var dialogue_label: Label = $PanelContainer/DialogueLabel
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var current_state: State = State.ARRIVING
var patience: float
var spawn_position: Vector2

var finny: Node2D = null
var target: Node2D = null

var health: int = 100
var rest_time: float = 0.0
var strong_attack: bool = false
var hit_done: bool = false


func _ready() -> void:
	add_to_group("customer")

	match customer_type:
		0:
			animated_sprite.sprite_frames = WITCH
			max_patience = 10.0

		1:
			animated_sprite.sprite_frames = SKELETON
			max_patience = 5.0

		2:
			animated_sprite.sprite_frames = GOLEM
			max_patience = 3.0

	spawn_position = global_position
	patience = max_patience

	patience_bar.max_value = max_patience
	patience_bar.value = patience
	patience_bar.hide()

	time_label.text = str(ceili(patience)) + "s"
	hide_dialogue()

	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(
		_on_animation_finished
	)

	animated_sprite.play("idle")


func say(text: String) -> void:
	dialogue_label.text = text
	dialogue_panel.show()


func hide_dialogue() -> void:
	dialogue_label.text = ""
	dialogue_panel.hide()


func _physics_process(delta: float) -> void:
	match current_state:
		State.ARRIVING:
			arriving(delta)

		State.WAITING:
			waiting(delta)

		State.LEAVING:
			leaving(delta)

		State.CHASING:
			chasing(delta)

		State.RESTING:
			velocity = Vector2.ZERO
			rest_time -= delta

			if rest_time <= 0.0:
				current_state = State.CHASING

		_:
			velocity = Vector2.ZERO

	move_and_slide()


func move_towards(destination: Vector2, delta: float) -> bool:
	var distance := global_position.distance_to(destination)

	if distance < 4.0:
		velocity = Vector2.ZERO
		return true

	var direction := global_position.direction_to(destination)
	var arrival_speed := minf(speed, distance * 6.0)

	velocity = velocity.move_toward(
		direction * arrival_speed,
		acceleration * delta
	)

	animated_sprite.speed_scale = clampf(
		velocity.length() / speed,
		0.65,
		1.0
	)

	animated_sprite.play("costumer1_walk")

	if absf(direction.x) > 0.1:
		animated_sprite.flip_h = direction.x < 0.0

	return false


func arriving(delta: float) -> void:
	if move_towards(wait_point, delta):
		current_state = State.WAITING
		patience_bar.show()

		animated_sprite.speed_scale = 1.0
		animated_sprite.play("idle")


func waiting(delta: float) -> void:
	velocity = Vector2.ZERO
	patience = maxf(0.0, patience - delta)

	patience_bar.value = patience
	time_label.text = str(ceili(patience)) + "s"
	patience_changed.emit(patience, max_patience)

	if patience <= 0.0:
		leave_angry()


func start_show() -> void:
	if current_state != State.WAITING:
		return

	if not is_instance_valid(finny):
		return

	var performer = finny

	if performer.is_dead or performer.is_doing_show \
	or performer.is_attacking:
		return

	current_state = State.SHOWING
	patience_bar.hide()
	velocity = Vector2.ZERO

	say(HELLO[customer_type])

	animated_sprite.speed_scale = 1.0
	animated_sprite.play("costumer1_attack")

	await performer.do_show()

	if not is_instance_valid(performer):
		return

	if performer.is_dead or current_state == State.STOPPED:
		return

	Economy.earn(price)
	paid.emit(price)
	await performer.play_collect_animation()

	say(THANKS[customer_type])

	await get_tree().create_timer(1.5).timeout

	if current_state == State.STOPPED:
		return

	hide_dialogue()
	current_state = State.LEAVING


func leave_angry() -> void:
	velocity = Vector2.ZERO
	patience_bar.hide()
	left_without_paying.emit()

	match customer_type:
		0:
			current_state = State.LEAVING

		1:
			current_state = State.UPSET
			animated_sprite.speed_scale = 1.0
			animated_sprite.play("upset")

		2:
			add_to_group("enemy")
			say("I'll smash this place!")
			current_state = State.CHASING


func find_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF

	for body in get_tree().get_nodes_in_group("damageable"):
		if not body is Node2D:
			continue

		if not body.has_method("get_hit_position") \
		or not body.has_method("take_damage"):
			continue

		var hit_position: Vector2 = body.call("get_hit_position")
		var distance := body_shape.global_position.distance_to(
			hit_position
		)

		if distance < nearest_distance:
			nearest = body
			nearest_distance = distance

	return nearest


func chasing(delta: float) -> void:
	if not is_instance_valid(target):
		target = find_target()
	elif not target.is_in_group("damageable"):
		target = find_target()

	if target == null:
		current_state = State.LEAVING
		hide_dialogue()
		return

	var hit_position: Vector2 = target.call("get_hit_position")

	if CombatRange.can_reach(self, target, 20.0):
		velocity = Vector2.ZERO

		animated_sprite.flip_h = (
			hit_position.x < body_shape.global_position.x
		)

		current_state = State.ATTACKING
		hit_done = false

		say("BIG SMASH!" if strong_attack else "SMASH!")

		animated_sprite.speed_scale = (
			1.0 if strong_attack else 1.5
		)

		animated_sprite.play("upset")
	else:
		var offset := body_shape.global_position - global_position
		move_towards(hit_position - offset, delta)


func _on_frame_changed() -> void:
	if current_state != State.ATTACKING:
		return

	if animated_sprite.animation != &"upset":
		return

	# Aplica el daño en el quinto dibujo del golpe.
	if animated_sprite.frame != 4 or hit_done:
		return

	hit_done = true
	var damage := 20 if strong_attack else 10

	for body in get_tree().get_nodes_in_group("damageable"):
		if not body is Node2D:
			continue

		if not body.has_method("take_damage"):
			continue

		if CombatRange.can_reach(self, body, 35.0):
			body.call("take_damage", damage)

			if current_state == State.STOPPED:
				break


func _on_animation_finished() -> void:
	if current_state != State.UPSET \
	and current_state != State.ATTACKING:
		return

	if animated_sprite.animation == &"upset":
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("recover")

	elif animated_sprite.animation == &"recover":
		if current_state == State.UPSET:
			current_state = State.LEAVING
		else:
			strong_attack = not strong_attack
			current_state = State.RESTING
			rest_time = attack_cooldown
			target = null
			animated_sprite.play("idle")


func take_damage(amount: int) -> void:
	if customer_type != 2:
		return

	if not is_in_group("enemy"):
		return

	if current_state == State.STOPPED or health <= 0:
		return

	if amount <= 0:
		return

	health = maxi(health - amount, 0)

	if health == 0:
		stop_for_game_over()
		remove_from_group("enemy")
		queue_free()
		return

	animated_sprite.modulate = Color(1.0, 0.4, 0.4)

	var flash := create_tween()
	flash.tween_property(
		animated_sprite,
		"modulate",
		Color.WHITE,
		0.2
	)


func stop_for_game_over() -> void:
	current_state = State.STOPPED
	velocity = Vector2.ZERO

	patience_bar.hide()
	hide_dialogue()
	animated_sprite.stop()


func leaving(delta: float) -> void:
	collision_mask = 0

	if global_position.distance_to(spawn_position) < 12.0 \
	or move_towards(spawn_position, delta):
		queue_free()


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		finny = body


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == finny:
		finny = null

extends CharacterBody2D

const CombatRange = preload("res://scripts/combat_range.gd")

enum State {
	ESCORTING,
	CHASING,
	ATTACKING,
	RESTING,
	LEAVING,
	STOPPED
}

@export var speed: float = 120.0
@export var acceleration: float = 800.0
@export var damage: int = 5
@export var attack_cooldown: float = 1.2
@export var raid_duration: float = 18.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var leader = null
var escort_offset: Vector2 = Vector2.ZERO

var current_state: State = State.ESCORTING
var target: Node2D = null
var spawn_position: Vector2

var health: int = 50
var raid_time: float = 0.0
var rest_time: float = 0.0
var attack_time: float = 0.0
var hit_done: bool = false
var is_angry: bool = false


func _ready() -> void:
	preload("res://scripts/actor_grounding.gd").setup(self, sprite, body_shape, 0.27)
	add_to_group("bandit")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	spawn_position = global_position
	sprite.play("idle")

	# Los acompañantes no bloquean el movimiento del grupo.
	if is_instance_valid(leader):
		add_collision_exception_with(leader)
		leader.add_collision_exception_with(self)

	for other in get_tree().get_nodes_in_group("bandit"):
		if other != self and other is PhysicsBody2D:
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)


func _physics_process(delta: float) -> void:
	if current_state == State.STOPPED:
		return

	var player = get_tree().get_first_node_in_group("player")

	if is_instance_valid(player) and player.is_dead:
		stop_for_game_over()
		return

	if current_state != State.LEAVING:
		check_leader()

	if is_angry and current_state != State.LEAVING:
		raid_time += delta

		if raid_time >= raid_duration:
			start_leaving()

	match current_state:
		State.ESCORTING:
			escort(delta)

		State.CHASING:
			chase(delta)

		State.ATTACKING:
			update_attack(delta)

		State.RESTING:
			velocity = Vector2.ZERO
			rest_time -= delta

			if rest_time <= 0.0:
				target = null
				current_state = State.CHASING

		State.LEAVING:
			if global_position.distance_to(spawn_position) < 12.0:
				queue_free()
				return

			move_towards(spawn_position, delta, &"run")

	move_and_slide()
	if get_parent().has_method("ground_actor"):
		get_parent().ground_actor(self)


func check_leader() -> void:
	if not is_instance_valid(leader):
		start_leaving()
		return

	if leader.is_queued_for_deletion():
		start_leaving()
		return

	if leader.current_state == leader.State.LEAVING \
	or leader.current_state == leader.State.STOPPED:
		start_leaving()
		return

	if is_angry:
		return

	if leader.current_state == leader.State.CHASING \
	or leader.current_state == leader.State.ATTACKING \
	or leader.current_state == leader.State.RESTING:
		is_angry = true
		raid_time = 0.0
		add_to_group("enemy")
		current_state = State.CHASING


func escort(delta: float) -> void:
	if not is_instance_valid(leader):
		start_leaving()
		return

	var destination: Vector2 = (
		leader.body_shape.global_position + escort_offset
	)

	var offset := body_shape.global_position - global_position
	destination -= offset

	if global_position.distance_to(destination) < 12.0:
		velocity = Vector2.ZERO
		sprite.play("idle")
		return

	move_towards(destination, delta, &"walk")


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
			nearest_distance = distance
			nearest = body

	return nearest


func chase(delta: float) -> void:
	if not is_instance_valid(target):
		target = find_target()
	elif not target.is_in_group("damageable"):
		target = find_target()

	if target == null:
		start_leaving()
		return

	var hit_position: Vector2 = target.call("get_hit_position")

	if CombatRange.can_reach(self, target, 18.0):
		velocity = Vector2.ZERO
		sprite.flip_h = hit_position.x < body_shape.global_position.x

		current_state = State.ATTACKING
		attack_time = 0.0
		hit_done = false

		sprite.speed_scale = 1.0
		sprite.play("attack")
		sprite.set_frame_and_progress(0, 0.0)
	else:
		var offset := body_shape.global_position - global_position
		move_towards(hit_position - offset, delta, &"run")


func update_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	attack_time += delta

	if attack_time >= 0.35 and not hit_done:
		hit_done = true

		if is_instance_valid(target):
			if target.is_in_group("damageable"):
				if CombatRange.can_reach(self, target, 28.0):
					target.call("take_damage", damage)

	# El golpe puede haber causado el Game Over.
	if current_state == State.STOPPED:
		return

	if attack_time >= 0.7:
		current_state = State.RESTING
		rest_time = attack_cooldown
		sprite.play("idle")


func move_towards(
	destination: Vector2,
	delta: float,
	animation: StringName
) -> void:
	var direction := global_position.direction_to(destination)
	var distance := global_position.distance_to(destination)
	var movement_speed := minf(speed, distance * 6.0)

	velocity = velocity.move_toward(
		direction * movement_speed,
		acceleration * delta
	)

	if absf(direction.x) > 0.1:
		sprite.flip_h = direction.x < 0.0

	sprite.play(animation)


func start_leaving() -> void:
	remove_from_group("enemy")
	current_state = State.LEAVING
	target = null
	velocity = Vector2.ZERO

	collision_layer = 0
	collision_mask = 0
	sprite.play("run")


func take_damage(amount: int) -> void:
	if not is_angry:
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

	sprite.modulate = Color(1.0, 0.4, 0.4)

	var flash := create_tween()
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.2)


func stop_for_game_over() -> void:
	current_state = State.STOPPED
	velocity = Vector2.ZERO
	sprite.stop()

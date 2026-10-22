extends Node2D

signal day_started(day_number: int)
signal night_started(day_number: int)
signal game_finished(victory: bool)

const MAX_DAYS := 3

@export var customer_scenes: Array[PackedScene] = []
@export var spawn_point: Marker2D
@export var delay_between_customers: float = 2.0
@export var daily_customer_counts: Array[int] = [6, 8, 5]
@export var night_duration: float = 10.0
@export var camera_smoothness: float = 4.0
@export var camera_left_limit: float = 576.0
@export var camera_right_limit: float = 650.0
@export var goblin_scene: PackedScene
@export var group_attack_duration: float = 18.0

@onready var camera: Camera2D = $Camera2D
@onready var background_sprite: Sprite2D = $ParallaxBackground/Sprite2D

var camera_target: Node2D
var current_day: int = 1
var day_customer_count: int = 6
var customers_spawned_today: int = 0
var is_running: bool = false
var environment_tween: Tween

func _ready() -> void:
	camera.position = Vector2(576.0, 324.0)
	camera.make_current()
	$ParallaxBackground.scroll_scale = Vector2(0.28, 0.0)
	$ParallaxBackground.repeat_size = Vector2(1549.0, 0.0)

func _process(delta: float) -> void:
	if not is_instance_valid(camera_target):
		camera_target = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(camera_target):
		return

	var target_x := clampf(camera_target.global_position.x, camera_left_limit, camera_right_limit)
	var weight := 1.0 - exp(-camera_smoothness * delta)
	camera.position.x = lerpf(camera.position.x, target_x, weight)
	camera.position.y = 324.0

func start_game(start_day: int = 1, customers_already_spawned: int = 0) -> void:
	if is_running:
		return
	if customer_scenes.is_empty() or spawn_point == null:
		push_warning("Asigna clientes y SpawnPoint para iniciar el nivel.")
		return
	is_running = true
	_run_days(clampi(start_day, 1, MAX_DAYS), maxi(customers_already_spawned, 0))

func stop_game() -> void:
	is_running = false
	for customer in get_tree().get_nodes_in_group("customer"):
		if customer.get_parent() == self:
			customer.queue_free()
	for bandit in get_tree().get_nodes_in_group("bandit"):
		if bandit.get_parent() == self:
			bandit.queue_free()
	camera_target = get_tree().get_first_node_in_group("player") as Node2D
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("wake_up"):
		player.wake_up()
	set_night(false)

func get_save_progress() -> Dictionary:
	return {
		"day": current_day,
		"customers_spawned": customers_spawned_today
	}

func game_has_ended() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	return not is_instance_valid(player) or player.is_dead

func _run_days(start_day: int, customers_already_spawned: int) -> void:
	for day_number in range(start_day, MAX_DAYS + 1):
		if not is_running or game_has_ended():
			return

		current_day = day_number
		customers_spawned_today = customers_already_spawned if day_number == start_day else 0
		day_customer_count = daily_customer_counts[day_number - 1] if daily_customer_counts.size() >= day_number else 3
		customers_already_spawned = 0
		day_started.emit(current_day)
		set_night(false)
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.has_method("wake_up"):
			player.wake_up()

		for customer_index in range(customers_spawned_today, day_customer_count):
			if not is_running or game_has_ended():
				return

			var scene_index := customer_index % customer_scenes.size()
			if customer_scenes.size() >= 3:
				scene_index = 2 if customer_index == day_customer_count - 1 else customer_index % 2
			var scene: PackedScene = customer_scenes[scene_index]
			if scene == null:
				push_warning("Hay una escena de cliente vacia.")
				continue

			var customer = scene.instantiate()
			add_child(customer)
			customer.global_position = spawn_point.global_position
			customer.spawn_position = spawn_point.global_position
			customers_spawned_today = customer_index + 1
			camera_target = customer

			if customer.customer_type == 2 and customer_index == day_customer_count - 1:
				prepare_ogre_group(customer)

			while is_running and is_instance_valid(customer) and not game_has_ended():
				await get_tree().process_frame
			if not is_running or game_has_ended():
				return

			camera_target = get_tree().get_first_node_in_group("player") as Node2D
			while is_running and get_tree().get_nodes_in_group("bandit").size() > 0:
				if game_has_ended():
					return
				await get_tree().process_frame

			if customer_index < day_customer_count - 1:
				await get_tree().create_timer(maxf(delay_between_customers, 0.1), false).timeout

		night_started.emit(current_day)
		set_night(true)
		player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.has_method("go_to_sleep"):
			player.go_to_sleep()
		await get_tree().create_timer(maxf(night_duration, 1.0), false).timeout
		if not is_running or game_has_ended():
			return

		if day_number == MAX_DAYS:
			is_running = false
			game_finished.emit(Economy.goal_reached())
			return

func set_night(is_night: bool) -> void:
	if is_instance_valid(environment_tween) and environment_tween.is_running():
		environment_tween.kill()
	environment_tween = create_tween()
	var color := Color(0.48, 0.54, 0.78, 1.0) if is_night else Color.WHITE
	environment_tween.tween_property(background_sprite, "modulate", color, 1.2)

func prepare_ogre_group(ogre: Node2D) -> void:
	ogre.max_patience = 3.0
	ogre.patience = 3.0
	ogre.patience_bar.max_value = 3.0
	ogre.patience_bar.value = 3.0
	ogre.time_label.text = "3s"

	if goblin_scene != null:
		spawn_goblin(ogre, Vector2(-110, -110))
		spawn_goblin(ogre, Vector2(-110, 110))
	watch_ogre(ogre)

func spawn_goblin(ogre: Node2D, offset: Vector2) -> void:
	var goblin = goblin_scene.instantiate()
	goblin.leader = ogre
	goblin.escort_offset = offset
	goblin.raid_duration = maxf(group_attack_duration, 1.0)
	add_child(goblin)
	goblin.global_position = spawn_point.global_position + offset

func watch_ogre(ogre: Node2D) -> void:
	while is_running and is_instance_valid(ogre):
		if ogre.is_queued_for_deletion() or game_has_ended():
			return
		if ogre.current_state == ogre.State.LEAVING:
			return
		if ogre.current_state == ogre.State.CHASING \
		or ogre.current_state == ogre.State.ATTACKING \
		or ogre.current_state == ogre.State.RESTING:
			finish_ogre_attack(ogre)
			return
		await get_tree().process_frame

func finish_ogre_attack(ogre: Node2D) -> void:
	await get_tree().create_timer(maxf(group_attack_duration, 1.0), false).timeout
	if not is_instance_valid(ogre) or ogre.is_queued_for_deletion() or game_has_ended():
		return
	ogre.target = null
	ogre.velocity = Vector2.ZERO
	ogre.hide_dialogue()
	ogre.animated_sprite.speed_scale = 1.0
	ogre.current_state = ogre.State.LEAVING
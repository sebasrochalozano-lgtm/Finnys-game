extends Node2D

signal day_started(day_number: int)
signal night_started(day_number: int)
signal game_finished(victory: bool)

const MAX_DAYS := 3

enum Location { LOBBY, PASSAGE, ROOM }
const EDGE_LEFT := 18.0
const EDGE_RIGHT := 1134.0
const PASSAGE_FLOOR_Y := 500.0
const ROOM_DOOR_X := 190.0

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
@export var shop_position: Vector2 = Vector2(96.0, 348.0)
@export var vault_position: Vector2 = Vector2(575.0, 500.0)

@onready var camera: Camera2D = $Camera2D
@onready var background_sprite: Sprite2D = $ParallaxBackground/Sprite2D
@onready var passage_sprite: Sprite2D = $ParallaxPassage/PassageArt
@onready var vault_sprite: Sprite2D = $ParallaxVault/VaultArt
@onready var lobby_layer: Parallax2D = $ParallaxBackground
@onready var passage_layer: Parallax2D = $ParallaxPassage
@onready var vault_layer: Parallax2D = $ParallaxVault
@onready var king_chest: Area2D = $ChestKing
@onready var business_chest: Area2D = $ChestBusiness
@onready var king_chest_area_shape: CollisionShape2D = $ChestKing/CollisionShape2D
@onready var king_chest_block_shape: CollisionShape2D = $ChestKing/StaticBody2D/CollisionShape2D
@onready var business_chest_area_shape: CollisionShape2D = $ChestBusiness/CollisionShape2D
@onready var business_chest_block_shape: CollisionShape2D = $ChestBusiness/StaticBody2D/CollisionShape2D

var camera_target: Node2D
var current_day: int = 1
var day_customer_count: int = 6
var customers_spawned_today: int = 0
var is_running: bool = false
var environment_tween: Tween
var current_location: Location = Location.LOBBY
var shop_is_open: bool = false
var passage_unlocked: bool = false
var scripted_route: bool = false
var transition_lock: float = 0.0

func _ready() -> void:
	camera.position = Vector2(576.0, 324.0)
	camera.make_current()
	lobby_layer.scroll_scale = Vector2(0.28, 0.0)
	lobby_layer.repeat_size = Vector2(1549.0, 0.0)
	passage_layer.scroll_scale = Vector2(0.28, 0.0)
	vault_layer.scroll_scale = Vector2(0.28, 0.0)
	_show_location(Location.LOBBY)

func _process(delta: float) -> void:
	if not is_instance_valid(camera_target):
		camera_target = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(camera_target):
		var target_x := clampf(camera_target.global_position.x, camera_left_limit, camera_right_limit)
		var weight := 1.0 - exp(-camera_smoothness * delta)
		camera.position.x = lerpf(camera.position.x, target_x, weight)
		camera.position.y = 324.0

	if scripted_route:
		return
	if transition_lock > 0.0:
		transition_lock = maxf(transition_lock - delta, 0.0)
		if transition_lock == 0.0:
			transition_lock = -1.0
		return
	if transition_lock < 0.0:
		var direction_held := Input.is_action_pressed("move_left") \
			or Input.is_action_pressed("move_right") \
			or Input.is_action_pressed("move_up") \
			or Input.is_action_pressed("move_down")
		if not direction_held:
			var locked_player = get_tree().get_first_node_in_group("player")
			if is_instance_valid(locked_player):
				locked_player.is_doing_action = false
			transition_lock = 0.0
		return
	if scripted_route:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or player.is_dead or player.is_doing_action or player.is_sleeping:
		return
	if shop_is_open and current_location == Location.LOBBY:
		player.global_position.x = maxf(player.global_position.x, EDGE_LEFT)
		return

	match current_location:
		Location.LOBBY:
			if player.global_position.x <= EDGE_LEFT:
				if passage_unlocked and not shop_is_open:
					passage_unlocked = false
					_change_location(Location.PASSAGE, Vector2(EDGE_RIGHT, PASSAGE_FLOOR_Y), true)
				else:
					player.global_position.x = EDGE_LEFT
		Location.PASSAGE:
			if player.global_position.x >= EDGE_RIGHT:
				_change_location(Location.LOBBY, Vector2(EDGE_LEFT, shop_position.y), true)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or player.is_dead or player.is_doing_action or player.is_sleeping:
		return

	if event.keycode == KEY_A and current_location == Location.LOBBY:
		passage_unlocked = true
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_W and current_location == Location.PASSAGE \
	and player.global_position.x <= ROOM_DOOR_X:
		_change_location(Location.ROOM, Vector2(110.0, PASSAGE_FLOOR_Y), true)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_S and current_location == Location.ROOM \
	and player.global_position.x <= ROOM_DOOR_X:
		_change_location(Location.PASSAGE, Vector2(EDGE_LEFT, PASSAGE_FLOOR_Y), true)
		get_viewport().set_input_as_handled()

func start_game(start_day: int = 1, customers_already_spawned: int = 0) -> void:
	if is_running:
		return
	if customer_scenes.is_empty() or spawn_point == null:
		push_warning("Asigna clientes y SpawnPoint para iniciar el nivel.")
		return
	is_running = true
	shop_is_open = false
	passage_unlocked = false
	_show_location(Location.LOBBY)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		player.global_position = shop_position
	_run_days(clampi(start_day, 1, MAX_DAYS), maxi(customers_already_spawned, 0))

func stop_game() -> void:
	is_running = false
	shop_is_open = false
	passage_unlocked = false
	scripted_route = false
	transition_lock = 0.0
	_show_location(Location.LOBBY)
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
	if is_instance_valid(player):
		player.global_position = shop_position
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
		await _walk_finny_to(shop_position)
		if not is_running or game_has_ended():
			return
		shop_is_open = true

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

		shop_is_open = false
		night_started.emit(current_day)
		set_night(true)
		var entered_room_for_night := current_location == Location.ROOM
		while is_running and not entered_room_for_night and not game_has_ended():
			await get_tree().process_frame
			entered_room_for_night = current_location == Location.ROOM
		if not is_running or game_has_ended():
			return
		var night_time := maxf(night_duration, 1.0)
		var decision_time := minf(5.0, night_time * 0.5)
		await get_tree().create_timer(decision_time, false).timeout
		player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.has_method("go_to_sleep"):
			player.go_to_sleep()
		await get_tree().create_timer(maxf(night_time - decision_time, 0.5), false).timeout
		if not is_running or game_has_ended():
			return

		if day_number == MAX_DAYS:
			is_running = false
			game_finished.emit(Economy.goal_reached())
			return

func _walk_finny_to(destination: Vector2) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return
	scripted_route = true
	transition_lock = 0.0
	player.is_doing_action = false
	camera_target = player
	if current_location == Location.ROOM:
		await player.call("walk_to_position", Vector2(EDGE_LEFT, PASSAGE_FLOOR_Y))
		_change_location(Location.PASSAGE, Vector2(EDGE_LEFT, PASSAGE_FLOOR_Y))
	if current_location == Location.PASSAGE:
		await player.call("walk_to_position", Vector2(EDGE_RIGHT, PASSAGE_FLOOR_Y))
		_change_location(Location.LOBBY, Vector2(EDGE_LEFT, shop_position.y))
	await player.call("walk_to_position", destination)
	scripted_route = false

func _show_location(location: Location) -> void:
	current_location = location
	lobby_layer.visible = location == Location.LOBBY
	passage_layer.visible = location == Location.PASSAGE
	vault_layer.visible = location == Location.ROOM
	king_chest.visible = location == Location.ROOM
	king_chest.monitoring = location == Location.ROOM
	business_chest.visible = location == Location.ROOM
	business_chest.monitoring = location == Location.ROOM
	king_chest_area_shape.disabled = location != Location.ROOM
	king_chest_block_shape.disabled = location != Location.ROOM
	business_chest_area_shape.disabled = location != Location.ROOM
	business_chest_block_shape.disabled = location != Location.ROOM
	if location != Location.ROOM:
		king_chest.player_inside = false
		business_chest.player_inside = false

func _change_location(location: Location, player_position: Vector2, lock_controls: bool = false) -> void:
	_show_location(location)
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		player.global_position = player_position
		player.velocity = Vector2.ZERO
		if lock_controls:
			player.is_doing_action = true
			transition_lock = 0.45
	camera_target = player
	camera.position = Vector2(576.0, 324.0)

func set_night(is_night: bool) -> void:
	if is_instance_valid(environment_tween) and environment_tween.is_running():
		environment_tween.kill()
	environment_tween = create_tween()
	var color := Color(0.48, 0.54, 0.78, 1.0) if is_night else Color.WHITE
	for layer in [background_sprite, passage_sprite, vault_sprite]:
		environment_tween.parallel().tween_property(layer, "modulate", color, 1.2)

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

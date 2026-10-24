extends Node2D
signal day_started(day_number: int)
signal night_started(day_number: int)
signal game_finished(victory: bool)
const ActorSave = preload("res://scripts/actor_save.gd")
enum Location { LOBBY, PASSAGE, ROOM }
enum Phase { OPENING, BETWEEN, CUSTOMER, NIGHT, EVENT, RESTING, FINISHED }
@export var customer_scenes: Array[PackedScene] = []
@export var spawn_point: Marker2D
@export var goblin_scene: PackedScene
@export var delay_between_customers: float = 2.0
@export var daily_customer_counts: Array[int] = [6, 8, 5]
@onready var camera: Camera2D = $Camera2D
@onready var background_sprite: Sprite2D = $ParallaxBackground/Sprite2D
@onready var passage_sprite: Sprite2D = $ParallaxPassage/PassageArt
@onready var vault_sprite: Sprite2D = $ParallaxVault/VaultArt
@onready var king_chest: Area2D = $ChestKing
@onready var business_chest: Area2D = $ChestBusiness
var host: Node
var current_day: int = 1
var day_customer_count: int = 6
var customers_spawned_today: int = 0
var next_customer: int = 0
var is_running: bool = false
var current_location: Location = Location.LOBBY
var phase: Phase = Phase.FINISHED
var shop_is_open: bool = false
var is_night: bool = false
var wait_time: float = 0
var active_customer: Node2D
var environment_tween: Tween
var extent := Vector2(1152, 648)
var shop_position := Vector2(460, 520)
var wait_point := Vector2(600, 520)
var door_left: Label
var door_right: Label
var wages_message: String = ""
var stage: Node2D

func get_level_number() -> int:
	return 1

func last_day() -> int:
	return 3 if get_level_number() == 1 else 7

func _ready() -> void:
	camera.make_current()
	for layer in [$ParallaxBackground, $ParallaxPassage, $ParallaxVault]:
		layer.scroll_scale = Vector2.ONE
		layer.repeat_size = Vector2.ZERO
		layer.follow_viewport = false
	for chest in [king_chest, business_chest]:
		chest.sprite.position = Vector2(0, -55)
		chest.sprite.offset = Vector2.ZERO
		chest.get_node("CollisionShape2D").position = Vector2(0, -20)
		chest.get_node("StaticBody2D").position = Vector2(0, -15)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(60, 24)
		chest.get_node("StaticBody2D/CollisionShape2D").shape = shape
		var tag := Label.new()
		tag.text = "KING'S CHEST" if chest.chest_type == 0 else "BUSINESS RESERVE"
		tag.position = Vector2(-95, 12)
		tag.size = Vector2(190, 30)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_color_override("font_shadow_color", Color.BLACK)
		chest.add_child(tag)
	door_left = _make_sign()
	door_right = _make_sign()
	get_viewport().size_changed.connect(_resize_world)
	_resize_world()
	_show_location(Location.LOBBY)

func _make_sign() -> Label:
	var label := Label.new()
	label.size = Vector2(200, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("ffe6a4"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_outline_size", 5)
	label.z_index = 10
	add_child(label)
	return label

func _resize_world() -> void:
	var old_extent := extent
	extent = get_viewport_rect().size
	if extent.x < 1 or extent.y < 1:
		extent = Vector2(1152, 648)
	camera.position = extent * 0.5
	camera.position_smoothing_enabled = false
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = ceili(extent.x)
	camera.limit_bottom = ceili(extent.y)
	for art in [background_sprite, passage_sprite, vault_sprite]:
		var factor := maxf(extent.x / art.texture.get_width(), extent.y / art.texture.get_height()) * 1.015
		art.scale = Vector2.ONE * factor
		art.position = (extent - art.texture.get_size() * factor) * 0.5
	# Keep the doorway visible even on 4:3 screens; derive its spawn from the art.
	background_sprite.position.x = extent.x - background_sprite.texture.get_width() * background_sprite.scale.x
	spawn_point.position = background_sprite.position + background_sprite.texture.get_size() * background_sprite.scale * Vector2(0.91, 0.73)
	wait_point = extent * Vector2(0.53, 0.80)
	shop_position = extent * Vector2(0.39, 0.80)
	king_chest.position = extent * Vector2(0.36, 0.81)
	business_chest.position = extent * Vector2(0.75, 0.81)
	door_left.position = Vector2(12, extent.y * 0.65)
	door_right.position = Vector2(extent.x - 212, extent.y * 0.65)
	if is_instance_valid(stage):
		stage.position = extent * Vector2(0.65, 0.80)
	for group in ["player", "customer", "bandit", "royal_hero"]:
		for actor in get_tree().get_nodes_in_group(group):
			if actor.get_parent() != self:
				continue
			actor.position = actor.position / old_extent * extent
			if group in ["customer", "bandit"]:
				actor.spawn_position = spawn_point.position
			if group == "customer":
				actor.wait_point = wait_point
			elif group == "royal_hero":
				actor.destination = extent * Vector2(0.65, 0.80)
	queue_redraw()

func ground_actor(actor: CharacterBody2D) -> void:
	actor.position.x = clampf(actor.position.x, 55, extent.x - 55)
	actor.position.y = clampf(actor.position.y, extent.y * 0.72, extent.y * 0.89)

func _process(delta: float) -> void:
	if not is_running or game_has_ended():
		return
	if phase == Phase.BETWEEN:
		wait_time -= delta
		if wait_time <= 0:
			prepare_next_customer()
	elif phase == Phase.CUSTOMER:
		if not is_instance_valid(active_customer) and get_tree().get_nodes_in_group("bandit").is_empty():
			next_customer += 1
			phase = Phase.BETWEEN
			wait_time = delay_between_customers

func get_player():
	return get_tree().get_first_node_in_group("player")

func game_has_ended() -> bool:
	var player = get_player()
	return not is_instance_valid(player) or player.is_dead

func start_game(start_day: int = 1, _already_spawned: int = 0, saved: Dictionary = {}) -> void:
	if is_running:
		return
	is_running = true
	if not saved.is_empty():
		restore_progress(saved)
		return
	current_day = clampi(start_day, 1 if get_level_number() == 1 else 4, last_day())
	begin_day(true)

func begin_day(first_entry: bool = false) -> void:
	phase = Phase.OPENING
	Economy.level_number = get_level_number()
	Economy.start_day(current_day)
	day_customer_count = daily_customer_counts[current_day - 1 if get_level_number() == 1 else current_day - 4]
	next_customer = 0
	customers_spawned_today = 0
	shop_is_open = true
	set_night(false)
	_show_location(Location.LOBBY)
	var player = get_player()
	player.wake_up()
	player.position = spawn_point.position if first_entry else Vector2(100, extent.y * 0.80)
	day_started.emit(current_day)
	await player.walk_to_position(shop_position)
	if not is_running:
		return
	await day_events()
	if not is_running:
		return
	phase = Phase.BETWEEN
	wait_time = 0.8
	if is_instance_valid(host):
		host.autosave()

func day_events() -> void:
	pass

func before_customer(_index: int) -> String:
	return "cash"

func prepare_next_customer() -> void:
	phase = Phase.EVENT
	if next_customer >= day_customer_count:
		begin_night()
		return
	var payment_mode: String = await before_customer(next_customer)
	if not is_running:
		return
	if payment_mode == "closed":
		begin_night()
		return
	customers_spawned_today = next_customer + 1
	if payment_mode == "skip":
		next_customer += 1
		phase = Phase.BETWEEN
		wait_time = 0.5
		return
	var scene_index := 2 if next_customer == day_customer_count - 1 else next_customer % 2
	active_customer = spawn_customer(scene_index, payment_mode)
	if scene_index == 2:
		spawn_goblin(active_customer, Vector2(75, -24))
		spawn_goblin(active_customer, Vector2(75, 30))
	phase = Phase.CUSTOMER

func spawn_customer(scene_index: int, payment_mode: String):
	var customer = customer_scenes[scene_index].instantiate()
	customer.position = spawn_point.position
	customer.wait_point = wait_point
	customer.speed = 145.0
	customer.payment_mode = payment_mode
	add_child(customer)
	customer.spawn_position = spawn_point.position
	customer.add_collision_exception_with(get_player())
	get_player().add_collision_exception_with(customer)
	return customer

func spawn_goblin(ogre: Node2D, offset: Vector2):
	var goblin = goblin_scene.instantiate()
	goblin.leader = ogre
	goblin.escort_offset = offset
	goblin.position = spawn_point.position
	add_child(goblin)
	goblin.spawn_position = spawn_point.position
	return goblin

func begin_night() -> void:
	shop_is_open = false
	phase = Phase.NIGHT
	wages_message = Economy.pay_wages() if get_level_number() == 2 else ""
	set_night(true)
	_update_signs()
	night_started.emit(current_day)
	if is_instance_valid(host):
		host.toast("Nightfall. Walk left and press E for the passage. Rest in your room.")
		host.autosave()

func interact_environment() -> bool:
	if not is_running or phase in [Phase.OPENING, Phase.RESTING, Phase.EVENT]:
		return false
	var x: float = get_player().position.x
	match current_location:
		Location.LOBBY:
			if x < 170:
				if not shop_is_open:
					_change_location(Location.PASSAGE, Vector2(extent.x - 115, extent.y * 0.80))
				else:
					host.toast("The passage opens when today's customers have left.")
				return true
		Location.PASSAGE:
			if x < 170:
				_change_location(Location.ROOM, Vector2(120, extent.y * 0.80))
				return true
			if x > extent.x - 170:
				_change_location(Location.LOBBY, Vector2(120, extent.y * 0.80))
				return true
		Location.ROOM:
			if x < 170:
				_change_location(Location.PASSAGE, Vector2(120, extent.y * 0.80))
				return true
			if absf(x - extent.x * 0.55) < 75 and phase == Phase.NIGHT:
				finish_night()
				return true
	return false

func finish_night() -> void:
	if phase != Phase.NIGHT or current_location != Location.ROOM:
		return
	phase = Phase.EVENT
	await host.night_summary(self)
	if not is_running:
		return
	phase = Phase.RESTING
	get_player().go_to_sleep()
	await get_tree().create_timer(1.8, false).timeout
	if not is_running:
		return
	get_player().wake_up()
	if current_day == last_day():
		phase = Phase.FINISHED
		is_running = false
		game_finished.emit(Economy.goal_reached())
	else:
		current_day += 1
		begin_day()

func _show_location(location: Location) -> void:
	current_location = location
	$ParallaxBackground.visible = location == Location.LOBBY
	$ParallaxPassage.visible = location == Location.PASSAGE
	$ParallaxVault.visible = location == Location.ROOM
	for chest in [king_chest, business_chest]:
		var active := location == Location.ROOM
		chest.visible = active
		chest.monitoring = active
		chest.get_node("CollisionShape2D").set_deferred("disabled", not active)
		chest.get_node("StaticBody2D/CollisionShape2D").set_deferred("disabled", not active)
		chest.player_inside = false
		if active and not chest.is_broken:
			chest.add_to_group("damageable")
		else:
			chest.remove_from_group("damageable")
	if is_instance_valid(stage):
		stage.visible = location == Location.LOBBY
	_update_signs()
	queue_redraw()

func _update_signs() -> void:
	door_left.text = "PASSAGE\n[E] after closing" if current_location == Location.LOBBY and shop_is_open else ("[E] PASSAGE" if current_location != Location.PASSAGE else "[E] ROOM")
	door_right.text = "CAVE ENTRANCE" if current_location == Location.LOBBY else ("[E] SHOW HALL" if current_location == Location.PASSAGE else "")

func _change_location(location: Location, player_position: Vector2) -> void:
	_show_location(location)
	var player = get_player()
	player.position = player_position
	player.velocity = Vector2.ZERO
	player.is_doing_action = false
	if is_instance_valid(host):
		host.toast(["Show hall", "Interior passage - walk left to your room", "Your room - E by a chest to deposit; E at the bed to rest"][location])

func set_night(value: bool) -> void:
	is_night = value
	if is_instance_valid(environment_tween):
		environment_tween.kill()
	environment_tween = create_tween()
	var color := Color(0.50, 0.58, 0.84) if value else Color.WHITE
	for art in [background_sprite, passage_sprite, vault_sprite]:
		environment_tween.parallel().tween_property(art, "modulate", color, 1.8)

func _draw() -> void:
	if current_location == Location.ROOM:
		var bed := extent * Vector2(0.55, 0.83)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("345d65")
		style.border_color = Color("9e7850")
		style.set_border_width_all(5)
		style.set_corner_radius_all(10)
		draw_style_box(style, Rect2(bed - Vector2(70, 30), Vector2(140, 60)))
		draw_rect(Rect2(bed - Vector2(55, 20), Vector2(30, 40)), Color("c6cfaf"))
		draw_string(ThemeDB.fallback_font, bed + Vector2(-47, 55), "[E] REST", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffe4ab"))

func is_save_safe() -> bool:
	if not is_running or phase not in [Phase.BETWEEN, Phase.CUSTOMER, Phase.NIGHT]:
		return false
	var player = get_player()
	if player.is_doing_show or player.is_doing_action or player.is_attacking or player.is_dead:
		return false
	if is_instance_valid(active_customer) and active_customer.current_state == active_customer.State.SHOWING:
		return false
	for chest in [king_chest, business_chest]:
		if chest.is_opening:
			return false
	return true

func get_save_progress() -> Dictionary:
	var player = get_player()
	var data := {"day":current_day, "next_customer":next_customer, "customers_spawned":customers_spawned_today, "phase":phase, "location":current_location, "night":is_night, "wait_time":wait_time, "wages_message":wages_message, "player_position":player.position / extent, "player_health":player.health, "player_flip":player.sprite.flip_h, "player_hurt":player.hurt_time, "goblins":[], "chests":[]}
	if is_instance_valid(active_customer):
		data["customer"] = ActorSave.capture(active_customer, ActorSave.CUSTOMER_FIELDS, extent)
	for goblin in get_tree().get_nodes_in_group("bandit"):
		data.goblins.append(ActorSave.capture(goblin, ActorSave.GOBLIN_FIELDS, extent))
	for chest in [king_chest, business_chest]:
		data.chests.append({"health":chest.health, "broken":chest.is_broken})
	return data

func restore_progress(data: Dictionary) -> void:
	current_day = int(data.get("day", 1))
	day_customer_count = daily_customer_counts[current_day - 1 if get_level_number() == 1 else current_day - 4]
	next_customer = int(data.get("next_customer", 0))
	customers_spawned_today = int(data.get("customers_spawned", 0))
	phase = int(data.get("phase", Phase.BETWEEN)) as Phase
	wait_time = float(data.get("wait_time", 0))
	wages_message = str(data.get("wages_message", ""))
	shop_is_open = not bool(data.get("night", false))
	_show_location(int(data.get("location", 0)) as Location)
	set_night(not shop_is_open)
	var player = get_player()
	player.position = data.get("player_position", Vector2(0.39, 0.8)) * extent
	player.health = int(data.get("player_health", 100))
	player.health_bar.value = player.health
	player.sprite.flip_h = bool(data.get("player_flip", false))
	player.hurt_time = float(data.get("player_hurt", 0))
	if data.has("customer"):
		var saved: Dictionary = data.customer
		active_customer = spawn_customer(int(saved.customer_type), str(saved.payment_mode))
		ActorSave.restore(active_customer, ActorSave.CUSTOMER_FIELDS, saved, extent)
		active_customer.patience_bar.visible = active_customer.current_state == active_customer.State.WAITING
		active_customer.patience_bar.value = active_customer.patience
		active_customer.target = player
	for saved in data.get("goblins", []):
		var goblin = spawn_goblin(active_customer, saved.escort_offset)
		ActorSave.restore(goblin, ActorSave.GOBLIN_FIELDS, saved, extent)
		goblin.target = player
	for i in range(data.get("chests", []).size()):
		var chest = [king_chest, business_chest][i]
		chest.health = int(data.chests[i].health)
		chest.is_broken = bool(data.chests[i].broken)
		chest.health_bar.value = chest.health
		if chest.is_broken:
			chest.remove_from_group("damageable")
			chest.sprite.modulate = Color(0.4, 0.4, 0.4)
	if is_night:
		night_started.emit(current_day)
	else:
		day_started.emit(current_day)

func stop_game() -> void:
	is_running = false
	phase = Phase.FINISHED
	shop_is_open = false
	for group in ["customer", "bandit", "royal_hero"]:
		for actor in get_tree().get_nodes_in_group(group):
			if actor.get_parent() == self:
				actor.stop_for_game_over()
				actor.queue_free()

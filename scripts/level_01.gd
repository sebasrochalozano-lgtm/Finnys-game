extends Node2D

@export var customer_scenes: Array[PackedScene] = []
@export var spawn_point: Marker2D
@export var delay_between_customers: float = 3.0
@export var camera_smoothness: float = 4.0
@export var camera_left_limit: float = 576.0
@export var camera_right_limit: float = 732.0

@onready var camera: Camera2D = $Camera2D

var camera_target: Node2D

@export var goblin_scene: PackedScene
@export var group_attack_duration: float = 18.0


func _ready() -> void:
	if spawn_point == null:
		push_warning("Asigna Spawn Point.")
		return

	if customer_scenes.is_empty():
		push_warning("Asigna Customer Scenes.")
		return

	spawn_loop()


func game_has_ended() -> bool:
	var player = get_tree().get_first_node_in_group("player")

	if not is_instance_valid(player):
		return true

	return player.is_dead


func spawn_loop() -> void:
	var index: int = 0

	while is_inside_tree():
		if game_has_ended():
			return

		var scene: PackedScene = customer_scenes[
			index % customer_scenes.size()
		]

		if scene == null:
			push_warning("Hay una escena de cliente vacia.")
			return

		var customer = scene.instantiate()
		customer.position = to_local(spawn_point.global_position)
		add_child(customer)
		customer.spawn_position = spawn_point.global_position

		if customer.customer_type == 2:
			prepare_ogre_group(customer)

		await customer.tree_exited

		while get_tree().get_nodes_in_group("bandit").size() > 0:
			if game_has_ended():
				return

			await get_tree().process_frame

		if game_has_ended():
			return

		await get_tree().create_timer(
			maxf(delay_between_customers, 0.1)
		).timeout

		index += 1


func prepare_ogre_group(ogre) -> void:
	# Mantiene al ogro como cliente hasta perder la paciencia.
	ogre.max_patience = 3.0
	ogre.patience = 3.0
	ogre.patience_bar.max_value = 3.0
	ogre.patience_bar.value = 3.0
	ogre.time_label.text = "3s"

	if goblin_scene != null:
		spawn_goblin(ogre, Vector2(-110, -110))
		spawn_goblin(ogre, Vector2(-110, 110))

	watch_ogre(ogre)


func spawn_goblin(ogre, offset: Vector2) -> void:
	var goblin = goblin_scene.instantiate()

	goblin.leader = ogre
	goblin.escort_offset = offset
	goblin.raid_duration = maxf(group_attack_duration, 1.0)

	goblin.position = to_local(
		spawn_point.global_position + offset
	)

	add_child(goblin)


func watch_ogre(ogre) -> void:
	while is_instance_valid(ogre):
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


func finish_ogre_attack(ogre) -> void:
	# El tiempo empieza cuando se enfada, no cuando aparece.
	await get_tree().create_timer(
		maxf(group_attack_duration, 1.0)
	).timeout

	if not is_instance_valid(ogre):
		return

	if ogre.is_queued_for_deletion() or game_has_ended():
		return

	ogre.target = null
	ogre.velocity = Vector2.ZERO
	ogre.hide_dialogue()
	ogre.animated_sprite.speed_scale = 1.0
	ogre.current_state = ogre.State.LEAVING

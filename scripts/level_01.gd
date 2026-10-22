extends Node2D

@export var customer_scenes: Array[PackedScene] = []
@export var spawn_point: Marker2D
@export var delay_between_customers: float = 3.0
@export var camera_smoothness: float = 4.0
@export var camera_left_limit: float = 576.0
@export var camera_right_limit: float = 732.0

@onready var camera: Camera2D = $Camera2D

var camera_target: Node2D

func _ready() -> void:
	camera.position = Vector2(576.0, 324.0)
	camera.make_current()
	spawn_loop()

func _process(delta: float) -> void:
	if not is_instance_valid(camera_target):
		camera_target = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(camera_target):
		return

	var target_x := clampf(camera_target.global_position.x, camera_left_limit, camera_right_limit)
	camera.global_position.x = move_toward(camera.global_position.x, target_x, camera_smoothness * 120.0 * delta)
	camera.global_position.y = 324.0

func spawn_loop() -> void:
	if customer_scenes.is_empty() or spawn_point == null:
		return

	var index := 0
	while is_inside_tree():
		var customer = customer_scenes[index % customer_scenes.size()].instantiate()
		add_child(customer)
		customer.global_position = spawn_point.global_position
		customer.spawn_position = spawn_point.global_position
		camera_target = customer
		await customer.tree_exited
		camera_target = get_tree().get_first_node_in_group("player") as Node2D
		await get_tree().create_timer(delay_between_customers).timeout
		index += 1

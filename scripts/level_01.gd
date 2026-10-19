extends Node2D

@export var customer_scenes: Array[PackedScene] = []
@export var spawn_point: Marker2D
@export var delay_between_customers: float = 3.0

func _ready() -> void:
	spawn_loop()

func spawn_loop() -> void:
	var index := 0
	while true:
		var customer = customer_scenes[index % customer_scenes.size()].instantiate()
		add_child(customer)
		customer.global_position = spawn_point.global_position
		customer.spawn_position = spawn_point.global_position # a dónde regresa al irse
		await customer.tree_exited # espera a que se vaya antes de crear el siguiente
		await get_tree().create_timer(delay_between_customers).timeout
		index += 1

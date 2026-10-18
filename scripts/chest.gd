extends Area2D

@export_enum("King", "Business") var chest_type: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar

var player_inside: bool = false
var is_opening: bool = false
var is_broken: bool = false
var game_over: bool = false
var health: int = 100


func _ready() -> void:
	add_to_group("chest")
	add_to_group("damageable")

	if chest_type == 0:
		sprite.sprite_frames = preload(
			"res://assets/animations/king.tres"
		)
	else:
		sprite.sprite_frames = preload(
			"res://assets/animations/business.tres"
		)

	sprite.play("closed")

	health_bar.max_value = 100
	health_bar.value = health
	health_bar.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false


func deposit() -> void:
	if is_opening or is_broken or game_over:
		return

	is_opening = true

	if chest_type == 0:
		Economy.deposit_to_king()
	else:
		Economy.deposit_to_business()

	sprite.play("open")
	await sprite.animation_finished

	await get_tree().create_timer(0.3).timeout

	sprite.play("close")
	await sprite.animation_finished

	sprite.play("closed")
	is_opening = false


func get_hit_position() -> Vector2:
	return $CollisionShape2D.global_position


func take_damage(amount: int) -> void:
	if is_broken or game_over:
		return

	health = maxi(health - amount, 0)
	health_bar.value = health
	health_bar.show()

	if health == 0:
		is_broken = true
		remove_from_group("damageable")

		sprite.modulate = Color(0.4, 0.4, 0.4)
		sprite.rotation_degrees = -8.0


func stop_for_game_over() -> void:
	game_over = true

extends CharacterBody2D

signal raid_finished(destroyed: bool)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
var destination := Vector2(780, 450)
var health: int = 150
var timer: float = 0.0
var attack_started: bool = false
var finished: bool = false
var health_bar: ProgressBar

func _ready() -> void:
	preload("res://scripts/actor_grounding.gd").setup(self, sprite, shape, 0.75)
	add_to_group("enemy")
	add_to_group("royal_hero")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	sprite.sprite_frames = preload("res://assets/animations/skeleton.tres")
	sprite.modulate = Color(1.0, 0.85, 0.4)
	$PatienceBar.hide()
	$PanelContainer/DialogueLabel.text = "ROYAL HERO"
	$PanelContainer.show()
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(-85, -90)
	health_bar.size = Vector2(100, 10)
	health_bar.max_value = health
	health_bar.value = health
	health_bar.show_percentage = false
	add_child(health_bar)

func _physics_process(delta: float) -> void:
	if finished:
		return
	if not attack_started:
		var direction := global_position.direction_to(destination)
		velocity = direction * 85
		sprite.flip_h = direction.x < 0
		sprite.play("costumer1_walk")
		move_and_slide()
		get_parent().ground_actor(self)
		timer += delta
		if global_position.distance_to(destination) < 35 or timer > 8:
			attack_started = true
			timer = 0
			velocity = Vector2.ZERO
			sprite.play("upset")
	else:
		timer += delta
		if timer >= 2:
			Economy.stage_broken = true
			finish_raid(true)

func take_damage(amount: int) -> void:
	if finished:
		return
	health = maxi(health - amount, 0)
	health_bar.value = health
	if health == 0:
		finish_raid(false)

func finish_raid(destroyed: bool) -> void:
	if finished:
		return
	finished = true
	remove_from_group("enemy")
	raid_finished.emit(destroyed)
	queue_free()

func stop_for_game_over() -> void:
	finished = true
	velocity = Vector2.ZERO
	sprite.stop()

func _on_detection_area_body_entered(_body: Node2D) -> void:
	pass

func _on_detection_area_body_exited(_body: Node2D) -> void:
	pass

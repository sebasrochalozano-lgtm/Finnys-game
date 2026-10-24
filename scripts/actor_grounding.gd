extends RefCounted

# Actor origins are their feet; top-down movement needs no platformer gravity.
static func setup(body: CharacterBody2D, sprite: AnimatedSprite2D, collision: CollisionShape2D, visual_scale: float) -> void:
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision.position = Vector2(0, -12)
	collision.rotation = 0
	collision.scale = Vector2.ONE
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 24)
	collision.shape = shape
	sprite.scale = Vector2.ONE * visual_scale
	sprite.offset = Vector2.ZERO
	sprite.position = Vector2.ZERO
	align_feet(sprite)
	sprite.frame_changed.connect(align_feet.bind(sprite))
	var shadow := Polygon2D.new()
	shadow.color = Color(0.03, 0.02, 0.07, 0.38)
	shadow.z_index = -1
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		points.append(Vector2(cos(angle) * 29, sin(angle) * 8))
	shadow.polygon = points
	body.add_child(shadow)
	if body.has_node("HealthBar"):
		body.get_node("HealthBar").position = Vector2(-40, -125)
	if body.has_node("PatienceBar"):
		body.get_node("PatienceBar").position = Vector2(-53, -168)
		body.get_node("PatienceBar").mouse_filter = Control.MOUSE_FILTER_IGNORE
		var panel := body.get_node("PanelContainer") as Control
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.position = Vector2(-105, -215)
		panel.size = Vector2(210, 42)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := panel.get_node("DialogueLabel") as Label
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 17)
		body.get_node("DetectionArea/CollisionShape2D2").position = Vector2(0, -40)

static func align_feet(sprite: AnimatedSprite2D) -> void:
	if sprite.sprite_frames == null:
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture != null:
		sprite.position.y = -texture.get_height() * sprite.scale.y * 0.46875

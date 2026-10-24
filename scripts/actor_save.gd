extends RefCounted
const CUSTOMER_FIELDS := ["customer_type", "current_state", "patience", "health", "rest_time", "strong_attack", "hit_done", "raid_time", "payment_mode", "price", "speed"]
const GOBLIN_FIELDS := ["current_state", "health", "raid_time", "rest_time", "attack_time", "hit_done", "is_angry", "escort_offset"]

static func capture(actor: Node2D, fields: Array, extent: Vector2) -> Dictionary:
	var result := {"position": actor.position / extent, "velocity": actor.velocity}
	for field in fields:
		result[field] = actor.get(field)
	var sprite := actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
	for field in ["animation", "frame", "frame_progress", "speed_scale", "flip_h"]:
		result[field] = sprite.get(field)
	result["enemy"] = actor.is_in_group("enemy")
	return result

static func restore(actor: Node2D, fields: Array, data: Dictionary, extent: Vector2) -> void:
	actor.position = data.get("position", Vector2(0.5, 0.8)) * extent
	actor.velocity = data.get("velocity", Vector2.ZERO)
	for field in fields:
		if data.has(field):
			actor.set(field, data[field])
	if bool(data.get("enemy", false)):
		actor.add_to_group("enemy")
	var sprite := actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
	sprite.play(data.get("animation", &"idle"))
	sprite.set_frame_and_progress(int(data.get("frame", 0)), float(data.get("frame_progress", 0)))
	sprite.speed_scale = float(data.get("speed_scale", 1))
	sprite.flip_h = bool(data.get("flip_h", false))

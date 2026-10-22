extends RefCounted


static func body_rect(body: Node2D) -> Rect2:
	var collision := body.get_node_or_null(
		"StaticBody2D/CollisionShape2D"
	) as CollisionShape2D

	if collision == null:
		collision = body.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D

	if collision == null or collision.shape == null:
		return Rect2(
			body.global_position - Vector2.ONE,
			Vector2(2, 2)
		)

	return collision.global_transform * collision.shape.get_rect()


static func can_reach(
	attacker: Node2D,
	defender: Node2D,
	reach: float
) -> bool:
	var attacker_rect := body_rect(attacker)
	var defender_rect := body_rect(defender)

	return attacker_rect.grow(reach).intersects(defender_rect)

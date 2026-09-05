class_name Projectile
extends Area2D

var velocity := Vector2.ZERO
var damage := 10.0
var pierce := 0
var life := 1.0
var radius := 5.0
var color := Color.WHITE
var hostile := false
var already_hit: Array[Node] = []

func launch(from: Vector2, direction: Vector2, shot_speed: float, shot_damage: float, shot_life: float, shot_color: Color, shot_pierce: int, is_hostile: bool) -> void:
	global_position = from
	velocity = direction.normalized() * shot_speed
	damage = shot_damage
	life = shot_life
	color = shot_color
	pierce = shot_pierce
	hostile = is_hostile
	collision_layer = Layers.ENEMY_SHOT if is_hostile else Layers.PLAYER_SHOT
	collision_mask = Layers.WORLD | (Layers.PLAYER if is_hostile else Layers.ENEMY)
	queue_redraw()

func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0: queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		queue_free()
		return
	if hostile:
		if body is Player:
			body.hurt(damage)
			queue_free()
		return
	if body is Enemy and not already_hit.has(body):
		already_hit.append(body)
		body.take_damage(damage)
		if pierce > 0: pierce -= 1
		else: queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 2.0, Color(color.r, color.g, color.b, 0.25))
	draw_circle(Vector2.ZERO, radius, color)

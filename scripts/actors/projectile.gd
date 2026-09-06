class_name Projectile
extends Area2D

# Reported so the session can pay lifesteal without the projectile needing a
# reference back to the player.
signal dealt_damage(amount: float)

var velocity := Vector2.ZERO
var damage := 10.0
var pierce := 0
var life := 1.0
var radius := 5.0
var color := Color.WHITE
var hostile := false
var crit := false
var already_hit: Array[Node] = []

func launch(from: Vector2, direction: Vector2, shot_speed: float, shot_damage: float, shot_life: float, shot_color: Color, shot_pierce: int, is_hostile: bool, is_crit: bool = false) -> void:
	position = from
	velocity = direction.normalized() * shot_speed
	damage = shot_damage
	life = shot_life
	color = shot_color
	pierce = shot_pierce
	hostile = is_hostile
	crit = is_crit
	radius = 7.0 if is_crit else 5.0
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
		body.take_damage(damage, crit)
		dealt_damage.emit(damage)
		if pierce > 0: pierce -= 1
		else: queue_free()

# A round dot reads as a pellet. A white-hot core with a coloured tail behind
# it reads as a shot, and the tail also shows which way the thing is going.
func _draw() -> void:
	var heading := velocity.normalized()
	if heading == Vector2.ZERO: heading = Vector2.RIGHT
	var tail := -heading * radius * (7.0 if crit else 5.5)
	draw_line(tail, Vector2.ZERO, Color(color.r, color.g, color.b, 0.20), radius * 2.6)
	draw_line(tail * 0.55, Vector2.ZERO, Color(color.r, color.g, color.b, 0.60), radius * 1.5)
	draw_circle(Vector2.ZERO, radius * 1.45, Color(color.r, color.g, color.b, 0.55))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(1.0, 1.0, 1.0, 0.95))
	if crit:
		draw_arc(Vector2.ZERO, radius * 2.1, 0.0, TAU, 14, Color(1.0, 0.92, 0.5, 0.85), 1.6)

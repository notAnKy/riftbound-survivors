class_name Pickup
extends Area2D

signal collected(value: int, kind: String)

const KIND_MATERIAL := "material"
const KIND_HEALTH := "health"

const SCATTER_MIN := 70.0
const SCATTER_MAX := 170.0
const SCATTER_DRAG := 340.0
const PULL_ACCEL := 2600.0
const PULL_SPEED := 900.0
const REACHED := 16.0

var value := 1
var kind := KIND_MATERIAL
var target: Node2D = null
var velocity := Vector2.ZERO
var age := 0.0

func setup(at: Vector2, amount: int, pickup_kind: String = KIND_MATERIAL) -> void:
	# Set before the node enters the tree, so use the local transform.
	position = at
	value = amount
	kind = pickup_kind
	# A short outward scatter, so several kills in one spot do not pile every
	# drop onto a single pixel.
	velocity = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(SCATTER_MIN, SCATTER_MAX)

func attract(to: Node2D) -> void:
	target = to

func _physics_process(delta: float) -> void:
	age += delta
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length() < REACHED:
			collected.emit(value, kind)
			queue_free()
			return
		# Accelerating rather than moving at a fixed speed is what makes a
		# pickup visibly snap to the player once it enters the magnet.
		velocity = velocity.move_toward(to_target.normalized() * PULL_SPEED, PULL_ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SCATTER_DRAG * delta)
	position += velocity * delta
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(age * 6.0) * 0.12
	var tint := Color("ff6d8d") if kind == KIND_HEALTH else Color("8cffd1")
	if target != null and velocity.length() > 200.0:
		draw_line(Vector2.ZERO, -velocity.normalized() * 16.0, Color(tint.r, tint.g, tint.b, 0.35), 3.0)
	if kind == KIND_HEALTH:
		var r := 9.0 * pulse
		draw_circle(Vector2.ZERO, r + 5.0, Color(1.0, 0.45, 0.55, 0.22))
		draw_circle(Vector2.ZERO, r, tint)
		draw_rect(Rect2(-r * 0.55, -r * 0.18, r * 1.1, r * 0.36), Color("fff0f3"))
		draw_rect(Rect2(-r * 0.18, -r * 0.55, r * 0.36, r * 1.1), Color("fff0f3"))
		return
	var size := (5.0 + float(value)) * pulse
	draw_circle(Vector2.ZERO, size + 3.0, Color(0.55, 1.0, 0.82, 0.22))
	draw_circle(Vector2.ZERO, size, tint)

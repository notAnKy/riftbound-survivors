class_name Pickup
extends Area2D

signal collected(value: int)

const DRIFT_SPEED := 620.0

var value := 1
var target: Node2D = null
var age := 0.0

func setup(at: Vector2, amount: int) -> void:
	# Set before the node enters the tree, so use the local transform.
	position = at
	value = amount

func attract(to: Node2D) -> void:
	target = to

func _physics_process(delta: float) -> void:
	age += delta
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length() < 14.0:
			collected.emit(value)
			queue_free()
			return
		position += to_target.normalized() * DRIFT_SPEED * delta
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(age * 6.0) * 0.12
	var size := (5.0 + float(value)) * pulse
	draw_circle(Vector2.ZERO, size + 3.0, Color(0.55, 1.0, 0.82, 0.22))
	draw_circle(Vector2.ZERO, size, Color("8cffd1"))

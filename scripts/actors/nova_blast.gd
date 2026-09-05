class_name NovaBlast
extends Node2D

# Pure visual. The damage and knockback are applied by GameSession the instant
# the nova is cast, so this never has to agree with the simulation about who
# was inside the ring.

const DURATION := 0.5

var radius := 300.0
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= DURATION: queue_free()

func _draw() -> void:
	var t := clampf(age / DURATION, 0.0, 1.0)
	# Ease out, so the ring leaves fast and settles at the real radius rather
	# than crawling out at a constant rate.
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var r := radius * eased
	var fade := 1.0 - t
	draw_circle(Vector2.ZERO, r, Color(0.55, 0.32, 1.0, 0.18 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(0.80, 0.62, 1.0, 0.95 * fade), 8.0 * (1.0 - t * 0.6))
	draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 48, Color(0.38, 0.95, 1.0, 0.55 * fade), 4.0)
	draw_arc(Vector2.ZERO, r * 0.4, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.35 * fade), 2.0)
	# Spokes give the ring a direction of travel that a plain circle lacks.
	for i in range(12):
		var angle := TAU * float(i) / 12.0 + age * 2.0
		var from := Vector2.RIGHT.rotated(angle) * r * 0.62
		var to := Vector2.RIGHT.rotated(angle) * r * 0.98
		draw_line(from, to, Color(0.85, 0.70, 1.0, 0.5 * fade), 3.0)

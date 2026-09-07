class_name NovaBlast
extends Node2D

# Pure visual. The damage and knockback are applied by GameSession the instant
# the nova is cast, so this never has to agree with the simulation about who
# was inside the ring.

const DURATION := 0.5

var radius := 300.0
var age := 0.0
var tint := Color(0.80, 0.62, 1.0)
# Seconds of warning before the ring goes off. 0 for a nova, which the player
# cast deliberately and already knows about.
var fuse := 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= fuse + DURATION: queue_free()

# Drawn at the real radius from the very first frame. A warning ring that grows
# into place understates the danger right up until it is too late to leave it.
func draw_warning() -> void:
	var t := clampf(age / maxf(fuse, 0.001), 0.0, 1.0)
	var beat := 0.5 + 0.5 * sin(t * TAU * 3.0)
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, 0.08 + 0.10 * beat))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(tint.r, tint.g, tint.b, 0.5 + 0.45 * beat), 3.0 + 4.0 * t)
	# A core that fills as the fuse burns down, so the timing reads as well as
	# the reach -- otherwise it only says "something, somewhere, soon".
	draw_circle(Vector2.ZERO, radius * 0.16 * (0.5 + t), Color(1.0, 0.94, 0.78, 0.45 + 0.45 * beat))

func _draw() -> void:
	if age < fuse:
		draw_warning()
		return
	var t := clampf((age - fuse) / DURATION, 0.0, 1.0)
	# Ease out, so the ring leaves fast and settles at the real radius rather
	# than crawling out at a constant rate.
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var r := radius * eased
	var fade := 1.0 - t
	draw_circle(Vector2.ZERO, r, Color(tint.r, tint.g, tint.b, 0.18 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(tint.r, tint.g, tint.b, 0.95 * fade), 8.0 * (1.0 - t * 0.6))
	draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 48, Color(0.38, 0.95, 1.0, 0.55 * fade), 4.0)
	draw_arc(Vector2.ZERO, r * 0.4, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.35 * fade), 2.0)
	# Spokes give the ring a direction of travel that a plain circle lacks.
	for i in range(12):
		var angle := TAU * float(i) / 12.0 + age * 2.0
		var from := Vector2.RIGHT.rotated(angle) * r * 0.62
		var to := Vector2.RIGHT.rotated(angle) * r * 0.98
		draw_line(from, to, Color(tint.r, tint.g, tint.b, 0.5 * fade), 3.0)

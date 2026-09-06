extends Node2D

# Its own node so it draws after the floor sprites; a parent always draws first.
var rift_effects_enabled := true
var age := 0.0

const RIFTS := [
	Vector2(300, 300), Vector2(1620, 300), Vector2(300, 830),
	Vector2(1620, 830), Vector2(960, 240), Vector2(960, 890),
]

func _process(delta: float) -> void:
	if not rift_effects_enabled: return
	age += delta
	queue_redraw()

func _draw() -> void:
	var bounds := Arena.BOUNDS
	# A layered border reads as a lit edge rather than a one pixel outline.
	draw_rect(bounds.grow(2.0), Color(0.42, 0.86, 0.98, 0.85), false, 3.0)
	draw_rect(bounds.grow(7.0), Color(0.55, 0.34, 0.95, 0.45), false, 3.0)
	draw_rect(bounds.grow(13.0), Color(0.55, 0.34, 0.95, 0.16), false, 6.0)
	# Corner brackets: cheap, and they make the arena look designed.
	var corners := [
		[bounds.position, Vector2(1, 1)],
		[Vector2(bounds.end.x, bounds.position.y), Vector2(-1, 1)],
		[Vector2(bounds.position.x, bounds.end.y), Vector2(1, -1)],
		[bounds.end, Vector2(-1, -1)],
	]
	for corner in corners:
		var at: Vector2 = corner[0]
		var dir: Vector2 = corner[1]
		draw_line(at, at + Vector2(70.0 * dir.x, 0), Color(0.42, 0.86, 0.98, 0.95), 6.0)
		draw_line(at, at + Vector2(0, 70.0 * dir.y), Color(0.42, 0.86, 0.98, 0.95), 6.0)
	if not rift_effects_enabled: return
	for i in range(RIFTS.size()):
		var p: Vector2 = RIFTS[i]
		var pulse := 1.0 + sin(age * 1.6 + float(i)) * 0.14
		draw_circle(p, 46.0 * pulse, Color(0.55, 0.30, 0.95, 0.10))
		draw_arc(p, 34.0 * pulse, 0.0, TAU, 28, Color(0.62, 0.40, 1.0, 0.50), 5.0)
		draw_arc(p, 20.0 * pulse, age * 0.8, age * 0.8 + TAU * 0.7, 20, Color(0.40, 0.92, 1.0, 0.45), 3.0)

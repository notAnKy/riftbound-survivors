extends Node2D

# Its own node so it draws after the floor sprite; a parent always draws first.
var rift_effects_enabled := true

func _draw() -> void:
	var bounds := Arena.BOUNDS
	draw_rect(bounds.grow(3.0), Color(0.24, 0.32, 0.49, 0.9), false, 3.0)
	draw_rect(bounds.grow(7.0), Color(0.38, 0.26, 0.62, 0.35), false, 2.0)
	if not rift_effects_enabled: return
	for p in [Vector2(240, 280), Vector2(1660, 820), Vector2(1560, 250), Vector2(320, 860), Vector2(960, 540)]:
		draw_arc(p, 28.0, 0.0, TAU, 24, Color(0.56, 0.30, 0.95, 0.30), 5.0)
		draw_arc(p, 15.0, 0.0, TAU, 18, Color(0.35, 0.85, 0.95, 0.18), 3.0)

class_name MeleeSwing
extends Node2D

# Purely the visual. A melee weapon applies its damage the instant it swings,
# so this never has to agree with the simulation about who was in the arc.
const DURATION := 0.18

var angle := 0.0
var arc := 2.0
var reach := 150.0
var tint := Color.WHITE
var age := 0.0

func setup(facing: float, spread: float, distance: float, color: Color) -> void:
	angle = facing
	arc = spread
	reach = distance
	tint = color

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= DURATION: queue_free()

func _draw() -> void:
	var t := clampf(age / DURATION, 0.0, 1.0)
	var fade := 1.0 - t
	# The arc opens as it goes, so it reads as a sweep rather than a flash.
	var swept := arc * (0.35 + 0.65 * t)
	var from := angle - swept * 0.5
	var to := angle + swept * 0.5
	draw_arc(Vector2.ZERO, reach * 0.92, from, to, 32, Color(tint.r, tint.g, tint.b, 0.8 * fade), 2.0 + 9.0 * fade)
	draw_arc(Vector2.ZERO, reach * 0.62, from, to, 24, Color(1.0, 1.0, 1.0, 0.40 * fade), 3.0)
	draw_arc(Vector2.ZERO, reach * 0.35, from, to, 18, Color(tint.r, tint.g, tint.b, 0.30 * fade), 2.0)

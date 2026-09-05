class_name DamageNumber
extends Node2D

const LIFETIME := 0.7
const GRAVITY := 150.0

var amount := 0
var crit := false
var age := 0.0
var drift := Vector2.ZERO
var font: Font

func setup(at: Vector2, value: float, is_crit: bool) -> void:
	position = at
	amount = int(round(value))
	crit = is_crit
	# A little sideways spread and an upward toss, so numbers from a burst of
	# hits fan out instead of stacking into an unreadable column.
	drift = Vector2(randf_range(-34.0, 34.0), -randf_range(78.0, 118.0))

func _ready() -> void:
	font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	age += delta
	position += drift * delta
	drift.y += GRAVITY * delta
	queue_redraw()
	if age >= LIFETIME: queue_free()

func _draw() -> void:
	if font == null: return
	var t := clampf(age / LIFETIME, 0.0, 1.0)
	# Hold full opacity for the first part of the life, then fade, so a number
	# is readable rather than ghosting from the moment it appears.
	var alpha := 1.0 if t < 0.45 else 1.0 - (t - 0.45) / 0.55
	var size := 26 if crit else 18
	var text := "%d!" % amount if crit else str(amount)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-width * 0.5, 0.0)
	draw_string(font, at + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.0, alpha * 0.55))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.83, 0.32, alpha) if crit else Color(1.0, 1.0, 1.0, alpha))

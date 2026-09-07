class_name SpriteAnim
extends RefCounted

# Procedural life for a sprite that has no frames.
#
# Every actor in this game is a single static PNG that slides around the arena.
# That, and not the quality of the art, is the reason a wave reads as dead: a
# crowd of thirty things gliding at constant scale looks like a spreadsheet no
# matter what the pixels are. None of what follows needs new art. A hop while
# walking, a breath while standing, a squash on landing and a punch when hit are
# all just the sprite's transform, and they cost one sine apiece.
#
# The phase is seeded per actor. A crowd bobbing in unison reads as one machine,
# which is worse than a crowd not bobbing at all.

# Standing still: a slow breath. Moving: a real hop, off the ground and back.
const IDLE_RATE := 2.6
const IDLE_LIFT := 0.05
const WALK_RATE := 11.0
const WALK_LIFT := 0.17
# How much of the lift is paid back sideways. Squash at the bottom of the hop,
# stretch at the top -- volume is roughly conserved, which is what sells weight.
const SQUASH := 0.55
# A hit is a fast wide flinch, not a size change: the silhouette must not grow
# or a crowd under fire looks like it is inflating.
const PUNCH_SIZE := 0.26
const PUNCH_DECAY := 7.5
const SPAWN_TIME := 0.18

var phase := 0.0
var punch := 0.0
# 0 -> 1 across SPAWN_TIME. Starts finished for anything that does not pop in.
var spawn := 1.0
# Slow uniform pulse, for something that is visibly about to go off.
var swell := 0.0
var base_scale := Vector2.ONE
var lift_px := 16.0
var started := false

# Captures whatever scale the caller has already set, so this never fights the
# per-enemy `scale` in the catalog or the elite multiplier on top of it.
func begin(sprite: Sprite2D, pops_in: bool = true) -> void:
	base_scale = sprite.scale
	var height := 16.0
	if sprite.texture != null: height = float(sprite.texture.get_height())
	lift_px = height * absf(base_scale.y)
	phase = randf() * TAU
	spawn = 0.0 if pops_in else 1.0
	started = true

func hit() -> void:
	punch = 1.0

# `moving` is 0 standing to 1 at full speed, and blends the breath into the hop
# rather than switching between them -- a stopping enemy settles.
func tick(sprite: Sprite2D, delta: float, moving: float) -> void:
	if not started: begin(sprite, false)
	moving = clampf(moving, 0.0, 1.0)
	spawn = minf(1.0, spawn + delta / SPAWN_TIME)
	punch = maxf(0.0, punch - delta * PUNCH_DECAY)
	phase += delta * lerpf(IDLE_RATE, WALK_RATE, moving)
	var lift := lerpf(IDLE_LIFT, WALK_LIFT, moving)
	# abs(sin) is a hop -- it leaves the ground and comes back to it. A plain
	# sine floats through the floor and reads as hovering.
	var rise := lerpf((sin(phase) + 1.0) * 0.5, absf(sin(phase)), moving)
	sprite.position.y = -rise * lift * lift_px
	# -1 at the bottom of the hop, +1 at the top.
	var stretch := (rise - 0.5) * 2.0 * lift * SQUASH
	var pop := 0.25 + 0.75 * smoothstep(0.0, 1.0, spawn)
	# A little overshoot on arrival, so a spawn lands rather than just appearing.
	if spawn < 1.0: pop += sin(spawn * PI) * 0.18
	var breath := 1.0 + sin(phase * 0.5) * swell
	sprite.scale = Vector2(
		base_scale.x * (1.0 - stretch) * (1.0 + punch * PUNCH_SIZE) * pop * breath,
		base_scale.y * (1.0 + stretch) * (1.0 - punch * PUNCH_SIZE * 0.6) * pop * breath)

class_name Arena
extends Node2D

# The rectangle the arena occupies *on screen*, which is all the room the HUD
# leaves. It cannot grow: the bars and the wave clock live in the margins.
const VIEW := Rect2(40, 120, 1840, 890)
# So the playfield is bigger than the space it is drawn in, and GameSession
# scales the whole session down to fit. That is what buys room to move without
# taking a pixel from the HUD -- everything simply renders a little smaller.
# Must stay proportional to VIEW, or the two axes would not fit at one scale.
# Raised 1.12 -> 1.28 on play feedback: being surrounded with nowhere to run
# was the complaint. The cost is real and unavoidable -- the session scales down
# to fit, so every actor renders about 12% smaller. Room is bought in exactly
# that currency, which is why this is not simply set higher again.
const GROWTH := 1.28
const BOUNDS := Rect2(VIEW.position, VIEW.size * GROWTH)
const WALL_THICKNESS := 60.0

# Scattered decoration. Purely visual -- no collision, and drawn under the
# actors -- so the arena reads as a place without changing how it plays.
# Each prop carries its own colour in its own art now, so the tint here is only
# an opacity -- decoration sits back by being darker and thinner, not by being
# washed out. Formerly: the crates sit back in the palette, and the
# growth is pushed to teal so it reads as rift bloom rather than shrubbery.
# Heavily muted on purpose. These are ground texture, not objects: anything on
# the floor as saturated as an enemy is competing with the one thing the player
# actually has to look at. Brotato's floor is nearly flat grey for this reason.
# Mushrooms only. Anything square scattered on a tiled floor reads as a patch of
# different floor rather than as an object on it, which is worse than nothing;
# the ground's own detail comes from the accent layer instead.
const PROPS := [
	{"texture": "prop_rock", "tint": Color(1.0, 1.0, 1.0, 0.62)},
	{"texture": "prop_shard", "tint": Color(1.0, 1.0, 1.0, 0.55)},
]
const PROP_SCALE := 0.9
const PROP_COUNT := 16
const PROP_SEED := 20260906

func _ready() -> void:
	# The floor is stretched to BOUNDS here rather than in the .tscn, so
	# resizing the arena cannot leave the tiling covering the old rectangle.
	var ground := $Floor as Sprite2D
	ground.position = BOUNDS.position
	ground.region_rect = Rect2(Vector2.ZERO, BOUNDS.size)
	# A second tiled layer at a different scale breaks up the repeat, which is
	# what stopped the floor reading as one texture stamped over and over.
	var accent := $Accent as Sprite2D
	accent.position = BOUNDS.position
	accent.region_rect = Rect2(Vector2.ZERO, BOUNDS.size)
	flatten_floor()
	build_walls()
	scatter_props()

# A flat wash over the tiling.
#
# The floor texture repeats visibly, and a grid of squares behind the actors is
# competing with the only thing on screen the player has to read. Brotato's
# ground is close to a flat tone for exactly this reason. This keeps enough of
# the texture through it to stop the floor looking like a solid fill, and no
# more than that.
func flatten_floor() -> void:
	var wash := ColorRect.new()
	wash.name = "Wash"
	wash.color = Color(0.150, 0.150, 0.180, 0.60)
	wash.position = BOUNDS.position
	wash.size = BOUNDS.size
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	# Above the floor and its accent, below the border and everything else.
	move_child(wash, 2)

func build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = Layers.WORLD
	walls.collision_mask = 0
	add_child(walls)
	var t := WALL_THICKNESS
	for side in [
		Rect2(BOUNDS.position.x - t, BOUNDS.position.y - t, BOUNDS.size.x + t * 2.0, t),
		Rect2(BOUNDS.position.x - t, BOUNDS.end.y, BOUNDS.size.x + t * 2.0, t),
		Rect2(BOUNDS.position.x - t, BOUNDS.position.y, t, BOUNDS.size.y),
		Rect2(BOUNDS.end.x, BOUNDS.position.y, t, BOUNDS.size.y),
	]:
		var rect := RectangleShape2D.new()
		rect.size = side.size
		var shape := CollisionShape2D.new()
		shape.shape = rect
		shape.position = side.get_center()
		walls.add_child(shape)

# Seeded, so the arena looks the same every run rather than reshuffling between
# waves, and kept off the middle so the opening seconds are never blocked.
func scatter_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PROP_SEED
	var field := BOUNDS.grow(-90.0)
	var centre := BOUNDS.get_center()
	var placed := 0
	var guard := 0
	while placed < PROP_COUNT and guard < 400:
		guard += 1
		var spot := Vector2(rng.randf_range(field.position.x, field.end.x),
			rng.randf_range(field.position.y, field.end.y))
		if spot.distance_to(centre) < 260.0: continue
		var prop: Dictionary = PROPS[rng.randi_range(0, PROPS.size() - 1)]
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/sprites/%s.png" % prop.texture)
		sprite.position = spot
		# The quarter-turn rule was a pixel-art rule -- rotated off-axis, pixel
		# art turns to porridge. Vector props can take any angle, but a rock
		# stood on its side reads as floating, so it is a small tilt and a
		# flip rather than a spin.
		sprite.rotation = rng.randf_range(-0.22, 0.22)
		sprite.flip_h = rng.randf() < 0.5
		# Decoration sits under the actors in the hierarchy as well as in the
		# draw order: same source pixels, deliberately smaller and dimmer, so a
		# mushroom cannot be mistaken for something that matters.
		sprite.scale = Vector2.ONE * PROP_SCALE
		# Vector art, so linear. The Floor and Accent above are still pixel
		# tiles and keep nearest -- the filter is per node for that reason.
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.modulate = prop.tint
		add_child(sprite)
		placed += 1

func _draw() -> void:
	# A flat fill read as empty space. A soft radial keeps the eye on the arena
	# and gives the dark edges somewhere to go.
	# Drawn well past the screen: the session is scaled down to fit the arena, so
	# a rect the size of the screen in world units no longer reaches its edges.
	draw_rect(Rect2(-600, -600, GameUI.SCREEN.x + 1200, GameUI.SCREEN.y + 1200), Color("0c0d12"))
	var centre := BOUNDS.get_center()
	for i in range(7):
		var t := float(i) / 6.0
		# Proportional to the arena, so the glow keeps its shape as it grows.
		var radius: float = BOUNDS.size.x * (0.34 + t * 0.49)
		draw_circle(centre, radius, Color(0.22, 0.23, 0.30, 0.05 * (1.0 - t)))

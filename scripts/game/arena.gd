class_name Arena
extends Node2D

# The rectangle the arena occupies *on screen*, which is all the room the HUD
# leaves. It cannot grow: the bars and the wave clock live in the margins.
const VIEW := Rect2(40, 120, 1840, 890)
# So the playfield is bigger than the space it is drawn in, and GameSession
# scales the whole session down to fit. That is what buys room to move without
# taking a pixel from the HUD -- everything simply renders a little smaller.
# Must stay proportional to VIEW, or the two axes would not fit at one scale.
const GROWTH := 1.12
const BOUNDS := Rect2(VIEW.position, VIEW.size * GROWTH)
const WALL_THICKNESS := 60.0

# Scattered decoration. Purely visual -- no collision, and drawn under the
# actors -- so the arena reads as a place without changing how it plays.
# Each prop carries its own tint: the crates sit back in the palette, and the
# growth is pushed to teal so it reads as rift bloom rather than shrubbery.
const PROPS := [
	{"texture": "prop_crate", "tint": Color(0.70, 0.66, 0.72, 0.85)},
	{"texture": "prop_barrel", "tint": Color(0.80, 0.62, 0.52, 0.85)},
	{"texture": "prop_growth", "tint": Color(0.38, 0.95, 0.88, 0.75)},
]
const PROP_COUNT := 18
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
	build_walls()
	scatter_props()

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
		sprite.rotation = rng.randf_range(0.0, TAU)
		sprite.scale = Vector2.ONE * rng.randf_range(0.8, 1.1)
		sprite.modulate = prop.tint
		add_child(sprite)
		placed += 1

func _draw() -> void:
	# A flat fill read as empty space. A soft radial keeps the eye on the arena
	# and gives the dark edges somewhere to go.
	# Drawn well past the screen: the session is scaled down to fit the arena, so
	# a rect the size of the screen in world units no longer reaches its edges.
	draw_rect(Rect2(-600, -600, GameUI.SCREEN.x + 1200, GameUI.SCREEN.y + 1200), Color("0a0e1f"))
	var centre := BOUNDS.get_center()
	for i in range(7):
		var t := float(i) / 6.0
		# Proportional to the arena, so the glow keeps its shape as it grows.
		var radius: float = BOUNDS.size.x * (0.34 + t * 0.49)
		draw_circle(centre, radius, Color(0.16, 0.20, 0.42, 0.055 * (1.0 - t)))

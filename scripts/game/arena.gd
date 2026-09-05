class_name Arena
extends Node2D

const BOUNDS := Rect2(40, 120, 1840, 890)
const WALL_THICKNESS := 60.0

# Walls are built here rather than in the .tscn so the four slabs stay in sync
# with BOUNDS, which the spawner and the UI also read.
func _ready() -> void:
	# The floor is stretched to BOUNDS here rather than in the .tscn, so
	# resizing the arena cannot leave the tiling covering the old rectangle.
	var ground := $Floor as Sprite2D
	ground.position = BOUNDS.position
	ground.region_rect = Rect2(Vector2.ZERO, BOUNDS.size)
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

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, GameUI.SCREEN), Color("0b1020"))

extends SceneTree

# Bring one Tiny Dungeon tile into assets/sprites: upscale 3x nearest to the
# 48px the rest of the pack was brought in at, then strip the opaque dungeon
# floor square the tileset bakes in (see strip_tile_bg.gd for why it is a flood
# fill from the border and not a colour key).

const BG := Color("3f2631")

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file("res://assets/incoming/kenney_tiny-dungeon/Tiles/tile_%04d.png" % int(a[0]))
	img.convert(Image.FORMAT_RGBA8)
	img.resize(48, 48, Image.INTERPOLATE_NEAREST)
	var w := img.get_width()
	var h := img.get_height()
	var seen := {}
	var queue: Array[Vector2i] = []
	for x in range(w):
		queue.append(Vector2i(x, 0)); queue.append(Vector2i(x, h - 1))
	for y in range(h):
		queue.append(Vector2i(0, y)); queue.append(Vector2i(w - 1, y))
	var cleared := 0
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		if at.x < 0 or at.y < 0 or at.x >= w or at.y >= h: continue
		if seen.has(at): continue
		seen[at] = true
		var c := img.get_pixel(at.x, at.y)
		if c.a < 0.5:
			pass
		elif is_equal_approx(c.r, BG.r) and is_equal_approx(c.g, BG.g) and is_equal_approx(c.b, BG.b):
			img.set_pixel(at.x, at.y, Color(0, 0, 0, 0))
			cleared += 1
		else:
			continue
		queue.append(at + Vector2i(1, 0)); queue.append(at + Vector2i(-1, 0))
		queue.append(at + Vector2i(0, 1)); queue.append(at + Vector2i(0, -1))
	var out := "res://assets/sprites/%s.png" % a[1]
	img.save_png(ProjectSettings.globalize_path(out))
	print("wrote %s from tile_%04d, stripped %d bg px" % [out, int(a[0]), cleared])
	quit()

extends SceneTree

# Kenney's Tiny Dungeon is a *tileset*: several of its character tiles are drawn
# on an opaque dungeon-floor square (3f2631). At 1:1 that square was a handful of
# pixels and nobody saw it. Scaled up to read properly it is an obvious box
# behind the enemy.
#
# 3f2631 is also the colour of the outline baked into every one of these
# sprites, so it cannot simply be keyed out -- that would dissolve the outlines
# with the background. Only the pixels *connected to the border* are background,
# which is a flood fill from the edges inward.

const BG := Color("3f2631")

func _init() -> void:
	for name in ["player", "boss", "brute", "robot", "runner", "soldier", "warden", "zombie"]:
		var path := "res://assets/sprites/%s.png" % name
		var img := Image.load_from_file(path)
		var w := img.get_width()
		var h := img.get_height()
		var seen := {}
		var queue: Array[Vector2i] = []
		for x in range(w):
			queue.append(Vector2i(x, 0))
			queue.append(Vector2i(x, h - 1))
		for y in range(h):
			queue.append(Vector2i(0, y))
			queue.append(Vector2i(w - 1, y))
		var cleared := 0
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			if at.x < 0 or at.y < 0 or at.x >= w or at.y >= h: continue
			if seen.has(at): continue
			seen[at] = true
			var c := img.get_pixel(at.x, at.y)
			# Already transparent: keep walking, the background may be ringed
			# by empty space rather than reaching the border itself.
			if c.a < 0.5:
				pass
			elif is_equal_approx(c.r, BG.r) and is_equal_approx(c.g, BG.g) and is_equal_approx(c.b, BG.b):
				img.set_pixel(at.x, at.y, Color(0, 0, 0, 0))
				cleared += 1
			else:
				continue
			queue.append(at + Vector2i(1, 0))
			queue.append(at + Vector2i(-1, 0))
			queue.append(at + Vector2i(0, 1))
			queue.append(at + Vector2i(0, -1))
		if cleared == 0:
			print("%-9s clean already" % name)
			continue
		img.save_png(ProjectSettings.globalize_path(path))
		print("%-9s stripped %d px (%d%% of the tile)" % [name, cleared, 100 * cleared / (w * h)])
	quit()

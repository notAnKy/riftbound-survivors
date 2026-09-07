extends SceneTree

# Nearest-neighbour blow-up so a 48px sprite can actually be judged, and put
# beside the existing art because the only question that matters is whether the
# two look like they came from the same game.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var paths: Array = []
	for i in range(1, args.size()): paths.append(args[i])
	var zoom := 6
	var cell := 48 * zoom
	var sheet := Image.create(cell * paths.size(), cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.11, 0.09, 1.0))
	for i in range(paths.size()):
		var src := Image.load_from_file(paths[i])
		if src == null: continue
		src.resize(cell, cell, Image.INTERPOLATE_NEAREST)
		src.convert(Image.FORMAT_RGBA8)
		for y in range(cell):
			for x in range(cell):
				var c := src.get_pixel(x, y)
				if c.a <= 0.01: continue
				var bg := sheet.get_pixel(i * cell + x, y)
				sheet.set_pixel(i * cell + x, y, bg.lerp(c, c.a))
	sheet.save_png(out)
	print("wrote ", out)
	quit()

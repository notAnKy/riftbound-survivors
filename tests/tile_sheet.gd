extends SceneTree

# Contact sheet of the Tiny Dungeon tiles with their numbers on them, so a tile
# can be picked by eye and then referenced by name.

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var first := int(a[0])
	var last := int(a[1])
	var out: String = a[2]
	var cols := 12
	var zoom := 10
	var cell := 16 * zoom + 10
	var rows := int(ceil(float(last - first + 1) / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.10, 0.10, 0.13, 1.0))
	for n in range(first, last + 1):
		var path := "res://assets/incoming/kenney_tiny-dungeon/Tiles/tile_%04d.png" % n
		var img := Image.load_from_file(path)
		if img == null: continue
		img.resize(16 * zoom, 16 * zoom, Image.INTERPOLATE_NEAREST)
		img.convert(Image.FORMAT_RGBA8)
		var i := n - first
		var ox := (i % cols) * cell + 5
		var oy := int(i / cols) * cell + 5
		for y in range(16 * zoom):
			for x in range(16 * zoom):
				var c := img.get_pixel(x, y)
				if c.a <= 0.01: continue
				sheet.set_pixel(ox + x, oy + y, c)
	sheet.save_png(out)
	print("wrote ", out, " tiles ", first, "-", last)
	quit()

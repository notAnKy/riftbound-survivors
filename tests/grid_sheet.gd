extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var files: Array = []
	for i in range(1, a.size()): files.append(a[i])
	var cell := 128
	var cols := 6
	var rows := int(ceil(float(files.size()) / float(cols)))
	var sheet := Image.create(cell * cols, cell * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.19, 0.20, 0.22, 1.0))
	for i in range(files.size()):
		var src := Image.load_from_file("res://assets/sprites/%s.png" % files[i])
		if src == null: continue
		src.convert(Image.FORMAT_RGBA8)
		var ox := (i % cols) * cell
		var oy := int(i / cols) * cell
		for y in range(mini(cell, src.get_height())):
			for x in range(mini(cell, src.get_width())):
				var c := src.get_pixel(x, y)
				if c.a <= 0.004: continue
				var bg := sheet.get_pixel(ox + x, oy + y)
				sheet.set_pixel(ox + x, oy + y, bg.lerp(c, c.a))
	sheet.save_png(out)
	print("wrote ", out)
	quit()

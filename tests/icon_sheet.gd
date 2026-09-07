extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var ids: Array = []
	for i in range(1, a.size()): ids.append(a[i])
	var cell := 110
	var cols := 6
	var rows := int(ceil(float(ids.size()) / float(cols)))
	var sheet := Image.create(cell * cols, cell * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.13, 0.15, 0.20, 1.0))
	for i in range(ids.size()):
		var f := FileAccess.open("res://assets/icons/w_%s.svg" % ids[i], FileAccess.READ)
		if f == null: continue
		var img := Image.new()
		if img.load_svg_from_string(f.get_as_text(), 0.18) != OK: continue
		img.convert(Image.FORMAT_RGBA8)
		var ox := (i % cols) * cell + (cell - img.get_width()) / 2
		var oy := int(i / cols) * cell + (cell - img.get_height()) / 2
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var c := img.get_pixel(x, y)
				if c.a <= 0.01: continue
				sheet.set_pixel(ox + x, oy + y, Color(0.55, 0.95, 0.85).lerp(Color.WHITE, 0.3))
	sheet.save_png(out)
	print("wrote ", out)
	quit()

class_name Icons
extends RefCounted

# Icons are drawn, not imported. The whole UI is immediate-mode already, the
# Kenney pack has no inventory art, and a drawn glyph takes each weapon or item
# colour for free and stays sharp at any size.
#
# Every shape is authored in a -1..1 box and multiplied by `size`, so one
# definition serves the shop card, the weapon rack and the HUD chip.

const DARK := Color(0.05, 0.07, 0.13, 0.85)

static func poly(canvas: CanvasItem, at: Vector2, size: float, points: Array, color: Color) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(at + Vector2(p[0], p[1]) * size)
	canvas.draw_colored_polygon(pts, color)

static func bar(canvas: CanvasItem, at: Vector2, size: float, a: Array, b: Array, color: Color, width: float) -> void:
	canvas.draw_line(at + Vector2(a[0], a[1]) * size, at + Vector2(b[0], b[1]) * size, color, width * size * 0.1)

static func dot(canvas: CanvasItem, at: Vector2, size: float, p: Array, radius: float, color: Color) -> void:
	canvas.draw_circle(at + Vector2(p[0], p[1]) * size, radius * size * 0.1, color)

static func ring(canvas: CanvasItem, at: Vector2, size: float, p: Array, radius: float, color: Color, width: float) -> void:
	canvas.draw_arc(at + Vector2(p[0], p[1]) * size, radius * size * 0.1, 0.0, TAU, 24, color, width * size * 0.1)

static func star(canvas: CanvasItem, at: Vector2, size: float, p: Array, radius: float, color: Color) -> void:
	var c := Vector2(p[0], p[1])
	poly(canvas, at, size, [
		[c.x, c.y - radius], [c.x + radius * 0.32, c.y - radius * 0.32],
		[c.x + radius, c.y], [c.x + radius * 0.32, c.y + radius * 0.32],
		[c.x, c.y + radius], [c.x - radius * 0.32, c.y + radius * 0.32],
		[c.x - radius, c.y], [c.x - radius * 0.32, c.y - radius * 0.32],
	], color)

static func light(color: Color) -> Color:
	return color.lerp(Color.WHITE, 0.55)

# --- weapons -----------------------------------------------------------------

static func weapon(canvas: CanvasItem, id: String, at: Vector2, size: float, color: Color) -> void:
	var pale := light(color)
	match id:
		"pistol":
			poly(canvas, at, size, [[-0.7,-0.25],[0.55,-0.25],[0.55,0.05],[-0.7,0.05]], color)
			poly(canvas, at, size, [[-0.7,0.05],[-0.25,0.05],[-0.35,0.75],[-0.75,0.75]], color)
			bar(canvas, at, size, [0.55,-0.1], [0.9,-0.1], pale, 2.0)
		"wand":
			bar(canvas, at, size, [-0.75,0.75], [0.4,-0.4], color, 2.2)
			star(canvas, at, size, [0.55,-0.55], 0.45, pale)
			dot(canvas, at, size, [-0.2,0.2], 1.2, pale)
		"shotgun":
			poly(canvas, at, size, [[-0.85,-0.22],[0.35,-0.22],[0.35,0.12],[-0.85,0.12]], color)
			poly(canvas, at, size, [[-0.85,0.12],[-0.5,0.12],[-0.6,0.7],[-0.9,0.7]], color)
			for i in range(5):
				var spread: float = -0.5 + float(i) * 0.25
				dot(canvas, at, size, [0.62 + abs(spread) * 0.25, spread * 0.75], 1.0, pale)
		"smg":
			poly(canvas, at, size, [[-0.6,-0.3],[0.5,-0.3],[0.5,0.0],[-0.6,0.0]], color)
			poly(canvas, at, size, [[-0.35,0.0],[-0.05,0.0],[-0.05,0.7],[-0.35,0.7]], color)
			bar(canvas, at, size, [0.5,-0.15], [0.85,-0.15], pale, 1.6)
			for i in range(3):
				bar(canvas, at, size, [-0.85, -0.45 + float(i) * 0.28], [-0.55, -0.45 + float(i) * 0.28], pale, 1.0)
		"rifle":
			poly(canvas, at, size, [[-0.9,-0.12],[0.75,-0.12],[0.75,0.1],[-0.9,0.1]], color)
			poly(canvas, at, size, [[-0.9,0.1],[-0.45,0.1],[-0.55,0.6],[-0.95,0.6]], color)
			ring(canvas, at, size, [0.1,-0.4], 2.4, pale, 1.4)
			bar(canvas, at, size, [0.1,-0.28], [0.1,-0.12], pale, 1.2)
		"lance":
			bar(canvas, at, size, [-0.8,0.8], [0.35,-0.35], color, 2.4)
			poly(canvas, at, size, [[0.12,-0.5],[0.95,-0.95],[0.5,-0.12]], pale)
			dot(canvas, at, size, [-0.45,0.45], 1.4, pale)
		"scatter":
			poly(canvas, at, size, [[-0.75,-0.35],[0.15,-0.2],[0.15,0.2],[-0.75,0.35]], color)
			poly(canvas, at, size, [[0.15,-0.42],[0.5,-0.55],[0.5,0.55],[0.15,0.42]], color)
			for i in range(3):
				dot(canvas, at, size, [0.78, -0.42 + float(i) * 0.42], 1.3, pale)
		_:
			ring(canvas, at, size, [0,0], 6.0, color, 2.0)

# --- items -------------------------------------------------------------------

static func item(canvas: CanvasItem, id: String, at: Vector2, size: float, color: Color) -> void:
	var pale := light(color)
	match id:
		"scrap_plate", "bulwark":
			poly(canvas, at, size, [[0,-0.85],[0.75,-0.5],[0.62,0.45],[0,0.9],[-0.62,0.45],[-0.75,-0.5]], color)
			if id == "bulwark":
				poly(canvas, at, size, [[0,-0.5],[0.42,-0.28],[0.35,0.28],[0,0.55],[-0.35,0.28],[-0.42,-0.28]], pale)
			else:
				bar(canvas, at, size, [-0.35,-0.1], [0.35,-0.1], pale, 1.4)
		"focus_lens":
			ring(canvas, at, size, [0,0], 5.0, color, 2.2)
			dot(canvas, at, size, [0,0], 2.0, pale)
			for i in range(4):
				var a := TAU * float(i) / 4.0 + PI * 0.25
				var d := Vector2.RIGHT.rotated(a)
				bar(canvas, at, size, [d.x * 0.65, d.y * 0.65], [d.x * 0.95, d.y * 0.95], pale, 1.2)
		"coil_spring":
			for i in range(4):
				var y: float = -0.7 + float(i) * 0.42
				bar(canvas, at, size, [-0.55, y], [0.55, y + 0.22], color, 1.8)
		"hair_trigger", "overclock":
			poly(canvas, at, size, [[0.2,-0.9],[-0.5,0.08],[-0.05,0.08],[-0.25,0.9],[0.5,-0.15],[0.02,-0.15]], color)
			if id == "overclock": ring(canvas, at, size, [0,0], 8.5, pale, 1.2)
		"ration_pack":
			poly(canvas, at, size, [[-0.75,-0.55],[0.75,-0.55],[0.75,0.75],[-0.75,0.75]], color)
			bar(canvas, at, size, [-0.75,-0.2], [0.75,-0.2], pale, 1.2)
			poly(canvas, at, size, [[-0.16,0.05],[0.16,0.05],[0.16,0.28],[0.42,0.28],[0.42,0.5],[0.16,0.5],[0.16,0.68],[-0.16,0.68],[-0.16,0.5],[-0.42,0.5],[-0.42,0.28],[-0.16,0.28]], pale)
		"magnet_core":
			canvas.draw_arc(at, size * 0.62, PI, TAU, 24, color, size * 0.3)
			poly(canvas, at, size, [[-0.78,0.0],[-0.46,0.0],[-0.46,0.7],[-0.78,0.7]], pale)
			poly(canvas, at, size, [[0.46,0.0],[0.78,0.0],[0.78,0.7],[0.46,0.7]], pale)
		"honed_edge":
			poly(canvas, at, size, [[-0.15,0.85],[0.15,0.85],[0.35,-0.2],[0,-0.9],[-0.35,-0.2]], color)
			bar(canvas, at, size, [0,-0.6], [0,0.6], pale, 1.0)
		"long_barrel":
			poly(canvas, at, size, [[-0.9,-0.18],[0.9,-0.18],[0.9,0.18],[-0.9,0.18]], color)
			bar(canvas, at, size, [0.45,-0.18], [0.45,-0.6], pale, 1.4)
			dot(canvas, at, size, [0.9,0.0], 1.4, pale)
		"ghost_step":
			for i in range(3):
				var alpha: float = 0.28 + float(i) * 0.28
				var shade := Color(color.r, color.g, color.b, alpha)
				poly(canvas, at, size, [[-0.75 + float(i) * 0.34, -0.55],[-0.3 + float(i) * 0.34, -0.55],[-0.3 + float(i) * 0.34, 0.8],[-0.75 + float(i) * 0.34, 0.8]], shade)
		"leech_rune":
			poly(canvas, at, size, [[0,-0.9],[0.62,0.15],[0.42,0.68],[-0.42,0.68],[-0.62,0.15]], color)
			dot(canvas, at, size, [-0.15,0.28], 1.6, pale)
		"salvage_rig":
			ring(canvas, at, size, [0,0], 5.5, color, 3.0)
			for i in range(6):
				var a := TAU * float(i) / 6.0
				var d := Vector2.RIGHT.rotated(a)
				bar(canvas, at, size, [d.x * 0.55, d.y * 0.55], [d.x * 0.95, d.y * 0.95], color, 2.0)
			dot(canvas, at, size, [0,0], 1.8, pale)
		"repair_field":
			ring(canvas, at, size, [0,0], 8.0, color, 1.6)
			poly(canvas, at, size, [[-0.2,-0.55],[0.2,-0.55],[0.2,-0.2],[0.55,-0.2],[0.55,0.2],[0.2,0.2],[0.2,0.55],[-0.2,0.55],[-0.2,0.2],[-0.55,0.2],[-0.55,-0.2],[-0.2,-0.2]], pale)
		"lucky_coin":
			ring(canvas, at, size, [0,0], 7.5, color, 2.4)
			dot(canvas, at, size, [0,0], 5.5, Color(color.r, color.g, color.b, 0.35))
			star(canvas, at, size, [0,0], 0.42, pale)
		"war_drum":
			poly(canvas, at, size, [[-0.7,-0.5],[0.7,-0.5],[0.55,0.6],[-0.55,0.6]], color)
			bar(canvas, at, size, [-0.7,-0.5], [0.55,0.6], pale, 1.2)
			bar(canvas, at, size, [0.7,-0.5], [-0.55,0.6], pale, 1.2)
		_:
			ring(canvas, at, size, [0,0], 6.0, color, 2.0)
			dot(canvas, at, size, [0,0], 2.0, pale)

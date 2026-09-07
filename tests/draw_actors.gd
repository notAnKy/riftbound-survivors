extends SceneTree

# Every actor in the game, drawn as shapes rather than generated or painted.
#
# The style is geometry: a dome, a heavy outline, one flat fill, one gloss
# ellipse, two eyes, and one feature that says what this thing is. That makes it
# free, exactly consistent between actors, editable by changing a number instead
# of rerolling a generator, and resolution independent -- which is why these are
# SVG rasterised at whatever size is wanted rather than pixels chosen to match a
# tileset.
#
# The rule that matters: an actor is identified by its SILHOUETTE. The bloater
# proved it -- it wore the brute's texture in another colour, and no amount of
# aura, warning ring or fuse made it recognisable, because the outline the eye
# picks out of a crowd was one it already knew. So every body below differs in
# width, height or profile before it differs in colour, and a feature is put
# where it changes the outline rather than sitting inside it.
#
# SVG attributes are single-quoted throughout. That is valid XML and it keeps
# every string here free of escapes.

const SIZE := 128
const VIEW := "-15 -22 130 130"
const INK := "#16161a"

# --- shape helpers -----------------------------------------------------------

# `w` is half the width at the base, so the brute is a wide dome and the runner
# a narrow one without either needing a path of its own.
static func body_path(w: float, top: float, base: float) -> String:
	var l := 50.0 - w
	var r := 50.0 + w
	var knee: float = top + (base - top) * 0.42
	var out := PackedStringArray()
	out.append("M %.1f,%.1f" % [l, base - 14.0])
	out.append("C %.1f,%.1f %.1f,%.1f 50,%.1f" % [l, knee, l + w * 0.45, top, top])
	out.append("C %.1f,%.1f %.1f,%.1f %.1f,%.1f" % [r - w * 0.45, top, r, knee, r, base - 14.0])
	out.append("C %.1f,%.1f %.1f,%.1f 50,%.1f" % [r, base - 3.0, r - w * 0.35, base, base])
	out.append("C %.1f,%.1f %.1f,%.1f %.1f,%.1f Z" % [l + w * 0.35, base, l, base - 3.0, l, base - 14.0])
	return " ".join(out)

static func eyes(kind: String, y: float, spread: float) -> String:
	var l := 50.0 - spread
	var r := 50.0 + spread
	match kind:
		"angry":
			return ("<path d='M%.1f,%.1f L%.1f,%.1f L%.1f,%.1f L%.1f,%.1f Z' fill='%s'/>"
				+ "<path d='M%.1f,%.1f L%.1f,%.1f L%.1f,%.1f L%.1f,%.1f Z' fill='%s'/>") % [
				l - 7.0, y - 5.0, l + 6.0, y + 1.0, l + 5.0, y + 7.0, l - 8.0, y + 2.0, INK,
				r + 7.0, y - 5.0, r - 6.0, y + 1.0, r - 5.0, y + 7.0, r + 8.0, y + 2.0, INK]
		"dead":
			var s := ""
			for cx in [l, r]:
				s += ("<path d='M%.1f,%.1f L%.1f,%.1f M%.1f,%.1f L%.1f,%.1f' stroke='%s'"
					+ " stroke-width='4.5' stroke-linecap='round'/>") % [
					cx - 4.5, y - 4.5, cx + 4.5, y + 4.5, cx + 4.5, y - 4.5, cx - 4.5, y + 4.5, INK]
			return s
		"glow":
			return ("<ellipse cx='%.1f' cy='%.1f' rx='5.4' ry='6.4' fill='#ff5a5a'/>"
				+ "<ellipse cx='%.1f' cy='%.1f' rx='5.4' ry='6.4' fill='#ff5a5a'/>"
				+ "<ellipse cx='%.1f' cy='%.1f' rx='2.2' ry='3.0' fill='#fff3bf'/>"
				+ "<ellipse cx='%.1f' cy='%.1f' rx='2.2' ry='3.0' fill='#fff3bf'/>") % [
				l, y, r, y, l, y, r, y]
		"hollow":
			return ("<ellipse cx='%.1f' cy='%.1f' rx='5.6' ry='6.6' fill='none' stroke='%s' stroke-width='3.4'/>"
				+ "<ellipse cx='%.1f' cy='%.1f' rx='5.6' ry='6.6' fill='none' stroke='%s' stroke-width='3.4'/>") % [
				l, y, INK, r, y, INK]
		_:
			return ("<ellipse cx='%.1f' cy='%.1f' rx='4.8' ry='6.5' fill='%s'/>"
				+ "<ellipse cx='%.1f' cy='%.1f' rx='4.8' ry='6.5' fill='%s'/>") % [
				l, y, INK, r, y, INK]

# A horn, a tail or a hood only reads as attached if it is drawn *behind* the
# body, which is what `under` is for.
static func actor(fill: String, w: float, top: float, eye: String, eye_y: float,
		spread: float, under: String = "", over: String = "") -> String:
	var base := 87.0
	var gx: float = 50.0 - w * 0.42
	var gy: float = top + 20.0
	var gloss := ("<ellipse cx='%.1f' cy='%.1f' rx='%.1f' ry='%.1f' fill='#ffffff'"
		+ " opacity='0.80' transform='rotate(-28 %.1f %.1f)'/>") % [gx, gy, w * 0.30, w * 0.20, gx, gy]
	return ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='%s' width='130' height='130'>"
		+ "%s<path d='%s' fill='%s' stroke='%s' stroke-width='7' stroke-linejoin='round'/>"
		+ "%s%s%s</svg>") % [
		VIEW, under, body_path(w, top, base), fill, INK, gloss, eyes(eye, eye_y, spread), over]

# A horn is a triangle with one curved side and an actual point on it. Drawn
# with a tight linejoin, or a thick round join blunts the tip back into an ear.
static func horn(bx0: float, by0: float, cx: float, cy: float, tipx: float, tipy: float,
		bx1: float, by1: float, fill: String) -> String:
	return ("<path d='M%.1f,%.1f Q%.1f,%.1f %.1f,%.1f L%.1f,%.1f Z' fill='%s'"
		+ " stroke='%s' stroke-width='4.5' stroke-linejoin='miter' stroke-miterlimit='6'/>") % [
		bx0, by0, cx, cy, tipx, tipy, bx1, by1, fill, INK]

# --- the cast ----------------------------------------------------------------

static func cast() -> Dictionary:
	var g := "<g stroke='" + INK + "' stroke-width='5' stroke-linejoin='round'>"
	return {
		# ---------------------------------------------------------- players --
		"char_runner": actor("#5eead4", 37, 16, "dot", 57, 12),
		"char_warden": actor("#b197fc", 35, 22, "dot", 60, 12, "",
			g + "<path d='M50,-16 C44,0 37,12 24,22 L76,22 C63,12 56,0 50,-16 Z' fill='#7048e8'/>"
			+ "<ellipse cx='50' cy='23' rx='30' ry='7' fill='#845ef7'/></g>"
			+ "<path d='M50,-8 l2.8,5.6 6.2,.9 -4.5,4.4 1.1,6.2 -5.6-2.9 -5.6,2.9 1.1-6.2 -4.5-4.4 6.2-.9 Z' fill='#ffd43b'/>"),
		"char_revenant": actor("#ff8d6d", 37, 24, "glow", 58, 12, "",
			g + "<path d='M18,42 C18,12 30,0 50,0 C70,0 82,12 82,42 L69,42 C69,23 61,15 50,15 C39,15 31,23 31,42 Z' fill='#adb5bd'/>"
			+ "<rect x='45' y='4' width='10' height='38' rx='2' fill='#ced4da'/></g>"),
		"char_dancer": actor("#ff8fab", 35, 18, "angry", 60, 13, "",
			"<path d='M14,44 C19,27 32,17 50,17 C68,17 81,27 86,44' stroke='#e03131' stroke-width='12' fill='none' stroke-linecap='round'/>"
			+ "<path d='M84,38 L102,29 L98,44 L104,56 L82,49 Z' fill='#e03131' stroke='" + INK + "' stroke-width='4' stroke-linejoin='round'/>"),
		"char_siege": actor("#ffd166", 44, 30, "dot", 62, 14,
			g + "<rect x='40' y='-18' width='20' height='46' rx='5' fill='#868e96'/>"
			+ "<rect x='33' y='-22' width='34' height='11' rx='5' fill='#adb5bd'/></g>"),
		"char_scav": actor("#8cffd1", 36, 20, "dot", 60, 13, "",
			g + "<rect x='33' y='-6' width='34' height='24' rx='3' fill='#5c3d2e'/>"
			+ "<rect x='21' y='16' width='58' height='8' rx='4' fill='#4a3125'/></g>"
			+ "<circle cx='63' cy='60' r='11.5' fill='none' stroke='#ffd43b' stroke-width='4'/>"
			+ "<path d='M63,72 L66,82' stroke='#ffd43b' stroke-width='3.5' stroke-linecap='round'/>"),
		# ---------------------------------------------------------- enemies --
		"e_husk": actor("#8ce99a", 34, 22, "dead", 58, 12),
		"e_runner": actor("#74c0fc", 26, 14, "angry", 54, 10, "",
			"<path d='M2,42 L18,42 M0,54 L14,54' stroke='#dbe4ff' stroke-width='5' stroke-linecap='round' opacity='0.9'/>"),
		"e_gunner": actor("#ced4da", 33, 24, "glow", 56, 11, "",
			"<rect x='13' y='47' width='74' height='16' rx='8' fill='#343a40' stroke='" + INK + "' stroke-width='5'/>"
			+ "<circle cx='38' cy='55' r='4' fill='#ff6b6b'/><circle cx='62' cy='55' r='4' fill='#ff6b6b'/>"),
		"e_brute": actor("#ffa94d", 48, 32, "angry", 62, 17,
			horn(8, 52, 2, 22, 3, 2, 30, 44, "#f8f9fa")
			+ horn(92, 52, 98, 22, 97, 2, 70, 44, "#f8f9fa")),
		"e_marauder": actor("#adb5bd", 34, 22, "angry", 60, 12, "",
			"<path d='M15,42 C21,19 34,10 50,10 C66,10 79,19 85,42 Z' fill='#495057' stroke='" + INK + "' stroke-width='5' stroke-linejoin='round'/>"),
		"e_warden": actor("#63e6be", 33, 20, "hollow", 58, 12,
			"<path d='M6,82 C6,24 25,2 50,2 C75,2 94,24 94,82 C94,90 79,72 50,72 C21,72 6,90 6,82 Z' fill='#0ca678' stroke='" + INK + "' stroke-width='6' stroke-linejoin='round'/>"),
		"e_splitter": actor("#b2f2bb", 42, 24, "dot", 60, 16, "",
			"<path d='M50,17 L43,40 L57,57 L47,85' stroke='" + INK + "' stroke-width='5.5' fill='none' stroke-linecap='round'/>"),
		"e_bloater": actor("#ff8787", 47, 34, "dead", 64, 15, "",
			"<circle cx='24' cy='58' r='8' fill='#e03131' opacity='0.75'/>"
			+ "<circle cx='76' cy='53' r='10' fill='#e03131' opacity='0.75'/>"
			+ "<circle cx='57' cy='79' r='6.5' fill='#e03131' opacity='0.75'/>"
			+ "<path d='M50,34 C50,18 62,17 62,4' stroke='#495057' stroke-width='6' fill='none' stroke-linecap='round'/>"
			+ "<circle cx='63' cy='0' r='8' fill='#ffd43b'/>"),
		"e_charger": actor("#ffe066", 36, 26, "angry", 62, 13,
			horn(14, 46, 4, 16, 20, -6, 36, 34, "#f1f3f5")
			+ horn(86, 46, 96, 16, 80, -6, 64, 34, "#f1f3f5")),
		# ----------------------------------------------------------- bosses --
		"e_riftlord": actor("#ff6b9d", 46, 18, "glow", 56, 18, "",
			"<path d='M18,28 L25,-6 L38,14 L50,-14 L62,14 L75,-6 L82,28 Z' fill='#f06595' stroke='" + INK + "' stroke-width='5.5' stroke-linejoin='round'/>"
			+ "<ellipse cx='50' cy='74' rx='5.5' ry='6.5' fill='" + INK + "'/>"),
		"e_voidcaller": actor("#b197fc", 42, 20, "hollow", 54, 16,
			"<path d='M22,78 C13,97 7,101 2,106 M50,84 C50,101 48,107 46,113 M78,78 C87,97 93,101 98,106'"
			+ " stroke='#7048e8' stroke-width='9' fill='none' stroke-linecap='round'/>",
			"<circle cx='50' cy='74' r='9.5' fill='#f8f0fc' stroke='" + INK + "' stroke-width='4'/>"
			+ "<circle cx='50' cy='74' r='3.8' fill='" + INK + "'/>"),
	}

# Scatter. Deliberately dark, desaturated and outlined thinner than an actor:
# decoration has to sit behind the things that can kill you, and a prop drawn
# with the same weight as a slime competes with it for the eye.
static func props() -> Dictionary:
	var thin := "stroke='" + INK + "' stroke-width='5' stroke-linejoin='round'"
	return {
		"prop_rock": ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='%s' width='130' height='130'>"
			+ "<path d='M16,84 C10,60 24,40 44,38 C64,36 84,50 86,70 C88,82 76,88 50,88 C28,88 18,88 16,84 Z'"
			+ " fill='#4a4148' %s/>"
			+ "<path d='M30,60 C36,50 46,46 56,48' stroke='#5f555d' stroke-width='5' fill='none' stroke-linecap='round'/></svg>") % [VIEW, thin],
		"prop_shard": ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='%s' width='130' height='130'>"
			+ "<path d='M50,10 L66,54 L58,86 L42,86 L34,54 Z' fill='#4c4266' %s/>"
			+ "<path d='M72,44 L82,68 L76,86 L64,86 L68,64 Z' fill='#5a4e7a' %s/></svg>") % [VIEW, thin, thin],
	}

# The ground, as two seamless 128px tiles laid over each other at different
# scales -- the second one is what stops the repeat reading as a grid.
#
# Seamless by construction: nothing here crosses a tile edge, so the pattern
# meets itself cleanly whatever `texture_repeat` does with it. And no outline.
# A heavy outline is what makes something read as an *object* in this game; the
# floor has to stay underneath that and never compete with an actor for the eye.
static func floors() -> Dictionary:
	return {
		"floor": ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 128 128' width='128' height='128'>"
			+ "<rect x='0' y='0' width='128' height='128' fill='#43302c'/>"
			+ "<rect x='14' y='14' width='36' height='36' rx='9' fill='#4b3630'/>"
			+ "<rect x='78' y='14' width='36' height='36' rx='9' fill='#3d2b28'/>"
			+ "<rect x='14' y='78' width='36' height='36' rx='9' fill='#3d2b28'/>"
			+ "<rect x='78' y='78' width='36' height='36' rx='9' fill='#4b3630'/></svg>"),
		"floor_accent": ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 128 128' width='128' height='128'>"
			+ "<ellipse cx='40' cy='34' rx='22' ry='15' fill='#ffffff' opacity='0.030'/>"
			+ "<ellipse cx='96' cy='88' rx='26' ry='17' fill='#ffffff' opacity='0.026'/>"
			+ "<ellipse cx='22' cy='100' rx='14' ry='10' fill='#000000' opacity='0.045'/></svg>"),
	}

func _init() -> void:
	var made := 0
	for name in floors():
		var tile := Image.new()
		if tile.load_svg_from_string(String(floors()[name]), 1.0) != OK:
			print("FAILED ", name)
			continue
		tile.save_png(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % name))
		made += 1
	var all := cast()
	all.merge(props())
	for name in all:
		var img := Image.new()
		if img.load_svg_from_string(String(all[name]), float(SIZE) / 130.0) != OK:
			print("FAILED ", name)
			continue
		img.save_png(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % name))
		made += 1
	print("drew %d actors at %dpx" % [made, SIZE])
	quit()

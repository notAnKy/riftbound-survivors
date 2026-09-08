extends SceneTree

# Every weapon and item icon, drawn in full colour with the same heavy outline
# the actors carry, so the shop and the arena look like one game.
#
# These used to be monochrome silhouettes, because `Icons.draw_icon` tinted the
# glyph with the weapon's own colour through `modulate` -- one asset covering
# every rarity, and multi-coloured art would have collapsed to a single hue. The
# tint is gone now: rarity is already said twice on a shop card, in the border
# and the title, and saying it a third time cost the art all of its colour.
#
# Weapons **point +X**. The rack rotates each one by `weapon.aim`, so an icon
# drawn facing any other way aims backwards on every shot. Items never rotate.
#
# Authored at a 512 viewBox, which is what the existing .import files expect
# (svg/scale = 0.25, so 512 rasterises to the 128px an icon is drawn from).

const INK := "#16161a"
const STROKE := 22

# Palette. Named by material rather than by hue, so a new icon reaches for
# "steel" and lands in the same family as everything else.
const STEEL := "#6b7280"
const STEEL_D := "#454b56"
const STEEL_L := "#9ca3af"
const SILVER := "#dee2e6"
const WOOD := "#8b5a2b"
const WOOD_D := "#6b4423"
const GOLD := "#fcc419"
const ORANGE := "#fd7e14"
const RED := "#e03131"
const PURPLE := "#845ef7"
const GREEN := "#51cf66"
const BLUE := "#4dabf7"
const PINK := "#f06595"

static func p(d: String, fill: String) -> String:
	return "<path d='%s' fill='%s'/>" % [d, fill]

static func c(cx: float, cy: float, r: float, fill: String) -> String:
	return "<circle cx='%.0f' cy='%.0f' r='%.0f' fill='%s'/>" % [cx, cy, r, fill]

static func rect(x: float, y: float, w: float, h: float, fill: String, round_to := 8.0) -> String:
	return "<rect x='%.0f' y='%.0f' width='%.0f' height='%.0f' rx='%.0f' fill='%s'/>" % [x, y, w, h, round_to, fill]

# Every part carries the outline, not just the outer silhouette. That is what
# separates a barrel from a stock at 30px, and it is what the actors do too.
static func icon(body: String, plain := "") -> String:
	return ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512' width='512' height='512'>"
		+ "<g stroke='" + INK + "' stroke-width='" + str(STROKE) + "' stroke-linejoin='round' stroke-linecap='round'>"
		+ body + "</g>" + plain + "</svg>")

# --- weapons -----------------------------------------------------------------

static func weapons() -> Dictionary:
	return {
		"pistol": icon(
			p("M104,196 L392,196 L392,258 L250,258 L214,362 L118,362 L156,258 L104,258 Z", STEEL)
			+ rect(148, 210, 200, 34, STEEL_D, 6)),
		"shotgun": icon(
			rect(150, 188, 300, 48, STEEL, 10)
			+ rect(150, 250, 300, 44, STEEL_D, 10)
			+ p("M56,186 L160,186 L160,318 L56,372 Z", WOOD)
			+ rect(196, 296, 120, 34, WOOD_D, 8)),
		"smg": icon(
			rect(96, 196, 300, 66, STEEL_D, 10)
			+ rect(186, 256, 68, 130, STEEL, 10)
			+ p("M62,194 L112,194 L112,332 L62,300 Z", STEEL)
			+ rect(300, 212, 70, 26, RED, 6)),
		"rifle": icon(
			rect(110, 228, 358, 50, STEEL, 10)
			+ p("M40,214 L200,214 L200,338 L40,296 Z", WOOD)
			+ rect(198, 160, 130, 54, STEEL_D, 10)
			+ p("M198,276 L252,276 L228,358 L176,358 Z", WOOD_D)
			+ rect(330, 214, 40, 24, ORANGE, 6)),
		"wand": icon(
			p("M78,346 L286,196 L322,244 L114,394 Z", WOOD)
			+ p("M386,104 L412,176 L484,202 L412,228 L386,300 L360,228 L288,202 L360,176 Z", GOLD),
			c(392, 84, 16, "#ffe066") + c(468, 262, 13, "#ffe066")),
		# A thin shaft with a flat point read as an arrow, not a lance. The mass
		# is in the head: thicker shaft, a collar to break it, a leaf blade.
		"lance": icon(
			rect(40, 234, 300, 48, WOOD, 10)
			+ rect(306, 220, 44, 76, GOLD, 8)
			+ p("M344,256 C384,194 420,178 492,256 C420,334 384,318 344,256 Z", SILVER)),
		"scatter": icon(
			rect(64, 200, 190, 112, STEEL_D, 14)
			+ c(178, 256, 52, GOLD)
			+ p("M254,190 L322,150 L322,362 L254,322 Z", STEEL),
			c(388, 168, 30, ORANGE) + c(432, 256, 30, ORANGE) + c(388, 344, 30, ORANGE)),
		"blade": icon(
			p("M206,212 L356,212 L486,256 L356,300 L206,300 Z", SILVER)
			+ rect(164, 156, 46, 200, GOLD, 10)
			+ rect(46, 232, 122, 48, WOOD, 10)
			+ c(46, 256, 34, WOOD_D)),
		"hammer": icon(
			rect(296, 118, 176, 276, STEEL, 18)
			+ rect(252, 174, 52, 164, STEEL_D, 10)
			+ rect(40, 232, 218, 48, WOOD, 10)),
		"seeker": icon(
			p("M172,212 L340,212 L482,256 L340,300 L172,300 Z", STEEL_L)
			+ p("M78,148 L184,212 L184,300 L78,364 L126,256 Z", ORANGE)
			+ p("M192,116 L268,196 L196,196 Z", RED)
			+ p("M192,396 L268,316 L196,316 Z", RED)),
		"orb": icon(
			c(256, 256, 104, PURPLE)
			+ c(256, 66, 38, "#b197fc") + c(256, 446, 38, "#b197fc")
			+ c(66, 256, 38, "#b197fc") + c(446, 256, 38, "#b197fc"),
			c(222, 220, 30, "#f3f0ff")),
	}

# --- items -------------------------------------------------------------------

static func items() -> Dictionary:
	return {
		"scrap_plate": icon(
			p("M256,44 L436,104 L436,268 C436,378 348,442 256,468 C164,442 76,378 76,268 L76,104 Z", STEEL)
			+ p("M256,116 L366,152 L366,266 C366,336 314,378 256,398 Z", STEEL_D)),
		"focus_lens": icon(
			p("M40,256 C120,140 200,110 256,110 C312,110 392,140 472,256 C392,372 312,402 256,402 C200,402 120,372 40,256 Z", "#e7f5ff")
			+ c(256, 256, 92, BLUE) + c(256, 256, 40, INK)),
		"coil_spring": icon(
			rect(140, 40, 232, 46, STEEL_L, 10)
			+ rect(140, 426, 232, 46, STEEL_L, 10)
			+ p("M160,110 L352,166 L160,222 L352,278 L160,334 L352,390", "none")),
		"hair_trigger": icon(
			p("M116,120 L300,120 L300,196 L212,196 C212,300 268,332 316,344 L316,412 C180,392 116,300 116,196 Z", STEEL)
			+ c(360, 380, 62, RED)),
		"ration_pack": icon(
			rect(84, 132, 344, 268, "#c2410c", 22)
			+ rect(84, 132, 344, 74, "#ea580c", 22)
			+ p("M256,236 L256,352 M198,294 L314,294", "none")),
		"magnet_core": icon(
			p("M96,404 L96,232 C96,144 168,76 256,76 C344,76 416,144 416,232 L416,404 L316,404 L316,232 C316,198 290,172 256,172 C222,172 196,198 196,232 L196,404 Z", RED)
			+ rect(96, 380, 100, 68, SILVER, 8) + rect(316, 380, 100, 68, SILVER, 8)),
		"honed_edge": icon(
			p("M150,404 L106,360 L330,88 L392,144 Z", SILVER)
			+ rect(58, 348, 84, 108, WOOD, 12),
			c(414, 108, 18, "#ffe066") + c(452, 168, 13, "#ffe066")),
		"long_barrel": icon(
			rect(40, 208, 400, 96, STEEL, 18)
			+ rect(120, 208, 44, 96, STEEL_D, 4)
			+ rect(268, 208, 44, 96, STEEL_D, 4)
			+ c(440, 256, 54, STEEL_L)),
		"ghost_step": icon(
			p("M256,54 C346,54 402,124 402,224 L402,438 L340,386 L278,438 L216,386 L154,438 L110,386 L110,224 C110,124 166,54 256,54 Z", "#e9ecef")
			+ c(198, 218, 30, INK) + c(316, 218, 30, INK)),
		"leech_rune": icon(
			p("M256,48 C256,48 400,204 400,306 C400,388 336,452 256,452 C176,452 112,388 112,306 C112,204 256,48 256,48 Z", RED)
			+ p("M256,158 C256,158 330,244 330,306 C330,348 296,382 256,382 Z", "#ff8787")),
		"salvage_rig": icon(
			c(256, 256, 96, STEEL_D)
			+ p("M232,28 L280,28 L292,116 L220,116 Z", STEEL)
			+ p("M232,484 L280,484 L292,396 L220,396 Z", STEEL)
			+ p("M28,232 L28,280 L116,292 L116,220 Z", STEEL)
			+ p("M484,232 L484,280 L396,292 L396,220 Z", STEEL)
			+ c(256, 256, 40, GOLD)),
		"repair_field": icon(
			p("M256,444 C256,444 60,320 60,190 C60,118 116,64 186,64 C224,64 256,84 256,84 C256,84 288,64 326,64 C396,64 452,118 452,190 C452,320 256,444 256,444 Z", PINK)
			+ p("M226,150 L286,150 L286,208 L344,208 L344,268 L286,268 L286,326 L226,326 L226,268 L168,268 L168,208 L226,208 Z", "#fff0f6")),
		"impact_core": icon(
			c(256, 256, 96, ORANGE)
			+ p("M256,44 L292,140 L220,140 Z", GOLD)
			+ p("M256,468 L292,372 L220,372 Z", GOLD)
			+ p("M44,256 L140,220 L140,292 Z", GOLD)
			+ p("M468,256 L372,220 L372,292 Z", GOLD),
			c(224, 224, 26, "#fff3bf")),
		"cryo_round": icon(
			p("M256,26 L288,150 L256,182 L224,150 Z", BLUE)
			+ p("M256,486 L288,362 L256,330 L224,362 Z", BLUE)
			+ p("M26,256 L150,224 L182,256 L150,288 Z", BLUE)
			+ p("M486,256 L362,224 L330,256 L362,288 Z", BLUE)
			+ c(256, 256, 74, "#a5d8ff"),
			c(232, 232, 20, "#f1f8ff")),
		"lucky_coin": icon(
			c(256, 256, 196, GOLD)
			+ c(256, 256, 140, "#ffe066")
			+ p("M256,142 L292,222 L378,232 L314,290 L332,376 L256,332 L180,376 L198,290 L134,232 L220,222 Z", GOLD)),
		"war_drum": icon(
			rect(76, 152, 360, 208, RED, 26)
			+ rect(76, 152, 360, 44, "#ffe066", 20)
			+ rect(76, 316, 360, 44, "#ffe066", 20)
			+ p("M170,116 L206,42 M342,116 L306,42", "none")),
		"bulwark": icon(
			p("M256,40 L448,110 L448,282 C448,382 356,448 256,472 C156,448 64,382 64,282 L64,110 Z", BLUE)
			+ p("M256,116 L376,160 L376,280 C376,346 320,392 256,410 Z", "#a5d8ff")),
		"overclock": icon(
			p("M300,26 L118,282 L232,282 L212,486 L394,230 L280,230 Z", GOLD)),
		"arsenal_link": icon(
			p("M186,146 C118,146 62,202 62,270 C62,338 118,394 186,394 L246,394 L246,320 L186,320 C158,320 136,298 136,270 C136,242 158,220 186,220 L246,220 L246,146 Z", STEEL_L)
			+ p("M326,146 C394,146 450,202 450,270 C450,338 394,394 326,394 L266,394 L266,320 L326,320 C354,320 376,298 376,270 C376,242 354,220 326,220 L266,220 L266,146 Z", STEEL)),
		"lone_wolf": icon(
			p("M256,466 C130,466 74,368 74,268 L74,86 L182,158 L256,124 L330,158 L438,86 L438,268 C438,368 382,466 256,466 Z", STEEL_L)
			+ c(190, 258, 32, INK) + c(322, 258, 32, INK)
			+ p("M256,318 L300,362 L256,398 L212,362 Z", STEEL_D)),
		"hoarder": icon(
			p("M156,166 L356,166 C412,232 448,308 448,368 C448,432 372,470 256,470 C140,470 64,432 64,368 C64,308 100,232 156,166 Z", WOOD)
			+ p("M150,166 L362,166 L330,90 L182,90 Z", WOOD_D)
			+ c(256, 340, 66, GOLD)),
		"duelist": icon(
			p("M78,110 L134,54 L400,354 L376,410 L318,398 Z", SILVER)
			+ p("M434,110 L378,54 L112,354 L136,410 L194,398 Z", STEEL_L)),
		"quartermaster": icon(
			p("M256,42 L456,142 L456,370 L256,470 L56,370 L56,142 Z", WOOD)
			+ p("M56,142 L256,242 L456,142 M256,242 L256,470", "none")
			+ rect(196, 268, 120, 60, GOLD, 10)),
	}

func _init() -> void:
	var made := 0
	var sets := {"w": weapons(), "i": items()}
	for prefix in sets:
		var group: Dictionary = sets[prefix]
		for id in group:
			var path := "res://assets/icons/%s_%s.svg" % [prefix, id]
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				print("FAILED ", path)
				continue
			f.store_string(String(group[id]))
			f.close()
			made += 1
	print("wrote %d icons" % made)
	quit()

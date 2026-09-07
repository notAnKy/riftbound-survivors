extends SceneTree

# The eleven weapons, drawn as SVG into assets/icons/ where Icons already looks
# for them. No code changes anywhere: `Icons.weapon` resolves `w_<id>.svg` and
# the rack, the shop and the HUD all go through it.
#
# Two constraints these have to respect, both inherited rather than chosen.
#
# They are **monochrome**. Icons.draw_icon tints the glyph with the weapon's own
# colour through `modulate`, so one asset serves every rarity -- multi-coloured
# art would be flattened to a single hue the moment it was drawn. That rules out
# the dark-outline-plus-flat-fill treatment the actors get, so these carry their
# weight as bold silhouettes with cut-out negative space instead. Which is the
# right answer next to the actors anyway: the old game-icons glyphs were fussy
# line art, and fussy detail at 30px beside a chunky slime reads as noise.
#
# They **point right**. The rack rotates each icon by `weapon.aim`, so +X is
# forward. An icon drawn pointing any other way aims wrong on every shot.
#
# Authored at a 512 viewBox to match what the existing .import files expect
# (svg/scale = 0.25, so 512 rasterises to the 128px an icon is drawn from).

const OUT := "res://assets/icons/w_%s.svg"

static func svg(body: String) -> String:
	return ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512' width='512' height='512'>"
		+ "<g fill='#ffffff'>" + body + "</g></svg>")

static func weapons() -> Dictionary:
	return {
		# Blocky sidearm: barrel along the top, grip swept back under it.
		"pistol": svg("<path d='M96,196 L392,196 L392,262 L250,262 L214,368 L112,368 L150,262 L96,262 Z'/>"
			+ "<rect x='150' y='214' width='210' height='26' fill='#000' fill-opacity='0'/>"),
		# A shaft with a star on the business end.
		"wand": svg("<path d='M92,330 L300,180 L336,228 L128,378 Z'/>"
			+ "<path d='M386,110 L410,178 L478,202 L410,226 L386,294 L362,226 L294,202 L362,178 Z'/>"),
		# Two stacked barrels and a stock: wide, and unmistakably not the rifle.
		"shotgun": svg("<path d='M150,186 L446,186 L446,238 L150,238 Z'/>"
			+ "<path d='M150,258 L446,258 L446,310 L150,310 Z'/>"
			+ "<path d='M60,180 L150,180 L150,316 L60,376 Z'/>"),
		# Compact body, magazine hanging under the front.
		"smg": svg("<path d='M96,198 L400,198 L400,258 L96,258 Z'/>"
			+ "<path d='M188,258 L252,258 L252,388 L188,388 Z'/>"
			+ "<path d='M60,196 L110,196 L110,330 L60,300 Z'/>"),
		# Long barrel, scope on top, stock behind: the silhouette says reach.
		"rifle": svg("<path d='M104,226 L470,226 L470,278 L104,278 Z'/>"
			+ "<path d='M196,164 L322,164 L322,214 L196,214 Z'/>"
			+ "<path d='M40,214 L104,214 L104,332 L40,296 Z'/>"
			+ "<path d='M196,278 L246,278 L226,352 L176,352 Z'/>"),
		# One long line and a point. Nothing else in the rack is this thin.
		"lance": svg("<path d='M40,236 L360,236 L360,196 L488,256 L360,316 L360,276 L40,276 Z'/>"),
		# Stub barrel throwing a cone of pellets.
		"scatter": svg("<path d='M64,206 L236,206 L236,306 L64,306 Z'/>"
			+ "<path d='M248,190 L318,150 L318,362 L248,322 Z'/>"
			+ "<circle cx='372' cy='170'  r='30'/><circle cx='412' cy='256' r='30'/>"
			+ "<circle cx='372' cy='342' r='30'/>"),
		# Sword: triangular blade, crossguard, handle. Edge forward.
		"blade": svg("<path d='M198,214 L360,214 L488,256 L360,298 L198,298 Z'/>"
			+ "<path d='M162,158 L206,158 L206,354 L162,354 Z'/>"
			+ "<path d='M40,232 L162,232 L162,280 L40,280 Z'/>"
			+ "<circle cx='40' cy='256' r='34'/>"),
		# All the mass at the far end, which is the whole idea of a hammer.
		"hammer": svg("<path d='M300,120 L470,120 L470,392 L300,392 Z'/>"
			+ "<path d='M254,176 L300,176 L300,336 L254,336 Z'/>"
			+ "<path d='M40,232 L254,232 L254,280 L40,280 Z'/>"),
		# Dart with swept fins: reads as something that steers.
		"seeker": svg("<path d='M170,214 L340,214 L480,256 L340,298 L170,298 Z'/>"
			+ "<path d='M84,150 L182,214 L182,298 L84,362 L128,256 Z'/>"
			+ "<path d='M196,120 L262,196 L200,196 Z'/><path d='M196,392 L262,316 L200,316 Z'/>"),
		# Radially symmetric on purpose: an orbital does not point anywhere.
		"orb": svg("<circle cx='256' cy='256' r='96'/>"
			+ "<circle cx='256' cy='72'  r='40'/><circle cx='256' cy='440' r='40'/>"
			+ "<circle cx='72'  cy='256' r='40'/><circle cx='440' cy='256' r='40'/>"),
	}

func _init() -> void:
	var made := 0
	for id in weapons():
		var path: String = OUT % id
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			print("FAILED to open ", path)
			continue
		f.store_string(String(weapons()[id]))
		f.close()
		made += 1
	print("wrote %d weapon icons" % made)
	quit()

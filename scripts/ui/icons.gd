class_name Icons
extends RefCounted

# Weapon and item icons, drawn by `tests/draw_icons.gd` in the same heavy-outline
# style as the actors so the shop and the arena look like one game.
#
# They used to be white game-icons.net glyphs tinted through `modulate`, so one
# asset covered every rarity colour. The art is full colour now and the tint is
# gone: a shop card already states rarity in its border and its title, and
# saying it a third time through the icon cost the art all of its colour. The
# `color` argument survives for the missing-icon fallback, which still has to
# draw *something* and has no art to take a colour from.
#
# Imported at svg/scale = 0.25, so a 512px source rasterises to 128px -- still
# far more than the ~30px an icon is ever drawn at, without holding a megabyte
# of texture per glyph.

const WEAPON_PATH := "res://assets/icons/w_%s.svg"
const ITEM_PATH := "res://assets/icons/i_%s.svg"

# load() caches internally, but this avoids the path lookup on every draw, and
# an icon is drawn many times per frame across the shop, rack and HUD.
static var _cache: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[path]

# Level-up rewards are stat grants, so they borrow the icon of the item that
# grants the same thing. No extra art, and the two screens teach each other.
const STAT_ICON := {
	"damage": "focus_lens", "attack_speed": "hair_trigger", "max_hp": "ration_pack",
	"armor": "scrap_plate", "pickup_radius": "magnet_core", "speed": "coil_spring",
	"crit_chance": "honed_edge", "crit_damage": "honed_edge", "attack_range": "long_barrel",
	"lifesteal": "leech_rune", "harvesting": "salvage_rig", "luck": "lucky_coin",
	"dodge": "ghost_step", "hp_regen": "repair_field",
	"knockback": "impact_core", "slow": "cryo_round",
}

# Items that borrow another item's glyph, for the same reason the stat grants
# do: the art already says the right thing, and a second near-identical medical
# icon would only make the shop harder to read at a glance.
const ITEM_ALIAS := {
	"vital_spring": "repair_field",
	"field_medic": "ration_pack",
}

# The one place an item id turns into a path, so an alias cannot be honoured in
# the drawing and missed by anything else that asks whether the art exists.
static func item_path(id: String) -> String:
	return ITEM_PATH % String(ITEM_ALIAS.get(id, id))

static func stat(canvas: CanvasItem, stat_name: String, at: Vector2, size: float, color: Color) -> void:
	item(canvas, String(STAT_ICON.get(stat_name, "focus_lens")), at, size, color)

static func weapon(canvas: CanvasItem, id: String, at: Vector2, size: float, color: Color) -> void:
	draw_icon(canvas, WEAPON_PATH % id, at, size, color)

static func item(canvas: CanvasItem, id: String, at: Vector2, size: float, color: Color) -> void:
	draw_icon(canvas, item_path(id), at, size, color)

# `at` is the centre and `size` the half-extent, so a call site can swap an
# icon for another without touching its layout.
static func draw_icon(canvas: CanvasItem, path: String, at: Vector2, size: float, color: Color) -> void:
	var tex := texture(path)
	if tex == null:
		# A missing icon should read as a gap, not crash a screen mid-draw.
		canvas.draw_arc(at, size * 0.7, 0.0, TAU, 20, color, maxf(1.0, size * 0.16))
		return
	canvas.draw_texture_rect(tex, Rect2(at - Vector2(size, size), Vector2(size, size) * 2.0), false)

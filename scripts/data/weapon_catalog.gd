class_name WeaponCatalog
extends RefCounted

# Weapons are defined once at tier 1; higher tiers are the same weapon scaled.
# That keeps the catalog small and makes combining three of a kind meaningful
# without hand-authoring four stat blocks per weapon.
const MAX_TIER := 4
const TIER_DAMAGE := 1.62
const TIER_COOLDOWN := 0.91
const TIER_PRICE := 2.4
const TIER_NAMES := ["I", "II", "III", "IV"]

static func all() -> Array[Dictionary]:
	return [
		{"id":"pistol", "name":"PLASMA PISTOL", "price":8, "damage":11.0,
			"cooldown":0.5, "range":330.0, "bullet_speed":700.0, "pierce":0,
			"shots":1, "spread":0.0, "color":Color("62e8ff"),
			"text":"Reliable energy bolts"},
		{"id":"wand", "name":"RUNE WAND", "price":14, "damage":19.0,
			"cooldown":0.85, "range":380.0, "bullet_speed":540.0, "pierce":2,
			"shots":1, "spread":0.0, "color":Color("bf8cff"),
			"text":"Bolts punch through three targets"},
		{"id":"shotgun", "name":"VOID SHOTGUN", "price":16, "damage":7.0,
			"cooldown":0.95, "range":230.0, "bullet_speed":590.0, "pierce":0,
			"shots":5, "spread":0.26, "color":Color("ffcc70"),
			"text":"Five pellets, brutal up close"},
		{"id":"smg", "name":"SPLINTER SMG", "price":12, "damage":5.0,
			"cooldown":0.16, "range":260.0, "bullet_speed":760.0, "pierce":0,
			"shots":1, "spread":0.09, "color":Color("8cffd1"),
			"text":"Very fast, very light hits"},
		{"id":"rifle", "name":"ARC RIFLE", "price":20, "damage":34.0,
			"cooldown":1.25, "range":520.0, "bullet_speed":950.0, "pierce":1,
			"shots":1, "spread":0.0, "color":Color("82b7ff"),
			"text":"Long reach, heavy single shots"},
		{"id":"lance", "name":"RIFT LANCE", "price":26, "damage":58.0,
			"cooldown":1.9, "range":300.0, "bullet_speed":620.0, "pierce":4,
			"shots":1, "spread":0.0, "color":Color("ff8d6d"),
			"text":"Skewers a whole line of enemies"},
		{"id":"scatter", "name":"SCRAP CANNON", "price":18, "damage":12.0,
			"cooldown":1.05, "range":290.0, "bullet_speed":560.0, "pierce":1,
			"shots":3, "spread":0.16, "color":Color("ffd166"),
			"text":"Three heavy piercing slugs"},
	]

static func get_weapon(id: String) -> Dictionary:
	for def in all():
		if def.id == id: return def
	return all()[0]

static func tier_label(tier: int) -> String:
	return TIER_NAMES[clampi(tier - 1, 0, MAX_TIER - 1)]

static func display_name(id: String, tier: int) -> String:
	return "%s %s" % [get_weapon(id).name, tier_label(tier)]

static func damage_at(id: String, tier: int) -> float:
	return float(get_weapon(id).damage) * pow(TIER_DAMAGE, tier - 1)

static func cooldown_at(id: String, tier: int) -> float:
	return float(get_weapon(id).cooldown) * pow(TIER_COOLDOWN, tier - 1)

static func price_at(id: String, tier: int) -> int:
	return int(round(float(get_weapon(id).price) * pow(TIER_PRICE, tier - 1)))

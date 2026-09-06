class_name WeaponCatalog
extends RefCounted

# Weapons are defined once at tier 1; higher tiers are the same weapon scaled.
# That keeps the catalog small and makes combining three of a kind meaningful
# without hand-authoring four stat blocks per weapon.
#
# `kind` is the verb, and it is what stops every weapon being the same thing
# with different numbers:
#   ranged  - fires a projectile at the nearest target in reach
#   homing  - same, but the shot steers after its target
#   melee   - no projectile; sweeps an arc and knocks back what it hits
#   orbital - a shard circling the player, grinding whatever it passes over
const MAX_TIER := 4
const TIER_DAMAGE := 1.62
const TIER_COOLDOWN := 0.91
const TIER_PRICE := 2.4
const TIER_NAMES := ["I", "II", "III", "IV"]
const KINDS := ["ranged", "homing", "melee", "orbital"]

static func all() -> Array[Dictionary]:
	return [
		{"id":"pistol", "name":"PLASMA PISTOL", "kind":"ranged", "sound":"light", "price":8,
			"damage":14.0, "cooldown":0.5, "range":330.0, "bullet_speed":700.0,
			"pierce":0, "shots":1, "spread":0.0, "color":Color("62e8ff"),
			"text":"Reliable energy bolts"},
		{"id":"wand", "name":"RUNE WAND", "kind":"ranged", "sound":"medium", "price":14,
			"damage":24.0, "cooldown":0.85, "range":380.0, "bullet_speed":540.0,
			"pierce":2, "shots":1, "spread":0.0, "color":Color("bf8cff"),
			"text":"Bolts punch through three targets"},
		{"id":"shotgun", "name":"VOID SHOTGUN", "kind":"ranged", "sound":"heavy", "price":16,
			"damage":9.0, "cooldown":0.95, "range":230.0, "bullet_speed":590.0,
			"pierce":0, "shots":5, "spread":0.26, "color":Color("ffcc70"),
			"text":"Five pellets, brutal up close"},
		{"id":"smg", "name":"SPLINTER SMG", "kind":"ranged", "sound":"light", "price":12,
			"damage":6.5, "cooldown":0.16, "range":260.0, "bullet_speed":760.0,
			"pierce":0, "shots":1, "spread":0.09, "color":Color("8cffd1"),
			"text":"Very fast, very light hits"},
		{"id":"rifle", "name":"ARC RIFLE", "kind":"ranged", "sound":"heavy", "price":20,
			"damage":43.0, "cooldown":1.25, "range":520.0, "bullet_speed":950.0,
			"pierce":1, "shots":1, "spread":0.0, "color":Color("82b7ff"),
			"text":"Long reach, heavy single shots"},
		{"id":"lance", "name":"RIFT LANCE", "kind":"ranged", "sound":"heavy", "price":26,
			"damage":73.0, "cooldown":1.9, "range":300.0, "bullet_speed":620.0,
			"pierce":4, "shots":1, "spread":0.0, "color":Color("ff8d6d"),
			"text":"Skewers a whole line of enemies"},
		{"id":"scatter", "name":"SCRAP CANNON", "kind":"ranged", "sound":"medium", "price":18,
			"damage":15.0, "cooldown":1.05, "range":290.0, "bullet_speed":560.0,
			"pierce":1, "shots":3, "spread":0.16, "color":Color("ffd166"),
			"text":"Three heavy piercing slugs"},

		{"id":"blade", "name":"RIFT BLADE", "kind":"melee", "sound":"medium", "price":13,
			"damage":26.0, "cooldown":0.62, "range":150.0, "bullet_speed":0.0,
			"pierce":0, "shots":1, "spread":0.0, "arc":2.0, "knockback":300.0,
			"color":Color("ff6d8d"), "text":"Sweeps everything in front of you"},
		{"id":"hammer", "name":"PULSE HAMMER", "kind":"melee", "sound":"heavy", "price":24,
			"damage":78.0, "cooldown":1.55, "range":185.0, "bullet_speed":0.0,
			"pierce":0, "shots":1, "spread":0.0, "arc":2.7, "knockback":720.0,
			"color":Color("ffa657"), "text":"Slow, huge, hurls them back"},
		{"id":"seeker", "name":"SEEKER DARTS", "kind":"homing", "sound":"light", "price":19,
			"damage":13.0, "cooldown":0.55, "range":420.0, "bullet_speed":330.0,
			"pierce":0, "shots":2, "spread":0.5, "homing":7.0,
			"color":Color("69f4d4"), "text":"Slow darts that chase their target"},
		{"id":"orb", "name":"VOID ORB", "kind":"orbital", "sound":"medium", "price":21,
			"damage":17.0, "cooldown":0.35, "range":300.0, "bullet_speed":0.0,
			"pierce":0, "shots":1, "spread":0.0, "orbit_radius":110.0,
			"orbit_speed":2.4, "orbit_hit":34.0,
			"color":Color("ae7cff"), "text":"Circles you, grinding what it touches"},
	]

static func get_weapon(id: String) -> Dictionary:
	for def in all():
		if def.id == id: return def
	return all()[0]

# Characters can restrict which verbs they are allowed to carry; an empty list
# means no restriction.
static func of_kinds(kinds: Array) -> Array[Dictionary]:
	if kinds.is_empty(): return all()
	return all().filter(func(def: Dictionary) -> bool: return String(def.kind) in kinds)

static func allows(id: String, kinds: Array) -> bool:
	return kinds.is_empty() or String(get_weapon(id).kind) in kinds

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

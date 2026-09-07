class_name EnemyCatalog
extends RefCounted

# Tints are white. They used to be pushed over 1.0 to lift dark pixel art off a
# floor of the same value; the art is its own flat colour now, and multiplying a
# bright vector fill only washes it out. `hit_flash` still multiplies from here,
# so white is also what makes a hit read.
# One entry per enemy. `hp`/`speed` are multipliers against the round curve;
# `unlock_round` is the first round the type can appear in.
#
# The unlock rounds are deliberately one apart from wave 5 onward. Wave 5
# already carries the first boss and the spawn-batch step, and stacking two
# new enemy types onto wave 6 as well is what made it a wall.
static var _cache: Array[Dictionary] = []
static var _by_id: Dictionary = {}
static var _bosses: Array[Dictionary] = []

static func all() -> Array[Dictionary]:
	if _cache.is_empty(): _build()
	return _cache

static func _build() -> void:
	_cache = _definitions()
	_by_id = {}
	for def in _cache: _by_id[String(def.id)] = def

static func _definitions() -> Array[Dictionary]:
	return [
		{"id":"husk", "name":"HUSK", "texture":"e_husk", "behaviour":"chase",
			"hp":1.0, "speed":1.0, "radius":12.0, "scale":0.9, "damage":8.0,
			"cooldown":0.8, "material":1, "tint":Color(1,1,1), "unlock_round":1},
		{"id":"runner", "name":"RUNNER", "texture":"e_runner", "behaviour":"weave",
			"hp":0.82, "speed":1.5, "radius":10.0, "scale":0.8, "damage":6.0,
			"cooldown":0.7, "material":1, "tint":Color(1,1,1), "unlock_round":2},
		{"id":"gunner", "name":"GUNNER", "texture":"e_gunner", "behaviour":"shooter",
			"hp":1.1, "speed":0.86, "radius":11.0, "scale":0.9, "damage":7.0,
			"cooldown":1.5, "material":2, "tint":Color(1,1,1), "unlock_round":3,
			"range":230.0, "bullet_speed":300.0},
		{"id":"brute", "name":"BRUTE", "texture":"e_brute", "behaviour":"chase",
			"hp":3.6, "speed":0.56, "radius":18.0, "scale":1.3, "damage":16.0,
			"cooldown":1.1, "material":3, "tint":Color(1,1,1), "unlock_round":4},
		{"id":"marauder", "name":"MARAUDER", "texture":"e_marauder", "behaviour":"chase",
			"hp":1.8, "speed":1.15, "radius":13.0, "scale":1.0, "damage":11.0,
			"cooldown":0.9, "material":2, "tint":Color(1,1,1), "unlock_round":6},
		{"id":"warden", "name":"WARDEN", "texture":"e_warden", "behaviour":"weave",
			"hp":1.5, "speed":1.25, "radius":12.0, "scale":0.95, "damage":10.0,
			"cooldown":0.85, "material":2, "tint":Color(1,1,1), "unlock_round":9},
		{"id":"splitter", "name":"SPLITTER", "texture":"e_splitter", "behaviour":"chase",
			"hp":2.1, "speed":0.9, "radius":16.0, "scale":1.25, "damage":9.0,
			"cooldown":0.9, "material":2, "tint":Color(1,1,1), "unlock_round":5,
			"splits":{"into":"husk", "count":2}},
		{"id":"bloater", "name":"BLOATER", "texture":"e_bloater", "behaviour":"chase",
			"hp":1.3, "speed":1.0, "radius":14.0, "scale":1.1, "damage":5.0,
			"cooldown":1.0, "material":2, "tint":Color(1,1,1), "unlock_round":7,
			"explodes":{"radius":165.0, "damage":26.0}},
		{"id":"charger", "name":"CHARGER", "texture":"e_charger", "behaviour":"charge",
			"hp":1.35, "speed":0.75, "radius":13.0, "scale":1.05, "damage":15.0,
			"cooldown":1.2, "material":3, "tint":Color(1,1,1), "unlock_round":8,
			"charge_range":340.0, "charge_speed":5.4, "charge_windup":0.65, "charge_time":0.5},
	]

static func get_enemy(id: String) -> Dictionary:
	if _by_id.is_empty(): _build()
	return _by_id.get(id, _cache[0])

# Bosses alternate by boss round, so wave 5 and wave 10 are not the same fight.
static func bosses() -> Array[Dictionary]:
	if _bosses.is_empty(): _bosses = _boss_definitions()
	return _bosses

static func _boss_definitions() -> Array[Dictionary]:
	return [
		{"id":"riftlord", "name":"RIFTLORD", "texture":"e_riftlord", "behaviour":"boss",
			"hp":1.0, "speed":1.0, "radius":32.0, "scale":2.3, "damage":26.0,
			"cooldown":1.1, "material":25, "tint":Color(1,1,1), "unlock_round":5},
		{"id":"voidcaller", "name":"VOIDCALLER", "texture":"e_voidcaller", "behaviour":"shooter",
			"hp":1.0, "speed":1.15, "radius":29.0, "scale":2.1, "damage":19.0,
			"cooldown":0.7, "material":25, "tint":Color(1,1,1), "unlock_round":10,
			"range":430.0, "bullet_speed":360.0},
	]

static func boss(round_number: int = 5) -> Dictionary:
	var index: int = maxi(0, int(round_number / 5) - 1)
	var list := bosses()
	return list[index % list.size()]

static func available(round_number: int) -> Array[Dictionary]:
	return all().filter(func(def: Dictionary) -> bool: return round_number >= int(def.unlock_round))

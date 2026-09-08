class_name ItemCatalog
extends RefCounted

# Passive items. `stats` is a flat additive modifier.
#
# `per` makes an item scale off the rest of the build:
#   {"stat": "damage", "amount": 4.0, "of": "weapons"}  = +4% damage per
#   weapon held. `of` is counted by GameSession.synergy_count, and because
#   the count changes whenever the inventory does, the whole stat sheet is
#   rebuilt from scratch rather than added to once.
#
# `min_round` gates the stronger items out of the first shop.
static var _cache: Array[Dictionary] = []
static var _by_id: Dictionary = {}

static func all() -> Array[Dictionary]:
	if _cache.is_empty(): _build()
	return _cache

static func _build() -> void:
	_cache = _definitions()
	_by_id = {}
	for def in _cache: _by_id[String(def.id)] = def

static func _definitions() -> Array[Dictionary]:
	return [
		{"id":"scrap_plate", "name":"SCRAP PLATE", "price":18, "min_round":1,
			"stats":{"armor":3.0}, "color":Color("b6c6e8")},
		{"id":"focus_lens", "name":"FOCUS LENS", "price":16, "min_round":1,
			"stats":{"damage":8.0}, "color":Color("ff8d6d")},
		{"id":"coil_spring", "name":"COIL SPRING", "price":13, "min_round":1,
			"stats":{"speed":8.0}, "color":Color("8cffd1")},
		{"id":"hair_trigger", "name":"HAIR TRIGGER", "price":18, "min_round":1,
			"stats":{"attack_speed":10.0}, "color":Color("ffd166")},
		{"id":"ration_pack", "name":"RATION PACK", "price":16, "min_round":1,
			"stats":{"max_hp":14.0}, "color":Color("69f4d4")},
		{"id":"magnet_core", "name":"MAGNET CORE", "price":11, "min_round":1,
			"stats":{"pickup_radius":30.0}, "color":Color("8cffd1")},
		{"id":"honed_edge", "name":"HONED EDGE", "price":20, "min_round":2,
			"stats":{"crit_chance":6.0}, "color":Color("ffcf77")},
		{"id":"long_barrel", "name":"LONG BARREL", "price":17, "min_round":2,
			"stats":{"attack_range":15.0}, "color":Color("82b7ff")},
		{"id":"ghost_step", "name":"GHOST STEP", "price":30, "min_round":3,
			"stats":{"dodge":4.0}, "color":Color("bf8cff")},
		{"id":"leech_rune", "name":"LEECH RUNE", "price":32, "min_round":3,
			"stats":{"lifesteal":1.5}, "color":Color("ff718b")},
		{"id":"salvage_rig", "name":"SALVAGE RIG", "price":19, "min_round":3,
			"stats":{"harvesting":4.0}, "color":Color("ffd166")},
		{"id":"repair_field", "name":"REPAIR FIELD", "price":30, "min_round":4,
			"stats":{"hp_regen":0.55}, "color":Color("69f4d4")},
		{"id":"vital_spring", "name":"VITAL SPRING", "price":38, "min_round":3,
			"stats":{"hp_regen":0.9, "speed":-4.0}, "color":Color("8cffd1")},
		{"id":"impact_core", "name":"IMPACT CORE", "price":26, "min_round":2,
			"stats":{"knockback":6.0}, "color":Color("ffcc70")},
		{"id":"cryo_round", "name":"CRYO ROUND", "price":30, "min_round":3,
			"stats":{"slow":9.0}, "color":Color("82b7ff")},
		{"id":"lucky_coin", "name":"LUCKY COIN", "price":15, "min_round":4,
			"stats":{"luck":12.0}, "color":Color("ffe09b")},
		{"id":"war_drum", "name":"WAR DRUM", "price":34, "min_round":5,
			"stats":{"damage":14.0, "attack_speed":8.0, "max_hp":-10.0},
			"color":Color("ff6d8d")},
		{"id":"bulwark", "name":"BULWARK", "price":44, "min_round":5,
			"stats":{"armor":6.0, "max_hp":16.0, "speed":-6.0},
			"color":Color("b6c6e8")},
		{"id":"overclock", "name":"OVERCLOCK", "price":36, "min_round":6,
			"stats":{"attack_speed":22.0, "crit_chance":4.0, "armor":-4.0},
			"color":Color("ffcc70")},

		{"id":"arsenal_link", "name":"ARSENAL LINK", "price":26, "min_round":2,
			"stats":{}, "per":{"stat":"damage", "amount":5.0, "of":"weapons"},
			"color":Color("62e8ff")},
		{"id":"lone_wolf", "name":"LONE WOLF", "price":28, "min_round":2,
			"stats":{}, "per":{"stat":"damage", "amount":13.0, "of":"empty_slots"},
			"color":Color("ff8d6d")},
		{"id":"hoarder", "name":"HOARDER", "price":34, "min_round":3,
			"stats":{}, "per":{"stat":"armor", "amount":0.7, "of":"items"},
			"color":Color("b6c6e8")},
		{"id":"duelist", "name":"DUELIST", "price":30, "min_round":3,
			"stats":{}, "per":{"stat":"attack_speed", "amount":9.0, "of":"melee"},
			"color":Color("ff6d8d")},
		{"id":"quartermaster", "name":"QUARTERMASTER", "price":34, "min_round":4,
			"stats":{}, "per":{"stat":"max_hp", "amount":3.5, "of":"items"},
			"color":Color("69f4d4")},
		{"id":"field_medic", "name":"FIELD MEDIC", "price":40, "min_round":4,
			"stats":{}, "per":{"stat":"hp_regen", "amount":0.16, "of":"items"},
			"color":Color("69f4d4")},
	]

static func get_item(id: String) -> Dictionary:
	if _by_id.is_empty(): _build()
	return _by_id.get(id, _cache[0])

static func available(round_number: int) -> Array[Dictionary]:
	return all().filter(func(def: Dictionary) -> bool:
		return round_number >= int(def.min_round))

const PER_LABEL := {
	"weapons": "weapon held", "items": "item held",
	"melee": "melee weapon", "empty_slots": "empty slot",
}

# "+8% Damage, -10 Max HP" for the shop card and the item list.
static func describe(def: Dictionary) -> String:
	var parts: Array[String] = []
	if def.has("per"):
		var per: Dictionary = def.per
		var name := String(per.stat)
		var suffix := "%" if name in Stats.PERCENT else ""
		parts.append("+%s%s %s per %s" % [_trim(float(per.amount)), suffix,
			Stats.LABELS.get(name, name), PER_LABEL.get(String(per.of), String(per.of))])
	for key in def.stats:
		var name := String(key)
		var amount := float(def.stats[key])
		var suffix := "%" if name in Stats.PERCENT else ""
		var label: String = Stats.LABELS.get(name, name)
		parts.append("%s%s%s %s" % ["+" if amount > 0.0 else "", _trim(amount), suffix, label])
	return ", ".join(parts)

static func _trim(amount: float) -> String:
	if is_equal_approx(amount, round(amount)): return str(int(round(amount)))
	return "%.1f" % amount

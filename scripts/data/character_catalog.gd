class_name CharacterCatalog
extends RefCounted

# hp and speed are the run baseline; `stats` is layered on top as modifiers.
# `slots` and `kinds` are what turn a character into a strategy rather than a
# stat block: fewer weapons, or only one verb allowed, forces a whole build.
# An empty `kinds` means no restriction. `weapon` is the fallback starting
# weapon when the armory pick is not allowed.
static var _cache: Array[Dictionary] = []

static func all() -> Array[Dictionary]:
	if _cache.is_empty(): _cache = _definitions()
	return _cache

static func _definitions() -> Array[Dictionary]:
	return [
		{"name":"RIFT RUNNER", "description":"Balanced survivor", "cost":0,
			"hp":100.0, "speed":290.0, "slots":6, "kinds":[], "weapon":"pistol",
			"stats":{}, "color":Color("5eead4")},
		{"name":"ARCANE WARDEN", "description":"Glass cannon mage", "cost":30,
			"hp":80.0, "speed":280.0, "slots":6, "kinds":[], "weapon":"wand",
			"stats":{"damage":22.0, "crit_chance":5.0, "armor":-3.0}, "color":Color("bf8cff")},
		{"name":"IRON REVENANT", "description":"Armored undead hunter", "cost":60,
			"hp":145.0, "speed":250.0, "slots":6, "kinds":[], "weapon":"pistol",
			"stats":{"armor":10.0, "damage":-8.0, "hp_regen":0.8}, "color":Color("ff8d6d")},
		{"name":"BLADE DANCER", "description":"Melee only. Fast, fragile, in your face", "cost":80,
			"hp":90.0, "speed":350.0, "slots":6, "kinds":["melee"], "weapon":"blade",
			"stats":{"damage":30.0, "attack_speed":15.0, "dodge":8.0}, "color":Color("ff6d8d")},
		{"name":"SIEGE ENGINE", "description":"Only three weapons, but each one hits like a truck", "cost":110,
			"hp":130.0, "speed":215.0, "slots":3, "kinds":[], "weapon":"rifle",
			"stats":{"damage":90.0, "attack_speed":-15.0, "armor":6.0}, "color":Color("ffd166")},
		{"name":"SCAVENGER", "description":"Feeble in a fight, rich in the shop", "cost":90,
			"hp":95.0, "speed":300.0, "slots":6, "kinds":[], "weapon":"smg",
			"stats":{"harvesting":6.0, "luck":30.0, "pickup_radius":60.0, "damage":-15.0},
			"color":Color("8cffd1")}
	]

static func get_character(index: int) -> Dictionary:
	return all()[clampi(index, 0, all().size() - 1)]

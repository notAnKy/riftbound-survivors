class_name CharacterCatalog
extends RefCounted

# hp and speed are the run baseline; `stats` is layered on top as modifiers,
# which is what gives each character a shape rather than just bigger numbers.
static func all() -> Array[Dictionary]:
	return [
		{"name":"RIFT RUNNER", "description":"Balanced survivor", "cost":0, "hp":100.0, "speed":290.0,
			"stats":{}, "color":Color("5eead4")},
		{"name":"ARCANE WARDEN", "description":"Glass cannon mage", "cost":30, "hp":80.0, "speed":280.0,
			"stats":{"damage":22.0, "crit_chance":5.0, "armor":-3.0}, "color":Color("bf8cff")},
		{"name":"IRON REVENANT", "description":"Armored undead hunter", "cost":60, "hp":140.0, "speed":250.0,
			"stats":{"armor":10.0, "damage":-8.0, "hp_regen":0.8}, "color":Color("ff8d6d")}
	]

static func get_character(index: int) -> Dictionary:
	return all()[clampi(index, 0, all().size() - 1)]

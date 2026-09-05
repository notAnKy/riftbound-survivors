class_name CharacterCatalog
extends RefCounted

static func all() -> Array[Dictionary]:
	return [
		{"name":"RIFT RUNNER", "description":"Balanced survivor", "cost":0, "hp":100.0, "speed":290.0, "damage":1.0, "color":Color("5eead4")},
		{"name":"ARCANE WARDEN", "description":"Harder-hitting mage", "cost":30, "hp":85.0, "speed":280.0, "damage":1.25, "color":Color("bf8cff")},
		{"name":"IRON REVENANT", "description":"Armored undead hunter", "cost":60, "hp":135.0, "speed":250.0, "damage":0.9, "color":Color("ff8d6d")}
	]

static func get_character(index: int) -> Dictionary:
	return all()[clampi(index, 0, 2)]

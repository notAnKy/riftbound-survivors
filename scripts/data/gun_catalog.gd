class_name GunCatalog
extends RefCounted

static func all() -> Array[Dictionary]:
	return [
		{"name": "PLASMA BLASTER", "description": "Fast energy bolts", "cost":0, "color": Color("62e8ff")},
		{"name": "RUNE WAND", "description": "Piercing arcane bolts", "cost":25, "color": Color("bf8cff")},
		{"name": "VOID SHOTGUN", "description": "Wide close-range blast", "cost":50, "color": Color("ffcc70")}
	]

static func get_gun(index: int) -> Dictionary:
	return all()[clampi(index, 0, 2)]

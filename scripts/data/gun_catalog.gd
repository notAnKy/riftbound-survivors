class_name GunCatalog
extends RefCounted

# The armory picks which weapon a run starts with. Each entry points at a
# WeaponCatalog id; the cost and unlock live here because they are profile
# progression, not weapon balance.
static func all() -> Array[Dictionary]:
	return [
		{"name": "PLASMA BLASTER", "description": "Fast energy bolts", "cost":0, "weapon":"pistol", "color": Color("62e8ff")},
		{"name": "RUNE WAND", "description": "Piercing arcane bolts", "cost":25, "weapon":"wand", "color": Color("bf8cff")},
		{"name": "VOID SHOTGUN", "description": "Wide close-range blast", "cost":50, "weapon":"shotgun", "color": Color("ffcc70")}
	]

static func get_gun(index: int) -> Dictionary:
	return all()[clampi(index, 0, all().size() - 1)]

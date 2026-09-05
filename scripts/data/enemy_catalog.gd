class_name EnemyCatalog
extends RefCounted

# One entry per enemy. `hp`/`speed` are multipliers against the round curve;
# `unlock_round` is the first round the type can appear in.
static func all() -> Array[Dictionary]:
	return [
		{"id":"husk", "name":"HUSK", "texture":"zombie", "behaviour":"chase",
			"hp":1.0, "speed":1.0, "radius":13.0, "scale":1.0, "damage":8.0,
			"cooldown":0.8, "material":1, "tint":Color(0.86,1.0,0.82), "unlock_round":1},
		{"id":"runner", "name":"RUNNER", "texture":"runner", "behaviour":"weave",
			"hp":0.82, "speed":1.5, "radius":11.0, "scale":0.9, "damage":6.0,
			"cooldown":0.7, "material":1, "tint":Color(0.82,0.9,1.0), "unlock_round":2},
		{"id":"gunner", "name":"GUNNER", "texture":"robot", "behaviour":"shooter",
			"hp":1.1, "speed":0.86, "radius":12.0, "scale":1.0, "damage":7.0,
			"cooldown":1.5, "material":2, "tint":Color(1,1,1), "unlock_round":3,
			"range":230.0, "bullet_speed":300.0},
		{"id":"brute", "name":"BRUTE", "texture":"brute", "behaviour":"chase",
			"hp":3.6, "speed":0.56, "radius":20.0, "scale":1.5, "damage":16.0,
			"cooldown":1.1, "material":3, "tint":Color(1,0.86,0.8), "unlock_round":4},
		{"id":"marauder", "name":"MARAUDER", "texture":"soldier", "behaviour":"chase",
			"hp":1.8, "speed":1.15, "radius":14.0, "scale":1.1, "damage":11.0,
			"cooldown":0.9, "material":2, "tint":Color(1,1,1), "unlock_round":6},
		{"id":"warden", "name":"WARDEN", "texture":"warden", "behaviour":"weave",
			"hp":1.5, "speed":1.25, "radius":13.0, "scale":1.05, "damage":10.0,
			"cooldown":0.85, "material":2, "tint":Color(0.88,1.0,0.9), "unlock_round":8},
	]

static func boss() -> Dictionary:
	return {"id":"riftlord", "name":"RIFTLORD", "texture":"boss", "behaviour":"boss",
		"hp":1.0, "speed":1.0, "radius":36.0, "scale":2.6, "damage":26.0,
		"cooldown":1.1, "material":25, "tint":Color(1,0.82,0.86), "unlock_round":5}

static func available(round_number: int) -> Array[Dictionary]:
	return all().filter(func(def: Dictionary) -> bool: return round_number >= int(def.unlock_round))

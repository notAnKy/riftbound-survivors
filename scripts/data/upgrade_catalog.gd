class_name UpgradeCatalog
extends RefCounted

static func roll_choices(rng: RandomNumberGenerator, round_number: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = [
		{"title":"PLASMA CORE", "detail":"+6 damage", "apply":"damage", "rarity":"COMMON"},
		{"title":"RUNE HASTE", "detail":"+17% fire rate", "apply":"fire_rate", "rarity":"COMMON"},
		{"title":"NECRO PLATING", "detail":"+25 max health", "apply":"health", "rarity":"COMMON"},
		{"title":"PHASE TREADS", "detail":"+12% move speed", "apply":"speed", "rarity":"RARE"},
		{"title":"SOUL MAGNET", "detail":"+45 XP pickup range", "apply":"magnet", "rarity":"RARE"},
		{"title":"RIFT CROWN", "detail":"+20 damage and heal", "apply":"legendary", "rarity":"LEGENDARY"}
	]
	var choices: Array[Dictionary] = []
	while choices.size() < 3:
		var roll := rng.randf()
		var wanted := "LEGENDARY" if roll < 0.04 + round_number * 0.004 else ("RARE" if roll < 0.28 else "COMMON")
		var candidates := pool.filter(func(item: Dictionary) -> bool: return item.rarity == wanted)
		var candidate: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		if not choices.any(func(item: Dictionary) -> bool: return item.title == candidate.title): choices.append(candidate)
	return choices

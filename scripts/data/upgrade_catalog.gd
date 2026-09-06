class_name UpgradeCatalog
extends RefCounted

const CHOICES := 4

# Level-up rewards are pure stat grants now, so they read from the same sheet
# the shop items feed. Rarity decides how big the grant is, not what it does.
static func pool() -> Array[Dictionary]:
	return [
		{"title":"PLASMA CORE", "stats":{"damage":7.0}, "rarity":"COMMON"},
		{"title":"RUNE HASTE", "stats":{"attack_speed":8.0}, "rarity":"COMMON"},
		{"title":"NECRO PLATING", "stats":{"max_hp":15.0}, "rarity":"COMMON"},
		{"title":"SCRAP WEAVE", "stats":{"armor":3.0}, "rarity":"COMMON"},
		{"title":"SOUL MAGNET", "stats":{"pickup_radius":28.0}, "rarity":"COMMON"},
		{"title":"KNIT FLESH", "stats":{"hp_regen":0.5}, "rarity":"COMMON"},
		{"title":"PHASE TREADS", "stats":{"speed":9.0}, "rarity":"RARE"},
		{"title":"KEEN SIGHT", "stats":{"crit_chance":5.0}, "rarity":"RARE"},
		{"title":"LONG LENS", "stats":{"attack_range":14.0}, "rarity":"RARE"},
		{"title":"VEIN TAP", "stats":{"lifesteal":3.0}, "rarity":"RARE"},
		{"title":"SALVAGER", "stats":{"harvesting":3.0}, "rarity":"RARE"},
		{"title":"MENDING RUNE", "stats":{"hp_regen":1.1}, "rarity":"RARE"},
		{"title":"RIFT CROWN", "stats":{"damage":18.0, "max_hp":20.0}, "rarity":"LEGENDARY"},
		{"title":"VOID ENGINE", "stats":{"attack_speed":20.0, "crit_chance":6.0}, "rarity":"LEGENDARY"},
		{"title":"AEGIS SHARD", "stats":{"armor":9.0, "dodge":5.0}, "rarity":"LEGENDARY"},
		{"title":"LIVING CORE", "stats":{"hp_regen":2.2, "max_hp":25.0}, "rarity":"LEGENDARY"},
	]

static func roll_choices(rng: RandomNumberGenerator, round_number: int, luck: float = 0.0) -> Array[Dictionary]:
	var everything := pool()
	var choices: Array[Dictionary] = []
	var guard := 0
	while choices.size() < CHOICES and guard < 200:
		guard += 1
		var roll := rng.randf()
		var legendary_odds: float = 0.04 + round_number * 0.004 + luck / 900.0
		var rare_odds: float = 0.28 + luck / 500.0
		var wanted := "LEGENDARY" if roll < legendary_odds else ("RARE" if roll < rare_odds else "COMMON")
		var candidates := everything.filter(func(item: Dictionary) -> bool: return item.rarity == wanted)
		var candidate: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		if not choices.any(func(item: Dictionary) -> bool: return item.title == candidate.title):
			choices.append(candidate)
	return choices

static func describe(choice: Dictionary) -> String:
	return ItemCatalog.describe(choice)

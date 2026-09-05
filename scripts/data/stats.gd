class_name Stats
extends RefCounted

# The character sheet. Percent-style stats are stored as whole points, so
# damage = 25 means +25%, and everything that reads them goes through the
# multiplier helpers below rather than doing the /100 by hand.

const BASE := {
	"max_hp": 100.0,
	"hp_regen": 0.0,
	"lifesteal": 0.0,
	"damage": 0.0,
	"attack_speed": 0.0,
	"crit_chance": 5.0,
	"crit_damage": 100.0,
	"armor": 0.0,
	"dodge": 0.0,
	"speed": 0.0,
	"luck": 0.0,
	"harvesting": 0.0,
	"attack_range": 0.0,
	"pickup_radius": 0.0,
}

const LABELS := {
	"max_hp": "Max HP",
	"hp_regen": "HP Regen",
	"lifesteal": "Lifesteal",
	"damage": "Damage",
	"attack_speed": "Attack Speed",
	"crit_chance": "Crit Chance",
	"crit_damage": "Crit Damage",
	"armor": "Armor",
	"dodge": "Dodge",
	"speed": "Speed",
	"luck": "Luck",
	"harvesting": "Harvesting",
	"attack_range": "Range",
	"pickup_radius": "Pickup Range",
}

# Stats shown with a % sign in the UI.
const PERCENT := ["lifesteal", "damage", "attack_speed", "crit_chance",
	"crit_damage", "dodge", "speed", "luck", "attack_range"]

var values: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	values = BASE.duplicate()

func get_stat(stat: String) -> float:
	return float(values.get(stat, 0.0))

func set_stat(stat: String, amount: float) -> void:
	values[stat] = amount

func add(stat: String, amount: float) -> void:
	values[stat] = get_stat(stat) + amount

func apply_dict(mods: Dictionary) -> void:
	for key in mods:
		add(String(key), float(mods[key]))

func format(stat: String) -> String:
	var amount := get_stat(stat)
	var suffix := "%" if stat in PERCENT else ""
	return "%s%d%s" % ["+" if amount > 0.0 else "", int(round(amount)), suffix]

# Diminishing returns, so stacking armor approaches but never reaches immunity.
# 30 armor halves incoming damage; doubling it again only gets to two thirds.
func damage_taken(amount: float) -> float:
	var armor := maxf(get_stat("armor"), 0.0)
	return amount * (1.0 - armor / (armor + 30.0))

# Capped, or enough dodge would make a run unloseable.
func dodges(rng: RandomNumberGenerator) -> bool:
	return rng.randf() * 100.0 < minf(get_stat("dodge"), 60.0)

func damage_multiplier() -> float:
	return maxf(0.1, 1.0 + get_stat("damage") / 100.0)

func attack_speed_multiplier() -> float:
	return maxf(0.2, 1.0 + get_stat("attack_speed") / 100.0)

func range_multiplier() -> float:
	return maxf(0.4, 1.0 + get_stat("attack_range") / 100.0)

func speed_multiplier() -> float:
	return maxf(0.3, 1.0 + get_stat("speed") / 100.0)

# Returns the damage multiplier for this shot: 1.0, or the crit multiplier.
func roll_crit(rng: RandomNumberGenerator) -> float:
	if rng.randf() * 100.0 < get_stat("crit_chance"):
		return 1.0 + get_stat("crit_damage") / 100.0
	return 1.0

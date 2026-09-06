class_name Shop
extends RefCounted

# The between-wave shop. Holds four offers and the reroll price; it does not
# own the purse or the inventory, GameSession does, so this stays testable
# without a scene tree.

const SLOTS := 4
const REROLL_BASE := 3
const REROLL_STEP := 2
const WEAPON_CHANCE := 0.45
# How often a weapon offer is steered toward a class you already hold. Too
# low and a build never coalesces; too high and the shop stops surprising.
const CLASS_MATCH_CHANCE := 0.4

var offers: Array[Dictionary] = []
var rerolls := 0
# Set from the character. Empty means every weapon is on the table.
var allowed_kinds: Array = []
# Weapon classes the player already owns, for the bias above.
var owned_classes: Array = []

func reroll_cost() -> int:
	return REROLL_BASE + rerolls * REROLL_STEP

func open(rng: RandomNumberGenerator, round_number: int, luck: float) -> void:
	rerolls = 0
	roll(rng, round_number, luck)

func reroll(rng: RandomNumberGenerator, round_number: int, luck: float) -> void:
	rerolls += 1
	roll(rng, round_number, luck)

func roll(rng: RandomNumberGenerator, round_number: int, luck: float) -> void:
	offers.clear()
	for i in range(SLOTS):
		var offer := make_offer(rng, round_number, luck)
		# The same item twice on one board reads as a bug. Retry a few times
		# rather than looping, since the pool is small in the early rounds and
		# a strict no-duplicates rule could not always be satisfied.
		for attempt in range(6):
			if not offers.any(func(other: Dictionary) -> bool:
				return other.get("kind") == offer.kind and other.get("id") == offer.id):
				break
			offer = make_offer(rng, round_number, luck)
		offers.append(offer)

func take(index: int) -> Dictionary:
	if index < 0 or index >= offers.size(): return {}
	var offer: Dictionary = offers[index]
	if offer.is_empty(): return {}
	offers[index] = {}
	return offer

func make_offer(rng: RandomNumberGenerator, round_number: int, luck: float) -> Dictionary:
	# Prices drift up with the round so the shop keeps mattering once a run
	# is producing far more materials per wave than it did at the start.
	var inflation := 1.0 + float(round_number) * Balance.SHOP_INFLATION_PER_WAVE
	if rng.randf() < WEAPON_CHANCE:
		var defs := WeaponCatalog.of_kinds(allowed_kinds)
		# Bias toward what is already being built, so a run converges on a
		# strategy instead of handing out unrelated weapons for twenty waves.
		if not owned_classes.is_empty() and rng.randf() < CLASS_MATCH_CHANCE:
			var matching := defs.filter(func(candidate: Dictionary) -> bool:
				for id in candidate.get("classes", []):
					if id in owned_classes: return true
				return false)
			if not matching.is_empty(): defs = matching
		var def: Dictionary = defs[rng.randi_range(0, defs.size() - 1)]
		var tier := roll_tier(rng, round_number, luck)
		return {
			"kind": "weapon", "id": def.id, "tier": tier,
			"name": WeaponCatalog.display_name(def.id, tier),
			"text": def.text, "color": def.color,
			"price": int(round(float(WeaponCatalog.price_at(def.id, tier)) * inflation)),
		}
	var items := ItemCatalog.available(round_number)
	var item: Dictionary = items[rng.randi_range(0, items.size() - 1)]
	return {
		"kind": "item", "id": item.id, "tier": 1, "name": item.name,
		"text": ItemCatalog.describe(item), "color": item.color,
		"price": int(round(float(item.price) * inflation)),
	}

# Each extra tier is a second roll against the same chance, so tier IV stays
# rare early and becomes plausible late or with luck stacked.
func roll_tier(rng: RandomNumberGenerator, round_number: int, luck: float) -> int:
	var chance: float = 0.05 + float(round_number) * 0.035 + luck / 400.0
	var tier := 1
	while tier < WeaponCatalog.MAX_TIER and rng.randf() < chance:
		tier += 1
	return tier

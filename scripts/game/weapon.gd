class_name Weapon
extends RefCounted

# One equipped weapon. Every derived number goes through Stats, so an item
# bought in the shop changes all six weapons at once without touching them.

var id := "pistol"
var tier := 1
var timer := 0.0
# Where this weapon is pointing, and how recently it fired -- both purely
# for the rack drawn around the player.
var aim := 0.0
var flash := 0.0

func _init(weapon_id: String = "pistol", weapon_tier: int = 1) -> void:
	id = weapon_id
	tier = clampi(weapon_tier, 1, WeaponCatalog.MAX_TIER)

func def() -> Dictionary:
	return WeaponCatalog.get_weapon(id)

func display_name() -> String:
	return WeaponCatalog.display_name(id, tier)

func damage(stats: Stats) -> float:
	return WeaponCatalog.damage_at(id, tier) * stats.damage_multiplier()

func cooldown(stats: Stats) -> float:
	return maxf(0.05, WeaponCatalog.cooldown_at(id, tier) / stats.attack_speed_multiplier())

# Not called `range`: that is a GDScript builtin and shadowing it here would
# break any loop written inside this class later.
func attack_range(stats: Stats) -> float:
	return float(def().range) * stats.range_multiplier()

func sell_value() -> int:
	return maxi(1, int(float(WeaponCatalog.price_at(id, tier)) * 0.6))

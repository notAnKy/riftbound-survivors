class_name ProfileManager
extends RefCounted

const SAVE_PATH := "user://riftbound_profile.json"
var data: Dictionary = {"coins":0, "unlocked_guns":[0], "unlocked_characters":[0]}

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary: data = sanitized(parsed)

# The profile on disk is untrusted: a truncated write, a hand-edit or an older
# build can leave keys missing or holding the wrong type, and the game reads
# them before the title screen ever draws. Rebuild a known-good dictionary
# instead of trusting what was parsed.
func sanitized(parsed: Dictionary) -> Dictionary:
	var clean := {"coins":0, "unlocked_guns":[0], "unlocked_characters":[0]}
	var coins_value = parsed.get("coins")
	if coins_value is float or coins_value is int: clean.coins = maxi(0, int(coins_value))
	clean.unlocked_guns = sanitized_unlocks(parsed.get("unlocked_guns"), GunCatalog.all().size())
	clean.unlocked_characters = sanitized_unlocks(parsed.get("unlocked_characters"), CharacterCatalog.all().size())
	return clean

func sanitized_unlocks(raw, count: int) -> Array:
	var indices := [0]
	if raw is Array:
		for value in raw:
			if not (value is float or value is int): continue
			var index := int(value)
			if index >= 0 and index < count and not indices.has(index): indices.append(index)
	return indices

func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(data))

func coins() -> int:
	return int(data.coins)

func add_coins(amount: int) -> void:
	data.coins = coins() + amount
	save_profile()

func is_gun_unlocked(index: int) -> bool:
	return index in data.unlocked_guns

func is_character_unlocked(index: int) -> bool:
	return index in data.unlocked_characters

func unlock_gun(index: int, cost: int) -> bool:
	if is_gun_unlocked(index): return true
	if coins() < cost: return false
	data.coins = coins() - cost
	data.unlocked_guns.append(index)
	save_profile()
	return true

func unlock_character(index: int, cost: int) -> bool:
	if is_character_unlocked(index): return true
	if coins() < cost: return false
	data.coins = coins() - cost
	data.unlocked_characters.append(index)
	save_profile()
	return true

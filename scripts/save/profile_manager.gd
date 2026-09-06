class_name ProfileManager
extends RefCounted

const SAVE_PATH := "user://riftbound_profile.json"

const DEFAULTS := {
	"coins": 0,
	"unlocked_guns": [0],
	"unlocked_characters": [0],
	"max_danger": 0,
	"rift_effects": true,
	"fullscreen": false,
	"sfx_volume": 0.7,
	"music_volume": 0.45,
}

var data: Dictionary = DEFAULTS.duplicate(true)
# The test suite drives real runs, and a run that ends awards coins and saves.
# Left on, that silently tops up the player real profile every time the suite
# runs. Harnesses turn this off.
var persist := true

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
	var clean := DEFAULTS.duplicate(true)
	var coins_value = parsed.get("coins")
	if coins_value is float or coins_value is int: clean.coins = maxi(0, int(coins_value))
	var danger_value = parsed.get("max_danger")
	if danger_value is float or danger_value is int:
		clean.max_danger = clampi(int(danger_value), 0, Balance.DANGER_LEVELS - 1)
	clean.unlocked_guns = sanitized_unlocks(parsed.get("unlocked_guns"), GunCatalog.all().size())
	clean.unlocked_characters = sanitized_unlocks(parsed.get("unlocked_characters"), CharacterCatalog.all().size())
	for flag in ["rift_effects", "fullscreen"]:
		if parsed.get(flag) is bool: clean[flag] = parsed[flag]
	for level in ["sfx_volume", "music_volume"]:
		var value = parsed.get(level)
		if value is float or value is int: clean[level] = clampf(float(value), 0.0, 1.0)
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
	if not persist: return
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

# --- danger levels -----------------------------------------------------------

func max_danger() -> int:
	return int(data.max_danger)

# Winning at a danger level opens the next one, and only ever moves upward.
func record_victory(danger: int) -> bool:
	var next := clampi(danger + 1, 0, Balance.DANGER_LEVELS - 1)
	if next <= max_danger(): return false
	data.max_danger = next
	save_profile()
	return true

# --- settings ----------------------------------------------------------------

func setting(name: String) -> bool:
	return bool(data.get(name, DEFAULTS[name]))

func set_setting(name: String, value: bool) -> void:
	data[name] = value
	save_profile()

func level(name: String) -> float:
	return clampf(float(data.get(name, DEFAULTS[name])), 0.0, 1.0)

# `save` is off while a volume bar is being swept: save_profile rewrites the
# whole file, and a drag would do that sixty times a second. The caller flushes
# once the sweep stops.
func set_level(name: String, value: float, save: bool = true) -> void:
	data[name] = clampf(value, 0.0, 1.0)
	if save: save_profile()

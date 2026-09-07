class_name AchievementCatalog
extends RefCounted

# What a run has to do to earn something.
#
# Characters used to be bought with coins, which asks nothing of the player
# except time: grind enough runs and the whole roster falls out. An achievement
# asks for a thing you have not done yet, which is the point of a roster where
# every character forces a different build.
#
# `needs` is read against the snapshot GameSession hands over at the end of a
# run -- see `run_summary()` there. `unlocks` is the character index it opens,
# or -1 for one that is only worth having done.

static var _cache: Array[Dictionary] = []

static func all() -> Array[Dictionary]:
	if _cache.is_empty(): _cache = _definitions()
	return _cache

static func _definitions() -> Array[Dictionary]:
	return [
		{"id":"first_blood", "name":"FIRST BLOOD", "unlocks":-1,
			"description":"Clear wave 1", "needs":{"wave": 2}},
		{"id":"rift_walker", "name":"RIFT WALKER", "unlocks":1,
			"description":"Reach wave 5", "needs":{"wave": 5}},
		{"id":"boss_slayer", "name":"BOSS SLAYER", "unlocks":-1,
			"description":"Put down a boss", "needs":{"bosses": 1}},
		{"id":"arsenal", "name":"FULL ARSENAL", "unlocks":3,
			"description":"Carry six weapons at once", "needs":{"weapons": 6}},
		{"id":"deep_run", "name":"DEEP RUN", "unlocks":2,
			"description":"Reach wave 10", "needs":{"wave": 10}},
		{"id":"butcher", "name":"BUTCHER", "unlocks":-1,
			"description":"Kill 600 in a single run", "needs":{"kills": 600}},
		{"id":"master_smith", "name":"MASTER SMITH", "unlocks":4,
			"description":"Merge a weapon up to tier IV", "needs":{"tier": 4}},
		{"id":"survivor", "name":"SURVIVOR", "unlocks":5,
			"description":"Clear all 20 waves", "needs":{"won": 1}},
		{"id":"hard_won", "name":"HARD WON", "unlocks":-1,
			"description":"Win at danger 3 or above", "needs":{"won": 1, "danger": 3}},
		{"id":"together", "name":"BETTER TOGETHER", "unlocks":-1,
			"description":"Reach wave 5 in co-op", "needs":{"wave": 5, "coop": 1}},
	]

static func get_achievement(id: String) -> Dictionary:
	for def in all():
		if def.id == id: return def
	return all()[0]

# Every achievement the summary satisfies. Each `needs` key is a floor the run
# has to meet or beat, so one run can earn several at once.
static func earned_by(summary: Dictionary) -> Array[String]:
	var earned: Array[String] = []
	for def in all():
		var met := true
		for key in def.needs:
			if float(summary.get(key, 0)) < float(def.needs[key]): met = false
		if met: earned.append(String(def.id))
	return earned

# Which achievement opens a character, so the armory can say what to go and do
# rather than quoting a price.
static func unlocker_for(character: int) -> Dictionary:
	for def in all():
		if int(def.unlocks) == character: return def
	return {}

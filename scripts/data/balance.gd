class_name Balance
extends RefCounted

# Every tuning number the difficulty curve depends on, in one place so a
# balance pass is an edit here rather than a hunt through the spawner.

# Enemy health at round N is (BASE + PER_ROUND * N) * type multiplier * curve.
const ENEMY_HP_BASE := 26.0
const ENEMY_HP_PER_ROUND := 8.0

# The curve compounds, so small changes here matter far more by round 10 than
# anything else in this file. 1.30 made round 10 enemies roughly 1700hp.
const ROUND_INTENSITY := 1.22

const ENEMY_SPEED_MIN := 54.0
const ENEMY_SPEED_MAX := 82.0
const ENEMY_SPEED_PER_ROUND := 4.0
const ENEMY_DAMAGE_PER_ROUND := 0.8

const BOSS_HP_BASE := 380.0
const BOSS_HP_PER_ROUND := 0.22
const BOSS_SPEED_BASE := 45.0
const BOSS_SPEED_PER_ROUND := 2.0

# Levelling. XP needed for the next level is previous * GROWTH + FLAT.
const XP_FIRST_LEVEL := 14
const XP_GROWTH := 1.28
const XP_FLAT := 4

# Seconds between spawn batches, before the curve divides it down.
const SPAWN_INTERVAL := 1.05
const SPAWN_INTERVAL_MIN := 0.16

static func intensity(round_number: int) -> float:
	return pow(ROUND_INTENSITY, round_number - 1)

static func enemy_hp(round_number: int, type_multiplier: float) -> float:
	var base := ENEMY_HP_BASE + ENEMY_HP_PER_ROUND * float(round_number)
	return base * type_multiplier * intensity(round_number)

static func boss_hp(round_number: int) -> float:
	return BOSS_HP_BASE * (1.0 + float(round_number - 1) * BOSS_HP_PER_ROUND)

static func next_level_xp(current: int) -> int:
	return int(ceil(float(current) * XP_GROWTH)) + XP_FLAT

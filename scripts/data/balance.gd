class_name Balance
extends RefCounted

# Every tuning number the difficulty curve depends on, in one place so a
# balance pass is an edit here rather than a hunt through the spawner.

# Enemy health at round N is (BASE + PER_ROUND * N) * type multiplier * curve.
const ENEMY_HP_BASE := 18.0
const ENEMY_HP_PER_ROUND := 5.5

# The curve compounds, so small changes here matter far more by round 10 than
# anything else in this file. 1.30 made round 10 enemies roughly 1700hp.
const ROUND_INTENSITY := 1.185

const ENEMY_SPEED_MIN := 54.0
const ENEMY_SPEED_MAX := 82.0
const ENEMY_SPEED_PER_ROUND := 4.0
const ENEMY_DAMAGE_PER_ROUND := 1.5

const BOSS_HP_BASE := 300.0
const BOSS_HP_PER_ROUND := 0.18
const BOSS_SPEED_BASE := 45.0
const BOSS_SPEED_PER_ROUND := 2.0

# Levelling. XP needed for the next level is previous * GROWTH + FLAT.
const XP_FIRST_LEVEL := 10
const XP_GROWTH := 1.22
const XP_FLAT := 3

# Seconds between spawn batches, before the curve divides it down.
const SPAWN_INTERVAL := 1.05
const SPAWN_INTERVAL_MIN := 0.16

# Healing. A drop on some kills, plus a steady trickle every so many kills so
# a long clean wave repays the player even when no bandage rolls.
# Healing used to scale with the kill count, and the kill count explodes: by
# round 7 the passive drip out-paced a whole crowd hitting you, so standing
# still was the strongest play. All three sources are now scarce, and lifesteal
# is capped per hit so a piercing crit cannot refill the bar.
const HEALTH_DROP_CHANCE := 0.02
const HEALTH_DROP_AMOUNT := 8
const HEAL_EVERY_KILLS := 50
const HEAL_ON_KILLS := 4.0
const LIFESTEAL_MAX_PER_HIT := 0.02

# Shop prices climb per wave. Material income grows far faster than this, so a
# shallow curve stops the shop mattering by the midgame.
const SHOP_INFLATION_PER_WAVE := 0.18

# Rift Nova: a real area attack rather than a quiet damage tick.
const NOVA_RADIUS := 300.0
const NOVA_DAMAGE := 46.0
const NOVA_KNOCKBACK := 620.0
const NOVA_COOLDOWN := 8.0

# A run is a fixed twenty waves. Clearing the last one wins it, which is what
# gives the shop decisions somewhere to build toward.
const FINAL_WAVE := 20

# Danger levels are the replay ladder: beating one opens the next. Enemies get
# tougher, and materials rise to part-compensate so the shop keeps pace.
const DANGER_LEVELS := 6
const DANGER_HP := 0.24
const DANGER_SPEED := 0.05
const DANGER_SPAWN := 0.09
const DANGER_MATERIALS := 0.16

static func danger_hp(danger: int) -> float:
	return 1.0 + float(danger) * DANGER_HP

static func danger_speed(danger: int) -> float:
	return 1.0 + float(danger) * DANGER_SPEED

static func danger_spawn(danger: int) -> float:
	return 1.0 / (1.0 + float(danger) * DANGER_SPAWN)

static func danger_materials(danger: int) -> float:
	return 1.0 + float(danger) * DANGER_MATERIALS

# Elites: a rare, much tougher version of any enemy, worth far more materials.
const ELITE_FIRST_ROUND := 3
const ELITE_CHANCE_BASE := 0.02
const ELITE_CHANCE_PER_ROUND := 0.012
const ELITE_CHANCE_MAX := 0.16
const ELITE_HP := 3.2
const ELITE_SCALE := 1.35
const ELITE_SPEED := 0.9
const ELITE_MATERIALS := 4

# Screen shake, in pixels of offset, and how fast it bleeds off.
const SHAKE_MAX := 24.0
const SHAKE_DECAY := 48.0
const SHAKE_PLAYER_HIT := 5.0
const SHAKE_KILL := 1.1
const SHAKE_NOVA := 15.0
const SHAKE_BOSS_DEATH := 22.0

# Hit stop, in seconds of real time.
const HITSTOP_SCALE := 0.06
const HITSTOP_NOVA := 0.05
const HITSTOP_BOSS_DEATH := 0.12

static func elite_chance(round_number: int) -> float:
	if round_number < ELITE_FIRST_ROUND: return 0.0
	return minf(ELITE_CHANCE_BASE + float(round_number) * ELITE_CHANCE_PER_ROUND, ELITE_CHANCE_MAX)

static func intensity(round_number: int) -> float:
	return pow(ROUND_INTENSITY, round_number - 1)

static func enemy_hp(round_number: int, type_multiplier: float) -> float:
	var base := ENEMY_HP_BASE + ENEMY_HP_PER_ROUND * float(round_number)
	return base * type_multiplier * intensity(round_number)

static func boss_hp(round_number: int) -> float:
	return BOSS_HP_BASE * (1.0 + float(round_number - 1) * BOSS_HP_PER_ROUND)

static func next_level_xp(current: int) -> int:
	return int(ceil(float(current) * XP_GROWTH)) + XP_FLAT

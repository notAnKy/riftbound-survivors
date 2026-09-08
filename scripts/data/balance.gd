class_name Balance
extends RefCounted

# Every tuning number the difficulty curve depends on, in one place so a
# balance pass is an edit here rather than a hunt through the spawner.

# Enemy health at round N is (BASE + PER_ROUND * N) * type multiplier * curve.
const ENEMY_HP_BASE := 15.0
const ENEMY_HP_PER_ROUND := 4.2

# The curve compounds, so small changes here matter far more by round 10 than
# anything else in this file. 1.30 made round 10 enemies roughly 1700hp.
const ROUND_INTENSITY := 1.16
# And then it compounds more gently. Waves 1-10 were tuned by playing them and
# are left exactly as they were; past that, 1.16 all the way to wave 20 is a
# 16.8x multiplier on enemy health, which no build keeps pace with once the shop
# is a real constraint. The second rate takes wave 20 to 9.0x instead.
const ROUND_INTENSITY_LATE := 1.09
const INTENSITY_SOFTENS_AT := 10

const ENEMY_SPEED_MIN := 54.0
const ENEMY_SPEED_MAX := 82.0
const ENEMY_SPEED_PER_ROUND := 4.0
const ENEMY_DAMAGE_PER_ROUND := 1.5

# A boss is priced as a very fat enemy rather than on its own curve. It used to
# be BOSS_HP_BASE * (1 + 0.18 * round), which is *linear* while every regular
# enemy compounds -- so a wave-20 brute ended up with 2.4x the final boss's
# health, and the wave-5 boss died in about two seconds of focused fire. Running
# it through enemy_hp means it can never fall behind the crowd again.
const BOSS_HP_TYPE := 40.0
# And it hits harder than the thing it is standing in a crowd of.
const BOSS_DAMAGE := 1.35
const BOSS_SPEED_BASE := 45.0
const BOSS_SPEED_PER_ROUND := 2.0

# Levelling. XP needed for the next level is previous * GROWTH + FLAT.
const XP_FIRST_LEVEL := 10
const XP_GROWTH := 1.22
const XP_FLAT := 3

# Seconds between spawn batches, before the curve divides it down.
const SPAWN_INTERVAL := 1.05
# The floor binds from about wave 12 on, so it alone sets the late-game spawn
# rate: at 0.16 with a batch of five that was 31 enemies a second and close to
# two thousand in one wave, which is where the crowd ran away from any build
# that was not merging weapons.
const SPAWN_INTERVAL_MIN := 0.22
# Rounds at which the spawner starts adding another enemy per batch. It
# used to double up at round 4, which is exactly where the difficulty
# complaint landed.
const SPAWN_BATCH_EVERY := 5
# And a ceiling on that, for the same reason as the interval floor.
const SPAWN_BATCH_MAX := 4
# --- where the crowd comes from ----------------------------------------------
#
# Enemies used to pick a uniformly random edge on *every single spawn*, which
# averages out to "surrounded, always" and gives the player nothing to read.
# Instead a few gates are open at a time and they move: pressure with a
# direction is pressure you can run from, and running from it is the play.
# --- crowd control -----------------------------------------------------------
#
# Capping defence left the player with only one answer to a crowd: walk away
# from it. These are the other two -- push it back, or slow it down -- and they
# are what the defensive nerfs are balanced against.
const KNOCKBACK_PER_POINT := 11.0
const SLOW_PER_POINT := 1.1
# Capped, and deliberately short of a freeze. An enemy that cannot reach you is
# the same immortality problem wearing a different hat.
const SLOW_MAX := 55.0
const SLOW_TIME := 0.9

const SPAWN_GATE_SECONDS := 7.0
# How far either side of a gate an enemy can arrive, in radians.
const SPAWN_GATE_SPREAD := 0.34

# The spawner's shape, in one place: the report models a wave from these too,
# and a second copy of the formula would drift from the real one.
static func spawn_batch(round_number: int) -> int:
	return mini(1 + int(round_number / SPAWN_BATCH_EVERY), SPAWN_BATCH_MAX)

static func spawn_interval(round_number: int, danger: int) -> float:
	return maxf(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL / intensity(round_number) * danger_spawn(danger))

# Healing, in two halves that must not be confused.
#
# In-wave healing has to stay scarce. It used to scale with the kill count, and
# the kill count explodes with your damage: by round 7 the passive drip
# out-paced a whole crowd hitting you, so standing still was the strongest play.
# The bandage roll, the per-kill trickle and lifesteal are all deliberately thin,
# and lifesteal is capped per hit so a piercing crit cannot refill the bar.
const HEALTH_DROP_CHANCE := 0.03
const HEALTH_DROP_AMOUNT := 8
const HEAL_EVERY_KILLS := 40
const HEAL_ON_KILLS := 3.0
# --- survivability -----------------------------------------------------------
#
# Play-tested to round 14 standing still and never dying. Three unbounded stacks
# were multiplying: hp_regen reached ~20/s, armor ~70% reduction and dodge its
# 60% cap, so incoming damage arrived at 12% of face value against a pool that
# refilled faster than it drained.
#
# The root cause was `of:"items"`. A synergy scaling per item owned is fine when
# a run holds six; runs hold 29-43 after the economy rebalance, so FIELD MEDIC
# alone was worth 13.5 HP/s. The count these read is capped now -- naturally
# capped counts (weapons, empty slots, melee) top out at 6 on their own and are
# left alone.
const SYNERGY_ITEM_CAP := 12
# A hard ceiling on regen, so no combination of sources can outrun a crowd.
const REGEN_CAP := 6.0
# Armor is amount * (1 - armor / (armor + ARMOR_SOFTNESS)), then floored at
# ARMOR_MIN_TAKEN. Softness was 30, which is why 70 armor read as 70% off.
const ARMOR_SOFTNESS := 55.0
const ARMOR_MIN_TAKEN := 0.45
# Dodge was capped at 60%, which stacks multiplicatively with armor and regen
# and was doing more than either.
const DODGE_CAP := 30.0
const LIFESTEAL_MAX_PER_HIT := 0.008

# Between-wave healing is the opposite case, and is where the health economy
# actually lives. Chip damage carries across waves, so without this a run is a
# one-way ratchet: by wave 6 the player is fighting a harder wave on whatever
# was left over from the last five, which is exactly the wall play-testing hit.
# Once per wave, capped at max HP, it cannot be farmed the way a per-kill heal
# can -- standing still through a wave earns nothing extra.
const WAVE_CLEAR_HEAL := 0.15
# A wave survived at a sliver pays a little more, so a bad wave is recoverable
# without making a good one heal for nothing. Fraction of the missing bar.
const WAVE_CLEAR_HEAL_MISSING := 0.08

# Co-op. A downed survivor is revived at the start of the next round, at this
# fraction of max HP -- going down has to cost something, or throwing yourself at
# the crowd and waiting for the round to tick over is the safest play.
const REVIVE_HP := 0.5
# Enemy health per extra survivor. Two players put out far more than twice one
# player's damage, because most of the sheet is per-weapon and they carry two
# racks, so the crowd has to be tougher than a straight doubling of numbers.
# How long a bloater's blast hangs as a warning ring before it lands. The
# explosion used to fire on the same frame the enemy died -- and the player's own
# gun is what kills it, so 26 damage arrived from a corpse nobody was looking at
# with no visible cause at all. A fuse turns it into something to step out of
# without making it free: standing on one still costs you.
# How much bigger than its source pixels an actor is drawn. The Tiny Dungeon
# sprites are 16px and were being rendered at 1:1 -- *smaller* than the 26px
# collision diameter they carry, so the art understated its own hitbox, and the
# scattered props are the same 16px and were exactly as visually loud as the
# things that kill you. This is one number so the actors and the decoration can
# never drift back into the same size again.
# The file width every other sprite is measured against. The art is not all one
# resolution -- the Kenney tiles are 48px files and the generated characters are
# 32px -- so an actor's scale is derived from its own texture rather than being
# a magic number per sprite, and new art of any size lands the right size.
const SPRITE_BASE := 48.0
const ACTOR_SCALE := 1.7
const BLOAT_FUSE := 0.45
const COOP_ENEMY_HP := 0.45
const COOP_SPAWN := 0.35

# Shop prices climb per wave, and they compound.
#
# This used to be linear -- 1 + round * rate -- which reached only 4.6x by wave
# 20 while material income, which tracks the enemy count, grows about fiftyfold
# across a run. The balance report showed every simulated run ending with over a
# hundred items bought and twenty thousand materials still unspent: the shop had
# no scarcity left at all, and a stat sheet with a hundred items on it makes
# every other number meaningless. Compounding at the same rate reaches ~38x.
const SHOP_INFLATION_PER_WAVE := 0.20
# Each item already held makes the next one dearer. Wave inflation alone kept
# prices level with income, so the count purchased per wave never fell and a run
# still finished holding ninety of them. This is what makes an item a decision
# rather than something you pick up because you happen to have the materials.
const ITEM_PRICE_PER_OWNED := 0.055

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
# Enemy health and spawn rate both multiply pressure, and materials were the
# only thing paying for it: at 0.24 and 0.09 against 0.16, danger 5 was 3.2x the
# pressure for 1.8x the income, and the report walled it at wave 5. These are
# set so the extra income roughly covers the extra pressure and the ladder is
# harder to play rather than arithmetically out of reach.
const DANGER_LEVELS := 6
const DANGER_HP := 0.18
const DANGER_SPEED := 0.05
const DANGER_SPAWN := 0.06
const DANGER_MATERIALS := 0.26

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
	if round_number <= INTENSITY_SOFTENS_AT:
		return pow(ROUND_INTENSITY, round_number - 1)
	return pow(ROUND_INTENSITY, INTENSITY_SOFTENS_AT - 1) * pow(ROUND_INTENSITY_LATE, round_number - INTENSITY_SOFTENS_AT)

static func enemy_hp(round_number: int, type_multiplier: float) -> float:
	var base := ENEMY_HP_BASE + ENEMY_HP_PER_ROUND * float(round_number)
	return base * type_multiplier * intensity(round_number)

# What one enemy of `base` contact damage hits for at this round. Was inline in
# enemy.gd; it is here so the balance model and the suite read the same figure
# the game does rather than a second copy that can drift.
static func enemy_damage(round_number: int, base: float) -> float:
	return base + float(round_number) * ENEMY_DAMAGE_PER_ROUND

static func boss_hp(round_number: int) -> float:
	return enemy_hp(round_number, BOSS_HP_TYPE)

static func next_level_xp(current: int) -> int:
	return int(ceil(float(current) * XP_GROWTH)) + XP_FLAT

extends SceneTree

# What the back half of a run actually looks like, in numbers.
#
# Run: godot --headless --path . --script res://tests/balance_report.gd -- [danger]
#      (no argument sweeps every danger level)
#
# Twelve of the twenty waves have never been played by anybody, and playing
# 20 waves x 6 dangers by hand is not going to happen. This walks a run using
# the real Balance formulas, the real Shop and the real Weapon and Stats maths,
# and reports the two things that actually break in a game shaped like this:
#
#   1. the damage race  -- can the build kill what the wave sends?
#   2. the economy      -- can the purse keep up with the shop's prices?
#
# WHAT IT DOES NOT MODEL: positioning. It assumes every material is collected
# and says nothing about whether a human can physically kite that crowd. A wave
# ends on a timer, not on a body count, so pressure above 1.0 is not instant
# death -- it means the leftover crowd and the cleanup after the timer both grow.
#
# The first version of this compared "time to kill everything a wave sends"
# against the wave length and declared the game unwinnable from wave 5, which
# contradicted actual play. Two things were wrong: that is not the failure
# condition, and single-target DPS badly understates what a rack does to a pack.

const SEED := 20260907
# One run per danger was tuning against shop RNG: two dangers apart differed by
# more than the ladder does. Several seeds, and the median is reported.
const SAMPLES := 5
# Measured, not guessed: 80 enemies packed round a stationary player, six
# seconds of real firing, total damage dealt over the single-target figure.
#   one pistol   1.1x      six mixed weapons  3.9x      six melee blades  7.9x
# The mixed number is used here as the honest middle of a real build.
const CROWD_FACTOR := 3.9
# What the simulated player does with their materials each wave: spend down,
# most expensive affordable offer first, weapons while the rack has room.
const REROLL_BUDGET := 2

func _initialize() -> void:
	report.call_deferred()

func fresh(danger: int, seed_value: int) -> Node:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.profile.persist = false
	game.danger = danger
	game.state = "playing"
	game.start_run()
	await process_frame
	game.session.rng.seed = seed_value
	return game

# --- what a wave sends --------------------------------------------------------

# Straight out of the spawner: batch size, interval and wave length all come
# from Balance, so this tracks any tuning change automatically.
func wave_enemies(round_number: int, danger: int, duration: float) -> int:
	return int(duration / Balance.spawn_interval(round_number, danger)) * Balance.spawn_batch(round_number)

func average_enemy_hp(round_number: int, danger: int) -> float:
	var options := EnemyCatalog.available(round_number)
	var total := 0.0
	for def in options:
		total += Balance.enemy_hp(round_number, float(def.hp))
	return total / maxf(1.0, float(options.size())) * Balance.danger_hp(danger)

func average_material(round_number: int) -> float:
	var options := EnemyCatalog.available(round_number)
	var total := 0.0
	for def in options:
		total += float(def.material)
	return total / maxf(1.0, float(options.size()))

# --- what the build puts out --------------------------------------------------

# Single-target sustained damage, crits included. Melee sweeps a whole arc and
# an orbital grinds whatever it passes, so both are understated here.
func build_dps(who) -> float:
	var stats = who.stats
	var crit: float = 1.0 + stats.get_stat("crit_chance") / 100.0 * (stats.get_stat("crit_damage") / 100.0)
	var total := 0.0
	for weapon in who.weapons:
		var def: Dictionary = weapon.def()
		var shots: float = maxf(1.0, float(def.shots))
		total += weapon.damage(stats) * shots * crit / maxf(0.05, weapon.cooldown(stats))
	return total

# --- what the player does between waves --------------------------------------

# The weakest thing in the rack, which is what gets sold to make room.
func weakest(who) -> int:
	var at := 0
	for i in range(who.weapons.size()):
		if who.weapons[i].tier < who.weapons[at].tier: at = i
	return at

func combine_any(s) -> bool:
	for i in range(s.seat(0).weapons.size()):
		if s.can_combine(i, 0): return s.combine_weapon(i, 0)
	return false

# A reasonable player, not a naive one. The first version of this only ever
# bought, so the rack filled at wave 3 and then sat at tier 1 for seventeen
# waves -- which understated late damage enormously. Merging duplicates and
# trading up over the weakest slot is most of where late power comes from.
func spend(game, wave: int, skilled: bool) -> void:
	var s = game.session
	var who = s.seat(0)
	var rerolled := 0
	var moves := 0
	while moves < 40:
		moves += 1
		# Free power first: a pair becomes one a tier up and frees a slot.
		if skilled and combine_any(s): continue
		var best := -1
		var best_score := -1
		for i in range(s.shop.offers.size()):
			var offer: Dictionary = s.shop.offers[i]
			if offer.is_empty() or int(offer.price) > who.materials: continue
			var score := int(offer.price)
			if offer.kind == "weapon":
				if who.weapons.size() < who.weapon_slots: score += 20000
				elif skilled and who.weapons.size() > 1 and int(offer.tier) > who.weapons[weakest(who)].tier: score += 10000
				else: continue
			if score > best_score:
				best_score = score
				best = i
		if best >= 0:
			var offer: Dictionary = s.shop.offers[best]
			if offer.kind == "weapon" and who.weapons.size() >= who.weapon_slots:
				s.sell_weapon(weakest(who), 0)
			if s.buy(best, 0): continue
			break
		# Nothing worth having: reroll a couple of times.
		if rerolled >= REROLL_BUDGET or not s.reroll_shop(0): break
		rerolled += 1

func take_levels(game) -> void:
	var s = game.session
	var who = s.seat(0)
	var guard := 0
	while not who.upgrades.is_empty() and guard < 200:
		guard += 1
		# A reasonable player takes the best thing on offer.
		var best := 0
		var rank := {"COMMON": 0, "RARE": 1, "LEGENDARY": 2}
		for i in range(who.upgrades.size()):
			if int(rank.get(who.upgrades[i].rarity, 0)) > int(rank.get(who.upgrades[best].rarity, 0)): best = i
		s.choose_upgrade(best, 0)

# --- the walk -----------------------------------------------------------------

func run_danger(danger: int, skilled: bool, seed_value: int, quiet: bool) -> Dictionary:
	var game = await fresh(danger, seed_value)
	var s = game.session
	var who = s.seat(0)
	if not quiet:
		print("")
		print("DANGER %d  --  %s" % [danger, "player who merges and trades up" if skilled else "player who only buys"])
		print("wave  enemyHP  spawned  spawn/s  kill/s  pressure  leftover  cleanup   purse  cheapest  lvl")
	var first_behind := 0
	var first_broke := 0
	var worst_cleanup := 0.0
	for wave in range(1, Balance.FINAL_WAVE + 1):
		s.round_number = wave
		var duration: float = s.round_duration + minf(20.0, float(wave - 1) * 2.0)
		var count := wave_enemies(wave, danger, duration)
		var each := average_enemy_hp(wave, danger)
		var wave_hp := float(count) * each
		if wave % 5 == 0: wave_hp += Balance.boss_hp(wave)
		var dps := build_dps(who) * CROWD_FACTOR
		# The race that actually decides a wave: does the crowd grow or shrink?
		var spawn_rate := float(count) / duration
		var kill_rate := dps / maxf(1.0, each)
		var pressure := spawn_rate / maxf(0.001, kill_rate)
		# What is still standing when the timer runs out, and how long the
		# cleanup phase then takes -- a wave is not over until that is dead.
		var leftover := maxf(0.0, float(count) - kill_rate * duration)
		var cleanup := leftover * each / maxf(1.0, dps)
		worst_cleanup = maxf(worst_cleanup, cleanup)
		if first_behind == 0 and pressure > 1.0: first_behind = wave

		# Income, then the real shop, then the level-ups it paid for.
		var income := int(float(count) * average_material(wave) * Balance.danger_materials(danger))
		for i in range(count):
			s.on_pickup_collected(int(maxf(1.0, average_material(wave))), Pickup.KIND_MATERIAL, who)
		take_levels(game)
		var purse: int = who.materials
		s.finish_wave()
		var cheapest := 99999
		for offer in s.shop.offers:
			if not offer.is_empty(): cheapest = mini(cheapest, int(offer.price))
		if first_broke == 0 and cheapest > purse: first_broke = wave
		spend(game, wave, skilled)
		take_levels(game)

		if not quiet:
			print("%4d  %7.0f  %7d  %7.1f  %6.1f  %8.2f  %8.0f  %6.0fs %7d  %8d  %3d" % [
				wave, each, count, spawn_rate, kill_rate, pressure, leftover, cleanup,
				purse, cheapest, who.level])
		s.begin_round()
	var summary := {
		"danger": danger,
		"skilled": skilled,
		"behind": first_behind,
		"broke": first_broke,
		"cleanup": worst_cleanup,
		"dps": build_dps(who) * CROWD_FACTOR,
		"level": who.level,
		"weapons": who.weapons.size(),
		"items": who.items.size(),
		"max_hp": who.player.max_hp,
		"purse": who.materials,
	}
	game.free()
	return summary

# The middle run of the samples, by how bad its worst cleanup got.
func median_of(samples: Array[Dictionary]) -> Dictionary:
	samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.cleanup) < float(b.cleanup))
	return samples[samples.size() / 2]

func report() -> void:
	print("Balance model -- the damage race and the economy, using the real formulas.")
	print("Median of %d shop seeds per row." % SAMPLES)
	print("Positioning is not modelled: it assumes everything is reachable and collected.")
	var only := -1
	for argument in OS.get_cmdline_user_args():
		if String(argument).is_valid_int(): only = int(argument)
	var rows: Array[Dictionary] = []
	for danger in range(Balance.DANGER_LEVELS):
		if only >= 0 and danger != only: continue
		for skilled in [false, true]:
			var samples: Array[Dictionary] = []
			for i in range(SAMPLES):
				# Only the first sample prints its table; the rest are for the median.
				samples.append(await run_danger(danger, skilled, SEED + i * 977, i > 0 or only < 0))
			rows.append(median_of(samples))
	print("")
	print("SUMMARY")
	print("danger  policy   crowd-outruns-you  worst-cleanup  leftover-purse  items  finalDPS  maxHP")
	for row in rows:
		print("%6d  %-7s  %17s  %12.0fs  %14d  %5d  %8.0f  %5.0f" % [
			row.danger, "merges" if row.skilled else "buys",
			"never" if row.behind == 0 else "wave %d" % row.behind,
			row.cleanup, row.purse, row.items, row.dps, row.max_hp])
	print("")
	print("The two policies differ only in whether the player merges duplicates and")
	print("trades up over the weakest slot. That gap is the real difficulty range.")
	print("pressure > 1.00 means the crowd grows faster than it dies. A wave still")
	print("ends on its timer, so that shows up as leftover enemies and a long cleanup")
	print("rather than as a loss -- but it is what a wall feels like to play.")
	quit(0)

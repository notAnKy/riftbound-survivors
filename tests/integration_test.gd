extends SceneTree

# Headless integration pass over the node/physics rebuild.
# Run: godot --headless --script res://tests/integration_test.gd

var failures := 0
const EXPECTED_CHECKS := 394
var checks := 0

func _initialize() -> void:
	bootstrap.call_deferred()

func check(label: String, ok: bool) -> void:
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok: failures += 1

# Waits a physics frame AND an idle frame. Godot can run several physics steps
# inside one idle frame, so awaiting only physics_frame let a test advance
# without _process ever running -- and the wave clock and screen shake both
# live in _process. That silently broke two tests when startup got slower.
func step(frames: int) -> void:
	for i in range(frames):
		await physics_frame
		await process_frame

func fresh_game() -> Node:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.profile.persist = false
	# Characters are unlocked by achievement now. These tests are about
	# mechanics, not progression, so the harness owns the whole roster; the
	# gate has its own test.
	game.profile.data.unlocked_characters = [0, 1, 2, 3, 4, 5]
	game.state = "playing"
	game.start_run()
	await step(2)
	return game

func bootstrap() -> void:
	await test_boot()
	await test_spawn_inside_walls()
	await test_enemies_separate()
	await test_walls_contain_player()
	await test_shot_kills_and_drops()
	await test_pickup_is_collected()
	await test_death_ends_run_once()
	await test_boss_rounds()
	await test_pause_freezes_the_field()
	await test_wave_clear_opens_shop()
	await test_shop_buying()
	await test_weapon_combining()
	await test_combine_in_the_shop()
	await test_pinning_an_offer()
	await test_spawns_land_where_they_happened()
	await test_coop_lobby()
	await test_lobby_seats_follow_join_order()
	await test_coop_two_players()
	await test_coop_movement()
	await test_coop_down_and_revive()
	await test_coop_separate_economies()
	await test_coop_split_screen()
	await test_weapon_rack_limit()
	await test_multi_weapon_output()
	await test_materials_are_currency_and_xp()
	await test_healing()
	await test_nova()
	test_stat_math()
	test_display_settings()
	await test_menu_navigation()
	await test_damage_numbers()
	await test_elites()
	await test_shake_and_hitstop()
	await test_victory_ends_the_run()
	await test_danger_levels()
	test_profile_persistence()
	await test_achievements()
	test_every_icon_exists()
	await test_audio_banks()
	await test_music()
	await test_healing_is_scarce()
	await test_between_wave_healing()
	await test_level_up_selection()
	await test_pointer_does_not_fight_the_arrows()
	await test_everything_drawn_is_clickable()
	await test_spawn_gates_have_a_direction()
	await test_crowd_control()
	await test_controller()
	await test_quit_confirmation()
	await test_slider_sweeping()
	test_shop_prices_climb()
	await test_melee_archetype()
	await test_orbital_archetype()
	await test_homing_archetype()
	await test_character_constraints()
	await test_item_synergies()
	await test_enemy_roster()
	await test_weapon_classes()
	test_balance_curve()
	test_catalogs_are_built_once()
	test_profile_sanitizing()
	# A GDScript runtime error aborts only the function it happened in, so a
	# broken test just stops asserting and the suite still reads as green.
	# Pin the count so that shows up as a failure.
	var ran := checks
	check("every assertion ran (%d of %d)" % [ran, EXPECTED_CHECKS], ran == EXPECTED_CHECKS)
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)

func test_boot() -> void:
	var game = await fresh_game()
	var s = game.session
	check("run starts with a live player node", is_instance_valid(s.player) and s.player.alive)
	check("player reports full hp through the session (%.0f/%.0f)" % [s.player_hp, s.player_max_hp], s.player_hp == s.player_max_hp and s.player_hp > 0.0)
	check("arena built its wall body", s.get_node_or_null("Arena/Walls") != null)
	game.free()

# With real walls, anything spawned outside the arena would be sealed out.
func test_spawn_inside_walls() -> void:
	var game = await fresh_game()
	var s = game.session
	await step(120)
	var bounds: Rect2 = Arena.BOUNDS
	var outside := 0
	var near_player := 0
	for enemy in s.actors.get_children():
		if not bounds.has_point(enemy.position): outside += 1
		if enemy.position.distance_to(s.player.position) < 100.0: near_player += 1
	check("enemies spawned (%d alive)" % s.actors.get_child_count(), s.actors.get_child_count() > 0)
	check("no enemy is stranded outside the walls (%d outside)" % outside, outside == 0)
	game.free()

# Enemies collide with each other now, so a pile has to push itself apart.
func test_enemies_separate() -> void:
	var game = await fresh_game()
	var s = game.session
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	var spot := Arena.BOUNDS.get_center() + Vector2(0, -220)
	var defs = EnemyCatalog.all()
	for i in range(8):
		s.spawn_enemy(defs[0], spot, false)
	await step(45)
	var spread := 0.0
	var live: Array = s.actors.get_children()
	for a in live:
		for b in live:
			spread = maxf(spread, a.position.distance_to(b.position))
	check("a stacked crowd pushes itself apart (%.0fpx spread across %d)" % [spread, live.size()], spread > 40.0)
	game.free()

func test_walls_contain_player() -> void:
	var game = await fresh_game()
	var s = game.session
	Input.action_press("move_right")
	Input.action_press("move_down")
	await step(180)
	Input.action_release("move_right")
	Input.action_release("move_down")
	var p: Vector2 = s.player.position
	var limit_x: float = Arena.BOUNDS.end.x
	var limit_y: float = Arena.BOUNDS.end.y
	check("input actually moved the player (x=%.0f)" % p.x, p.x > Arena.BOUNDS.get_center().x + 50.0)
	check("walls stop the player leaving the arena (%.0f,%.0f)" % [p.x, p.y], p.x < limit_x and p.y < limit_y)
	game.free()

func test_shot_kills_and_drops() -> void:
	var game = await fresh_game()
	var s = game.session
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	for pickup in s.pickups.get_children():
		s.pickups.remove_child(pickup)
		pickup.queue_free()
	var target = s.spawn_enemy(EnemyCatalog.all()[0], s.player.position + Vector2(150, 0), false)
	# A wave-1 husk has 19hp and stands in front of the player's own auto-fire
	# for the twenty frames below, so it could die before the assertion reads it
	# and leave the next line on a freed node. This test kills it deliberately.
	target.max_hp = 1000000.0
	target.hp = target.max_hp
	await step(1)
	var before: float = target.hp
	s.add_shot(s.me, Vector2.RIGHT, 900.0, 1.0, 5.0, Color.WHITE, 0)
	await step(20)
	check("a projectile damages what it hits (%.0f -> %.0f)" % [before, target.hp], is_instance_valid(target) and target.hp < before)
	target.take_damage(target.max_hp * 2.0)
	await step(2)
	check("a killed enemy leaves the field", not is_instance_valid(target))
	var materials_dropped := 0
	for drop in s.pickups.get_children():
		if drop.kind == Pickup.KIND_MATERIAL: materials_dropped += 1
	check("a kill drops exactly one material pickup (%d of %d drops)" % [materials_dropped, s.pickups.get_child_count()], materials_dropped == 1)
	check("the kill counted (%d)" % s.kills, s.kills == 1)
	game.free()

func test_pickup_is_collected() -> void:
	var game = await fresh_game()
	var s = game.session
	var xp_before: int = s.xp
	var pickup = load("res://scenes/actors/Pickup.tscn").instantiate()
	s.pickups.add_child(pickup)
	pickup.setup(s.player.position + Vector2(20, 0), 3)
	pickup.collected.connect(s.on_pickup_collected)
	await step(30)
	check("the magnet pulls a pickup in and banks it (xp %d -> %d)" % [xp_before, s.xp], s.xp >= xp_before + 3)
	game.free()

# The bug fixed before the rewrite, re-proved against the new damage path.
func test_death_ends_run_once() -> void:
	var game = await fresh_game()
	var s = game.session
	var emitted := [0]
	s.run_ended.connect(func() -> void: emitted[0] += 1)
	s.player.hp = 1.0
	for i in range(6):
		s.player.hurt(50.0)
	await step(2)
	check("run_ended fires exactly once however many blows land (%d)" % emitted[0], emitted[0] == 1)
	check("the player is flagged dead", not s.player.alive)
	game.free()

func test_boss_rounds() -> void:
	var game = await fresh_game()
	var s = game.session
	var boss_rounds := []
	for r in range(2, 13):
		var before: int = s.actors.get_child_count()
		s.begin_round()
		if s.actors.get_child_count() > before: boss_rounds.append(s.round_number)
	check("a boss opens every fifth round (%s)" % [boss_rounds], boss_rounds == [5, 10])
	game.free()

func test_profile_sanitizing() -> void:
	var profile := ProfileManager.new()
	var clean := profile.sanitized({"coins": "lots", "unlocked_characters": [0, 9, -2, 1, 1, "x"]})
	check("junk coins fall back to 0 (%s)" % clean.coins, clean.coins == 0)
	check("missing unlocked_guns defaults to [0] (%s)" % [clean.unlocked_guns], clean.unlocked_guns == [0])
	check("bad unlock indices dropped (%s)" % [clean.unlocked_characters], clean.unlocked_characters == [0, 1])
	var kept := profile.sanitized({"coins": 120.0, "unlocked_guns": [0, 2], "unlocked_characters": [0]})
	check("a valid profile survives intact", kept.coins == 120 and kept.unlocked_guns == [0, 2])

# Regression: the controller was PROCESS_MODE_ALWAYS and every child inherits
# that by default, so the whole game tree ignored the pause. Enemies kept
# walking and killing during the pause and level-up menus.
func test_pause_freezes_the_field() -> void:
	var game = await fresh_game()
	var s = game.session
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	var mob = s.spawn_enemy(EnemyCatalog.all()[0], s.player.position + Vector2(200, 0), false)
	# The player auto-fires the moment the game resumes, and a round-1 husk
	# dies in two shots, so the final assertion could read a freed node.
	mob.max_hp = 1000000.0
	mob.hp = mob.max_hp
	await step(2)
	for menu in ["paused", "level_up"]:
		game.state = menu
		await step(4)
		var frozen_at: Vector2 = mob.position
		var hp_at: float = s.player_hp
		await step(60)
		check("%s freezes enemy movement (moved %.1fpx)" % [menu, mob.position.distance_to(frozen_at)], mob.position.distance_to(frozen_at) < 0.5)
		check("%s stops the player taking damage (%.0f -> %.0f)" % [menu, hp_at, s.player_hp], is_equal_approx(s.player_hp, hp_at))
	# and the freeze has to lift again, or the test above passes on a dead game
	game.state = "playing"
	var resumed_at: Vector2 = mob.position
	await step(30)
	check("leaving the menu lets enemies move again (%.1fpx)" % mob.position.distance_to(resumed_at), mob.position.distance_to(resumed_at) > 5.0)
	game.free()

func test_balance_curve() -> void:
	var husk: float = EnemyCatalog.all()[0].hp
	var r1 := Balance.enemy_hp(1, husk)
	var r10 := Balance.enemy_hp(10, husk)
	check("round 1 enemies die to a few shots (%.0f hp)" % r1, r1 < 45.0)
	check("round 10 is a step up without being a wall (%.0f hp)" % r10, r10 > 200.0 and r10 < 900.0)
	# The bug this replaces: boss HP was linear while every enemy compounded, so
	# a wave-20 brute ended up with 2.4x the final boss's health and the wave-5
	# boss died in about two seconds. A boss has to outweigh the fattest thing
	# in its own wave, at *every* boss wave, not just the first.
	var brute: float = EnemyCatalog.get_enemy("brute").hp
	var outweighs := true
	var worst := ""
	for wave in [5, 10, 15, 20]:
		var ratio: float = Balance.boss_hp(wave) / Balance.enemy_hp(wave, brute)
		if ratio < 2.5:
			outweighs = false
			worst = "wave %d at %.1fx" % [wave, ratio]
	check("a boss outweighs its wave's brute throughout (%s)" % ("ok" if outweighs else worst), outweighs)
	# And is still killable: a fight, not a wall.
	check("boss at round 5 is a fight, not a wall (%.0f hp)" % Balance.boss_hp(5),
		Balance.boss_hp(5) > 3500.0 and Balance.boss_hp(5) < 8000.0)
	check("and it hits harder than the crowd it arrives with (%.0fx)" % Balance.BOSS_DAMAGE,
		Balance.BOSS_DAMAGE > 1.0)
	var need := Balance.XP_FIRST_LEVEL
	var total := 0
	for i in range(5):
		total += need
		need = Balance.next_level_xp(need)
	check("five levels cost a reachable amount of xp (%d)" % total, total < 200)

# --- phase 2: stats, materials, weapons, shop --------------------------------

func test_wave_clear_opens_shop() -> void:
	var game = await fresh_game()
	var s = game.session
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	s.round_time_left = 0.0
	s.round_phase = "cleanup"
	await step(4)
	check("clearing a wave opens the shop", s.round_phase == "shop" and game.state == "shop")
	check("the shop rolled a full board (%d offers)" % s.shop.offers.size(), s.shop.offers.size() == Shop.SLOTS)
	var wave_before: int = s.round_number
	game.leave_shop()
	check("leaving the shop starts the next wave (%d -> %d)" % [wave_before, s.round_number], s.round_number == wave_before + 1 and s.round_phase == "combat")
	game.free()

func test_shop_buying() -> void:
	var game = await fresh_game()
	var s = game.session
	s.finish_wave()
	var lens: Dictionary = {"kind":"item", "id":"focus_lens", "tier":1, "name":"FOCUS LENS",
		"text":"", "color":Color.WHITE, "price":10}
	s.shop.offers[0] = lens
	s.materials = 10
	var before: float = s.stats.get_stat("damage")
	check("an affordable offer can be bought", s.buy(0))
	check("materials are spent (%d left)" % s.materials, s.materials == 0)
	check("the item stat lands on the sheet (%.0f -> %.0f)" % [before, s.stats.get_stat("damage")], is_equal_approx(s.stats.get_stat("damage"), before + 8.0))
	check("the slot is emptied", s.shop.offers[0].is_empty())

	# A sold card must leave the cursor's list. It did not, so walking the shop
	# with a pad stopped dead on everything already bought.
	game.state = "shop"
	var rows: Array = game.menu_items()
	check("a sold card leaves the navigable list (%s)" % str(rows.slice(0, 4)),
		not ("buy_0" in rows) and not ("lock_0" in rows))
	check("and the cards still on the board stay in it", "buy_1" in rows and "buy_2" in rows)
	# Park the cursor on the last row, empty the board, and it must not be left
	# pointing past the end of a list that just got shorter.
	game.menu_index = rows.size() - 1
	for i in range(Shop.SLOTS):
		s.shop.offers[i] = {}
	await step(2)
	check("the cursor never survives past the end of a shrunken list (%d of %d)"
		% [game.menu_index, game.menu_items().size()],
		game.menu_index < game.menu_items().size())
	check("and it still points at something real (%s)" % game.focused_action(), game.focused_action() != "")
	check("the same slot cannot be bought twice", not s.buy(0))
	var plate: Dictionary = {"kind":"item", "id":"scrap_plate", "tier":1, "name":"SCRAP PLATE",
		"text":"", "color":Color.WHITE, "price":999}
	s.shop.offers[1] = plate
	check("an unaffordable offer is refused", not s.buy(1))
	var reroll_before: int = s.shop.reroll_cost()
	s.materials = 100
	s.reroll_shop()
	check("rerolling costs more each time (%d -> %d)" % [reroll_before, s.shop.reroll_cost()], s.shop.reroll_cost() > reroll_before)
	check("rerolling refills the board", s.shop.offers.size() == Shop.SLOTS and not s.shop.offers[0].is_empty())
	game.free()

# Merging is a decision the player makes, not something that happens to them:
# two barrels firing now against one weapon that hits far harder is the whole
# point of holding a duplicate.
func test_weapon_combining() -> void:
	var game = await fresh_game()
	var s = game.session
	var rack: Array[Weapon] = [Weapon.new("smg", 1)]
	s.weapons = rack
	check("a lone weapon has nothing to merge with", not s.can_combine(0))
	s.add_weapon("smg", 1)
	check("two of a kind stay separate until asked (%d)" % s.weapons.size(), s.weapons.size() == 2)
	check("and both offer the merge", s.can_combine(0) and s.can_combine(1))
	check("merging consumes both (%d left)" % s.weapons.size(), s.combine_weapon(0) and s.weapons.size() == 1)
	check("the merged weapon is a tier higher (tier %d)" % s.weapons[0].tier, s.weapons[0].tier == 2)
	check("the merged weapon hits harder (%.0f vs %.0f)" % [WeaponCatalog.damage_at("smg", 2), WeaponCatalog.damage_at("smg", 1)], WeaponCatalog.damage_at("smg", 2) > WeaponCatalog.damage_at("smg", 1))

	# a pair has to match on tier as well as on weapon
	s.add_weapon("smg", 1)
	check("a tier I and a tier II are not a pair", not s.can_combine(0) and not s.can_combine(1))

	# and there is nowhere above the top tier to merge into
	var maxed: Array[Weapon] = [Weapon.new("smg", WeaponCatalog.MAX_TIER), Weapon.new("smg", WeaponCatalog.MAX_TIER)]
	s.weapons = maxed
	check("a maxed pair has nowhere to go", not s.can_combine(0) and not s.combine_weapon(0))

	# the player draws the rack from the same array, so it must be mutated in
	# place -- a fresh array would leave the character orbiting the old weapons
	var shared: Array[Weapon] = [Weapon.new("wand", 1), Weapon.new("wand", 1)]
	s.weapons = shared
	s.player.weapons = s.weapons
	s.combine_weapon(0)
	check("the player's rack follows the merge (%d)" % s.player.weapons.size(), s.player.weapons.size() == 1)
	game.free()

# The same thing, driven through the shop the way a player reaches it.
func test_combine_in_the_shop() -> void:
	var game = await fresh_game()
	var s = game.session
	var rack: Array[Weapon] = [Weapon.new("smg", 1), Weapon.new("smg", 1), Weapon.new("rifle", 1)]
	s.weapons = rack
	s.player.weapons = s.weapons
	s.finish_wave()
	game.state = "shop"

	check("a duplicate hit-tests to combine (%s)" % game.ui.menu_action_at(game.ui.slot_combine_rect(0).get_center()),
		game.ui.menu_action_at(game.ui.slot_combine_rect(0).get_center()) == "combine_0")
	check("the rest of the slot still sells (%s)" % game.ui.menu_action_at(game.ui.slot_rect(0).position + Vector2(30, 30)),
		game.ui.menu_action_at(game.ui.slot_rect(0).position + Vector2(30, 30)) == "sell_0")
	check("a lone weapon offers no chip (%s)" % game.ui.menu_action_at(game.ui.slot_combine_rect(2).get_center()),
		game.ui.menu_action_at(game.ui.slot_combine_rect(2).get_center()) == "sell_2")

	# reachable without a mouse, and in the band the slots are drawn in
	var rows: Array[String] = game.menu_items()
	check("combining is in the navigable list (%s)" % str(rows.slice(rows.find("sell_0"))),
		rows.has("combine_0") and rows.has("sell_0") and not rows.has("combine_2"))
	check("and the shop is still three bands (%d)" % game.menu_groups().size(), game.menu_groups().size() == 3)

	# Park the cursor on the last row first: merging removes three rows at once
	# (both sells and both chips, less the one the merged weapon adds back), so
	# without a clamp the cursor is left pointing past the end of the list.
	game.menu_index = game.menu_items().size() - 1
	click(game, game.ui.slot_combine_rect(0).get_center())
	check("clicking combine merges the pair (%d weapons)" % s.weapons.size(), s.weapons.size() == 2)
	check("into one a tier up (%s)" % s.weapons[1].display_name(), s.weapons[1].tier == 2)
	check("and the cursor stays inside the shortened list (%d of %d)" % [game.menu_index, game.menu_items().size()],
		game.menu_index < game.menu_items().size())
	game.free()

func test_weapon_rack_limit() -> void:
	var game = await fresh_game()
	var s = game.session
	s.finish_wave()
	var rack: Array[Weapon] = []
	for def in WeaponCatalog.all().slice(0, GameSession.MAX_WEAPONS):
		rack.append(Weapon.new(String(def.id), 1))
	s.weapons = rack
	s.materials = 500
	var lance: Dictionary = {"kind":"weapon", "id":"lance", "tier":1, "name":"x", "text":"",
		"color":Color.WHITE, "price":1}
	s.shop.offers[0] = lance
	check("a full rack refuses a seventh weapon", not s.buy(0))
	# A full rack is a block, but not a dead end: merging a pair frees the slot
	# the purchase needs, and that is the whole reason the chip is in the shop.
	s.weapons[1] = Weapon.new("pistol", 1)
	s.weapons[2] = Weapon.new("pistol", 1)
	check("two of a kind in a full rack can merge", s.combine_weapon(1))
	check("which frees a slot (%d)" % s.weapons.size(), s.weapons.size() < GameSession.MAX_WEAPONS)
	check("and the purchase then goes through", s.buy(0))
	game.free()

func shots_fired_over(s, frames: int) -> int:
	var count := [0]
	var counter := func(_node: Node) -> void: count[0] += 1
	s.shots.child_entered_tree.connect(counter)
	await step(frames)
	s.shots.child_entered_tree.disconnect(counter)
	return count[0]

# Each weapon runs its own cooldown, so three of them must actually produce
# more fire than one rather than sharing a single timer.
func test_multi_weapon_output() -> void:
	var game = await fresh_game()
	var s = game.session
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	s.round_phase = "cleanup"
	var dummy = s.spawn_enemy(EnemyCatalog.all()[3], s.player.position + Vector2(120, 0), false)
	dummy.max_hp = 1000000.0
	dummy.hp = dummy.max_hp
	var single: Array[Weapon] = [Weapon.new("pistol", 1)]
	s.weapons = single
	var one: int = await shots_fired_over(s, 90)
	var trio: Array[Weapon] = [Weapon.new("pistol", 1), Weapon.new("pistol", 1), Weapon.new("pistol", 1)]
	s.weapons = trio
	var three: int = await shots_fired_over(s, 90)
	check("three weapons out-shoot one (%d vs %d)" % [three, one], one > 0 and three > one * 2)
	game.free()

func test_materials_are_currency_and_xp() -> void:
	var game = await fresh_game()
	var s = game.session
	var materials_before: int = s.materials
	var xp_before: int = s.xp
	s.on_pickup_collected(5)
	check("a pickup pays into the purse (%d -> %d)" % [materials_before, s.materials], s.materials == materials_before + 5)
	check("and into the level track (%d -> %d)" % [xp_before, s.xp], s.xp == xp_before + 5 or s.level > 1)
	game.free()

func test_stat_math() -> void:
	var stats := Stats.new()
	check("no armor takes full damage", is_equal_approx(stats.damage_taken(100.0), 100.0))
	stats.add("armor", 30.0)
	check("30 armor takes about two thirds (%.1f)" % stats.damage_taken(100.0),
		stats.damage_taken(100.0) > 60.0 and stats.damage_taken(100.0) < 70.0)
	stats.add("armor", 9970.0)
	# Floored, not merely asymptotic. Armor used to approach immunity slowly
	# enough that stacking it with dodge and regen got there anyway.
	check("armor alone can never take more than its floor (%.1f)" % stats.damage_taken(100.0),
		is_equal_approx(stats.damage_taken(100.0), Balance.ARMOR_MIN_TAKEN * 100.0))
	var offence := Stats.new()
	offence.add("damage", 50.0)
	check("damage percent multiplies (%.2f)" % offence.damage_multiplier(), is_equal_approx(offence.damage_multiplier(), 1.5))
	offence.add("attack_speed", 100.0)
	var weapon := Weapon.new("pistol", 1)
	check("attack speed halves the cooldown (%.3f)" % weapon.cooldown(offence), is_equal_approx(weapon.cooldown(offence), WeaponCatalog.cooldown_at("pistol", 1) / 2.0))
	var dodgy := Stats.new()
	dodgy.add("dodge", 500.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dodged := 0
	for i in range(400):
		if dodgy.dodges(rng): dodged += 1
	check("dodge is capped well below certainty (%d/400)" % dodged, dodged > 80 and dodged < 170)

	# The build that made round 14 survivable standing still. Every defensive
	# item and reward at once, against the crowd of that round: it has to still
	# lose. No single number below is the fix -- they multiply, which is exactly
	# what made this reachable, so the assertion is on the product.
	var tank := Stats.new()
	tank.set_stat("max_hp", 100.0)
	for id in ["scrap_plate", "ration_pack", "ghost_step", "leech_rune", "repair_field",
			"vital_spring", "bulwark", "hoarder", "quartermaster", "field_medic"]:
		var def := ItemCatalog.get_item(id)
		tank.apply_dict(def.stats)
		if def.has("per"):
			tank.add(String(def.per.stat), float(def.per.amount) * float(Balance.SYNERGY_ITEM_CAP))
	for reward in ["max_hp:12", "armor:2", "hp_regen:0.25", "lifesteal:1.8", "hp_regen:0.55", "armor:5", "dodge:3", "hp_regen:0.9"]:
		var bits: PackedStringArray = reward.split(":")
		tank.add(bits[0], float(bits[1]))
	check("a full defensive build caps its regen (%.2f/s)" % tank.regen_per_second(),
		tank.regen_per_second() <= Balance.REGEN_CAP)
	# Round 14 sends roughly this much contact damage a second into a standing
	# player, before any of the mitigation below.
	# Eight husks in contact, which is about as many as fit round the player,
	# each landing roughly one hit a second at their cooldown.
	var raw := 8.0 * Balance.enemy_damage(14, 8.0)
	var after_armor := tank.damage_taken(raw)
	var after_dodge := after_armor * (1.0 - minf(tank.get_stat("dodge"), Balance.DODGE_CAP) / 100.0)
	check("armor and dodge together do not erase the crowd (%.0f of %.0f dps)" % [after_dodge, raw],
		after_dodge > raw * 0.30)
	check("and standing in it still outruns regen (%.0f dps vs %.2f/s)" % [after_dodge, tank.regen_per_second()],
		after_dodge > tank.regen_per_second() * 2.0)
	var pool: float = tank.get_stat("max_hp")
	var seconds: float = pool / maxf(after_dodge - tank.regen_per_second(), 0.01)
	check("so standing still kills you in %.0fs, not never" % seconds, seconds < 30.0)

# --- phase 2.5: healing, nova, bigger arena ----------------------------------

func test_healing() -> void:
	var game = await fresh_game()
	var s = game.session
	s.player.hp = 20.0
	s.on_pickup_collected(Balance.HEALTH_DROP_AMOUNT, Pickup.KIND_HEALTH)
	check("a bandage heals instead of paying materials (hp %.0f, mats %d)" % [s.player.hp, s.materials], s.player.hp > 20.0 and s.materials == 0)
	# the steady trickle: every HEAL_EVERY_KILLS kills pays out
	s.player.hp = 20.0
	var before: float = s.player.hp
	s.kills = 0
	for i in range(Balance.HEAL_EVERY_KILLS):
		s.on_enemy_died(s.player.position + Vector2(400, 0), 1, false)
	check("a run of kills heals on its own (%.0f -> %.0f)" % [before, s.player.hp], s.player.hp > before)
	s.player.hp = s.player.max_hp
	s.player.heal(10.0)
	check("healing at full hp does not overflow (%.0f/%.0f)" % [s.player.hp, s.player.max_hp], is_equal_approx(s.player.hp, s.player.max_hp))
	game.free()

func test_nova() -> void:
	var game = await fresh_game()
	var s = game.session
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	s.round_phase = "cleanup"
	var near = s.spawn_enemy(EnemyCatalog.all()[0], s.player.position + Vector2(90, 0), false)
	var far = s.spawn_enemy(EnemyCatalog.all()[0], s.player.position + Vector2(Balance.NOVA_RADIUS + 260.0, 0), false)
	near.max_hp = 100000.0
	near.hp = near.max_hp
	far.max_hp = 100000.0
	far.hp = far.max_hp
	await step(1)
	var near_hp: float = near.hp
	var far_hp: float = far.hp
	var near_at: Vector2 = near.position
	s.nova_cooldown = 0.0
	s.rift_nova()
	check("the nova spawns a visible blast", s.get_node_or_null("NovaBlast") != null)
	check("it damages what is inside the ring (%.0f -> %.0f)" % [near_hp, near.hp], near.hp < near_hp)
	check("and spares what is outside it", is_equal_approx(far.hp, far_hp))
	await step(10)
	check("it throws enemies outward (%.0fpx)" % near.position.distance_to(near_at), near.position.distance_to(near_at) > 20.0)
	check("the nova goes on cooldown (%.1fs)" % s.nova_cooldown, s.nova_cooldown > 0.0)
	await step(45)
	check("the blast cleans itself up", s.get_node_or_null("NovaBlast") == null)
	game.free()

# The window used to open exactly as tall as a 1080p desktop, so the title bar
# pushed the bottom of the UI -- the HP and XP bars -- off the screen entirely.
func test_display_settings() -> void:
	var design := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	check("the design viewport is 1920x1080 (%s)" % design, design == Vector2(1920, 1080))
	check("the UI is laid out against that same size", GameUI.SCREEN == design)
	check("canvas_items stretch scales the design size into the window",
		String(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items")
	check("aspect is kept, so nothing is cropped off an edge",
		String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "keep")
	var window_h := int(ProjectSettings.get_setting("display/window/size/window_height_override"))
	check("the default window leaves room for a title bar (%dpx tall)" % window_h, window_h > 0 and window_h <= 1000)
	var visible: Vector2 = get_root().get_visible_rect().size
	check("the viewport still measures the full design area (%s)" % visible, visible == design)

# --- menus: mouse and keyboard have to agree ---------------------------------

func press(game, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game._unhandled_input(event)

func click(game, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	game._unhandled_input(event)

func pad_press(game, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	# A real event reaches _input first, which is where the device is tracked.
	game._input(event)
	game._unhandled_input(event)

func move_mouse(game, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	game._unhandled_input(event)

func release_mouse(game) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	game._unhandled_input(event)

func test_menu_navigation() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.profile.persist = false

	game.state = "settings"
	check("a screen opens on its first row", game.menu_index == 0)
	press(game, KEY_DOWN)
	check("down moves the cursor (%d)" % game.menu_index, game.menu_index == 1)
	press(game, KEY_UP)
	press(game, KEY_UP)
	check("up wraps round to the last row (%d)" % game.menu_index, game.menu_index == game.menu_items().size() - 1)

	game.menu_index = 2
	game.state = "title"
	check("changing screen resets the cursor", game.menu_index == 0)

	# Enter activates whatever is focused, on every list screen.
	game.state = "settings"
	var volume_before: float = game.audio.volume
	press(game, KEY_ENTER)
	check("enter mutes the focused volume row (%.2f -> %.2f)" % [volume_before, game.audio.volume], not is_equal_approx(game.audio.volume, volume_before))
	press(game, KEY_LEFT)
	press(game, KEY_RIGHT)
	check("left and right adjust a slider (%.2f)" % game.audio.volume, game.audio.volume > 0.0)
	game.menu_index = game.menu_items().find("rift")
	var rift_before: bool = game.rift_effects_enabled
	press(game, KEY_SPACE)
	check("space toggles a toggle row", game.rift_effects_enabled != rift_before)
	game.menu_index = game.menu_items().size() - 1
	press(game, KEY_ENTER)
	check("the back row leaves the screen", game.state == "title")

	# Every row has to hit-test to its own action, or a click lands on the
	# wrong setting.
	for screen in ["settings", "paused", "title"]:
		game.state = screen
		var items: Array[String] = game.menu_items()
		var matched := true
		for i in range(items.size()):
			var rect: Rect2 = game.ui.settings_row_rect(i) if screen == "settings" else (game.ui.pause_row_rect(i) if screen == "paused" else game.ui.menu_button_rect(i))
			if game.ui.menu_action_at(rect.get_center()) != items[i]: matched = false
		check("every %s row hit-tests to its own action" % screen, matched)

	# A click has to do the same thing the keyboard would.
	game.state = "settings"
	var rift_row: int = game.menu_items().find("rift")
	var before: bool = game.rift_effects_enabled
	click(game, game.ui.settings_row_rect(rift_row).get_center())
	check("clicking a toggle row flips it", game.rift_effects_enabled != before)
	# clicking a slider sets it where you clicked, rather than toggling
	var bar: Rect2 = game.ui.settings_bar_rect(0)
	click(game, Vector2(bar.position.x + bar.size.x * 0.25, bar.get_center().y))
	check("clicking a bar sets it to that point (%.2f)" % game.audio.volume, absf(game.audio.volume - 0.25) < 0.06)

	# The mouse and the keyboard cursor must not disagree about the target.
	game.state = "settings"
	game.menu_index = 0
	var full_row: int = game.menu_items().find("quality")
	game.sync_hover(game.ui.settings_row_rect(full_row).get_center())
	check("hovering moves the keyboard cursor onto that row (%d)" % game.menu_index, game.menu_index == full_row and game.menu_hover == "quality")
	game.sync_hover(Vector2(5, 5))
	check("moving off the rows leaves the cursor where it was (%d)" % game.menu_index, game.menu_index == full_row and game.menu_hover == "")

	# The three display settings step through a list rather than toggling, and
	# they wrap, so a pad can walk one either way without a "back" row.
	game.menu_index = game.menu_items().find("quality")
	var quality_before: int = game.profile.choice("quality")
	game.handle_verb("nav_right")
	check("right steps a choice row (%d -> %d)" % [quality_before, game.profile.choice("quality")],
		game.profile.choice("quality") != quality_before)
	game.handle_verb("nav_left")
	check("and left steps it back (%d)" % game.profile.choice("quality"),
		game.profile.choice("quality") == quality_before)
	for i in range(DisplaySettings.QUALITY.size() + 1):
		game.handle_verb("nav_right")
	check("choices wrap rather than sticking at the end (%d)" % game.profile.choice("quality"),
		game.profile.choice("quality") >= 0 and game.profile.choice("quality") < DisplaySettings.QUALITY.size())
	# Quality is a frame-cost dial: it has to actually reach the things that
	# multiply with the crowd, not merely be remembered.
	game.profile.set_choice("quality", 0)
	game.apply_display()
	var low_numbers: int = game.session.number_cap
	game.profile.set_choice("quality", DisplaySettings.QUALITY.size() - 1)
	game.apply_display()
	check("quality changes the damage-number budget (%d -> %d)" % [low_numbers, game.session.number_cap],
		game.session.number_cap > low_numbers)

	# Settings grew to eight rows plus a hint line and a mouse footer. The same
	# thing that broke the title screen breaks this one: a footer placed under
	# the last row leaves the screen instead of overlapping something.
	var rows_here: int = game.menu_items().size()
	var last_row: Rect2 = game.ui.settings_row_rect(rows_here - 1)
	check("the settings rows and their footer fit the screen (%.0f + %.0f of %.0f)"
		% [last_row.end.y, GameUI.MENU_FOOTER, GameUI.SCREEN.y],
		last_row.end.y + GameUI.MENU_FOOTER <= GameUI.SCREEN.y)

	# The title menu and its footer have to fit the screen. Adding a sixth row
	# once pushed QUIT GAME straight over the coin line and the prompts, because
	# the footer was placed at fixed pixels rather than under the last button.
	game.state = "title"
	var last: Rect2 = game.ui.menu_button_rect(game.menu_items().size() - 1)
	check("the title menu and its footer fit on screen (%.0f + %.0f)" % [last.end.y, GameUI.MENU_FOOTER],
		last.end.y + GameUI.MENU_FOOTER <= GameUI.SCREEN.y)
	check("and the first row clears the title art (%.0f)" % last.position.y, GameUI.MENU_TOP > 380.0)

	game.state = "paused"
	press(game, KEY_ENTER)
	check("pause resumes from its first row", game.state == "playing")
	game.free()

# --- phase 3: feel -----------------------------------------------------------

func test_damage_numbers() -> void:
	var game = await fresh_game()
	var s = game.session
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	s.round_phase = "cleanup"
	var mob = s.spawn_enemy(EnemyCatalog.all()[0], s.player.position + Vector2(150, 0), false)
	mob.max_hp = 1000000.0
	mob.hp = mob.max_hp
	await step(1)
	mob.take_damage(37.0, false)
	await step(2)
	check("a hit spawns a floating number (%d)" % s.numbers.get_child_count(), s.numbers.get_child_count() == 1)
	var number = s.numbers.get_child(0)
	check("it reads the damage dealt (%d)" % number.amount, number.amount == 37)
	check("and is not flagged as a crit", not number.crit)
	mob.take_damage(80.0, true)
	await step(2)
	check("a crit is flagged for the bigger style", s.numbers.get_child(1).crit)
	# A fast weapon must not be able to bury the screen in numbers.
	for i in range(GameSession.MAX_NUMBERS + 40):
		mob.take_damage(1.0, false)
	await step(2)
	check("the number count is capped (%d)" % s.numbers.get_child_count(), s.numbers.get_child_count() <= GameSession.MAX_NUMBERS + 1)
	game.free()

func test_elites() -> void:
	var game = await fresh_game()
	var s = game.session
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	s.round_phase = "cleanup"
	s.round_number = 6
	var normal = s.spawn_enemy(EnemyCatalog.all()[0], s.player.position + Vector2(300, 0), false, false)
	var elite = s.spawn_enemy(EnemyCatalog.all()[0], s.player.position + Vector2(400, 0), false, true)
	await step(1)
	check("an elite has far more health (%.0f vs %.0f)" % [elite.max_hp, normal.max_hp], elite.max_hp > normal.max_hp * 3.0)
	check("it is worth more materials (%d vs %d)" % [elite.material_value, normal.material_value], elite.material_value > normal.material_value)
	check("it is physically bigger (%.0f vs %.0f)" % [elite.radius, normal.radius], elite.radius > normal.radius)
	check("no elites before round %d" % Balance.ELITE_FIRST_ROUND, is_zero_approx(Balance.elite_chance(1)) and is_zero_approx(Balance.elite_chance(2)))
	check("elites appear later (%.2f at round 6)" % Balance.elite_chance(6), Balance.elite_chance(6) > 0.0)
	check("and stay rare (%.2f at round 40)" % Balance.elite_chance(40), Balance.elite_chance(40) <= Balance.ELITE_CHANCE_MAX)
	game.free()

func test_shake_and_hitstop() -> void:
	var game = await fresh_game()
	var s = game.session
	s.shake = 0.0
	s.position = Vector2.ZERO
	s.add_shake(Balance.SHAKE_NOVA)
	check("shake builds up (%.1f)" % s.shake, s.shake > 0.0)
	s.add_shake(1000.0)
	check("and is capped (%.1f)" % s.shake, s.shake <= Balance.SHAKE_MAX)
	await step(4)
	check("it offsets the field", s.position != Vector2.ZERO)
	# The HUD is a sibling of the session, so it must not be moving with it.
	check("but not the HUD", game.ui.position == Vector2.ZERO)
	for i in range(120):
		s._process(0.05)
	# Back to where the session sits, which is not the origin: it is offset and
	# scaled so the oversized arena lands on Arena.VIEW.
	check("it settles back to rest (%.1f, %s)" % [s.shake, s.position],
		is_zero_approx(s.shake) and s.position.is_equal_approx(s.view_origin))
	check("and the arena is drawn exactly onto its view",
		s.position.is_equal_approx(Arena.VIEW.position - Arena.BOUNDS.position * s.scale.x)
		and is_equal_approx(Arena.BOUNDS.size.x * s.scale.x, Arena.VIEW.size.x)
		and is_equal_approx(Arena.BOUNDS.size.y * s.scale.y, Arena.VIEW.size.y))

	s.hit_stop(0.05)
	check("hit stop slows time (%.2f)" % Engine.time_scale, Engine.time_scale < 1.0)
	# main.gd restores it, because it keeps processing while the tree is
	# paused and the session does not.
	s.hitstop_until = 0
	game._process(0.016)
	check("and time is restored afterwards (%.2f)" % Engine.time_scale, is_equal_approx(Engine.time_scale, 1.0))
	Engine.time_scale = 1.0
	game.free()

# --- phase 4: the run has an end ---------------------------------------------

func test_victory_ends_the_run() -> void:
	var game = await fresh_game()
	var s = game.session
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	s.round_number = Balance.FINAL_WAVE
	s.round_time_left = 0.0
	s.round_phase = "cleanup"
	await step(4)
	check("clearing the final wave wins the run", s.round_phase == "won" and game.state == "victory")
	check("winning pays a reward (%d coins)" % game.last_reward, game.last_reward > 0)
	# and it must not roll on into wave 21
	var wave: int = s.round_number
	await step(30)
	check("the wave clock stops once won (%d)" % s.round_number, s.round_number == wave and s.actors.get_child_count() == 0)
	game.free()

func test_danger_levels() -> void:
	var game = await fresh_game()
	var s = game.session
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	s.round_phase = "cleanup"
	s.round_number = 5
	s.danger = 0
	var calm = s.spawn_enemy(EnemyCatalog.all()[0], s.player.position + Vector2(400, 0), false)
	s.danger = Balance.DANGER_LEVELS - 1
	var deadly = s.spawn_enemy(EnemyCatalog.all()[0], s.player.position + Vector2(500, 0), false)
	await step(1)
	check("danger 0 changes nothing", is_equal_approx(Balance.danger_hp(0), 1.0) and is_equal_approx(Balance.danger_speed(0), 1.0))
	check("higher danger means tougher enemies (%.0f vs %.0f hp)" % [deadly.max_hp, calm.max_hp], deadly.max_hp > calm.max_hp)
	check("and pays more materials (%d vs %d)" % [deadly.material_value, calm.material_value], deadly.material_value > calm.material_value)
	check("and spawns them faster", Balance.danger_spawn(5) < Balance.danger_spawn(0))
	# the ladder: you can only pick what you have unlocked
	game.profile.data.max_danger = 2
	game.set_danger(5)
	check("danger is clamped to what is unlocked (%d)" % game.danger, game.danger == 2)
	game.set_danger(-3)
	check("and cannot go below zero (%d)" % game.danger, game.danger == 0)
	game.free()

func test_profile_persistence() -> void:
	var profile := ProfileManager.new()
	profile.persist = false
	check("settings default on", profile.setting("rift_effects") and profile.level("sfx_volume") > 0.0)
	profile.set_setting("rift_effects", false)
	check("a setting sticks in memory", not profile.setting("rift_effects"))
	profile.set_level("music_volume", 0.3)
	check("a volume sticks in memory (%.2f)" % profile.level("music_volume"), is_equal_approx(profile.level("music_volume"), 0.3))
	var reloaded := profile.sanitized({"coins": 5, "sfx_volume": 0.25, "fullscreen": true, "max_danger": 3})
	check("settings survive a round trip", is_equal_approx(reloaded.sfx_volume, 0.25) and reloaded.fullscreen == true)
	check("max_danger survives (%s)" % reloaded.max_danger, reloaded.max_danger == 3)
	var junk := profile.sanitized({"rift_effects": "yes", "sfx_volume": 40.0, "max_danger": 99})
	check("a junk setting falls back to the default", junk.rift_effects == true)
	check("an out-of-range volume is clamped (%.2f)" % junk.sfx_volume, junk.sfx_volume <= 1.0)
	check("and max_danger is clamped (%s)" % junk.max_danger, junk.max_danger == Balance.DANGER_LEVELS - 1)
	# winning opens the next rung, and only ever upward
	var ladder := ProfileManager.new()
	ladder.persist = false
	check("winning at 0 unlocks 1", ladder.record_victory(0) and ladder.max_danger() == 1)
	check("winning at 0 again changes nothing", not ladder.record_victory(0) and ladder.max_danger() == 1)
	check("winning at 1 unlocks 2", ladder.record_victory(1) and ladder.max_danger() == 2)

# Adding a weapon or item without its icon would otherwise only show up as a
# blank space on a shop card, which is easy to miss.
# Characters are earned, not bought. A price only asks for time; an achievement
# asks for something the player has not done yet.
func test_achievements() -> void:
	var game = await fresh_game()
	game.profile.data.unlocked_characters = [0]
	game.profile.data.achievements = []
	var s = game.session

	check("only the first survivor is free at the start",
		game.profile.is_character_unlocked(0) and not game.profile.is_character_unlocked(1))
	# every achievement that opens a character must be reachable, and no two may
	# open the same one, or a character would be unreachable
	var opened: Array[int] = []
	for def in AchievementCatalog.all():
		if int(def.unlocks) >= 0:
			check("%s opens exactly one survivor" % def.id, not (int(def.unlocks) in opened))
			opened.append(int(def.unlocks))
	var missing: Array[int] = []
	for i in range(1, CharacterCatalog.all().size()):
		if not (i in opened): missing.append(i)
	check("every locked survivor has a way in (%s)" % str(missing), missing.is_empty())

	# a run that reaches wave 5 earns the wave-5 award and opens what it opens
	s.round_number = 5
	var earned: Array = game.profile.award_all(s.run_summary())
	check("reaching wave 5 earns it (%s)" % str(earned), "rift_walker" in earned)
	var opens := int(AchievementCatalog.get_achievement("rift_walker").unlocks)
	check("and unlocks its survivor (%d)" % opens, game.profile.is_character_unlocked(opens))
	check("it is not earned twice", game.profile.award_all(s.run_summary()).is_empty())
	# one run can satisfy several at once
	check("wave 5 also cleared the wave-1 award", game.profile.has_achievement("first_blood"))
	check("but not one it did not meet", not game.profile.has_achievement("deep_run"))

	# the armory refuses a survivor that has not been earned
	game.state = "title"
	game.selected_character = CharacterCatalog.all().size() - 1
	game.profile.data.unlocked_characters = [0]
	game.start_run()
	check("a locked survivor cannot be taken into a run (%s)" % game.state, game.state != "playing")
	# and cycling in the armory never lands on one
	game.state = "armory"
	game.selected_character = 0
	var strayed := false
	for i in range(10):
		game.cycle_character(1)
		if not game.profile.is_character_unlocked(game.selected_character): strayed = true
	check("the armory only walks what is unlocked", not strayed)

	# a truncated or tampered profile drops ids that are not in the catalog
	var raw := {"achievements": ["rift_walker", "not_a_real_award", 7]}
	game.profile.data = game.profile.sanitized(raw)
	check("unknown achievements are dropped on read (%s)" % str(game.profile.achievements()),
		game.profile.achievements() == ["rift_walker"])
	game.free()

func test_every_icon_exists() -> void:
	var missing: Array[String] = []
	for def in WeaponCatalog.all():
		if Icons.texture(Icons.WEAPON_PATH % def.id) == null:
			missing.append("weapon:" + String(def.id))
	for def in ItemCatalog.all():
		if Icons.texture(Icons.item_path(String(def.id))) == null:
			missing.append("item:" + String(def.id))
	check("every weapon and item has an icon (%s)" % ("all present" if missing.is_empty() else str(missing)), missing.is_empty())
	check("a missing icon degrades instead of crashing", Icons.texture("res://assets/icons/does_not_exist.svg") == null)

# The old audio was one generated sine, so a busy wave was a single voice
# cutting itself off. These assert the replacement is actually wired up.
func test_audio_banks() -> void:
	var game = await fresh_game()
	var audio = game.audio
	var empty: Array[String] = []
	for name in AudioSfx.BANKS:
		if (audio.banks.get(name, []) as Array).is_empty(): empty.append(String(name))
	check("every sound bank loaded from disk (%s)" % ("all present" if empty.is_empty() else str(empty)), empty.is_empty())
	check("the voice pool is polyphonic (%d voices)" % audio.voices.size(), audio.voices.size() >= 8)
	var varied := 0
	for name in AudioSfx.BANKS:
		if (audio.banks[name] as Array).size() > 1: varied += 1
	check("repeated sounds have variations (%d banks)" % varied, varied >= 5)
	var unmapped: Array[String] = []
	for def in WeaponCatalog.all():
		if not AudioSfx.BANKS.has("shoot_" + String(def.get("sound", ""))): unmapped.append(String(def.id))
	check("every weapon maps to a real shoot bank (%s)" % ("ok" if unmapped.is_empty() else str(unmapped)), unmapped.is_empty())
	audio.stop_all()
	audio.enabled = false
	audio.play("kill")
	var silent := 0
	for voice in audio.voices:
		if voice.playing: silent += 1
	check("sound off means nothing plays (%d voices busy)" % silent, silent == 0)
	audio.enabled = true
	game.free()

func test_music() -> void:
	var game = await fresh_game()
	var audio = game.audio
	audio.set_music_volume(0.5)
	audio.play_music("combat")
	check("a track loads and starts", audio.music.stream != null and audio.current_track == "combat")
	check("it is set to loop", not (audio.music.stream is AudioStreamMP3) or audio.music.stream.loop)
	audio.play_music("menu")
	check("switching tracks swaps the stream", audio.current_track == "menu")
	audio.set_music_volume(0.0)
	check("zero music volume stops playback", not audio.music.playing)
	audio.set_music_volume(0.5)
	check("raising it again resumes", audio.music.playing)
	game.state = "playing"
	var combat: String = game.music_for_state()
	game.state = "title"
	check("combat and the menus use different tracks (%s / %s)" % [combat, game.music_for_state()], combat != game.music_for_state())
	game.free()

# The complaint that started this: healing scaled with the kill count, and the
# kill count explodes, so by round 7 standing still was the strongest play.
func test_healing_is_scarce() -> void:
	var game = await fresh_game()
	var s = game.session
	s.player.hp = 10.0
	var before: float = s.player.hp
	for i in range(100):
		s.on_enemy_died(s.player.position + Vector2(700, 0), 1, false)
	var trickle: float = s.player.hp - before
	check("a hundred kills heal only a trickle (%.0f hp)" % trickle, trickle > 0.0 and trickle < 20.0)
	s.stats.add("lifesteal", 50.0)
	s.player.hp = 10.0
	s.on_damage_dealt(100000.0)
	var leeched: float = s.player.hp - 10.0
	var ceiling: float = s.player.max_hp * Balance.LIFESTEAL_MAX_PER_HIT
	check("one huge hit cannot refill the bar (%.1f of %.1f allowed)" % [leeched, ceiling], leeched <= ceiling + 0.01)
	check("bandages are rare (%.0f%% of kills)" % (Balance.HEALTH_DROP_CHANCE * 100.0), Balance.HEALTH_DROP_CHANCE <= 0.03)
	game.free()

# The wave-6 wall was a health economy problem, not a damage one: chip damage
# carried across a whole run with nothing that could ever answer it.
func test_between_wave_healing() -> void:
	var game = await fresh_game()
	var s = game.session
	s.player.hp = s.player.max_hp * 0.3
	var before: float = s.player.hp
	s.finish_wave()
	var gained: float = s.player.hp - before
	# Deliberately modest. It exists so chip damage does not carry across a
	# whole run untouched, not so a wave clear undoes the wave -- the second
	# pass on healing cut it after "I take damage and heal immediately".
	check("clearing a wave pays back some of the bar (%.0f hp)" % gained,
		gained > s.player.max_hp * 0.10 and gained < s.player.max_hp * 0.25)
	check("but not a full refill (%.0f/%.0f)" % [s.player.hp, s.player.max_hp], s.player.hp < s.player.max_hp)
	s.player.hp = s.player.max_hp
	s.finish_wave()
	check("and it cannot overflow the bar", is_equal_approx(s.player.hp, s.player.max_hp))

	# Regen has to be something a build can actually invest in, or the stat is
	# a number on a sheet that nothing ever grants.
	var levels: Array = UpgradeCatalog.pool().filter(func(reward: Dictionary) -> bool:
		return reward.stats.has("hp_regen"))
	check("levelling up can grant regen (%d rewards)" % levels.size(), levels.size() >= 2)
	var sold: Array = ItemCatalog.all().filter(func(def: Dictionary) -> bool:
		return def.stats.has("hp_regen") or (def.has("per") and String(def.per.stat) == "hp_regen"))
	check("and the shop sells it (%d items)" % sold.size(), sold.size() >= 3)

	# and it has to actually tick on the player. finish_wave sent the game to
	# the shop, which pauses the tree -- and regen lives in _physics_process.
	clear_field(s)
	game.state = "playing"
	s.round_phase = "shop"
	s.player.stats.set_stat("hp_regen", 30.0)
	s.player.hp = 10.0
	await step(20)
	check("regen ticks while the player is alive (%.1f hp)" % s.player.hp, s.player.hp > 10.0)
	game.free()

# Level-up rewards were keyboard-only: 1 to 4 and nothing else.
func test_level_up_selection() -> void:
	var game = await fresh_game()
	var s = game.session
	s.upgrades = UpgradeCatalog.roll_choices(s.rng, 1, 0.0)
	game.state = "level_up"
	check("the level-up screen is a navigable list (%d rows)" % game.menu_items().size(),
		game.menu_items().size() == s.upgrades.size())
	var matched := true
	for i in range(s.upgrades.size()):
		if game.ui.menu_action_at(game.ui.upgrade_rect(i).get_center()) != "upgrade_%d" % i: matched = false
	check("every card hit-tests to its own reward", matched)

	# a click takes that reward and leaves the screen
	s.upgrade_totals = {}
	click(game, game.ui.upgrade_rect(1).get_center())
	check("clicking a card takes the reward (%s)" % str(s.upgrade_totals), not s.upgrade_totals.is_empty())
	check("and leaves the level-up screen (%s)" % game.state, game.state != "level_up")

	# the arrows and Enter reach the same card
	s.upgrades = UpgradeCatalog.roll_choices(s.rng, 1, 0.0)
	s.upgrade_totals = {}
	game.state = "level_up"
	check("the cursor starts on the first card (%d)" % game.menu_index, game.menu_index == 0)
	press(game, KEY_RIGHT)
	check("right moves along the cards (%d)" % game.menu_index, game.menu_index == 1)
	press(game, KEY_ENTER)
	check("enter takes the focused card", not s.upgrade_totals.is_empty() and game.state != "level_up")

	# the shop opens on NEXT WAVE, because Space has always meant "leave"
	game.state = "playing"
	s.finish_wave()
	check("the shop opens on its exit button (%s)" % game.focused_action(), game.focused_action() == "go")
	check("and its cards, buttons and slots are one list (%d rows)" % game.menu_items().size(),
		game.menu_items().size() >= GameUI.SHOP_CARDS + 2)
	check("laid out as the bands it is drawn in (%d)" % game.menu_groups().size(), game.menu_groups().size() == 3)
	game.free()

# A button that is drawn and not hit-tested is the quietest bug on a menu: it
# looks finished and does nothing. Both of these shipped that way, because their
# rectangles were laid out inline where they were drawn rather than coming from
# a helper menu_action_at could ask about.
func test_everything_drawn_is_clickable() -> void:
	var game = await fresh_game()

	# Controls: reachable only from settings, and its BACK went nowhere.
	game.state = "settings"
	game.handle_menu_action("controls")
	check("settings opens the controls screen (%s)" % game.state, game.state == "controls")
	check("its BACK button is hit-tested",
		game.ui.menu_action_at(game.ui.controls_back_rect().get_center()) == "back")
	click(game, game.ui.controls_back_rect().get_center())
	check("and clicking it goes back where it came from (%s)" % game.state, game.state == "settings")

	# Armory: only BACK and the danger chips were clickable, so the weapon cards
	# and the survivor panel could be seen and not chosen.
	game.state = "armory"
	game.selected_gun = 0
	click(game, game.ui.gun_rect(2).get_center())
	check("clicking a weapon card equips it (%d)" % game.selected_gun, game.selected_gun == 2)
	var before: int = game.selected_character
	click(game, game.ui.character_panel_rect().get_center())
	check("clicking the survivor panel steps to the next one (%d -> %d)" % [before, game.selected_character],
		game.selected_character != before)
	# And the rows that already worked still do.
	click(game, game.ui.danger_rect(0).get_center())
	check("the danger chips still answer (%d)" % game.danger, game.danger == 0)
	game.free()

# Enemies used to pick a uniformly random edge on every single spawn, which
# averages out to "surrounded, always" and gives the player nothing to read or
# run from. A few gates are open at a time instead, and they move.
func test_spawn_gates_have_a_direction() -> void:
	var game = await fresh_game()
	var s = game.session
	var centre := Arena.BOUNDS.get_center()
	var worst := 0
	for wave in range(6):
		s.pick_gates()
		var octants := {}
		for i in range(90):
			var at: Vector2 = s.spawn_point()
			octants[int(wrapf((at - centre).angle(), 0.0, TAU) / (TAU / 8.0))] = true
		worst = maxi(worst, octants.size())
	check("a wave's crowd arrives from a direction, not everywhere (%d of 8 octants)" % worst,
		worst <= 5)
	# Whatever the gates are, an enemy still has to arrive inside the walls.
	var outside := 0
	for i in range(120):
		if not Arena.BOUNDS.has_point(s.spawn_point()): outside += 1
	check("and always inside the arena (%d outside)" % outside, outside == 0)
	game.free()

# Capping defence left walking away as the only answer to a crowd. These are the
# other two, and they are what the defensive nerfs are balanced against.
func test_crowd_control() -> void:
	var game = await fresh_game()
	var s = game.session
	var control := Stats.new()
	check("no investment means no crowd control (%.0f, %.2f)" % [control.knockback_force(), control.slow_factor()],
		is_zero_approx(control.knockback_force()) and is_equal_approx(control.slow_factor(), 1.0))
	control.add("slow", 999.0)
	check("slow is capped short of a freeze (%.2f)" % control.slow_factor(),
		control.slow_factor() > 0.0 and is_equal_approx(control.slow_factor(), 1.0 - Balance.SLOW_MAX / 100.0))

	# Two identical enemies the same distance out, one chilled. The slowed one
	# has to cover measurably less ground.
	clear_field(s)
	var husk := EnemyCatalog.get_enemy("husk")
	var quick: Enemy = s.spawn_enemy(husk, s.player.position + Vector2(0, -420), false)
	var slowed: Enemy = s.spawn_enemy(husk, s.player.position + Vector2(0, 420), false)
	quick.max_hp = 1000000.0
	quick.hp = quick.max_hp
	slowed.max_hp = 1000000.0
	slowed.hp = slowed.max_hp
	await step(1)
	var quick_from: Vector2 = quick.position
	var slow_from: Vector2 = slowed.position
	slowed.chill(0.4, 5.0)
	await step(12)
	var quick_moved: float = quick.position.distance_to(quick_from)
	var slow_moved: float = slowed.position.distance_to(slow_from)
	check("a chilled enemy covers less ground (%.0f vs %.0fpx)" % [slow_moved, quick_moved],
		slow_moved < quick_moved * 0.75)

	# And a shove moves one away from where it was heading.
	var target: Vector2 = s.player.position
	var shoved: Enemy = s.spawn_enemy(husk, target + Vector2(0, -300), false)
	shoved.max_hp = 1000000.0
	shoved.hp = shoved.max_hp
	await step(1)
	var near: float = shoved.position.distance_to(target)
	shoved.push(Vector2.UP, 900.0)
	await step(4)
	check("and a shove pushes one back out (%.0f -> %.0fpx)" % [near, shoved.position.distance_to(target)],
		shoved.position.distance_to(target) > near)
	game.free()

# A mouse left sitting on a card must not fight the arrow keys. The shop and
# the level-up screen are wall-to-wall cards, so the pointer is nearly always
# resting on one -- and re-reading it every frame put the cursor straight back
# under the mouse, which made the arrows look dead on exactly those two screens.
func test_pointer_does_not_fight_the_arrows() -> void:
	var game = await fresh_game()
	var s = game.session

	s.upgrades = UpgradeCatalog.roll_choices(s.rng, 1, 0.0)
	game.state = "level_up"
	var parked: Vector2 = game.ui.upgrade_rect(1).get_center()
	game.follow_pointer(parked)
	check("a resting pointer takes the cursor (%d)" % game.menu_index, game.menu_index == 1)
	press(game, KEY_RIGHT)
	check("right still moves off it (%d)" % game.menu_index, game.menu_index == 2)
	# The frames that follow, with the mouse sitting exactly where it was left.
	for _i in range(3): game.follow_pointer(parked)
	check("and the resting pointer does not drag it back (%d)" % game.menu_index,
		game.menu_index == 2)
	game.follow_pointer(game.ui.upgrade_rect(0).get_center())
	check("actually moving the mouse takes the cursor back (%d)" % game.menu_index,
		game.menu_index == 0)

	# The shop is the other screen laid out across the display, and the one the
	# pointer is most likely to be parked on.
	game.state = "playing"
	s.finish_wave()
	var card: Vector2 = game.ui.card_rect(1).get_center()
	game.follow_pointer(card)
	var hovered: int = game.menu_index
	check("the pointer takes the shop cursor (%s)" % game.focused_action(),
		game.focused_action() == "buy_1")
	press(game, KEY_RIGHT)
	var moved: int = game.menu_index
	for _i in range(3): game.follow_pointer(card)
	check("the shop cursor stays where the arrows put it (%d -> %d)" % [hovered, game.menu_index],
		moved != hovered and game.menu_index == moved)
	press(game, KEY_LEFT)
	for _i in range(3): game.follow_pointer(card)
	check("and left walks back the same way (%d)" % game.menu_index, game.menu_index == hovered)
	game.free()

# A PS4 pad has to reach everything a keyboard can, and the prompts have to
# name whichever device is actually in the player's hands.
func test_controller() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.profile.persist = false

	var bound := 0
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion or event is InputEventJoypadButton: bound += 1
	# Four actions, a stick axis and a d-pad button each. The InputMap is global
	# and this suite builds many games, so a count over eight means the binding
	# is being stapled on again per instance.
	check("the pad drives the movement actions (%d events)" % bound, bound == 8)

	game.state = "settings"
	pad_press(game, JOY_BUTTON_DPAD_DOWN)
	check("the d-pad walks a menu (%d)" % game.menu_index, game.menu_index == 1)
	game.menu_index = game.menu_items().find("rift")
	var rift_before: bool = game.rift_effects_enabled
	pad_press(game, Gamepad.CROSS)
	check("cross activates the focused row", game.rift_effects_enabled != rift_before)
	pad_press(game, Gamepad.CIRCLE)
	check("circle backs out of a screen (%s)" % game.state, game.state == "title")

	# Options is a dedicated pause, so it reaches the menu from inside a fight
	# without also being the button that backs out of one.
	game.state = "playing"
	pad_press(game, Gamepad.OPTIONS)
	check("options pauses the game (%s)" % game.state, game.state == "paused")
	pad_press(game, Gamepad.OPTIONS)
	check("and unpauses it again (%s)" % game.state, game.state == "playing")

	game.input_device = "keyboard"
	var push := InputEventJoypadMotion.new()
	push.axis = JOY_AXIS_LEFT_X
	push.axis_value = 1.0
	game._input(push)
	check("a stick push switches the prompts to the pad (%s)" % game.input_device, game.input_device == "pad")
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.1
	game.input_device = "keyboard"
	game._input(drift)
	check("a resting stick does not (%s)" % game.input_device, game.input_device == "keyboard")
	var key := InputEventKey.new()
	key.keycode = KEY_UP
	key.pressed = true
	game.input_device = "pad"
	game._input(key)
	check("and a key switches them back (%s)" % game.input_device, game.input_device == "keyboard")

	# The cursor gets out of the way when a pad takes over. This also has to stop
	# sync_hover: the OS mouse stays parked where it was left, and syncing from
	# it would drag the menu cursor back onto that row every frame.
	game.input_device = "keyboard"
	game.state = "settings"
	game.menu_hover = "fullscreen"
	pad_press(game, JOY_BUTTON_DPAD_DOWN)
	# Input.mouse_mode itself cannot be asserted here: the headless display
	# server discards the write and always reads back VISIBLE. So this checks the
	# predicate that drives it, which is also what gates the hover sync -- the
	# two cannot disagree about who is in control.
	check("a pad stands the mouse down (%s)" % game.input_device,
		game.input_device == "pad" and not game.mouse_active())
	check("and drops the stale hover (%s)" % game.menu_hover, game.menu_hover == "")

	var jitter := InputEventMouseMotion.new()
	jitter.relative = Vector2(0.6, 0.0)
	game._input(jitter)
	check("jitter does not bring the cursor back (%s)" % game.input_device, game.input_device == "pad")
	var moved := InputEventMouseMotion.new()
	moved.relative = Vector2(14.0, 5.0)
	game._input(moved)
	check("but a real movement hands it back (%s)" % game.input_device,
		game.input_device == "keyboard" and game.mouse_active())

	# every prompt the UI can draw resolves to a glyph, on either brand of pad
	var missing: Array[String] = []
	for verb in ["confirm", "back", "alt", "special", "pause"]:
		if Gamepad.glyph(game.ui.pad_button(String(verb))) == "": missing.append(String(verb))
	check("every prompt has a button glyph (%s)" % ("all present" if missing.is_empty() else str(missing)), missing.is_empty())
	check("an unplugged pad still names its buttons (%s)" % Gamepad.brand(), Gamepad.brand() != "")
	game.state = "title"
	game.free()

# Leaving a run mid-way pays no coins at all, unlike dying, so it is worth one
# question -- and the question has to default to the harmless answer.
func test_quit_confirmation() -> void:
	var game = await fresh_game()
	game.state = "paused"
	game.handle_menu_action("menu")
	check("main menu asks before it leaves (%s)" % game.state, game.state == "confirm_quit")
	check("and opens on the safe answer (%s)" % game.focused_action(), game.focused_action() == "keep_playing")
	press(game, KEY_ENTER)
	check("so a reflexive enter keeps the run (%s)" % game.state, game.state == "paused")

	game.handle_menu_action("menu")
	press(game, KEY_ESCAPE)
	check("escape keeps the run too (%s)" % game.state, game.state == "paused")

	game.handle_menu_action("menu")
	var rows: Array[String] = game.menu_items()
	var matched := true
	for i in range(rows.size()):
		if game.ui.menu_action_at(game.ui.confirm_row_rect(i).get_center()) != rows[i]: matched = false
	check("both answers hit-test to their own action", matched)
	click(game, game.ui.confirm_row_rect(rows.find("quit_run")).get_center())
	check("and leaving actually leaves (%s)" % game.state, game.state == "title")

	# the pause screen's own Q shortcut has to go through the same gate
	game.state = "paused"
	press(game, KEY_Q)
	check("the Q shortcut asks as well (%s)" % game.state, game.state == "confirm_quit")
	game.free()

# A volume bar that only moved in fixed steps was not a slider.
func test_slider_sweeping() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.profile.persist = false
	game.state = "settings"
	game.menu_index = game.menu_items().find("sfx")
	var bar: Rect2 = game.ui.settings_bar_rect(0)

	# pressing a bar grabs it, and the mouse then drags it
	click(game, Vector2(bar.position.x + bar.size.x * 0.2, bar.get_center().y))
	check("pressing a bar starts a drag (%s)" % game.dragging, game.dragging == "sfx")
	var stops: Array[float] = []
	for ratio in [0.4, 0.6, 0.85]:
		move_mouse(game, Vector2(bar.position.x + bar.size.x * float(ratio), bar.get_center().y))
		stops.append(game.audio.volume)
	check("dragging follows the mouse (%s)" % str(stops),
		stops[0] < stops[1] and stops[1] < stops[2] and absf(stops[2] - 0.85) < 0.06)
	release_mouse(game)
	check("releasing lets go (%s)" % game.dragging, game.dragging == "")
	move_mouse(game, Vector2(bar.position.x, bar.get_center().y))
	check("and the bar stops following (%.2f)" % game.audio.volume, game.audio.volume > 0.5)

	# holding a direction sweeps continuously rather than stepping
	game.audio.set_volume(0.4)
	Input.action_press("move_right")
	var swept: bool = game.poll_slider(0.25)
	Input.action_release("move_right")
	check("holding a direction sweeps the bar (0.40 -> %.2f)" % game.audio.volume,
		swept and game.audio.volume > 0.55)
	game.audio.set_volume(0.4)
	check("and releasing it stops the sweep", not game.poll_slider(0.25) and is_equal_approx(game.audio.volume, 0.4))

	# a tap is a fine nudge, not a tenth of the range
	press(game, KEY_RIGHT)
	var nudge: float = game.audio.volume - 0.4
	check("one tap is a fine nudge (%.3f)" % nudge, nudge > 0.0 and nudge <= 0.06)

	# the profile is written when the sweep stops, not once per frame of it
	check("a moved slider is pending a write", game.slider_dirty)
	await step(2)
	check("and it is flushed once the sweep ends (%.2f)" % game.profile.level("sfx_volume"),
		not game.slider_dirty and absf(game.profile.level("sfx_volume") - game.audio.volume) < 0.01)
	game.free()

# A pinned offer survives a reroll, which is what makes rerolling a decision
# rather than a gamble on losing the one good thing on the board.
func test_pinning_an_offer() -> void:
	var game = await fresh_game()
	var s = game.session
	s.finish_wave()
	game.state = "shop"
	s.materials = 100000
	var board: Shop = s.shop
	check("nothing is pinned on a fresh board", not board.is_locked(0) and board.has_unlocked_offer())
	var kept: String = String(board.offers[1].id)
	check("the chip hit-tests inside its own card (%s)" % game.ui.menu_action_at(game.ui.card_lock_rect(1).get_center()),
		game.ui.menu_action_at(game.ui.card_lock_rect(1).get_center()) == "lock_1")
	check("and the rest of the card still buys",
		game.ui.menu_action_at(game.ui.card_rect(1).position + Vector2(30, 60)) == "buy_1")

	click(game, game.ui.card_lock_rect(1).get_center())
	check("clicking it pins that offer", board.is_locked(1))
	var changed := 0
	for i in range(6):
		s.reroll_shop(0)
		if String(board.offers[1].id) != kept: changed += 1
	check("a pinned offer survives every reroll (%d changes in 6)" % changed, changed == 0)
	check("while the others are replaced", not board.offers[0].is_empty())

	# The chip is clickable but deliberately NOT on the cursor's path: a pad
	# pins with Square from anywhere on the card, so stopping the cursor on a
	# tiny chip between every two cards is a step that buys nothing.
	check("the pin chip is off the cursor's path", not game.menu_items().has("lock_1"))
	check("but the mouse can still hit it",
		game.ui.menu_action_at(game.ui.card_lock_rect(1).get_center()) == "lock_1")
	# A pad should not have to walk the cursor onto the chip: Square pins
	# whatever offer the cursor is on, from the card or from the chip itself.
	game.set_cursor(0, game.menu_items().find("buy_3"))
	check("the cursor on a card knows which offer it is on", game.focused_offer(0) == 3)
	pad_press(game, Gamepad.SQUARE)
	check("square pins the offer under the cursor", board.is_locked(3))
	# Walking the cards must not stop anywhere between them.
	var stops: Array = []
	game.set_cursor(0, 0)
	for step_i in range(4):
		stops.append(game.focused_action())
		game.handle_verb("nav_right")
	var only_cards := true
	for at in stops:
		if not String(at).begins_with("buy_"): only_cards = false
	check("and walking the row visits only cards (%s)" % str(stops), only_cards)
	# Put it back where the next assertion expects it -- walking the row above
	# deliberately moved the cursor.
	game.set_cursor(0, game.menu_items().find("buy_3"))
	pad_press(game, Gamepad.SQUARE)
	check("and unpins it again", not board.is_locked(3))
	# Triangle rerolls, so it is not buried behind the cursor either.
	var spun: String = String(board.offers[0].id)
	var moved := false
	for i in range(6):
		pad_press(game, Gamepad.TRIANGLE)
		if String(board.offers[0].id) != spun: moved = true
	check("triangle rerolls the board", moved)
	# and the shoulder leaves, without hunting for NEXT WAVE
	game.state = "shop"
	var wave: int = s.round_number
	pad_press(game, Gamepad.R1)
	check("the shoulder starts the next wave (%s)" % game.state,
		game.state == "playing" and s.round_number == wave + 1)
	game.state = "shop"
	# pinning the whole board and paying to respin it changes nothing, so it is
	# refused rather than quietly taking the materials
	for i in range(Shop.SLOTS): board.locked[i] = true
	check("a fully pinned board cannot be rerolled", not board.has_unlocked_offer() and not s.reroll_shop(0))
	# buying a pinned offer releases the pin, or the empty slot would persist
	board.locked[1] = true
	s.buy(1, 0)
	check("buying a pinned offer releases it", not board.is_locked(1))
	# and a pin survives into the next wave's board: saving up for something you
	# cannot afford yet is the reason to pin it in the first place
	board.locked[2] = true
	var saved: String = String(board.offers[2].id)
	s.finish_wave()
	check("a pin survives into the next wave (%s)" % board.offers[2].id,
		board.is_locked(2) and String(board.offers[2].id) == saved)
	check("while the rest of the board is new", board.has_unlocked_offer())
	game.free()

# Everything under GameSession lives in session space, and the session is scaled
# and offset so the oversized arena lands on its view. An emitter that hands out
# a *global* position has it transformed a second time when it lands on another
# node's local position -- which put enemy bullets, drops, damage numbers and
# blasts a growing distance from where they happened. It was invisible for as
# long as the session sat at identity, and appeared the moment the arena grew.
func test_spawns_land_where_they_happened() -> void:
	var game = await fresh_game()
	var s = game.session
	clear_field(s)
	s.round_phase = "shop"
	# Far from the origin, because the error grows with distance from it.
	var far := Arena.BOUNDS.end - Vector2(240.0, 240.0)
	var mob = s.spawn_enemy(EnemyCatalog.all()[0], far, false)
	check("the session is genuinely transformed (%s vs %s)" % [mob.global_position.round(), mob.position.round()],
		not mob.global_position.is_equal_approx(mob.position))

	var reported := [Vector2.ZERO]
	mob.damaged.connect(func(at: Vector2, amount: float, crit: bool) -> void: reported[0] = at)
	mob.take_damage(1.0)
	check("an enemy reports where it is in session space (%s vs %s)" % [reported[0].round(), mob.position.round()],
		reported[0].is_equal_approx(mob.position))

	var landed := [Vector2.ZERO]
	mob.wants_shot.connect(func(from: Vector2, dir: Vector2, dmg: float, speed: float) -> void: landed[0] = from)
	mob.wants_shot.emit(mob.position, Vector2.RIGHT, 5.0, 300.0)
	s.on_enemy_shot(landed[0], Vector2.RIGHT, 5.0, 300.0)
	var bullet = s.shots.get_child(s.shots.get_child_count() - 1)
	check("a bullet leaves the body that fired it (%.0fpx)" % bullet.position.distance_to(mob.position),
		bullet.position.distance_to(mob.position) < 2.0)

	mob.take_damage(mob.max_hp * 2.0)
	await step(2)
	var drop = s.pickups.get_child(s.pickups.get_child_count() - 1)
	check("and a drop lands where the enemy died (%.0fpx)" % drop.position.distance_to(far),
		drop.position.distance_to(far) < 40.0)
	game.free()

# --- co-op: two players, one arena -------------------------------------------

# CO-OP opens a join screen, not a run: hold to join, pick a survivor each, pick
# a starting weapon each, and only then does anything start.
func test_coop_lobby() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.profile.persist = false
	# Pinned, or the test would pass or fail depending on what the machine it
	# runs on happens to have unlocked.
	game.profile.data.unlocked_characters = [0, 1, 2]
	game.profile.data.unlocked_guns = [0, 1]

	game.handle_menu_action("coop")
	check("CO-OP opens the lobby rather than a run (%s)" % game.state, game.state == "lobby")
	check("with nobody joined yet (%d)" % game.lobby.count(), game.lobby.count() == 0)
	# The lobby is reachable straight off the title, so it draws with no run
	# behind it. Everything it reads has to cope with there being no survivors
	# at all -- the weapon panel used to ask for survivor 0 and index -1.
	check("and nothing to read a survivor from",
		game.session.seat(0) == null and game.session.class_counts(null).is_empty())

	# joining is a hold, so a tap must not sign anybody up
	game.lobby.tick_join("kb", 0.1, true)
	check("a tap does not join (%.0f%% held)" % (game.lobby.hold_ratio(0) * 100.0),
		not bool(game.lobby.joined[0]) and game.lobby.hold_ratio(0) > 0.0)
	game.lobby.tick_join("kb", 0.05, false)
	check("and letting go loses the progress", is_zero_approx(game.lobby.hold_ratio(0)))
	check("holding it through joins",
		game.lobby.tick_join("kb", Lobby.HOLD_TIME, true) == 0 and bool(game.lobby.joined[0]))

	# one player cannot take a co-op run out on their own
	game.lobby.locked[0] = true
	game.advance_lobby()
	check("one player alone cannot move on (%s)" % game.lobby.stage, game.lobby.stage == "character")
	game.lobby.locked[0] = false

	game.lobby.tick_join("pad0", Lobby.HOLD_TIME, true)
	check("the second player joins from the same screen", game.lobby.everyone_in())

	# each seat steers its own row
	game.handle_verb("nav_right", 1)
	check("the two seats pick separately (%d / %d)" % [game.lobby.character[0], game.lobby.character[1]],
		int(game.lobby.character[0]) != int(game.lobby.character[1]))
	var owned: Array = game.profile.unlocked_guns_or_characters("characters")
	var strayed := false
	for i in range(12):
		game.handle_verb("nav_right", 1)
		if not (int(game.lobby.character[1]) in owned): strayed = true
	check("and never onto a character this profile does not own (%s)" % str(owned), not strayed)

	# a locked seat stops moving, so a confirmed pick stays put
	var settled: int = int(game.lobby.character[1])
	game.handle_verb("confirm", 1)
	game.handle_verb("nav_right", 1)
	check("a locked pick cannot drift (%d)" % game.lobby.character[1], int(game.lobby.character[1]) == settled)

	var wanted_a: int = int(game.lobby.character[0])
	var wanted_b: int = settled
	game.handle_verb("confirm", 0)
	check("both locked moves on to the weapons (%s)" % game.lobby.stage, game.lobby.stage == "weapon")
	check("and unlocks them for the new choice", not bool(game.lobby.locked[0]) and not bool(game.lobby.locked[1]))
	check("still in the lobby, not in a run (%s)" % game.state, game.state == "lobby")

	# back undoes the stage rather than leaving the screen
	game.handle_verb("back", 0)
	check("back returns to the survivors (%s)" % game.lobby.stage, game.lobby.stage == "character")
	check("and stays in the lobby (%s)" % game.state, game.state == "lobby")

	# forward again, pick a weapon each, and the last lock starts the run
	game.handle_verb("confirm", 0)
	game.handle_verb("confirm", 1)
	game.handle_verb("nav_right", 0)
	var wanted_gun: int = int(game.lobby.gun[0])
	game.handle_verb("confirm", 0)
	check("one player ready does not start it (%s)" % game.state, game.state == "lobby")
	game.handle_verb("confirm", 1)
	check("both ready starts the run (%s)" % game.state, game.state == "playing")
	check("with two survivors", game.session.seats() == 2)
	check("each as the survivor they picked (%d / %d)" % [game.session.seat(0).character, game.session.seat(1).character],
		game.session.seat(0).character == wanted_a and game.session.seat(1).character == wanted_b)
	var opening: String = String(GunCatalog.get_gun(wanted_gun).weapon)
	check("and holding the weapon they picked (%s)" % game.session.seat(0).weapons[0].id,
		game.session.seat(0).weapons[0].id == opening)
	game.free()

# Seats are handed out in the order people finish holding, and any pair of
# devices is valid. There is no "the keyboard is player one" any more.
func test_lobby_seats_follow_join_order() -> void:
	var game = await fresh_game()
	game.lobby.reset([0], [0])
	# The second pad joins first, so it *is* player one.
	check("the first to finish holding takes seat 0",
		game.lobby.tick_join("pad1", Lobby.HOLD_TIME, true) == 0)
	check("and the next one takes seat 1",
		game.lobby.tick_join("kb", Lobby.HOLD_TIME, true) == 1)
	check("which is the order they are recorded in (%s)" % str(game.lobby.seat_device),
		game.lobby.seat_device[0] == "pad1" and game.lobby.seat_device[1] == "kb")
	# Two pads is as valid a pairing as a pad and a keyboard.
	game.lobby.reset([0], [0])
	game.lobby.tick_join("pad0", Lobby.HOLD_TIME, true)
	game.lobby.tick_join("pad1", Lobby.HOLD_TIME, true)
	check("two controllers can hold both seats (%s)" % str(game.lobby.seat_device),
		game.lobby.seat_device[0] == "pad0" and game.lobby.seat_device[1] == "pad1")
	# And each pad reads its own actions, or one would steer both.
	check("each pad has its own movement actions",
		Controls.actions_for("pad0") != Controls.actions_for("pad1"))
	# The lobby said "PLAYER 1 - KEYBOARD" whatever had actually joined, which
	# is a lie the moment a pad takes seat 0. It names the real device now.
	check("a device names itself (%s / %s / %s)"
		% [Controls.label("kb"), Controls.label("pad0"), Controls.label("pad1")],
		Controls.label("kb") == "KEYBOARD" and Controls.label("pad0") == "CONTROLLER 1"
		and Controls.label("pad1") == "CONTROLLER 2")
	# And one thumb must not fill the bar on both empty seats at once.
	game.lobby.reset([0], [0])
	game.lobby.tick_join("pad0", Lobby.HOLD_TIME * 0.5, true)
	check("only the seat about to be filled shows progress (%.2f / %.2f)"
		% [game.lobby.hold_ratio(0), game.lobby.hold_ratio(1)],
		game.lobby.hold_ratio(0) > 0.0 and is_zero_approx(game.lobby.hold_ratio(1)))
	game.free()

func coop_game() -> Node:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.profile.persist = false
	game.state = "playing"
	game.start_run(true)
	await step(2)
	return game

func test_coop_two_players() -> void:
	var game = await coop_game()
	var s = game.session
	check("co-op puts two survivors in the arena (%d)" % s.seats(), s.seats() == 2)
	# The whole reason Controls exists: on one machine, a shared move action
	# would have each player dragging the other around.
	check("each pinned to its own device (%s / %s)" % [s.seat(0).device, s.seat(1).device],
		s.seat(0).device == "kb" and s.seat(1).device == "pad0")
	check("and the bodies read those devices",
		s.seat(0).player.input_source == "kb" and s.seat(1).player.input_source == "pad0")
	var apart: float = s.seat(0).player.position.distance_to(s.seat(1).player.position)
	check("they start apart, not stacked (%.0fpx)" % apart, apart > 100.0)
	check("with a rack each", not s.seat(1).weapons.is_empty() and s.seat(0).weapons != s.seat(1).weapons)
	check("each device drives its own seat",
		game.seat_for("kb") == 0 and game.seat_for("pad0") == 1)

	# an enemy goes for whoever is closest, and never for somebody who is down
	clear_field(s)
	var mob = s.spawn_enemy(EnemyCatalog.all()[0], s.seat(1).player.position + Vector2(50, 0), false)
	mob.max_hp = 1000000.0
	mob.hp = mob.max_hp
	check("an enemy goes for the nearer player", mob.closest_target() == s.seat(1).player)
	s.seat(1).downed = true
	s.seat(1).player.set_downed(true)
	check("and never for one who is down", mob.closest_target() == s.seat(0).player)
	game.free()

# Driven through the real actions, because the rest of the co-op tests only
# assert that each seat is *labelled* with a device. That is not the same as a
# key actually moving a body, and the difference was a version where neither
# player could move: the per-device actions were never registered.
func test_coop_movement() -> void:
	var game = await coop_game()
	var s = game.session
	var missing: Array[String] = []
	for action in Controls.KEYBOARD + Controls.PADS[0] + Controls.PADS[1]:
		if not InputMap.has_action(String(action)): missing.append(String(action))
	check("the per-device actions exist (%s)" % ("all present" if missing.is_empty() else str(missing)),
		missing.is_empty())

	clear_field(s)
	# Parked in the shop phase so nothing spawns and shoves the two of them.
	s.round_phase = "shop"
	var one: Vector2 = s.seat(0).player.position
	var two: Vector2 = s.seat(1).player.position
	Input.action_press("kb_right")
	await step(8)
	Input.action_release("kb_right")
	check("the keyboard moves player one (%.0fpx)" % s.seat(0).player.position.distance_to(one),
		s.seat(0).player.position.distance_to(one) > 20.0)
	check("and leaves player two where they were (%.0fpx)" % s.seat(1).player.position.distance_to(two),
		s.seat(1).player.position.distance_to(two) < 1.0)

	one = s.seat(0).player.position
	two = s.seat(1).player.position
	Input.action_press("pad0_left")
	await step(8)
	Input.action_release("pad0_left")
	check("the pad moves player two (%.0fpx)" % s.seat(1).player.position.distance_to(two),
		s.seat(1).player.position.distance_to(two) > 20.0)
	check("and leaves player one where they were (%.0fpx)" % s.seat(0).player.position.distance_to(one),
		s.seat(0).player.position.distance_to(one) < 1.0)
	game.free()

# Nobody loses the run alone: going down is a round out, not the end.
func test_coop_down_and_revive() -> void:
	var game = await coop_game()
	var s = game.session
	var ended := [false]
	s.run_ended.connect(func() -> void: ended[0] = true)

	s.seat(0).player.hurt(1000000.0)
	await step(2)
	check("a killed player goes down, not out (%s)" % str(ended[0]), s.seat(0).downed and not ended[0])
	check("and stops being something enemies can hit", s.seat(0).player.collision_layer == 0)
	check("while the other is still standing", s.seat(1).alive())

	s.finish_wave()
	s.begin_round()
	check("surviving the wave revives them (%.0f hp)" % s.seat(0).player.hp,
		not s.seat(0).downed and s.seat(0).player.alive and s.seat(0).player.hp > 0.0)
	check("but not at full health, or going down would be free",
		s.seat(0).player.hp < s.seat(0).player.max_hp)
	# The collision change is deferred -- set_downed is reached from hurt(),
	# inside a physics callback -- so it lands on the next frame, not this one.
	await step(1)
	check("and they can be hit again", s.seat(0).player.collision_layer != 0)

	s.seat(0).player.hurt(1000000.0)
	await step(2)
	check("one down is still not the end", not ended[0])
	s.seat(1).player.hurt(1000000.0)
	await step(2)
	check("the run ends only when both are down", ended[0])
	game.free()

# Each player earns and spends their own, which is what makes spreading out to
# collect worth doing.
func test_coop_separate_economies() -> void:
	var game = await coop_game()
	var s = game.session
	s.on_pickup_collected(50, Pickup.KIND_MATERIAL, s.seat(1))
	check("materials go to whoever collected them (%d / %d)" % [s.seat(0).materials, s.seat(1).materials],
		s.seat(0).materials == 0 and s.seat(1).materials == 50)
	check("and so does the XP (%d / %d)" % [s.seat(0).xp, s.seat(1).xp], s.seat(0).xp == 0 and s.seat(1).xp > 0)

	s.finish_wave()
	check("each player gets their own board",
		s.seat(0).shop != s.seat(1).shop and not s.seat(1).shop.offers.is_empty())
	s.seat(0).materials = 500
	var before: int = s.seat(1).materials
	s.buy(0, 0)
	check("buying spends only that player's materials (%d unchanged)" % s.seat(1).materials,
		s.seat(0).materials < 500 and s.seat(1).materials == before)

	# one player leaving the shop must not drag the other out mid-purchase
	game.state = "shop"
	var wave: int = s.round_number
	game.leave_shop(0)
	check("one ready does not start the wave (%s)" % game.state,
		game.state == "shop" and s.round_number == wave)
	game.leave_shop(1)
	check("both ready does (%s, wave %d)" % [game.state, s.round_number],
		game.state == "playing" and s.round_number == wave + 1)

	# both can level on the same pickup, and the overlay waits for both
	s.seat(0).upgrades = UpgradeCatalog.roll_choices(s.rng, 1, 0.0)
	s.seat(1).upgrades = UpgradeCatalog.roll_choices(s.rng, 1, 0.0)
	game.state = "level_up"
	game.choose_upgrade(0, 0)
	check("the overlay waits for the other player (%s)" % game.state, game.state == "level_up")
	game.choose_upgrade(0, 1)
	check("and closes once both have chosen (%s)" % game.state, game.state != "level_up")
	check("each grant landed on its own sheet",
		not s.seat(0).upgrade_totals.is_empty() and not s.seat(1).upgrade_totals.is_empty())
	game.free()

# The arena is shared; only the two screens that ask a player to choose are not.
func test_coop_split_screen() -> void:
	var game = await coop_game()
	var s = game.session
	s.finish_wave()
	game.state = "shop"

	game.ui.use_pane(0)
	var left: Rect2 = game.ui.card_rect(0)
	var left_slots: Rect2 = game.ui.slot_rect(0)
	game.ui.use_pane(1)
	var right: Rect2 = game.ui.card_rect(0)
	check("each board sits on its own half (%.0f / %.0f)" % [left.get_center().x, right.get_center().x],
		left.end.x <= GameUI.SCREEN.x * 0.5 and right.position.x >= GameUI.SCREEN.x * 0.5)
	check("and stays inside it", right.end.x <= GameUI.SCREEN.x and left.position.x >= 0.0)
	# four offers still fit, wrapped rather than shrunk
	game.ui.use_pane(0)
	check("the offers wrap into a grid at full size (%s)" % str(game.ui.card_rect(3).position),
		game.ui.card_rect(3).position.y > game.ui.card_rect(0).position.y
		and game.ui.card_rect(0).size == GameUI.CARD_SIZE)
	check("and the weapon slots wrap too",
		game.ui.slot_rect(5).position.y > left_slots.position.y)
	# each half answers to its own cursor
	game.set_cursor(0, game.menu_items(0).find("reroll"))
	game.set_cursor(1, game.menu_items(1).find("go"))
	check("the two cursors are independent",
		game.ui.is_focused("reroll", 0) and not game.ui.is_focused("reroll", 1)
		and game.ui.is_focused("go", 1))
	# and the solo layout is untouched
	game.coop = false
	game.ui.use_pane(0)
	check("solo still lays four offers across the display",
		is_equal_approx(game.ui.card_rect(0).position.y, game.ui.card_rect(3).position.y))
	game.free()

# The lookups are on the hot path: Weapon.def() goes through get_weapon on every
# draw and every shot. Rebuilding the catalog per call cost 21us a lookup and
# 0.72ms for one pass over a six-weapon rack; built once it is 0.045ms. If these
# stop handing back the same object, something has gone back to rebuilding.
func test_catalogs_are_built_once() -> void:
	check("the weapon catalog is built once", is_same(WeaponCatalog.all(), WeaponCatalog.all()))
	check("and looked up by id, not searched", is_same(WeaponCatalog.get_weapon("rifle"), WeaponCatalog.get_weapon("rifle")))
	check("the item catalog too", is_same(ItemCatalog.all(), ItemCatalog.all())
		and is_same(ItemCatalog.get_item("focus_lens"), ItemCatalog.get_item("focus_lens")))
	check("and the enemies, bosses included", is_same(EnemyCatalog.all(), EnemyCatalog.all())
		and is_same(EnemyCatalog.bosses(), EnemyCatalog.bosses()))
	check("and the characters, guns and level-up pool",
		is_same(CharacterCatalog.all(), CharacterCatalog.all())
		and is_same(GunCatalog.all(), GunCatalog.all())
		and is_same(UpgradeCatalog.pool(), UpgradeCatalog.pool()))
	# A shared entry is only safe while nothing writes to one.
	var before: float = float(WeaponCatalog.get_weapon("rifle").damage)
	var offers := WeaponCatalog.of_kinds([])
	check("a filtered view does not disturb the catalog (%.1f)" % before,
		is_equal_approx(float(WeaponCatalog.get_weapon("rifle").damage), before) and not offers.is_empty())

func test_shop_prices_climb() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var shop := Shop.new()
	var early := 0
	var late := 0
	for i in range(40):
		shop.roll(rng, 1, 0.0)
		for offer in shop.offers: early += int(offer.price)
		shop.roll(rng, 15, 0.0)
		for offer in shop.offers: late += int(offer.price)
	check("a late shop costs far more than an early one (%d vs %d)" % [late, early], float(late) > float(early) * 2.0)
	check("prices still start low (%d for four offers at wave 1)" % (early / 40), early / 40 < 120)

# --- phase 6: weapon archetypes and characters that force a build ------------

# Clears the arena AND unequips the starting weapon, so an archetype test is
# measuring only the archetype it drives by hand.
func clear_field(s) -> void:
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	for shot in s.shots.get_children():
		s.shots.remove_child(shot)
		shot.queue_free()
	var empty: Array[Weapon] = []
	s.weapons = empty
	s.round_phase = "cleanup"

func tough_enemy(s, at: Vector2):
	var mob = s.spawn_enemy(EnemyCatalog.all()[0], at, false)
	mob.max_hp = 1000000.0
	mob.hp = mob.max_hp
	return mob

func test_melee_archetype() -> void:
	var game = await fresh_game()
	var s = game.session
	clear_field(s)
	var blade := Weapon.new("blade", 1)
	var reach: float = blade.attack_range(s.stats)
	var front = tough_enemy(s, s.player.position + Vector2(reach * 0.6, 0))
	var behind = tough_enemy(s, s.player.position + Vector2(-reach * 0.6, 0))
	var far = tough_enemy(s, s.player.position + Vector2(reach * 3.0, 0))
	await step(1)
	var front_hp: float = front.hp
	var behind_hp: float = behind.hp
	var far_hp: float = far.hp
	var was: Vector2 = front.position
	s.swing_melee(s.me, blade, front, reach)
	check("a melee swing hits what is in front (%.0f -> %.0f)" % [front_hp, front.hp], front.hp < front_hp)
	check("it spares what is behind", is_equal_approx(behind.hp, behind_hp))
	check("and what is out of reach", is_equal_approx(far.hp, far_hp))
	check("it spawns a visible swing", s.get_node_or_null("MeleeSwing") != null)
	await step(8)
	check("it knocks the target back (%.0fpx)" % front.position.distance_to(was), front.position.distance_to(was) > 10.0)
	check("melee fires no projectile", s.shots.get_child_count() == 0)
	game.free()

func test_orbital_archetype() -> void:
	var game = await fresh_game()
	var s = game.session
	clear_field(s)
	var orb := Weapon.new("orb", 1)
	var radius: float = float(orb.def().orbit_radius)
	var mob = tough_enemy(s, s.player.position + Vector2(radius, 0))
	await step(1)
	var before: float = mob.hp
	var angle_before: float = orb.orbit
	for i in range(40):
		s.tick_orbital(s.me, orb, 0.05)
	check("the orbital travels round (%.2f rad)" % orb.orbit, orb.orbit > angle_before)
	check("it grinds what it passes over (%.0f -> %.0f)" % [before, mob.hp], mob.hp < before)
	check("and fires no projectile", s.shots.get_child_count() == 0)
	game.free()

func test_homing_archetype() -> void:
	var game = await fresh_game()
	var s = game.session
	clear_field(s)
	var mob = tough_enemy(s, s.player.position + Vector2(0, -300))
	await step(1)
	# fired sideways, so only steering can bring it round
	var shot = s.add_shot(s.me, Vector2.RIGHT, 300.0, 3.0, 5.0, Color.WHITE, 0)
	shot.chase(mob, 7.0)
	var straight = s.add_shot(s.me, Vector2.RIGHT, 300.0, 3.0, 5.0, Color.WHITE, 0)
	await step(14)
	if is_instance_valid(shot) and is_instance_valid(straight):
		check("a homing shot turns toward its target (%.2f vs %.2f)" % [shot.velocity.angle(), straight.velocity.angle()], shot.velocity.y < straight.velocity.y - 20.0)
	else:
		check("a homing shot turns toward its target", false)
	check("a plain shot does not steer", not is_instance_valid(straight) or is_equal_approx(straight.velocity.y, 0.0))
	game.free()

func test_character_constraints() -> void:
	var game = await fresh_game()
	var s = game.session
	var blade_dancer := -1
	var siege := -1
	for i in range(CharacterCatalog.all().size()):
		var c := CharacterCatalog.get_character(i)
		if not (c.kinds as Array).is_empty(): blade_dancer = i
		if int(c.slots) < 6: siege = i
	check("there is a kind-restricted character", blade_dancer >= 0)
	check("there is a fewer-slots character", siege >= 0)

	# a melee-only character cannot start with, be offered, or buy a gun
	game.selected_character = blade_dancer
	game.selected_gun = 0
	game.start_run()
	await step(2)
	s = game.session
	check("a melee-only character starts with a melee weapon (%s)" % s.weapons[0].id, s.weapons[0].kind() == "melee")
	s.finish_wave()
	var offered_kinds: Array[String] = []
	for i in range(200):
		s.shop.roll(s.rng, 6, 0.0)
		for offer in s.shop.offers:
			if offer.kind == "weapon": offered_kinds.append(WeaponCatalog.get_weapon(String(offer.id)).kind)
	check("the shop only offers weapons it can hold (%d rolls)" % offered_kinds.size(), offered_kinds.size() > 0 and not offered_kinds.has("ranged"))
	s.materials = 9999
	var gun: Dictionary = {"kind":"weapon", "id":"rifle", "tier":1, "name":"x", "text":"", "color":Color.WHITE, "price":1}
	s.shop.offers[0] = gun
	check("buying a forbidden weapon is refused", not s.buy(0))

	# fewer slots is actually enforced
	game.selected_character = siege
	game.start_run()
	await step(2)
	s = game.session
	check("a restricted character has fewer slots (%d)" % s.weapon_slots, s.weapon_slots < GameSession.MAX_WEAPONS)
	var rack: Array[Weapon] = []
	for i in range(s.weapon_slots):
		rack.append(Weapon.new(WeaponCatalog.all()[i].id, 1))
	s.weapons = rack
	s.finish_wave()
	s.materials = 9999
	var extra: Dictionary = {"kind":"weapon", "id":"lance", "tier":1, "name":"x", "text":"", "color":Color.WHITE, "price":1}
	s.shop.offers[0] = extra
	check("a full rack refuses another weapon", not s.buy(0))
	game.free()

# Synergy items scale off the rest of the build, so the sheet has to be rebuilt
# rather than added to -- selling a weapon must take the bonus with it.
func test_item_synergies() -> void:
	var game = await fresh_game()
	var s = game.session
	var rack: Array[Weapon] = [Weapon.new("pistol", 1)]
	s.weapons = rack
	s.rebuild_stats()
	var bare: float = s.stats.get_stat("damage")
	s.add_item("arsenal_link")
	var one: float = s.stats.get_stat("damage")
	check("a per-weapon item pays out on what you hold (%.0f -> %.0f)" % [bare, one], one > bare)
	s.add_weapon("smg", 1)
	var two: float = s.stats.get_stat("damage")
	check("buying a weapon raises it (%.0f -> %.0f)" % [one, two], two > one)
	s.sell_weapon(1)
	check("selling one takes the bonus back (%.0f -> %.0f)" % [two, s.stats.get_stat("damage")], is_equal_approx(s.stats.get_stat("damage"), one))

	# level-up grants must survive the rebuild an item purchase triggers
	var granted: Dictionary = {"damage": 25.0}
	var choice: Array[Dictionary] = [{"title":"T", "rarity":"COMMON", "stats":granted}]
	s.upgrades = choice
	s.choose_upgrade(0)
	var after_upgrade: float = s.stats.get_stat("damage")
	check("a level-up grant lands (%.0f)" % after_upgrade, after_upgrade > one)
	s.add_item("focus_lens")
	check("and survives an item purchase rebuilding the sheet", s.stats.get_stat("damage") > after_upgrade)

	# empty slots version moves the other way
	var solo = await fresh_game()
	var t = solo.session
	var single: Array[Weapon] = [Weapon.new("pistol", 1)]
	t.weapons = single
	t.rebuild_stats()
	t.add_item("lone_wolf")
	var lonely: float = t.stats.get_stat("damage")
	t.add_weapon("smg", 1)
	check("an empty-slot item pays less as you fill up (%.0f -> %.0f)" % [lonely, t.stats.get_stat("damage")], t.stats.get_stat("damage") < lonely)
	check("its description names the scaling (%s)" % ItemCatalog.describe(ItemCatalog.get_item("lone_wolf")), "per" in ItemCatalog.describe(ItemCatalog.get_item("lone_wolf")))
	solo.free()
	game.free()

func test_enemy_roster() -> void:
	var game = await fresh_game()
	var s = game.session
	clear_field(s)

	# a splitter leaves children behind
	var before: int = s.actors.get_child_count()
	s.on_enemy_died(Arena.BOUNDS.get_center(), 1, false, EnemyCatalog.get_enemy("splitter"))
	await step(3)
	check("a splitter leaves children behind (%d)" % (s.actors.get_child_count() - before), s.actors.get_child_count() > before)
	# and they land inside the walls even when it dies against one
	clear_field(s)
	s.on_enemy_died(Arena.BOUNDS.position - Vector2(400, 400), 1, false, EnemyCatalog.get_enemy("splitter"))
	await step(3)
	var outside := 0
	for child in s.actors.get_children():
		if not Arena.BOUNDS.has_point(child.position): outside += 1
	check("splits land inside the arena (%d outside)" % outside, outside == 0)

	# a bloater hurts you if you are standing on it, and not from across the map
	clear_field(s)
	var bloater := EnemyCatalog.get_enemy("bloater")
	s.player.hp = s.player.max_hp
	s.on_enemy_died(s.player.position + Vector2(1200, 0), 1, false, bloater)
	check("a distant explosion is harmless (%.0f hp)" % s.player.hp, is_equal_approx(s.player.hp, s.player.max_hp))
	# The blast is fused rather than instant. The player's own gun is what kills
	# a bloater, so damage on the death frame arrives with nothing to attribute
	# it to -- the warning ring is the whole point and it needs time to be seen.
	s.round_phase = "combat"
	s.round_time_left = 99.0
	s.player.hp = s.player.max_hp
	s.on_enemy_died(s.player.position + Vector2(20, 0), 1, false, bloater)
	check("the blast does not land on the death frame (%.0f hp)" % s.player.hp,
		is_equal_approx(s.player.hp, s.player.max_hp))
	s.tick(Balance.BLOAT_FUSE * 0.5)
	check("nor half way through the fuse (%.0f hp)" % s.player.hp,
		is_equal_approx(s.player.hp, s.player.max_hp))
	s.tick(Balance.BLOAT_FUSE)
	check("one at your feet hurts once the fuse burns down (%.0f hp)" % s.player.hp,
		s.player.hp < s.player.max_hp)
	# A fuse still burning holds the wave open, or the last bloater of a wave
	# opens the shop and then blows up somebody who is buying things.
	clear_field(s)
	s.round_phase = "cleanup"
	s.on_enemy_died(s.player.position + Vector2(1200, 0), 1, false, bloater)
	s.tick(Balance.BLOAT_FUSE * 0.5)
	check("a burning fuse holds the wave open (%s)" % s.round_phase, s.round_phase == "cleanup")

	# a charger winds up before it dashes
	clear_field(s)
	var charger = s.spawn_enemy(EnemyCatalog.get_enemy("charger"), s.player.position + Vector2(200, 0), false)
	charger.max_hp = 1000000.0
	charger.hp = charger.max_hp
	await step(6)
	check("a charger telegraphs before it moves (%s)" % charger.charge_state, charger.charge_state == "windup")
	var held: Vector2 = charger.position
	await step(4)
	check("and holds still while winding up (%.1fpx)" % charger.position.distance_to(held), charger.position.distance_to(held) < 4.0)
	await step(60)
	check("then it commits to a dash (%s)" % charger.charge_state, charger.charge_state != "windup")

	# bosses alternate
	check("wave 5 and wave 10 are different bosses (%s / %s)" % [EnemyCatalog.boss(5).id, EnemyCatalog.boss(10).id], EnemyCatalog.boss(5).id != EnemyCatalog.boss(10).id)
	check("the ladder wraps rather than running out", EnemyCatalog.boss(15).id == EnemyCatalog.boss(5).id)
	# and every enemy the spawner can pick has a real texture
	var missing: Array[String] = []
	for def in EnemyCatalog.all() + EnemyCatalog.bosses():
		if not ResourceLoader.exists("res://assets/sprites/%s.png" % def.texture): missing.append(String(def.id))
	check("every enemy has a sprite (%s)" % ("all present" if missing.is_empty() else str(missing)), missing.is_empty())
	game.free()

# Weapon classes: holding several of one pays an escalating bonus, and the shop
# leans toward what you already hold so a run converges on a strategy.
func test_weapon_classes() -> void:
	var game = await fresh_game()
	var s = game.session
	var solo: Array[Weapon] = [Weapon.new("pistol", 1)]
	s.weapons = solo
	s.rebuild_stats()
	var one: float = s.stats.get_stat("attack_range")
	check("one weapon of a class pays nothing (%.0f)" % one, s.class_steps(1) == 0)
	s.add_weapon("rifle", 1)
	var two: float = s.stats.get_stat("attack_range")
	check("a second of the class starts the bonus (%.0f -> %.0f)" % [one, two], two > one)
	s.add_weapon("smg", 1)
	check("a third raises it again (%.0f)" % s.stats.get_stat("attack_range"), s.stats.get_stat("attack_range") > two)
	s.sell_weapon(0)
	check("selling drops back down (%.0f)" % s.stats.get_stat("attack_range"), s.stats.get_stat("attack_range") < s.stats.get_stat("attack_range") + 1.0 and s.stats.get_stat("attack_range") == two)
	check("the bonus is capped (%d steps at 20 held)" % s.class_steps(20), s.class_steps(20) == WeaponCatalog.CLASS_STEP_CAP)

	# a weapon in two classes counts for both
	var dual: Array[Weapon] = [Weapon.new("smg", 1), Weapon.new("blade", 1)]
	s.weapons = dual
	s.rebuild_stats()
	var counts: Dictionary = s.class_counts()
	check("a dual-class weapon counts for both (%s)" % [counts], int(counts.get("swift", 0)) == 2)

	# class bonuses carry a cost, so stacking is a decision
	var costs := 0
	for id in WeaponCatalog.CLASSES:
		for stat in WeaponCatalog.CLASSES[id].per_step:
			if float(WeaponCatalog.CLASSES[id].per_step[stat]) < 0.0: costs += 1
	check("most classes cost you something (%d downsides)" % costs, costs >= 3)

	# the shop leans toward classes already held
	var biased := Shop.new()
	biased.owned_classes = ["arcane"]
	var arcane := 0
	var total := 0
	for i in range(300):
		biased.roll(s.rng, 6, 0.0)
		for offer in biased.offers:
			if offer.kind != "weapon": continue
			total += 1
			if "arcane" in WeaponCatalog.classes_of(String(offer.id)): arcane += 1
	var share := float(arcane) / maxf(1.0, float(total))
	var natural := float(WeaponCatalog.of_kinds([]).filter(func(d): return "arcane" in d.get("classes", [])).size()) / float(WeaponCatalog.all().size())
	check("the shop favours classes you hold (%.0f%% vs %.0f%% by chance)" % [share * 100.0, natural * 100.0], share > natural + 0.1)
	game.free()

extends SceneTree

# Headless integration pass over the node/physics rebuild.
# Run: godot --headless --script res://tests/integration_test.gd

var failures := 0
const EXPECTED_CHECKS := 128
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
	test_every_icon_exists()
	await test_audio_banks()
	test_balance_curve()
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
	await step(1)
	var before: float = target.hp
	s.add_shot(Vector2.RIGHT, 900.0, 1.0, 5.0, Color.WHITE, 0)
	await step(20)
	check("a projectile damages what it hits (%.0f -> %.0f)" % [before, target.hp], is_instance_valid(target) and target.hp < before)
	target.take_damage(99999.0)
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
	check("boss at round 5 is beatable (%.0f hp)" % Balance.boss_hp(5), Balance.boss_hp(5) < 900.0)
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

func test_weapon_combining() -> void:
	var game = await fresh_game()
	var s = game.session
	var rack: Array[Weapon] = [Weapon.new("smg", 1)]
	s.weapons = rack
	s.add_weapon("smg", 1)
	check("two of a kind stay separate (%d)" % s.weapons.size(), s.weapons.size() == 2)
	s.add_weapon("smg", 1)
	check("three of a kind merge into one (%d)" % s.weapons.size(), s.weapons.size() == 1)
	check("the merged weapon is a tier higher (tier %d)" % s.weapons[0].tier, s.weapons[0].tier == 2)
	check("the merged weapon hits harder (%.0f vs %.0f)" % [WeaponCatalog.damage_at("smg", 2), WeaponCatalog.damage_at("smg", 1)], WeaponCatalog.damage_at("smg", 2) > WeaponCatalog.damage_at("smg", 1))
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
	# but a third copy of one already held merges, so it is allowed through
	s.weapons[1] = Weapon.new("pistol", 1)
	var extra: Dictionary = {"kind":"weapon", "id":"pistol", "tier":1, "name":"x", "text":"",
		"color":Color.WHITE, "price":1}
	s.shop.offers[1] = extra
	check("a full rack still accepts a merge", s.buy(1))
	check("and the merge shrank the rack (%d)" % s.weapons.size(), s.weapons.size() < GameSession.MAX_WEAPONS)
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
	check("30 armor halves incoming damage (%.1f)" % stats.damage_taken(100.0), is_equal_approx(stats.damage_taken(100.0), 50.0))
	stats.add("armor", 9970.0)
	check("stacked armor never reaches immunity (%.3f)" % stats.damage_taken(100.0), stats.damage_taken(100.0) > 0.0)
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
	check("dodge is capped well below certainty (%d/400)" % dodged, dodged > 180 and dodged < 290)

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
	var sound_before: bool = game.sound_enabled
	press(game, KEY_ENTER)
	check("enter toggles the focused row", game.sound_enabled != sound_before)
	press(game, KEY_DOWN)
	var rift_before: bool = game.rift_effects_enabled
	press(game, KEY_SPACE)
	check("space works the same as enter", game.rift_effects_enabled != rift_before)
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
	var before: bool = game.rift_effects_enabled
	click(game, game.ui.settings_row_rect(1).get_center())
	check("clicking a row toggles it", game.rift_effects_enabled != before)

	# The mouse and the keyboard cursor must not disagree about the target.
	game.state = "settings"
	game.menu_index = 0
	game.sync_hover(game.ui.settings_row_rect(2).get_center())
	check("hovering moves the keyboard cursor onto that row (%d)" % game.menu_index, game.menu_index == 2 and game.menu_hover == "fullscreen")
	game.sync_hover(Vector2(5, 5))
	check("moving off the rows leaves the cursor where it was (%d)" % game.menu_index, game.menu_index == 2 and game.menu_hover == "")

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
	check("it settles back to nothing (%.1f, %s)" % [s.shake, s.position], is_zero_approx(s.shake) and s.position == Vector2.ZERO)

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
	check("settings default on", profile.setting("sound") and profile.setting("rift_effects"))
	profile.set_setting("sound", false)
	check("a setting sticks in memory", not profile.setting("sound"))
	var reloaded := profile.sanitized({"coins": 5, "sound": false, "fullscreen": true, "max_danger": 3})
	check("settings survive a round trip", reloaded.sound == false and reloaded.fullscreen == true)
	check("max_danger survives (%s)" % reloaded.max_danger, reloaded.max_danger == 3)
	var junk := profile.sanitized({"sound": "yes", "max_danger": 99})
	check("a junk setting falls back to the default", junk.sound == true)
	check("and max_danger is clamped (%s)" % junk.max_danger, junk.max_danger == Balance.DANGER_LEVELS - 1)
	# winning opens the next rung, and only ever upward
	var ladder := ProfileManager.new()
	ladder.persist = false
	check("winning at 0 unlocks 1", ladder.record_victory(0) and ladder.max_danger() == 1)
	check("winning at 0 again changes nothing", not ladder.record_victory(0) and ladder.max_danger() == 1)
	check("winning at 1 unlocks 2", ladder.record_victory(1) and ladder.max_danger() == 2)

# Adding a weapon or item without its icon would otherwise only show up as a
# blank space on a shop card, which is easy to miss.
func test_every_icon_exists() -> void:
	var missing: Array[String] = []
	for def in WeaponCatalog.all():
		if Icons.texture(Icons.WEAPON_PATH % def.id) == null:
			missing.append("weapon:" + String(def.id))
	for def in ItemCatalog.all():
		if Icons.texture(Icons.ITEM_PATH % def.id) == null:
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

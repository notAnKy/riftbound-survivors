extends SceneTree

# Dev tool: plays a short run and writes frames to disk so a change can be
# eyeballed without sitting at the game. Needs a real (non-headless) run.
# Run: godot --path . --script res://tests/screenshot.gd -- <output_dir>

var out_dir := "user://"

func _initialize() -> void:
	# Uncapped, this runs at several hundred fps and settle(n) covers a few
	# milliseconds rather than n/60 of a second, so timed effects get captured
	# in their first frame. Pin the rate so waits mean what they read.
	Engine.max_fps = 60
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	capture.call_deferred()

func settle(frames: int) -> void:
	for i in range(frames):
		await process_frame

func shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	var err := image.save_png(path)
	print("%s -> %s" % [name, "ok" if err == OK else "ERR %d" % err])

func report_display() -> void:
	var window_size := DisplayServer.window_get_size()
	var visible: Vector2 = get_root().get_visible_rect().size
	var scale: Vector2 = get_root().get_final_transform().get_scale()
	print("window %s | design %s | scale %.3f | cropped: %s" % [
		window_size, visible, scale.x,
		"YES" if scale.x * visible.x > float(window_size.x) + 1.0 or scale.y * visible.y > float(window_size.y) + 1.0 else "no"])

func capture() -> void:
	report_display()
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await settle(4)
	# Never let a capture run top up the real profile.
	game.profile.persist = false
	game.profile.data.max_danger = 3
	game.danger = 2
	await shoot("01_title")

	game.state = "settings"
	game.menu_index = 0
	await settle(3)
	await shoot("08_settings")

	game.state = "armory"
	await settle(3)
	await shoot("02_armory")

	game.profile.data.achievements = ["first_blood", "rift_walker", "boss_slayer", "arsenal"]
	game.state = "awards"
	await settle(3)
	await shoot("18_achievements")
	game.state = "title"

	# The co-op lobby, drawn on a cold boot: this is what CO-OP off the title
	# screen actually reaches, with no run and so no survivors to read from.
	game.profile.data.unlocked_characters = [0, 1, 2, 3]
	game.profile.data.unlocked_guns = [0, 1, 2]
	game.handle_menu_action("coop")
	game.lobby.tick_join(0, Lobby.HOLD_TIME * 0.55, true)
	await settle(3)
	await shoot("15_lobby_join")
	game.lobby.tick_join(0, Lobby.HOLD_TIME, true)
	game.lobby.tick_join(1, Lobby.HOLD_TIME, true)
	game.lobby.character[1] = 2
	await settle(3)
	await shoot("16_lobby_characters")
	game.lobby.advance()
	game.lobby.gun[1] = 2
	await settle(3)
	await shoot("17_lobby_weapons")
	game.leave_lobby()
	await settle(2)

	game.state = "playing"
	game.start_run()
	# Walk into the field for a few seconds so enemies close in and the
	# auto-fire has something to shoot at.
	Input.action_press("move_right")
	await settle(150)
	Input.action_release("move_right")
	Input.action_press("move_up")
	await settle(120)
	Input.action_release("move_up")
	await shoot("03_combat")

	# Jump to a boss round to catch the big sprite on screen.
	var s = game.session
	s.round_number = 4
	s.begin_round()
	await settle(90)
	await shoot("04_boss")

	# Rift Nova mid-blast, with a crowd to throw.
	s.player.position = Arena.BOUNDS.get_center()
	s.round_phase = "cleanup"
	for i in range(16):
		var spot: Vector2 = s.player.position + Vector2(randf_range(-260, 260), randf_range(-230, 230))
		s.spawn_enemy(EnemyCatalog.all()[i % 3], spot, false)
	await settle(12)
	s.nova_cooldown = 0.0
	s.rift_nova()
	await settle(13)
	await shoot("07_nova")

	# Damage numbers and an elite (the ringed one) under sustained fire.
	s.player.position = Arena.BOUNDS.get_center()
	s.round_number = 8
	s.round_phase = "cleanup"
	for enemy in s.actors.get_children():
		s.actors.remove_child(enemy)
		enemy.queue_free()
	s.add_weapon("smg", 2)
	s.add_weapon("shotgun", 1)
	for i in range(7):
		var ring: float = randf_range(190.0, 330.0)
		var at: Vector2 = s.player.position + Vector2.RIGHT.rotated(TAU * float(i) / 7.0 + 0.4) * ring
		s.spawn_enemy(EnemyCatalog.all()[i % 4], at, false, i == 0)
	await settle(50)
	await shoot("09_numbers")

	# The shop, with a purse worth spending and a couple of things owned.
	s.materials = 46
	s.add_weapon("smg", 1)
	s.add_weapon("smg", 1)
	s.add_weapon("rifle", 2)
	s.add_item("focus_lens")
	s.add_item("scrap_plate")
	s.finish_wave()
	game.state = "shop"
	await settle(4)
	await shoot("05_shop")

	# Victory, with a full run summary.
	s.round_number = Balance.FINAL_WAVE
	s.kills = 431
	s.run_time = 742.0
	s.level = 17
	s.add_item("honed_edge")
	s.add_item("ghost_step")
	s.add_item("war_drum")
	s.add_weapon("lance", 3)
	game.last_reward = 210
	game.state = "victory"
	await settle(4)
	await shoot("10_victory")

	# Level-up overlay, four choices.
	s.upgrades = UpgradeCatalog.roll_choices(s.rng, 6, 0.0)
	game.state = "level_up"
	await settle(4)
	await shoot("06_level_up")

	# The ask before abandoning a run, which quotes the run it is about to end.
	s.round_number = 9
	s.level = 8
	s.kills = 164
	game.state = "paused"
	game.state = "confirm_quit"
	await settle(4)
	await shoot("11_confirm_quit")

	# Co-op: the arena is shared, and only the two screens that ask a player to
	# choose something are split.
	game.state = "playing"
	game.start_run(true)
	await settle(6)
	var c = game.session
	c.seat(0).materials = 61
	c.seat(1).materials = 44
	c.round_number = 7
	c.add_weapon("smg", 1, c.seat(0))
	c.add_weapon("blade", 2, c.seat(0))
	c.add_item("focus_lens", c.seat(0))
	c.add_weapon("wand", 1, c.seat(1))
	c.add_item("scrap_plate", c.seat(1))
	c.seat(1).level = 4
	await shoot("12_coop_arena")
	c.finish_wave()
	game.state = "shop"
	await settle(4)
	await shoot("13_coop_shop")
	c.seat(0).upgrades = UpgradeCatalog.roll_choices(c.rng, 6, 0.0)
	c.seat(1).upgrades = UpgradeCatalog.roll_choices(c.rng, 6, 0.0)
	game.state = "level_up"
	await settle(4)
	await shoot("14_coop_level_up")
	quit(0)

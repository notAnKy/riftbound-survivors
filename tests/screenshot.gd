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
	await shoot("01_title")

	game.state = "settings"
	game.menu_index = 2
	await settle(3)
	await shoot("08_settings")

	game.state = "armory"
	await settle(3)
	await shoot("02_armory")

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

	# The shop, with a purse worth spending and a couple of things owned.
	s.materials = 46
	s.add_weapon("smg", 1)
	s.add_weapon("rifle", 2)
	s.add_item("focus_lens")
	s.add_item("scrap_plate")
	s.finish_wave()
	game.state = "shop"
	await settle(4)
	await shoot("05_shop")

	# Level-up overlay, four choices.
	s.upgrades = UpgradeCatalog.roll_choices(s.rng, 6, 0.0)
	game.state = "level_up"
	await settle(4)
	await shoot("06_level_up")
	quit(0)

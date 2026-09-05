extends SceneTree

# Dev tool: plays a short run and writes frames to disk so a change can be
# eyeballed without sitting at the game. Needs a real (non-headless) run.
# Run: godot --path . --script res://tests/screenshot.gd -- <output_dir>

var out_dir := "user://"

func _initialize() -> void:
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

func capture() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await settle(4)
	await shoot("01_title")

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
	s.round_phase = "intermission"
	s.intermission_left = 0.0
	s.begin_round()
	await settle(90)
	await shoot("04_boss")
	quit(0)

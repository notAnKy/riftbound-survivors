extends SceneTree

# Headless integration pass over the node/physics rebuild.
# Run: godot --headless --script res://tests/integration_test.gd

var failures := 0

func _initialize() -> void:
	bootstrap.call_deferred()

func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok: failures += 1

func step(frames: int) -> void:
	for i in range(frames):
		await physics_frame

func fresh_game() -> Node:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
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
	test_profile_sanitizing()
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
	check("a kill drops a pickup (%d)" % s.pickups.get_child_count(), s.pickups.get_child_count() == 1)
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
		s.round_phase = "intermission"
		s.intermission_left = 0.0
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

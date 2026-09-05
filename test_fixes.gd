extends SceneTree

func _initialize() -> void:
	bootstrap.call_deferred()

func bootstrap() -> void:
	var failures := 0
	failures += await test_single_run_ended()
	failures += test_profile_sanitizing()
	failures += await test_boss_banner_window()
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)

func check(label: String, ok: bool) -> int:
	print(("PASS  " if ok else "FAIL  ") + label)
	return 0 if ok else 1

# The old code emitted run_ended once per overlapping enemy per frame, so a
# death inside a crowd paid out coins several times over.
func test_single_run_ended() -> int:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var session = game.session
	session.reset_run()
	session.player_hp = 1.0
	var emitted := [0]
	session.run_ended.connect(func() -> void: emitted[0] += 1)
	for i in range(6):
		session.enemies.append({"p": session.player_pos, "hp": 500.0, "max_hp": 500.0, "speed": 0.0, "kind": 0, "hit": 0.0, "attack": 5.0})
	for frame in range(4):
		session.update_enemies(0.5)
	var failed := check("run_ended fires once for a death in a crowd (got %d)" % emitted[0], emitted[0] == 1)
	game.free()
	return failed

func test_profile_sanitizing() -> int:
	var failed := 0
	var profile := ProfileManager.new()
	# A truncated or hand-edited file: keys missing, wrong types, junk indices.
	var clean := profile.sanitized({"coins": "lots", "unlocked_characters": [0, 9, -2, 1, 1, "x"]})
	failed += check("missing/!int coins falls back to 0 (got %s)" % clean.coins, clean.coins == 0)
	failed += check("missing unlocked_guns defaults to [0] (got %s)" % [clean.unlocked_guns], clean.unlocked_guns == [0])
	failed += check("out-of-range and duplicate unlocks dropped (got %s)" % [clean.unlocked_characters], clean.unlocked_characters == [0, 1])
	var kept := profile.sanitized({"coins": 120.0, "unlocked_guns": [0, 2], "unlocked_characters": [0]})
	failed += check("a valid profile survives intact", kept.coins == 120 and kept.unlocked_guns == [0, 2])
	return failed

# The banner used `round == 5` against the base 40s duration, so it never showed
# on rounds 10/15 and would have lingered ~24s if it had.
func test_boss_banner_window() -> int:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var session = game.session
	session.reset_run()
	var failed := 0
	var banner_rounds := []
	var banner_seconds := 0.0
	for r in range(2, 13):
		session.round_phase = "intermission"
		session.intermission_left = 0.0
		session.begin_round()
		if session.round_number % 5 == 0 and session.round_time_left > session.round_length - 3.0:
			banner_rounds.append(session.round_number)
			if session.round_number == 10:
				# how long the banner stays up on a late boss round
				var t := 0.0
				while session.round_time_left > session.round_length - 3.0:
					session.round_time_left -= 0.1
					t += 0.1
				banner_seconds = t
	failed += check("banner shows on every boss round (got %s)" % [banner_rounds], banner_rounds == [5, 10])
	failed += check("banner lasts ~3s on round 10 (got %.1fs)" % banner_seconds, banner_seconds > 2.9 and banner_seconds < 3.2)

	# a robot volley and a boss slam must end the run the same way contact does
	for kind in [2, 4]:
		session.reset_run()
		session.player_hp = 1.0
		var ended := [0]
		session.run_ended.connect(func() -> void: ended[0] += 1)
		session.enemies.append({"p": session.player_pos + Vector2(120, 0), "hp": 999.0, "max_hp": 999.0, "speed": 0.0, "kind": kind, "hit": 0.0, "attack": 0.0})
		session.update_enemies(0.016)
		failed += check("kind %d killing blow ends the run (hp %.0f, emits %d)" % [kind, session.player_hp, ended[0]], session.player_hp == 0.0 and ended[0] == 1)

	# the player is no longer frozen for the 7s intermission
	session.reset_run()
	session.round_phase = "intermission"
	session.intermission_left = 7.0
	var before: Vector2 = session.player_pos
	session.gems.append({"p": session.player_pos, "value": 5})
	session.tick(0.1)
	failed += check("gems are collectible during intermission (xp %d)" % session.xp, session.xp == 5)
	failed += check("intermission still counts down (%.1f left)" % session.intermission_left, absf(session.intermission_left - 6.9) < 0.01)
	failed += check("move_player runs in intermission", before == session.player_pos)

	game.free()
	return failed

class_name GameSession
extends Node2D

signal level_up_requested
signal run_ended

const ARENA := Rect2(28, 92, 1224, 596)
const PLAYER_RADIUS := 17.0
const PALETTE := [Color("6df7e4"), Color("ae7cff"), Color("ff6d8d"), Color("ffd166")]
var player_texture: Texture2D
var zombie_texture: Texture2D
var robot_texture: Texture2D
var warden_texture: Texture2D

var player_pos := Vector2(640, 390)
var player_hp := 100.0
var player_max_hp := 100.0
var player_speed := 290.0
var player_damage := 15.0
var fire_delay := 0.33
var fire_timer := 0.0
var run_time := 0.0
var spawn_timer := 0.0
var level := 1
var xp := 0
var xp_to_next := 24
var kills := 0
var round_number := 1
var round_duration := 40.0
var round_length := 40.0
var round_time_left := 40.0
var intermission_left := 0.0
var round_phase := "combat"
var pickup_radius := 34.0
var selected_gun := 0
var dash_cooldown := 0.0
var nova_cooldown := 0.0
var last_move := Vector2.RIGHT
var rift_effects_enabled := true
var run_over := false
var upgrades: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var audio: AudioSfx

func _ready() -> void:
	rng.randomize()
	audio = get_node("../AudioSfx") as AudioSfx
	player_texture = load("res://assets/sprites/player.png") as Texture2D
	zombie_texture = load("res://assets/sprites/zombie.png") as Texture2D
	robot_texture = load("res://assets/sprites/robot.png") as Texture2D
	warden_texture = load("res://assets/sprites/warden.png") as Texture2D

func reset_run() -> void:
	player_pos = Vector2(640, 390)
	player_hp = 100.0
	player_max_hp = 100.0
	player_speed = 290.0
	player_damage = 15.0
	fire_delay = 0.33
	fire_timer = 0.0
	run_time = 0.0
	spawn_timer = 0.0
	level = 1
	xp = 0
	xp_to_next = 24
	kills = 0
	round_number = 1
	round_length = round_duration
	round_time_left = round_length
	intermission_left = 0.0
	round_phase = "combat"
	run_over = false
	pickup_radius = 34.0
	dash_cooldown = 0.0
	nova_cooldown = 0.0
	enemies.clear()
	bullets.clear()
	gems.clear()
	queue_redraw()

func tick(delta: float) -> void:
	run_time += delta
	if round_phase == "intermission":
		intermission_left -= delta
		move_player(delta)
		collect_gems()
		if intermission_left <= 0.0: begin_round()
		queue_redraw()
		return
	move_player(delta)
	if round_phase == "combat":
		round_time_left = maxf(0.0, round_time_left - delta)
		spawn_enemies(delta)
		if round_time_left <= 0.0: round_phase = "cleanup"
	fire_weapon(delta)
	update_bullets(delta)
	update_enemies(delta)
	collect_gems()
	if round_phase == "cleanup" and enemies.is_empty():
		round_phase = "intermission"
		intermission_left = 7.0
		audio.play_tone(920.0, 0.18)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	nova_cooldown = maxf(0.0, nova_cooldown - delta)
	queue_redraw()

func begin_round() -> void:
	round_number += 1
	round_length = round_duration + minf(20.0, float(round_number - 1) * 2.0)
	round_time_left = round_length
	round_phase = "combat"
	spawn_timer = 0.15
	if round_number % 5 == 0:
		spawn_boss()
		audio.play_tone(90.0, 0.45)

func spawn_boss() -> void:
	var hp := 560.0 * (1.0 + (round_number - 1) * 0.34)
	enemies.append({"p":Vector2(640, 118), "hp":hp, "max_hp":hp, "speed":45.0 + round_number * 2.0, "kind":4, "hit":0.0, "attack":0.0})

func move_player(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO: last_move = direction
	player_pos += direction * player_speed * delta
	player_pos.x = clampf(player_pos.x, ARENA.position.x + PLAYER_RADIUS, ARENA.end.x - PLAYER_RADIUS)
	player_pos.y = clampf(player_pos.y, ARENA.position.y + PLAYER_RADIUS, ARENA.end.y - PLAYER_RADIUS)

func spawn_enemies(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0: return
	var intensity: float = pow(1.30, round_number - 1)
	spawn_timer = maxf(0.16, 1.05 / intensity)
	for count in range(1 + int(round_number / 4)):
		var side := rng.randi_range(0, 3)
		var p := Vector2.ZERO
		match side:
			0: p = Vector2(rng.randf_range(ARENA.position.x, ARENA.end.x), ARENA.position.y - 20)
			1: p = Vector2(ARENA.end.x + 20, rng.randf_range(ARENA.position.y, ARENA.end.y))
			2: p = Vector2(rng.randf_range(ARENA.position.x, ARENA.end.x), ARENA.end.y + 20)
			_: p = Vector2(ARENA.position.x - 20, rng.randf_range(ARENA.position.y, ARENA.end.y))
		var kind := choose_enemy_kind()
		var hp_multiplier: float = [1.0, 0.82, 1.10, 3.6][kind]
		var speed_multiplier: float = [1.0, 1.48, 0.86, 0.56][kind]
		var hp: float = (38.0 + round_number * 12.0) * hp_multiplier * intensity
		enemies.append({"p": p, "hp": hp, "max_hp": hp, "speed": (rng.randf_range(54.0, 82.0) + round_number * 4.0) * speed_multiplier, "kind": kind, "hit": 0.0, "attack": rng.randf_range(0.0, 1.2)})

func choose_enemy_kind() -> int:
	var options := [0]
	if round_number >= 2: options.append(1)
	if round_number >= 3: options.append(2)
	if round_number >= 4: options.append(3)
	return options[rng.randi_range(0, options.size() - 1)]

func fire_weapon(delta: float) -> void:
	fire_timer -= delta
	if fire_timer > 0.0 or enemies.is_empty(): return
	fire_timer = fire_delay
	var target: Dictionary = enemies[0]
	var best_distance: float = player_pos.distance_squared_to(target.p)
	for enemy in enemies:
		var distance: float = player_pos.distance_squared_to(enemy.p)
		if distance < best_distance:
			target = enemy
			best_distance = distance
	var direction: Vector2 = player_pos.direction_to(target.p)
	if selected_gun == 0:
		add_bullet(direction, 680.0, 0.9, player_damage, Color("62e8ff"), 0)
		audio.play_tone(540.0, 0.05)
	elif selected_gun == 1:
		add_bullet(direction, 540.0, 1.2, player_damage * 1.35, Color("bf8cff"), 2)
		audio.play_tone(390.0, 0.10)
	else:
		for offset in [-0.26, -0.13, 0.0, 0.13, 0.26]: add_bullet(direction.rotated(offset), 590.0, 0.44, player_damage * 0.68, Color("ffcc70"), 0)
		audio.play_tone(145.0, 0.10)

func add_bullet(direction: Vector2, speed: float, lifetime: float, damage: float, color: Color, pierce: int) -> void:
	bullets.append({"p": player_pos, "v": direction * speed, "life": lifetime, "damage": damage, "color": color, "pierce": pierce})

func update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		bullet.p += bullet.v * delta
		bullet.life -= delta
		var removed: bool = bullet.life <= 0.0
		if not removed:
			for enemy in enemies:
				if bullet.p.distance_squared_to(enemy.p) < 576.0:
					enemy.hp -= bullet.damage
					enemy.hit = 0.12
					if int(bullet.pierce) > 0: bullet.pierce -= 1
					else: removed = true
					break
		if removed: bullets.remove_at(i)
		else: bullets[i] = bullet

func update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		enemy.hit = maxf(0.0, enemy.hit - delta)
		if enemy.hp <= 0.0:
			var gem_value: int = 8 if enemy.kind == 4 else (3 if enemy.kind == 3 else 1)
			gems.append({"p": enemy.p, "value": gem_value})
			enemies.remove_at(i)
			kills += 1
			audio.play_tone(190.0, 0.06)
			continue
		var direction: Vector2 = enemy.p.direction_to(player_pos)
		var distance: float = enemy.p.distance_to(player_pos)
		if enemy.kind == 1:
			enemy.p += direction.rotated(sin(run_time * 5.0 + float(i)) * 0.7) * enemy.speed * delta
		elif enemy.kind == 2:
			if distance > 180.0: enemy.p += direction * enemy.speed * delta
			enemy.attack -= delta
			if enemy.attack <= 0.0 and distance < 250.0:
				damage_player((7.0 + round_number) * 0.65)
				enemy.attack = 1.4
		elif enemy.kind == 4:
			enemy.p += direction * enemy.speed * delta
			enemy.attack -= delta
			if enemy.attack <= 0.0 and distance < 230.0:
				damage_player(15.0 + round_number * 2.0)
				enemy.attack = 1.1
		else:
			enemy.p += direction * enemy.speed * delta
		if enemy.p.distance_to(player_pos) < PLAYER_RADIUS + 13.0:
			damage_player((11.0 + round_number * 1.8) * delta)
		enemies[i] = enemy

# Contact, robot fire and boss slams all killed the player, but only contact
# ended the run - the other two left the player alive at 0 HP. One entry point
# means a new damage source cannot reintroduce that, and run_over keeps a death
# inside a crowd from paying out coins once per overlapping enemy.
func damage_player(amount: float) -> void:
	player_hp = maxf(0.0, player_hp - amount)
	if player_hp <= 0.0 and not run_over:
		run_over = true
		run_ended.emit()

func collect_gems() -> void:
	for i in range(gems.size() - 1, -1, -1):
		var gem: Dictionary = gems[i]
		if gem.p.distance_to(player_pos) < pickup_radius:
			xp += gem.value
			gems.remove_at(i)
			audio.play_tone(740.0, 0.04)
			if xp >= xp_to_next:
				xp -= xp_to_next
				level += 1
				xp_to_next = int(ceil(xp_to_next * 1.45)) + 5
				upgrades = UpgradeCatalog.roll_choices(rng, round_number)
				level_up_requested.emit()

func choose_upgrade(index: int) -> void:
	if index < 0 or index >= upgrades.size(): return
	match upgrades[index].apply:
		"damage": player_damage += 6.0
		"fire_rate": fire_delay *= 0.83
		"health":
			player_max_hp += 25.0
			player_hp = minf(player_max_hp, player_hp + 25.0)
		"speed": player_speed *= 1.12
		"magnet": pickup_radius += 45.0
		"legendary":
			player_damage += 20.0
			player_hp = minf(player_max_hp, player_hp + 35.0)

func apply_character(index: int) -> void:
	var character := CharacterCatalog.get_character(index)
	player_max_hp = character.hp
	player_hp = player_max_hp
	player_speed = character.speed
	player_damage *= character.damage

func dash() -> void:
	if dash_cooldown > 0.0: return
	player_pos += last_move.normalized() * 155.0
	player_pos.x = clampf(player_pos.x, ARENA.position.x + PLAYER_RADIUS, ARENA.end.x - PLAYER_RADIUS)
	player_pos.y = clampf(player_pos.y, ARENA.position.y + PLAYER_RADIUS, ARENA.end.y - PLAYER_RADIUS)
	dash_cooldown = 4.0
	audio.play_tone(820.0, 0.09)

func rift_nova() -> void:
	if nova_cooldown > 0.0: return
	for enemy in enemies:
		if enemy.p.distance_to(player_pos) < 175.0:
			enemy.hp -= player_damage * 2.2
			enemy.hit = 0.25
	nova_cooldown = 9.0
	audio.play_tone(260.0, 0.28)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("0b1020"))
	draw_rect(ARENA, Color("151d35"), true)
	draw_rect(ARENA, Color("3d527d"), false, 3.0)
	for x in range(60, 1250, 40): draw_line(Vector2(x, ARENA.position.y), Vector2(x, ARENA.end.y), Color(0.12,0.17,0.30,0.55), 1.0)
	for y in range(120, 680, 40): draw_line(Vector2(ARENA.position.x,y), Vector2(ARENA.end.x,y), Color(0.12,0.17,0.30,0.55), 1.0)
	if rift_effects_enabled:
		for p in [Vector2(130,180), Vector2(1130,560), Vector2(1040,170)]: draw_arc(p, 28.0, 0.0, TAU, 20, Color(0.56,0.30,0.95,0.35), 5.0)
	for gem in gems: draw_circle(gem.p, 7.0, Color("8cffd1"))
	for bullet in bullets: draw_circle(bullet.p, 5.0, bullet.color)
	for enemy in enemies: draw_enemy(enemy)
	draw_player()

func draw_player() -> void:
	var bob := Vector2(0, sin(run_time * 7.0) * 1.5)
	draw_circle(player_pos + bob, 24.0 + sin(run_time * 4.0) * 1.5, Color(0.2,0.9,0.95,0.12))
	if player_texture != null: draw_texture_rect(player_texture, Rect2(player_pos + bob - Vector2(22,22), Vector2(44,44)), false)
	draw_line(player_pos + bob, player_pos + bob + last_move.normalized() * 27.0, Color("ffe49a"), 5.0)

func draw_enemy(enemy: Dictionary) -> void:
	var colors := [Color("86a85a"), Color("b66cff"), Color("ff667e"), Color("a85435"), Color("f2b84b")]
	var radius := 35.0 if enemy.kind == 4 else (14.0 if enemy.kind != 2 else 11.0)
	var pulse := sin(run_time * (4.0 if enemy.kind == 1 else 2.0) + enemy.p.x) * 1.2
	draw_circle(enemy.p, radius + pulse, Color.WHITE if enemy.hit > 0.0 else colors[enemy.kind])
	var texture: Texture2D = robot_texture if enemy.kind == 2 else (warden_texture if enemy.kind == 1 else zombie_texture)
	var texture_size: float = 78.0 if enemy.kind == 4 else 38.0
	if texture != null: draw_texture_rect(texture, Rect2(enemy.p - Vector2(texture_size,texture_size) * 0.5, Vector2(texture_size,texture_size)), false, Color.WHITE if enemy.hit <= 0.0 else Color("fff6cc"))
	if enemy.kind == 2 or enemy.kind == 4: draw_arc(enemy.p, radius + 4.0, 0, TAU, 16, Color("ffa657"), 3.0)
	else:
		draw_circle(enemy.p + Vector2(-4,-2), 2.5, Color("171722"))
		draw_circle(enemy.p + Vector2(4,-2), 2.5, Color("171722"))
	var ratio: float = enemy.hp / enemy.max_hp
	draw_rect(Rect2(enemy.p + Vector2(-14,-22), Vector2(28,4)), Color("34243a"))
	draw_rect(Rect2(enemy.p + Vector2(-14,-22), Vector2(28 * ratio,4)), Color("ff718b"))

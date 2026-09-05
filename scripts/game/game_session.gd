class_name GameSession
extends Node2D

signal level_up_requested
signal run_ended

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/actors/Enemy.tscn")
const SHOT_SCENE := preload("res://scenes/actors/Projectile.tscn")
const PICKUP_SCENE := preload("res://scenes/actors/Pickup.tscn")

@onready var actors: Node2D = $Actors
@onready var shots: Node2D = $Shots
@onready var pickups: Node2D = $Pickups

var player: Player = null
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
var selected_gun := 0
var nova_cooldown := 0.0
var pending_pickup_radius := 34.0
var upgrades: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var audio: AudioSfx

var rift_effects_enabled := true:
	set(value):
		rift_effects_enabled = value
		var trim := get_node_or_null("Arena/Trim")
		if trim != null:
			trim.rift_effects_enabled = value
			trim.queue_redraw()

# The UI reads the player vitals through the session, but they live on the
# player node now, so these forward instead of being mirrored and going stale.
var player_hp: float:
	get: return player.hp if is_instance_valid(player) else 0.0
var player_max_hp: float:
	get: return player.max_hp if is_instance_valid(player) else 1.0
var dash_cooldown: float:
	get: return player.dash_cooldown if is_instance_valid(player) else 0.0

func _ready() -> void:
	rng.randomize()
	audio = get_node("../AudioSfx") as AudioSfx
	rift_effects_enabled = rift_effects_enabled

func reset_run() -> void:
	for group in [actors, shots, pickups]:
		for child in group.get_children():
			group.remove_child(child)
			child.queue_free()
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	player = PLAYER_SCENE.instantiate()
	player.position = Arena.BOUNDS.get_center()
	add_child(player)
	player.died.connect(func() -> void: run_ended.emit())
	(player.get_node("Magnet") as Area2D).area_entered.connect(on_magnet_touched)
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
	nova_cooldown = 0.0
	pending_pickup_radius = 34.0
	player.apply_pickup_radius(pending_pickup_radius)

func apply_character(index: int) -> void:
	if not is_instance_valid(player): return
	var character := CharacterCatalog.get_character(index)
	player.max_hp = character.hp
	player.hp = player.max_hp
	player.speed = character.speed
	# A full modulate drains the sprite art, so the character colour is only
	# mixed in as a tint.
	player.tint = Color.WHITE.lerp(character.color, 0.35)
	player_damage *= character.damage

# Wave clock and spawning only. Movement, collision and pickup drift all run in
# the actor _physics_process callbacks, which the tree pauses with the game.
func tick(delta: float) -> void:
	run_time += delta
	nova_cooldown = maxf(0.0, nova_cooldown - delta)
	aim_player()
	if round_phase == "intermission":
		intermission_left -= delta
		if intermission_left <= 0.0: begin_round()
		return
	if round_phase == "combat":
		round_time_left = maxf(0.0, round_time_left - delta)
		spawn_enemies(delta)
		if round_time_left <= 0.0: round_phase = "cleanup"
	fire_weapon(delta)
	if round_phase == "cleanup" and actors.get_child_count() == 0:
		round_phase = "intermission"
		intermission_left = 7.0
		audio.play_tone(920.0, 0.18)

func begin_round() -> void:
	round_number += 1
	round_length = round_duration + minf(20.0, float(round_number - 1) * 2.0)
	round_time_left = round_length
	round_phase = "combat"
	spawn_timer = 0.15
	if round_number % 5 == 0:
		var top := Vector2(Arena.BOUNDS.get_center().x, Arena.BOUNDS.position.y + 70.0)
		spawn_enemy(EnemyCatalog.boss(), top, true)
		audio.play_tone(90.0, 0.45)

func spawn_enemies(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0: return
	var intensity: float = pow(1.30, round_number - 1)
	spawn_timer = maxf(0.16, 1.05 / intensity)
	var options := EnemyCatalog.available(round_number)
	for count in range(1 + int(round_number / 4)):
		spawn_enemy(options[rng.randi_range(0, options.size() - 1)], spawn_point(), false)

# Enemies used to appear outside the arena and walk in. With real walls that
# would trap them, so they arrive just inside the border, away from the player.
func spawn_point() -> Vector2:
	var band := Arena.BOUNDS.grow(-26.0)
	for attempt in range(8):
		var p := Vector2.ZERO
		match rng.randi_range(0, 3):
			0: p = Vector2(rng.randf_range(band.position.x, band.end.x), band.position.y)
			1: p = Vector2(band.end.x, rng.randf_range(band.position.y, band.end.y))
			2: p = Vector2(rng.randf_range(band.position.x, band.end.x), band.end.y)
			_: p = Vector2(band.position.x, rng.randf_range(band.position.y, band.end.y))
		if not is_instance_valid(player) or p.distance_to(player.position) > 190.0:
			return p
	return band.position

func spawn_enemy(def: Dictionary, at: Vector2, is_boss: bool) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.position = at
	actors.add_child(enemy)
	enemy.configure(def, round_number, player, is_boss)
	enemy.died.connect(on_enemy_died)
	enemy.wants_shot.connect(on_enemy_shot)
	return enemy

func nearest_enemy() -> Enemy:
	if not is_instance_valid(player): return null
	var best: Enemy = null
	var best_distance := INF
	for node in actors.get_children():
		var enemy := node as Enemy
		if enemy == null or not enemy.alive: continue
		var distance: float = player.position.distance_squared_to(enemy.position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best

func aim_player() -> void:
	if not is_instance_valid(player): return
	var target := nearest_enemy()
	if target != null: player.aim_at(target.global_position)
	else: player.face_travel()

func fire_weapon(delta: float) -> void:
	fire_timer -= delta
	if fire_timer > 0.0 or not is_instance_valid(player): return
	var target := nearest_enemy()
	if target == null: return
	fire_timer = fire_delay
	var direction: Vector2 = (target.position - player.position).normalized()
	if selected_gun == 0:
		add_shot(direction, 680.0, 0.9, player_damage, Color("62e8ff"), 0)
		audio.play_tone(540.0, 0.05)
	elif selected_gun == 1:
		add_shot(direction, 540.0, 1.2, player_damage * 1.35, Color("bf8cff"), 2)
		audio.play_tone(390.0, 0.10)
	else:
		for offset in [-0.26, -0.13, 0.0, 0.13, 0.26]:
			add_shot(direction.rotated(offset), 590.0, 0.44, player_damage * 0.68, Color("ffcc70"), 0)
		audio.play_tone(145.0, 0.10)

func add_shot(direction: Vector2, speed: float, life: float, damage: float, color: Color, pierce: int) -> void:
	var shot: Projectile = SHOT_SCENE.instantiate()
	shots.add_child(shot)
	shot.launch(player.position, direction, speed, damage, life, color, pierce, false)

func on_enemy_shot(from: Vector2, direction: Vector2, damage: float, shot_speed: float) -> void:
	var shot: Projectile = SHOT_SCENE.instantiate()
	shots.add_child(shot)
	shot.launch(from, direction, shot_speed, damage, 3.0, Color("ff9f6d"), 0, true)

func on_enemy_died(at: Vector2, material_value: int) -> void:
	kills += 1
	audio.play_tone(190.0, 0.06)
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	pickup.setup(at, material_value)
	pickup.collected.connect(on_pickup_collected)
	# This runs inside the projectile collision callback, and the physics
	# server refuses to have an Area2D added while it is flushing queries.
	pickups.add_child.call_deferred(pickup)

func on_magnet_touched(area: Area2D) -> void:
	if area is Pickup: area.attract(player)

func on_pickup_collected(value: int) -> void:
	xp += value
	audio.play_tone(740.0, 0.04)
	if xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(ceil(xp_to_next * 1.45)) + 5
		upgrades = UpgradeCatalog.roll_choices(rng, round_number)
		level_up_requested.emit()

func choose_upgrade(index: int) -> void:
	if index < 0 or index >= upgrades.size() or not is_instance_valid(player): return
	match upgrades[index].apply:
		"damage": player_damage += 6.0
		"fire_rate": fire_delay *= 0.83
		"health":
			player.max_hp += 25.0
			player.heal(25.0)
		"speed": player.speed *= 1.12
		"magnet":
			pending_pickup_radius += 45.0
			player.apply_pickup_radius(pending_pickup_radius)
		"legendary":
			player_damage += 20.0
			player.heal(35.0)

func dash() -> void:
	if is_instance_valid(player) and player.dash(): audio.play_tone(820.0, 0.09)

func rift_nova() -> void:
	if nova_cooldown > 0.0 or not is_instance_valid(player): return
	for node in actors.get_children():
		var enemy := node as Enemy
		if enemy != null and enemy.position.distance_to(player.position) < 175.0:
			enemy.take_damage(player_damage * 2.2)
	nova_cooldown = 9.0
	audio.play_tone(260.0, 0.28)

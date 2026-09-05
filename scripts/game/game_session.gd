class_name GameSession
extends Node2D

signal level_up_requested
signal run_ended
signal wave_cleared

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/actors/Enemy.tscn")
const SHOT_SCENE := preload("res://scenes/actors/Projectile.tscn")
const PICKUP_SCENE := preload("res://scenes/actors/Pickup.tscn")
const MAX_WEAPONS := 6

@onready var actors: Node2D = $Actors
@onready var shots: Node2D = $Shots
@onready var pickups: Node2D = $Pickups

var player: Player = null
var stats: Stats = Stats.new()
var weapons: Array[Weapon] = []
var items: Array[String] = []
var shop := Shop.new()
var materials := 0
var run_time := 0.0
var spawn_timer := 0.0
var level := 1
var xp := 0
var xp_to_next := Balance.XP_FIRST_LEVEL
var kills := 0
var round_number := 1
var round_duration := 40.0
var round_length := 40.0
var round_time_left := 40.0
var round_phase := "combat"
var selected_gun := 0
var nova_cooldown := 0.0
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
	stats = Stats.new()
	weapons = [Weapon.new(String(GunCatalog.get_gun(selected_gun).weapon), 1)]
	items = []
	materials = 0
	player = PLAYER_SCENE.instantiate()
	player.stats = stats
	player.position = Arena.BOUNDS.get_center()
	add_child(player)
	player.died.connect(func() -> void: run_ended.emit())
	(player.get_node("Magnet") as Area2D).area_entered.connect(on_magnet_touched)
	run_time = 0.0
	spawn_timer = 0.0
	level = 1
	xp = 0
	xp_to_next = Balance.XP_FIRST_LEVEL
	kills = 0
	round_number = 1
	round_length = round_duration
	round_time_left = round_length
	round_phase = "combat"
	nova_cooldown = 0.0
	player.hp = player.max_hp
	player.refresh_pickup_radius()

func apply_character(index: int) -> void:
	if not is_instance_valid(player): return
	var character := CharacterCatalog.get_character(index)
	stats.set_stat("max_hp", float(character.hp))
	stats.apply_dict(character.get("stats", {}))
	player.base_speed = float(character.speed)
	# A full modulate drains the sprite art, so the character colour is only
	# mixed in as a tint.
	player.tint = Color.WHITE.lerp(character.color, 0.35)
	player.hp = player.max_hp
	player.refresh_pickup_radius()

# Wave clock and spawning only. Movement, collision and pickup drift all run in
# the actor _physics_process callbacks, which the tree pauses with the game.
func tick(delta: float) -> void:
	run_time += delta
	nova_cooldown = maxf(0.0, nova_cooldown - delta)
	aim_player()
	if round_phase == "shop": return
	if round_phase == "combat":
		round_time_left = maxf(0.0, round_time_left - delta)
		spawn_enemies(delta)
		if round_time_left <= 0.0: round_phase = "cleanup"
	fire_weapons(delta)
	if round_phase == "cleanup" and actors.get_child_count() == 0:
		finish_wave()

# The wave ends into the shop rather than a timer, which is where a run
# actually gets built. begin_round is only reached when the player leaves it.
func finish_wave() -> void:
	round_phase = "shop"
	var harvest := int(stats.get_stat("harvesting"))
	if harvest > 0: materials += harvest
	shop.open(rng, round_number, stats.get_stat("luck"))
	audio.play_tone(920.0, 0.18)
	wave_cleared.emit()

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

# --- shop transactions -------------------------------------------------------

func offer_affordable(index: int) -> bool:
	if index < 0 or index >= shop.offers.size(): return false
	var offer: Dictionary = shop.offers[index]
	return not offer.is_empty() and materials >= int(offer.price)

func buy(index: int) -> bool:
	if not offer_affordable(index): return false
	var offer: Dictionary = shop.offers[index]
	if offer.kind == "weapon" and weapons.size() >= MAX_WEAPONS and not would_combine(String(offer.id), int(offer.tier)):
		return false
	materials -= int(offer.price)
	shop.take(index)
	if offer.kind == "weapon": add_weapon(String(offer.id), int(offer.tier))
	else: add_item(String(offer.id))
	audio.play_tone(660.0, 0.08)
	return true

func reroll_shop() -> bool:
	var cost := shop.reroll_cost()
	if materials < cost: return false
	materials -= cost
	shop.reroll(rng, round_number, stats.get_stat("luck"))
	audio.play_tone(430.0, 0.06)
	return true

func sell_weapon(index: int) -> bool:
	if index < 0 or index >= weapons.size() or weapons.size() <= 1: return false
	materials += weapons[index].sell_value()
	weapons.remove_at(index)
	audio.play_tone(360.0, 0.07)
	return true

# A third copy of the same weapon at the same tier merges upward, so a full
# rack is not a hard block on buying one more.
func would_combine(id: String, tier: int) -> bool:
	if tier >= WeaponCatalog.MAX_TIER: return false
	var same := 0
	for weapon in weapons:
		if weapon.id == id and weapon.tier == tier: same += 1
	return same >= 2

func add_weapon(id: String, tier: int) -> void:
	weapons.append(Weapon.new(id, tier))
	combine_weapons()

func combine_weapons() -> void:
	var merged := true
	while merged:
		merged = false
		for weapon in weapons:
			if weapon.tier >= WeaponCatalog.MAX_TIER: continue
			var same := weapons.filter(func(other: Weapon) -> bool:
				return other.id == weapon.id and other.tier == weapon.tier)
			if same.size() < 3: continue
			for i in range(3): weapons.erase(same[i])
			weapons.append(Weapon.new(weapon.id, weapon.tier + 1))
			audio.play_tone(880.0, 0.16)
			merged = true
			break

func add_item(id: String) -> void:
	items.append(id)
	apply_stat_gain(ItemCatalog.get_item(id).stats)

# Max HP granted mid-run should also heal, or an item that raises the ceiling
# makes the health bar read as damage just taken.
func apply_stat_gain(mods: Dictionary) -> void:
	var before := stats.get_stat("max_hp")
	stats.apply_dict(mods)
	if not is_instance_valid(player): return
	var gained := stats.get_stat("max_hp") - before
	if gained > 0.0: player.hp += gained
	player.hp = clampf(player.hp, 0.0, player.max_hp)
	player.refresh_pickup_radius()

# --- combat ------------------------------------------------------------------

func spawn_enemies(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0: return
	spawn_timer = maxf(Balance.SPAWN_INTERVAL_MIN, Balance.SPAWN_INTERVAL / Balance.intensity(round_number))
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

func nearest_enemy(within: float = INF) -> Enemy:
	if not is_instance_valid(player): return null
	var best: Enemy = null
	var best_distance := within * within
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

# Each weapon runs its own cooldown and picks its own target inside its own
# reach, so a short shotgun and a long rifle behave differently on the same
# frame instead of sharing one timer.
func fire_weapons(delta: float) -> void:
	if not is_instance_valid(player) or not player.alive: return
	for weapon in weapons:
		weapon.timer -= delta
		if weapon.timer > 0.0: continue
		var reach := weapon.attack_range(stats)
		var target := nearest_enemy(reach)
		if target == null: continue
		weapon.timer = weapon.cooldown(stats)
		fire(weapon, target, reach)

func fire(weapon: Weapon, target: Enemy, reach: float) -> void:
	var def := weapon.def()
	var damage := weapon.damage(stats)
	var direction: Vector2 = (target.position - player.position).normalized()
	var shots_fired := maxi(1, int(def.shots))
	var spread := float(def.spread)
	var bullet_speed := float(def.bullet_speed)
	# Lifetime comes from reach, so the range shown in the shop is the range
	# actually fired, including any Range stat stacked on top.
	var life: float = maxf(0.08, reach / maxf(bullet_speed, 1.0))
	for i in range(shots_fired):
		var offset := 0.0
		if shots_fired > 1: offset = lerpf(-spread, spread, float(i) / float(shots_fired - 1))
		elif spread > 0.0: offset = rng.randf_range(-spread, spread)
		var crit := stats.roll_crit(rng)
		add_shot(direction.rotated(offset), bullet_speed, life, damage * crit, def.color, int(def.pierce), crit > 1.0)
	audio.play_tone(340.0 + float(def.damage) * 4.0, 0.05)

func add_shot(direction: Vector2, speed: float, life: float, damage: float, color: Color, pierce: int, is_crit: bool = false) -> void:
	var shot: Projectile = SHOT_SCENE.instantiate()
	shots.add_child(shot)
	shot.launch(player.position, direction, speed, damage, life, color, pierce, false, is_crit)
	shot.dealt_damage.connect(on_damage_dealt)

func on_damage_dealt(amount: float) -> void:
	var leech := stats.get_stat("lifesteal")
	if leech > 0.0 and is_instance_valid(player): player.heal(amount * leech / 100.0)

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

# Materials are both the shop currency and the level track, as in Brotato:
# one pickup pays into each.
func on_pickup_collected(value: int) -> void:
	materials += value
	xp += value
	audio.play_tone(740.0, 0.04)
	if xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = Balance.next_level_xp(xp_to_next)
		upgrades = UpgradeCatalog.roll_choices(rng, round_number, stats.get_stat("luck"))
		level_up_requested.emit()

func choose_upgrade(index: int) -> void:
	if index < 0 or index >= upgrades.size(): return
	apply_stat_gain(upgrades[index].stats)

func dash() -> void:
	if is_instance_valid(player) and player.dash(): audio.play_tone(820.0, 0.09)

func rift_nova() -> void:
	if nova_cooldown > 0.0 or not is_instance_valid(player): return
	var punch := 26.0 * stats.damage_multiplier()
	for node in actors.get_children():
		var enemy := node as Enemy
		if enemy != null and enemy.position.distance_to(player.position) < 175.0:
			enemy.take_damage(punch)
	nova_cooldown = 9.0
	audio.play_tone(260.0, 0.28)

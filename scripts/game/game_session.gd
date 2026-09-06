class_name GameSession
extends Node2D

signal level_up_requested
signal run_ended
signal wave_cleared
signal run_won

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/actors/Enemy.tscn")
const SHOT_SCENE := preload("res://scenes/actors/Projectile.tscn")
const PICKUP_SCENE := preload("res://scenes/actors/Pickup.tscn")
const NOVA_SCENE := preload("res://scenes/actors/Nova.tscn")
const NUMBER_SCENE := preload("res://scenes/actors/DamageNumber.tscn")
const SWING_SCENE := preload("res://scenes/actors/MeleeSwing.tscn")
# A fast weapon can land dozens of hits a second; past this many live numbers
# the screen is unreadable anyway, so stop adding to it.
const MAX_NUMBERS := 60
const MAX_WEAPONS := 6

@onready var actors: Node2D = $Actors
@onready var shots: Node2D = $Shots
@onready var pickups: Node2D = $Pickups
@onready var numbers: Node2D = $Numbers

# One entry in solo, two in co-op. Everything that used to be "the player" is a
# field on one of these; the block of forwarding properties further down keeps
# the old singular names pointing at seat 0, so the HUD, the tests and every
# solo path never learn there is a list.
var survivors: Array[Survivor] = []
var coop := false
# What each seat takes into the run, chosen in the co-op lobby. Solo leaves
# these empty and both fall back to the single armory selection.
var seat_characters: Array[int] = []
var seat_guns: Array[int] = []
var run_time := 0.0
var spawn_timer := 0.0
var kills := 0
var round_number := 1
var round_duration := 40.0
var round_length := 40.0
var round_time_left := 40.0
var round_phase := "combat"
var selected_gun := 0
var selected_character := 0
var danger := 0
var shake := 0.0
var hitstop_until := 0
var rng := RandomNumberGenerator.new()
var audio: AudioSfx

var rift_effects_enabled := true:
	set(value):
		rift_effects_enabled = value
		var trim := get_node_or_null("Arena/Trim")
		if trim != null:
			trim.rift_effects_enabled = value
			trim.queue_redraw()

# --- seat 0, under its old name ----------------------------------------------
#
# Co-op turned one set of run state into a list of them. Rather than rewrite
# every caller, seat 0 keeps answering to the singular names it always had: the
# HUD, the shop screen and the whole test suite are solo-shaped and stay that
# way, and only the paths that genuinely handle two players take a seat.
# Null before a run exists. The co-op lobby is reachable straight from the title
# on a cold boot, and it draws before reset_run has built anybody, so every
# caller that can be on screen without a run has to cope with that.
func seat(index: int) -> Survivor:
	if survivors.is_empty(): return null
	return survivors[clampi(index, 0, survivors.size() - 1)]

func seats() -> int:
	return survivors.size()

var me: Survivor:
	get: return survivors[0] if not survivors.is_empty() else null

var player: Player:
	get: return me.player if me != null else null
	set(value):
		if me != null: me.player = value
var stats: Stats:
	get: return me.stats if me != null else null
	set(value):
		if me != null: me.stats = value
var weapons: Array[Weapon]:
	get: return me.weapons if me != null else ([] as Array[Weapon])
	set(value):
		if me != null: me.weapons = value
var items: Array[String]:
	get: return me.items if me != null else ([] as Array[String])
	set(value):
		if me != null: me.items = value
var shop: Shop:
	get: return me.shop if me != null else null
	set(value):
		if me != null: me.shop = value
var upgrades: Array[Dictionary]:
	get: return me.upgrades if me != null else ([] as Array[Dictionary])
	set(value):
		if me != null: me.upgrades = value
var upgrade_totals: Dictionary:
	get: return me.upgrade_totals if me != null else {}
	set(value):
		if me != null: me.upgrade_totals = value
var materials: int:
	get: return me.materials if me != null else 0
	set(value):
		if me != null: me.materials = value
var level: int:
	get: return me.level if me != null else 1
	set(value):
		if me != null: me.level = value
var xp: int:
	get: return me.xp if me != null else 0
	set(value):
		if me != null: me.xp = value
var xp_to_next: int:
	get: return me.xp_to_next if me != null else Balance.XP_FIRST_LEVEL
	set(value):
		if me != null: me.xp_to_next = value
var weapon_slots: int:
	get: return me.weapon_slots if me != null else MAX_WEAPONS
	set(value):
		if me != null: me.weapon_slots = value
var allowed_kinds: Array:
	get: return me.allowed_kinds if me != null else []
	set(value):
		if me != null: me.allowed_kinds = value
var nova_cooldown: float:
	get: return me.nova_cooldown if me != null else 0.0
	set(value):
		if me != null: me.nova_cooldown = value

# The UI reads the player vitals through the session, but they live on the
# player node now, so these forward instead of being mirrored and going stale.
var player_hp: float:
	get: return player.hp if is_instance_valid(player) else 0.0
var player_max_hp: float:
	get: return player.max_hp if is_instance_valid(player) else 1.0
var dash_cooldown: float:
	get: return player.dash_cooldown if is_instance_valid(player) else 0.0

# Everyone still standing. The run ends when this comes back empty, which is
# the whole of the co-op loss condition.
func living() -> Array[Survivor]:
	var live: Array[Survivor] = []
	for who in survivors:
		if who.alive(): live.append(who)
	return live

# The player nodes, for enemies to pick a target out of.
func player_nodes() -> Array:
	var nodes: Array = []
	for who in survivors:
		if is_instance_valid(who.player): nodes.append(who.player)
	return nodes

func _ready() -> void:
	rng.randomize()
	audio = get_node("../AudioSfx") as AudioSfx
	rift_effects_enabled = rift_effects_enabled

# Shake offsets the whole session node, which carries the arena and every
# actor but not the HUD -- that lives on a sibling and has to stay still.
func add_shake(amount: float) -> void:
	shake = minf(shake + amount, Balance.SHAKE_MAX)

func hit_stop(seconds: float) -> void:
	hitstop_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	Engine.time_scale = Balance.HITSTOP_SCALE

func _process(delta: float) -> void:
	if shake > 0.0:
		shake = maxf(0.0, shake - Balance.SHAKE_DECAY * delta)
		position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	elif position != Vector2.ZERO:
		position = Vector2.ZERO

func reset_run() -> void:
	for group in [actors, shots, pickups, numbers]:
		for child in group.get_children():
			group.remove_child(child)
			child.queue_free()
	for old in survivors:
		if is_instance_valid(old.player):
			remove_child(old.player)
			old.player.queue_free()
	var fresh: Array[Survivor] = []
	survivors = fresh
	var count := 2 if coop else 1
	for i in range(count):
		survivors.append(build_survivor(i, count))
	run_time = 0.0
	spawn_timer = 0.0
	kills = 0
	round_number = 1
	round_length = round_duration
	round_time_left = round_length
	round_phase = "combat"
	shake = 0.0
	position = Vector2.ZERO

# One seat's body and starting kit. Both seats take the armory's character and
# weapon: picking one each would need a second armory screen, and that is not
# what was asked for.
func build_survivor(index: int, count: int) -> Survivor:
	var who := Survivor.new()
	who.seat = index
	who.device = "any" if count == 1 else ("keyboard" if index == 0 else "pad")
	var chosen: int = int(seat_characters[index]) if index < seat_characters.size() else selected_character
	var character := CharacterCatalog.get_character(chosen)
	who.character = chosen
	who.weapon_slots = int(character.get("slots", MAX_WEAPONS))
	who.allowed_kinds = character.get("kinds", [])
	who.shop.allowed_kinds = who.allowed_kinds
	# The armory pick only sticks if this character is allowed to hold it;
	# otherwise the character's own weapon is the fallback.
	var starter: int = int(seat_guns[index]) if index < seat_guns.size() else selected_gun
	var opening := String(GunCatalog.get_gun(starter).weapon)
	if not WeaponCatalog.allows(opening, who.allowed_kinds):
		opening = String(character.weapon)
	var rack: Array[Weapon] = [Weapon.new(opening, 1)]
	who.weapons = rack
	who.player = PLAYER_SCENE.instantiate()
	who.player.stats = who.stats
	who.player.input_source = who.device
	# Started apart in co-op, so the opening crowd does not land on both at once.
	var apart := Vector2(140.0 * (float(index) * 2.0 - float(count - 1)), 0.0)
	who.player.position = Arena.BOUNDS.get_center() + apart
	add_child(who.player)
	who.player.died.connect(on_survivor_died.bind(who))
	who.player.was_hit.connect(on_player_hit)
	(who.player.get_node("Magnet") as Area2D).area_entered.connect(on_magnet_touched.bind(who))
	who.player.hp = who.player.max_hp
	who.player.weapons = who.weapons
	who.player.refresh_pickup_radius()
	return who

# Down, not out. A downed survivor is gone for the rest of the round and comes
# back at the start of the next one -- so the run only ends when nobody is left
# standing, and holding out alone to the end of a wave is worth playing for.
func on_survivor_died(who: Survivor) -> void:
	who.downed = true
	who.player.set_downed(true)
	if living().is_empty(): run_ended.emit()

func revive(who: Survivor) -> void:
	who.downed = false
	who.player.set_downed(false)
	# Half health, because going down has to cost something. Otherwise the safest
	# play is to throw yourself at the crowd and wait for the round to tick over.
	who.player.hp = who.player.max_hp * Balance.REVIVE_HP
	who.player.position = Arena.BOUNDS.get_center()
	audio.play("heal", 3.0)

func on_player_hit() -> void:
	add_shake(Balance.SHAKE_PLAYER_HIT)
	audio.play("player_hurt", 2.0)

# With no argument every survivor keeps the character it was built with, which
# is what co-op needs -- the two seats picked separately. Solo passes the one
# armory selection and it lands on everybody.
func apply_character(index: int = -1) -> void:
	if survivors.is_empty(): return
	if index >= 0:
		selected_character = index
		for who in survivors: who.character = index
	for who in survivors:
		if not is_instance_valid(who.player): continue
		var character := CharacterCatalog.get_character(who.character)
		rebuild_stats(false, who)
		who.player.base_speed = float(character.speed)
		# A full modulate drains the sprite art, so the character colour is only
		# mixed in as a tint. The second seat is pushed warm so the two players
		# can tell themselves apart in a crowd.
		var shade: Color = character.color if who.seat == 0 else character.color.lerp(Color("ffcf77"), 0.6)
		who.player.tint = Color.WHITE.lerp(shade, 0.35)
		who.player.hp = who.player.max_hp
		who.player.refresh_pickup_radius()

# Wave clock and spawning only. Movement, collision and pickup drift all run in
# the actor _physics_process callbacks, which the tree pauses with the game.
func tick(delta: float) -> void:
	run_time += delta
	for who in survivors:
		who.nova_cooldown = maxf(0.0, who.nova_cooldown - delta)
	aim_players()
	if round_phase == "shop" or round_phase == "won": return
	if round_phase == "combat":
		round_time_left = maxf(0.0, round_time_left - delta)
		spawn_enemies(delta)
		if round_time_left <= 0.0: round_phase = "cleanup"
	fire_weapons(delta)
	if round_phase == "cleanup" and actors.get_child_count() == 0:
		if round_number >= Balance.FINAL_WAVE:
			round_phase = "won"
			audio.play("victory", 2.0)
			run_won.emit()
		else:
			finish_wave()

# The wave ends into the shop rather than a timer, which is where a run
# actually gets built. begin_round is only reached when the player leaves it.
func finish_wave() -> void:
	round_phase = "shop"
	heal_between_waves()
	# A board each, so the two players are not fighting over the same offers.
	for who in survivors:
		var harvest := int(who.stats.get_stat("harvesting"))
		if harvest > 0: who.materials += harvest
		who.ready = false
		who.shop.allowed_kinds = who.allowed_kinds
		who.shop.owned_classes = class_counts(who).keys()
		who.shop.open(rng, round_number, who.stats.get_stat("luck"))
	audio.play("wave_clear")
	wave_cleared.emit()

# Both seats have to press NEXT WAVE. Returns whether everyone is now waiting,
# which is what actually starts the round.
func mark_ready(at_seat: int = 0) -> bool:
	seat(at_seat).ready = true
	return all_ready()

func all_ready() -> bool:
	for who in survivors:
		if not who.ready: return false
	return true

func begin_round() -> void:
	# Anyone who went down last wave comes back now, because somebody was still
	# standing when it ended -- had nobody been, the run would already be over.
	for who in survivors:
		if who.downed: revive(who)
		who.ready = false
	round_number += 1
	round_length = round_duration + minf(20.0, float(round_number - 1) * 2.0)
	round_time_left = round_length
	round_phase = "combat"
	spawn_timer = 0.15
	if round_number % 5 == 0:
		var top := Vector2(Arena.BOUNDS.get_center().x, Arena.BOUNDS.position.y + 70.0)
		spawn_enemy(EnemyCatalog.boss(round_number), top, true)
		audio.play("boom", 3.0)

# Surviving a wave pays back part of the bar. Once per wave and capped at max
# HP, so unlike the per-kill heal it cannot be farmed -- and it is what stops a
# run being a one-way ratchet where wave 6 is fought on wave 1's leftovers.
# The missing-health share means a wave survived at a sliver recovers more than
# a wave walked through untouched, without ever exceeding the cap.
func heal_between_waves() -> void:
	for who in living():
		var flat := who.player.max_hp * Balance.WAVE_CLEAR_HEAL
		var missing := maxf(0.0, who.player.max_hp - who.player.hp) * Balance.WAVE_CLEAR_HEAL_MISSING
		who.player.heal(flat + missing)

# --- shop transactions -------------------------------------------------------

func offer_affordable(index: int, at_seat: int = 0) -> bool:
	var who := seat(at_seat)
	if index < 0 or index >= who.shop.offers.size(): return false
	var offer: Dictionary = who.shop.offers[index]
	return not offer.is_empty() and who.materials >= int(offer.price)

func buy(index: int, at_seat: int = 0) -> bool:
	if not offer_affordable(index, at_seat): return false
	var who := seat(at_seat)
	var offer: Dictionary = who.shop.offers[index]
	if offer.kind == "weapon":
		if not WeaponCatalog.allows(String(offer.id), who.allowed_kinds): return false
		# A full rack is a hard block now that merging is deliberate. It is not a
		# dead end: two of a kind can be combined right there in the shop, which
		# frees the slot the purchase needs.
		if who.weapons.size() >= who.weapon_slots: return false
	who.materials -= int(offer.price)
	who.shop.take(index)
	if offer.kind == "weapon": add_weapon(String(offer.id), int(offer.tier), who)
	else: add_item(String(offer.id), who)
	audio.play("buy")
	return true

func reroll_shop(at_seat: int = 0) -> bool:
	var who := seat(at_seat)
	var cost := who.shop.reroll_cost()
	if who.materials < cost: return false
	who.materials -= cost
	who.shop.owned_classes = class_counts(who).keys()
	who.shop.reroll(rng, round_number, who.stats.get_stat("luck"))
	audio.play("reroll")
	return true

func sell_weapon(index: int, at_seat: int = 0) -> bool:
	var who := seat(at_seat)
	if index < 0 or index >= who.weapons.size() or who.weapons.size() <= 1: return false
	who.materials += who.weapons[index].sell_value()
	who.weapons.remove_at(index)
	rebuild_stats(false, who)
	audio.play("sell")
	return true

func add_weapon(id: String, tier: int, who: Survivor = null) -> void:
	var owner := who if who != null else me
	owner.weapons.append(Weapon.new(id, tier))
	rebuild_stats(false, owner)

# Two of the same weapon at the same tier merge into one a tier higher.
#
# This is a shop action the player takes, not something that happens to them.
# It used to fire on its own at three of a kind, which meant the interesting
# decision -- a second barrel firing now, or one weapon that hits far harder --
# was made for you the moment you bought the third. An automatic rule and a
# button would also be two sources of truth for the same merge, and the
# automatic one would always win before the button could be pressed.
func combine_partner(index: int, at_seat: int = 0) -> int:
	var who := seat(at_seat)
	if index < 0 or index >= who.weapons.size(): return -1
	var weapon: Weapon = who.weapons[index]
	if weapon.tier >= WeaponCatalog.MAX_TIER: return -1
	for i in range(who.weapons.size()):
		if i == index: continue
		if who.weapons[i].id == weapon.id and who.weapons[i].tier == weapon.tier: return i
	return -1

func can_combine(index: int, at_seat: int = 0) -> bool:
	return combine_partner(index, at_seat) >= 0

func combine_weapon(index: int, at_seat: int = 0) -> bool:
	var partner := combine_partner(index, at_seat)
	if partner < 0: return false
	var who := seat(at_seat)
	var weapons: Array[Weapon] = who.weapons
	var weapon: Weapon = weapons[index]
	var id := weapon.id
	var tier := weapon.tier
	# The rack is mutated in place, never reassigned: the player node holds the
	# same array to draw the weapons orbiting it, and a fresh one would leave it
	# drawing the old rack. Higher index first, or the second erase shifts under
	# itself and takes the wrong weapon.
	weapons.remove_at(maxi(index, partner))
	weapons.remove_at(mini(index, partner))
	weapons.append(Weapon.new(id, tier + 1))
	# Weapon count feeds the class bonuses and every per-weapon item, and it just
	# went down by one, so the whole sheet has to be recomputed.
	rebuild_stats(false, who)
	audio.play("merge", 2.0)
	return true

func add_item(id: String, who: Survivor = null) -> void:
	var owner := who if who != null else me
	owner.items.append(id)
	rebuild_stats(true, owner)

# What a `per` item counts. Anything added here becomes available to every
# synergy item at once.
func synergy_count(of: String, who: Survivor = null) -> int:
	var owner := who if who != null else me
	match of:
		"weapons": return owner.weapons.size()
		"items": return owner.items.size()
		"empty_slots": return maxi(0, owner.weapon_slots - owner.weapons.size())
		"melee":
			var melee := 0
			for weapon in owner.weapons:
				if weapon.kind() == "melee": melee += 1
			return melee
	return 0

# Items can scale off the rest of the build, so the sheet cannot be added to
# once and forgotten -- selling a weapon has to take an Arsenal Link bonus with
# it. Everything is recomputed from the character, the level-ups and the items.
# How many of each weapon class are equipped. A weapon in two classes counts
# for both, which is what makes those weapons worth more than their numbers.
func class_counts(who: Survivor = null) -> Dictionary:
	var owner := who if who != null else me
	var counts := {}
	if owner == null: return counts
	for weapon in owner.weapons:
		for id in WeaponCatalog.classes_of(weapon.id):
			counts[id] = int(counts.get(id, 0)) + 1
	return counts

# The bonus for a class at a given count: one step per weapon past the first.
func class_steps(count: int) -> int:
	return clampi(count - 1, 0, WeaponCatalog.CLASS_STEP_CAP)

func rebuild_stats(heal_gain: bool = false, who: Survivor = null) -> void:
	var owner := who if who != null else me
	if owner == null: return
	var before := owner.stats.get_stat("max_hp")
	var fresh := Stats.new()
	var character := CharacterCatalog.get_character(owner.character)
	fresh.set_stat("max_hp", float(character.hp))
	fresh.apply_dict(character.get("stats", {}))
	fresh.apply_dict(owner.upgrade_totals)
	for id in owner.items:
		var def := ItemCatalog.get_item(id)
		fresh.apply_dict(def.stats)
		if def.has("per"):
			var per: Dictionary = def.per
			fresh.add(String(per.stat), float(per.amount) * float(synergy_count(String(per.of), owner)))
	# Weapon class set bonuses, applied after the items so a class bonus and a
	# per-item bonus can both land on the same stat.
	var counts := class_counts(owner)
	for id in counts:
		var steps := class_steps(int(counts[id]))
		if steps <= 0: continue
		var spec: Dictionary = WeaponCatalog.CLASSES[id]
		for stat in spec.per_step:
			fresh.add(String(stat), float(spec.per_step[stat]) * float(steps))
	owner.stats = fresh
	if not is_instance_valid(owner.player): return
	owner.player.stats = owner.stats
	var gained := owner.stats.get_stat("max_hp") - before
	if heal_gain and gained > 0.0: owner.player.hp += gained
	owner.player.hp = clampf(owner.player.hp, 0.0, owner.player.max_hp)
	owner.player.refresh_pickup_radius()

# --- combat ------------------------------------------------------------------

func spawn_enemies(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0: return
	# Two players kill far faster than one, so the crowd arrives faster too.
	var crowd := 1.0 + Balance.COOP_SPAWN * float(maxi(0, survivors.size() - 1))
	spawn_timer = maxf(Balance.SPAWN_INTERVAL_MIN, Balance.SPAWN_INTERVAL / Balance.intensity(round_number) * Balance.danger_spawn(danger) / crowd)
	var options := EnemyCatalog.available(round_number)
	var elite_odds := Balance.elite_chance(round_number)
	for count in range(1 + int(round_number / Balance.SPAWN_BATCH_EVERY)):
		var def: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		spawn_enemy(def, spawn_point(), false, rng.randf() < elite_odds)

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
		# Clear of everybody, not just seat 0: in co-op an enemy dropped on the
		# other player's head is exactly as unfair.
		var crowded := false
		for who in living():
			if p.distance_to(who.player.position) <= 190.0: crowded = true
		if not crowded: return p
	return band.position

func spawn_enemy(def: Dictionary, at: Vector2, is_boss: bool, is_elite: bool = false) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.position = at
	actors.add_child(enemy)
	enemy.configure(def, round_number, player_nodes(), is_boss, is_elite)
	enemy.apply_danger(danger)
	# Two racks put out well over twice one player's damage -- most of the sheet
	# is per-weapon -- so the crowd needs more than twice the health to match.
	if survivors.size() > 1:
		enemy.max_hp *= 1.0 + Balance.COOP_ENEMY_HP * float(survivors.size() - 1)
		enemy.hp = enemy.max_hp
	enemy.died.connect(on_enemy_died)
	enemy.damaged.connect(on_enemy_damaged)
	enemy.wants_shot.connect(on_enemy_shot)
	return enemy

func on_enemy_damaged(at: Vector2, amount: float, crit: bool) -> void:
	audio.play("crit" if crit else "hit", -6.0 if crit else -15.0)
	if numbers.get_child_count() >= MAX_NUMBERS: return
	var number: DamageNumber = NUMBER_SCENE.instantiate()
	number.setup(at, amount, crit)
	# Added straight away, not deferred: a DamageNumber carries no collision
	# shape, so the physics server has no objection, and deferring would make
	# the cap above read a stale count and let every hit through.
	numbers.add_child(number)

# Distances are measured from a point rather than from "the player", because in
# co-op each survivor's weapons pick their own targets from where they stand.
func nearest_enemy_to(origin: Vector2, within: float = INF) -> Enemy:
	var best: Enemy = null
	var best_distance := within * within
	for node in actors.get_children():
		var enemy := node as Enemy
		if enemy == null or not enemy.alive: continue
		var distance: float = origin.distance_squared_to(enemy.position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best

func nearest_enemy(within: float = INF) -> Enemy:
	if not is_instance_valid(player): return null
	return nearest_enemy_to(player.position, within)

func aim_players() -> void:
	for who in survivors:
		if not is_instance_valid(who.player) or who.downed: continue
		var target := nearest_enemy_to(who.player.position)
		if target != null: who.player.aim_at(target.global_position)
		else: who.player.face_travel()

# Each weapon runs its own cooldown and picks its own target inside its own
# reach, so a short shotgun and a long rifle behave differently on the same
# frame instead of sharing one timer.
func fire_weapons(delta: float) -> void:
	for who in living(): fire_for(who, delta)

func fire_for(who: Survivor, delta: float) -> void:
	var player: Player = who.player
	var stats: Stats = who.stats
	# The rack drawn around the player reads straight off this list.
	player.weapons = who.weapons
	for weapon in who.weapons:
		weapon.flash = maxf(0.0, weapon.flash - delta)
		# An orbital is always out there grinding, so it never waits for a
		# target to come into reach the way the others do.
		if weapon.kind() == "orbital":
			tick_orbital(who, weapon, delta)
			continue
		weapon.timer -= delta
		if weapon.timer > 0.0: continue
		var reach := weapon.attack_range(stats)
		var target := nearest_enemy_to(player.position, reach)
		if target == null:
			# Nothing in range: settle in behind the way the player is facing.
			weapon.aim = lerp_angle(weapon.aim, player.last_move.angle(), 0.15)
			continue
		weapon.aim = (target.position - player.position).angle()
		weapon.timer = weapon.cooldown(stats)
		weapon.flash = 0.09
		fire(who, weapon, target, reach)

func fire(who: Survivor, weapon: Weapon, target: Enemy, reach: float) -> void:
	if weapon.kind() == "melee":
		swing_melee(who, weapon, target, reach)
		return
	fire_shots(who, weapon, target, reach)

# A sweep in front of the player: no projectile, everything inside the wedge is
# hit at once and shoved back.
func swing_melee(who: Survivor, weapon: Weapon, target: Enemy, reach: float) -> void:
	var player: Player = who.player
	var stats: Stats = who.stats
	var def := weapon.def()
	var facing: Vector2 = (target.position - player.position).normalized()
	var arc := float(def.get("arc", 1.8))
	var damage := weapon.damage(stats)
	var knock := float(def.get("knockback", 260.0))
	for node in actors.get_children():
		var enemy := node as Enemy
		if enemy == null or not enemy.alive: continue
		var offset: Vector2 = enemy.position - player.position
		if offset.length() > reach + enemy.radius: continue
		if absf(facing.angle_to(offset)) > arc * 0.5: continue
		var crit := stats.roll_crit(rng)
		enemy.push(offset, knock)
		enemy.take_damage(damage * crit, crit > 1.0)
	var swing: MeleeSwing = SWING_SCENE.instantiate()
	swing.position = player.position
	swing.setup(facing.angle(), arc, reach, def.color)
	add_child(swing)
	audio.play("shoot_%s" % def.get("sound", "medium"), -7.0)

# Circles the player and damages whatever it passes over, on its own cooldown
# so it grinds rather than deleting a crowd on contact.
func tick_orbital(who: Survivor, weapon: Weapon, delta: float) -> void:
	var player: Player = who.player
	var stats: Stats = who.stats
	var def := weapon.def()
	weapon.orbit += delta * float(def.get("orbit_speed", 2.2))
	weapon.aim = weapon.orbit + PI * 0.5
	weapon.orbit_radius = float(def.get("orbit_radius", 110.0)) * stats.range_multiplier()
	weapon.timer -= delta
	if weapon.timer > 0.0: return
	var spot: Vector2 = player.position + Vector2.RIGHT.rotated(weapon.orbit) * weapon.orbit_radius
	var hit := float(def.get("orbit_hit", 34.0))
	var struck := false
	for node in actors.get_children():
		var enemy := node as Enemy
		if enemy == null or not enemy.alive: continue
		if enemy.position.distance_to(spot) > hit + enemy.radius: continue
		var crit := stats.roll_crit(rng)
		enemy.take_damage(weapon.damage(stats) * crit, crit > 1.0)
		struck = true
	if struck:
		weapon.timer = weapon.cooldown(stats)
		weapon.flash = 0.09
		audio.play("hit", -16.0)

func fire_shots(who: Survivor, weapon: Weapon, target: Enemy, reach: float) -> void:
	var player: Player = who.player
	var stats: Stats = who.stats
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
		var shot := add_shot(who, direction.rotated(offset), bullet_speed, life, damage * crit, def.color, int(def.pierce), crit > 1.0)
		var homing := float(def.get("homing", 0.0))
		if homing > 0.0: shot.chase(target, homing)
	audio.play("shoot_%s" % def.get("sound", "light"), -13.0 if weapon.cooldown(stats) < 0.25 else -6.0)

func add_shot(who: Survivor, direction: Vector2, speed: float, life: float, damage: float, color: Color, pierce: int, is_crit: bool = false) -> Projectile:
	var shot: Projectile = SHOT_SCENE.instantiate()
	shots.add_child(shot)
	shot.launch(who.player.position, direction, speed, damage, life, color, pierce, false, is_crit)
	# Bound to the seat that fired it, so lifesteal pays the player who shot
	# rather than whoever happens to be seat 0.
	shot.dealt_damage.connect(on_damage_dealt.bind(who))
	return shot

func on_damage_dealt(amount: float, who: Survivor = null) -> void:
	var owner := who if who != null else me
	if owner == null: return
	var leech := owner.stats.get_stat("lifesteal")
	if leech <= 0.0 or not is_instance_valid(owner.player): return
	# Capped per hit: a piercing weapon reports a hit per enemy, and a crit
	# multiplies the amount, so an uncapped percentage refilled the bar from a
	# single shot into a crowd.
	var ceiling := owner.player.max_hp * Balance.LIFESTEAL_MAX_PER_HIT
	owner.player.heal(minf(amount * leech / 100.0, ceiling))

func on_enemy_shot(from: Vector2, direction: Vector2, damage: float, shot_speed: float) -> void:
	var shot: Projectile = SHOT_SCENE.instantiate()
	shots.add_child(shot)
	shot.launch(from, direction, shot_speed, damage, 3.0, Color("ff9f6d"), 0, true)

func on_enemy_died(at: Vector2, material_value: int, was_boss: bool, definition: Dictionary = {}) -> void:
	kills += 1
	if definition.has("explodes"): explode(at, definition.explodes)
	if definition.has("splits"): split(at, definition.splits)
	audio.play("kill", -3.0)
	if was_boss:
		add_shake(Balance.SHAKE_BOSS_DEATH)
		hit_stop(Balance.HITSTOP_BOSS_DEATH)
	else:
		add_shake(Balance.SHAKE_KILL)
	drop_pickup(at, material_value, Pickup.KIND_MATERIAL)
	# Luck nudges the bandage roll, so the stat is worth something outside the
	# shop as well.
	var bandage_odds: float = Balance.HEALTH_DROP_CHANCE * (1.0 + stats.get_stat("luck") / 200.0)
	if rng.randf() < bandage_odds:
		drop_pickup(at, Balance.HEALTH_DROP_AMOUNT, Pickup.KIND_HEALTH)
	# A steady trickle as well, so a long clean wave still repays the player
	# when no bandage happens to roll.
	if kills % Balance.HEAL_EVERY_KILLS == 0:
		for who in living(): who.player.heal(Balance.HEAL_ON_KILLS)

# A bloater hurts the player on death, so killing one at your feet is a real
# mistake rather than free materials.
func explode(at: Vector2, spec: Dictionary) -> void:
	var radius := float(spec.get("radius", 150.0))
	var blast: NovaBlast = NOVA_SCENE.instantiate()
	blast.position = at
	blast.radius = radius
	blast.tint = Color(1.0, 0.55, 0.3)
	add_child(blast)
	add_shake(Balance.SHAKE_NOVA * 0.5)
	audio.play("boom", -4.0)
	for who in living():
		if who.player.position.distance_to(at) <= radius:
			who.player.hurt(float(spec.get("damage", 25.0)))

# Splits are spawned deferred: this runs inside the projectile collision
# callback, and the physics server will not take a new body mid-query.
func split(at: Vector2, spec: Dictionary) -> void:
	for i in range(int(spec.get("count", 2))):
		var offset := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(24.0, 48.0)
		spawn_split.call_deferred(String(spec.get("into", "husk")), at + offset)

func spawn_split(id: String, at: Vector2) -> void:
	if round_phase == "shop" or round_phase == "won": return
	# A parent killed against the wall would otherwise drop its children inside
	# it, where the walls hold them out of reach.
	var band := Arena.BOUNDS.grow(-24.0)
	var spot := Vector2(clampf(at.x, band.position.x, band.end.x), clampf(at.y, band.position.y, band.end.y))
	spawn_enemy(EnemyCatalog.get_enemy(id), spot, false)

func drop_pickup(at: Vector2, amount: int, kind: String) -> void:
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	pickup.setup(at, amount, kind)
	pickup.collected.connect(on_pickup_collected)
	# This runs inside the projectile collision callback, and the physics
	# server refuses to have an Area2D added while it is flushing queries.
	pickups.add_child.call_deferred(pickup)

# Whichever magnet touched it claims it, which is what makes spreading out to
# collect worth doing rather than both standing on the same pile.
func on_magnet_touched(area: Area2D, who: Survivor = null) -> void:
	var owner := who if who != null else me
	if not (area is Pickup) or owner == null or not owner.alive(): return
	var pickup := area as Pickup
	# First magnet to reach it wins, so two players cannot both claim one drop.
	if pickup.target != null: return
	pickup.attract(owner.player)
	# Rebound to the seat that caught it: the drop was connected before anyone
	# had touched it, and the materials and XP belong to whoever did.
	if pickup.collected.is_connected(on_pickup_collected):
		pickup.collected.disconnect(on_pickup_collected)
	pickup.collected.connect(on_pickup_collected.bind(owner))

# Materials are both the shop currency and the level track, as in Brotato:
# one pickup pays into each, and both belong to whoever walked over it.
func on_pickup_collected(value: int, kind: String = Pickup.KIND_MATERIAL, who: Survivor = null) -> void:
	var owner := who if who != null else me
	if owner == null: return
	if kind == Pickup.KIND_HEALTH:
		if is_instance_valid(owner.player): owner.player.heal(float(value))
		audio.play("heal", 2.0)
		return
	owner.materials += value
	owner.xp += value
	audio.play("pickup", -9.0)
	if owner.xp >= owner.xp_to_next:
		owner.xp -= owner.xp_to_next
		owner.level += 1
		owner.xp_to_next = Balance.next_level_xp(owner.xp_to_next)
		audio.play("level_up", 2.0)
		owner.upgrades = UpgradeCatalog.roll_choices(rng, round_number, owner.stats.get_stat("luck"))
		level_up_requested.emit()

func choose_upgrade(index: int, at_seat: int = 0) -> void:
	var who := seat(at_seat)
	if index < 0 or index >= who.upgrades.size(): return
	for key in who.upgrades[index].stats:
		who.upgrade_totals[key] = float(who.upgrade_totals.get(key, 0.0)) + float(who.upgrades[index].stats[key])
	# Cleared so the overlay knows this seat is done; it stays up while anybody
	# still has a choice in front of them.
	var empty: Array[Dictionary] = []
	who.upgrades = empty
	rebuild_stats(true, who)

# Anybody still owed a level-up choice. The overlay is up while this is true.
func anyone_choosing() -> bool:
	for who in survivors:
		if who.choosing(): return true
	return false

func dash(at_seat: int = 0) -> void:
	var who := seat(at_seat)
	if who.alive() and who.player.dash(): audio.play("dash")

# Rift Nova: a shockwave that damages and throws everything around the player.
# The visual is a separate node so the ring can outlive the frame the damage
# lands on, which is what makes it read as an attack rather than a stat tick.
func rift_nova(at_seat: int = 0) -> void:
	var who := seat(at_seat)
	if who.nova_cooldown > 0.0 or not who.alive(): return
	var player: Player = who.player
	var punch := Balance.NOVA_DAMAGE * who.stats.damage_multiplier()
	var reach := Balance.NOVA_RADIUS
	var blast: NovaBlast = NOVA_SCENE.instantiate()
	blast.position = player.position
	blast.radius = reach
	add_child(blast)
	for node in actors.get_children():
		var enemy := node as Enemy
		if enemy == null: continue
		var offset: Vector2 = enemy.position - player.position
		if offset.length() > reach: continue
		# Closer enemies take the full hit and are thrown hardest.
		var falloff: float = 1.0 - clampf(offset.length() / reach, 0.0, 1.0) * 0.55
		enemy.push(offset, Balance.NOVA_KNOCKBACK * falloff)
		enemy.take_damage(punch * falloff)
	who.nova_cooldown = Balance.NOVA_COOLDOWN
	add_shake(Balance.SHAKE_NOVA)
	hit_stop(Balance.HITSTOP_NOVA)
	audio.play("nova", 3.0)

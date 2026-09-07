class_name Enemy
extends CharacterBody2D

signal died(at: Vector2, material_value: int, was_boss: bool, definition: Dictionary)
signal damaged(at: Vector2, amount: float, crit: bool)
signal wants_shot(from: Vector2, direction: Vector2, damage: float, shot_speed: float)

var definition: Dictionary = {}
var hp := 10.0
var max_hp := 10.0
var speed := 60.0
var radius := 13.0
var contact_damage := 8.0
var attack_cooldown := 0.9
var attack_timer := 0.0
var material_value := 1
var behaviour := "chase"
var attack_range := 0.0
var bullet_speed := 0.0
var hit_flash := 0.0
var wobble := 0.0
var knockback := Vector2.ZERO
var is_elite := false
var is_boss := false
# Charger state machine: approach, wind up on the spot, dash, recover.
var charge_state := "ready"
var charge_timer := 0.0
var charge_dir := Vector2.RIGHT
var age := 0.0
var alive := true
var tint := Color.WHITE
# A hop, a breath and a flinch on a sprite that has no frames. See sprite_anim.
var anim := SpriteAnim.new()
# Whoever this enemy is currently going for. In solo that is the only player
# there is; in co-op it is re-picked every frame, so a crowd splits between the
# two survivors and follows whichever one comes closer.
var player: Player = null
var targets: Array = []

# Everything this emits is in *session* space, not global.
#
# The session is scaled and offset so the oversized arena lands on its view, and
# what these values become is another node's local position -- a bullet, a drop,
# a damage number, a blast. Handing out global_position there gets it
# transformed a second time, which put all of them a growing distance from where
# they actually happened. It was invisible for as long as the session sat at
# identity. Comparisons between two globals (a distance, a direction) are fine
# and stay as they are.

# Called straight after add_child(). $Sprite / $Body resolve as soon as the
# scene is instantiated, so this does not depend on _ready having run.
func configure(def: Dictionary, round_number: int, who: Array, boss: bool = false, elite: bool = false) -> void:
	definition = def
	is_boss = boss
	is_elite = elite and not boss
	targets = who
	player = closest_target()
	behaviour = String(def.behaviour)
	tint = def.get("tint", Color.WHITE)
	if is_boss:
		max_hp = Balance.boss_hp(round_number)
		speed = Balance.BOSS_SPEED_BASE + round_number * Balance.BOSS_SPEED_PER_ROUND
	else:
		max_hp = Balance.enemy_hp(round_number, float(def.hp))
		var roll := randf_range(Balance.ENEMY_SPEED_MIN, Balance.ENEMY_SPEED_MAX)
		speed = (roll + round_number * Balance.ENEMY_SPEED_PER_ROUND) * float(def.speed)
	hp = max_hp
	radius = float(def.radius)
	contact_damage = float(def.damage) + round_number * Balance.ENEMY_DAMAGE_PER_ROUND
	attack_cooldown = float(def.cooldown)
	attack_timer = randf_range(0.0, attack_cooldown)
	material_value = int(def.material)
	attack_range = float(def.get("range", 0.0))
	bullet_speed = float(def.get("bullet_speed", 0.0))
	wobble = randf() * TAU
	# An elite is any enemy, scaled up in every direction at once, so the
	# threat reads without needing its own art.
	if is_elite:
		max_hp *= Balance.ELITE_HP
		hp = max_hp
		speed *= Balance.ELITE_SPEED
		radius *= Balance.ELITE_SCALE
		material_value *= Balance.ELITE_MATERIALS
	var sprite := $Sprite as Sprite2D
	sprite.texture = load("res://assets/sprites/%s.png" % def.texture)
	sprite.scale = Vector2.ONE * float(def.scale) * Balance.ACTOR_SCALE * (Balance.ELITE_SCALE if is_elite else 1.0)
	sprite.modulate = tint
	anim.begin(sprite)
	# A bloater breathes visibly, because it is the brute's sprite in another
	# colour and it has to be pickable out of a crowd before it dies.
	if def.has("explodes"): anim.swell = 0.06
	var shape := $Body as CollisionShape2D
	shape.shape = shape.shape.duplicate()
	shape.shape.radius = radius
	queue_redraw()

# Applied after configure, so the danger ladder scales whatever the round curve
# and the elite roll already produced rather than fighting with them.
func apply_danger(danger: int) -> void:
	if danger <= 0: return
	max_hp *= Balance.danger_hp(danger)
	hp = max_hp
	speed *= Balance.danger_speed(danger)
	material_value = int(ceil(float(material_value) * Balance.danger_materials(danger)))

# The nearest one still standing. A downed survivor is not a target -- its body
# stays in the tree so its inventory survives, and enemies would otherwise pile
# onto a corpse while the live player went unbothered.
func closest_target() -> Player:
	var best: Player = null
	var best_distance := INF
	for node in targets:
		var candidate := node as Player
		if candidate == null or not is_instance_valid(candidate): continue
		if not candidate.alive or candidate.downed: continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _physics_process(delta: float) -> void:
	if not alive: return
	player = closest_target()
	if player == null: return
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	var sprite := $Sprite as Sprite2D
	# Bright enough to read as a hit, not so bright the silhouette is lost --
	# a boss under sustained fire is in this state a good part of the time.
	if hit_flash > 0.0: sprite.modulate = tint * 1.75
	elif charge_state == "windup": sprite.modulate = tint * 1.6
	else: sprite.modulate = tint
	# Last frame's velocity is plenty: this is a hop, not a simulation.
	anim.tick(sprite, delta, velocity.length() / maxf(speed, 1.0))
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player / maxf(distance, 0.001)
	# Flipped, not rotated. These sprites face the camera rather than a
	# direction, and spinning a front-facing character reads as a compass
	# needle. A near-vertical approach keeps whichever way it was already
	# facing, so an enemy directly above does not flicker between the two.
	if absf(direction.x) > 0.08: sprite.flip_h = direction.x < 0.0
	match behaviour:
		"weave":
			velocity = direction.rotated(sin(age * 5.0 + wobble) * 0.7) * speed
		"charge":
			velocity = tick_charge(delta, direction, distance)
		"shooter":
			# Hold the firing line: close in when out of range, back off when
			# the player closes, so gunners stay a ranged threat.
			if distance > attack_range: velocity = direction * speed
			elif distance < attack_range * 0.65: velocity = -direction * speed * 0.55
			else: velocity = direction.orthogonal() * speed * 0.4
			if attack_timer <= 0.0 and distance <= attack_range * 1.1:
				attack_timer = attack_cooldown
				wants_shot.emit(position, direction, contact_damage, bullet_speed)
		_:
			velocity = direction * speed
	# Knockback rides on top of the steering and bleeds off, so a nova throws
	# the crowd outward without permanently changing where they are heading.
	velocity += knockback
	knockback = knockback.move_toward(Vector2.ZERO, 1500.0 * delta)
	# Enemies collide with each other, so a crowd spreads out under its own
	# pressure instead of stacking into one sprite the way the old sim did.
	move_and_slide()
	# The bloater's aura pulses, so it needs a redraw every frame the way the
	# charger's wind-up ring does.
	if charge_state == "windup" or definition.has("explodes"): queue_redraw()
	if behaviour != "shooter" and distance < radius + Player.BODY_RADIUS + 2.0 and attack_timer <= 0.0:
		attack_timer = attack_cooldown
		player.hurt(contact_damage)

func push(direction: Vector2, force: float) -> void:
	knockback = direction.normalized() * force

func take_damage(amount: float, crit: bool = false) -> void:
	if not alive: return
	hp -= amount
	hit_flash = 0.07
	anim.hit()
	damaged.emit(position, amount, crit)
	queue_redraw()
	if hp <= 0.0:
		alive = false
		died.emit(position, material_value, is_boss, definition)
		queue_free()

# Winding up is telegraphed by standing still and glowing, so a charge is
# something you can react to rather than something that just happens.
func tick_charge(delta: float, direction: Vector2, distance: float) -> Vector2:
	charge_timer = maxf(0.0, charge_timer - delta)
	var reach := float(definition.get("charge_range", 320.0))
	match charge_state:
		"windup":
			if charge_timer <= 0.0:
				charge_state = "dash"
				charge_timer = float(definition.get("charge_time", 0.5))
				charge_dir = direction
			return Vector2.ZERO
		"dash":
			if charge_timer <= 0.0:
				charge_state = "cool"
				charge_timer = 1.1
			return charge_dir * speed * float(definition.get("charge_speed", 5.0))
		"cool":
			if charge_timer <= 0.0: charge_state = "ready"
			return direction * speed * 0.5
		_:
			if distance < reach:
				charge_state = "windup"
				charge_timer = float(definition.get("charge_windup", 0.65))
				return Vector2.ZERO
			return direction * speed

func _draw() -> void:
	if charge_state == "windup":
		var wind := 1.0 - charge_timer / maxf(float(definition.get("charge_windup", 0.65)), 0.01)
		draw_arc(Vector2.ZERO, radius + 6.0 + wind * 8.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.4, 0.8), 3.0)
	# The bloater kills from its own corpse, so it has to be readable as the
	# thing that is going to do it while it is still alive.
	if definition.has("explodes"):
		var swell := 3.0 + sin(age * 6.0 + wobble) * 2.5
		draw_arc(Vector2.ZERO, radius + swell, 0.0, TAU, 24, Color(1.0, 0.46, 0.22, 0.8), 2.5)
		draw_arc(Vector2.ZERO, radius + swell + 4.0, 0.0, TAU, 24, Color(1.0, 0.30, 0.16, 0.35), 2.0)
	if is_elite:
		var pulse := 3.0 + sin(age * 4.0) * 2.0
		draw_arc(Vector2.ZERO, radius + pulse, 0.0, TAU, 28, Color(1.0, 0.78, 0.28, 0.75), 3.0)
		draw_arc(Vector2.ZERO, radius + pulse + 6.0, 0.0, TAU, 28, Color(1.0, 0.55, 0.25, 0.30), 2.0)
	if hp >= max_hp: return
	var width := radius * 2.2
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var top := -radius - 13.0
	draw_rect(Rect2(-width * 0.5, top, width, 4.0), Color(0.13, 0.08, 0.15, 0.85))
	draw_rect(Rect2(-width * 0.5, top, width * ratio, 4.0), Color("ff718b"))

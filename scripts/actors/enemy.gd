class_name Enemy
extends CharacterBody2D

signal died(at: Vector2, material_value: int)
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
var age := 0.0
var alive := true
var tint := Color.WHITE
var player: Player = null

# Called straight after add_child(). $Sprite / $Body resolve as soon as the
# scene is instantiated, so this does not depend on _ready having run.
func configure(def: Dictionary, round_number: int, target: Player, is_boss: bool = false) -> void:
	definition = def
	player = target
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
	var sprite := $Sprite as Sprite2D
	sprite.texture = load("res://assets/sprites/%s.png" % def.texture)
	sprite.scale = Vector2.ONE * float(def.scale)
	sprite.modulate = tint
	var shape := $Body as CollisionShape2D
	shape.shape = shape.shape.duplicate()
	shape.shape.radius = radius
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not alive or player == null or not is_instance_valid(player): return
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	var sprite := $Sprite as Sprite2D
	# Bright enough to read as a hit, not so bright the silhouette is lost --
	# a boss under sustained fire is in this state a good part of the time.
	sprite.modulate = tint * 1.75 if hit_flash > 0.0 else tint
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player / maxf(distance, 0.001)
	sprite.rotation = direction.angle()
	match behaviour:
		"weave":
			velocity = direction.rotated(sin(age * 5.0 + wobble) * 0.7) * speed
		"shooter":
			# Hold the firing line: close in when out of range, back off when
			# the player closes, so gunners stay a ranged threat.
			if distance > attack_range: velocity = direction * speed
			elif distance < attack_range * 0.65: velocity = -direction * speed * 0.55
			else: velocity = direction.orthogonal() * speed * 0.4
			if attack_timer <= 0.0 and distance <= attack_range * 1.1:
				attack_timer = attack_cooldown
				wants_shot.emit(global_position, direction, contact_damage, bullet_speed)
		_:
			velocity = direction * speed
	# Knockback rides on top of the steering and bleeds off, so a nova throws
	# the crowd outward without permanently changing where they are heading.
	velocity += knockback
	knockback = knockback.move_toward(Vector2.ZERO, 1500.0 * delta)
	# Enemies collide with each other, so a crowd spreads out under its own
	# pressure instead of stacking into one sprite the way the old sim did.
	move_and_slide()
	if behaviour != "shooter" and distance < radius + Player.BODY_RADIUS + 2.0 and attack_timer <= 0.0:
		attack_timer = attack_cooldown
		player.hurt(contact_damage)

func push(direction: Vector2, force: float) -> void:
	knockback = direction.normalized() * force

func take_damage(amount: float) -> void:
	if not alive: return
	hp -= amount
	hit_flash = 0.07
	queue_redraw()
	if hp <= 0.0:
		alive = false
		died.emit(global_position, material_value)
		queue_free()

func _draw() -> void:
	if hp >= max_hp: return
	var width := radius * 2.2
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var top := -radius - 13.0
	draw_rect(Rect2(-width * 0.5, top, width, 4.0), Color(0.13, 0.08, 0.15, 0.85))
	draw_rect(Rect2(-width * 0.5, top, width * ratio, 4.0), Color("ff718b"))

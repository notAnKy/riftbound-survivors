class_name Player
extends CharacterBody2D

signal died
signal was_hit

const DASH_SPEED := 3.1
const DASH_TIME := 0.16
const DASH_COOLDOWN := 4.0
const BODY_RADIUS := 13.0
const BASE_PICKUP_RADIUS := 105.0
const RACK_RADIUS := 30.0

# Everything derived lives on the sheet. The session hands one in at the start
# of a run and then only ever adds to it, so an item bought in the shop changes
# health, movement, weapons and survivability from a single place.
var stats: Stats = Stats.new()
var base_speed := 290.0
var hp := 100.0
var dash_cooldown := 0.0
var dash_time := 0.0
var last_move := Vector2.RIGHT
var hit_flash := 0.0
var alive := true
var heal_flash := 0.0
# Which device steers this body. "any" in solo; in co-op each seat is pinned
# to one device so the two players cannot drag each other around.
var input_source := "any"
# Down, not dead: the body stays in the tree so the survivor's rack and stats
# are untouched, but it stops moving, colliding, magnetising and drawing until
# the next round brings it back.
var downed := false
var tint := Color.WHITE
var rng := RandomNumberGenerator.new()
# Set by the session so the equipped weapons can be drawn orbiting the
# character, each turned toward its own target.
var weapons: Array = []

var max_hp: float:
	get: return maxf(1.0, stats.get_stat("max_hp"))
var speed: float:
	get: return base_speed * stats.speed_multiplier()

func _ready() -> void:
	rng.randomize()
	# A .tscn sub-resource is shared by every instance of that scene, so the
	# radius has to be changed on a copy or it would leak to any other Player.
	var shape: CollisionShape2D = $Magnet/Shape
	shape.shape = shape.shape.duplicate()
	refresh_pickup_radius()

func refresh_pickup_radius() -> void:
	($Magnet/Shape as CollisionShape2D).shape.radius = BASE_PICKUP_RADIUS + stats.get_stat("pickup_radius")

func _physics_process(delta: float) -> void:
	if downed: return
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	if alive:
		var regen := stats.get_stat("hp_regen")
		if regen > 0.0: hp = minf(max_hp, hp + regen * delta)
	heal_flash = maxf(0.0, heal_flash - delta)
	var sprite := $Sprite as Sprite2D
	if hit_flash > 0.0: sprite.modulate = Color(2.2, 0.8, 0.8)
	elif heal_flash > 0.0: sprite.modulate = Color(0.7, 2.1, 1.2)
	else: sprite.modulate = tint
	var direction := Controls.vector_for(input_source)
	if direction != Vector2.ZERO: last_move = direction
	if dash_time > 0.0:
		dash_time -= delta
		# A dash that moves through the physics engine slides along a wall
		# instead of teleporting into it, which the old position += did.
		velocity = last_move.normalized() * speed * DASH_SPEED
	else:
		velocity = direction * speed
	move_and_slide()
	queue_redraw()

# Sprites in the Kenney pack are drawn facing +X, so an angle is all it takes.
# Drawn on the player itself, which renders before its Sprite child, so the
# rack sits behind the character rather than covering it.
func _draw() -> void:
	if downed: return
	var count := weapons.size()
	if count == 0: return
	for i in range(count):
		var weapon = weapons[i]
		# An orbital is not in the rack: it is out on its own circle.
		if weapon.kind() == "orbital":
			var spot: Vector2 = Vector2.RIGHT.rotated(weapon.orbit) * weapon.orbit_radius
			var glow: Color = weapon.def().color
			draw_circle(spot, 19.0, Color(glow.r, glow.g, glow.b, 0.18))
			draw_set_transform(spot, weapon.orbit, Vector2.ONE)
			Icons.weapon(self, weapon.id, Vector2.ZERO, 15.0, glow)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		var slot := TAU * float(i) / float(count) - PI * 0.5
		var base := Vector2.RIGHT.rotated(slot) * RACK_RADIUS
		draw_set_transform(base, weapon.aim, Vector2.ONE)
		var tint: Color = weapon.def().color
		if weapon.flash > 0.0:
			var punch: float = clampf(weapon.flash / 0.09, 0.0, 1.0)
			draw_circle(Vector2(15.0, 0.0), 5.0 + 7.0 * punch, Color(1.0, 0.93, 0.62, 0.75 * punch))
			draw_circle(Vector2(15.0, 0.0), 2.5 + 3.0 * punch, Color(1.0, 1.0, 1.0, 0.9 * punch))
		Icons.weapon(self, weapon.id, Vector2.ZERO, 12.0, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func aim_at(target: Vector2) -> void:
	($Sprite as Sprite2D).rotation = (target - global_position).angle()

func face_travel() -> void:
	($Sprite as Sprite2D).rotation = last_move.angle()

func dash() -> bool:
	if dash_cooldown > 0.0 or not alive: return false
	dash_time = DASH_TIME
	dash_cooldown = DASH_COOLDOWN
	return true

# Toggling the collision layer is what actually takes a downed player out of
# the fight: enemies mask PLAYER to find a target, so clearing the layer makes
# the body invisible to them without removing it from the tree.
func set_downed(value: bool) -> void:
	downed = value
	visible = not value
	# Deferred: this is reached from hurt(), inside a physics callback, and the
	# server will not take a collision change while it is flushing queries.
	set_deferred("collision_layer", 0 if value else Layers.PLAYER)
	($Magnet as Area2D).set_deferred("monitoring", not value)
	if not value:
		alive = true
		hit_flash = 0.0

func heal(amount: float) -> void:
	if not alive or amount <= 0.0: return
	var before := hp
	hp = minf(max_hp, hp + amount)
	# Only flash on a heal that actually did something, or lifesteal at full
	# health would leave the player permanently green.
	if hp > before + 0.01: heal_flash = 0.22

func hurt(amount: float) -> void:
	if not alive: return
	if stats.dodges(rng): return
	hp = maxf(0.0, hp - stats.damage_taken(amount))
	hit_flash = 0.1
	was_hit.emit()
	# `alive` is the latch: every damage source funnels through here, so the
	# run can only end once no matter how many enemies land a blow this frame.
	if hp <= 0.0:
		alive = false
		died.emit()

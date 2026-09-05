class_name Player
extends CharacterBody2D

signal died

const DASH_SPEED := 3.1
const DASH_TIME := 0.16
const DASH_COOLDOWN := 4.0
const BODY_RADIUS := 13.0

var max_hp := 100.0
var hp := 100.0
var speed := 290.0
var damage_mult := 1.0
var pickup_radius := 34.0
var dash_cooldown := 0.0
var dash_time := 0.0
var last_move := Vector2.RIGHT
var hit_flash := 0.0
var alive := true
var tint := Color.WHITE

func _ready() -> void:
	# A .tscn sub-resource is shared by every instance of that scene, so the
	# radius has to be changed on a copy or it would leak to any other Player.
	var shape: CollisionShape2D = $Magnet/Shape
	shape.shape = shape.shape.duplicate()
	apply_pickup_radius(pickup_radius)

func apply_pickup_radius(value: float) -> void:
	pickup_radius = value
	($Magnet/Shape as CollisionShape2D).shape.radius = value

func _physics_process(delta: float) -> void:
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	($Sprite as Sprite2D).modulate = Color(2.2, 0.8, 0.8) if hit_flash > 0.0 else tint
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO: last_move = direction
	if dash_time > 0.0:
		dash_time -= delta
		# A dash that moves through the physics engine slides along a wall
		# instead of teleporting into it, which the old position += did.
		velocity = last_move.normalized() * speed * DASH_SPEED
	else:
		velocity = direction * speed
	move_and_slide()

# Sprites in the Kenney pack are drawn facing +X, so an angle is all it takes.
func aim_at(target: Vector2) -> void:
	($Sprite as Sprite2D).rotation = (target - global_position).angle()

func face_travel() -> void:
	($Sprite as Sprite2D).rotation = last_move.angle()

func dash() -> bool:
	if dash_cooldown > 0.0 or not alive: return false
	dash_time = DASH_TIME
	dash_cooldown = DASH_COOLDOWN
	return true

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)

func hurt(amount: float) -> void:
	if not alive: return
	hp = maxf(0.0, hp - amount)
	hit_flash = 0.1
	# `alive` is the latch: every damage source funnels through here, so the
	# run can only end once no matter how many enemies land a blow this frame.
	if hp <= 0.0:
		alive = false
		died.emit()

## Tactical marksman: keeps range, paints a red warning beam at your chest,
## then fires flat and fast. Slide/roll under the locked line, or make him
## whiff and punish the recovery. The beam freezes where you WERE — move.
class_name Marksman2D
extends Enemy2D

@export var engage_min := 150.0
@export var engage_max := 430.0
@export var aim_time := 0.85
@export var bolt_speed := 520.0

var _beam: Line2D
var _aim_locked := Vector2.ZERO


func _ready() -> void:
	walk_speed = 55.0
	run_speed = 130.0
	attack_cooldown = 1.6
	recover_time = 0.55
	windup_time = aim_time
	max_hp = 3
	armor = false
	tint = Color(0.35, 0.4, 0.55)
	super()
	_build_beam()


func _build_beam() -> void:
	_beam = Line2D.new()
	_beam.default_color = Color(1.0, 0.15, 0.2, 0.75)
	_beam.width = 2.5
	_beam.visible = false
	add_child(_beam)


func _in_attack_window() -> bool:
	if not is_instance_valid(_player) or not _seen:
		return false
	var dx := absf(_player.global_position.x - global_position.x)
	var dy := absf(_player.global_position.y - global_position.y)
	return dx >= engage_min and dx <= engage_max and dy < 64.0


func _begin_windup() -> void:
	_say("!", COLOR_ANGRY, maxf(_windup_t, 0.3))
	_beam.visible = true
	if is_instance_valid(_player):
		_aim_locked = _player.global_position + Vector2(0, -30)


func _begin_strike() -> void:
	_beam.visible = false
	var from := global_position + Vector2(0, -34)
	var dir := _aim_locked - from
	if dir.length() < 1.0:
		dir = Vector2(_dir, 0)
	var bolt := Projectile2D.new()
	bolt.speed = bolt_speed
	bolt.damage = 1
	bolt.life = 2.0
	bolt.tint = Color(1.0, 0.5, 0.2)
	get_parent().add_child(bolt)
	bolt.launch(from, dir.normalized())


func _do_attack(delta: float) -> void:
	# while winding, keep the beam tracking eyes-on; it locks at strike
	if _phase == Phase.WINDUP and _beam.visible and is_instance_valid(_player):
		var from := global_position + Vector2(0, -34)
		_aim_locked = _player.global_position + Vector2(0, -30)
		_beam.points = PackedVector2Array([from - global_position,
			_aim_locked - global_position])
	super(delta)


## Ranged discipline: crowd him and he back-pedals to his firing band.
func _do_chase(delta: float) -> void:
	super(delta)
	if state != State.CHASE or not is_instance_valid(_player):
		return
	var dx := _player.global_position.x - global_position.x
	if absf(dx) < engage_min * 0.8:
		velocity.x = move_toward(velocity.x, -signf(dx) * walk_speed, 700.0 * delta)
		if _wall_ahead() or not _floor_ahead():
			velocity.x = 0.0

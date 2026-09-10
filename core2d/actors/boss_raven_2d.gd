## "The Raven" — 2D rooftop duel (both phases).
## Tells & counters (Mark-of-the-Ninja readable, tuned to THIS moveset):
##   TRIPLE VOLLEY  -> bolts 1-2 ride chest-high (SLIDE under), bolt 3 low (JUMP)
##   STAFF RUSH     -> telegraphed dash; PARRY it, or vault overhead and
##                     punish the RUSH_RECOVER wall-eat
##   RELOAD         -> 2.0 s vulnerability window, the main damage opening
##   PHASE 2 (<40%)
##   LEAP IMPACT    -> drops on your head, spawns two floor shockwaves (jump)
##   BEAM GRID      -> red floor panels; the burst hits ONLY grounded players
##                     below the girder line — be airborne or on the girders
##   REVERSAL       -> glowing guard: hitting him eats a counter grab-toss
## He never staggers. Windows of discipline are the whole fight.
class_name BossRaven2D
extends CharacterBody2D

signal boss_died(boss)
signal hp_changed(hp: int, max_hp: int)

enum St { CINEMA, IDLE, APPROACH, TRIPLE_AIM, TRIPLE_FIRE, RUSH_AIM, RUSHING,
	RUSH_RECOVER, RELOAD, SLAM_AIR, SLAM_LAND, SWEEP_TEL, SWEEP_FIRE,
	REVERSAL, GRAB_DASH, GRAB_RECOVER, DEAD }

@export var arena_min_x := 3850.0
@export var arena_max_x := 4650.0
@export var floor_y := 280.0
@export var sweep_safe_y := 230.0
@export var max_hp := 36
@export var walk_speed := 110.0
@export var rush_speed := 520.0
@export var gravity := 1450.0
@export var coat_tint := Color(0.1, 0.12, 0.18)

const FONT_BOLD := "res://assets/fonts/DejaVuSans-Bold.ttf"
const P1 := ["triple", "approach", "triple", "rush", "reload", "approach",
	"triple", "reversal", "rush", "reload"]
const P2 := ["slam", "triple", "sweep", "rush", "reversal", "reload",
	"slam", "sweep", "triple", "reload"]
const BOLT_Y := [-30.0, -30.0, -8.0]
const COLOR_TELL := Color(1.0, 0.3, 0.15)

var state := St.CINEMA
var hp := 0
var _phase_two := false
var _dir := -1.0
var _player: Node2D
var _timer := 0.0
var _idle_pace := 0.0
var _shots_left := 0
var _shot_gap := 0.0
var _pattern_idx := 0
var _rush_hit := false
var _flash_t := 0.0
var _visual: Node2D
var _poly: Polygon2D
var _indicator: Label2D
var _ind_t := 0.0
var _panels: Array[Polygon2D] = []
var _health: TitoHealth


func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1
	up_direction = Vector2.UP
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 18.0
	cap.height = 72.0
	cs.shape = cap
	cs.position = Vector2(0, -36)
	add_child(cs)
	var hb := HurtBox2D.new()
	var hcs := CollisionShape2D.new()
	var hcap := CapsuleShape2D.new()
	hcap.radius = 19.0
	hcap.height = 74.0
	hcs.shape = hcap
	hcs.position = Vector2(0, -37)
	hb.add_child(hcs)
	add_child(hb)
	_health = TitoHealth.new()
	_health.max_hp = max_hp
	add_child(_health)
	_health.died.connect(_die)
	_health.damaged.connect(func(_a: int, h: int) -> void: hp_changed.emit(h, max_hp))
	_build_visual()


func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	_poly = Polygon2D.new()
	# broad coat + shoulders, origin at feet
	_poly.polygon = PackedVector2Array([
		Vector2(-26, 0), Vector2(-28, -20), Vector2(-24, -54), Vector2(-20, -62),
		Vector2(-14, -66), Vector2(-12, -78), Vector2(-7, -84),
		Vector2(-20, -88), Vector2(20, -88), Vector2(7, -84),
		Vector2(12, -78), Vector2(14, -66), Vector2(20, -62),
		Vector2(24, -54), Vector2(28, -20), Vector2(26, 0),
	])
	_poly.color = coat_tint
	_visual.add_child(_poly)
	for ez in [-6, 6]:  # ember eyes under the brim
		var eye := Polygon2D.new()
		eye.polygon = PackedVector2Array([
			Vector2(ez - 2, -72), Vector2(ez + 2, -72),
			Vector2(ez + 2, -69), Vector2(ez - 2, -69)])
		eye.color = Color(1.0, 0.45, 0.15)
		_visual.add_child(eye)
	_indicator = Label2D.new()
	_indicator.font = load(FONT_BOLD) as Font
	_indicator.font_size = 30
	_indicator.position = Vector2(-8, -112)
	_indicator.visible = false
	add_child(_indicator)


func begin_fight() -> void:
	if state == St.CINEMA:
		state = St.IDLE
		_idle_pace = 0.6


func _physics_process(delta: float) -> void:
	if state == St.DEAD:
		return
	_player = _find_player()
	_timer = maxf(_timer - delta, 0.0)
	_ind_t = maxf(_ind_t - delta, 0.0)
	_flash_t = maxf(_flash_t - delta, 0.0)
	if _ind_t <= 0.0 and _indicator != null:
		_indicator.visible = false
	velocity.y = minf(velocity.y + gravity * delta, 640.0)

	match state:
		St.CINEMA:
			_face_player()
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		St.IDLE: _do_idle(delta)
		St.APPROACH: _do_approach(delta)
		St.TRIPLE_AIM: _do_triple_aim(delta)
		St.TRIPLE_FIRE: _do_triple_fire(delta)
		St.RUSH_AIM: _do_rush_aim(delta)
		St.RUSHING: _do_rushing(delta)
		St.RUSH_RECOVER, St.GRAB_RECOVER: _do_recover(delta)
		St.RELOAD: _do_reload(delta)
		St.SLAM_AIR: _do_slam_air()
		St.SLAM_LAND: _do_slam_land(delta)
		St.SWEEP_TEL: _do_sweep_tel(delta)
		St.SWEEP_FIRE: _do_sweep_fire(delta)
		St.REVERSAL: _do_reversal(delta)
		St.GRAB_DASH: _do_grab_dash(delta)

	move_and_slide()
	global_position.x = clampf(global_position.x, arena_min_x + 24.0, arena_max_x - 24.0)
	_apply_visual(delta)


# ------------------------------------------------------------ patterns ----
func _do_idle(delta: float) -> void:
	_face_player()
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	_idle_pace -= delta
	if _idle_pace <= 0.0:
		_start_pattern(_next_pattern())


func _next_pattern() -> String:
	var list: Array = P2 if _phase_two else P1
	var p: String = list[_pattern_idx % list.size()]
	_pattern_idx += 1
	return p


func _start_pattern(p: String) -> void:
	match p:
		"triple":
			state = St.TRIPLE_AIM
			_timer = 0.55
			_say("!")
		"approach":
			state = St.APPROACH
		"rush":
			state = St.RUSH_AIM
			_timer = 0.55
			_say("!!")
		"reload":
			state = St.RELOAD
			_timer = 2.0
			_say("…", Color(0.55, 0.85, 1.0))
		"slam":
			_leap_at_player()
		"sweep":
			state = St.SWEEP_TEL
			_timer = 1.5
			_build_sweep_telegraph()
			_say("!!!")
		"reversal":
			state = St.REVERSAL
			_timer = 2.1
			_say("🛡", COLOR_TELL)


func _do_approach(delta: float) -> void:
	if not is_instance_valid(_player):
		state = St.IDLE
		_idle_pace = 0.4
		return
	_face_player()
	var dx := _player.global_position.x - global_position.x
	if absf(dx) < 56.0:
		velocity.x = 0.0
		state = St.IDLE
		_idle_pace = 0.15
		return
	velocity.x = move_toward(velocity.x, signf(dx) * walk_speed * (1.25 if _phase_two else 1.0),
		900.0 * delta)


func _do_triple_aim(delta: float) -> void:
	_face_player()
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	if _timer <= 0.0:
		state = St.TRIPLE_FIRE
		_shots_left = 3
		_shot_gap = 0.0


func _do_triple_fire(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	_shot_gap -= delta
	if _shot_gap <= 0.0 and _shots_left > 0:
		_fire_bolt(BOLT_Y[3 - _shots_left])
		_shots_left -= 1
		_shot_gap = 0.36
	if _shots_left <= 0 and _shot_gap <= 0.0:
		state = St.IDLE
		_idle_pace = 0.3


func _fire_bolt(y_off: float) -> void:
	var bolt := Projectile2D.new()
	bolt.speed = 430.0
	bolt.damage = 1
	bolt.life = 3.0
	bolt.tint = Color(1.0, 0.5, 0.2)
	get_parent().add_child(bolt)
	bolt.launch(global_position + Vector2(0, y_off), Vector2(_dir, 0))


func _do_rush_aim(delta: float) -> void:
	_face_player()
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	if _timer <= 0.0:
		state = St.RUSHING
		_rush_hit = false
		_timer = 0.85


func _do_rushing(delta: float) -> void:
	velocity.x = _dir * rush_speed
	if not _rush_hit and is_instance_valid(_player):
		var pdx := absf(_player.global_position.x - global_position.x)
		var pdy := absf(_player.global_position.y - global_position.y)
		if pdx < 30.0 and pdy < 56.0:
			_rush_hit = true
			_player.take_damage(1, global_position)
	var at_edge := global_position.x <= arena_min_x + 26.0 \
		or global_position.x >= arena_max_x - 26.0
	if _timer <= 0.0 or at_edge or is_on_wall():
		velocity.x = 0.0
		state = St.RUSH_RECOVER
		_timer = 0.85
		_say("…")


func _do_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	if _timer <= 0.0:
		state = St.IDLE
		_idle_pace = 0.35


func _do_reload(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	if _timer <= 0.0:
		state = St.IDLE
		_idle_pace = 0.3


func _leap_at_player() -> void:
	var target_x := global_position.x
	if is_instance_valid(_player):
		target_x = _player.global_position.x
	var dx := target_x - global_position.x
	velocity.y = -560.0
	velocity.x = clampf(dx / 0.9, -320.0, 320.0)
	_dir = -signf(dx) if absf(dx) > 2.0 else _dir
	state = St.SLAM_AIR
	_say("!")


func _do_slam_air() -> void:
	if is_on_floor():
		state = St.SLAM_LAND
		_timer = 0.55
		_spawn_shockwaves()


func _spawn_shockwaves() -> void:
	for side in [-1.0, 1.0]:
		var w := Projectile2D.new()
		w.speed = 240.0
		w.damage = 1
		w.life = 3.2
		w.tint = Color(0.6, 0.5, 0.7)
		get_parent().add_child(w)
		w.launch(global_position + Vector2(0, -8), Vector2(side, 0))


func _do_slam_land(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	if _timer <= 0.0:
		state = St.IDLE
		_idle_pace = 0.3


func _build_sweep_telegraph() -> void:
	_clear_panels()
	var w := (arena_max_x - arena_min_x) / 6.0
	for i in 6:
		var p := Polygon2D.new()
		var x0 := arena_min_x + i * w + 4.0
		p.polygon = PackedVector2Array([
			Vector2(x0, 0), Vector2(x0 + w - 8.0, 0),
			Vector2(x0 + w - 8.0, -44.0), Vector2(x0, -44.0)])
		p.color = Color(1.0, 0.1, 0.15, 0.2)
		p.position = Vector2(0, floor_y)
		get_parent().add_child(p)
		_panels.append(p)


func _do_sweep_tel(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	for p in _panels:
		p.color.a = 0.2 + 0.22 * (1.5 - _timer) / 1.5
	if _timer <= 0.0:
		state = St.SWEEP_FIRE
		_timer = 0.4
		for p in _panels:
			p.color = Color(1.0, 0.25, 0.2, 0.6)
		if is_instance_valid(_player) and _player.is_on_floor() \
		and _player.global_position.y > sweep_safe_y:
			_player.take_damage(1, global_position)


func _do_sweep_fire(delta: float) -> void:
	if _timer <= 0.0:
		_clear_panels()
		state = St.IDLE
		_idle_pace = 0.35


func _clear_panels() -> void:
	for p in _panels:
		p.queue_free()
	_panels.clear()


func _do_reversal(delta: float) -> void:
	_face_player()
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	if _timer <= 0.0:
		state = St.IDLE
		_idle_pace = 0.35


func _do_grab_dash(delta: float) -> void:
	if is_instance_valid(_player):
		var dx := _player.global_position.x - global_position.x
		velocity.x = signf(dx) * 560.0
		if absf(dx) < 30.0 and absf(_player.global_position.y - global_position.y) < 60.0:
			_player.take_damage(1, global_position)
			_player.velocity = Vector2(signf(dx) * 340.0, -200.0)
			state = St.GRAB_RECOVER
			_timer = 0.8
			velocity.x = 0.0
			return
	if _timer <= 0.0:
		state = St.GRAB_RECOVER
		_timer = 0.65


# -------------------------------------------------------------- damage ----
func take_damage(amount: int, from_pos = null) -> void:
	if state == St.DEAD or state == St.CINEMA:
		return
	if state == St.REVERSAL:
		state = St.GRAB_DASH
		_timer = 0.4
		return  # the trap springs: zero damage, counter toss
	_health.take_damage(amount)
	if state == St.DEAD:
		return
	hp = _health.hp
	_flash_t = 0.12
	if not _phase_two and hp <= int(max_hp * 0.4):
		_enter_phase_two()


func _enter_phase_two() -> void:
	_phase_two = true
	_say("!!", COLOR_TELL)
	state = St.IDLE
	_pattern_idx = 0
	_idle_pace = 0.4
	coat_tint = coat_tint.lerp(Color(0.4, 0.1, 0.12), 0.5)


func _die() -> void:
	state = St.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_clear_panels()
	if _indicator != null:
		_indicator.visible = false
	set_physics_process(false)
	var ih := get_node_or_null("/root/InputHelper")
	if ih != null and ih.has_method("rumble_large"):
		ih.rumble_large()
	boss_died.emit(self)


# ----------------------------------------------------------------- misc ---
func _face_player() -> void:
	if not is_instance_valid(_player):
		return
	var dx := _player.global_position.x - global_position.x
	if absf(dx) > 2.0:
		_dir = signf(dx)


func _apply_visual(delta: float) -> void:
	if _visual != null:
		_visual.scale.x = lerpf(_visual.scale.x, _dir, clampf(14.0 * delta, 0.0, 1.0))
	if _poly == null:
		return
	var want := Vector2.ONE
	match state:
		St.RUSH_AIM: want = Vector2(1.14, 0.84)
		St.RUSHING: want = Vector2(1.3, 0.72)
		St.SLAM_AIR: want = Vector2(0.85, 1.2)
		St.RELOAD: want = Vector2(1.05, 0.88)
	_poly.scale = _poly.scale.lerp(want, clampf(10.0 * delta, 0.0, 1.0))
	if _flash_t > 0.0:
		_poly.color = Color(1, 1, 1)
	elif state == St.REVERSAL:
		_poly.color = coat_tint.lerp(Color(0.55, 0.25, 0.65), 0.75)
	else:
		_poly.color = coat_tint


func _say(text: String, color := Color(1.0, 0.85, 0.2)) -> void:
	if _indicator == null:
		return
	_indicator.text = text
	_indicator.modulate = color
	_indicator.visible = true
	_ind_t = 0.7


func _find_player() -> Node2D:
	if is_instance_valid(_player):
		return _player
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes.size() > 0 else null

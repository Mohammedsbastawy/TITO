## TITO 2D — the player's whole move set, one state machine.
## States & numbers follow docs/MIGRATION_2D_PLAN.md §2.2 (tuning contract).
## Placeholder ink-silhouette visuals live behind _play_anim() so real
## sprite sheets can drop in later WITHOUT touching logic (Phase 9).
class_name Player2D
extends CharacterBody2D

signal died
signal damaged(amount: int, hp: int)
signal landed(heavy: bool)
signal parried

enum State { STAGGER, IDLE, RUN, JUMP, FALL, WALL_SLIDE, SLIDE, ROLL, PARRY,
	LIGHT1, LIGHT2, LIGHT3, HEAVY, POUND, HURT, CLIMB, DEAD }

# ----------------------------- tuning (plan §2.2) -------------------------
@export var run_speed := 190.0
@export var sprint_speed := 250.0
@export var sprint_delay := 0.8          # hold-run time before sprint kicks in
@export var accel_ground := 1400.0
@export var friction_ground := 1700.0
@export var accel_air := 900.0
@export var gravity := 1450.0
@export var max_fall := 640.0
@export var jump_speed := 560.0
@export var air_jumps := 1                # extra jumps allowed mid-air (double jump)
@export var air_jump_mult := 0.92         # double-jump strength vs ground jump
@export var coyote_time := 0.11
@export var jump_buffer := 0.12
@export var slide_boost := 420.0
@export var slide_min := 180.0
@export var slide_max_time := 0.6
@export var roll_speed := 360.0
@export var roll_time := 0.28
@export var roll_iframes := 0.22
@export var wall_fall_cap := 90.0
@export var wall_jump_push := 380.0
@export var wall_jump_up := 520.0
@export var wall_lock := 0.16            # input lockout after wall-jump
@export var pound_speed := 900.0
@export var stall_time := 0.08
@export var parry_window := 0.18
@export var parry_recover := 0.32
@export var hurt_knockback := Vector2(220.0, -160.0)
@export var invuln_time := 0.9

var state := State.IDLE
var facing := 1
var hp_max := 6
var hp := 6
var _health: TitoHealth

var _t := 0.0                 # generic per-state timer
var _run_hold := 0.0
var _land_t := 0.0
var _jumps_left := 1            # air jumps still in the pocket
var _carry := 0.0               # ground speed kept when going airborne
var _air_jump_t := 0.0          # >0 briefly after a double jump (anim pick)
var _coyote := 0.0
var _buffer := 0.0
var _iframes := 0.0
var _roll_iframes := 0.0
var _parry_active := 0.0
var _chain_queued := false
var _slide_time := 0.0
var _ladder: Area2D = null
var _checkpoint := Vector2.ZERO
var _intro_lock := false
var _air_lock := 0.0             # wall-jump push protection
var _floor_y_before := 0.0
var _dead_t := 0.0

var _visual: Node2D
var _body_poly: Polygon2D
var _hero: Sprite2D
var _hero_sc := 1.0
var _heroA: AnimatedSprite2D
var _heroA_sc := 1.0
var _cur_anim := &""

const HERO_TEX := "res://assets2d/sprites/chars/tito_idle.png"
const CHAR_ANIM_DIR := "res://assets2d/sprites/chars/anim/"
var _ring: Polygon2D          # parry flash ring
var _hitbox: HitBox2D
var _hit_shape: CollisionShape2D
var _stand_shape: CollisionShape2D
var _slide_shape: CollisionShape2D

const STATE_TINT := {
	State.STAGGER: Color(0.55, 0.6, 0.8),
	State.IDLE: Color(0.35, 0.5, 0.9),
	State.RUN: Color(0.3, 0.6, 1.0),
	State.JUMP: Color(0.4, 0.75, 1.0),
	State.FALL: Color(0.35, 0.6, 0.95),
	State.WALL_SLIDE: Color(0.5, 0.85, 0.7),
	State.SLIDE: Color(0.25, 0.8, 0.85),
	State.ROLL: Color(1.0, 1.0, 1.0),
	State.PARRY: Color(0.4, 1.0, 0.95),
	State.LIGHT1: Color(1.0, 0.8, 0.35),
	State.LIGHT2: Color(1.0, 0.7, 0.3),
	State.LIGHT3: Color(1.0, 0.55, 0.25),
	State.HEAVY: Color(1.0, 0.4, 0.25),
	State.POUND: Color(1.0, 0.35, 0.2),
	State.HURT: Color(1.0, 0.3, 0.3),
	State.CLIMB: Color(0.6, 0.9, 0.6),
	State.DEAD: Color(0.25, 0.25, 0.3),
}


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	up_direction = Vector2.UP
	floor_snap_length = 6.0
	_build_shapes()
	_build_hurtbox()
	_build_hitbox()
	_build_visual()
	_health = TitoHealth.new()
	_health.max_hp = hp_max
	add_child(_health)
	_health.died.connect(_on_died)
	_health.damaged.connect(func(a: int, h: int) -> void:
		hp = h
		damaged.emit(a, h))
	hp = hp_max
	_checkpoint = global_position


func _build_shapes() -> void:
	_stand_shape = CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 15.0
	cap.height = 56.0
	_stand_shape.shape = cap
	_stand_shape.position = Vector2(0, -28)
	add_child(_stand_shape)
	_slide_shape = CollisionShape2D.new()
	var low := CapsuleShape2D.new()
	low.radius = 10.0
	low.height = 30.0
	_slide_shape.shape = low
	_slide_shape.position = Vector2(0, -15)
	_slide_shape.disabled = true
	add_child(_slide_shape)


func _build_hurtbox() -> void:
	var hb := HurtBox2D.new()
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 16.0
	cap.height = 58.0
	cs.shape = cap
	cs.position = Vector2(0, -29)
	hb.add_child(cs)
	add_child(hb)


func _build_hitbox() -> void:
	_hitbox = HitBox2D.new()
	_hit_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44.0, 34.0)
	_hit_shape.shape = rect
	_hit_shape.position = Vector2(26, -30)
	_hitbox.add_child(_hit_shape)
	add_child(_hitbox)


func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	_body_poly = Polygon2D.new()
	# ink silhouette: rounded-ish body + head, origin at feet
	_body_poly.polygon = PackedVector2Array([
		Vector2(-13, 0), Vector2(-15, -22), Vector2(-13, -44), Vector2(-8, -52),
		Vector2(-8, -58), Vector2(0, -64), Vector2(8, -58), Vector2(8, -52),
		Vector2(13, -44), Vector2(15, -22), Vector2(13, 0),
	])
	_body_poly.color = Color(0.35, 0.5, 0.9)
	_visual.add_child(_body_poly)
	# single bright eye so facing reads instantly
	var eye := Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(3, -56), Vector2(9, -56), Vector2(9, -52), Vector2(3, -52),
	])
	eye.color = Color(1, 1, 1)
	_visual.add_child(eye)
	# parry ring flash
	_ring = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 18:
		var a := i / 18.0 * TAU
		pts.append(Vector2(cos(a), sin(a)) * 34.0 + Vector2(0, -32))
	_ring.polygon = pts
	_ring.color = Color(0.4, 1.0, 0.95, 0.0)
	_visual.add_child(_ring)
	_build_hero()


## Animated sheets (assets2d/sprites/chars/anim/tito_<anim>/f_XX.png) win;
## the single inked placeholder frame is the fallback.
func _build_hero() -> void:
	if _try_build_hero_anims():
		for c in _visual.get_children():
			if c is Polygon2D and c != _ring:
				c.visible = false
		_ring.z_index = 1
		return
	_hero = Sprite2D.new()
	_hero.texture = load(HERO_TEX) as Texture2D
	if _hero.texture != null:
		_hero_sc = 74.0 / float(_hero.texture.get_height())
		_hero.scale = Vector2(_hero_sc, _hero_sc)
		_hero.centered = false
		_hero.position = Vector2(-_hero.texture.get_width() * _hero_sc * 0.5, -72.0)
		_visual.add_child(_hero)
		for c in _visual.get_children():
			if c is Polygon2D and c != _ring:
				c.visible = false
		_ring.z_index = 1


func _try_build_hero_anims() -> bool:
	var fr := SpriteFrames.new()
	fr.remove_animation(&"default")
	var target_h := 0.0
	var speeds := {&"idle": 6.0, &"run": 12.0, &"sprint": 14.0,
		&"jump": 9.0, &"jump2": 10.0, &"fall": 7.0, &"land": 11.0}
	var loops := {&"jump": false, &"jump2": false, &"land": false}
	for anim in [&"idle", &"run", &"sprint", &"jump", &"jump2", &"fall", &"land"]:
		var dir := CHAR_ANIM_DIR + "tito_" + String(anim) + "/"
		var frames: Array[String] = []
		for f in ResourceLoader.list_directory(dir):
			if f.ends_with(".png"):
				frames.append(f)
		if frames.is_empty():
			continue
		frames.sort()
		fr.add_animation(anim)
		fr.set_animation_loop(anim, bool(loops.get(anim, true)))
		fr.set_animation_speed(anim, float(speeds.get(anim, 12.0)))
		for f in frames:
			var tex := load(dir + f) as Texture2D
			fr.add_frame(anim, tex)
			target_h = maxf(target_h, float(tex.get_height()))
	if fr.get_animation_names().size() == 0:
		return false
	_heroA = AnimatedSprite2D.new()
	_heroA.sprite_frames = fr
	_heroA_sc = 74.0 / target_h
	_heroA.scale = Vector2(_heroA_sc, _heroA_sc)
	_heroA.position = Vector2(0, -74.0 * 0.5)  # frames bottom-aligned at feet
	_visual.add_child(_heroA)
	_cur_anim = &"idle"
	if fr.has_animation(&"idle"):
		_heroA.play(&"idle")
	return true


## Pick the anim for the current state; unmapped states keep the last anim.
func _sync_hero_anim() -> void:
	var want := _cur_anim
	match state:
		State.IDLE:
			want = &"land" if _land_t > 0.0 else &"idle"
		State.RUN:
			want = &"sprint" if _run_hold >= sprint_delay else &"run"
		State.JUMP:
			want = &"jump"
			if _air_jump_t > 0.0 and _heroA.sprite_frames.has_animation(&"jump2"):
				want = &"jump2"
		State.FALL:
			want = &"fall"
	if want == _cur_anim:
		return
	if _heroA.sprite_frames.has_animation(want):
		_cur_anim = want
		_heroA.play(want)


# ============================================================ main loop ==
func _physics_process(delta: float) -> void:
	_coyote = maxf(_coyote - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	_iframes = maxf(_iframes - delta, 0.0)
	_roll_iframes = maxf(_roll_iframes - delta, 0.0)
	_air_lock = maxf(_air_lock - delta, 0.0)
	_land_t = maxf(_land_t - delta, 0.0)
	_air_jump_t = maxf(_air_jump_t - delta, 0.0)
	_t = maxf(_t - delta, 0.0)
	if is_on_floor():
		_coyote = coyote_time
		_jumps_left = air_jumps      # touching ground restocks the double jump
		_carry = absf(velocity.x)    # remember ground speed for air momentum
	if Input.is_action_just_pressed(&"jump"):
		_buffer = jump_buffer

	match state:
		State.STAGGER: _do_stagger(delta)
		State.IDLE, State.RUN: _do_ground(delta)
		State.JUMP, State.FALL: _do_air(delta)
		State.WALL_SLIDE: _do_wall_slide(delta)
		State.SLIDE: _do_slide(delta)
		State.ROLL: _do_roll(delta)
		State.PARRY: _do_parry(delta)
		State.LIGHT1, State.LIGHT2, State.LIGHT3: _do_light(delta)
		State.HEAVY: _do_heavy(delta)
		State.POUND: _do_pound(delta)
		State.HURT: _do_hurt(delta)
		State.CLIMB: _do_climb(delta)
		State.DEAD: _do_dead(delta)

	_floor_y_before = velocity.y
	move_and_slide()
	# landing
	if is_on_floor() and _floor_y_before > 340.0 and state in [State.JUMP, State.FALL]:
		landed.emit(_floor_y_before > 700.0)
		_land_t = 0.22
	_apply_visual(delta)


# ------------------------------------------------------------- helpers ----
func _axis() -> float:
	if _intro_lock:
		return 0.0
	return Input.get_axis(&"move_left", &"move_right")


func _enter(s: int, t := 0.0) -> void:
	state = s
	_t = t
	_play_anim()


func _ground_friction(delta: float, f := friction_ground) -> void:
	velocity.x = move_toward(velocity.x, 0.0, f * delta)


func _request_jump(force := false) -> bool:
	if _buffer > 0.0 and (_coyote > 0.0 or force):
		_buffer = 0.0
		_coyote = 0.0
		_jumps_left = air_jumps          # ground jump spent; air jumps remain
		velocity.y = -jump_speed
		_enter(State.JUMP)
		return true
	return false


func _apply_gravity(delta: float, cap := max_fall) -> void:
	velocity.y = minf(velocity.y + gravity * delta, cap)


func _face_input(ax: float) -> void:
	if absf(ax) > 0.01:
		facing = int(signf(ax))


func _start_attack(active_t: float, recover_t: float, dmg: int, ahead: float,
		kb := Vector2(160, -60)) -> void:
	_hit_shape.position = Vector2(ahead, -30)
	_hitbox.arm(dmg, Vector2(kb.x * facing, kb.y), active_t)
	_t = active_t + recover_t
	# small forward step sells the lunge
	velocity.x = facing * maxf(velocity.x * 0.4, 70.0)


func is_invulnerable() -> bool:
	return _iframes > 0.0 or _roll_iframes > 0.0 or state == State.DEAD


func set_ladder(l: Area2D) -> void:
	_ladder = l


func set_checkpoint(pos: Vector2) -> void:
	_checkpoint = pos


func play_stagger_intro(duration := 2.4) -> void:
	_intro_lock = true
	_enter(State.STAGGER, duration)


func take_damage(amount: int, from_pos = null) -> void:
	if is_invulnerable():
		return
	if state == State.PARRY and _parry_active > 0.0:
		_parry_success()
		return
	_iframes = invuln_time
	var dir := -float(facing)
	if from_pos is Vector2:
		dir = signf(global_position.x - (from_pos as Vector2).x)
		if dir == 0.0:
			dir = -float(facing)
	velocity = Vector2(dir * hurt_knockback.x, hurt_knockback.y)
	_stand_shape.disabled = false
	_slide_shape.disabled = true
	_enter(State.HURT, 0.32)
	var ih := get_node_or_null("/root/InputHelper")
	if ih != null and ih.has_method("rumble_medium"):
		ih.rumble_medium()
	_health.take_damage(amount)


func _parry_success() -> void:
	parried.emit()
	_enter(State.PARRY, parry_recover)
	# comic beat: the world slows so the reader savors the deflection
	Engine.time_scale = 0.3
	get_tree().create_timer(0.35, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0)


func _on_died() -> void:
	velocity = Vector2.ZERO
	_enter(State.DEAD)
	_dead_t = 1.4
	died.emit()


func _respawn() -> void:
	global_position = _checkpoint
	velocity = Vector2.ZERO
	_health.hp = hp_max
	hp = hp_max
	damaged.emit(0, hp)  # HUD refresh on revive
	_iframes = 1.2
	_enter(State.IDLE)


# -------------------------------------------------------------- states ----
func _do_stagger(delta: float) -> void:
	# winded shuffle to the right, then the game hands you control
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 60.0, 500.0 * delta)
	facing = 1
	if _t <= 0.0:
		_intro_lock = false
		_enter(State.IDLE)


func _do_ground(delta: float) -> void:
	var ax := _axis()
	_face_input(ax)
	_run_hold = _run_hold + delta if absf(ax) > 0.1 else 0.0
	var top := run_speed if _run_hold < sprint_delay else sprint_speed
	velocity.x = move_toward(velocity.x, ax * top,
		(accel_ground if absf(ax) > 0.1 else friction_ground) * delta)
	var want := State.RUN if absf(velocity.x) > 8.0 else State.IDLE
	if state != want:
		_enter(want)
	if not is_on_floor():
		_enter(State.FALL)
		return
	if _request_jump():
		return
	if Input.is_action_just_pressed(&"dash_roll") and not _intro_lock:
		_enter(State.ROLL, roll_time)
		_roll_iframes = roll_iframes
		velocity.x = roll_speed * facing
		return
	if Input.is_action_pressed(&"crawl") and absf(velocity.x) > slide_min and not _intro_lock:
		_enter(State.SLIDE)
		_slide_time = 0.0
		velocity.x = signf(velocity.x) * slide_boost
		_stand_shape.disabled = true
		_slide_shape.disabled = false
		return
	if Input.is_action_just_pressed(&"parry") and not _intro_lock:
		_enter(State.PARRY, parry_recover)
		_parry_active = parry_window
		return
	if Input.is_action_just_pressed(&"attack_light") and not _intro_lock:
		_enter(State.LIGHT1, 0.0)
		_start_attack(0.12, 0.16, 1, 26.0)
		return
	if Input.is_action_just_pressed(&"attack_heavy") and not _intro_lock:
		_enter(State.HEAVY, 0.78)  # windup 0.28 + active 0.16 + recover 0.34
		_start_heavy()
		return
	if _ladder != null and Input.is_action_pressed(&"climb_up"):
		_enter(State.CLIMB)


func _do_air(delta: float) -> void:
	if _request_jump():
		return  # buffered/coyote jump still counts mid-air
	var ax := _axis()
	# DOUBLE JUMP: fresh press past the coyote window, stock left
	if Input.is_action_just_pressed(&"jump") and _jumps_left > 0 and not _intro_lock:
		_jumps_left -= 1
		_air_jump_t = 0.4
		velocity.y = -jump_speed * air_jump_mult
		_enter(State.JUMP)
		if _heroA != null:
			var anim: StringName = &"jump2" if _heroA.sprite_frames.has_animation(&"jump2") else &"jump"
			_cur_anim = anim
			_heroA.play(anim)
		_face_input(ax)
	if _air_lock <= 0.0:
		_face_input(ax)
		# keep the run/sprint speed you launched with instead of hard-capping
		var top: float = maxf(run_speed, _carry) if absf(ax) > 0.1 else run_speed
		velocity.x = move_toward(velocity.x, ax * top, accel_air * delta)
	_apply_gravity(delta)
	var want_air := State.FALL if velocity.y > 0.0 else State.JUMP
	if state != want_air:
		_enter(want_air)
	# grab a wall mid-flight only if actually pushing toward it
	var nx := _wall_normal_x() if is_on_wall() else 0.0
	if not is_on_floor() and is_on_wall_only() and absf(ax) > 0.1 \
	and signf(ax) == -signf(nx):
		_enter(State.WALL_SLIDE)
		return
	if Input.is_action_just_pressed(&"attack_heavy") and not _intro_lock:
		_enter(State.POUND, stall_time)
		velocity = Vector2.ZERO
		return
	if is_on_floor():
		_enter(State.RUN if absf(velocity.x) > 8.0 else State.IDLE)


func _wall_normal_x() -> float:
	return get_wall_normal().x


func _do_wall_slide(delta: float) -> void:
	velocity.y = minf(velocity.y + gravity * 0.25 * delta, wall_fall_cap)
	velocity.x = -_wall_normal_x() * 10.0  # keep kissing the wall
	var ax := _axis()
	if _buffer > 0.0:
		_buffer = 0.0
		var nx := _wall_normal_x()
		velocity = Vector2(nx * wall_jump_push, -wall_jump_up)
		facing = int(signf(nx))
		_air_lock = wall_lock
		_jumps_left = air_jumps  # wall-kick restocks the double jump
		_carry = absf(velocity.x)
		_enter(State.JUMP)
		return
	if is_on_floor():
		_enter(State.IDLE)
	elif not is_on_wall() or (absf(ax) > 0.1 and signf(ax) == signf(_wall_normal_x())):
		_enter(State.FALL)


func _do_slide(delta: float) -> void:
	_slide_time += delta
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 260.0 * delta)
	var over := _slide_time > slide_max_time \
		or absf(velocity.x) < slide_min * 0.7 \
		or not Input.is_action_pressed(&"crawl")
	if over:
		if _can_stand():
			_stand_shape.disabled = false
			_slide_shape.disabled = true
			_enter(State.RUN if absf(_axis()) > 0.1 else State.IDLE)
		else:
			# stuck under something: creep as a crawl until there's headroom
			var dir := signf(velocity.x) if absf(velocity.x) > 1.0 else float(facing)
			velocity.x = dir * minf(absf(velocity.x) + 40.0, slide_min)


func _can_stand() -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _stand_shape.shape
	params.transform = Transform2D(0.0, global_position + _stand_shape.position)
	params.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


func _do_roll(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = roll_speed * facing
	if _t <= 0.0:
		_enter(State.RUN if absf(_axis()) > 0.1 else State.IDLE)


func _do_parry(delta: float) -> void:
	_parry_active = maxf(_parry_active - delta, 0.0)
	_apply_gravity(delta)
	_ground_friction(delta)
	if _t <= 0.0:
		_enter(State.IDLE)


func _do_light(delta: float) -> void:
	_apply_gravity(delta)
	if Input.is_action_just_pressed(&"attack_light"):
		_chain_queued = true
	if _t <= 0.0:
		if _chain_queued and state != State.LIGHT3:
			_chain_queued = false
			match state:
				State.LIGHT1:
					_enter(State.LIGHT2)
					_start_attack(0.12, 0.16, 1, 28.0)
				State.LIGHT2:
					_enter(State.LIGHT3)
					_start_attack(0.14, 0.24, 2, 32.0, Vector2(300, -120))
		else:
			_chain_queued = false
			_enter(State.IDLE)


func _start_heavy() -> void:
	# wind-up pause, THEN the hit arms — readable and punishable
	await get_tree().create_timer(0.28, true, false, true).timeout
	if state != State.HEAVY:
		return
	_start_attack(0.16, 0.34, 2, 30.0, Vector2(380, -160))


func _do_heavy(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	if _t <= 0.0:
		_enter(State.IDLE)


func _do_pound(delta: float) -> void:
	if _t > 0.0:
		return                      # telegraph stall hangs mid-air
	velocity.x = 0.0
	velocity.y = pound_speed
	if is_on_floor():
		# impact: AoE thump + camera reads it
		_hit_shape.position = Vector2(0, -16)
		_hitbox.arm(2, Vector2(240, -80), 0.12)
		landed.emit(true)
		_enter(State.IDLE, 0.0)
		_t = 0.3


func _do_hurt(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	if _t <= 0.0:
		_enter(State.IDLE)


func _do_climb(delta: float) -> void:
	velocity = Vector2.ZERO
	if _ladder == null:
		_enter(State.IDLE)
		return
	var up := Input.get_axis(&"climb_up", &"climb_down")
	velocity.y = up * 140.0
	global_position.x = lerpf(global_position.x, _ladder.global_position.x,
		clampf(10.0 * delta, 0.0, 1.0))
	if _buffer > 0.0:
		_buffer = 0.0
		velocity = Vector2(_axis() * run_speed * 0.6, -jump_speed * 0.85)
		_ladder = null
		_enter(State.JUMP)


func _do_dead(delta: float) -> void:
	velocity = Vector2.ZERO
	_dead_t -= delta
	if _dead_t <= 0.0:
		_respawn()


# -------------------------------------------------------------- visuals ---
func _play_anim() -> void:
	var tint: Color = STATE_TINT.get(state, Color.WHITE)
	_body_poly.color = tint


func _apply_visual(delta: float) -> void:
	_visual.scale.x = lerpf(_visual.scale.x, float(facing), clampf(18.0 * delta, 0.0, 1.0))
	var squash := Vector2.ONE
	match state:
		State.SLIDE: squash = Vector2(1.35, 0.5)
		State.ROLL: squash = Vector2(1.15, 0.7)
		State.POUND: squash = Vector2(1.2, 0.85)
		State.WALL_SLIDE: squash = Vector2(0.85, 1.1)
	_body_poly.scale = _body_poly.scale.lerp(squash, clampf(14.0 * delta, 0.0, 1.0))
	if is_on_floor() and squash == Vector2.ONE:
		_body_poly.scale = Vector2.ONE
	# parry ring: pop on activation, fade out
	var want_a := 0.9 if _parry_active > 0.0 else 0.0
	_ring.color.a = lerpf(_ring.color.a, want_a, clampf(12.0 * delta, 0.0, 1.0))
	_ring.rotation += delta * 4.0
	# damage blink
	if _iframes > 0.0 and state != State.DEAD:
		_body_poly.modulate.a = 0.45 + 0.35 * sin(Time.get_ticks_msec() / 40.0)
	else:
		_body_poly.modulate.a = 1.0
	# placeholder sheet mirrors tint / blink / squash of the old capsule
	if _hero != null:
		var tint := _body_poly.color
		tint.a *= _body_poly.modulate.a
		_hero.modulate = tint
		_hero.scale = Vector2(_hero_sc * _body_poly.scale.x, _hero_sc * _body_poly.scale.y)
	# animated hero: same mirror + state-driven playback
	if _heroA != null:
		_sync_hero_anim()
		var tinta := _body_poly.color
		tinta.a *= _body_poly.modulate.a
		_heroA.modulate = tinta
		_heroA.scale = Vector2(_heroA_sc * _body_poly.scale.x, _heroA_sc * _body_poly.scale.y)

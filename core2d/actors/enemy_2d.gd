## Smart 2D opponent base — the 2D port of our legacy 3D AI brain
## (same soul): patrol with ledge/wall flips, vision cone + LOS, last-seen
## search, pack shouts, readable windup→strike→recover scaffold that
## subclasses specialize (staff jab vs overhead, shield block, marksman...).
## Placeholder ink silhouette behind _build_visual(); sheets swap in later.
class_name Enemy2D
extends CharacterBody2D

enum State { PATROL, CHASE, SEARCH, ATTACK, STAGGER, DEAD }
enum Phase { NONE, WINDUP, STRIKE, RECOVER }

signal died

@export var patrol_min_x := -160.0
@export var patrol_max_x := 160.0
@export var walk_speed := 60.0
@export var run_speed := 150.0
@export var vision_range := 260.0
@export var attack_range := 46.0
@export var attack_cooldown := 1.1
@export var windup_time := 0.45
@export var recover_time := 0.5
@export var attack_active := 0.12
@export var attack_damage := 1
@export var stagger_time := 0.42
@export var gravity := 1450.0
@export var max_fall := 640.0
@export var max_hp := 3
@export var armor := false            # true: hits don't stagger (shields, bruisers)
@export var tint := Color(0.75, 0.35, 0.3)

const FONT_BOLD := "res://assets/fonts/DejaVuSans-Bold.ttf"
const COLOR_ALERT := Color(1.0, 0.85, 0.2)
const COLOR_QUESTION := Color(0.55, 0.85, 1.0)
const COLOR_ANGRY := Color(1.0, 0.3, 0.15)

var state := State.PATROL
var _phase := Phase.NONE
var _dir := 1.0
var _player: Node2D
var _seen := false
var _last_seen := Vector2.ZERO
var _lost_t := 0.0
var _attack_cd := 0.0
var _windup_t := 0.0
var _strike_t := 0.0
var _recover_t := 0.0
var _search_t := 0.0
var _stagger_t := 0.0
var _flash_t := 0.0

var _visual: Node2D
var _sheet: Sprite2D
var _sheet_sc := 1.0

const SHEET_TEX := "res://assets2d/sprites/chars/enforcer_idle.png"
var _poly: Polygon2D
var _indicator: Label2D
var _ind_t := 0.0
var _hitbox: HitBox2D
var _hit_shape: CollisionShape2D
var _health: TitoHealth


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8        # enemy body
	collision_mask = 1         # world
	up_direction = Vector2.UP
	floor_snap_length = 5.0
	_patrol_setup()
	_build_shape()
	_build_visual()
	_build_indicator()
	_build_hurtbox()
	_build_hitbox()
	_health = TitoHealth.new()
	_health.max_hp = max_hp
	add_child(_health)
	_health.died.connect(_on_died)


func _patrol_setup() -> void:
	# clamp patrol band around the spawn so designers only set distances
	pass  # subclasses/overrides may set dir; patrol bounds are absolute x


func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 14.0
	cap.height = 50.0
	cs.shape = cap
	cs.position = Vector2(0, -25)
	add_child(cs)


func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-13, 0), Vector2(-14, -16), Vector2(-12, -40), Vector2(-9, -46),
		Vector2(-9, -52), Vector2(0, -58), Vector2(9, -52), Vector2(9, -46),
		Vector2(12, -40), Vector2(14, -16), Vector2(13, 0),
	])
	_poly.color = tint
	_visual.add_child(_poly)
	var eye := Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(2, -52), Vector2(8, -52), Vector2(8, -48), Vector2(2, -48)])
	eye.color = Color(1, 1, 1)
	_visual.add_child(eye)
	# placeholder inked sheet until the real animation frames land
	_sheet = Sprite2D.new()
	_sheet.texture = load(SHEET_TEX) as Texture2D
	if _sheet.texture != null:
		_sheet_sc = 76.0 / float(_sheet.texture.get_height())
		_sheet.scale = Vector2(_sheet_sc, _sheet_sc)
		_sheet.centered = false
		_sheet.position = Vector2(-_sheet.texture.get_width() * _sheet_sc * 0.5, -74.0)
		_visual.add_child(_sheet)
		for c in _visual.get_children():
			if c is Polygon2D:
				c.visible = false


func _build_indicator() -> void:
	_indicator = Label2D.new()
	_indicator.font = load(FONT_BOLD) as Font
	_indicator.font_size = 26
	_indicator.position = Vector2(-6, -84)
	_indicator.visible = false
	add_child(_indicator)


func _build_hurtbox() -> void:
	var hb := HurtBox2D.new()
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 15.0
	cap.height = 52.0
	cs.shape = cap
	cs.position = Vector2(0, -26)
	hb.add_child(cs)
	add_child(hb)


func _build_hitbox() -> void:
	_hitbox = HitBox2D.new()
	_hitbox.victim_group = "player"
	_hit_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(38, 30)
	_hit_shape.shape = rect
	_hit_shape.position = Vector2(24, -28)
	_hitbox.add_child(_hit_shape)
	add_child(_hitbox)


# ============================================================ main loop ==
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_player = _find_player()
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_ind_t = maxf(_ind_t - delta, 0.0)
	_flash_t = maxf(_flash_t - delta, 0.0)
	if _ind_t <= 0.0 and _indicator != null:
		_indicator.visible = false
	velocity.y = minf(velocity.y + gravity * delta, max_fall)

	match state:
		State.PATROL: _do_patrol(delta)
		State.CHASE: _do_chase(delta)
		State.SEARCH: _do_search(delta)
		State.ATTACK: _do_attack(delta)
		State.STAGGER: _do_stagger(delta)

	move_and_slide()
	_apply_visual(delta)
	_scan()


# -------------------------------------------------------------- senses ----
func _find_player() -> Node2D:
	if is_instance_valid(_player):
		return _player
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes.size() > 0 else null


func _los_to(target: Vector2) -> bool:
	var from := global_position + Vector2(0, -40)
	var q := PhysicsRayQueryParameters2D.create(from, target + Vector2(0, -30))
	q.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _scan() -> void:
	if state in [State.ATTACK, State.STAGGER, State.DEAD] or not is_instance_valid(_player):
		return
	var to_p := _player.global_position - global_position
	var in_ear := to_p.length() < 70.0
	var in_cone := absf(to_p.x) < vision_range and absf(to_p.y) < 80.0 \
		and signf(to_p.x) == _dir
	if (in_ear or in_cone) and _los_to(_player.global_position):
		if not _seen:
			_say("!", COLOR_ALERT, 0.9)
		_seen = true
		_last_seen = _player.global_position
		_lost_t = 0.0
		if state in [State.PATROL, State.SEARCH]:
			state = State.CHASE


func _say(text: String, color: Color, duration: float) -> void:
	if _indicator == null:
		return
	_indicator.text = text
	_indicator.modulate = color
	_indicator.visible = true
	_ind_t = duration


func _floor_ahead() -> bool:
	var from := global_position + Vector2(_dir * 20.0, -38.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 84.0))
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wall_ahead() -> bool:
	var from := global_position + Vector2(0, -28.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(_dir * 12.0, 0))
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


# -------------------------------------------------------------- states ----
func _do_patrol(delta: float) -> void:
	velocity.x = _dir * walk_speed
	if patrol_min_x < patrol_max_x:
		if global_position.x < patrol_min_x:
			_dir = 1.0
		elif global_position.x > patrol_max_x:
			_dir = -1.0
	if _wall_ahead() or not _floor_ahead():
		_dir = -_dir
		velocity.x = _dir * walk_speed


func _do_chase(delta: float) -> void:
	if not is_instance_valid(_player) or not _seen:
		state = State.SEARCH
		_search_t = 2.4
		_say("?", COLOR_QUESTION, 1.2)
		return
	var dx := _player.global_position.x - global_position.x
	if absf(dx) > 1.0:
		_dir = signf(dx)
	if not _los_to(_player.global_position):
		_lost_t += delta
		if _lost_t > 2.2:
			_seen = false
			state = State.SEARCH
			_search_t = 2.4
			_say("?", COLOR_QUESTION, 1.2)
			return
	else:
		_lost_t = 0.0
		_last_seen = _player.global_position
	if _in_attack_window() and _attack_cd <= 0.0:
		state = State.ATTACK
		_phase = Phase.NONE
		return
	var top := run_speed
	velocity.x = move_toward(velocity.x, _dir * top, 900.0 * delta)
	if _wall_ahead() or not _floor_ahead():
		velocity.x = 0.0


## Override point: when may this unit trigger its ATTACK state?
func _in_attack_window() -> bool:
	if not is_instance_valid(_player):
		return false
	var dx := absf(_player.global_position.x - global_position.x)
	var dy := absf(_player.global_position.y - global_position.y)
	return dx < attack_range and dy < 50.0


func _do_attack(delta: float) -> void:
	match _phase:
		Phase.NONE:
			_phase = Phase.WINDUP
			_windup_t = _pick_windup()
			velocity.x = 0.0
			_begin_windup()
		Phase.WINDUP:
			if is_instance_valid(_player):
				var dx := _player.global_position.x - global_position.x
				if absf(dx) > 1.0:
					_dir = signf(dx)
			_windup_t -= delta
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _windup_t <= 0.0:
				_phase = Phase.STRIKE
				_strike_t = attack_active
				_begin_strike()
		Phase.STRIKE:
			_strike_t -= delta
			if _strike_t <= 0.0:
				_phase = Phase.RECOVER
				_recover_t = recover_time
		Phase.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			_recover_t -= delta
			if _recover_t <= 0.0:
				_phase = Phase.NONE
				_attack_cd = attack_cooldown * randf_range(0.9, 1.25)
				state = State.CHASE


## Telegraph hooks (subclasses override durations/visuals)
func _pick_windup() -> float:
	return windup_time


func _begin_windup() -> void:
	_say("!", COLOR_ANGRY, maxf(_windup_t, 0.3))


func _begin_strike() -> void:
	# hitbox is a ROOT child (not under the flipped visual): use _dir here
	_hit_shape.position = Vector2(24.0 * _dir, -28)
	_hitbox.arm(attack_damage, Vector2(200 * _dir, -60), attack_active)


func _do_search(delta: float) -> void:
	_search_t -= delta
	var dx := _last_seen.x - global_position.x
	if absf(dx) > 12.0:
		_dir = signf(dx)
		velocity.x = move_toward(velocity.x, _dir * walk_speed, 700.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if _wall_ahead() or not _floor_ahead():
		velocity.x = 0.0
		_search_t = minf(_search_t, 0.4)
	if _search_t <= 0.0:
		state = State.PATROL


func _do_stagger(delta: float) -> void:
	_stagger_t -= delta
	velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
	if _stagger_t <= 0.0:
		state = State.CHASE if _seen else State.PATROL


# -------------------------------------------------------------- damage ----
func take_damage(amount: int, from_pos = null) -> void:
	if state == State.DEAD:
		return
	_health.take_damage(amount)
	if state == State.DEAD:
		return
	_flash_t = 0.12
	# aggression wakes up: a hit always reveals the player
	if is_instance_valid(_player):
		_seen = true
		_last_seen = _player.global_position
		_shout()
	var dir := -_dir
	if from_pos is Vector2:
		dir = signf(global_position.x - (from_pos as Vector2).x)
		if dir == 0.0:
			dir = -_dir
	velocity.x = dir * 130.0
	if not armor:
		state = State.STAGGER
		_stagger_t = stagger_time
		_phase = Phase.NONE
		if _hitbox != null:
			_hitbox.disarm()


func _shout() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.global_position.distance_to(global_position) < 300.0:
			e._seen = true
			e._last_seen = _last_seen
			if e.state == State.PATROL:
				e.state = State.SEARCH
				e._search_t = 2.8


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if _hitbox != null:
		_hitbox.disarm()
	if _indicator != null:
		_indicator.visible = false
	set_physics_process(false)
	died.emit()
	# ink-cut: tip over and fade like a torn panel
	var tw := create_tween().set_parallel()
	tw.tween_property(_visual, "rotation", _dir * -PI * 0.5, 0.5) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_poly, "color:a", 0.0, 1.6).set_delay(0.9)
	var fin := create_tween()
	fin.tween_interval(2.6)
	fin.tween_callback(queue_free)


# -------------------------------------------------------------- visuals ---
func _apply_visual(delta: float) -> void:
	if _visual != null:
		_visual.scale.x = lerpf(_visual.scale.x, _dir, clampf(14.0 * delta, 0.0, 1.0))
	if _poly != null:
		_poly.color = Color(1, 1, 1) if _flash_t > 0.0 else tint
		var squash := Vector2.ONE
		if state == State.ATTACK and _phase == Phase.WINDUP:
			squash = Vector2(1.12, 0.88)
		elif state == State.STAGGER:
			squash = Vector2(1.15, 0.85)
		_poly.scale = _poly.scale.lerp(squash, clampf(12.0 * delta, 0.0, 1.0))
	# placeholder sheet mirrors tint / squash of the old capsule
	if _sheet != null:
		_sheet.modulate = _poly.color
		_sheet.scale = Vector2(_sheet_sc * _poly.scale.x, _sheet_sc * _poly.scale.y)

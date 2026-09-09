## Enemy AI for Tito: The Crow's Curse (3D, X/Y side-scroller plane).
## States: PATROL -> ALERT (spotted) -> CHASE -> SEARCH (lost sight) -> ATTACK
## Smart behaviors:
##   - Vision cone + range + line-of-sight (walls block vision)
##   - Ledge-aware chase (stops at edges, does not blindly fall)
##   - Lost target: goes to last seen position, then searches nearby
##   - Attack only in range, with cooldown; returns to patrol if target dies
class_name TitoEnemy
extends CharacterBody3D

enum State { PATROL, CHASE, SEARCH, ATTACK, DEAD }

@export var patrol_min_x := -4.0
@export var patrol_max_x := 4.0
@export var walk_speed := 2.0
@export var run_speed := 4.5
@export var vision_range := 8.0
@export var vision_deg := 100.0
@export var attack_range := 1.6
@export var attack_cooldown := 1.0
@export var attack_active_time := 0.15
@export var attack_damage := 1
@export var search_time := 3.0
@export var gravity := 30.0
@export var z_lock := 0.0

var state := State.PATROL
var _player: Node3D
var _dir := 1.0
var _attack_timer := 0.0
var _search_timer := 0.0
var _swing_timer := 0.0
var _swing_hits := {}
var _last_seen := Vector3.ZERO
var _spawn := Transform3D()
var _visual: Node3D

@onready var _health: TitoHealth = $Health
@onready var _hitbox: Area3D = $Visual/HitBox

const EYE_HEIGHT := 0.8


func _ready() -> void:
	_spawn = global_transform
	_visual = get_node_or_null("Visual")
	add_to_group("enemies")
	_health.died.connect(_on_died)
	_pick_new_patrol_dir()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -25.0)

	_player = _find_player()

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.CHASE:
			_do_chase(delta)
		State.SEARCH:
			_do_search(delta)
		State.ATTACK:
			_do_attack(delta)

	velocity.z = 0.0
	global_position.z = z_lock
	move_and_slide()
	_apply_facing()


func _do_patrol(delta: float) -> void:
	velocity.x = move_toward(velocity.x, _dir * walk_speed, 20.0 * delta)
	if _at_patrol_edge() or _wall_ahead() or _ledge_ahead():
		_pick_new_patrol_dir()
	if _can_see_player():
		state = State.CHASE
		_last_seen = _player.global_position


func _do_chase(delta: float) -> void:
	if not is_instance_valid(_player):
		_enter_search()
		return
	var can_see := _can_see_player()
	if can_see:
		_last_seen = _player.global_position
	var dx := _last_seen.x - global_position.x
	# Chase direction drives wall/ledge checks and facing, not stale patrol dir.
	if absf(dx) > 0.05:
		_dir = signf(dx)
	if absf(dx) < 0.2 and is_on_floor():
		# Reached last seen spot without seeing the player -> search.
		_enter_search()
		return
	if _in_attack_range():
		state = State.ATTACK
		return
	# Smart pathing: never walk into walls or off ledges while chasing.
	if _wall_ahead():
		if _can_see_player():
			velocity.x = 0.0  # wait at the wall; player may come around
		else:
			_enter_search()
		return
	if _ledge_ahead():
		# Don't fall into pits chasing anyone.
		velocity.x = 0.0
		if not _can_see_player():
			_enter_search()
		return
	var speed := run_speed if can_see else run_speed * 0.7
	velocity.x = move_toward(velocity.x, signf(dx) * speed, 30.0 * delta)


func _do_search(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
	_search_timer -= delta
	if _can_see_player():
		state = State.CHASE
		return
	if _search_timer <= 0.0:
		state = State.PATROL
		_pick_new_patrol_dir()


func _do_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
	_attack_timer -= delta
	if not _in_attack_range():
		state = State.CHASE
		if _hitbox != null:
			_hitbox.monitoring = false
		_swing_timer = 0.0
		return
	# Face the player BEFORE the vision check: without this, a player who
	# circles behind mid-attack reads as "outside the cone" and the attack
	# silently drops into SEARCH with a stale _dir.
	if is_instance_valid(_player):
		var dx2 := _player.global_position.x - global_position.x
		if absf(dx2) > 0.05:
			_dir = signf(dx2)
	if not _can_see_player():
		_enter_search()
		if _hitbox != null:
			_hitbox.monitoring = false
		_swing_timer = 0.0
		return
	if _attack_timer <= 0.0:
		# Start a swing: hitbox opens NEXT physics frame (monitoring just-set
		# is not populated until the physics step flushes), stays open for
		# attack_active_time, each victim hit at most once per swing.
		_swing_timer = attack_active_time
		_swing_hits.clear()
		if _hitbox != null:
			_hitbox.monitoring = true
		_attack_timer = attack_cooldown
	# While the swing is open, apply damage to overlapping hurtboxes.
	if _swing_timer > 0.0:
		_swing_timer -= delta
		if _hitbox != null:
			TitoCombat.try_hit(self, "Visual/HitBox", ["player"], _swing_hits)
			if _swing_timer <= 0.0:
				_hitbox.monitoring = false


func _enter_search() -> void:
	state = State.SEARCH
	_search_timer = search_time


# ------------------------------------------------------------ perception --
func _find_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes.size() > 0 else null


func _can_see_player() -> bool:
	if not is_instance_valid(_player):
		return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var target := _player.global_position + Vector3.UP * 0.5
	var to_target := target - eye
	if to_target.length() > vision_range:
		return false
	if is_equal_approx(to_target.length(), 0.0):
		return true
	var facing_vec := Vector3(float(_dir), 0, 0)
	if rad_to_deg(facing_vec.angle_to(Vector3(to_target.x, 0, to_target.z))) > vision_deg * 0.5:
		return false
	# Line of sight: walls block vision. The ray ends INSIDE the player's own
	# collider, so a hit whose collider IS the player means the view is clear.
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == _player


func _in_attack_range() -> bool:
	return is_instance_valid(_player) \
		and absf(_player.global_position.x - global_position.x) < attack_range \
		and absf(_player.global_position.y - global_position.y) < 1.5


# ----------------------------------------------------------- environment --
func _at_patrol_edge() -> bool:
	return (global_position.x <= patrol_min_x and _dir < 0) \
		or (global_position.x >= patrol_max_x and _dir > 0)


func _wall_ahead() -> bool:
	var from := global_position + Vector3.UP * 0.5
	var to := from + Vector3(_dir, 0, 0) * 0.8
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _ledge_ahead() -> bool:
	if not is_on_floor():
		return false
	var from := global_position + Vector3(_dir * 0.7, -0.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _pick_new_patrol_dir() -> void:
	_dir = 1.0 if global_position.x <= patrol_min_x else -1.0


func _apply_facing() -> void:
	if _visual != null:
		_visual.rotation.y = 0.0 if _dir > 0 else PI


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	_health.take_damage(amount)
	# died -> _on_died ran synchronously and set DEAD; never un-die.
	if state == State.DEAD:
		return
	# Smart reaction: getting punched reveals the attacker even if unseen.
	_player = _find_player()
	if is_instance_valid(_player):
		_last_seen = _player.global_position
		state = State.CHASE
		velocity.x = 0.0


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	if _hitbox != null:
		_hitbox.monitoring = false
	# Greybox: disable collision and hide; swap for a death anim/ragdoll later.
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	hide()
	# Keep node alive so tests can inspect state; queue_free in production polish.

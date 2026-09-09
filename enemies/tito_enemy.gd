## Enemy AI for Tito: The Crow's Curse (3D, X/Y side-scroller plane).
##
## State machine:
##   PATROL -> SUSPICIOUS (heard something) -> CHASE -> ATTACK (WINDUP -> STRIKE -> RECOVER)
##   CHASE -> WATCH (prey visible but unreachable) -> SEARCH (lost) -> PATROL
##   any hit -> STAGGER, 0 hp -> DEAD (flop, fade, hide)
##
## Smarts over the old brain:
##   - Hearing: landing thumps and punched air nearby = investigated
##   - Reaction time with a startled hop + "!" bubble, shouts alert the pack
##   - Telegraphed attacks: wind-up -> committed lunge -> recovery (dodgeable)
##   - Pursuit platforming: steps up ledges/stairs, hops small gaps, drops down
##   - Flanking: second chaser circles to the free side of the player
##   - Separation steering so a pack doesn't stack into one blob
##   - Leads the target by player velocity while chasing
##   - Ducks back from repeat punches instead of eating every combo
##   - Search actually walks to the last-seen spot and scans both ways
##   - Full squash/stretch, lean, tint and knockback feedback (juice)
class_name TitoEnemy
extends CharacterBody3D

# NOTE: the first five indices are load-bearing (tests match on them).
enum State { PATROL, CHASE, SEARCH, ATTACK, DEAD, SUSPICIOUS, WATCH, STAGGER }
enum AttackPhase { NONE, WINDUP, STRIKE, RECOVER }

# ------------------------------------------------------------ tuning -----
@export var patrol_min_x := -4.0
@export var patrol_max_x := 4.0
@export var walk_speed := 2.0
@export var run_speed := 4.5
@export var vision_range := 8.0
@export var vision_deg := 100.0
@export var attack_range := 1.6
@export var attack_cooldown := 1.0
@export var attack_active_time := 0.16
@export var attack_damage := 1
@export var search_time := 3.0
@export var gravity := 30.0
@export var z_lock := 0.0

@export_group("Smarts")
@export var alert_time := 0.35      # startled freeze when freshly spotted
@export var suspect_time := 4.5     # how long a noise keeps it interested
@export var hearing_range := 6.0    # landing / punch noise radius
@export var pack_range := 12.0      # shout radius that wakes allies
@export var windup_time := 0.38     # readable telegraph before the lunge
@export var recover_time := 0.45    # punishable window after a swing
@export var lunge_speed := 7.0
@export var jump_velocity := 10.5   # apex ~1.8m: climbs stairs & pillars
@export var dodge_chance := 0.35    # vs REPEAT punches (the first always lands)
@export var aggression := 1.0       # per-enemy courage dial for level designers
@export var base_tint := Color(0.75, 0.2, 0.2)   # body color at rest (level dressing)

var state := State.PATROL

var _player: Node3D
var _dir := 1.0
var _aggr := 1.0
var _seen := false
var _last_seen := Vector3.ZERO
var _flank_side := 0.0
var _phase := AttackPhase.NONE
var _swing_hits := {}
var _spawn := Transform3D()

# timers
var _attack_timer := 0.0   # attack cooldown (tests poke this)
var _swing_timer := 0.0    # hitbox active window (tests poke this)
var _windup_timer := 0.0
var _recover_timer := 0.0
var _alert_timer := 0.0
var _search_timer := 0.0
var _sus_timer := 0.0
var _bored_timer := 0.0
var _blocked_timer := 0.0
var _stagger_timer := 0.0
var _shout_cd := 0.0
var _dodge_cd := 0.0
var _taunt_timer := 0.0
var _patrol_pause := 0.0
var _scan_timer := 0.0
var _resume_dir := -1.0
var _flank_check := 0.0
var _recent_swing_timer := 0.0
var _recent_swings := 0

# perception bookkeeping
var _player_was_floor := false
var _swing_edge_seen := false

# visuals / juice
var _visual: Node3D
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _indicator: Label3D
var _ind_timer := 0.0
var _flash_t := 0.0
var _squash_t := 0.0   # >0 squash (landed), <0 stretch (jumped)
var _floor_before := true
var _vy_before := 0.0

@onready var _health: TitoHealth = $Health
@onready var _hitbox: Area3D = $Visual/HitBox

const EYE_HEIGHT := 0.8
const COLOR_ALERT := Color(1.0, 0.85, 0.2)
const COLOR_QUESTION := Color(0.55, 0.85, 1.0)
const COLOR_ANGRY := Color(1.0, 0.3, 0.15)


func _ready() -> void:
	_spawn = global_transform
	_visual = get_node_or_null("Visual")
	_mesh = get_node_or_null("Visual/Mesh") as MeshInstance3D
	if _mesh != null and _mesh.material_override is StandardMaterial3D:
		# own copy of the material so state-tinting doesn't leak between enemies
		var src := _mesh.material_override as StandardMaterial3D
		_mat = src.duplicate() as StandardMaterial3D
		_mesh.material_override = _mat
	add_to_group("enemies")
	_health.died.connect(_on_died)
	_aggr = aggression * randf_range(0.92, 1.1)
	_build_indicator()
	_pick_new_patrol_dir()


func _build_indicator() -> void:
	_indicator = Label3D.new()
	_indicator.name = "Indicator"
	_indicator.position = Vector3(0.0, 1.5, 0.0)
	_indicator.font_size = 128
	_indicator.outline_size = 24
	_indicator.outline_modulate = Color(0, 0, 0, 0.9)
	_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_indicator.no_depth_test = true
	_indicator.visible = false
	add_child(_indicator)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_shout_cd = maxf(_shout_cd - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_recent_swing_timer -= delta
	if _recent_swing_timer <= 0.0:
		_recent_swings = 0
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -25.0)

	_player = _find_player()
	_update_perception()

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.SUSPICIOUS:
			_do_suspicious(delta)
		State.CHASE:
			_do_chase(delta)
		State.SEARCH:
			_do_search(delta)
		State.WATCH:
			_do_watch(delta)
		State.STAGGER:
			_do_stagger(delta)
		State.ATTACK:
			_do_attack(delta)

	_apply_separation()
	_floor_before = is_on_floor()
	_vy_before = velocity.y
	velocity.z = 0.0
	global_position.z = z_lock
	move_and_slide()
	_land_feedback()
	_update_indicator(delta)
	_apply_visual(delta)
	if global_position.y < -40.0:
		fell_out()  # parachute: never leave a body falling forever


# ------------------------------------------------------------ patrol -----
func _do_patrol(delta: float) -> void:
	if _seen:
		_go_chase(true)
		return
	if _patrol_pause > 0.0:
		# paused at an edge: actually LOOK around (nearly covers both flanks)
		_patrol_pause -= delta
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_dir = -_dir
			_scan_timer = 0.45
		if _patrol_pause <= 0.0:
			_dir = _resume_dir
		return
	velocity.x = move_toward(velocity.x, _dir * walk_speed * _aggr, 20.0 * delta)
	if _at_patrol_edge() or _wall_ahead() or _ledge_ahead():
		_resume_dir = -_dir
		_patrol_pause = randf_range(0.4, 1.1)
		_scan_timer = 0.3


# ---------------------------------------------------------- suspicious ---
func _do_suspicious(delta: float) -> void:
	_assert_indicator("?", COLOR_QUESTION)
	if _seen:
		_go_chase(true)  # suspicion confirmed: startle, shout, chase
		return
	_sus_timer -= delta
	if _sus_timer <= 0.0:
		_give_up()
		return
	var dx := _last_seen.x - global_position.x
	if absf(dx) < 0.35 or _wall_ahead() or _ledge_ahead():
		_enter_search()  # arrived (or got blocked): look around
		return
	_dir = signf(dx)
	velocity.x = move_toward(velocity.x, _dir * walk_speed * 1.6 * _aggr, 25.0 * delta)


# -------------------------------------------------------------- chase ----
func _do_chase(delta: float) -> void:
	if not is_instance_valid(_player):
		_enter_search()
		return
	# freshly spotted: startled freeze (the player's window to react or run)
	if _alert_timer > 0.0:
		_alert_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		if _seen:
			_last_seen = _player.global_position
		return

	if _seen:
		# lead the target — run where they are GOING, not where they were
		_last_seen = _player.global_position
		_last_seen.x += _player.velocity.x * 0.18
		_flank_check -= delta
		if _flank_check <= 0.0:
			_flank_check = 0.5
			_update_flanking()

	var target_x := _last_seen.x
	if _seen and _flank_side != 0.0:
		target_x = _player.global_position.x + _flank_side * 1.25
	var dx := target_x - global_position.x
	if absf(dx) > 0.05:
		_dir = signf(dx)

	if not _seen and absf(_last_seen.x - global_position.x) < 0.3 and is_on_floor():
		# arrived at the memory and it's empty: look around
		_enter_search()
		return

	var pdx := _player.global_position.x - global_position.x
	var pdy := _player.global_position.y - global_position.y
	if _seen and is_on_floor() and _attack_timer <= 0.0 and _in_attack_window():
		state = State.ATTACK
		_phase = AttackPhase.NONE
		velocity.x = 0.0
		return

	# never stand inside the player's model — jockey for space instead
	if absf(pdx) < 0.65 and absf(pdy) < 1.4:
		var away := -signf(pdx)
		if away == 0.0:
			away = -_dir
		velocity.x = move_toward(velocity.x, away * 2.5, 40.0 * delta)
		return

	_maybe_dodge()

	# smart traversal: climb stairs/ledges after prey, hop small gaps, drop down.
	# Only re-planned while grounded — mid-air we keep our committed momentum.
	if is_on_floor():
		if _wall_ahead():
			if not _try_step_up():
				velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
				if _seen:
					_blocked_timer += delta
					if _blocked_timer > 0.8:
						_enter_watch()
				else:
					_enter_search()
			return
		if _ledge_ahead():
			if not _try_gap_hop() and not _try_drop_down():
				velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
				if _seen:
					_blocked_timer += delta
					if _blocked_timer > 0.8:
						_enter_watch()
				else:
					_enter_search()
			return
		_blocked_timer = 0.0
	var speed := run_speed * _aggr if _seen else run_speed * 0.72 * _aggr
	velocity.x = move_toward(velocity.x, _dir * speed, 30.0 * delta)


# -------------------------------------------------------------- watch ----
## Prey is visible but unreachable (on a pillar, across a pit): pin them with
## a stare, taunt-hop, and pounce the instant a path exists — or get bored.
func _do_watch(delta: float) -> void:
	_assert_indicator("!", COLOR_ANGRY)
	if not is_instance_valid(_player):
		_enter_search()
		return
	velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
	var pdx := _player.global_position.x - global_position.x
	if absf(pdx) > 0.05:
		_dir = signf(pdx)
	if _seen:
		_bored_timer = 0.0
	else:
		_bored_timer += delta
		if _bored_timer > 1.0:
			_enter_search()
			return
	# frustrated hop — a frozen guard reads as broken, a hopping one reads as mad
	_taunt_timer -= delta
	if _taunt_timer <= 0.0 and is_on_floor():
		_taunt_timer = 1.15
		velocity.y = 3.0
		_squash_t = -0.06
	if _seen and is_on_floor() and _attack_timer <= 0.0 and _in_attack_window():
		state = State.ATTACK
		_phase = AttackPhase.NONE
		velocity.x = 0.0
		return
	# pounce the moment a route exists (never decide this while mid-hop)
	if _seen and is_on_floor() and _path_resumable():
		_blocked_timer = 0.0
		state = State.CHASE
		return
	# while the prey is visible a good guard never stands down; the boredom
	# timer above (sight lost > 1s) is what sends it searching again.


# -------------------------------------------------------------- search ---
func _do_search(delta: float) -> void:
	_assert_indicator("?", COLOR_QUESTION)
	if _seen:
		_go_chase(false)  # already hunting: no startle, straight back to pursuit
		return
	_search_timer -= delta
	if _search_timer <= 0.0:
		_give_up()
		return
	var dx := _last_seen.x - global_position.x
	if absf(dx) > 0.35 and not _wall_ahead() and not _ledge_ahead():
		_dir = signf(dx)
		velocity.x = move_toward(velocity.x, _dir * walk_speed * 1.3, 25.0 * delta)
	else:
		# at the spot: scan BOTH ways, not just stare at a wall
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_dir = -_dir
			_scan_timer = 0.55


# ------------------------------------------------------------- stagger ---
func _do_stagger(delta: float) -> void:
	_stagger_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	if _stagger_timer <= 0.0:
		state = State.CHASE  # furious: skip the startle freeze
		if is_instance_valid(_player):
			_last_seen = _player.global_position


# -------------------------------------------------------------- attack ---
## Telegraphed, committed strike: WINDUP tracks the player, STRIKE lunges
## with a live hitbox, RECOVER is a punish window, then cooldown.
func _do_attack(delta: float) -> void:
	if _hitbox == null:
		state = State.CHASE
		return
	if not is_instance_valid(_player):
		_abort_attack()
		_enter_search()
		return
	if _phase == AttackPhase.NONE:
		_begin_windup()
	match _phase:
		AttackPhase.WINDUP:
			# track until the very last moment, then commit
			var dx := _player.global_position.x - global_position.x
			if absf(dx) > 0.05:
				_dir = signf(dx)
			velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
			_windup_timer -= delta
			if _windup_timer <= 0.0:
				_begin_strike()
		AttackPhase.STRIKE:
			_swing_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
			TitoCombat.try_hit(self, "Visual/HitBox", ["player"], _swing_hits)
			if _swing_timer <= 0.0:
				_hitbox.monitoring = false
				_phase = AttackPhase.RECOVER
				_recover_timer = recover_time * randf_range(0.85, 1.25)
		AttackPhase.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
			_recover_timer -= delta
			if _recover_timer <= 0.0:
				_attack_timer = attack_cooldown * randf_range(0.9, 1.3) / _aggr
				_phase = AttackPhase.NONE
				state = State.CHASE


func _begin_windup() -> void:
	_phase = AttackPhase.WINDUP
	# per-swing variance: the player can't perfectly memorize the timing
	_windup_timer = (windup_time / _aggr) * randf_range(0.8, 1.25)
	if is_instance_valid(_player):
		var dx := _player.global_position.x - global_position.x
		if absf(dx) > 0.05:
			_dir = signf(dx)
	_set_indicator("!", COLOR_ANGRY, maxf(_windup_timer, 0.25))
	velocity.x = 0.0


func _begin_strike() -> void:
	_phase = AttackPhase.STRIKE
	_swing_timer = attack_active_time
	_swing_hits.clear()
	_hitbox.monitoring = true
	velocity.x = _dir * lunge_speed * _aggr
	if is_instance_valid(_player):
		var dy := _player.global_position.y - global_position.y
		var dx := absf(_player.global_position.x - global_position.x)
		# anti-air: pop up to swat jump-overs and ledge-teasers
		if dy > 0.9 and dx < 1.8 and is_on_floor():
			velocity.y = 6.5


func _abort_attack() -> void:
	if _hitbox != null:
		_hitbox.monitoring = false
	_phase = AttackPhase.NONE
	_swing_timer = 0.0


# --------------------------------------------------------- transitions ---
func _go_chase(fresh: bool) -> void:
	var was_chasing := state == State.CHASE
	state = State.CHASE
	_blocked_timer = 0.0
	if fresh and not was_chasing:
		_startle()


func _startle() -> void:
	if is_instance_valid(_player):
		_last_seen = _player.global_position
	_alert_timer = alert_time * randf_range(0.8, 1.3)
	velocity.x = 0.0
	if is_on_floor():
		velocity.y = 2.6  # startled hop
	_squash_t = -0.12
	_set_indicator("!", COLOR_ALERT, 1.0)
	if is_instance_valid(_player):
		_shout(_player.global_position)


func _enter_search() -> void:
	_abort_attack()
	_flank_side = 0.0
	state = State.SEARCH
	_search_timer = search_time
	_scan_timer = 0.5
	_set_indicator("?", COLOR_QUESTION, 1.6)


func _enter_watch() -> void:
	state = State.WATCH
	_bored_timer = 0.0
	_blocked_timer = 0.0
	_taunt_timer = 0.55
	_assert_indicator("!", COLOR_ANGRY)


func _give_up() -> void:
	_abort_attack()
	_flank_side = 0.0
	_clear_indicator()
	state = State.PATROL
	_patrol_pause = 0.0
	_pick_new_patrol_dir()


# ------------------------------------------------------------- pack -------
func _shout(pos: Vector3) -> void:
	if _shout_cd > 0.0:
		return
	_shout_cd = 2.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not (e is TitoEnemy):
			continue
		var o := e as TitoEnemy
		if o.state == State.DEAD:
			continue
		if o.global_position.distance_to(global_position) > pack_range:
			continue
		o.hear_alert(pos)


## Heard a shout/noise. Never interrupts an active fight or a fresh corpse.
func hear_alert(pos: Vector3) -> void:
	if state == State.DEAD:
		return
	if state in [State.CHASE, State.ATTACK, State.STAGGER]:
		return
	_last_seen = pos
	if state in [State.PATROL, State.WATCH]:
		state = State.SUSPICIOUS
		_sus_timer = suspect_time
		_patrol_pause = 0.0
		_set_indicator("?", COLOR_QUESTION, 1.4)
	elif state == State.SUSPICIOUS:
		_sus_timer = maxf(_sus_timer, suspect_time * 0.6)
	# SEARCH silently redirects: it walks to _last_seen anyway


# ------------------------------------------------------- group tactics ---
## If an ally is already on my side of the player (and closer), I circle to
## the free side — the classic pincer. Cheap, legible, very effective.
func _update_flanking() -> void:
	_flank_side = 0.0
	if not is_instance_valid(_player):
		return
	var me_side := signf(global_position.x - _player.global_position.x)
	if me_side == 0.0:
		return
	var my_dist := absf(global_position.x - _player.global_position.x)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not (e is TitoEnemy):
			continue
		var o := e as TitoEnemy
		if o.state == State.DEAD:
			continue
		if not o.state in [State.CHASE, State.ATTACK, State.STAGGER, State.WATCH]:
			continue
		if absf(o.global_position.x - _player.global_position.x) > my_dist - 0.6:
			continue
		if signf(o.global_position.x - _player.global_position.x) == me_side:
			_flank_side = -me_side
			return


## Repeat-punch respect: the FIRST hit of a stretch always lands (fair), but
## hold down the punch button and they start hopping out of your rhythm.
func _maybe_dodge() -> void:
	if _dodge_cd > 0.0 or not is_on_floor() or not _seen:
		return
	var sv = _player.get("_swing_timer")
	if sv == null:
		return
	var swinging := float(sv) > 0.0
	var rising := swinging and not _swing_edge_seen
	_swing_edge_seen = swinging
	if not rising:
		return
	var pdx := _player.global_position.x - global_position.x
	if absf(pdx) > 2.1 or absf(_player.global_position.y - global_position.y) > 1.2:
		return
	_recent_swings += 1
	_recent_swing_timer = 2.8
	if _recent_swings < 2:
		return
	if randf() > dodge_chance:
		return
	_dodge_cd = randf_range(1.2, 2.0)
	var back := -_dir
	if _floor_at(global_position.x + back * 1.1):
		velocity.x = back * 4.6
		_squash_t = -0.08


func _apply_separation() -> void:
	if not is_on_floor():
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not (e is TitoEnemy):
			continue
		var o := e as TitoEnemy
		if o.state == State.DEAD:
			continue
		var odx := global_position.x - o.global_position.x
		if absf(odx) < 0.05 or absf(odx) > 1.1:
			continue
		if absf(o.global_position.y - global_position.y) > 1.2:
			continue
		# shove apart, but never shove a buddy off a cliff
		if _floor_at(global_position.x + signf(odx) * 0.75):
			velocity.x += signf(odx) * 1.35


# ------------------------------------------------------------ traversal --
func _step_up_available() -> bool:
	if not is_on_floor() or not _seen:
		return false
	var want_up := _player.global_position.y > global_position.y + 0.45
	var probe_from := global_position + Vector3(_dir * 1.0, 1.9, 0)
	var q := PhysicsRayQueryParameters3D.create(probe_from, probe_from + Vector3.DOWN * 2.1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	var rise: float = (hit.position as Vector3).y - (global_position.y - 0.9)
	if rise > 1.55 or rise < 0.05:
		return false
	if not want_up and rise > 0.75:
		return false  # tall walls are only worth climbing when prey is up there
	var clr := PhysicsRayQueryParameters3D.create(
		hit.position + Vector3.UP * 0.1, hit.position + Vector3.UP * 1.75)
	clr.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(clr).is_empty()


func _try_step_up() -> bool:
	if not _step_up_available():
		return false
	velocity.y = jump_velocity
	velocity.x = _dir * walk_speed  # carry over the lip
	_squash_t = -0.14
	return true


func _gap_hop_available() -> bool:
	if not is_on_floor() or not _seen:
		return false
	var to_p := _player.global_position - global_position
	if absf(to_p.y) > 1.6 or to_p.x * _dir <= 0.0 or absf(to_p.x) > 4.6:
		return false
	for d in [1.1, 1.7, 2.3]:
		var from := global_position + Vector3(_dir * d, 0.35, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.4)
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			continue
		if (hit.position as Vector3).y < global_position.y - 2.2:
			continue  # that's a swan dive, not a hop
		return true
	return false


func _try_gap_hop() -> bool:
	if not _gap_hop_available():
		return false
	velocity.y = jump_velocity * 0.75
	velocity.x = _dir * run_speed * 0.95
	_squash_t = -0.12
	return true


func _drop_down_available() -> bool:
	if not is_on_floor() or not _seen:
		return false
	var dy := _player.global_position.y - global_position.y
	var dx := absf(_player.global_position.x - global_position.x)
	if dy > -1.2 or dy < -6.0 or dx > 3.0:
		return false
	var from := global_position + Vector3(_dir * 0.8, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.5)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	# walk off only when the landing is roughly at the prey's level
	return (hit.position as Vector3).y > _player.global_position.y - 1.6


func _try_drop_down() -> bool:
	if not _drop_down_available():
		return false
	velocity.x = _dir * walk_speed * 1.5  # just stroll off the edge
	return true


func _path_resumable() -> bool:
	if _wall_ahead():
		return _step_up_available()
	if _ledge_ahead():
		return _gap_hop_available() or _drop_down_available()
	return true


# ------------------------------------------------------------ perception --
func _update_perception() -> void:
	_seen = _can_see_player()
	if not is_instance_valid(_player):
		return
	var pf: bool = _player.is_on_floor()
	var sv = _player.get("_swing_timer")
	var swinging := sv != null and float(sv) > 0.0
	if not _seen and state in [State.PATROL, State.SUSPICIOUS, State.SEARCH]:
		var close := absf(_player.global_position.x - global_position.x) < hearing_range \
			and absf(_player.global_position.y - global_position.y) < 3.0
		# you are NOT silent: hard landings and punched air carry
		if close and ((pf and not _player_was_floor) or (swinging and not _swing_edge_seen)):
			_heard_something(_player.global_position)
	_player_was_floor = pf


func _heard_something(pos: Vector3) -> void:
	_last_seen = pos
	if state == State.PATROL:
		state = State.SUSPICIOUS
		_sus_timer = suspect_time
		_patrol_pause = 0.0
		_set_indicator("?", COLOR_QUESTION, 1.4)
	elif state == State.SUSPICIOUS:
		_sus_timer = suspect_time  # refresh interest
	# SEARCH redirects silently via _last_seen


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


## Trigger window for starting a wind-up: slightly generous horizontally
## (the lunge closes it) and tall enough to punish jump-overs.
func _in_attack_window() -> bool:
	return is_instance_valid(_player) \
		and absf(_player.global_position.x - global_position.x) < attack_range + 0.65 \
		and absf(_player.global_position.y - global_position.y) < 1.75


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


func _floor_at(x_pos: float) -> bool:
	var from := Vector3(x_pos, global_position.y + 0.3, global_position.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.6)
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _pick_new_patrol_dir() -> void:
	_dir = 1.0 if global_position.x <= patrol_min_x else -1.0


# -------------------------------------------------------------- feedback --
func _apply_visual(delta: float) -> void:
	if _visual != null:
		var target_yaw := 0.0 if _dir > 0.0 else PI
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, clampf(14.0 * delta, 0.0, 1.0))
	if _mesh != null:
		var want_scale := Vector3.ONE
		var want_roll := 0.0
		match state:
			State.SUSPICIOUS:
				want_scale = Vector3(0.98, 0.97, 0.98)
			State.CHASE:
				want_roll = -0.10
			State.WATCH:
				want_scale = Vector3(0.97, 0.95, 0.97)
			State.STAGGER:
				want_roll = 0.22
			State.ATTACK:
				match _phase:
					AttackPhase.WINDUP:
						want_roll = 0.32
						want_scale = Vector3(0.94, 1.07, 0.94)
					AttackPhase.STRIKE:
						want_roll = -0.30
						want_scale = Vector3(1.14, 0.88, 0.94)
					AttackPhase.RECOVER:
						want_roll = -0.06
						want_scale = Vector3(0.98, 0.99, 0.98)
		# squash & stretch overlay
		if _squash_t > 0.0:
			_squash_t = maxf(_squash_t - delta, 0.0)
			var ks := _squash_t * 2.6
			want_scale.x *= 1.0 + 0.28 * ks
			want_scale.y *= 1.0 - 0.30 * ks
		elif _squash_t < 0.0:
			_squash_t = minf(_squash_t + delta, 0.0)
			var kt := -_squash_t * 3.0
			want_scale.x *= 1.0 - 0.18 * kt
			want_scale.y *= 1.0 + 0.22 * kt
		_mesh.scale = _mesh.scale.lerp(want_scale, clampf(12.0 * delta, 0.0, 1.0))
		_mesh.rotation.z = lerpf(_mesh.rotation.z, want_roll, clampf(10.0 * delta, 0.0, 1.0))
	if _mat != null:
		var c := _state_tint()
		if _flash_t > 0.0:
			_flash_t -= delta
			c = Color(1, 1, 1)
		_mat.albedo_color = _mat.albedo_color.lerp(c, clampf(9.0 * delta, 0.0, 1.0))


func _state_tint() -> Color:
	match state:
		State.PATROL:
			return base_tint
		State.SUSPICIOUS:
			return base_tint.lerp(Color(0.85, 0.5, 0.15), 0.75)
		State.CHASE:
			return base_tint.lerp(Color(0.9, 0.12, 0.12), 0.8)
		State.SEARCH:
			return base_tint.lerp(Color(0.7, 0.45, 0.3), 0.7)
		State.WATCH:
			return base_tint.lerp(Color(0.8, 0.3, 0.3), 0.7)
		State.STAGGER:
			return Color(1.0, 0.8, 0.6)
		State.ATTACK:
			match _phase:
				AttackPhase.WINDUP:
					return Color(1.0, 0.45, 0.1)
				AttackPhase.STRIKE:
					return Color(1.0, 0.1, 0.05)
	return base_tint


func _land_feedback() -> void:
	if is_on_floor() and not _floor_before and _vy_before < -6.0:
		_squash_t = 0.15


func _set_indicator(text: String, color: Color, duration: float) -> void:
	if _indicator == null:
		return
	_indicator.text = text
	_indicator.modulate = color
	_indicator.visible = true
	_ind_timer = duration


func _assert_indicator(text: String, color: Color) -> void:
	# keep a state bubble alive while the state lasts
	if _indicator == null or not _indicator.visible or _indicator.text != text:
		_set_indicator(text, color, 0.5)


func _clear_indicator() -> void:
	if _indicator != null:
		_indicator.visible = false
	_ind_timer = 0.0


func _update_indicator(delta: float) -> void:
	if _ind_timer > 0.0:
		_ind_timer -= delta
		if _ind_timer <= 0.0:
			_clear_indicator()


# --------------------------------------------------------------- damage ---
func take_damage(amount: int, from_pos = null) -> void:
	if state == State.DEAD:
		return
	_health.take_damage(amount)
	_flash_t = 0.15
	_squash_t = 0.10
	# died -> _on_died ran synchronously and set DEAD; never un-die.
	if state == State.DEAD:
		return
	_abort_attack()
	_clear_indicator()
	_player = _find_player()
	if is_instance_valid(_player):
		_last_seen = _player.global_position
		_shout(_player.global_position)  # "I'm hit! Over here!"
	# knockback away from the source — getting combo'd actually moves them
	var kb := -_dir
	if from_pos is Vector3 and not is_equal_approx((from_pos as Vector3).x, global_position.x):
		kb = signf(global_position.x - (from_pos as Vector3).x)
	elif is_instance_valid(_player) \
		and not is_equal_approx(_player.global_position.x, global_position.x):
		kb = signf(global_position.x - _player.global_position.x)
	if kb == 0.0:
		kb = -_dir
	velocity.x = kb * 4.5
	if is_on_floor():
		velocity.y = 2.6
	_alert_timer = 0.0
	state = State.STAGGER
	_stagger_timer = 0.32


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	_abort_attack()
	_clear_indicator()
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	# flop over, grey out, then vanish (corpse-free greybox, but with dignity)
	if _mesh != null:
		var tw := get_tree().create_tween()
		tw.set_parallel(true)
		tw.tween_property(_mesh, "rotation:z", PI * 0.5, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if _mat != null:
			tw.tween_property(_mat, "albedo_color", Color(0.25, 0.25, 0.28), 0.45)
		tw.set_parallel(false)
		tw.tween_interval(0.35)
		tw.tween_callback(hide)
	else:
		hide()
	# Keep node alive so tests can inspect state; queue_free in production polish.


## Pit safety net for enemies (knocked in or misjudged a hop): dust off and
## return to the post, a little embarrassed.
func fell_out() -> void:
	global_position = _spawn.origin
	velocity = Vector3.ZERO
	_last_seen = _spawn.origin
	_abort_attack()
	_clear_indicator()
	_flank_side = 0.0
	_alert_timer = 0.0
	_blocked_timer = 0.0
	_squash_t = 0.15
	state = State.PATROL
	_pick_new_patrol_dir()

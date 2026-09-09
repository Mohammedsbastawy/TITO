## "El-Ghorab" (The Raven) — two-phase rooftop boss.
##
## Tells & counters (Hollow-Knight-style rigor, mapped to THIS controller):
##   TRIPLE-SHOT DRILL  -> shots 1-2 fly at chest (CROUCH under), shot 3 flies low (JUMP over)
##   TACTICAL RUSH      -> telegraphed floor dash; jump it, then punish RUSH_RECOVER
##   RELOAD             -> 2.0 s of vulnerability, the main damage window
##   (Phase 2, <40% hp)
##   SKY SLAM           -> drops on your head, spawns two floor shockwaves (jump them)
##   LASER SWEEP        -> red floor grid telegraph, then a floor-wide burst:
##                         be airborne OR standing on a steel girder (y >= safe line)
##   REVERSAL STANCE    -> glowing guard: punching him eats a counter grab-throw
##
## Poise: he never staggers from punches. Kill him through windows of discipline.
class_name GhorabBoss
extends CharacterBody3D

signal boss_died(boss)

enum St { CINEMA, IDLE, APPROACH, TRIPLE_AIM, TRIPLE_FIRE, RUSH_AIM, RUSHING, RUSH_RECOVER,
	RELOAD, SLAM_AIR, SLAM_LAND, SWEEP_TEL, SWEEP_FIRE, REVERSAL, GRAB_DASH, GRAB_RECOVER, DEAD }

@export var arena_min_x := 117.0
@export var arena_max_x := 143.0
@export var sweep_safe_y := 11.5
@export var max_hp := 42
@export var walk_speed := 3.6
@export var rush_speed := 15.0
@export var gravity := 34.0
@export var z_lock := 0.0
@export var coat_tint := Color(0.12, 0.14, 0.20)

var state := St.CINEMA
var hp := 0
var _phase_two := false
var _dir := -1.0
var _player: Node3D
var _timer := 0.0
var _shots_left := 0
var _shot_gap := 0.0
var _pattern_idx := 0
var _idle_pace := 0.0
var _rush_hit := false
var _visual: Node3D
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _hp_fg: MeshInstance3D
var _indicator: Label3D
var _flash_t := 0.0
var _sweep_panels: Array[MeshInstance3D] = []
var _floor_before := true
var _vy_before := 0.0

const P1 := ["triple", "approach", "triple", "rush", "reload", "approach", "triple", "reversal", "rush", "reload"]
const P2 := ["slam", "triple", "sweep", "rush", "reversal", "reload", "slam", "sweep", "triple", "reload"]
const SHOT_HEIGHTS := [1.25, 1.25, 0.42]
const COLOR_TELL := Color(1.0, 0.3, 0.15)


func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_build_body()
	_build_hurtbox()
	_build_hp_bar()
	_build_indicator()


func _build_body() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_mesh = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 2.1
	_mesh.mesh = cap
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = coat_tint
	_mat.roughness = 0.55
	_mesh.material_override = _mat
	_visual.add_child(_mesh)
	# shoulders + long coat skirt so he looms wider than a man
	for side in [-1, 1]:
		var sh := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.5, 0.28, 0.35)
		sh.mesh = sb
		sh.material_override = _mat
		sh.position = Vector3(0.1, 0.85, side * 0.42)
		_visual.add_child(sh)
	# wide-brim hat + ember eyes: you always know where the Raven looks
	var hat := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.34
	hm.bottom_radius = 0.38
	hm.height = 0.34
	hat.mesh = hm
	hat.material_override = _mat
	hat.position = Vector3(0, 1.22, 0)
	_visual.add_child(hat)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.45, 0.15)
	for ez in [-0.11, 0.11]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.045
		es.height = 0.09
		eye.mesh = es
		eye.material_override = eye_mat
		eye.position = Vector3(0.38, 1.02, ez * 2.0)
		_visual.add_child(eye)


func _build_hurtbox() -> void:
	var hb := Area3D.new()
	hb.collision_layer = 4
	hb.collision_mask = 0
	hb.monitoring = false
	hb.monitorable = true
	hb.add_to_group("hurtbox")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 2.2
	cs.shape = cap
	hb.add_child(cs)
	add_child(hb)


func _build_hp_bar() -> void:
	var bar := Node3D.new()
	bar.position = Vector3(0, 1.9, 0)
	add_child(bar)
	var bg := MeshInstance3D.new()
	var bgb := BoxMesh.new()
	bgb.size = Vector3(1.9, 0.13, 0.05)
	bg.mesh = bgb
	var bgm := StandardMaterial3D.new()
	bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bgm.albedo_color = Color(0.05, 0.05, 0.08, 0.85)
	bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg.material_override = bgm
	bar.add_child(bg)
	_hp_fg = MeshInstance3D.new()
	var fgb := BoxMesh.new()
	fgb.size = Vector3(1.82, 0.09, 0.05)
	_hp_fg.mesh = fgb
	var fgm := StandardMaterial3D.new()
	fgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fgm.albedo_color = Color(0.85, 0.2, 0.15)
	_hp_fg.material_override = fgm
	bar.add_child(_hp_fg)


func _build_indicator() -> void:
	_indicator = Label3D.new()
	_indicator.position = Vector3(0, 2.3, 0)
	_indicator.font_size = 110
	_indicator.outline_size = 18
	_indicator.outline_modulate = Color(0, 0, 0, 0.9)
	_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_indicator.no_depth_test = true
	_indicator.visible = false
	add_child(_indicator)


func begin_fight() -> void:
	if state == St.CINEMA:
		state = St.IDLE
		_idle_pace = 0.6


# ------------------------------------------------------------- main loop --
func _physics_process(delta: float) -> void:
	if state == St.DEAD:
		return
	_player = _find_player()
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -30.0)
	_flash_t = maxf(_flash_t - delta, 0.0)

	match state:
		St.CINEMA:
			_face_player()
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		St.IDLE:
			_do_idle(delta)
		St.APPROACH:
			_do_approach(delta)
		St.TRIPLE_AIM:
			_do_triple_aim(delta)
		St.TRIPLE_FIRE:
			_do_triple_fire(delta)
		St.RUSH_AIM:
			_do_rush_aim(delta)
		St.RUSHING:
			_do_rushing(delta)
		St.RUSH_RECOVER, St.GRAB_RECOVER:
			_do_recover(delta)
		St.RELOAD:
			_do_reload(delta)
		St.SLAM_AIR:
			_do_slam_air(delta)
		St.SLAM_LAND:
			_do_slam_land(delta)
		St.SWEEP_TEL:
			_do_sweep_tel(delta)
		St.SWEEP_FIRE:
			_do_sweep_fire(delta)
		St.REVERSAL:
			_do_reversal(delta)
		St.GRAB_DASH:
			_do_grab_dash(delta)

	_floor_before = is_on_floor()
	_vy_before = velocity.y
	velocity.z = 0.0
	global_position.z = z_lock
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_min_x + 0.4, arena_max_x - 0.4)
	_apply_visual(delta)


# ------------------------------------------------------------ behaviors ---
func _do_idle(delta: float) -> void:
	_face_player()
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	_idle_pace -= delta
	if _idle_pace <= 0.0:
		_start_pattern(_next_pattern())


func _next_pattern() -> String:
	var list := P2 if _phase_two else P1
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
			_timer = 0.5
			_say("!!")
		"reload":
			state = St.RELOAD
			_timer = 2.0
			_say("…", Color(0.55, 0.85, 1.0))
		"slam":
			_leap_at_player()
		"sweep":
			state = St.SWEEP_TEL
			_timer = 1.4
			_build_sweep_telegraph()
			_say("!!!")
		"reversal":
			state = St.REVERSAL
			_timer = 2.2
			_say("🛡", COLOR_TELL)  # guard glyph
			if _mat != null:
				_mat.albedo_color = coat_tint.lerp(Color(0.5, 0.2, 0.6), 0.8)


func _do_approach(delta: float) -> void:
	if not is_instance_valid(_player):
		state = St.IDLE
		_idle_pace = 0.4
		return
	_face_player()
	var dx := _player.global_position.x - global_position.x
	if absf(dx) < 2.1:
		velocity.x = 0.0
		state = St.IDLE
		_idle_pace = 0.15
		return
	velocity.x = move_toward(velocity.x, signf(dx) * walk_speed * (1.2 if _phase_two else 1.0), 25.0 * delta)
	# never stroll off the arena edge
	if _ledge_ahead():
		velocity.x = 0.0
		state = St.IDLE
		_idle_pace = 0.3


# ---- triple shot drill: chest, chest, then LOW — crouch, crouch, jump ----
func _do_triple_aim(delta: float) -> void:
	_face_player()
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	_timer -= delta
	if _timer <= 0.0:
		state = St.TRIPLE_FIRE
		_shots_left = 3
		_shot_gap = 0.0


func _do_triple_fire(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	_shot_gap -= delta
	if _shot_gap <= 0.0 and _shots_left > 0:
		_fire_shot(SHOT_HEIGHTS[3 - _shots_left])
		_shots_left -= 1
		_shot_gap = 0.34
	if _shots_left <= 0 and _shot_gap <= 0.0:
		state = St.IDLE
		_idle_pace = 0.3


func _fire_shot(height: float) -> void:
	var from := global_position + Vector3.UP * height
	var dir := Vector3(_dir, 0, 0)
	var shot := TitoProjectile.new()
	shot.speed = 13.0
	shot.damage = 1
	shot.life = 3.5
	get_parent().add_child(shot)
	var bolt := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.09
	bm.height = 0.18
	bolt.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.5, 0.2)
	bolt.material_override = mat
	shot.add_child(bolt)
	shot.launch(from, dir)


# ---- rush: jump the dash, then he eats wall and is YOURS for 0.8 s --------
func _do_rush_aim(delta: float) -> void:
	_face_player()
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	_timer -= delta
	if _timer <= 0.0:
		state = St.RUSHING
		_rush_hit = false
		_timer = 1.0


func _do_rushing(delta: float) -> void:
	_timer -= delta
	velocity.x = _dir * rush_speed
	if not _rush_hit and is_instance_valid(_player):
		var pdx := absf(_player.global_position.x - global_position.x)
		var pdy := absf(_player.global_position.y - global_position.y)
		if pdx < 1.0 and pdy < 1.7:
			_rush_hit = true
			_player.take_damage(1, global_position)
	var at_edge := global_position.x <= arena_min_x + 0.45 or global_position.x >= arena_max_x - 0.45
	if _timer <= 0.0 or at_edge or _wall_ahead():
		velocity.x = 0.0
		state = St.RUSH_RECOVER
		_timer = 0.85
		_say("…")


func _do_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	_timer -= delta
	if _timer <= 0.0:
		state = St.IDLE
		_idle_pace = 0.35


func _do_reload(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	_timer -= delta
	if _timer <= 0.0:
		state = St.IDLE
		_idle_pace = 0.3


# ---- phase-2 slam: he lands where you stand; the waves hug the floor ------
func _leap_at_player() -> void:
	var target_x := global_position.x
	if is_instance_valid(_player):
		target_x = _player.global_position.x
	var dx := target_x - global_position.x
	velocity.y = 13.0
	velocity.x = clampf(dx / 0.85, -9.0, 9.0)  # airtime estimate, lands on their head
	_dir = -signf(dx) if absf(dx) > 0.1 else _dir
	state = St.SLAM_AIR
	_say("!")


func _do_slam_air(_delta: float) -> void:
	if is_on_floor():
		state = St.SLAM_LAND
		_timer = 0.5
		_spawn_shockwaves()
		# landing squash
		if _mesh != null:
			_mesh.scale = Vector3(1.35, 0.6, 1.35)


func _spawn_shockwaves() -> void:
	for side in [-1.0, 1.0]:
		var w := TitoProjectile.new()
		w.floor_crawl = true
		w.speed = 6.5
		w.damage = 1
		w.life = 3.5
		w.break_on_world = false
		get_parent().add_child(w)
		var chunk := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.5, 0.42, 0.5)
		chunk.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.38, 0.5)
		chunk.material_override = mat
		w.add_child(chunk)
		w.launch(global_position + Vector3.UP * 0.2, Vector3(side, 0, 0))


func _do_slam_land(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	_timer -= delta
	if _timer <= 0.0:
		state = St.IDLE
		_idle_pace = 0.3


# ---- laser sweep grid: red floor panels, then the floor itself detonates --
func _build_sweep_telegraph() -> void:
	_clear_sweep_panels()
	var z0 := arena_min_x
	var w := (arena_max_x - arena_min_x) / 6.0
	for i in 6:
		var p := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(w - 0.25, 3.6)
		p.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(1.0, 0.1, 0.15, 0.22)
		p.material_override = m
		p.position = Vector3(z0 + (i + 0.5) * w, 1.9, -0.4)
		get_parent().add_child(p)  # arena-space, not boss-local
		_sweep_panels.append(p)


func _do_sweep_tel(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	# panels ratchet brighter as the grid arms
	var m: StandardMaterial3D
	for p in _sweep_panels:
		m = p.material_override as StandardMaterial3D
		m.albedo_color.a = 0.22 + 0.25 * (1.4 - _timer)
	_timer -= delta
	if _timer <= 0.0:
		state = St.SWEEP_FIRE
		_timer = 0.42
		for p in _sweep_panels:
			m = p.material_override as StandardMaterial3D
			m.albedo_color = Color(1.0, 0.25, 0.2, 0.65)
		if is_instance_valid(_player) and _player.is_on_floor() \
		and _player.global_position.y < sweep_safe_y:
			_player.take_damage(1, global_position)


func _do_sweep_fire(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_clear_sweep_panels()
		state = St.IDLE
		_idle_pace = 0.35


func _clear_sweep_panels() -> void:
	for p in _sweep_panels:
		p.queue_free()
	_sweep_panels.clear()


# ---- reversal: punching the glow eats a grab-throw ------------------------
func _do_reversal(delta: float) -> void:
	_face_player()
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	_timer -= delta
	if _timer <= 0.0:
		if _mat != null:
			_mat.albedo_color = coat_tint
		state = St.IDLE
		_idle_pace = 0.35


func _do_grab_dash(delta: float) -> void:
	_timer -= delta
	if is_instance_valid(_player):
		var dx := _player.global_position.x - global_position.x
		velocity.x = signf(dx) * 18.0
		if absf(dx) < 0.95 and absf(_player.global_position.y - global_position.y) < 1.7:
			_player.take_damage(1, global_position)
			_player.velocity = Vector3(signf(dx) * 8.5, 3.2, 0.0)
			state = St.GRAB_RECOVER
			_timer = 0.8
			velocity.x = 0.0
			return
	if _timer <= 0.0:
		state = St.GRAB_RECOVER
		_timer = 0.6


func take_damage(amount: int, from_pos = null) -> void:
	if state == St.DEAD or state == St.CINEMA:
		return
	if state == St.REVERSAL:
		# the trap springs: counter grab, zero damage taken
		if _mat != null:
			_mat.albedo_color = coat_tint
		state = St.GRAB_DASH
		_timer = 0.35
		return
	hp -= amount
	_flash_t = 0.12
	if _hp_fg != null:
		var f := clampf(float(hp) / max_hp, 0.0, 1.0)
		_hp_fg.scale.x = f
		_hp_fg.position.x = -(1.0 - f) * 0.91
	if hp <= 0:
		_die()
		return
	if not _phase_two and hp <= int(max_hp * 0.4):
		_enter_phase_two()


func _enter_phase_two() -> void:
	_phase_two = true
	_say("!!", COLOR_TELL)
	if _mat != null:
		_mat.albedo_color = coat_tint.lerp(Color(0.45, 0.1, 0.12), 0.5)
	# desperation opens with a slam
	state = St.IDLE
	_pattern_idx = 0
	_idle_pace = 0.4


func _die() -> void:
	state = St.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_clear_sweep_panels()
	if _indicator != null:
		_indicator.visible = false
	set_physics_process(false)
	boss_died.emit(self)


# ---------------------------------------------------------------- visuals --
func _face_player() -> void:
	if not is_instance_valid(_player):
		return
	var dx := _player.global_position.x - global_position.x
	if absf(dx) > 0.1:
		_dir = signf(dx)


func _apply_visual(delta: float) -> void:
	if _visual != null:
		var yaw := 0.0 if _dir > 0.0 else PI
		_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, clampf(12.0 * delta, 0.0, 1.0))
	if _mesh != null:
		var want := Vector3.ONE
		match state:
			St.RUSH_AIM:
				want = Vector3(1.15, 0.8, 1.15)
			St.RUSHING:
				want = Vector3(1.28, 0.75, 1.05)
			St.SLAM_AIR:
				want = Vector3(0.85, 1.25, 0.85)
			St.RELOAD:
				want = Vector3(1.05, 0.9, 1.05)
		_mesh.scale = _mesh.scale.lerp(want, clampf(10.0 * delta, 0.0, 1.0))
		if _flash_t > 0.0:
			_mat.albedo_color = Color(1, 1, 1)
		elif state == St.REVERSAL:
			_mat.albedo_color = coat_tint.lerp(Color(0.5, 0.2, 0.6), 0.8)
		elif _phase_two:
			_mat.albedo_color = coat_tint.lerp(Color(0.45, 0.1, 0.12), 0.5)
		else:
			_mat.albedo_color = coat_tint
		# small bob for menace
		_mesh.position.y = sin(Time.get_ticks_msec() / 1000.0 * 2.2) * 0.03


func _say(text: String, color := Color(1.0, 0.85, 0.2)) -> void:
	if _indicator == null:
		return
	_indicator.text = text
	_indicator.modulate = color
	_indicator.visible = true
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if _indicator != null:
			_indicator.visible = false
	)


func _ledge_ahead() -> bool:
	var from := global_position + Vector3(_dir * 0.7, -0.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _wall_ahead() -> bool:
	var from := global_position + Vector3.UP * 0.7
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(_dir, 0, 0) * 0.8)
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _find_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes.size() > 0 else null

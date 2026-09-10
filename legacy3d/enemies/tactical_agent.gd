## Tactical Agent: keeps distance, paints a red targeting line, then fires at
## standing-chest height. The read: beam = get LOW (crouch) or break the line.
## Reuses the TitoEnemy WINDUP/STRIKE/RECOVER attack scaffold — only the
## trigger window and the strike payload differ (hitscan-ish projectile).
class_name TitoTacticalAgent
extends TitoEnemy

@export var engage_range := 10.0
@export var aim_time := 0.85
@export var shot_speed := 18.0

var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _lock_point := Vector3.ZERO


func _ready() -> void:
	walk_speed = 1.6
	run_speed = 3.4
	attack_cooldown = 1.6
	recover_time = 0.4
	super()
	_build_beam()


func _build_beam() -> void:
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.albedo_color = Color(1.0, 0.18, 0.22, 0.75)
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.035, 0.035)
	_beam.mesh = box
	_beam.material_override = _beam_mat
	_beam.visible = false
	add_child(_beam)


## Engage from range with line of sight (fires across the street).
func _in_attack_window() -> bool:
	return is_instance_valid(_player) and _seen \
		and absf(_player.global_position.x - global_position.x) < engage_range \
		and absf(_player.global_position.y - global_position.y) < 1.3


func _do_attack(delta: float) -> void:
	if not is_instance_valid(_player):
		_abort_attack()
		_beam.visible = false
		_enter_search()
		return
	match _phase:
		AttackPhase.NONE:
			_begin_windup()
		AttackPhase.WINDUP:
			var dx := _player.global_position.x - global_position.x
			if absf(dx) > 0.05:
				_dir = signf(dx)
			velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
			_lock_point = _player.global_position + Vector3.UP * 1.15
			_update_beam(_lock_point)
			_windup_timer -= delta
			if _windup_timer <= 0.0:
				_fire()
		AttackPhase.STRIKE:
			# muzzle flash window; the projectile is already gone
			_swing_timer -= delta
			if _swing_timer <= 0.0:
				_beam.visible = false
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
	_windup_timer = (aim_time / _aggr) * randf_range(0.9, 1.2)
	velocity.x = 0.0
	_beam.visible = true
	_set_indicator("!", COLOR_ANGRY, maxf(_windup_timer, 0.25))


func _update_beam(target: Vector3) -> void:
	var from := global_position + Vector3.UP * 1.2
	var to := target
	var mid := (from + to) * 0.5
	var d := to - from
	_beam.global_position = mid
	_beam.rotation = Vector3.ZERO
	_beam.rotation.z = atan2(d.y, d.x)
	_beam.scale = Vector3(maxf(d.length(), 0.1), 1.0, 1.0)


func _fire() -> void:
	_phase = AttackPhase.STRIKE
	_swing_timer = 0.12
	var from := global_position + Vector3.UP * 1.2
	var dir := _lock_point - from
	var shot := TitoProjectile.new()
	shot.speed = shot_speed
	shot.damage = 1
	shot.life = 2.5
	get_parent().add_child(shot)
	# tracer: hot little bolt
	var bolt := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.06, 0.06)
	bolt.mesh = bm
	var bolt_mat := StandardMaterial3D.new()
	bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_mat.albedo_color = Color(1.0, 0.55, 0.25)
	bolt.material_override = bolt_mat
	shot.add_child(bolt)
	shot.launch(from, dir.normalized())
	_update_beam(_lock_point)  # beam freezes on the locked line for one flash


## Ranged discipline: if the player crowds him, he back-pedals while hunting
## his firing window (parent chase runs first, then we bias away).
func _do_chase(delta: float) -> void:
	super._do_chase(delta)
	if state != State.CHASE or not _seen or not is_instance_valid(_player):
		return
	var pdx := _player.global_position.x - global_position.x
	if absf(pdx) < 2.6 and _floor_at(global_position.x - signf(pdx) * 1.0):
		velocity.x = move_toward(velocity.x, -signf(pdx) * 2.4, 25.0 * delta)

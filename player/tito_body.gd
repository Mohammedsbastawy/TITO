## Tito — 3D side-scroller player: run / jump / crawl / rope-climb / melee.
##
## States: NORMAL, CROUCH (crawl under obstacles), CLIMB (on a rope).
## Combat: HurtBox takes hits, HitBox swings in front (child of Model so it flips).
## Z is hard-locked every physics tick.
class_name TitoBody
extends CharacterBody3D

enum State { NORMAL, CROUCH, CLIMB }

# ------------------------------------------------------------- movement ---
@export_group("Movement")
@export var max_speed := 6.0
@export var crawl_speed := 2.5
@export var acceleration := 45.0
@export var deceleration := 60.0
@export var turn_acceleration := 90.0
@export var air_acceleration := 28.0
@export var air_deceleration := 8.0
@export var air_turn_acceleration := 45.0

# ---------------------------------------------------- jump and gravity ---
@export_group("Jump & Gravity")
@export var jump_velocity := 13.5
@export var jump_gravity := 42.0
@export var fall_gravity := 60.0
@export var max_fall_speed := 25.0
@export var jump_cut_multiplier := 0.45
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12

# ------------------------------------------------------------- climbing ---
@export_group("Climbing")
@export var climb_speed := 3.0
@export var rope_detach_jump := 12.0
@export var rope_detach_horizontal := 5.0

# --------------------------------------------------------------- combat ---
@export_group("Combat")
@export var attack_cooldown := 0.5
@export var attack_active_time := 0.15
@export var attack_animation_lock := 0.32 ## after this, locomotion may cancel the punch
@export var animation_blend_time := 0.12 ## smooth crossfade between clips
@export var attack_damage := 1
@export var invulnerability_time := 1.0

# --------------------------------------------------------- 2.5D lock ------
@export_group("2.5D Lock")
@export var fall_reset_y := -25.0

# ------------------------------------------------------ model alignment ---
@export_group("Model Alignment")
@export var model_yaw_offset_deg := 90.0
@export var sprite_faces_right := true

# ------------------------------------------------- procedural animation ---
@export_group("Procedural Animation")
@export var run_bob_amplitude := 0.07
@export var run_bob_frequency := 10.0
@export var run_lean_deg := 6.0
@export var idle_breathe_amplitude := 0.015
@export var idle_breathe_frequency := 2.0
@export var air_tilt_deg := 14.0

var state := State.NORMAL
var facing := 1
var mission_complete := false

var _coyote := 0.0
var _jump_buffer := 0.0
var _spawn := Transform3D()
var _z_lock := 0.0
var _anim_time := 0.0
var _base_model_y := 0.0
var _anim_player: AnimationPlayer = null
var _current_anim := ""
var _rope: Node3D = null
var _attack_timer := 0.0
var _swing_timer := 0.0
var _attack_anim_lock_timer := 0.0
var _swing_hits := {}
var _invuln := 0.0
var _flash_timer := 0.0
var _stand_shape_h := 1.8
var _stand_shape_y := 0.0

@onready var _model: Node3D = get_node_or_null("Model")
@onready var _shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var _hitbox: Area3D = get_node_or_null("Model/HitBox")
@onready var _health: TitoHealth = get_node_or_null("Health")
@onready var _hurtbox: Area3D = get_node_or_null("HurtBox")


func _ready() -> void:
	add_to_group("player")
	_spawn = transform
	_z_lock = global_position.z
	if _model != null:
		_base_model_y = _model.position.y
		var inner := _model.get_node_or_null("TitoModel") as Node3D
		if inner != null:
			inner.rotation.y = deg_to_rad(model_yaw_offset_deg)
		# Real animations: the FBX instance carries an AnimationPlayer whose
		# library we replace with the merged Mixamo clip library.
		_anim_player = inner.get_node_or_null("AnimationPlayer") if inner != null else null
		if _anim_player != null:
			# The FBX ships its own default library (name "") with "mixamo_com";
			# add the merged clip library under a separate namespace instead.
			if not _anim_player.has_animation_library("tito"):
				var lib: AnimationLibrary = load("res://assets/models/TITO/anim_library.res")
				if lib != null:
					_anim_player.add_animation_library("tito", lib)
			# One-shot clips must release control the frame they end, or the
			# state machine can hold a stale _current_anim for a whole second.
			_anim_player.animation_finished.connect(_on_anim_finished)
			_play_anim("idle")
	if _shape_node != null and _shape_node.shape is CapsuleShape3D:
		_stand_shape_h = (_shape_node.shape as CapsuleShape3D).height
		_stand_shape_y = _shape_node.position.y
	if _health != null:
		_health.died.connect(_on_died)
	if _hitbox != null:
		_hitbox.monitoring = false


func _physics_process(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_anim_lock_timer = maxf(_attack_anim_lock_timer - delta, 0.0)
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	# i-frame blink: the model flickers while invulnerable (no material hacks —
	# Node3D has no modulate; toggling visibility is the classic 2.5D approach).
	if _model != null:
		_model.visible = _flash_timer <= 0.0 or fmod(_flash_timer, 0.24) >= 0.12

	match state:
		State.CLIMB:
			_climb(delta)
		_:
			_ground_move(delta)

	move_and_slide()

	velocity.z = 0.0
	global_position.z = _z_lock

	_apply_facing()
	_animate(delta)
	_update_swing(delta)

	if global_position.y < fall_reset_y or Input.is_action_just_pressed(&"reset_position"):
		_respawn()
	if Input.is_action_just_pressed(&"attack") and state != State.CLIMB and _attack_timer <= 0.0:
		_start_swing()


# -------------------------------------------------------- ground / air ----
func _ground_move(delta: float) -> void:
	_update_crawl(delta)
	var top_speed := crawl_speed if state == State.CROUCH else max_speed

	var axis := Input.get_axis(&"move_left", &"move_right")
	var target := axis * top_speed
	velocity.x = move_toward(velocity.x, target, _pick_accel(axis) * delta)
	if absf(axis) > 0.01:
		facing = 1 if axis > 0.0 else -1

	_apply_gravity_and_jump(delta)

	# Rope grab: overlapping a rope and pressing up/down starts climbing.
	if _rope != null and (Input.is_action_pressed(&"climb_up") or Input.is_action_pressed(&"climb_down")):
		_enter_climb()


func _apply_gravity_and_jump(delta: float) -> void:
	if is_on_floor():
		_coyote = coyote_time
	else:
		_coyote -= delta

	if Input.is_action_just_pressed(&"jump") and state != State.CROUCH:
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer -= delta

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0

	if Input.is_action_just_released(&"jump") and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier

	var g := jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y = maxf(velocity.y - g * delta, -max_fall_speed)


func _pick_accel(axis: float) -> float:
	var grounded := is_on_floor()
	if absf(axis) < 0.01:
		return deceleration if grounded else air_deceleration
	var turning := signf(axis) != signf(velocity.x) and absf(velocity.x) > 0.1
	if turning:
		return turn_acceleration if grounded else air_turn_acceleration
	return acceleration if grounded else air_acceleration


# ---------------------------------------------------------------- crawl ---
func _update_crawl(_delta: float) -> void:
	if _shape_node == null:
		return
	var want_crawl := Input.is_action_pressed(&"crawl") and is_on_floor() and state == State.NORMAL
	if want_crawl and state != State.CROUCH:
		_set_crouch(true)
	elif state == State.CROUCH and (not Input.is_action_pressed(&"crawl") or not is_on_floor()):
		if _can_stand():
			_set_crouch(false)
		# else: stay crouched under the low ceiling


func _set_crouch(crouched: bool) -> void:
	var capsule := _shape_node.shape as CapsuleShape3D
	if crouched:
		capsule.height = 0.9
		# Keep the capsule BOTTOM at the feet (body origin is the capsule center
		# when standing): center must drop to -0.45 so bottom stays at -0.9.
		_shape_node.position.y = -0.45
		state = State.CROUCH
	else:
		capsule.height = _stand_shape_h
		_shape_node.position.y = _stand_shape_y
		state = State.NORMAL


func _can_stand() -> bool:
	var from := global_position + Vector3.UP * 0.1
	var to := from + Vector3.UP * (_stand_shape_h + 0.05)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ---------------------------------------------------------------- climb ---
func _enter_climb() -> void:
	state = State.CLIMB
	velocity = Vector3.ZERO
	if _shape_node != null and state != State.CROUCH:
		pass # keep full capsule while climbing


func _climb(delta: float) -> void:
	if _rope == null or not is_instance_valid(_rope):
		state = State.NORMAL
		return
	var up := Input.is_action_pressed(&"climb_up")
	var down := Input.is_action_pressed(&"climb_down")
	velocity.y = (climb_speed if up else -climb_speed if down else 0.0)
	velocity.x = 0.0
	# Snap to the rope's X so Tito hangs on the line.
	global_position.x = lerpf(global_position.x, _rope.global_position.x, clampf(12.0 * delta, 0.0, 1.0))
	# Don't climb above the anchor. Clamp leaves the capsule BOTTOM (origin-0.9)
	# level with top_y-1.05, so a top-of-rope origin can step/leap onto a
	# platform whose surface is at top_y-0.9 (greybox tower math).
	var top_y: float = _rope.top_y
	var at_top := false
	if global_position.y > top_y - 0.15:
		global_position.y = top_y - 0.15
		at_top = true
		if up:
			velocity.y = 0.0
	# Standing on ground while pressing down -> let go.
	if down and is_on_floor():
		state = State.NORMAL
		return
	# Leap off: a fresh jump tap, OR holding jump at the very top of the rope.
	if Input.is_action_just_pressed(&"jump") or (Input.is_action_pressed(&"jump") and at_top):
		# Leap: up + sideways impulse.
		var axis := Input.get_axis(&"move_left", &"move_right")
		velocity = Vector3(axis * rope_detach_horizontal, rope_detach_jump, 0.0)
		if absf(axis) > 0.01:
			facing = 1 if axis > 0.0 else -1
		# Drop the rope reference so holding climb_up can't re-grab instantly;
		# body_exited will keep it null and a later re-entry re-grabs cleanly.
		_rope = null
		state = State.NORMAL


func set_rope(rope: Node3D) -> void:
	_rope = rope
	if rope == null and state == State.CLIMB:
		state = State.NORMAL


# --------------------------------------------------------------- combat ---
func _start_swing() -> void:
	_attack_timer = attack_cooldown
	_swing_timer = attack_active_time
	_attack_anim_lock_timer = attack_animation_lock
	_swing_hits.clear()
	if _hitbox != null:
		_hitbox.monitoring = true
	# Small forward lunge for punch feel.
	velocity.x += facing * 2.0
	_trigger_punch_anim()


func _update_swing(delta: float) -> void:
	if _swing_timer <= 0.0:
		return
	_swing_timer -= delta
	if _hitbox != null:
		# HitBox lives under Model (so it flips with facing) — path must match.
		TitoCombat.try_hit(self, "Model/HitBox", ["enemies"], _swing_hits)
	if _swing_timer <= 0.0 and _hitbox != null:
		_hitbox.monitoring = false


func take_damage(amount: int, from_pos = null) -> void:
	if _invuln > 0.0:
		return
	_invuln = invulnerability_time
	_flash_timer = invulnerability_time * 0.75
	# hit knockback: shove away from the source (unless hanging on a rope)
	if from_pos is Vector3 and state != State.CLIMB:
		var kb := signf(global_position.x - (from_pos as Vector3).x)
		if kb == 0.0:
			kb = -float(facing)
		velocity.x = kb * 4.2
		velocity.y = maxf(velocity.y, 2.4)
	if _health != null:
		_health.take_damage(amount)


func fell_out() -> void:
	take_damage(1)
	_respawn()


func mission_complete_signal() -> void:
	mission_complete = true


func _on_died() -> void:
	if _health != null:
		_health.hp = _health.max_hp
	_respawn()


# ----------------------------------------------------------- checkpoints --
func set_checkpoint(pos: Vector3) -> void:
	_spawn = Transform3D(Basis(), pos)


func _respawn() -> void:
	transform = _spawn
	velocity = Vector3.ZERO
	_coyote = 0.0
	_jump_buffer = 0.0
	_invuln = invulnerability_time
	if state == State.CROUCH:
		_set_crouch(false)
	state = State.NORMAL
	if _model != null:
		_model.position.y = _base_model_y
		_model.rotation.z = 0.0


# ------------------------------------------------------------- facing -----
func _apply_facing() -> void:
	if _model == null:
		return
	var target_yaw := 0.0 if (facing > 0) == sprite_faces_right else PI
	_model.rotation.y = target_yaw


# ----------------------------------------------- real animation layer -----
const ANIM_PREFIX := "tito/"   ## merged Mixamo library namespace on the FBX player

## Plays a named clip from the merged Mixamo library. Non-looping clips
## (jump/fall/punches) fall back to idle when they finish. The procedural
## bob/lean below stays as a subtle secondary layer on top.
func _play_anim(clip: String, force := false) -> void:
	if _anim_player == null:
		return
	var target := ANIM_PREFIX + clip
	if not _anim_player.has_animation(target):
		return
	# Skip only while the SAME clip is actively playing. finished one-shots
	# fall through so they can replay or be replaced. blend_time gives a smooth
	# crossfade between locomotion clips instead of a hard cut.
	if not force and _current_anim == clip and _anim_player.is_playing():
		return
	_current_anim = clip
	_anim_player.play(target, animation_blend_time)


func _on_anim_finished(clip_name: StringName) -> void:
	## One-shot clips (punch/jump/fall) end here: release the state machine so
	## run/idle resume immediately — no frozen last frame.
	if String(clip_name).begins_with(ANIM_PREFIX):
		_current_anim = ""


func _update_anim_state() -> void:
	if _anim_player == null:
		return
	if state == State.CLIMB:
		_play_anim("idle")
		return
	if state == State.CROUCH:
		_play_anim("idle")
		return
	# Punches own the body ONLY for their active lock window. After that, a
	# moving player (run) or standing player (idle) immediately cancels the
	# remaining tail of the punch — so you never freeze mid-stride. The hitbox
	# already closed, so cancelling visuals is safe.
	var punching := _current_anim in ["punch_left", "punch_right", "punch_combo"]
	if punching:
		if _attack_anim_lock_timer > 0.0 or _anim_player.is_playing():
			return
	if not is_on_floor():
		_play_anim("jump" if velocity.y > 0.5 else "fall")
		return
	if absf(velocity.x) > 0.5:
		_play_anim("run")
	else:
		_play_anim("idle")


func _trigger_punch_anim() -> void:
	## Alternate left/right punches; combo clip reserved for later chains.
	var next := "punch_right" if _last_punch == "punch_left" else "punch_left"
	_last_punch = next
	_play_anim(next, true)


var _last_punch := ""


# ----------------------------------------------- procedural animation ----
func _animate(delta: float) -> void:
	_update_anim_state()
	if _model == null:
		return
	_anim_time += delta
	var target_roll := 0.0
	var target_scale_y := 1.0
	var bob := 0.0
	match state:
		State.CLIMB:
			bob = sin(_anim_time * 6.0) * 0.04
		State.CROUCH:
			target_scale_y = 0.55
		_:
			if not is_on_floor():
				var rising := 1.0 if velocity.y > 0.0 else -1.0
				target_roll = deg_to_rad(air_tilt_deg) * rising * float(facing)
			elif absf(velocity.x) > 0.5:
				var speed_ratio := absf(velocity.x) / maxf(max_speed, 0.01)
				bob = sin(_anim_time * run_bob_frequency) * run_bob_amplitude * speed_ratio
				target_roll = -deg_to_rad(run_lean_deg) * float(facing)
			else:
				bob = sin(_anim_time * idle_breathe_frequency) * idle_breathe_amplitude
	_model.position.y = _base_model_y + bob
	_model.rotation.z = lerp_angle(_model.rotation.z, target_roll, clampf(10.0 * delta, 0.0, 1.0))
	_model.scale.y = lerpf(_model.scale.y, target_scale_y, clampf(12.0 * delta, 0.0, 1.0))

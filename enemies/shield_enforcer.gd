## Heavy Enforcer: carries a ballistic riot shield. Frontal punches CLANG off
## with a spark — you must hop over him and hit his back, or punish his own
## swings/exposed moments. Slower, heavier, meaner than a light guard.
class_name TitoShieldEnforcer
extends TitoEnemy


func _ready() -> void:
	walk_speed = 1.3
	run_speed = 3.3
	windup_time = 0.5
	recover_time = 0.6
	attack_cooldown = 1.5
	lunge_speed = 5.5
	super()
	_build_shield()


func _build_shield() -> void:
	if _visual == null:
		return
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 1.55, 1.05)
	plate.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.16, 0.22)
	mat.metallic = 0.85
	mat.roughness = 0.32
	plate.material_override = mat
	plate.position = Vector3(0.5, 0.05, 0.0)
	plate.name = "ShieldPlate"
	_visual.add_child(plate)
	# glowing visor slit so the shield reads as a face
	var slit := MeshInstance3D.new()
	var slit_box := BoxMesh.new()
	slit_box.size = Vector3(0.05, 0.06, 0.6)
	slit.mesh = slit_box
	var slit_mat := StandardMaterial3D.new()
	slit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slit_mat.albedo_color = Color(1.0, 0.35, 0.2)
	slit.material_override = slit_mat
	slit.position = Vector3(0.58, 0.55, 0.0)
	_visual.add_child(slit)


## Frontal immunity: blows landing from the direction he FACES are blocked,
## unless he is mid-swing (shield down) or already staggered.
func take_damage(amount: int, from_pos = null) -> void:
	if state == State.DEAD:
		return
	var exposed := state == State.STAGGER \
		or (state == State.ATTACK and _phase in [AttackPhase.WINDUP, AttackPhase.STRIKE])
	if not exposed and from_pos is Vector3:
		var dx: float = (from_pos as Vector3).x - global_position.x
		if absf(dx) > 0.05 and signf(dx) == signf(_dir):
			_block_hit()
			return
	super(amount, from_pos)


func _block_hit() -> void:
	# bright clang flash, tiny shove back — and he stays mad
	_flash_t = 0.09
	_squash_t = 0.07
	var ih := get_node_or_null("/root/InputHelper")
	if ih != null and ih.has_method("rumble_small"):
		ih.rumble_small()  # you feel the shield CLANG
	velocity.x = -_dir * 1.8
	if is_instance_valid(_player):
		_last_seen = _player.global_position

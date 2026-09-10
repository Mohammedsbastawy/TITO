## Area-Denial Unit: lobs smoke canisters in a high arc toward the player's
## position; each burst leaves a lingering hazard cloud. Forces the fight up
## onto awnings and fire-escapes instead of the open street.
class_name TitoSmokeLauncher
extends TitoEnemy

@export var lob_min := 3.0
@export var lob_max := 12.0
@export var lob_gravity := 20.0


func _ready() -> void:
	attack_cooldown = 2.6
	windup_time = 0.45
	super()


## Fire when the player is in the lob band (and can be seen).
func _in_attack_window() -> bool:
	if not is_instance_valid(_player) or not _seen:
		return false
	var dx := absf(_player.global_position.x - global_position.x)
	return dx >= lob_min and dx <= lob_max \
		and absf(_player.global_position.y - global_position.y) < 5.0


func _begin_strike() -> void:
	_phase = AttackPhase.STRIKE
	_swing_timer = attack_active_time
	if not is_instance_valid(_player):
		return
	var from := global_position + Vector3.UP * 1.4
	var to := _player.global_position + Vector3.UP * 0.3
	var t := clampf(absf(to.x - from.x) / 7.0, 0.7, 1.7)
	# solve the lob: gravity pulls vy down; pick vx/vy to land on target in t
	var vx := (to.x - from.x) / t
	var vy := (to.y - from.y) / t + 0.5 * lob_gravity * t
	var can := TitoProjectile.new()
	can.gravity = lob_gravity
	can.floor_crawl = false
	can.damage = 0            # the canister itself is harmless; the cloud is not
	can.makes_smoke = true
	can.smoke_duration = 7.0
	can.life = 4.0
	get_parent().add_child(can)
	# small metal can with a faint emissive band
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.09
	cm.height = 0.3
	body.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.38)
	mat.metallic = 0.7
	mat.roughness = 0.4
	body.material_override = mat
	can.add_child(body)
	can.global_position = from
	can.velocity = Vector3(vx, vy, 0.0)
	if _hitbox != null:
		_hitbox.monitoring = false  # no melee swing — this unit is pure support

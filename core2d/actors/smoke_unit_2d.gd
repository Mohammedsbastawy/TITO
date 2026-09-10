## Area-Denial unit: lobs smoke canisters in a high arc to salt the
## player's ground route (Zone 4) — the canopies overhead stay clean.
class_name SmokeUnit2D
extends Enemy2D

@export var lob_min := 90.0
@export var lob_max := 380.0
@export var lob_gravity := 900.0


func _ready() -> void:
	attack_cooldown = 2.4
	windup_time = 0.5
	recover_time = 0.55
	max_hp = 3
	tint = Color(0.5, 0.55, 0.35)
	super()


func _in_attack_window() -> bool:
	if not is_instance_valid(_player) or not _seen:
		return false
	var dx := absf(_player.global_position.x - global_position.x)
	var dy := absf(_player.global_position.y - global_position.y)
	return dx >= lob_min and dx <= lob_max and dy < 180.0


func _begin_strike() -> void:
	# no melee arm: the canister IS the attack
	if not is_instance_valid(_player):
		return
	var from := global_position + Vector2(0, -56)
	var to := _player.global_position + Vector2(0, -8)
	var t := clampf(absf(to.x - from.x) / 220.0, 0.6, 1.6)
	var vx := (to.x - from.x) / t
	var vy := (to.y - from.y) / t - 0.5 * lob_gravity * t
	var can := Projectile2D.new()
	can.gravity = lob_gravity
	can.damage = 0             # the tin is harmless; the cloud is not
	can.makes_hazard = true
	can.hazard_duration = 7.0
	can.life = 4.0
	can.tint = Color(0.6, 0.65, 0.75)
	get_parent().add_child(can)
	can.launch(from, Vector2(vx, vy).normalized(), Vector2(vx, vy).length())

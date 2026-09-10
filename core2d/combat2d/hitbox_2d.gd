## Strike volume. Enabled ONLY during active attack frames (windup/strike
## windows are owned by the wielder's state machine). Team-filtered so
## player blades ignore other players and enemy weapons ignore their crew.
class_name HitBox2D
extends Area2D

@export var victim_group := "enemies"  # player blades hunt enemies; crews hunt "player"

var damage := 1
var knockback := Vector2(160.0, -60.0)
var _hit := {}


func _ready() -> void:
	collision_layer = 16        # hitbox layer
	collision_mask = 4          # touches hurtboxes only
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


## Enable for `active_time`; each arm() can tag every target once.
func arm(dmg: int, kb: Vector2, active_time: float) -> void:
	damage = dmg
	knockback = kb
	_hit.clear()
	monitoring = true
	get_tree().create_timer(maxf(active_time, 0.03), true, false, true) \
		.timeout.connect(disarm)


func disarm() -> void:
	monitoring = false


func _on_area_entered(area: Area2D) -> void:
	if _hit.has(area):
		return
	var target: Node = area.get_parent()
	if target == null or not target.has_method("take_damage"):
		return
	if not target.is_in_group(victim_group):
		return
	_hit[area] = true
	var src := Vector2(global_position.x + signf(knockback.x) * 8.0, global_position.y)
	target.take_damage(damage, src)
	_hitstop()


## Comic-book connect: a heartbeat of frozen time, real-time scaled.
func _hitstop() -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(0.07, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0)

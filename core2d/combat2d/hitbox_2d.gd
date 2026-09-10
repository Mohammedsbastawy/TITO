## Player-side strike volume. Enabled ONLY during active attack frames
## (windup/strike windows are owned by the player's state machine).
## Dimension-agnostic 2D counterpart of legacy3d tito_combat logic.
class_name HitBox2D
extends Area2D

var damage := 1
var knockback := Vector2(160.0, -60.0)
var _hit := {}


func _ready() -> void:
	collision_layer = 16        # player hitbox layer
	collision_mask = 4          # touches hurtboxes only
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


## Enable for `active_time`; each arm() can hit every target once.
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
	_hit[area] = true
	var src := Vector2(global_position.x + signf(knockback.x) * 8.0, global_position.y)
	target.take_damage(damage, src)

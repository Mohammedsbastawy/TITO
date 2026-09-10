## Lingering ground hazard (smoke pockets, coil fields...): damages the
## player on a tick while they stand inside. Arm with a duration, or pass
## a negative duration to make it permanent until queue_free().
class_name HazardZone2D
extends Area2D

@export var tick_time := 0.9
@export var damage := 1
@export var duration := -1.0
@export var tint := Color(0.55, 0.6, 0.75, 0.4)

var _t := 0.0
var _life: SceneTreeTimer
var _blob: Polygon2D


func _ready() -> void:
	collision_layer = 32       # hazards
	collision_mask = 2         # player body
	_blob = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 14:
		var a := i / 14.0 * TAU
		pts.append(Vector2(cos(a), sin(a) * 0.42) * 52.0 + Vector2(0, -12))
	_blob.polygon = pts
	_blob.color = tint
	add_child(_blob)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(96, 44)
	cs.shape = rect
	cs.position = Vector2(0, -14)
	add_child(cs)
	if duration > 0.0:
		_life = get_tree().create_timer(duration)
		_life.timeout.connect(_expire)


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = tick_time
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)


func _expire() -> void:
	var tw := create_tween()
	tw.tween_property(_blob, "color:a", 0.0, 0.8)
	tw.tween_callback(queue_free)

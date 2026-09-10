## Game camera: input-lookahead so the frame leads the action
## (Mark-of-the-Ninja readability), trauma-based shake, zone limits,
## and a cinematic focus() API for boss intro/outro moves.
class_name TitoCamera2D
extends Camera2D

@export var lookahead := 90.0
@export var follow_speed := 6.0
@export var shake_decay := 2.6

var target: Node2D
var _trauma := 0.0
var _focus: Node = null


func _ready() -> void:
	position_smoothing_enabled = false  # manual: lookahead needs raw control
	make_current()


func set_target(t: Node2D) -> void:
	target = t
	if target != null:
		global_position = target.global_position


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	if _focus != null:
		return  # cinematic owns the frame
	if target != null:
		var ax := 0.0
		if target is Player2D:
			ax = clampf((target as Player2D).velocity.x / 300.0, -1.0, 1.0)
		var want: Vector2 = target.global_position + Vector2(ax * lookahead, -36.0)
		global_position = global_position.lerp(want, clampf(follow_speed * delta, 0.0, 1.0))
	_trauma = maxf(_trauma - shake_decay * delta * _trauma, 0.0)
	var mag := _trauma * _trauma * 9.0
	offset = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))


## Cinematic takeover: tween to a point/zoom, hold, then release().
func focus(point: Vector2, zoom_level := 1.1, travel := 0.8) -> void:
	_focus = self
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "global_position", point, travel)
	tw.tween_property(self, "zoom", Vector2.ONE * zoom_level, travel)


func release(travel := 0.6) -> void:
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC)
	if target != null:
		tw.tween_property(self, "global_position", target.global_position, travel)
	tw.tween_property(self, "zoom", Vector2.ONE, travel)
	tw.finished.connect(func() -> void: _focus = null)


func apply_zone_limits(l: Rect2, pad_top := 96.0) -> void:
	limit_left = int(l.position.x)
	limit_top = int(l.position.y - pad_top)
	limit_right = int(l.end.x)
	limit_bottom = int(l.end.y)

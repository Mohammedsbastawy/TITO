## Zone-2 tutor: patrol goon with a wooden staff. Two readable swings —
## a quick jab, and a slow OVERHEAD arc (40%): the long windup literally
## says "parry me". Parrying any swing works; the overhead is the lesson.
class_name StaffEnforcer
extends Enemy2D

var _overhead := false


func _ready() -> void:
	walk_speed = 55.0
	run_speed = 140.0
	attack_range = 58.0
	attack_cooldown = 1.0
	windup_time = 0.42
	recover_time = 0.5
	max_hp = 3
	tint = Color(0.72, 0.42, 0.3)
	super()
	_build_staff()


func _build_staff() -> void:
	# the wooden staff: a warm slat the silhouette carries everywhere
	var staff := Polygon2D.new()
	staff.polygon = PackedVector2Array([
		Vector2(8, -46), Vector2(12, -46), Vector2(30, -4), Vector2(26, -2)])
	staff.color = Color(0.55, 0.38, 0.2)
	staff.position = Vector2(4, 0)
	_visual.add_child(staff)


func _pick_windup() -> float:
	_overhead = randf() < 0.4
	return windup_time * (1.8 if _overhead else 1.0)


func _begin_windup() -> void:
	if _overhead:
		_say("⬇!", COLOR_ANGRY, maxf(_windup_t, 0.4))
	else:
		super()


func _begin_strike() -> void:
	if _overhead:
		# big vertical arc: hurts more, covers above-head space too
		_hit_shape.position = Vector2(20.0 * _dir, -38)
		(_hit_shape.shape as RectangleShape2D).size = Vector2(44, 52)
		_hitbox.arm(2, Vector2(300 * _dir, -140), attack_active + 0.06)
	else:
		(_hit_shape.shape as RectangleShape2D).size = Vector2(38, 30)
		super()

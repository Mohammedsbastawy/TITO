## Tear-smoke hazard: a lingering cloud of churning billboards that drains the
## player while they stand in it — area denial that pushes the fight upward.
class_name TitoSmokeZone
extends Area3D

@export var duration := 7.0
@export var tick := 0.9
@export var radius := 2.6

var _tick_timer := 0.0
var _puffs: Array[MeshInstance3D] = []
var _t := 0.0
var _expiring := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # player body
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	cs.shape = sphere
	cs.position.y = radius * 0.55
	add_child(cs)
	# churning billboard puffs (GL-compat safe: unshaded alpha billboards)
	var tex := load("res://assets/textures/prologue/smoke_puff.png") as Texture2D
	for i in 6:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = tex
		mat.albedo_color = Color(0.55, 0.62, 0.78, 0.0)
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(3.2, 3.2)
		q.mesh = quad
		q.material_override = mat
		var a := i * TAU / 6.0
		q.position = Vector3(cos(a) * 0.7, 0.8 + (i % 3) * 0.7, sin(a) * 0.7)
		add_child(q)
		_puffs.append(q)
	get_tree().create_timer(duration).timeout.connect(_expire)


func _process(delta: float) -> void:
	_t += delta
	# bloom in, churn, breathe
	var bloom: float = clampf(_t / 0.7, 0.0, 1.0)
	for i in _puffs.size():
		var q := _puffs[i]
		var m := q.material_override as StandardMaterial3D
		var target_a := 0.42 * bloom * (0.75 + 0.25 * sin(_t * 1.7 + i * 1.3))
		m.albedo_color.a = lerpf(m.albedo_color.a, target_a, clampf(3.0 * delta, 0.0, 1.0))
		q.position.y += sin(_t * 0.9 + i * 2.1) * 0.12 * delta
		q.rotation.z += (0.14 if i % 2 == 0 else -0.11) * delta
	# damage ticks
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick
		for b in get_overlapping_bodies():
			if b.is_in_group("player") and b.has_method("take_damage"):
				b.take_damage(1, global_position)


func _expire() -> void:
	if _expiring:
		return
	_expiring = true
	set_process(false)
	collision_mask = 0
	var tw := get_tree().create_tween()
	tw.set_parallel(true)
	for q in _puffs:
		var m := q.material_override as StandardMaterial3D
		tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
		tw.tween_property(q, "scale", q.scale * 1.5, 0.9)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)

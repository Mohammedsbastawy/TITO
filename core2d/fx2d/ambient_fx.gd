## Ambient life pack (dust motes, wind streaks, drifting paper scraps).
## Everything recycles inside a band that rides the camera. Cheap, no
## shaders, GL-Compatibility safe — pure Neo-Noir breathing room.
class_name AmbientFx2D
extends Node2D

var follow: Node2D
var _dust: CPUParticles2D
var _streaks: Array = []
var _papers: Array = []
var _t := 0.0


func _ready() -> void:
	_dust = CPUParticles2D.new()
	_dust.amount = 48
	_dust.lifetime = 5.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(720.0, 320.0)
	_dust.direction = Vector2(-0.2, -0.6)
	_dust.spread = 40.0
	_dust.initial_velocity_min = 6.0
	_dust.initial_velocity_max = 18.0
	_dust.gravity = Vector2.ZERO
	_dust.color = Color(0.85, 0.88, 1.0, 0.22)
	add_child(_dust)
	for i in 8:
		var ln := Line2D.new()
		ln.default_color = Color(0.8, 0.86, 1.0, 0.0)
		ln.width = 1.5
		add_child(ln)
		_streaks.append({"n": ln, "p": Vector2(randf() * 900, randf() * 500),
			"len": randf_range(60.0, 140.0), "spd": randf_range(240.0, 420.0)})
	for i in 5:
		var paper := Polygon2D.new()
		paper.polygon = PackedVector2Array([
			Vector2(-7, -4), Vector2(7, -6), Vector2(9, 4), Vector2(-6, 6)])
		paper.color = Color(0.75, 0.72, 0.6, 0.75)
		add_child(paper)
		_papers.append({"n": paper, "p": Vector2(randf() * 900, 300.0 + randf() * 260),
			"spd": randf_range(50.0, 120.0), "ph": randf() * TAU,
			"spin": randf_range(-1.4, 1.4)})


func _process(delta: float) -> void:
	_t += delta
	if follow == null:
		return
	var base := follow.global_position + Vector2(-620.0, -300.0)
	_dust.global_position = base + Vector2(640.0, 300.0)
	for s in _streaks:
		s.p.x += s.spd * delta
		if s.p.x > base.x + 1350.0:
			s.p = Vector2(base.x - 40.0, base.y + randf() * 640.0)
		var n: Line2D = s.n
		n.points = PackedVector2Array([
			s.p, s.p + Vector2(s.len, s.len * 0.06)])
		var fade := clampf(1.0 - absf(s.p.x - (base.x + 620.0)) / 700.0, 0.0, 1.0)
		n.default_color.a = 0.16 * fade
	for s in _papers:
		s.p.x += s.spd * delta
		s.p.y += sin(_t * 1.7 + s.ph) * 26.0 * delta
		if s.p.x > base.x + 1350.0:
			s.p = Vector2(base.x - 30.0, base.y + 240.0 + randf() * 340.0)
		var n: Polygon2D = s.n
		n.position = s.p
		n.rotation += s.spin * delta

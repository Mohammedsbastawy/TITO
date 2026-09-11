class_name Rain2D
extends Node2D
## Cheap procedural night-rain for the mansion's outdoor beats (garden lawn,
## terrace). Pooled streaks, drawn straight to canvas: no textures, no
## particle nodes, zero allocation per frame.

@export var region := Rect2(0.0, -140.0, 1560.0, 780.0)
@export var drops := 130
@export var slant := 0.14        # sideways wind drift per unit fall
@export var base_speed := 620.0
@export var tint := Color(0.62, 0.74, 1.0, 0.34)

var _d: Array = []               # [x, y, speed, len]

func _ready() -> void:
	z_index = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in drops:
		_d.append([
			rng.randf_range(region.position.x, region.end.x),
			rng.randf_range(region.position.y, region.end.y),
			rng.randf_range(0.85, 1.2) * base_speed,
			rng.randf_range(9.0, 16.0),
		])


func _process(delta: float) -> void:
	for p in _d:
		p[1] += p[2] * delta
		p[0] += p[2] * slant * delta
		if p[1] > region.end.y:
			p[1] = region.position.y - 8.0
			p[0] = region.position.x + fposmod(p[0] + 97.0, region.size.x)
	queue_redraw()


func _draw() -> void:
	for p in _d:
		var tail := Vector2(p[3] * slant, p[3])
		draw_line(Vector2(p[0], p[1]), Vector2(p[0], p[1]) + tail, tint, 1.1)

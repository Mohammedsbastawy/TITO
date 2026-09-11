class_name SwingChandelier2D
extends Node2D
## The foyer chandelier as a REAL pendulum: pivot at the ceiling fixture, the
## art + a one-way landing plate ride the swing. Anything weighty landing on
## the plate kicks the amplitude up; it decays back to its resting sway.

const ENV := "res://assets2d/sprites/env/"

@export var total_h := 212.0      # chain + cluster, pivot to plate
@export var rest_amp := 0.24     # radians at rest
@export var period := 2.7
@export var plate_w := 88.0

var _amp := 0.24
var _t := 0.0
var _pivot: Node2D


func _ready() -> void:
	_pivot = Node2D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	# ceiling fixture dot right at the pivot
	var hub := Polygon2D.new()
	hub.polygon = PackedVector2Array([Vector2(-14, -10), Vector2(14, -10),
		Vector2(6, 4), Vector2(-6, 4)])
	hub.color = Color(0.55, 0.46, 0.24)
	_pivot.add_child(hub)
	# the art (chain included) hangs straight down from the pivot
	var spr := Sprite2D.new()
	spr.texture = load(ENV + "chandelier.png") as Texture2D
	if spr.texture != null:
		var sc := total_h / float(spr.texture.get_height())
		spr.scale = Vector2(sc, sc)
		spr.centered = false
		spr.position = Vector2(-float(spr.texture.get_width()) * sc * 0.5, 8.0)
		spr.z_index = -1
		_pivot.add_child(spr)
	# one-way landing plate at cluster bottom
	var body := AnimatableBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(-plate_w * 0.5, total_h + 8.0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(plate_w, 10.0)
	cs.shape = rect
	cs.one_way_collision = true
	cs.position = Vector2(plate_w * 0.5, 5.0)
	body.add_child(cs)
	_pivot.add_child(body)
	# kick detector: anything heavy touching the plate pumps the swing
	var kick := Area2D.new()
	kick.collision_layer = 0
	kick.collision_mask = 2     # player layer
	kick.monitoring = true
	kick.position = Vector2(0, total_h)
	var kcs := CollisionShape2D.new()
	var kr := RectangleShape2D.new()
	kr.size = Vector2(plate_w + 26.0, 26.0)
	kcs.shape = kr
	kick.add_child(kcs)
	_pivot.add_child(kick)
	kick.body_entered.connect(_on_kick_body)
	# warm halo riding the swing
	var glow := PointLight2D.new()
	glow.texture = load("res://assets2d/fx/light_dot.png") as Texture2D
	if glow.texture != null:
		glow.color = Color(1.0, 0.8, 0.45)
		glow.energy = 2.0
		glow.scale = Vector2.ONE * 2.6
		glow.position = Vector2(0, total_h * 0.82)
		_pivot.add_child(glow)


func _physics_process(delta: float) -> void:
	_t += delta
	_pivot.rotation = sin(_t * TAU / period) * _amp
	_amp = move_toward(_amp, rest_amp, delta * 0.05)  # calm decay


func _on_kick_body(body: Node2D) -> void:
	if body.is_in_group("player"):
		_amp = clampf(_amp + 0.16, rest_amp, 0.7)

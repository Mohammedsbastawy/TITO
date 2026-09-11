class_name Dart2D
extends Area2D
## Tito's stun dart (locker sidearm): silent, single-target, takes one of the
## squad out of the rotation without ruckus. Flies level, dies on first
## contact with the world or an enforcer body (layer 8).

@export var speed := 560.0
@export var life := 1.6

var velocity := Vector2.ZERO
var _trail: Line2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 9           # world (1) + enemies (8)
	monitoring = true
	_trail = Line2D.new()
	_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-16, 0)])
	_trail.width = 3.0
	_trail.default_color = Color(0.6, 1.0, 0.85, 0.8)
	_trail.z_index = 2
	add_child(_trail)
	var glow := PointLight2D.new()
	glow.texture = load("res://assets2d/fx/light_dot.png") as Texture2D
	if glow.texture != null:
		glow.color = Color(0.5, 1.0, 0.8)
		glow.energy = 0.7
		glow.scale = Vector2.ONE * 0.5
		add_child(glow)
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 4.0
	cs.shape = circ
	add_child(cs)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(life).timeout.connect(queue_free)


func launch(from: Vector2, dir: Vector2) -> void:
	global_position = from
	velocity = dir.normalized() * speed
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	global_position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(1, global_position)
	queue_free()

## Shared hostile projectile: marksman bolts (fast, straight), smoke
## canisters (arcing, burst into a HazardZone2D on contact), boss bolts.
## The spawner decorates it; physics is a plain Area2D fly-path.
class_name Projectile2D
extends Area2D

@export var speed := 380.0
@export var fall_gravity := 0.0
@export var damage := 1
@export var life := 3.0
@export var makes_hazard := false
@export var hazard_duration := 6.0
@export var tint := Color(1.0, 0.6, 0.3)

var velocity := Vector2.ZERO
var _body: Polygon2D


func _ready() -> void:
	collision_layer = 32       # hazards
	collision_mask = 3         # world + player
	monitoring = true
	_body = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 8:
		var a := i / 8.0 * TAU
		pts.append(Vector2(cos(a) * 7.0, sin(a) * 3.5))
	_body.polygon = pts
	_body.color = tint
	add_child(_body)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	cs.shape = circle
	add_child(cs)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(life).timeout.connect(queue_free)


func launch(from: Vector2, dir: Vector2, spd := -1.0) -> Projectile2D:
	global_position = from
	velocity = dir.normalized() * (spd if spd > 0.0 else speed)
	return self


func _physics_process(delta: float) -> void:
	if fall_gravity != 0.0:
		velocity.y += fall_gravity * delta
	global_position += velocity * delta
	if _body != null and velocity.length() > 1.0:
		_body.rotation = velocity.angle()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
		_burst()
	elif body.collision_layer & 1:
		_burst()  # wall/floor impact


func _burst() -> void:
	if makes_hazard:
		var zone := HazardZone2D.new()
		zone.duration = hazard_duration
		zone.position = global_position
		get_parent().add_child(zone)
	queue_free()

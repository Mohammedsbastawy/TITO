## Shared hostile projectile for the prologue: magnum shots (fast & straight),
## slam shockwaves (floor crawlers), tear-smoke canisters (lobbed arc that
## bursts into a TitoSmokeZone on impact). Visuals are attached by the spawner.
class_name TitoProjectile
extends Area3D

@export var speed := 12.0
@export var gravity := 0.0
@export var floor_crawl := false
@export var damage := 1
@export var life := 5.0
@export var break_on_world := true
@export var makes_smoke := false
@export var smoke_duration := 7.0

var velocity := Vector3.ZERO


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3   # world geometry + the player's body
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	cs.shape = sphere
	add_child(cs)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(life).timeout.connect(queue_free)


func launch(from: Vector3, dir: Vector3, spd := -1.0) -> TitoProjectile:
	global_position = from
	velocity = dir.normalized() * (spd if spd > 0.0 else speed)
	return self


func _physics_process(delta: float) -> void:
	if gravity != 0.0:
		velocity.y -= gravity * delta
	if floor_crawl:
		var fy = _floor_under(global_position + Vector3.UP * 0.6)
		if fy != null:
			global_position.y = fy + 0.22
			velocity.y = 0.0
	global_position += velocity * delta


func _floor_under(from: Vector3):
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.4)
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else null


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
		_burst()
	elif body.collision_layer & 1:
		_burst()  # wall/floor impact


func _burst() -> void:
	if makes_smoke:
		var zone := TitoSmokeZone.new()
		zone.duration = smoke_duration
		get_parent().add_child(zone)
		zone.global_position = global_position
	queue_free()

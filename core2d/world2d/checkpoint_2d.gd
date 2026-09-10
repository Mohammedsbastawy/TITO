## Respawn anchor: player walks through -> their respawn point moves here.
class_name Checkpoint2D
extends Area2D

var activated := false


func _ready() -> void:
	collision_layer = 64       # triggers
	collision_mask = 2         # player body
	body_entered.connect(_on_body_entered)
	# thin marker pole
	var pole := Polygon2D.new()
	pole.polygon = PackedVector2Array([
		Vector2(-2, 0), Vector2(2, 0), Vector2(2, -56), Vector2(-2, -56)])
	pole.color = Color(0.9, 0.7, 0.3, 0.85)
	add_child(pole)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 72)
	cs.shape = rect
	cs.position = Vector2(0, -36)
	add_child(cs)


func _on_body_entered(body: Node2D) -> void:
	if activated or not body.has_method("set_checkpoint"):
		return
	activated = true
	body.call("set_checkpoint", global_position)
	# flare the pole so the save "reads"
	var pole := get_child(0) as Polygon2D
	if pole != null:
		pole.color = Color(0.4, 1.0, 0.55, 0.95)

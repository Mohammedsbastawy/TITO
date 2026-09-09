## A climbable rope. Overlap + press W/S to climb. `top_y` is the anchor height.
class_name TitoRope
extends Area3D

@export var top_y := 8.0


func _ready() -> void:
	add_to_group("ropes")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_rope"):
		body.set_rope(self)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_rope"):
		body.set_rope(null)

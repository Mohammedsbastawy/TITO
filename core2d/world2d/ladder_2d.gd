## Wall ladder: while the player overlaps, climb_up/down enters a climb
## state (Player2D handles the movement; jump kicks off the ladder).
class_name Ladder2D
extends Area2D


func _ready() -> void:
	collision_layer = 64       # triggers
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_ladder"):
		body.call("set_ladder", self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_ladder"):
		body.call("set_ladder", null)

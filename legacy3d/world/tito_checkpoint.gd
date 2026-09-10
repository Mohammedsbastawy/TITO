## Checkpoint flag: touching it saves respawn position.
class_name TitoCheckpoint
extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_checkpoint"):
		body.set_checkpoint(global_position + Vector3(0, 1.0, 0))
		print("CHECKPOINT reached: ", global_position)

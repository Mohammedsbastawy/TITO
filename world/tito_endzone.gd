## Mission exit zone: touching it completes the mission.
class_name TitoEndZone
extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("mission_complete_signal"):
		body.mission_complete_signal()
		print("MISSION COMPLETE")

## Kill-floor: falling into it damages and respawns at the last checkpoint.
class_name TitoDeathZone
extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("fell_out"):
		body.fell_out()

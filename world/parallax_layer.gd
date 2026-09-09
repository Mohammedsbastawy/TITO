## Depth-faking mover for 2.5D backdrops (Prince of Persia style layering).
## Child quads partially follow the camera instead of staying in world space:
##   stick  0.0  -> normal world object (moves with the level)
##   stick  1.0  -> glued to the camera (infinitely far away)
##   stick  0.6-0.95 -> mid/far parallax layers
##   stick  >1   -> FOREGROUND sweep: slides against the world, feels close
class_name CairoParallax
extends Node3D

@export_range(-1.0, 2.0) var stick := 0.8
@export var vertical_drift := 0.15   # how much jumps shift the layer on Y

var _base := Vector3.ZERO
var _cam_y_base := 0.0


func _ready() -> void:
	_base = position


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _cam_y_base == 0.0:
		_cam_y_base = cam.global_position.y
	position.x = _base.x + cam.global_position.x * stick
	position.y = _base.y + (cam.global_position.y - _cam_y_base) * stick * vertical_drift

## Diagnostic 4: why is current_animation not "run" while vel=6?
extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	var ap: AnimationPlayer = tito.get_node("Model/TitoModel/AnimationPlayer")

	_settle(tito, 45.0)
	print("after settle: anim=%s internal=%s playing=%s" % [ap.current_animation, str(tito.get("_current_anim")), str(ap.is_playing())])
	Input.action_press("move_right")
	for i in 40:
		await process_frame
		if i % 8 == 0:
			print("run f=%d anim=%s internal=%s vel=%.1f" % [i, ap.current_animation, str(tito.get("_current_anim")), tito.velocity.x])
	print("state=%s speed_export=%.1f" % [str(tito.get("state")), tito.get("max_speed")])
	Input.action_release("move_right")
	for i in 90:
		await process_frame
		if i % 15 == 0:
			print("stop f=%d anim=%s internal=%s vel=%.1f" % [i, ap.current_animation, str(tito.get("_current_anim")), tito.velocity.x])
	quit(0)

func _settle(tito: CharacterBody3D, x: float) -> void:
	tito.global_position = Vector3(x, 1.75, 0)
	tito.velocity = Vector3.ZERO
	for i in 60:
		await process_frame
		if tito.is_on_floor() and absf(tito.velocity.y) < 0.01:
			break
	for i in 15:
		await process_frame
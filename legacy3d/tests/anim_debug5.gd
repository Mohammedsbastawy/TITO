## Diagnostic 5: frame-exact _current_anim vs current_animation vs floor.
extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://legacy3d/levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	var ap: AnimationPlayer = tito.get_node("Model/TitoModel/AnimationPlayer")

	# settle
	tito.global_position = Vector3(5.0, 1.75, 0)
	tito.velocity = Vector3.ZERO
	for i in 60:
		await process_frame
		if tito.is_on_floor() and absf(tito.velocity.y) < 0.01:
			break
	for i in 15:
		await process_frame
	print("settled: cur=%s internal=%s playing=%s floor=%s" % [ap.current_animation, str(tito.get("_current_anim")), str(ap.is_playing()), str(tito.is_on_floor())])

	Input.action_press("move_right")
	for i in 25:
		await process_frame
		print("f=%02d cur=%-12s internal=%-6s playing=%-5s floor=%-5s vel=%.1f y=%.2f" % [i, ap.current_animation, str(tito.get("_current_anim")), str(ap.is_playing()), str(tito.is_on_floor()), tito.velocity.x, tito.velocity.y])
	Input.action_release("move_right")
	quit(0)
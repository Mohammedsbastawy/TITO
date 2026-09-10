## Diagnostic 2: is the punch slowing movement? Track state + speed each frame.
extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	var ap: AnimationPlayer = tito.get_node("Model/TitoModel/AnimationPlayer")

	tito.global_position = Vector3(45.0, 1.75, 0)
	tito.velocity = Vector3.ZERO
	for i in 15:
		await process_frame
	Input.action_press("move_right")
	for i in 30:
		await process_frame
	print("before punch: anim=%s vel=%.1f state=%s pos=%.1f" % [ap.current_animation, tito.velocity.x, str(tito.get("state")), tito.global_position.x])
	tito.call("_start_swing")
	print("after _start_swing: vel=%.1f" % tito.velocity.x)
	for i in 90:
		await process_frame
		if i % 10 == 0:
			print("t=%3d anim=%s playing=%s vel=%.1f state=%s x=%.1f" % [i, ap.current_animation, str(ap.is_playing()), tito.velocity.x, str(tito.get("state")), tito.global_position.x])
	# wait for punch to fully finish
	for i in 200:
		await process_frame
		if not ap.is_playing():
			break
	print("punch done at frame: anim=%s playing=%s" % [ap.current_animation, str(ap.is_playing())])
	for i in 40:
		await process_frame
		if i % 10 == 0:
			print("after done t=%d anim=%s vel=%.1f state=%s" % [i, ap.current_animation, tito.velocity.x, str(tito.get("state"))])
	Input.action_release("move_right")
	quit(0)
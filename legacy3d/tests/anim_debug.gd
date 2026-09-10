## Diagnostic: what animation actually runs after punch ends / after stopping.
extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	var ap: AnimationPlayer = tito.get_node("Model/TitoModel/AnimationPlayer")

	# --- scenario 1: punch while running
	tito.global_position = Vector3(45.0, 1.75, 0)
	tito.velocity = Vector3.ZERO
	for i in 15:
		await process_frame
	tito.set("facing", 1)
	tito.call("_start_swing")
	Input.action_press("move_right")
	var last := ""
	for i in 300:
		await process_frame
		var cur: String = ap.current_animation
		if cur != last:
			print("t=%3d anim=%s playing=%s grounded=%s vel=%.1f pos=%.1f" % [i, cur, str(ap.is_playing()), str(tito.is_on_floor()), tito.velocity.x, tito.global_position.x])
			last = cur
	Input.action_release("move_right")

	print("---- scenario 2: stop after run ----")
	tito.global_position = Vector3(45.0, 1.75, 0)
	tito.velocity = Vector3.ZERO
	for i in 15:
		await process_frame
	Input.action_press("move_right")
	for i in 20:
		await process_frame
	Input.action_release("move_right")
	last = ""
	for i in 120:
		await process_frame
		var cur2: String = ap.current_animation
		if cur2 != last:
			print("t=%3d anim=%s playing=%s grounded=%s vel=%.1f" % [i, cur2, str(ap.is_playing()), str(tito.is_on_floor()), tito.velocity.x])
			last = cur2
	quit(0)
## Diagnostic 3: what happens between punch end and run? Frame-exact trace.
extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	var ap: AnimationPlayer = tito.get_node("Model/TitoModel/AnimationPlayer")

	# settle
	tito.global_position = Vector3(45.0, 1.75, 0)
	tito.velocity = Vector3.ZERO
	for i in 60:
		await process_frame
		if tito.is_on_floor() and absf(tito.velocity.y) < 0.01:
			break
	for i in 10:
		await process_frame
	print("settled: anim=%s vel=%.1f floor=%s input_axis_will_be=%s" % [ap.current_animation, tito.velocity.x, str(tito.is_on_floor()), "right"])

	tito.set("facing", 1)
	tito.call("_start_swing")
	Input.action_press("move_right")
	var last := ""
	for i in 200:
		await process_frame
		var cur: String = ap.current_animation
		var curp: bool = ap.is_playing()
		var key := cur + "/" + str(curp)
		if key != last:
			print("f=%3d anim=%-18s playing=%-5s vel=%.1f floor=%s x=%.1f" % [i, cur, str(curp), tito.velocity.x, str(tito.is_on_floor()), tito.global_position.x])
			last = key
		if i > 180:
			break
	Input.action_release("move_right")
	quit(0)
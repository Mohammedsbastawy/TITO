## Diagnostic 6: settle at spawn 2.2, then trace the exact transition frames.
extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://legacy3d/levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	var ap: AnimationPlayer = tito.get_node("Model/TitoModel/AnimationPlayer")

	tito.global_position = Vector3(5.0, 2.2, 0)
	tito.velocity = Vector3.ZERO
	var last := ""
	for i in 140:
		await process_frame
		var cur: String = ap.current_animation
		var key := cur + "/" + str(tito.is_on_floor())
		if key != last:
			print("f=%3d anim=%-12s floor=%-5s vel=%.1f y=%.2f playing=%s" % [i, cur, str(tito.is_on_floor()), tito.velocity.x, tito.global_position.y, str(ap.is_playing())])
			last = key
	print("--- press right ---")
	Input.action_press("move_right")
	last = ""
	for i in 40:
		await process_frame
		var cur2: String = ap.current_animation
		var key2 := cur2 + "/" + str(tito.is_on_floor())
		if key2 != last:
			print("f=%3d anim=%-12s floor=%-5s vel=%.1f playing=%s internal=%s" % [i, cur2, str(tito.is_on_floor()), tito.velocity.x, str(ap.is_playing()), str(tito.get("_current_anim"))])
			last = key2
	Input.action_release("move_right")
	print("--- release ---")
	last = ""
	for i in 120:
		await process_frame
		var cur3: String = ap.current_animation
		var key3 := cur3 + "/" + str(ap.is_playing())
		if key3 != last:
			print("f=%3d anim=%-12s playing=%-5s internal=%s vel=%.1f" % [i, cur3, str(ap.is_playing()), str(tito.get("_current_anim")), tito.velocity.x])
			last = key3
		if i > 100:
			break
	quit(0)
## Diagnostic 7: replay the EXACT test sequence and print every transition.
extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	var ap: AnimationPlayer = tito.get_node("Model/TitoModel/AnimationPlayer")

	# ---- settle exactly like the test
	tito.global_position = Vector3(5.0, 2.2, 0)
	tito.velocity = Vector3.ZERO
	for i in 120:
		await process_frame
		if tito.is_on_floor() and absf(tito.velocity.y) < 0.01 \
			and tito.global_position.y > 0.5 and tito.global_position.y < 1.2:
			break
	for i in 20:
		await process_frame
	print("settled: anim=%s y=%.2f floor=%s internal=%s" % [ap.current_animation, tito.global_position.y, str(tito.is_on_floor()), str(tito.get("_current_anim"))])

	# ---- run right, wait for run clip
	Input.action_press("move_right")
	var got_run := false
	for i in 120:
		await process_frame
		if ap.current_animation == "tito/run":
			got_run = true
			print("run at f=%d" % i)
			break
	if not got_run:
		# trace what happened instead
		var last := ""
		for i in 60:
			await process_frame
			var key: String = ap.current_animation + "/" + str(tito.is_on_floor()) + "/y=%.1f" % tito.global_position.y
			if key != last:
				print("NOT-RUN f=%d %s vel=%.1f x=%.1f" % [i, key, tito.velocity.x, tito.global_position.x])
				last = key
	Input.action_release("move_right")
	print("got_run=", got_run)

	# ---- stop -> idle
	Input.action_press("move_right")
	for i in 12:
		await process_frame
	Input.action_release("move_right")
	var got_idle := false
	for i in 90:
		await process_frame
		if ap.current_animation == "tito/idle":
			got_idle = true
			break
	if not got_idle:
		var last2 := ""
		for i in 90:
			await process_frame
			var key2: String = ap.current_animation + "/" + str(tito.is_on_floor())
			if key2 != last2:
				print("NOT-IDLE f=%d %s vel=%.1f x=%.1f y=%.2f" % [i, key2, tito.velocity.x, tito.global_position.x, tito.global_position.y])
				last2 = key2
	print("got_idle=", got_idle)
	quit(0)
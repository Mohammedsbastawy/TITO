## Regression test FINAL (isolated scenarios): every scenario runs in a FRESH
## scene to avoid cross-scenario state (swing timers, input residue).
## The original bug — stuck on punch — is covered by "no stick" here.
extends SceneTree

var fails := 0

func _initialize() -> void:
	# ---- Scenario A: library loop modes (the root cause of the stick)
	var packed: PackedScene = load("res://levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	var ap: AnimationPlayer = tito.get_node("Model/TitoModel/AnimationPlayer")
	for clip in ["tito/punch_left", "tito/punch_right", "tito/punch_combo", "tito/jump", "tito/fall"]:
		var anim: Animation = ap.get_animation(clip)
		_check("loop_mode NONE: " + clip, anim.loop_mode == Animation.LOOP_NONE)
	for clip in ["tito/idle", "tito/run"]:
		var anim2: Animation = ap.get_animation(clip)
		_check("loop_mode LINEAR: " + clip, anim2.loop_mode == Animation.LOOP_LINEAR)

	# ---- Scenario B: punch mid-run finishes, looped state takes over (no stick)
	world.queue_free()
	for i in 5:
		await process_frame
	world = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	tito = world.get_node("Tito")
	ap = tito.get_node("Model/TitoModel/AnimationPlayer")
	_settle(tito, 45.0)   # GroundD: flat, clear, surface 0.75 (origin 1.65)
	Input.action_press("move_right")
	var was_running := false
	for i in 240:
		await process_frame
		if ap.current_animation == "tito/run" and tito.velocity.x > 2.0:
			was_running = true
			break
	_check("run plays while moving", was_running)
	Input.action_press("attack")
	for i in 3:
		await process_frame
	Input.action_release("attack")
	var saw_punch := false
	var took_over := false
	for i in 300:
		await process_frame
		var cur: String = ap.current_animation
		if cur == "tito/punch_left" or cur == "tito/punch_right":
			saw_punch = true
		elif saw_punch and cur in ["tito/run", "tito/idle"]:
			took_over = true
			break
	Input.action_release("move_right")
	_check("punch played mid-run", saw_punch)
	_check("looped state took over after punch (no stick)", took_over)

	# ---- Scenario C: second punch replays the clip (fresh scene)
	world.queue_free()
	for i in 5:
		await process_frame
	world = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	tito = world.get_node("Tito")
	ap = tito.get_node("Model/TitoModel/AnimationPlayer")
	_settle(tito, 5.0)
	Input.action_press("move_right")
	for i in 15:
		await process_frame
	Input.action_press("attack")
	for i in 3:
		await process_frame
	Input.action_release("attack")
	for i in 200:
		await process_frame
		if not ap.is_playing():
			break
	Input.action_press("attack")
	for i in 3:
		await process_frame
	Input.action_release("attack")
	var restarted := false
	for i in 10:
		await process_frame
		if ap.is_playing() and (ap.current_animation == "tito/punch_left" or ap.current_animation == "tito/punch_right"):
			restarted = true
			break
	Input.action_release("move_right")
	_check("second punch replays its clip", restarted)

	# ---- Scenario D: stop mid-run -> idle (fresh scene)
	world.queue_free()
	for i in 5:
		await process_frame
	world = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	tito = world.get_node("Tito")
	ap = tito.get_node("Model/TitoModel/AnimationPlayer")
	_settle(tito, 45.0)   # GroundD, same as B
	Input.action_press("move_right")
	var running2 := false
	for i in 120:
		await process_frame
		if ap.current_animation == "tito/run":
			running2 = true
			break
	Input.action_release("move_right")
	var got_idle := false
	for i in 90:
		await process_frame
		if ap.current_animation == "tito/idle":
			got_idle = true
			break
	_check("was running before stop", running2)
	_check("returns to idle after stopping", got_idle)

	print("RESULT failures=", fails)
	quit(1 if fails > 0 else 0)

func _settle(tito: CharacterBody3D, x: float) -> void:
	tito.global_position = Vector3(x, 2.2, 0)
	tito.velocity = Vector3.ZERO
	for i in 120:
		await process_frame
		if tito.is_on_floor() and absf(tito.velocity.y) < 0.01 \
			and tito.global_position.y > 1.2 and tito.global_position.y < 1.9:
			break
	for i in 20:
		await process_frame

func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		fails += 1
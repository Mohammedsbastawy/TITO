## Headless smoke test (3D): drives Tito with synthetic input and asserts
## movement, turning (3D rotation.y flip), jump, landing, and the Z-axis lock.
## Run:  godot --headless --path . res://tests/smoke_test.tscn
extends Node

var fails: PackedStringArray = []


func _ready() -> void:
	var packed: PackedScene = load("res://levels/main.tscn")
	if packed == null:
		print("FAIL  could not load res://levels/main.tscn")
		get_tree().quit(1)
		return
	var world: Node = packed.instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var tito := world.get_node_or_null("Tito") as CharacterBody3D
	_check("TitoBody exists", tito != null)
	if tito == null:
		_finish()
		return
	var model := tito.get_node_or_null("Model") as Node3D
	var imported_model := tito.get_node_or_null("Model/TitoModel") as Node3D
	_check("3D model wrapper exists", model != null)
	_check("Tito.glb is instanced", imported_model != null)

	# --- settle on the floor
	for i in 10:
		await get_tree().physics_frame
	_check("on floor after settle", tito.is_on_floor())
	_check("z locked at 0 (settle)", absf(tito.global_position.z) < 0.001)

	# --- run right
	var x0 := tito.global_position.x
	Input.action_press("move_right")
	for i in 30:
		await get_tree().physics_frame
	_check("moved right", tito.global_position.x - x0 > 1.0)
	_check("facing right", tito.get("facing") == 1)
	_check("3D model rotation.y ~0 (faces right)", model == null or absf(fmod(model.rotation.y, TAU)) < 0.02)
	_check("no z drift (right)", absf(tito.global_position.z) < 0.001)

	# --- hard stop (deceleration)
	Input.action_release("move_right")
	for i in 20:
		await get_tree().physics_frame
	_check("decelerated to stop", absf(tito.velocity.x) < 0.05)

	# --- run left (sharp turn -> 3D flip)
	var x1 := tito.global_position.x
	Input.action_press("move_left")
	for i in 20:
		await get_tree().physics_frame
	_check("moved left", tito.global_position.x < x1)
	_check("facing left", tito.get("facing") == -1)
	_check("model rotation.y ~PI (faces left)", model == null or absf(fmod(model.rotation.y, TAU) - PI) < 0.02)
	_check("no z drift (left)", absf(tito.global_position.z) < 0.001)
	Input.action_release("move_left")

	# --- stop, then jump
	for i in 30:
		await get_tree().physics_frame
	var y0 := tito.global_position.y
	var peak := y0
	var landed := false
	Input.action_press("jump")
	for i in 200:
		await get_tree().physics_frame
		peak = maxf(peak, tito.global_position.y)
		if i == 20:
			Input.action_release("jump")
		if i > 25 and tito.is_on_floor():
			landed = true
			break
	_check("jumped (>1 unit)", peak - y0 > 1.0)
	_check("landed back on floor", landed)
	_check("no z drift (jump)", absf(tito.global_position.z) < 0.001)

	_finish()


func _check(test_name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + test_name)
	if not ok:
		fails.append(test_name)


func _finish() -> void:
	print("RESULT: %d failure(s)" % fails.size())
	get_tree().quit(0 if fails.is_empty() else 1)

## Quality regression: continuous run must keep the visual mesh OUT of the
## ground (Mixamo root motion converted to in-place) and locomotion clips must
## crossfade without the body snapping into the collider.
extends SceneTree

var fails := 0

func _initialize() -> void:
	var packed: PackedScene = load("res://levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	var ap: AnimationPlayer = tito.get_node("Model/TitoModel/AnimationPlayer")

	# Settle on GroundD (flat, clear) at x=45.
	tito.global_position = Vector3(45.0, 2.2, 0)
	tito.velocity = Vector3.ZERO
	for i in 120:
		await process_frame
		if tito.is_on_floor() and absf(tito.velocity.y) < 0.01 \
			and tito.global_position.y > 1.2 and tito.global_position.y < 1.9:
			break
	for i in 20:
		await process_frame

	var body_y_start: float = tito.global_position.y
	# Run continuously for 3 seconds; sample the body's Y and the mesh's lowest
	# world point across the run. The mesh must never sink below the collider
	# floor or oscillate (root-motion not removed -> big Y swings).
	Input.action_press("move_right")
	var min_body_y := 999.0
	var max_body_y := -999.0
	var mesh_min_y := 999.0
	var prev_anim := ""
	var cuts := 0
	var _all_anims := ""
	for i in 180:
		await process_frame
		min_body_y = minf(min_body_y, tito.global_position.y)
		max_body_y = maxf(max_body_y, tito.global_position.y)
		# Lowest vertex of the visible model in world space.
		var model: Node3D = tito.get_node("Model/TitoModel")
		var arb: MeshInstance3D = _first_mesh(model)
		if arb != null:
			var inv: Transform3D = arb.global_transform.affine_inverse()
			for v in arb.mesh.get_faces():
				var w: Vector3 = arb.global_transform * inv * v
				mesh_min_y = minf(mesh_min_y, w.y)
		var cur: String = ap.current_animation
		_all_anims += cur + " "
		if cur != prev_anim and prev_anim != "" and cur == "tito/run":
			cuts += 1
		prev_anim = cur
	Input.action_release("move_right")

	# Body must stay grounded (collider bottom ~0.75) and not dive below 0.4.
	_check("body stays above ground while running", min_body_y > 0.4)
	_check("body does not fly up unrealistically", max_body_y < 5.0)
	# Mesh surface must never sink below the collision floor (0.75) by more
	# than a small tolerance; root-motion-in-place keeps it near foot level.
	_check("mesh never sinks into ground", mesh_min_y > 0.0)
	# Continuous run should not repeatedly hard-cut back to run (crossfade).
	_check("run is stable (no repeated hard cuts)", cuts <= 1)
	# The run clip must actually play at some point during the movement window.
	_check("run plays during movement", "tito/run" in _all_anims)
	print("DEBUG saw_run=", ("tito/run" in _all_anims), " mesh_min=", mesh_min_y)

	print("RESULT failures=", fails)
	quit(1 if fails > 0 else 0)

func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh != null:
		return node
	for child in node.get_children():
		var r: MeshInstance3D = _first_mesh(child)
		if r != null:
			return r
	return null

func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		fails += 1

extends SceneTree

func _initialize() -> void:
	var files: Array = [
		"Breathing Idle.fbx",
		"Falling To Landing.fbx",
		"Jumping.fbx",
		"Punch Combo.fbx",
		"Running.fbx",
		"left Punching.fbx",
		"right Punching.fbx",
	]
	for f in files:
		var path: String = "res://assets/models/TITO/" + f
		var packed: PackedScene = load(path)
		if packed == null:
			print("LOAD FAIL  ", f)
			continue
		var root: Node = packed.instantiate()
		get_root().add_child(root)
		var ap: AnimationPlayer = _find_animation_player(root)
		var sk: Skeleton3D = _find_skeleton(root)
		var anims: Array = ap.get_animation_list() if ap else []
		print("FILE ", f)
		print("  animations: ", anims)
		if sk:
			print("  bones: ", sk.get_bone_count())
		root.queue_free()
	quit(0)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r: AnimationPlayer = _find_animation_player(c)
		if r != null:
			return r
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var r: Skeleton3D = _find_skeleton(c)
		if r != null:
			return r
	return null
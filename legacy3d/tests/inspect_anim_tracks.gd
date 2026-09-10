extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://assets/models/TITO/Running.fbx")
	var root_node: Node = packed.instantiate()
	root.add_child(root_node)
	await process_frame
	var ap: AnimationPlayer = _find_player(root_node)
	var anim: Animation = ap.get_animation("mixamo_com")
	print("length=", anim.length, " tracks=", anim.get_track_count())
	for i in anim.get_track_count():
		var path: NodePath = anim.track_get_path(i)
		var type: int = anim.track_get_type(i)
		print(i, " type=", type, " path=", path, " keys=", anim.track_get_key_count(i))
	quit(0)

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result: AnimationPlayer = _find_player(child)
		if result != null:
			return result
	return null

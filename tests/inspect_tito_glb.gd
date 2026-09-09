extends SceneTree

func _initialize() -> void:
	var packed := load("res://assets/models/Tito.glb") as PackedScene
	if packed == null:
		print("FAIL unable to load Tito.glb")
		quit(1)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	print("ROOT: %s (%s)" % [root.name, root.get_class()])
	_walk(root, "")
	quit(0)

func _walk(node: Node, indent: String) -> void:
	var extra := ""
	if node is AnimationPlayer:
		extra = " animations=" + str((node as AnimationPlayer).get_animation_list())
	elif node is Skeleton3D:
		extra = " bones=%d" % (node as Skeleton3D).get_bone_count()
	elif node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		extra = " mesh=" + (mesh.get_class() if mesh else "none")
	print(indent + node.name + " (" + node.get_class() + ")" + extra)
	for child in node.get_children():
		_walk(child, indent + "  ")

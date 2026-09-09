extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://assets/models/TITO/Breathing Idle.fbx")
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	_walk(root, "")
	quit(0)

func _walk(node: Node, indent: String) -> void:
	var info := ""
	if node is Skeleton3D:
		var sk := node as Skeleton3D
		info = " [Skeleton3D bones=%d]" % sk.get_bone_count()
		# print first few bone names
		for i in range(mini(5, sk.get_bone_count())):
			info += "\n" + indent + "   bone[%d]=%s" % [i, sk.get_bone_name(i)]
	elif node is AnimationPlayer:
		info = " [AnimationPlayer]"
	elif node is MeshInstance3D:
		info = " [Mesh]"
	print(indent + node.name + " (" + node.get_class() + ")" + info)
	for c in node.get_children():
		_walk(c, indent + "  ")

func mini(a: int, b: int) -> int:
	return a if a < b else b
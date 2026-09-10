extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://legacy3d/levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	# Walk the whole TitoModel subtree and print every node + its class.
	var model: Node = tito.get_node("Model/TitoModel")
	_walk(model, "")
	quit(0)

func _walk(node: Node, indent: String) -> void:
	var extra := ""
	if node is AnimationPlayer:
		var ap := node as AnimationPlayer
		extra = " libs=" + str(ap.get_animation_library_list()) + " anims=" + str(ap.get_animation_list())
	print(indent + node.name + " (" + node.get_class() + ")" + extra)
	for c in node.get_children():
		_walk(c, indent + "  ")
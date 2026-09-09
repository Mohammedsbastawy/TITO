extends SceneTree

func _initialize() -> void:
	var packed := load("res://assets/models/Tito.glb") as PackedScene
	var root := packed.instantiate() as Node3D
	get_root().add_child(root)
	var found := false
	var bounds := AABB()
	for mesh_node in _meshes(root):
		var aabb := (mesh_node as MeshInstance3D).get_aabb()
		var world_aabb := _transform_aabb(mesh_node.global_transform, aabb)
		bounds = world_aabb if not found else bounds.merge(world_aabb)
		found = true
	print("MODEL_AABB position=%s size=%s center=%s" % [bounds.position, bounds.size, bounds.get_center()])
	quit(0)

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_meshes(child))
	return result

func _transform_aabb(t: Transform3D, aabb: AABB) -> AABB:
	var out := AABB(t * aabb.position, Vector3.ZERO)
	for x in [0.0, aabb.size.x]:
		for y in [0.0, aabb.size.y]:
			for z in [0.0, aabb.size.z]:
				out = out.expand(t * (aabb.position + Vector3(x, y, z)))
	return out

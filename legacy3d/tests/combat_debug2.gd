## Diagnostic 2: why does try_hit find no overlaps during enemy swing?
extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://legacy3d/levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: CharacterBody3D = world.get_node("Tito")
	var list := get_nodes_in_group("enemies")
	var enemy: CharacterBody3D = list[0]
	enemy.set_physics_process(false)
	tito.global_position = Vector3(3.0, 2.2, 0)
	enemy.global_position = Vector3(6.0, 2.2, 0)
	for i in 90:
		await process_frame
	var gy: float = tito.global_position.y
	tito.global_position = Vector3(enemy.global_position.x + 1.0, gy, 0)
	for i in 10:
		await process_frame

	var hb: Area3D = enemy._hitbox
	var phb: Area3D = tito._hurtbox
	print("hitbox layer=%d mask=%d mon=%s" % [hb.collision_layer, hb.collision_mask, str(hb.monitoring)])
	print("player hurtbox layer=%d mask=%d mon=%s monable=%s groups=%s" % [
		phb.collision_layer, phb.collision_mask, str(phb.monitoring), str(phb.monitorable), str(phb.get_groups())])
	print("hitbox world pos=", hb.global_position, " player hurt world=", phb.global_position)
	print("hitbox in tree=", hb.is_inside_tree(), " visible=", hb.visible)

	# Force a LONG swing window manually and watch overlaps appear.
	hb.monitoring = true
	enemy._swing_hits.clear()
	for f in 30:
		await process_frame
		var overlaps: Array = hb.get_overlapping_areas()
		if f % 5 == 0 or overlaps.size() > 0:
			print("f=%d overlaps=%d" % [f, overlaps.size()])
			for a in overlaps:
				print("   -> ", a.get_path(), " groups=", a.get_groups())
	var hits: int = TitoCombat.try_hit(enemy, "Visual/HitBox", ["player"], {})
	print("manual try_hit result=", hits)
	quit(0)

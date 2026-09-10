## Diagnostic: trace _do_attack state frame by frame.
extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://levels/mission1.tscn")
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
	enemy.state = TitoEnemy.State.ATTACK
	enemy._attack_timer = 0.0
	enemy._player = tito
	enemy.set_physics_process(true)
	for i in 90:
		await process_frame
		if i % 10 == 0:
			var in_range: bool = enemy._in_attack_range()
			var can_see: bool = enemy._can_see_player()
			print("f=%d state=%s timer=%.2f swing=%.2f in_range=%s see=%s mon=%s epos=%.2f tpos=%.2f" % [
				i, TitoEnemy.State.keys()[enemy.state], enemy._attack_timer,
				enemy._swing_timer, str(in_range), str(can_see),
				str(enemy._hitbox.monitoring), enemy.global_position.x, tito.global_position.x])
		if tito._health.hp < tito._health.max_hp:
			print("HIT at f=", i, " hp=", tito._health.hp)
			break
	quit(0)

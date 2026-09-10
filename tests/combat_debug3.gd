## Diagnostic: why does the enemy attack no longer land in combat_test?
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
	print("gy=", gy, " tito_floor=", tito.is_on_floor(), " enemy_floor=", enemy.is_on_floor())
	tito.global_position = Vector3(enemy.global_position.x + 1.0, gy, 0)
	enemy.state = TitoEnemy.State.ATTACK
	enemy._attack_timer = 0.0
	enemy.set_physics_process(true)
	for i in 90:
		await process_frame
		if i % 10 == 0:
			print("f=%d state=%s phase=%s atk_timer=%.2f in_range=%s see=%s hp=%d epos=%.2f tpos=%.2f" % [
				i, TitoEnemy.State.keys()[enemy.state],
				TitoEnemy.AttackPhase.keys()[enemy._attack_phase] if "_attack_phase" in enemy else "?",
				enemy._attack_timer, str(enemy._in_attack_range()),
				str(enemy._can_see_player()), tito._health.hp,
				enemy.global_position.x, tito.global_position.x])
		if tito._health.hp < tito._health.max_hp:
			print("HIT at f=", i)
			break
	quit(0)

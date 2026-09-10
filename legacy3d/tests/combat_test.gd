## Combat regression v2: vision cone, enemy attack, i-frames, player punch,
## enemy death. All on the flat starting platform (x 1..9, clear sky).
extends SceneTree

var fails := 0

func _initialize() -> void:
	var packed: PackedScene = load("res://levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: CharacterBody3D = world.get_node("Tito")
	var list := get_nodes_in_group("enemies")
	var enemy: CharacterBody3D = list[0] if list.size() > 0 else null
	_check("enemy exists in mission", enemy != null)
	if enemy == null:
		print("RESULT failures=", fails)
		quit(1)
		return

	# Freeze the training enemy's own brain: drive it manually via direct
	# calls so level layout (patrol edges) cannot interfere.
	enemy.set_physics_process(false)

	# Settle both on the starting platform (surface y=0 -> origin 0.9... use
	# observed settle: spawn 2.2, feet land at y=0.9 per stick-test data).
	var gy := 0.9
	tito.global_position = Vector3(3.0, 2.2, 0)
	tito.velocity = Vector3.ZERO
	enemy.global_position = Vector3(6.0, 2.2, 0)
	enemy.velocity = Vector3.ZERO
	for i in 90:
		await process_frame
		if tito.is_on_floor() and enemy.is_on_floor():
			break
	gy = tito.global_position.y
	_check("both grounded on start platform", tito.is_on_floor() and enemy.is_on_floor())

	# --- Scenario 1: vision cone (enemy dir +1: sees right, not left)
	enemy._dir = 1.0
	tito.global_position = Vector3(enemy.global_position.x + 3.0, gy, 0)
	for i in 8:
		await process_frame
	_check("vision clear in front (dir+1, player right)", enemy._can_see_player())
	tito.global_position = Vector3(enemy.global_position.x - 3.0, gy, 0)
	for i in 8:
		await process_frame
	_check("vision blocked from behind (dir+1, player left)", not enemy._can_see_player())
	enemy._dir = -1.0
	for i in 8:
		await process_frame
	_check("vision follows facing flip", enemy._can_see_player())

	# --- Scenario 2: enemy attack is telegraphed (windup), then lands; i-frames
	enemy.set_physics_process(true)   # brain back on for the attack scenario
	tito.global_position = Vector3(enemy.global_position.x + 1.0, gy, 0)
	enemy.state = TitoEnemy.State.ATTACK
	enemy._attack_timer = 0.0
	var hp_before: int = tito._health.hp
	# the windup must NEVER deal instant damage: free reaction time up front
	for i in 6:
		await process_frame
	_check("attack is telegraphed (no instant hit)", tito._health.hp == hp_before)
	var got_hit := false
	for i in 60:
		await process_frame
		if tito._health.hp < hp_before:
			got_hit = true
			break
	_check("enemy attack damages player", got_hit)
	_check("i-frames active after hit", tito._invuln > 0.0)
	_check("blink timer active after hit", tito._flash_timer > 0.0)
	var hp_after_first: int = tito._health.hp
	for i in 25:  # ~0.42s, inside the 1.0s i-frame window
		await process_frame
	_check("i-frames block repeat hits", tito._health.hp == hp_after_first)

	# --- Scenario 3: player punch damages enemy
	tito._invuln = 0.0
	tito._flash_timer = 0.0
	# player stands left of enemy, faces right, in punch range
	tito.global_position = Vector3(enemy.global_position.x - 1.0, gy, 0)
	tito.velocity = Vector3.ZERO
	for i in 8:
		await process_frame
	enemy._attack_timer = 5.0
	enemy._swing_timer = 0.0
	var ehp_before: int = enemy._health.hp
	Input.action_press("attack")
	for i in 3:
		await process_frame
	Input.action_release("attack")
	var player_hit_enemy := false
	for i in 40:
		await process_frame
		if enemy._health.hp < ehp_before:
			player_hit_enemy = true
			break
	_check("player punch damages enemy", player_hit_enemy)
	_check("punched enemy staggers (hit reaction)", enemy.state == TitoEnemy.State.STAGGER)

	# --- Scenario 4: enemy death (kill via take_damage, check no un-die)
	enemy.take_damage(999)
	for i in 3:
		await process_frame
	_check("enemy dies at 0 hp", enemy.state == TitoEnemy.State.DEAD)
	_check("enemy hitbox closed on death", enemy._hitbox.monitoring == false)
	# the corpse flops over for ~0.75 s before vanishing
	for i in 90:
		await process_frame
		if not enemy.is_visible_in_tree():
			break
	_check("enemy hidden after death flop", not enemy.is_visible_in_tree())

	# --- Scenario 5: i-frames expire over time
	tito._invuln = 0.6
	var expired := false
	for i in 90:
		await process_frame
		if tito._invuln <= 0.0:
			expired = true
			break
	_check("i-frames expire over time", expired)

	print("RESULT failures=", fails)
	quit(1 if fails > 0 else 0)

func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		fails += 1

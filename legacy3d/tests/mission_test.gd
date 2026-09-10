## Full Mission 1 playthrough test (headless): pillars, crawl, rope, combat,
## enemy AI states, checkpoint respawn, mission completion.
extends Node

var fails: PackedStringArray = []
var tito: CharacterBody3D
var world: Node


func _ready() -> void:
	var packed: PackedScene = load("res://levels/mission1.tscn")
	if packed == null:
		print("FAIL  could not load mission1")
		_finish()
		return
	world = packed.instantiate()
	add_child(world)
	await _frames(5)

	tito = world.get_node_or_null("Tito") as CharacterBody3D
	_check("player exists", tito != null)
	_check("3 enemies exist", world.get_node_or_null("Enemy1") != null \
		and world.get_node_or_null("Enemy2") != null \
		and world.get_node_or_null("Enemy3") != null)
	_check("rope exists", world.get_node_or_null("Rope") != null)
	if tito == null:
		_finish()
		return

	await _frames(15)
	_check("on floor at start", tito.is_on_floor())
	_check("z locked at start", absf(tito.global_position.z) < 0.001)

	# ---- 1. pillar jumps over the death pit (pillars at 25.5 / 29.5 / 33.5)
	_teleport(21.0, 1.0)
	await _frames(15)
	await _pillar_hop()
	_dbg("after pillars")
	_check("crossed pillars to GroundD", tito.global_position.x > 34.0 and tito.global_position.y > -1.0)

	# ---- 2. crawl under the low ceiling (x 46..54, gap 1.0m, crawl 2.5m/s)
	_teleport(45.5, 1.75)
	await _frames(15)
	Input.action_press("crawl")
	Input.action_press("move_right")
	var saw_crouch := false
	var passed_under := false
	for i in 400:
		await _frames(1)
		if tito.get("state") == 1:
			saw_crouch = true
		var cx := tito.global_position.x
		if cx > 46.5 and cx < 53.5:
			passed_under = true
		if cx > 54.5:
			break
	_check("crouch state active", saw_crouch)
	_check("crawled under the ceiling", passed_under)
	Input.action_release("move_right")
	Input.action_release("crawl")
	_teleport(56.0, 1.75)
	await _frames(10)
	_dbg("released crawl")
	_check("stands back up after crawl", tito.get("state") == 0)  # State.NORMAL

	# ---- 3. rope climb (x=57, top clamp ~7.65)
	_teleport(57.0, 1.75)
	await _frames(15)
	Input.action_press("climb_up")
	# Climb until the top clamp stops us (y ~7.65), max 5 s.
	for i in 600:
		await _frames(1)
		if tito.global_position.y >= 7.6:
			break
	_dbg("climb done")
	_check("grabbed the rope (CLIMB)", tito.get("state") == 2)  # State.CLIMB
	var y_before := tito.global_position.y
	_check("climbed to rope top", y_before > 6.5)

	# ---- 4. leap off the rope top onto the tower (x 58..62, top 6.75)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")
	Input.action_release("move_right")
	Input.action_release("climb_up")
	await _frames(120)
	_dbg("after rope leap")
	var on_tower := tito.global_position.x > 57.5 and tito.global_position.x < 63.0 \
		and tito.global_position.y > 6.0
	_check("landed on the tower after rope leap", on_tower)

	# ---- 5. down the stairs to the arena
	Input.action_press("move_right")
	await _frames(180)
	Input.action_release("move_right")
	await _frames(10)
	_dbg("after stairs")
	_check("descended into the arena", tito.global_position.x > 66.0 and tito.is_on_floor())

	# ---- 6. combat (deterministic probe): park an enemy in front of Tito and
	# force one swing programmatically — no input-timing flakiness.
	var enemy2 := world.get_node_or_null("Enemy2")
	var hp0: int = enemy2.get_node("Health").hp
	_teleport(71.0, 2.75)
	enemy2.global_position = Vector3(72.1, 2.75, 0)
	enemy2.velocity = Vector3.ZERO
	await _frames(12)   # settle both on the floor
	tito.set("facing", 1)
	tito.call("_start_swing")
	var overlap_seen := false
	for i in 30:
		await _frames(1)
		var hb: Area3D = tito.get_node("Model/HitBox")
		if hb.monitoring and hb.get_overlapping_areas().size() > 0:
			overlap_seen = true
	var hp1: int = enemy2.get_node("Health").hp
	print("DBG   probe: hp %d->%d overlap_seen=%s enemy_state=%s" % [hp0, hp1, str(overlap_seen), str(enemy2.get("state"))])
	_check("punch damaged the enemy (%d -> %d)" % [hp0, hp1], hp1 < hp0)
	_check("hitbox physically overlapped the enemy", overlap_seen)

	# ---- 7. enemy AI: Enemy3 spots and chases, then loses and returns to patrol
	var enemy3 := world.get_node_or_null("Enemy3")
	_teleport(76.0, 2.75)
	await _frames(15)
	var spotted := false
	for i in 100:
		await _frames(5)
		if enemy3.get("state") in [1, 3]:  # CHASE or ATTACK
			spotted = true
			break
	_check("enemy spotted and chased player", spotted)
	# retreat far away -> enemy loses sight, searches, returns to patrol
	_teleport(43.0, 1.75)
	var returned := false
	var last_state := -1
	for i in 240:
		await _frames(5)
		var st := int(enemy3.get("state"))
		if st != last_state:
			print("DBG   enemy3 state=%s x=%.1f (t+%d)" % [str(st), enemy3.global_position.x, i * 5])
			last_state = st
		if st == 0:  # PATROL
			returned = true
			break
	_check("enemy gave up and returned to patrol", returned)

	# ---- 8. checkpoint: touch CP2, then fall out -> respawn at CP2
	_teleport(55.0, 1.75)
	await _frames(15)
	tito.fell_out()
	await _frames(15)
	_dbg("after checkpoint respawn")
	_check("respawned at checkpoint CP2", absf(tito.global_position.x - 55.0) < 2.0)

	# ---- 9. mission end
	_teleport(83.0, 2.75)
	await _frames(15)
	_check("mission completed", tito.get("mission_complete") == true)
	_check("z locked at end", absf(tito.global_position.z) < 0.001)

	_finish()


# ------------------------------------------------------------- helpers ----
func _pillar_hop() -> void:
	## Hold right and tap jump every ~0.3 s while grounded. Periodic hops clear
	## both the 0.75 m step-up at the pit edge and the 2 m gaps between pillars.
	Input.action_press("move_right")
	var deadline := 900
	var since_jump := 0
	while deadline > 0:
		deadline -= 1
		since_jump += 1
		await _frames(1)
		if tito.global_position.y < -5.0:
			break  # fell into the pit
		if tito.global_position.x > 34.6 and tito.is_on_floor():
			break  # reached GroundD
		if tito.is_on_floor() and since_jump > 18:
			Input.action_press("jump")
			await _frames(20)  # hold: a released jump gets cut to ~half height
			Input.action_release("jump")
			since_jump = 0
	Input.action_release("move_right")
	await _frames(15)


func _approach_x(target_x: float, stop_dist: float, max_iters: int) -> void:
	for i in max_iters:
		var dx := target_x - tito.global_position.x
		if absf(dx) <= stop_dist:
			break
		if dx > 0:
			Input.action_press("move_right")
			Input.action_release("move_left")
		else:
			Input.action_press("move_left")
			Input.action_release("move_right")
		await _frames(2)
	Input.action_release("move_right")
	Input.action_release("move_left")
	await _frames(3)


func _teleport(x: float, y: float) -> void:
	## y = body origin. Feet are at y - 0.9, so pass surface_top + 1.0 to land just above.
	tito.global_position = Vector3(x, y, 0)
	tito.velocity = Vector3.ZERO


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _dbg(label: String) -> void:
	print("DBG   %s x=%.1f y=%.2f state=%s floor=%s" % [label, tito.global_position.x, tito.global_position.y, str(tito.get("state")), str(tito.is_on_floor())])


func _check(test_name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + test_name)
	if not ok:
		fails.append(test_name)


func _finish() -> void:
	print("RESULT: %d failure(s)" % fails.size())
	get_tree().quit(0 if fails.is_empty() else 1)

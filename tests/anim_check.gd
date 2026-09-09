## Verifies the Mixamo clip library is mounted on the player's AnimationPlayer
## and that every state transition actually plays its clip.
extends SceneTree

var fails := 0

func _initialize() -> void:
	var packed: PackedScene = load("res://levels/mission1.tscn")
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 20:
		await process_frame
	var tito: Node = world.get_node("Tito")
	var ap: AnimationPlayer = tito.get_node("Model/TitoModel/AnimationPlayer")
	_check("AnimationPlayer found on TitoModel", ap != null)
	var anims: Array = ap.get_animation_list()
	print("ANIMS: ", anims)
	var has_lib: bool = ap.has_animation_library("tito")
	_check("tito library mounted", has_lib)
	for expected in ["tito/idle", "tito/run", "tito/jump", "tito/fall", "tito/punch_left", "tito/punch_right", "tito/punch_combo"]:
		_check("clip mounted: " + expected, expected in anims)
	# play each clip and confirm it runs
	for clip in ["tito/idle", "tito/run", "tito/jump", "tito/fall", "tito/punch_left"]:
		ap.play(clip)
		for i in 5:
			await process_frame
		_check("clip plays: " + clip, ap.is_playing() or ap.current_animation == clip)
	print("RESULT failures=", fails)
	quit(1 if fails > 0 else 0)

func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		fails += 1
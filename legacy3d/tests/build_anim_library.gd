## Merge Mixamo FBX clips (same 67-bone skeleton) into one AnimationLibrary.
## Each FBX instantiates root -> Armature -> Skeleton3D(with bones) -> meshes,
## with an AnimationPlayer carrying a single track named "mixamo_com".
## We pull Skeleton3D (root motion removed: bones are named with ':' prefix).
extends SceneTree

func _initialize() -> void:
	var clips := {
		"idle": "res://assets/models/TITO/Breathing Idle.fbx",
		"fall": "res://assets/models/TITO/Falling To Landing.fbx",
		"jump": "res://assets/models/TITO/Jumping.fbx",
		"punch_combo": "res://assets/models/TITO/Punch Combo.fbx",
		"run": "res://assets/models/TITO/Running.fbx",
		"punch_left": "res://assets/models/TITO/left Punching.fbx",
		"punch_right": "res://assets/models/TITO/right Punching.fbx",
	}

	var lib := AnimationLibrary.new()
	for clip_name in clips:
		var path: String = clips[clip_name]
		var packed: PackedScene = load(path)
		if packed == null:
			print("LOAD FAIL  ", clip_name)
			continue
		var root: Node = packed.instantiate()
		get_root().add_child(root)
		var ap: AnimationPlayer = _find_animation_player(root)
		if ap == null:
			print("NO PLAYER  ", clip_name)
			root.queue_free()
			continue
		var source: Animation = ap.get_animation("mixamo_com")
		var anim: Animation = source.duplicate(true)

		# Convert Mixamo root motion to IN-PLACE. Track 0 is the position track
		# for mixamorig_Hips. Keeping its first value preserves the imported rest
		# height while removing forward/down translation that makes the mesh sink
		# through the CharacterBody3D collider and snap back every loop.
		for track_index in anim.get_track_count():
			var track_path: String = String(anim.track_get_path(track_index))
			if anim.track_get_type(track_index) == Animation.TYPE_POSITION_3D \
				and track_path.ends_with(":mixamorig_Hips"):
				var base_position: Vector3 = anim.track_get_key_value(track_index, 0)
				for key_index in anim.track_get_key_count(track_index):
					anim.track_set_key_value(track_index, key_index, base_position)

		# Loop ONLY continuous locomotion. Every action clip is a one-shot.
		if clip_name in ["idle", "run"]:
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE
		lib.add_animation(clip_name, anim)
		print("ADDED ", clip_name, " length=%.2f loop=%d in_place=true" % [anim.length, anim.loop_mode])
		root.queue_free()

	# Save the merged library to disk.
	var err: int = ResourceSaver.save(lib, "res://assets/models/TITO/anim_library.res")
	print("SAVE ", "OK" if err == OK else ("ERR " + str(err)))
	quit(0)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r: AnimationPlayer = _find_animation_player(c)
		if r != null:
			return r
	return null
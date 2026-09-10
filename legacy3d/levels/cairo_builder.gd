## Downtown Cairo at night ("وسط البلد") — builds the whole level from code:
## painterly parallax backdrops (Prince of Persia style), khedivial facades,
## neon Arabic signage, street slabs + rooftop parkour, lamps with warm pools
## of light, and the enemies/checkpoints wired for the smart-AI showcase.
##
## Conventions: the playfield is the X/Y plane at z=0; the camera sits at
## z=+14 looking down -z. Building boxes live z-4..0 so their roofs are
## walkable at the player's plane; facade ART quads sit at z=+0.01..0.03.
extends Node3D

const TEX := "res://assets/textures/cairo/"
const FONT_BOLD := "res://assets/fonts/DejaVuSans-Bold.ttf"
const ENEMY: PackedScene = preload("res://legacy3d/enemies/enemy.tscn")
const ROPE: PackedScene = preload("res://legacy3d/world/rope.tscn")
const CHECKPOINT: PackedScene = preload("res://legacy3d/world/checkpoint.tscn")
const ENDZONE: PackedScene = preload("res://legacy3d/world/endzone.tscn")
const DEATHZONE: PackedScene = preload("res://legacy3d/world/deathzone.tscn")
const TITO: PackedScene = preload("res://legacy3d/player/tito.tscn")
const PARALLAX := preload("res://legacy3d/world/parallax_layer.gd")

var _mats: Dictionary = {}


func _ready() -> void:
	_build_materials()
	_build_environment()
	_build_parallax_backdrop()
	_build_street()
	_build_buildings()
	_build_props()
	_build_gameplay()
	_build_labels()


# ------------------------------------------------------------ materials --
func _std(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _tex_mat(path: String, unshaded := false, alpha := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path) as Texture2D
	m.roughness = 1.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# backdrop quads are sometimes mirrored; both faces must render
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _build_materials() -> void:
	_mats["wall"] = _std(Color(0.145, 0.16, 0.25))       # building bodies (moon-lit)
	_mats["wall2"] = _std(Color(0.11, 0.12, 0.20))       # shopfront band
	_mats["roof"] = _std(Color(0.09, 0.11, 0.19))        # walkable roof tops
	_mats["prop"] = _std(Color(0.065, 0.075, 0.14))      # tanks, ACs, bins
	_mats["ledge"] = _std(Color(0.19, 0.20, 0.32))       # balcony ledges
	_mats["dark"] = _std(Color(0.035, 0.04, 0.08))       # pit guts, silhouettes
	_mats["street"] = _tex_mat(TEX + "street_top.png")
	_mats["sidewalk"] = _tex_mat(TEX + "sidewalk.png")
	_mats["facade"] = _tex_mat(TEX + "facade_hero.png", true)
	_mats["sky"] = _tex_mat(TEX + "sky.png", true)
	_mats["far"] = _tex_mat(TEX + "skyline_far.png", true, true)
	_mats["mid"] = _tex_mat(TEX + "skyline_mid.png", true, true)
	_mats["palm"] = _tex_mat(TEX + "palm_frond.png", true, true)
	_mats["qahwa"] = _tex_mat(TEX + "sign_qahwa.png", true, true)
	_mats["radio"] = _tex_mat(TEX + "sign_radio.png", true, true)
	_mats["metro"] = _tex_mat(TEX + "sign_metro.png", true, true)
	_mats["funduq"] = _tex_mat(TEX + "sign_funduq.png", true, true)
	var lamp := StandardMaterial3D.new()
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color = Color(1.0, 0.78, 0.42)
	_mats["lamp_head"] = lamp


# ------------------------------------------------------ environment etc. --
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0x0a / 255.0, 0x12 / 255.0, 0x24 / 255.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0x30 / 255.0, 0x3a / 255.0, 0x68 / 255.0)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.010
	env.fog_light_color = Color(0x16 / 255.0, 0x1e / 255.0, 0x42 / 255.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# cool moonlight raking across the rooftops
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0x8f / 255.0, 0x9b / 255.0, 0xde / 255.0)
	moon.light_energy = 0.75
	moon.rotation = Vector3(-0.65, 0.55, 0.0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 80.0
	add_child(moon)


# -------------------------------------------------- parallax backdrop ----
func _parallax(stick: float, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.set_script(PARALLAX)
	p.set("stick", stick)
	p.position = pos
	add_child(p)
	return p


func _quad_mesh(mat: Material, w: float, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	mi.material_override = mat
	return mi


func _quad(parent: Node3D, mat: Material, x: float, y: float, w: float, h: float, z: float, flip_x := false) -> MeshInstance3D:
	var mi := _quad_mesh(mat, w, h)
	mi.position = Vector3(x, y, z)
	if flip_x:
		mi.scale.x = -1.0
	parent.add_child(mi)
	return mi


func _build_parallax_backdrop() -> void:
	# painted sky with the low glowing moon (almost camera-locked)
	var sky := _parallax(0.93, Vector3(55.0, 40.0, -60.0))
	_quad(sky, _mats["sky"], 0.0, 0.0, 230.0, 118.0, 0.0)

	# far silhouette: citadel + minarets skyline band (two tiles, one flipped)
	var far := _parallax(0.72, Vector3(55.0, 13.9, -44.0))
	_quad(far, _mats["far"], -80.0, 0.0, 170.0, 31.9, 0.0)
	_quad(far, _mats["far"], 80.0, 0.0, 170.0, 31.9, 0.0, true)

	# mid silhouette: rooftop jungle with tanks, dishes, warm windows
	var mid := _parallax(0.50, Vector3(55.0, 12.2, -27.0))
	_quad(mid, _mats["mid"], -61.0, 0.0, 130.0, 28.4, 0.0)
	_quad(mid, _mats["mid"], 61.0, 0.0, 130.0, 28.4, 0.0, true)

	# foreground palm fronds sweeping past the camera (Lost Crown flourish)
	for spot in [Vector2(-2.0, 7.5), Vector2(62.5, 8.5), Vector2(108.0, 7.0)]:
		var fg := _parallax(1.3, Vector3(spot.x, spot.y, 6.5))
		_quad(fg, _mats["palm"], 0.0, 0.0, 9.0, 9.0, 0.0)


# ------------------------------------------------------------ geometry ----
## Box spanning x0..x1 whose TOP face is at `top`. zc/d = playfield depth.
func _slab(x0: float, x1: float, top: float, h: float, d: float, mat: Material, zc := 0.0) -> StaticBody3D:
	var w := x1 - x0
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, h, d)
	cs.shape = shape
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, h, d)
	mi.mesh = mesh
	mi.material_override = mat
	b.add_child(mi)
	b.position = Vector3((x0 + x1) * 0.5, top - h * 0.5, zc)
	add_child(b)
	return b


const STREET_RUNS := [[-8.0, 20.0], [22.6, 56.6], [59.0, 74.0], [77.5, 118.0]]

func _build_street() -> void:
	for run in STREET_RUNS:
		var x0: float = run[0]
		var x1: float = run[1]
		_slab(x0, x1, 0.0, 1.0, 4.0, _mats["street"])                    # asphalt (walkable)
		_slab(x0, x1, 0.07, 0.14, 1.7, _mats["sidewalk"], -1.15)         # sidewalk strip
		_slab(x0, x1, -0.30, 0.14, 2.4, _mats["street"], 3.1)            # road band (front)
	# pit guts (visual floor far below; the deathzone does the real work)
	_slab(19.4, 23.2, -2.2, 0.3, 4.0, _mats["dark"])
	_slab(56.2, 59.4, -2.2, 0.3, 4.0, _mats["dark"])
	_slab(73.6, 77.9, -2.2, 0.3, 4.0, _mats["dark"])


## building body: walkable roof at `top`, body spans z-4..0 (front face ~z0,
## always BEHIND the player's plane so it never occludes the action)
func _building(x0: float, x1: float, top: float, depth_zc := -2.0) -> void:
	_slab(x0, x1, top, top + 2.0, 4.0, _mats["roof"], depth_zc)
	# back parapet lip so the roofline reads as a roof
	_slab(x0, x1, top + 0.55, 0.55, 0.3, _mats["prop"], depth_zc - 1.85)


func _build_buildings() -> void:
	# --- plaza backdrop: hero khedivial facades rising behind the shop strip
	_building(-8.0, 20.0, 2.4)                       # plaza shop-strip roof (walkable)
	for i in 3:
		var cx := -3.5 + i * 7.0
		_quad(self, _mats["facade"], cx, 2.4 + 3.025, 7.0, 6.05, -2.35)
	# kiosk step onto the plaza roofs + a plank bridging the first pit
	_slab(17.0, 18.3, 1.2, 0.35, 1.2, _mats["prop"], 0.3)
	_slab(22.9, 23.9, 2.4, 0.25, 1.1, _mats["ledge"], 0.2)

	# --- shops row A (walkable low roofs) with قهوة corner
	_building(26.0, 40.0, 2.4)
	# awning step to hop onto the roofs
	_slab(24.4, 26.0, 1.3, 0.3, 1.2, _mats["ledge"], 0.4)

	# --- the METRO cinema block
	_building(44.0, 58.0, 5.4)
	_quad(self, _mats["metro"], 47.0, 4.35, 6.2, 2.23, 0.03)
	_slab(42.8, 45.2, 3.7, 0.3, 1.2, _mats["ledge"], 0.5)   # marquee canopy (jumpable)
	_slab(40.4, 41.4, 3.0, 0.3, 1.0, _mats["ledge"], 0.4)   # hanging banner step
	_slab(45.4, 46.2, 4.6, 0.3, 1.0, _mats["ledge"], 0.4)   # sign bracket step

	# --- mid-rise roofs (parkour band)
	_building(60.0, 72.0, 4.2)
	_building(72.0, 84.0, 6.4)
	# climbset: kiosk -> ledges -> roof A
	_slab(57.6, 59.4, 1.5, 0.3, 1.2, _mats["prop"], 0.4)
	_slab(59.8, 60.7, 2.5, 0.25, 1.0, _mats["ledge"], 0.35)
	_slab(61.0, 62.0, 3.4, 0.25, 1.0, _mats["ledge"], 0.35)
	# roof A helper stack toward roof B
	_slab(69.6, 70.6, 5.2, 0.8, 1.4, _mats["prop"], -0.6)
	_slab(83.6, 84.4, 7.3, 0.25, 1.0, _mats["ledge"], 0.35)  # roof B exit lip

	# --- the khedivial tower finale (hero facade x2) with the balcony climb
	_building(92.0, 106.0, 8.45)
	_quad(self, _mats["facade"], 95.5, 5.425, 7.0, 6.05, 0.02)
	_quad(self, _mats["facade"], 102.5, 5.425, 7.0, 6.05, 0.02, true)
	var ledges := [
		[92.9, 94.5, 1.2], [96.0, 97.6, 2.5], [99.1, 100.7, 3.8],
		[102.2, 103.8, 5.15], [104.0, 105.6, 6.5], [101.8, 103.0, 7.55],
	]
	for l in ledges:
		_slab(l[0], l[1], l[2], 0.32, 1.1, _mats["ledge"], 0.35)
	# radio mast crowning the roof
	_slab(94.0, 95.0, 11.4, 3.0, 0.4, _mats["prop"], -1.2)

	# --- a lone minaret silhouette at the plaza's back edge (landmark)
	var mz := -9.0
	_slab(-14.5, -11.5, 4.0, 6.0, 3.0, _mats["dark"], mz)
	_slab(-13.6, -12.4, 12.0, 12.0, 1.2, _mats["dark"], mz)
	_slab(-14.1, -11.9, 12.7, 0.7, 1.7, _mats["dark"], mz)
	_slab(-13.5, -12.5, 14.6, 1.9, 1.0, _mats["dark"], mz)
	var cone := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.45
	cone_mesh.height = 2.2
	cone.mesh = cone_mesh
	cone.material_override = _mats["dark"]
	cone.position = Vector3(-13.0, 15.7, mz)
	add_child(cone)

	# shopfront band + signs along the whole street (dressing, non-climbable)
	var bands := [[22.6, 44.0], [48.0, 56.6], [59.0, 74.0], [77.5, 92.0], [106.0, 118.0]]
	for band in bands:
		_slab(band[0], band[1], 2.4, 2.4, 0.5, _mats["wall2"], -1.7)
	# awnings + doorways accents
	for ax in [25.0, 31.0, 37.0, 52.0, 62.5, 68.5, 82.0, 88.0, 110.0, 115.0]:
		_slab(ax, ax + 2.2, 2.05, 0.22, 1.1, _mats["ledge"], -1.05)
	_quad(self, _mats["qahwa"], 28.0, 3.05, 4.4, 1.38, -0.01)
	_quad(self, _mats["radio"], 66.0, 3.05, 4.4, 1.38, -0.01)
	_quad(self, _mats["funduq"], 115.0, 2.85, 5.8, 1.21, -0.01)


# ---------------------------------------------------------------- props ---
func _lamp(x: float, real_light: bool) -> void:
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.09
	pm.height = 4.6
	post.mesh = pm
	post.material_override = _mats["prop"]
	post.position = Vector3(x, 2.3, -1.2)
	add_child(post)
	_slab(x, x + 0.9, 4.62, 0.12, 0.12, _mats["prop"], -0.75)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.18
	hs.height = 0.36
	head.mesh = hs
	head.material_override = _mats["lamp_head"]
	head.position = Vector3(x + 0.9, 4.45, -0.75)
	add_child(head)
	if real_light:
		var omni := OmniLight3D.new()
		omni.light_color = Color(1.0, 0.72, 0.38)
		omni.light_energy = 1.2
		omni.omni_range = 8.0
		omni.omni_attenuation = 1.1
		omni.position = Vector3(x + 0.9, 4.3, -0.75)
		add_child(omni)


func _build_props() -> void:
	# a few REAL lights; the rest are emissive-only heads (GL-compat budget)
	_lamp(8.0, true)
	_lamp(18.0, false)
	_lamp(30.0, true)
	_lamp(40.5, false)
	_lamp(52.0, true)
	_lamp(64.0, false)
	_lamp(79.0, true)
	_lamp(88.0, false)
	_lamp(100.0, true)
	_lamp(110.0, false)
	# bus stop shelter (roof is a sneaky platform)
	_slab(63.0, 63.2, 2.55, 2.55, 0.3, _mats["prop"], -0.9)
	_slab(67.2, 67.4, 2.55, 2.55, 0.3, _mats["prop"], -0.9)
	_slab(62.8, 67.6, 2.8, 0.22, 1.5, _mats["ledge"], -0.85)
	# rooftop clutter: water tanks + AC units + a clothesline pole
	_slab(48.0, 49.2, 6.6, 1.2, 1.3, _mats["prop"], -0.8)
	_slab(52.0, 52.9, 5.9, 0.5, 0.9, _mats["prop"], -0.5)
	_slab(64.0, 65.1, 5.4, 1.2, 1.3, _mats["prop"], -0.8)
	_slab(74.0, 74.9, 6.9, 0.5, 0.9, _mats["prop"], -0.5)
	_slab(79.0, 80.1, 7.6, 1.2, 1.3, _mats["prop"], -0.8)
	# bins on the pavement
	for bx in [12.5, 34.5, 54.0, 71.0, 90.5, 108.5]:
		_slab(bx, bx + 0.7, 0.7, 0.7, 0.7, _mats["prop"], -0.75)


# ------------------------------------------------------------- gameplay ---
func _spawn_enemy(x: float, y_surface: float, min_x: float, max_x: float, tint: Color, aggr := 1.0) -> void:
	var e := ENEMY.instantiate()
	e.set("patrol_min_x", min_x)
	e.set("patrol_max_x", max_x)
	e.set("base_tint", tint)
	e.set("aggression", aggr)
	e.position = Vector3(x, y_surface + 0.9, 0.0)  # set BEFORE add_child: _ready caches the spawn
	add_child(e)


func _spawn_scene(scene: PackedScene, pos: Vector3, props := {}) -> Node3D:
	var n := scene.instantiate()
	for k in props.keys():
		n.set(k, props[k])
	n.position = pos  # set BEFORE add_child: _ready caches initial state
	add_child(n)
	return n


func _build_gameplay() -> void:
	# the hero
	var tito := TITO.instantiate()
	tito.position = Vector3(2.0, 1.2, 0.0)  # BEFORE add_child (spawn cache)
	add_child(tito)

	# checkpoints: plaza -> cinema roof -> before the tower climb
	_spawn_scene(CHECKPOINT, Vector3(14.0, 0.75, 0.0))
	_spawn_scene(CHECKPOINT, Vector3(46.5, 6.15, 0.0))
	_spawn_scene(CHECKPOINT, Vector3(91.6, 0.75, 0.0))

	# rope up the cinema wall (alternative to the marquee parkour)
	_spawn_scene(ROPE, Vector3(43.2, 0.0, 0.0), {"top_y": 5.4})

	# pit deathzones (two per pit: the whole gap is lethal, no safe corners)
	for dx in [20.8, 22.2, 57.3, 58.6, 75.2, 76.6]:
		_spawn_scene(DEATHZONE, Vector3(dx, -1.2, 0.0))

	# mission exit: the tower rooftop under the moon
	_spawn_scene(ENDZONE, Vector3(103.8, 8.5, 0.0))

	# street thugs (dark navy tint; the finale guard is feisty)
	var thug := Color(0.20, 0.24, 0.40)
	_spawn_enemy(30.0, 0.0, 24.0, 37.0, thug)
	_spawn_enemy(33.0, 2.4, 27.0, 39.0, thug)
	_spawn_enemy(68.0, 0.0, 62.0, 73.0, thug)
	_spawn_enemy(52.0, 5.4, 45.0, 57.0, thug)
	_spawn_enemy(96.0, 0.0, 92.5, 104.0, thug, 1.15)


# ---------------------------------------------------------------- labels --
var _controls_label: Label3D


func _label(text: String, pos: Vector3, size: int, tint: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load(FONT_BOLD) as Font
	l.font_size = size
	l.modulate = tint
	l.outline_size = max(8, size / 8)
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = pos
	add_child(l)
	return l


func _apply_controls_text(device: String) -> void:
	if _controls_label == null:
		return
	match device:
		"xbox", "switch", "steamdeck", "generic":
			_controls_label.text = "LEFT STICK / D-PAD move · A jump · B or STICK DOWN crawl · X punch"
		"playstation":
			_controls_label.text = "LEFT STICK move · CROSS jump · CIRCLE or STICK DOWN crawl · SQUARE punch"
		_:
			_controls_label.text = "A/D move · SPACE jump · CTRL crawl · W/S rope · J punch"


func _setup_device_hints() -> void:
	var ih: Node = get_node_or_null("/root/InputHelper")
	if ih == null:
		return
	ih.device_changed.connect(func(d: String, _i: int) -> void: _apply_controls_text(d))
	_apply_controls_text(str(ih.get("device")))


func _build_labels() -> void:
	_label("وسط البلد — القاهرة", Vector3(4.0, 3.4, -0.6), 128, Color(1.0, 0.85, 0.55))
	_label("منتصف الليل · ليلة الهروب", Vector3(4.0, 2.5, -0.6), 56, Color(0.75, 0.85, 1.0))
	_controls_label = _label("A/D move · SPACE jump · CTRL crawl · W/S rope · J punch", \
		Vector3(4.0, 1.9, -0.6), 40, Color(0.6, 0.65, 0.8))
	_setup_device_hints()

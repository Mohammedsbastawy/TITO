## BOOT — 2D smoke-test yard (also tests2d smoke scene): ground, one-way
## steps, a slide-gap bar, a wall-jump shaft with a demo ladder, checkpoint
## + hazard showcase, 3 parallax layers from the cairo art, CanvasModulate
## night grade + PointLight2D lamps. All geometry is code-built (same
## builder philosophy as the legacy 3D levels).
extends Node2D

const CAIRO := "res://assets/textures/cairo/"
const FONT_BOLD := "res://assets/fonts/DejaVuSans-Bold.ttf"
const LIGHT_DOT := "res://assets2d/fx/light_dot.png"

const GROUND_Y := 600.0
const WORLD_L := -64.0
const WORLD_R := 1624.0

var _hints: Array = []


func _ready() -> void:
	_build_parallax()
	_build_lighting()
	_build_geometry()
	_build_gameplay()
	_build_prompts()


# ------------------------------------------------------- parallax layers --
func _tex_sprite(path: String, scale_f: float, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path) as Texture2D
	s.scale = Vector2.ONE * scale_f
	s.centered = false
	s.position = pos
	return s


func _build_parallax() -> void:
	var bg := ParallaxBackground.new()
	add_child(bg)
	var l1 := ParallaxLayer.new()
	l1.motion_scale = Vector2(0.04, 1.0)
	l1.motion_mirroring = Vector2(1024, 0)
	l1.add_child(_tex_sprite(CAIRO + "sky.png", 2.0, Vector2(-900, -420)))
	bg.add_child(l1)
	var l2 := ParallaxLayer.new()
	l2.motion_scale = Vector2(0.16, 1.0)
	l2.motion_mirroring = Vector2(544, 0)
	l2.add_child(_tex_sprite(CAIRO + "skyline_far.png", 1.6, Vector2(-900, 44)))
	bg.add_child(l2)
	var l3 := ParallaxLayer.new()
	l3.motion_scale = Vector2(0.34, 1.0)
	l3.motion_mirroring = Vector2(416, 0)
	l3.add_child(_tex_sprite(CAIRO + "skyline_mid.png", 1.3, Vector2(-900, 190)))
	bg.add_child(l3)


# ------------------------------------------------------------- lighting ---
func _lamp(x: float) -> void:
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([
		Vector2(-3, 0), Vector2(3, 0), Vector2(3, -180), Vector2(14, -180),
		Vector2(14, -171), Vector2(3, -171), Vector2(-3, -171),
	])
	post.color = Color(0.10, 0.11, 0.16)
	post.position = Vector2(x, GROUND_Y)
	add_child(post)
	var light := PointLight2D.new()
	light.texture = load(LIGHT_DOT) as Texture2D
	light.color = Color(1.0, 0.78, 0.45)
	light.energy = 1.7
	light.texture_scale = 4.2
	light.position = Vector2(x + 13, GROUND_Y - 168)
	add_child(light)


func _build_lighting() -> void:
	var grade := CanvasModulate.new()
	grade.color = Color(0.42, 0.48, 0.72)  # deep asphalt-blue night
	add_child(grade)
	_lamp(140.0)
	_lamp(700.0)
	_lamp(1300.0)


# ------------------------------------------------------------- geometry ---
func _poly(parent: Node, pts: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	parent.add_child(p)
	return p


## Solid box: (x, top) to (x+w, top+h). Visual polygon + StaticBody2D.
func _box2d(x: float, top: float, w: float, h: float, color: Color,
		one_way := false) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	cs.one_way_collision = one_way
	cs.position = Vector2(x + w * 0.5, top + h * 0.5)
	b.add_child(cs)
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(x, top), Vector2(x + w, top), Vector2(x + w, top + h), Vector2(x, top + h)])
	p.color = color
	add_child(p)
	add_child(b)
	return b


func _build_geometry() -> void:
	var asphalt := Color(0.13, 0.15, 0.24)
	var curb := Color(0.18, 0.2, 0.3)
	var brick := Color(0.24, 0.2, 0.26)
	var metal := Color(0.2, 0.22, 0.3)
	# street slab + curb lip + front road band
	_box2d(WORLD_L, GROUND_Y, WORLD_R - WORLD_L, 120.0, asphalt)
	_box2d(WORLD_L, GROUND_Y - 8.0, WORLD_R - WORLD_L, 8.0, curb)
	# world-end walls
	_box2d(WORLD_L - 32.0, 120.0, 32.0, 480.0, brick)
	_box2d(WORLD_R, 120.0, 32.0, 480.0, brick)
	# one-way practice steps
	_box2d(400.0, 500.0, 140.0, 12.0, metal, true)
	_box2d(580.0, 448.0, 140.0, 12.0, metal, true)
	# SLIDE GAP: roller-shutter bar; opening is 34 px — slide (30) only
	_box2d(820.0, 486.0, 110.0, 80.0, brick)  # masonry frame
	_box2d(820.0, 566.0, 110.0, 8.0, Color(0.75, 0.2, 0.15))  # hazard lip
	for i in 3:  # shutter slats
		_poly(self, PackedVector2Array([
			Vector2(822.0, 492.0 + i * 22.0), Vector2(928.0, 492.0 + i * 22.0),
			Vector2(928.0, 500.0 + i * 22.0), Vector2(822.0, 500.0 + i * 22.0),
		]), Color(0.28, 0.3, 0.38))
	# WALL-JUMP SHAFT: two towers, 70 px gap between them
	_box2d(1080.0, 340.0, 30.0, 260.0, brick)
	_box2d(1180.0, 340.0, 30.0, 260.0, brick)
	# exit ledge atop the left tower
	_box2d(960.0, 334.0, 120.0, 12.0, metal, true)
	# decorative AC box on the shaft roof
	_poly(self, PackedVector2Array([
		Vector2(1094.0, 340.0), Vector2(1140.0, 340.0),
		Vector2(1140.0, 312.0), Vector2(1094.0, 312.0),
	]), Color(0.16, 0.17, 0.22))


# ------------------------------------------------------------- gameplay ---
func _build_gameplay() -> void:
	var cp1 := Checkpoint2D.new()
	cp1.position = Vector2(700.0, GROUND_Y)
	add_child(cp1)
	var cp2 := Checkpoint2D.new()
	cp2.position = Vector2(1240.0, GROUND_Y)
	add_child(cp2)
	# hazard showcase strip (harmless-looking smoke pocket that ticks)
	var hz := HazardZone2D.new()
	hz.position = Vector2(760.0, GROUND_Y)
	hz.tint = Color(0.5, 0.55, 0.7, 0.35)
	add_child(hz)
	# demo ladder on the shaft's outer right face
	var ladder := Ladder2D.new()
	ladder.position = Vector2(1210.0, 470.0)
	var lcs := CollisionShape2D.new()
	var lrect := RectangleShape2D.new()
	lrect.size = Vector2(26, 260)
	lcs.shape = lrect
	ladder.add_child(lcs)
	for i in 7:
		_poly(ladder, PackedVector2Array([
			Vector2(-10, -120 + i * 40), Vector2(10, -120 + i * 40),
			Vector2(10, -114 + i * 40), Vector2(-10, -114 + i * 40),
		]), Color(0.5, 0.4, 0.25))
	add_child(ladder)

	# THE STAR
	var tito := Player2D.new()
	tito.position = Vector2(120.0, GROUND_Y)
	add_child(tito)
	var cam := TitoCamera2D.new()
	add_child(cam)
	cam.set_target(tito)
	cam.apply_zone_limits(Rect2(WORLD_L, 120.0, WORLD_R - WORLD_L, 592.0))
	# a soft hero glow so the silhouette pops out of the grade
	var hero_light := PointLight2D.new()
	hero_light.texture = load(LIGHT_DOT) as Texture2D
	hero_light.color = Color(0.7, 0.8, 1.0)
	hero_light.energy = 0.55
	hero_light.texture_scale = 1.6
	hero_light.position = Vector2(0, -34)
	tito.add_child(hero_light)


# -------------------------------------------------------------- prompts ---
func _hint(pos: Vector2, kb: String, pad: String, size := 22,
		tint := Color(0.85, 0.9, 1.0)) -> void:
	var lbl := Label2D.new()
	lbl.text = kb
	lbl.font = load(FONT_BOLD) as Font
	lbl.font_size = size
	lbl.modulate = tint
	lbl.position = pos
	add_child(lbl)
	_hints.append([lbl, kb, pad])


func _refresh_hints(device: String) -> void:
	var gamepad := device in ["xbox", "playstation", "switch", "steamdeck", "generic"]
	for h in _hints:
		(h[0] as Label2D).text = h[2] if gamepad else h[1]


func _build_prompts() -> void:
	_hint(Vector2(60, 260), "A/D حركة · مسافة قفز جري مستمر = عدوة",
		"عصا شمال حركة · A قفز · عدوة مستمرة = سبرنت")
	_hint(Vector2(395, 420), "المنصات الشفافة: اقفز من تحتها عادي", "")
	_hint(Vector2(800, 420), "زحلقة: SHIFT ثم اضغط ثانية · أو امسك زرار الزحلقة",
		"زحلقة: Shift+اتجاه · أو امسك RT")
	_hint(Vector2(1040, 240), "قفزة الحيطة: المس الحيطة في الهوا واضغط قفز", "")
	_hint(Vector2(60, 300), "ضرب خفيف: J (٣ ورا بعض) · تقيل: K · صدّ: L · دحرجة: Shift",
		"خفيف: X (٣) · تقيل: Y · صدّ: RB · دحرجة: B")
	_hint(Vector2(1265, 420), "السلّم: W/S أثناء اللمس · قفز للنزول", "")
	var ih: Node = get_node_or_null("/root/InputHelper")
	if ih != null:
		ih.device_changed.connect(func(d: String, _i: int) -> void: _refresh_hints(d))
		_refresh_hints(str(ih.get("device")))
	for h in _hints:
		if h[2] == "":
			(h[0] as Label2D).text = h[1]

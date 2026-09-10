## PROLOGUE 2D — "The Night It All Began" (ليلة البداية)
## Five tutorial zones across a storm-drowned street, then the Raven duel
## on a floodlit construction rooftop, then the rewind into Chapter 1.
## Everything is code-built (same philosophy as the rest of the project).
## Layout contract (px, GROUND_Y=600):
##   Z1   0..780    stagger intro -> wall-jump shaft -> slide shutter
##   Z2   780..1300 two staff tutors (parry lessons)
##   Z3   1300..1900 shield sentry w/ bounce sedan + cover van
##   Z4   1900..2900 smoke pockets + red-beam marksman -> canopy route
##   Z5   2900..3500 squad gauntlet -> gate breach
##   SC   3500..3780 scaffold zigzag up to the roof (y=280)
##   RF   3780..4750 girders y=200, floodlights, THE RAVEN x=4500
extends Node2D

const CAIRO := "res://assets/textures/cairo/"
const ENV := "res://assets2d/sprites/env/"
const FONT_BOLD := "res://assets/fonts/DejaVuSans-Bold.ttf"
const LIGHT_DOT := "res://assets2d/fx/light_dot.png"
const CHAPTER_ONE := "res://levels2d/chapter1/chapter1.tscn"

const GROUND_Y := 600.0
const ROOF_Y := 280.0
const WORLD_L := 0.0
const WORLD_R := 4780.0
const ARENA_MIN := 3850.0
const ARENA_MAX := 4650.0

const LINES_INTRO := [
	["الغراب", Color(0.95, 0.38, 0.22),
		"«فاكر إنك هتمشي بس كده؟ النظام ده هو اللي صنعك... وهو كمان اللي هينهيك.»",
		"You think you can just walk away? You were built by this system, and you end with it.", 6.0],
	["تيتو", Color(0.55, 0.85, 1.0),
		"«أنا اتحملت مسؤولية طريقي... دلوقتي دورك إنك تتحاسب على طريقك.»",
		"I took responsibility for my path... now you answer for yours.", 5.4],
]
const LINES_OUTRO := [
	["تيتو", Color(0.9, 0.9, 0.95),
		"«عشان تفهم النهاية... لازم ترجع لليوم اللي القصة بدأت فيه فعلًا.»",
		"To understand the ending... you have to return to where the story truly began.", 6.2],
]

var _player: Player2D
var _cam: TitoCamera2D
var _dialogue: DialogueLayer
var _boss: BossRaven2D
var _gate: StaticBody2D
var _gate_lamp: Polygon2D
var _squad_alive := 0
var _intro_done := false
var _outro_started := false
var _hints: Array = []
# outro overlay bits
var _white: ColorRect
var _black: ColorRect
var _ecg: Line2D
var _ecg_t := -1.0
var _ecg_vals: PackedFloat32Array = []
var _bolt_timer := 5.0
var _flash := 0.0
var _flash_rect: ColorRect
# boss bar
var _boss_ui: CanvasLayer
var _boss_fg: ColorRect


func _ready() -> void:
	_build_parallax()
	_build_lighting()
	_build_street()
	_build_zone1()
	_build_zone2()
	_build_zone3()
	_build_zone4()
	_build_zone5()
	_build_rooftop()
	_build_weather()
	_build_gameplay()
	# ambient life: dust, wind streaks, drifting paper — all ride the camera
	var fx := AmbientFx2D.new()
	add_child(fx)
	fx.follow = _cam
	_build_prompts()


# ================================================================= looks ==
func _tex_sprite(path: String, scale_f: float, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path) as Texture2D
	s.scale = Vector2.ONE * scale_f
	s.centered = false
	s.position = pos
	return s


var _cloud_layer: ParallaxLayer


func _build_parallax() -> void:
	var bg := ParallaxBackground.new()
	add_child(bg)
	# inked night stack: deep storm sky -> drifting cloud sprites ->
	# minaret skyline -> far block silhouettes -> near keyed facades
	_layer(bg, 0.04, _tex_sprite(ENV + "night_sky.png", 2.4, Vector2(-1600, -900)), 3302.4)
	_cloud_layer = _layer(bg, 0.07, _cloud_band(), 1250.0)
	_layer(bg, 0.16, _tex_sprite(ENV + "skyline_far.png", 1.6, Vector2(-1600, -40)), 3123.2)
	_facade_band(bg, 0.24, ["facades_d"], 0.72, Color(0.46, 0.5, 0.72))
	_facade_band(bg, 0.34, ["facades_b", "facades_c", "facades_d"], 0.95)


## Transparent storm-cloud sprites on their own (slow) layer.
func _cloud_band() -> Node2D:
	var holder := Node2D.new()
	var defs := [
		["cloud_1", -1500.0, -330.0, 1.5],
		["cloud_2", -450.0, -400.0, 1.15],
		["cloud_3", 350.0, -290.0, 1.7],
	]
	for d in defs:
		var s := _tex_sprite(ENV + String(d[0]) + ".png", float(d[3]),
				Vector2(float(d[1]), float(d[2])))
		if s.texture == null:
			continue
		s.modulate = Color(0.7, 0.76, 1.0)
		holder.add_child(s)
	return holder


## Bottom-aligned keyed facade strips, concatenated into one endless band.
func _facade_band(bg: ParallaxBackground, stick: float, names: Array,
		scale_f: float, tint := Color(1, 1, 1)) -> void:
	var holder := Node2D.new()
	var x := -1600.0
	for n in names:
		var s := _tex_sprite(ENV + String(n) + ".png", scale_f, Vector2.ZERO)
		if s.texture == null:
			continue
		var tw := float(s.texture.get_width()) * scale_f
		var th := float(s.texture.get_height()) * scale_f
		s.position = Vector2(x, GROUND_Y - th)
		s.modulate = tint
		holder.add_child(s)
		x += tw
	if holder.get_child_count() > 0:
		_layer(bg, stick, holder, x + 1600.0)


## Ground-anchored env sprite, horizontally centered on cx.
## NOTE on chopped filenames: "ladder".png is the vertical I-beam column,
## "plank_stack".png is the leaning ladder, "ibeam_col".png is the plank stack.
func _ground_prop(name: String, cx: float, target_h: float, z := -1,
		ground := GROUND_Y, tint := Color(1, 1, 1), rot := 0.0) -> Sprite2D:
	var s := _tex_sprite(ENV + name + ".png", 1.0, Vector2.ZERO)
	if s.texture == null:
		push_warning("prologue: missing env sprite " + name)
		return s
	var th := float(s.texture.get_height())
	var sc := target_h / th
	s.scale = Vector2(sc, sc)
	var tw := float(s.texture.get_width()) * sc
	s.position = Vector2(cx - tw * 0.5, ground - target_h)
	s.z_index = z
	s.modulate = tint
	s.rotation = rot
	add_child(s)
	return s


## Top-anchored env sprite (platforms, awnings, beams), centered on cx.
func _prop(name: String, cx: float, top: float, target_h: float, z := -1,
		tint := Color(1, 1, 1), rot := 0.0) -> Sprite2D:
	var s := _tex_sprite(ENV + name + ".png", 1.0, Vector2.ZERO)
	if s.texture == null:
		push_warning("prologue: missing env sprite " + name)
		return s
	var sc := target_h / float(s.texture.get_height())
	s.scale = Vector2(sc, sc)
	s.centered = false
	s.position = Vector2(cx - float(s.texture.get_width()) * sc * 0.5, top)
	s.z_index = z
	s.modulate = tint
	s.rotation = rot
	add_child(s)
	return s


## Non-uniform stretched env sprite (beams, strips).
func _stretch_prop(name: String, x: float, top: float, w: float, h: float, z := -1,
		tint := Color(1, 1, 1)) -> Sprite2D:
	var s := _tex_sprite(ENV + name + ".png", 1.0, Vector2(x, top))
	if s.texture == null:
		push_warning("prologue: missing env sprite " + name)
		return s
	s.scale = Vector2(w / float(s.texture.get_width()), h / float(s.texture.get_height()))
	s.z_index = z
	s.modulate = tint
	add_child(s)
	return s


func _layer(bg: ParallaxBackground, stick: float, child: Node, mirror_x: float) -> ParallaxLayer:
	var l := ParallaxLayer.new()
	l.motion_scale = Vector2(stick, 1.0)
	l.motion_mirroring = Vector2(mirror_x, 0)
	l.add_child(child)
	bg.add_child(l)
	return l


func _build_lighting() -> void:
	var grade := CanvasModulate.new()
	grade.color = Color(0.4, 0.46, 0.7)
	add_child(grade)
	for x in [140.0, 640.0, 1160.0, 1680.0, 2200.0, 2720.0, 3240.0]:
		_lamp(x, GROUND_Y)
	# lightning wash
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(0.9, 0.94, 1.0, 0.0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fc := CanvasLayer.new()
	fc.layer = 26
	fc.add_child(_flash_rect)
	add_child(fc)


func _lamp(x: float, ground: float) -> void:
	_ground_prop("lamp_post", x + 7.0, 190.0, -1, ground)
	var light := PointLight2D.new()
	light.texture = load(LIGHT_DOT) as Texture2D
	light.color = Color(1.0, 0.78, 0.45)
	light.energy = 1.8
	light.texture_scale = 4.4
	light.position = Vector2(x + 13, ground - 168)
	add_child(light)


func _build_weather() -> void:
	var p := CPUParticles2D.new()
	p.amount = 420
	p.lifetime = 1.1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(760.0, 40.0)
	p.direction = Vector2(0.22, 1.0)
	p.initial_velocity_min = 640.0
	p.initial_velocity_max = 780.0
	p.gravity = Vector2.ZERO
	p.color = Color(0.65, 0.75, 0.95, 0.35)
	add_child(p)
	_rain = p  # _process re-centers it on the camera every frame


var _rain: CPUParticles2D


# ============================================================== geometry ==
func _box2d(x: float, top: float, w: float, h: float, color: Color,
		one_way := false, parent_z := 0) -> StaticBody2D:
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
	if parent_z != 0:
		p.z_index = parent_z
	add_child(p)
	add_child(b)
	return b


func _poly(pts: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	add_child(p)
	return p


const ASPHALT := Color(0.13, 0.15, 0.24)
const CURB := Color(0.18, 0.2, 0.3)
const BRICK := Color(0.24, 0.2, 0.26)
const METAL := Color(0.2, 0.22, 0.3)
const SAND := Color(0.45, 0.38, 0.27)
const CONCRETE := Color(0.2, 0.21, 0.27)


func _build_street() -> void:
	# collision stays, visuals now come from the inked street strip
	_box2d(WORLD_L - 32.0, GROUND_Y, ROOF_EDGE + 60.0, 120.0, Color(0, 0, 0, 0))
	_box2d(WORLD_L - 32.0, GROUND_Y - 8.0, ROOF_EDGE + 60.0, 8.0, Color(0, 0, 0, 0))
	_box2d(WORLD_L - 64.0, 120.0, 32.0, 480.0, BRICK)  # west cap wall
	# tiled wet-asphalt strip (curb face sits behind the walking line)
	var strip := load(ENV + "street_flat.png") as Texture2D
	var strip_s := 0.82
	var strip_w := 1408.0 * strip_s
	var strip_top := GROUND_Y - 70.0 * strip_s
	var tiles := int(ceil((WORLD_R + 320.0) / strip_w)) + 1
	for i in tiles:
		var s := Sprite2D.new()
		s.texture = strip
		s.scale = Vector2.ONE * strip_s
		s.centered = false
		s.position = Vector2(WORLD_L - 96.0 + i * strip_w, strip_top)
		s.z_index = -2
		add_child(s)


const ROOF_EDGE := 3800.0


# ============================================================== ZONE 1 ===
func _build_zone1() -> void:
	# wall-jump shaft: a cramped alley slit between two coherent facades
	_box2d(300.0, 420.0, 30.0, 180.0, Color(0, 0, 0, 0))
	_box2d(400.0, 420.0, 30.0, 180.0, Color(0, 0, 0, 0))
	_box2d(200.0, 414.0, 100.0, 12.0, Color(0, 0, 0, 0), true)  # exit ledge
	_stretch_prop("facades_strip", 280.0, 360.0, 180.0, 240.0, -2)
	_stretch_prop("facades_b", 296.0, 400.0, 38.0, 200.0, -1)
	_stretch_prop("facades_c", 392.0, 400.0, 44.0, 200.0, -1)
	# the exit ledge is a scaffold plank on a real X-frame
	_stretch_prop("plank", 193.0, 408.0, 128.0, 13.0, 0)
	_prop("scaffold_frame", 255.0, 420.0, 180.0, -1)
	# slide shutter: inked roll-up door w/ real torn gap at its bottom
	_box2d(640.0, 486.0, 110.0, 80.0, Color(0, 0, 0, 0))
	_ground_prop("shutter", 695.0, 118.0, -1)
	_box2d(640.0, 566.0, 110.0, 8.0, Color(0.75, 0.2, 0.15))


# ============================================================== ZONE 2 ===
func _build_zone2() -> void:
	# cafe fronts; awnings stay as mid cover platforms
	_ground_prop("cafe_front", 942.0, 158.0, -2)
	_ground_prop("cafe_front", 1190.0, 152.0, -2)
	_box2d(880.0, 500.0, 120.0, 10.0, METAL, true)
	_box2d(1130.0, 500.0, 120.0, 10.0, METAL, true)
	# street life: kiosk between the cafes + neon signs on the storefronts
	_ground_prop("news_kiosk", 1040.0, 82.0, -2)
	_prop("neon_round", 942.0, 418.0, 46.0, -2)
	_prop("neon_stack", 1215.0, 380.0, 96.0, -2)
	_ground_prop("hose_reel", 769.0, 58.0, -1)


# ============================================================== ZONE 3 ===
func _build_zone3() -> void:
	# sedan: solid shell + BOUNCE roof + headlights at both lanes
	_box2d(1450.0, 554.0, 110.0, 46.0, Color(0, 0, 0, 0))
	_box2d(1468.0, 528.0, 74.0, 26.0, Color(0, 0, 0, 0))
	_ground_prop("sedan_dark", 1505.0, 82.0, -1)
	var pad := Area2D.new()
	pad.collision_layer = 64
	pad.collision_mask = 2
	var pcs := CollisionShape2D.new()
	var prect := RectangleShape2D.new()
	prect.size = Vector2(110, 8)
	pcs.shape = prect
	pcs.position = Vector2(1505, 550)
	pad.add_child(pcs)
	pad.body_entered.connect(func(body: Node2D) -> void:
		if body is Player2D and body.velocity.y > 200.0:
			body.velocity.y = -640.0)
	add_child(pad)
	_poly(PackedVector2Array([Vector2(1452, 566), Vector2(1458, 566), Vector2(1458, 574), Vector2(1452, 574)]),
		Color(1.0, 0.85, 0.4))
	_poly(PackedVector2Array([Vector2(1552, 566), Vector2(1558, 566), Vector2(1558, 574), Vector2(1552, 574)]),
		Color(0.9, 0.15, 0.12))
	# cover van
	_box2d(1700.0, 516.0, 130.0, 84.0, Color(0, 0, 0, 0))
	_box2d(1700.0, 506.0, 40.0, 10.0, Color(0, 0, 0, 0))
	_ground_prop("van", 1765.0, 96.0, -1)
	# parked toktok in the alley mouth after the van
	_ground_prop("toktok", 1892.0, 72.0, -1)


# ============================================================== ZONE 4 ===
func _build_zone4() -> void:
	# canopy route above the smoke lane.
	# Every platform is a real striped shop awning, with the shuttered
	# storefront drawn on the wall behind it and pipe posts to the street.
	var cans := [[1930.0, 2070.0, "awning_blue"], [2110.0, 2250.0, "awning_green"],
		[2300.0, 2440.0, "awning_beige"], [2480.0, 2620.0, "wire_banner"],
		[2670.0, 2810.0, "awning_green"]]
	for c in cans:
		var cx := (c[0] + c[1]) * 0.5
		_box2d(c[0], 470.0, c[1] - c[0], 10.0, Color(0, 0, 0, 0), true)
		# shuttered shopfront on the wall behind the awning
		_stretch_prop("shutter_wide", cx - 78.0, 452.0, 168.0, 148.0, -2,
			Color(0.55, 0.58, 0.72))
		# the awning itself: slope + valance hanging past the stand line
		_stretch_prop(c[2], c[0] - 6.0, 460.0, c[1] - c[0] + 14.0, 54.0, -1)
		# awning support pipes
		_poly(PackedVector2Array([
			Vector2(c[0] + 6, 470), Vector2(c[0] + 13, 470),
			Vector2(c[0] + 13, GROUND_Y), Vector2(c[0] + 6, GROUND_Y)]),
			Color(0.07, 0.075, 0.1))
	# market stands at street level (visual huts)
	_box2d(2150.0, 520.0, 90.0, 80.0, Color(0, 0, 0, 0))
	_ground_prop("crate_stand", 2195.0, 92.0, -1)
	_box2d(2600.0, 520.0, 90.0, 80.0, Color(0, 0, 0, 0))
	_ground_prop("market_table", 2645.0, 86.0, -1)


# ============================================================== ZONE 5 ===
func _build_zone5() -> void:
	# sandbags + striped barriers
	_box2d(2950.0, 570.0, 70.0, 30.0, Color(0, 0, 0, 0))
	_box2d(2960.0, 552.0, 50.0, 18.0, Color(0, 0, 0, 0))
	_ground_prop("sandbags", 2985.0, 50.0, -1)
	_box2d(3120.0, 570.0, 70.0, 30.0, Color(0, 0, 0, 0))
	_ground_prop("sandbags", 3155.0, 44.0, -1)
	for bx in [3050.0, 3240.0]:
		_box2d(bx, 560.0, 8.0, 40.0, Color(0, 0, 0, 0))
		_box2d(bx + 42.0, 560.0, 8.0, 40.0, Color(0, 0, 0, 0))
		for i in 2:
			_box2d(bx, 584.0 - i * 14.0, 50.0, 12.0, Color(0, 0, 0, 0))
		_ground_prop("barrier", bx + 25.0, 66.0, -1)
	# THE GATE: a welded steel shutter on runners; sinks when the squad falls.
	# Every visual is parented to the gate body so it travels with the breach tween.
	_gate = _box2d(3450.0, 430.0, 55.0, 170.0, Color(0, 0, 0, 0))
	var gate_art := Sprite2D.new()
	var gtex: Texture2D = load(ENV + "shutter_wide.png")
	gate_art.texture = gtex
	gate_art.centered = false
	gate_art.scale = Vector2(55.0 / gtex.get_width(), 170.0 / gtex.get_height())
	gate_art.position = Vector2(3450.0, 430.0)
	gate_art.modulate = Color(0.5, 0.52, 0.62)
	_gate.add_child(gate_art)
	for i in 3:
		var mat := Color(0.8, 0.15, 0.12) if i % 2 == 0 else Color(0.9, 0.9, 0.92)
		var stripe := Polygon2D.new()
		stripe.polygon = PackedVector2Array([
			Vector2(3452.0, 448.0 + i * 48.0), Vector2(3503.0, 448.0 + i * 48.0),
			Vector2(3503.0, 464.0 + i * 48.0), Vector2(3452.0, 464.0 + i * 48.0)])
		stripe.color = mat
		_gate.add_child(stripe)
	_gate_lamp = Polygon2D.new()
	_gate_lamp.polygon = PackedVector2Array([
		Vector2(3468.0, 434.0), Vector2(3486.0, 434.0),
		Vector2(3486.0, 442.0), Vector2(3468.0, 442.0)])
	_gate_lamp.color = Color(0.9, 0.15, 0.12)
	_gate.add_child(_gate_lamp)
	# construction clutter flanking the blockade
	_ground_prop("ibeam_col", 3392.0, 34.0, -1)
	_ground_prop("brace", 3360.0, 86.0, -1, 600.0, Color(1, 1, 1), 0.22)


# ============================================================= ROOFTOP ===
func _build_rooftop() -> void:
	# scaffold zigzag up to ROOF_Y: wood planks on a real two-tower scaffold.
	_box2d(3520.0, 520.0, 120.0, 10.0, Color(0, 0, 0, 0), true)
	_box2d(3640.0, 440.0, 120.0, 10.0, Color(0, 0, 0, 0), true)
	_box2d(3520.0, 360.0, 120.0, 10.0, Color(0, 0, 0, 0), true)
	# the tall tower carries the 360 and 520 planks, the short one the 440
	_prop("scaffold_frame", 3570.0, 366.0, 234.0, -2)
	_prop("scaffold_frame", 3690.0, 446.0, 154.0, -2)
	# leaning extension ladder ties the zigzag to the street
	_prop("plank_stack", 3622.0, 378.0, 222.0, -1, Color(1, 1, 1), 0.08)
	# the planks you actually stand on
	_stretch_prop("plank", 3512.0, 514.0, 136.0, 15.0, 0)
	_stretch_prop("plank", 3632.0, 434.0, 136.0, 15.0, 0)
	_stretch_prop("plank", 3512.0, 354.0, 136.0, 15.0, 0)
	# the roof slab + backstop wall + parapet lip
	_box2d(ROOF_EDGE, ROOF_Y, 950.0, 32.0, CONCRETE)
	_box2d(4700.0, -140.0, 50.0, 420.0, BRICK)
	_box2d(ROOF_EDGE, ROOF_Y - 5.0, 950.0, 5.0, CURB)
	# girders: the only floor the sweep grid respects
	_box2d(3860.0, 200.0, 240.0, 10.0, Color(0, 0, 0, 0))
	_box2d(4260.0, 200.0, 240.0, 10.0, Color(0, 0, 0, 0))
	_stretch_prop("girder", 3860.0, 200.0, 240.0, 46.0, -1)
	_stretch_prop("girder", 4260.0, 200.0, 240.0, 46.0, -1)
	# riveted I-beam columns stand each girder on the roof slab
	for gx in [3875.0, 4085.0, 4275.0, 4485.0]:
		_prop("ladder", gx, 210.0, 70.0, -2)
	for gx in [3864.0, 4488.0]:
		_poly(PackedVector2Array([
			Vector2(gx, 200), Vector2(gx + 6, 200), Vector2(gx + 6, 120), Vector2(gx, 120)]),
			Color(0.09, 0.1, 0.13))
	# rooftop dressing: water tank, ACs, antenna
	_box2d(3900.0, ROOF_Y - 56.0, 64.0, 56.0, Color(0, 0, 0, 0))
	_ground_prop("water_tank", 3932.0, 66.0, -1, ROOF_Y)
	# lived-in Cairo roof: pigeon coop, dish farm, hose cabinet
	_ground_prop("pigeon_coop", 4010.0, 42.0, -2, ROOF_Y)
	_ground_prop("dish_cluster", 4555.0, 48.0, -2, ROOF_Y)
	_ground_prop("hose_reel", 4690.0, 56.0, -2, ROOF_Y)
	_box2d(4150.0, ROOF_Y - 34.0, 46.0, 34.0, Color(0, 0, 0, 0))
	_ground_prop("ac_unit", 4173.0, 38.0, -1, ROOF_Y)
	_box2d(4450.0, ROOF_Y - 34.0, 46.0, 34.0, Color(0, 0, 0, 0))
	_ground_prop("ac_unit", 4473.0, 38.0, -1, ROOF_Y)
	_ground_prop("antenna", 4680.0, 134.0, -1, ROOF_Y)
	# floodlight towers with fake cones + real amber pools
	for fx in [3830.0, 4660.0]:
		_ground_prop("floodlight", fx + 3.0, 178.0, -1, ROOF_Y)
		var cone := Polygon2D.new()
		cone.polygon = PackedVector2Array([
			Vector2(fx - 12, ROOF_Y - 166), Vector2(fx + 18, ROOF_Y - 166),
			Vector2(fx + 90, ROOF_Y), Vector2(fx - 84, ROOF_Y)])
		cone.color = Color(1.0, 0.8, 0.45, 0.08)
		add_child(cone)
		var light := PointLight2D.new()
		light.texture = load(LIGHT_DOT) as Texture2D
		light.color = Color(1.0, 0.82, 0.5)
		light.energy = 2.0
		light.texture_scale = 5.0
		light.position = Vector2(fx + 3, ROOF_Y - 150)
		add_child(light)


# ============================================================= gameplay ===
func _spawn_enemy(e: Enemy2D, pos: Vector2, min_x: float, max_x: float) -> Enemy2D:
	e.position = pos
	e.patrol_min_x = min_x
	e.patrol_max_x = max_x
	add_child(e)
	return e


func _track_squad(e: Enemy2D) -> void:
	_squad_alive += 1
	e.died.connect(_on_squad_died)


func _on_squad_died() -> void:
	_squad_alive -= 1
	if _squad_alive <= 0:
		_breach_gate()


func _breach_gate() -> void:
	if _gate == null:
		return
	_gate_lamp.color = Color(0.2, 1.0, 0.4)
	var ih := get_node_or_null("/root/InputHelper")
	if ih != null and ih.has_method("rumble_medium"):
		ih.rumble_medium()
	var tw := create_tween()
	tw.tween_property(_gate, "position:y", _gate.position.y + 180.0, 1.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_gate.queue_free)


func _build_gameplay() -> void:
	# checkpoints
	for cx in [760.0, 1920.0, 3520.0]:
		var cp := Checkpoint2D.new()
		cp.position = Vector2(cx, GROUND_Y)
		add_child(cp)

	# THE STAR
	_player = Player2D.new()
	_player.position = Vector2(80.0, GROUND_Y)
	add_child(_player)
	_player.play_stagger_intro(2.6)
	_cam = TitoCamera2D.new()
	add_child(_cam)
	_cam.set_target(_player)
	_cam.apply_zone_limits(Rect2(WORLD_L, -140.0, WORLD_R - WORLD_L, 852.0))
	var hero_light := PointLight2D.new()
	hero_light.texture = load(LIGHT_DOT) as Texture2D
	hero_light.color = Color(0.7, 0.8, 1.0)
	hero_light.energy = 0.55
	hero_light.texture_scale = 1.7
	hero_light.position = Vector2(0, -34)
	_player.add_child(hero_light)
	var hud := VitalityHud.new()
	add_child(hud)
	hud.bind(_player)
	_dialogue = DialogueLayer.new()
	add_child(_dialogue)
	_build_boss_bar()
	_build_outro_overlay()

	# Z2 staff tutors
	_spawn_enemy(StaffEnforcer.new(), Vector2(860.0, GROUND_Y), 800.0, 1050.0)
	_spawn_enemy(StaffEnforcer.new(), Vector2(1150.0, GROUND_Y), 1080.0, 1280.0)
	# Z3 shield sentry
	_spawn_enemy(ShieldSentry.new(), Vector2(1620.0, GROUND_Y), 1500.0, 1780.0)
	# Z4 denial pair
	_spawn_enemy(SmokeUnit2D.new(), Vector2(2500.0, GROUND_Y), 2420.0, 2620.0)
	_spawn_enemy(Marksman2D.new(), Vector2(2700.0, GROUND_Y), 2620.0, 2860.0)
	# Z5 the gate squad: staff x2 + shield + marksman
	_track_squad(_spawn_enemy(StaffEnforcer.new(), Vector2(3020.0, GROUND_Y), 2960.0, 3120.0))
	_track_squad(_spawn_enemy(StaffEnforcer.new(), Vector2(3140.0, GROUND_Y), 3060.0, 3210.0))
	_track_squad(_spawn_enemy(ShieldSentry.new(), Vector2(3240.0, GROUND_Y), 3160.0, 3320.0))
	_track_squad(_spawn_enemy(Marksman2D.new(), Vector2(3350.0, GROUND_Y), 3280.0, 3440.0))

	# THE RAVEN, waiting in the floodlights
	_boss = BossRaven2D.new()
	_boss.arena_min_x = ARENA_MIN
	_boss.arena_max_x = ARENA_MAX
	_boss.floor_y = ROOF_Y
	_boss.sweep_safe_y = ROOF_Y - 50.0
	_boss.position = Vector2(4500.0, ROOF_Y)
	add_child(_boss)
	_boss.boss_died.connect(_on_boss_died)
	_boss.hp_changed.connect(_on_boss_hp)

	# dialogue tripwire at the roof's mouth
	var trig := Area2D.new()
	trig.collision_layer = 0
	trig.collision_mask = 2
	var tcs := CollisionShape2D.new()
	var trect := RectangleShape2D.new()
	trect.size = Vector2(40, 160)
	tcs.shape = trect
	trig.add_child(tcs)
	trig.position = Vector2(3900.0, ROOF_Y - 80)
	add_child(trig)
	trig.body_entered.connect(_on_intro_body)


func _build_boss_bar() -> void:
	_boss_ui = CanvasLayer.new()
	_boss_ui.layer = 24
	_boss_ui.visible = false
	add_child(_boss_ui)
	var title := Label.new()
	title.text = "الغراب — THE RAVEN"
	title.add_theme_font_override("font", load(FONT_BOLD) as Font)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.6, 0.4))
	title.position = Vector2(360, 600)
	_boss_ui.add_child(title)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.85)
	bg.position = Vector2(360, 626)
	bg.size = Vector2(440, 14)
	_boss_ui.add_child(bg)
	_boss_fg = ColorRect.new()
	_boss_fg.color = Color(0.85, 0.2, 0.15)
	_boss_fg.position = Vector2(362, 628)
	_boss_fg.size = Vector2(436, 10)
	_boss_ui.add_child(_boss_fg)


func _on_boss_hp(hp: int, max_hp: int) -> void:
	if _boss_fg != null:
		_boss_fg.size.x = 436.0 * clampf(float(hp) / max_hp, 0.0, 1.0)


func _on_intro_body(body: Node2D) -> void:
	if _intro_done or not body.is_in_group("player"):
		return
	_intro_done = true
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO
	_boss_ui.visible = true
	_cam.focus(Vector2(4400.0, ROOF_Y - 40.0), 1.12, 1.0)
	_dialogue.play(LINES_INTRO, Callable(self, "_intro_finished"))


func _intro_finished() -> void:
	_cam.release(0.8)
	if is_instance_valid(_player):
		_player.set_physics_process(true)
	if _boss != null:
		_boss.begin_fight()


# ================================================================ outro ===
func _build_outro_overlay() -> void:
	var ol := CanvasLayer.new()
	ol.layer = 28
	add_child(ol)
	_white = _full_rect(Color(1, 1, 1, 0), ol)
	_black = _full_rect(Color(0, 0, 0, 0), ol)
	_ecg = Line2D.new()
	_ecg.default_color = Color(0.3, 1.0, 0.5)
	_ecg.width = 3.0
	_ecg.visible = false
	ol.add_child(_ecg)


func _full_rect(c: Color, parent: Node) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _on_boss_died(boss: BossRaven2D) -> void:
	if _outro_started:
		return
	_outro_started = true
	var tw := create_tween().set_parallel()
	tw.tween_property(boss, "rotation", -1.4, 0.7) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(boss, "position:y", boss.position.y - 10.0, 0.7)
	_boss_ui.visible = false
	_run_outro()


func _run_outro() -> void:
	if is_instance_valid(_player):
		_player.set_physics_process(false)
	await get_tree().create_timer(1.6).timeout
	# high-beams sweep + the cue
	var wt := create_tween()
	wt.tween_property(_white, "color:a", 1.0, 0.12)
	wt.tween_interval(0.18)
	wt.tween_property(_white, "color:a", 0.0, 0.5)
	await wt.finished
	await get_tree().create_timer(0.35).timeout
	_black.color = Color(0, 0, 0, 1)
	await get_tree().create_timer(0.9).timeout
	_ecg_vals.clear()
	_ecg.visible = true
	_ecg_t = 0.0
	await get_tree().create_timer(6.0).timeout
	_ecg.visible = false
	_dialogue.play(LINES_OUTRO, Callable(self, "_to_chapter_one"))


func _ecg_sample(t: float) -> float:
	if t > 2.4:
		return randf_range(-0.03, 0.03)
	var ph := fposmod(t, 0.86) / 0.86
	if ph < 0.06:
		return -0.35
	if ph < 0.14:
		return 1.0
	if ph < 0.22:
		return -0.28
	if ph < 0.3:
		return 0.12
	return 0.0


func _redraw_ecg() -> void:
	var vp := get_viewport().get_visible_rect().size
	var base_y := vp.y * 0.45
	var n := maxi(_ecg_vals.size(), 2)
	var pts := PackedVector2Array()
	for i in n:
		var x := vp.x * 0.5 - (n * 0.5 - i) * 4.0
		pts.append(Vector2(x, base_y - _ecg_vals[i] * 42.0))
	_ecg.points = pts


func _to_chapter_one() -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.8)
	await tw.finished
	get_tree().change_scene_to_file(CHAPTER_ONE)


# =============================================================== process ===
func _process(delta: float) -> void:
	# rain rides the camera
	if _rain != null and _cam != null:
		_rain.global_position = _cam.global_position + Vector2(0, -320)
	# storm clouds drift on their own layer
	if _cloud_layer != null:
		_cloud_layer.motion_offset.x -= 9.0 * delta
	# lightning
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = randf_range(6.0, 13.0)
		_flash = randf_range(0.35, 0.6)
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		_flash_rect.color.a = _flash * 0.5
	# flatline
	if _ecg_t >= 0.0:
		_ecg_t += delta
		_ecg_vals.append(_ecg_sample(_ecg_t))
		if _ecg_vals.size() > 240:
			_ecg_vals.remove_at(0)
		_redraw_ecg()


# =============================================================== prompts ===
func _hint(x: float, y: float, kb: String, pad: String,
		tint := Color(0.85, 0.9, 1.0), size := 20) -> void:
	var lbl := Label.new()
	lbl.text = kb
	lbl.add_theme_font_override("font", load(FONT_BOLD) as Font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.modulate = tint
	lbl.position = Vector2(x, y)
	add_child(lbl)
	_hints.append([lbl, kb, pad])


func _refresh_hints(device: String) -> void:
	var gamepad := device in ["xbox", "playstation", "switch", "steamdeck", "generic"]
	for h in _hints:
		(h[0] as Label).text = h[2] if gamepad and h[2] != "" else h[1]


func _build_prompts() -> void:
	_hint(40, 220, "ليلة البداية — الهروب", "", Color(1.0, 0.8, 0.5), 34)
	_hint(40, 262, "حركة: A/D · قفز: مسافة · سبرنت: امسك الاتجاه",
		"حركة: عصا شمال · قفز: A")
	_hint(255, 350, "شق رأسي: المس الحيطة واقفز بالتبادل", "", Color(0.7, 0.9, 1.0))
	_hint(605, 430, "شتر مكسور: زحلقة — قفّ كنّية أثناء الجري",
		"زحلقة: امسك زرار الزحلقة/تحت أثناء الجري", Color(1.0, 0.85, 0.5))
	_hint(820, 380, "كومبو خفيف ×3 · تقيل · العلوية ⬇ = صدّ وقتها!",
		"X ×3 · Y تقيل · صدّ: RB", Color(1.0, 0.8, 0.45))
	_hint(1420, 430, "الحاجز بيصد من قدام — دحرجة خلفه أو سقطة هوائية!",
		"دحرجة: B خلفه · سقطة: تقيل في الهوا", Color(1.0, 0.65, 0.4))
	_hint(2040, 380, "الدخان على الأرض — الطريق النضيف فوق المظلات",
		"", Color(0.75, 0.9, 1.0))
	_hint(2540, 380, "الشعاع الأحمر: زحلقة أو دحرجة وقت الطلقة",
		"زحلقة/دحرجة: RT أو B", Color(1.0, 0.55, 0.45))
	_hint(2960, 400, "اقضوا على الفرقة كلها عشان البوابة تفتح", "", Color(1.0, 0.85, 0.5))
	_hint(3880, 100, "الشبكة الحمرا؟ الجسور المعلقة أو الهوا = الأمان", "", Color(0.8, 0.85, 1.0))
	var ih: Node = get_node_or_null("/root/InputHelper")
	if ih != null:
		ih.device_changed.connect(func(d: String, _i: int) -> void: _refresh_hints(d))
		_refresh_hints(str(ih.get("device")))

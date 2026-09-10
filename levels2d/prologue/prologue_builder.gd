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
	_build_prompts()


# ================================================================= looks ==
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
	_layer(bg, 0.04, _tex_sprite(CAIRO + "sky.png", 2.4, Vector2(-1200, -500)), 1024.0)
	_layer(bg, 0.16, _tex_sprite(CAIRO + "skyline_far.png", 1.9, Vector2(-1200, -60)), 650.0)
	_layer(bg, 0.34, _tex_sprite(CAIRO + "skyline_mid.png", 1.5, Vector2(-1200, 100)), 540.0)


func _layer(bg: ParallaxBackground, stick: float, child: Node, mirror_x: float) -> void:
	var l := ParallaxLayer.new()
	l.motion_scale = Vector2(stick, 1.0)
	l.motion_mirroring = Vector2(mirror_x, 0)
	l.add_child(child)
	bg.add_child(l)


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
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([
		Vector2(-3, 0), Vector2(3, 0), Vector2(3, -180), Vector2(14, -180),
		Vector2(14, -171), Vector2(3, -171), Vector2(-3, -171)])
	post.color = Color(0.10, 0.11, 0.16)
	post.position = Vector2(x, ground)
	add_child(post)
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
	_box2d(WORLD_L - 32.0, GROUND_Y, ROOF_EDGE + 60.0, 120.0, ASPHALT)
	_box2d(WORLD_L - 32.0, GROUND_Y - 8.0, ROOF_EDGE + 60.0, 8.0, CURB)
	_box2d(WORLD_L - 64.0, 120.0, 32.0, 480.0, BRICK)  # west cap wall
	# backdrop brick strips behind the street (non-gameplay silhouette)
	for seg in [[0.0, 700.0, 5.0], [700.0, 1400.0, 6.0], [1400.0, 2100.0, 7.0],
			[2100.0, 2900.0, 6.0], [2900.0, 3520.0, 6.5]]:
		var x0: float = seg[0]
		var x1: float = seg[1]
		var h: float = seg[2] * 56.0
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([
			Vector2(x0, GROUND_Y), Vector2(x1, GROUND_Y),
			Vector2(x1, GROUND_Y - h), Vector2(x0, GROUND_Y - h)])
		p.color = Color(0.16, 0.15, 0.21)
		p.z_index = -1
		add_child(p)


const ROOF_EDGE := 3800.0


# ============================================================== ZONE 1 ===
func _build_zone1() -> void:
	# wall-jump shaft: two brick towers, 70 px throat
	_box2d(300.0, 420.0, 30.0, 180.0, BRICK)
	_box2d(400.0, 420.0, 30.0, 180.0, BRICK)
	_box2d(200.0, 414.0, 100.0, 12.0, METAL, true)  # exit ledge on the left tower
	# slide shutter: masonry frame + 34 px gap under it
	_box2d(640.0, 486.0, 110.0, 80.0, BRICK)
	_box2d(640.0, 566.0, 110.0, 8.0, Color(0.75, 0.2, 0.15))
	for i in 3:
		_poly(PackedVector2Array([
			Vector2(642.0, 492.0 + i * 22.0), Vector2(748.0, 492.0 + i * 22.0),
			Vector2(748.0, 500.0 + i * 22.0), Vector2(642.0, 500.0 + i * 22.0),
		]), Color(0.28, 0.3, 0.38))


# ============================================================== ZONE 2 ===
func _build_zone2() -> void:
	# cafe awnings as mid cover
	_box2d(880.0, 500.0, 120.0, 10.0, METAL, true)
	_box2d(1130.0, 500.0, 120.0, 10.0, METAL, true)


# ============================================================== ZONE 3 ===
func _build_zone3() -> void:
	# sedan: solid shell + BOUNCE roof + headlights at both lanes
	_box2d(1450.0, 554.0, 110.0, 46.0, Color(0.14, 0.16, 0.24))
	_box2d(1468.0, 528.0, 74.0, 26.0, Color(0.1, 0.11, 0.17))
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
	_box2d(1700.0, 516.0, 130.0, 84.0, Color(0.16, 0.18, 0.26))
	_box2d(1700.0, 506.0, 40.0, 10.0, Color(0.12, 0.13, 0.2))


# ============================================================== ZONE 4 ===
func _build_zone4() -> void:
	# canopy route above the smoke lane
	var cans := [[1930.0, 2070.0], [2110.0, 2250.0], [2300.0, 2440.0],
		[2480.0, 2620.0], [2670.0, 2810.0]]
	for c in cans:
		_box2d(c[0], 470.0, c[1] - c[0], 10.0, METAL, true)
		_poly(PackedVector2Array([
			Vector2(c[0] + 6, 470), Vector2(c[0] + 14, 470),
			Vector2(c[0] + 14, GROUND_Y), Vector2(c[0] + 6, GROUND_Y)]),
			Color(0.1, 0.1, 0.14))
	# market stands at street level (visual huts)
	_box2d(2150.0, 520.0, 90.0, 80.0, Color(0.2, 0.14, 0.12))
	_box2d(2600.0, 520.0, 90.0, 80.0, Color(0.2, 0.14, 0.12))


# ============================================================== ZONE 5 ===
func _build_zone5() -> void:
	# sandbags + striped barriers
	_box2d(2950.0, 570.0, 70.0, 30.0, SAND)
	_box2d(2960.0, 552.0, 50.0, 18.0, SAND)
	_box2d(3120.0, 570.0, 70.0, 30.0, SAND)
	for bx in [3050.0, 3240.0]:
		_box2d(bx, 560.0, 8.0, 40.0, METAL)
		_box2d(bx + 42.0, 560.0, 8.0, 40.0, METAL)
		for i in 2:
			var mat := Color(0.8, 0.15, 0.12) if i == 0 else Color(0.9, 0.9, 0.92)
			_box2d(bx, 584.0 - i * 14.0, 50.0, 12.0, mat)
	# THE GATE: sinks when the squad falls
	_gate = _box2d(3450.0, 430.0, 55.0, 170.0, METAL)
	for i in 3:
		var mat := Color(0.8, 0.15, 0.12) if i % 2 == 0 else Color(0.9, 0.9, 0.92)
		_poly(PackedVector2Array([
			Vector2(3452.0, 448.0 + i * 48.0), Vector2(3503.0, 448.0 + i * 48.0),
			Vector2(3503.0, 464.0 + i * 48.0), Vector2(3452.0, 464.0 + i * 48.0)]), mat)
	_gate_lamp = _poly(PackedVector2Array([
		Vector2(3468.0, 420.0), Vector2(3486.0, 420.0),
		Vector2(3486.0, 428.0), Vector2(3468.0, 428.0)]), Color(0.9, 0.15, 0.12))


# ============================================================= ROOFTOP ===
func _build_rooftop() -> void:
	# scaffold zigzag up to ROOF_Y
	_box2d(3520.0, 520.0, 120.0, 10.0, METAL, true)
	_box2d(3640.0, 440.0, 120.0, 10.0, METAL, true)
	_box2d(3520.0, 360.0, 120.0, 10.0, METAL, true)
	# the roof slab + backstop wall + parapet lip
	_box2d(ROOF_EDGE, ROOF_Y, 950.0, 32.0, CONCRETE)
	_box2d(4700.0, -140.0, 50.0, 420.0, BRICK)
	_box2d(ROOF_EDGE, ROOF_Y - 5.0, 950.0, 5.0, CURB)
	# girders: the only floor the sweep grid respects
	_box2d(3860.0, 200.0, 240.0, 10.0, METAL)
	_box2d(4260.0, 200.0, 240.0, 10.0, METAL)
	for gx in [3864.0, 4488.0]:
		_poly(PackedVector2Array([
			Vector2(gx, 200), Vector2(gx + 6, 200), Vector2(gx + 6, 120), Vector2(gx, 120)]),
			Color(0.09, 0.1, 0.13))
	# rooftop dressing: water tank, ACs, antenna
	_box2d(3900.0, ROOF_Y - 56.0, 64.0, 56.0, Color(0.18, 0.19, 0.24))
	_box2d(4150.0, ROOF_Y - 34.0, 46.0, 34.0, Color(0.16, 0.17, 0.22))
	_box2d(4450.0, ROOF_Y - 34.0, 46.0, 34.0, Color(0.16, 0.17, 0.22))
	_poly(PackedVector2Array([
		Vector2(4676.0, ROOF_Y), Vector2(4684.0, ROOF_Y),
		Vector2(4684.0, ROOF_Y - 130.0), Vector2(4676.0, ROOF_Y - 130.0)]), Color(0.08, 0.09, 0.12))
	# floodlight towers with fake cones + real amber pools
	for fx in [3830.0, 4660.0]:
		_poly(PackedVector2Array([
			Vector2(fx, ROOF_Y), Vector2(fx + 6, ROOF_Y),
			Vector2(fx + 6, ROOF_Y - 170.0), Vector2(fx, ROOF_Y - 170.0)]), Color(0.09, 0.1, 0.13))
		_poly(PackedVector2Array([
			Vector2(fx - 14, ROOF_Y - 178), Vector2(fx + 20, ROOF_Y - 178),
			Vector2(fx + 20, ROOF_Y - 166), Vector2(fx - 14, ROOF_Y - 166)]), Color(1.0, 0.82, 0.5))
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
	var lbl := Label2D.new()
	lbl.text = kb
	lbl.font = load(FONT_BOLD) as Font
	lbl.font_size = size
	lbl.modulate = tint
	lbl.position = Vector2(x, y)
	add_child(lbl)
	_hints.append([lbl, kb, pad])


func _refresh_hints(device: String) -> void:
	var gamepad := device in ["xbox", "playstation", "switch", "steamdeck", "generic"]
	for h in _hints:
		(h[0] as Label2D).text = h[2] if gamepad and h[2] != "" else h[1]


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

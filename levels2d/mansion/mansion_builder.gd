## MANSION EVASION 2D — "فيلا الاستهداف" (البرولو الجديد v1)
## Six zones across a secured neoclassical estate at night:
##   Z1   0..1560    garden parkour: wall-kick the perimeter wall, hedge
##                   crawl-gaps + searchlights, dry fountain, trellis -> garage roof
##   Z2   1560..1900 entrance breach: the armored van rams the doors behind
##                   you; debris ramp up to the mezzanine (y=380)
##   Z3   1900..2600 grand foyer: chandelier hop, slide-under shield, marble steps
##   Z4   2600..3100 upper gallery: security locker = sidearm pickup
##   Z5   3100..3850 glass sunroom ambush: squad drops in, tables as cover,
##                   exit barricade unlocks when the squad falls
##   Z6   3850..4300 terrace: cinematic vault into the canal -> title card
## Everything is code-built (same philosophy as prologue_builder).
extends Node2D

const ENV := "res://assets2d/sprites/env/"
const FONT_BOLD := "res://assets/fonts/DejaVuSans-Bold.ttf"
const LIGHT_DOT := "res://assets2d/fx/light_dot.png"

const GROUND_Y := 600.0     # garden + foyer ground floor
const MEZZ_Y := 380.0       # mezzanine / upper gallery / terrace floor
const WORLD_L := 0.0
const WORLD_R := 4450.0

const LINES_INTRO := [
	["تيتو", Color(0.55, 0.85, 1.0),
		"«مش هتلحقني يا غراب... مش النهاردة.»",
		"You won't catch me, Ghorab... not today.", 3.6],
]
const LINES_LOCKER := [
	["تيتو", Color(0.55, 0.85, 1.0),
		"«تمام... كده نلعب على نضيف.»",
		"Good... now we play fair.", 3.2],
]
const LINES_OUTRO := [
	["تيتو", Color(0.9, 0.9, 0.95),
		"«عشان تفهم النهاية... لازم ترجع لليوم اللي القصة بدأت فيه فعلًا.»",
		"To understand the ending... you have to return to where the story began.", 5.6],
]

# garden palette
const LAWN := Color(0.16, 0.3, 0.2)
const HEDGE := Color(0.14, 0.34, 0.19)
const STONE := Color(0.52, 0.5, 0.44)
const MARBLE := Color(0.82, 0.8, 0.74)
const WOOD := Color(0.4, 0.27, 0.17)
const LIME := Color(0.62, 0.58, 0.5)  # limestone facade
const VAN_COL := Color(0.3, 0.32, 0.38)
const GLASS := Color(0.55, 0.75, 0.9, 0.3)

var _player: Player2D
var _cam: TitoCamera2D
var _dialogue: DialogueLayer
var _hints: Array = []

# breach set-piece handles
var _breach_done := false
var _door_seal: StaticBody2D = null
# ambush handles
var _ambush_done := false
var _squad_alive := 0
var _exit_bar: StaticBody2D = null
var _locker_done := false
# outro
var _outro := false
var _black: ColorRect = null
var _title: Label = null


func _ready() -> void:
	_build_parallax()
	_build_lighting()
	_build_zone1()
	_build_zone2()
	_build_zone3()
	_build_zone4()
	_build_zone5()
	_build_zone6()
	_build_gameplay()
	_build_prompts()
	_build_outro_overlay()
	var afx := AmbientFx2D.new()
	afx.follow = _cam
	add_child(afx)


# ============================================================ helpers =====
func _tex_sprite(path: String, scale_f: float, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path) as Texture2D
	s.scale = Vector2.ONE * scale_f
	s.centered = false
	s.position = pos
	return s


func _layer(bg: ParallaxBackground, stick: float, child: Node, mirror_x: float) -> ParallaxLayer:
	var l := ParallaxLayer.new()
	l.motion_scale = Vector2(stick, 1.0)
	l.motion_mirroring = Vector2(mirror_x, 0)
	l.add_child(child)
	bg.add_child(l)
	return l


func _poly(points: PackedVector2Array, color: Color, z := 0) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.z_index = z
	add_child(p)
	return p


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


func _ground_prop(name: String, cx: float, target_h: float, z := -1,
		ground := GROUND_Y, tint := Color(1, 1, 1)) -> Sprite2D:
	var s := _tex_sprite(ENV + name + ".png", 1.0, Vector2.ZERO)
	if s.texture == null:
		return s
	var sc := target_h / float(s.texture.get_height())
	s.scale = Vector2(sc, sc)
	s.centered = false
	s.position = Vector2(cx - float(s.texture.get_width()) * sc * 0.5, ground - target_h)
	s.z_index = z
	s.modulate = tint
	add_child(s)
	return s


func _hint(x: float, y: float, ar: String) -> void:
	var l := Label.new()
	l.text = ar
	l.add_theme_font_override("font", load(FONT_BOLD) as Font)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	l.modulate.a = 0.0
	l.position = Vector2(x, y)
	add_child(l)
	_hints.append({"n": l, "c": Vector2(x + 60, y + 10), "done": false})


func _lamp(x: float, y: float, col: Color, energy := 1.6, sc := 3.2) -> void:
	var li := PointLight2D.new()
	li.texture = load(LIGHT_DOT) as Texture2D
	li.color = col
	li.energy = energy
	li.texture_scale = sc
	li.position = Vector2(x, y)
	add_child(li)


func _trigger(x: float, y: float, w: float, h: float, cb: Callable) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	cs.shape = r
	cs.position = Vector2(x + w * 0.5, y + h * 0.5)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(cb)
	return a


# ============================================================ parallax ====
func _build_parallax() -> void:
	var bg := ParallaxBackground.new()
	add_child(bg)
	_layer(bg, 0.04, _tex_sprite(ENV + "night_sky.png", 2.4, Vector2(-1600, -900)), 3302.4)
	for spec in [["cloud_1", -1500.0, -330.0, 1.5], ["cloud_2", -450.0, -400.0, 1.15],
			["cloud_3", 350.0, -290.0, 1.7]]:
		_layer(bg, 0.1, _tex_sprite(ENV + spec[0] + ".png", spec[3], Vector2(spec[1], spec[2])), 1900.0)
	_layer(bg, 0.16, _tex_sprite(ENV + "skyline_far.png", 1.6, Vector2(-1600, -40)), 3123.2)
	# estate enclosure silhouette (dark facades doubling as perimeter walls)
	var wall := _tex_sprite(ENV + "facades_d.png", 1.5, Vector2(-1600, 8))
	wall.modulate = Color(0.35, 0.38, 0.55)
	_layer(bg, 0.72, wall, 2332.5)


func _build_lighting() -> void:
	var cm := CanvasModulate.new()
	cm.color = Color(0.4, 0.46, 0.66)
	add_child(cm)


# ========================================================= ZONE 1 : garden =
func _build_zone1() -> void:
	# lawn baseline + wild grass fringe + the estate boundary wall behind
	_poly(PackedVector2Array([Vector2(0, GROUND_Y), Vector2(1560, GROUND_Y),
		Vector2(1560, 636), Vector2(0, 636)]), LAWN, -3)
	_box2d(0.0, 600.0, 1600.0, 36.0, Color(0, 0, 0, 0))
	for wx in range(60, 1560, 250):
		_ground_prop("wall_stone", wx, 118.0, -3, 600.0, Color(0.55, 0.58, 0.72))
	for gx in range(60, 1560, 195):
		_ground_prop("grass_strip", gx, 26.0, -1)
	# trash container -> wall-kick the 3.5 m perimeter wall
	_box2d(420.0, 540.0, 90.0, 60.0, Color(0, 0, 0, 0))
	_ground_prop("trash_bin", 465.0, 92.0, -1)
	_box2d(480.0, 390.0, 22.0, 210.0, Color(0, 0, 0, 0))
	_prop_centered("wall_stone", 491.0, 388.0, 62.0, -1)
	_poly(PackedVector2Array([Vector2(484, 452), Vector2(498, 452),
		Vector2(498, 600), Vector2(484, 600)]), Color(0.4, 0.39, 0.35), -1)
	_hint(340.0, 470.0, "من على الصندوق: نط + نطّ حيطة فوق السور")
	# hedge labyrinth: sculpted arches with crawl tunnels (slide!)
	for hx in [700.0, 980.0]:
		_box2d(hx, 506.0, 100.0, 44.0, Color(0, 0, 0, 0))
		_ground_prop("hedge_arch", hx + 50.0, 96.0, -1)
	_hint(720.0, 560.0, "زحلقة تحت السياج (اتحداك تعدّي الكشاف)")
	# searchlights sweeping the lawn
	for sx in [820.0, 1130.0]:
		_ground_prop("searchlight_pole", sx, 122.0, -2)
		var cone := Polygon2D.new()
		cone.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(64, 0), Vector2(150, 220), Vector2(-70, 220)])
		cone.color = Color(1.0, 0.95, 0.6, 0.13)
		cone.position = Vector2(sx, 330)
		cone.z_index = -2
		add_child(cone)
		_lamp(sx + 30, 326, Color(1.0, 0.95, 0.6), 1.2, 2.2)
	# dry marble fountain (vault the rims)
	_box2d(1180.0, 568.0, 26.0, 32.0, Color(0, 0, 0, 0))
	_box2d(1314.0, 568.0, 26.0, 32.0, Color(0, 0, 0, 0))
	_ground_prop("fountain_dry", 1260.0, 112.0, -1)
	_hint(1210.0, 520.0, "جري + نط فوق حرف النافورة")
	# wooden trellis climb -> garage roof
	var lad := Ladder2D.new()
	lad.position = Vector2(1454.0, 512.0)
	var lcs := CollisionShape2D.new()
	var lrect := RectangleShape2D.new()
	lrect.size = Vector2(26.0, 176.0)
	lcs.shape = lrect
	lad.add_child(lcs)
	add_child(lad)
	_ground_prop("trellis", 1441.0, 186.0, -2)
	_box2d(1380.0, 420.0, 190.0, 14.0, WOOD, true)  # garage roof (one-way up)
	_hint(1380.0, 470.0, "اطلع العريشة (سهم لفوق على السلم)")


# ========================================================= ZONE 2 : breach =
func _build_zone2() -> void:
	# mansion facade: left wall over the door gate
	_poly(PackedVector2Array([Vector2(1560, 170.0), Vector2(1905, 170.0),
		Vector2(1905, 230.0), Vector2(1560, 230.0)]), LIME, 0)
	# the very doors the squad will ram through
	_ground_prop("doors_mahogany", 1568.0, 188.0, -2, 600.0)
	_prop_centered("column_tall", 1686.0, 150.0, 452.0, -2)
	# the doors will be rammed; keep the gate open until the breach seals it
	_box2d(1560.0, 600.0, 350.0, 36.0, Color(0, 0, 0, 0))  # foyer floor
	_trigger(1640.0, 470.0, 60.0, 130.0, _on_breach_body)
	_hint(1600.0, 540.0, "ادخل القصر... براحة")


# ========================================================= ZONE 3 : foyer ==
func _build_zone3() -> void:
	_box2d(1910.0, 600.0, 700.0, 36.0, Color(0, 0, 0, 0))
	# chandelier pass (one-way hoop until a real pendulum lands)
	_prop_centered("chandelier", 2212.0, 150.0, 162.0, -1)
	_box2d(2168.0, 290.0, 88.0, 10.0, Color(0.66, 0.55, 0.28), true)
	_lamp(2212.0, 300.0, Color(1.0, 0.8, 0.45), 2.0, 2.6)
	_hint(2130.0, 340.0, "من الميزانين انط على النجفة تعدّي بسرعة")
	# marble steps up to the mezzanine (art under the collision)
	for i in 4:
		_box2d(2450.0 + i * 45.0, 600.0 - 55.0 * (i + 1), 45.0, 55.0 * (i + 1), MARBLE)
	_stretch_prop("stairs_marble", 2450.0, 380.0, 182.0, 220.0, -2)
	# mezzanine slab (zones 4-6 all run on it, out to the terrace edge)
	_box2d(1750.0, 380.0, 2550.0, 16.0, LIME)
	# red runner carpet along the whole hall
	for rx in range(1800, 2860, 132):
		_stretch_prop("rug_strip", rx, 368.0, 130.0, 12.0, -2)
	# wall sconces down the hall
	for wx in [1850.0, 2300.0, 2900.0, 3500.0, 4100.0]:
		_lamp(wx, 300.0, Color(1.0, 0.75, 0.4), 1.5, 2.4)
		_prop_centered("sconce", wx, 268.0, 46.0, -2)
	# hall ceiling
	_poly(PackedVector2Array([Vector2(1560, 150), Vector2(4450, 150),
		Vector2(4450, 170), Vector2(1560, 170)]), Color(0.3, 0.28, 0.24), -1)


# ========================================================= ZONE 4 : armory =
func _build_zone4() -> void:
	# security locker against the gallery wall
	_box2d(2940.0, 316.0, 44.0, 64.0, Color(0, 0, 0, 0))
	_ground_prop("locker_metal", 2962.0, 70.0, -1, 380.0)
	_lamp(2962.0, 330.0, Color(0.5, 0.9, 1.0), 1.0, 1.6)
	_trigger(2900.0, 300.0, 130.0, 90.0, _on_locker_body)
	_hint(2880.0, 270.0, "دولاب الأمن")


# ========================================================= ZONE 5 : ambush =
func _build_zone5() -> void:
	# french-window wall: moonlit glass, drawn between the columns
	for i in 6:
		var wx: float = 3120.0 + i * 120.0
		_prop_centered("french_window", wx + 45.0, 172.0, 200.0, -2)
	for cx in [3060.0, 2980.0]:
		_prop_centered("column_tall", cx, 150.0, 452.0, -2)
	_ground_prop("plant_pot", 3080.0, 62.0, -3, 380.0)
	_ground_prop("sideboard", 2668.0, 56.0, -3, 380.0)
	_ground_prop("armchair", 2700.0, 52.0, -3, 380.0)
	_ground_prop("plant_pot", 3820.0, 62.0, -3, 380.0)
	# overturned marble tables (cover)
	_box2d(3340.0, 340.0, 78.0, 40.0, Color(0, 0, 0, 0))
	_ground_prop("table_flipped", 3379.0, 64.0, -1, 380.0)
	_box2d(3560.0, 340.0, 78.0, 40.0, Color(0, 0, 0, 0))
	_ground_prop("table_flipped", 3599.0, 64.0, -1, 380.0)
	# exit barricade (unlocks when the squad falls)
	_exit_bar = _box2d(3860.0, 230.0, 22.0, 166.0, Color(0.5, 0.2, 0.2))
	_trigger(3140.0, 300.0, 50.0, 90.0, _on_ambush_body)
	_hint(3200.0, 250.0, "الزجاج بيتكسر... غطّي ورا الترابيزات!")


# ========================================================= ZONE 6 : terrace =
func _build_zone6() -> void:
	# terrace floor is the same mezzanine slab; balustrade till the gap
	for bx in range(3880, 4280, 104):
		_ground_prop("balustrade", bx + 52.0, 88.0, 0, 380.0)
	_poly(PackedVector2Array([Vector2(3880, 292), Vector2(4280, 292),
		Vector2(4280, 302), Vector2(3880, 302)]), STONE, 1)
	_ground_prop("plant_pot", 3898.0, 60.0, 1, 380.0)
	# broken end + the canal below
	_poly(PackedVector2Array([Vector2(4290, 640), Vector2(4450, 640),
		Vector2(4450, 720), Vector2(4290, 720)]), Color(0.05, 0.12, 0.24), -2)
	_lamp(4220.0, 320.0, Color(1.0, 0.75, 0.45), 1.4, 2.6)
	_trigger(4240.0, 300.0, 46.0, 90.0, _on_balcony_body)


# ========================================================= gameplay ======
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
	if _squad_alive <= 0 and _exit_bar != null:
		var tw := create_tween()
		tw.tween_property(_exit_bar, "position:y", _exit_bar.position.y + 180.0, 1.2) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(_exit_bar.queue_free)


func _build_gameplay() -> void:
	for cx in [1560.0, 2650.0, 3120.0]:
		var cp := Checkpoint2D.new()
		cp.position = Vector2(cx, GROUND_Y)
		add_child(cp)
	# THE STAR
	_player = Player2D.new()
	_player.position = Vector2(60.0, GROUND_Y)
	add_child(_player)
	_player.play_stagger_intro(2.6)
	_cam = TitoCamera2D.new()
	add_child(_cam)
	_cam.set_target(_player)
	_cam.apply_zone_limits(Rect2(WORLD_L, -160.0, WORLD_R - WORLD_L, 880.0))
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
	await get_tree().create_timer(1.4).timeout
	_dialogue.play(LINES_INTRO, Callable(self, "_noop"))


func _build_prompts() -> void:
	pass  # Arabic flags already planted in zone builders


# ============================================================ events ======
func _on_breach_body(body: Node2D) -> void:
	if _breach_done or not body.is_in_group("player"):
		return
	_breach_done = true
	# 1) seal the door line behind the player
	_door_seal = _box2d(1564.0, 230.0, 14.0, 386.0, WOOD)
	# 2) the armored van rams in from the courtyard (visual swoop + rubble)
	var van := _tex_sprite(ENV + "van_armored.png", 1.0, Vector2(1150, 340))
	if van.texture == null:
		return
	var vsc := 84.0 / float(van.texture.get_height())
	van.scale = Vector2(-vsc, vsc)  # nose-first toward the doors
	van.centered = false
	van.modulate = Color(0.85, 0.87, 1.0)
	add_child(van)
	var tw := create_tween()
	tw.tween_property(van, "position:x", 1490.0, 0.5).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(_breach_impact.bind(van))


func _breach_impact(van: Node2D) -> void:
	var ih := get_node_or_null("/root/InputHelper")
	if ih != null and ih.has_method("rumble_large"):
		ih.rumble_large()
	# debris ramp: blocks from the door up to the mezzanine
	_box2d(1580.0, 470.0, 60.0, 130.0, Color(0.45, 0.4, 0.35))
	_box2d(1640.0, 420.0, 70.0, 180.0, Color(0.5, 0.44, 0.37))
	_box2d(1710.0, 380.0, 44.0, 220.0, Color(0.55, 0.5, 0.43))
	# guards deploy from the wreck
	_spawn_enemy(StaffEnforcer.new(), Vector2(1900.0, GROUND_Y), 1810.0, 2150.0)
	_spawn_enemy(ShieldSentry.new(), Vector2(2280.0, GROUND_Y), 2180.0, 2430.0)
	_hint(1770.0, 330.0, "اقتحام! اطلع الرامبة للميزانين")


func _on_locker_body(body: Node2D) -> void:
	if _locker_done or not body.is_in_group("player"):
		return
	_locker_done = true
	_lamp(2962.0, 340.0, Color(0.4, 1.0, 0.7), 1.6, 2.0)
	_dialogue.play(LINES_LOCKER, Callable(self, "_noop"))


func _noop() -> void:
	pass


func _on_ambush_body(body: Node2D) -> void:
	if _ambush_done or not body.is_in_group("player"):
		return
	_ambush_done = true
	# glass shards burst off the panes (cheap white poly spray)
	for i in 10:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(-4, -3), Vector2(4, -2), Vector2(0, 4)])
		shard.color = Color(0.8, 0.9, 1.0, 0.85)
		shard.position = Vector2(3180.0 + randf() * 560.0, 200.0 + randf() * 150.0)
		add_child(shard)
		var stw := create_tween()
		stw.set_parallel()
		stw.tween_property(shard, "position:y", 374.0 + randf() * 40.0,
			0.7 + randf() * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		stw.tween_property(shard, "modulate:a", 0.0, 0.9).set_delay(0.7)
		stw.chain().tween_callback(shard.queue_free)
	var ih := get_node_or_null("/root/InputHelper")
	if ih != null and ih.has_method("rumble_medium"):
		ih.rumble_medium()
	# the squad rappels in
	_track_squad(_spawn_enemy(StaffEnforcer.new(), Vector2(3280.0, MEZZ_Y), 3200.0, 3420.0))
	_track_squad(_spawn_enemy(ShieldSentry.new(), Vector2(3450.0, MEZZ_Y), 3360.0, 3580.0))
	_track_squad(_spawn_enemy(Marksman2D.new(), Vector2(3660.0, MEZZ_Y), 3580.0, 3780.0))
	_track_squad(_spawn_enemy(StaffEnforcer.new(), Vector2(3760.0, MEZZ_Y), 3680.0, 3840.0))


func _on_balcony_body(body: Node2D) -> void:
	if _outro or not body.is_in_group("player"):
		return
	_outro = true
	# cinematic vault: lock controls, arc over the balustrade into the canal
	_player._intro_lock = true
	_player.set_physics_process(false)
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(_player, "global_position:x", 4370.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_player, "global_position:y", 700.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_outro_lines)


func _outro_lines() -> void:
	_dialogue.play(LINES_OUTRO, Callable(self, "_fade_title"))


func _build_outro_overlay() -> void:
	var lay := CanvasLayer.new()
	lay.layer = 30
	add_child(lay)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.size = Vector2(1280, 720)
	lay.add_child(_black)
	_title = Label.new()
	_title.text = "الفصل الأول — THE ORIGIN"
	_title.add_theme_font_override("font", load(FONT_BOLD) as Font)
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_title.modulate.a = 0.0
	_title.position = Vector2(430, 330)
	lay.add_child(_title)


func _fade_title() -> void:
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(_black, "color:a", 1.0, 1.6)
	tw.tween_property(_title, "modulate:a", 1.0, 1.6).set_delay(0.8)


# ---------------------------------------------------------- hint reveal ---
func _stretch_prop(name: String, x: float, y: float, w: float, h: float, z := -2) -> void:
	var s := _tex_sprite(ENV + name + ".png", 1.0, Vector2.ZERO)
	if s.texture == null:
		return
	s.scale = Vector2(w / float(s.texture.get_width()),
		h / float(s.texture.get_height()))
	s.centered = false
	s.position = Vector2(x, y)
	s.z_index = z
	add_child(s)


func _prop_centered(name: String, cx: float, top: float, target_h: float, z := -1) -> void:
	var s := _tex_sprite(ENV + name + ".png", 1.0, Vector2.ZERO)
	if s.texture == null:
		return
	var sc := target_h / float(s.texture.get_height())
	s.scale = Vector2(sc, sc)
	s.centered = false
	s.position = Vector2(cx - float(s.texture.get_width()) * sc * 0.5, top)
	s.z_index = z
	add_child(s)


func _process(_delta: float) -> void:
	if _player == null:
		return
	for h in _hints:
		if not h["done"] and _player.position.distance_to(h["c"]) < 150.0:
			h["done"] = true
			var tw := create_tween()
			tw.tween_property(h["n"], "modulate:a", 0.92, 0.5)
			tw.tween_interval(4.0)
			tw.tween_property(h["n"], "modulate:a", 0.0, 1.2)

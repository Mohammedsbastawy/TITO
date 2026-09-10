## CHAPTER 1 — stub landing scene (the prologue's rewind drops Tito here).
## Full Wasat-El-Balad rebuild comes in a later phase; for now: title card,
## mood, and a live player body so the transition never dead-ends.
extends Node2D

const CAIRO := "res://assets/textures/cairo/"
const FONT_BOLD := "res://assets/fonts/DejaVuSans-Bold.ttf"


func _ready() -> void:
	var sky := Sprite2D.new()
	sky.texture = load(CAIRO + "sky.png") as Texture2D
	sky.scale = Vector2.ONE * 2.4
	sky.centered = false
	sky.position = Vector2(-200, -220)
	add_child(sky)
	var grade := CanvasModulate.new()
	grade.color = Color(0.4, 0.46, 0.72)
	add_child(grade)
	# ground strip
	var g := StaticBody2D.new()
	var gcs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(4200, 120)
	gcs.shape = r
	gcs.position = Vector2(2100, 660)
	g.add_child(gcs)
	add_child(g)
	var gp := Polygon2D.new()
	gp.polygon = PackedVector2Array([
		Vector2(0, 600), Vector2(4200, 600), Vector2(4200, 720), Vector2(0, 720)])
	gp.color = Color(0.13, 0.15, 0.24)
	add_child(gp)
	# title card
	var title := Label2D.new()
	title.text = "الفصل الأول — وسط البلد"
	title.font = load(FONT_BOLD) as Font
	title.font_size = 64
	title.modulate = Color(1.0, 0.85, 0.55)
	title.position = Vector2(300, 240)
	add_child(title)
	var sub := Label2D.new()
	sub.text = "CHAPTER 1 — DOWNTOWN  ·  the day it all truly began"
	sub.font = load(FONT_BOLD) as Font
	sub.font_size = 22
	sub.modulate = Color(0.7, 0.8, 1.0)
	sub.position = Vector2(304, 320)
	add_child(sub)
	var soon := Label2D.new()
	soon.text = "(إعادة بناء الحي بالكامل — المرحلة الجاية)"
	soon.font = load(FONT_BOLD) as Font
	soon.font_size = 20
	soon.modulate = Color(0.55, 0.6, 0.75)
	soon.position = Vector2(304, 360)
	add_child(soon)
	# a live Tito so the player keeps a body after the rewind
	var tito := Player2D.new()
	tito.position = Vector2(140.0, 600)
	add_child(tito)
	var cam := TitoCamera2D.new()
	add_child(cam)
	cam.set_target(tito)
	cam.apply_zone_limits(Rect2(0.0, -140.0, 4200.0, 860.0))
	var hud := VitalityHud.new()
	add_child(hud)
	hud.bind(tito)

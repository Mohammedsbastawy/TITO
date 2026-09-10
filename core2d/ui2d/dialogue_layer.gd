## Cinematic dialogue overlay (2D): letterbox bars + speaker tag + AR line
## + EN subtitle. play(lines) awaits each beat then fires the callback.
## lines: [[speaker:String, tint:Color, ar:String, en:String, secs:float]]
class_name DialogueLayer
extends CanvasLayer

const FONT_BOLD := "res://assets/fonts/DejaVuSans-Bold.ttf"

var _root: Control
var _spk: Label
var _ar: Label
var _en: Label


func _ready() -> void:
	layer = 30
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var top := _bar()
	top.anchor_bottom = 0.0
	top.offset_bottom = 78
	_root.add_child(top)
	var bottom := _bar()
	bottom.anchor_top = 1.0
	bottom.offset_top = -150
	_root.add_child(bottom)
	var font: Font = load(FONT_BOLD)
	_spk = _label(Vector2(0.08, -140), Vector2(0.92, -104), 24, Color.WHITE, font)
	_ar = _label(Vector2(0.06, -100), Vector2(0.94, -54), 30, Color(1.0, 0.95, 0.85), font, true)
	_en = _label(Vector2(0.08, -48), Vector2(0.92, -10), 17, Color(0.62, 0.66, 0.78), font, true)


func _bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


func _label(lrtb_pos: Vector2, lrtb_end: Vector2, size: int, tint: Color,
		font: Font, centered := false) -> Label:
	var l := Label.new()
	l.anchor_left = lrtb_pos.x
	l.anchor_right = lrtb_end.x
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_top = lrtb_pos.y
	l.offset_bottom = lrtb_end.y
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", tint)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(l)
	return l


func play(lines: Array, on_done: Callable) -> void:
	_root.visible = true
	for item in lines:
		_spk.text = item[0]
		_spk.add_theme_color_override("font_color", item[1])
		_ar.text = item[2]
		_en.text = item[3]
		await get_tree().create_timer(item[4]).timeout
	_root.visible = false
	on_done.call()


func set_bars_only(v: bool) -> void:
	_root.visible = v
	_spk.text = ""
	_ar.text = ""
	_en.text = ""

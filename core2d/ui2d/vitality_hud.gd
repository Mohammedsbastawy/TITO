## Player vitality HUD: comic-panel pips top-left. Bind to the player;
## refreshes on every damage tick (amount 0 = full refresh, e.g. respawn).
class_name VitalityHud
extends CanvasLayer

@export var pip_size := Vector2(18, 18)
@export var pip_gap := 4.0

var _pips: Array[ColorRect] = []


func bind(player: Player2D) -> void:
	for p in _pips:
		p.queue_free()
	_pips.clear()
	for i in player.hp_max:
		var r := ColorRect.new()
		r.custom_minimum_size = pip_size
		r.position = Vector2(14 + i * (pip_size.x + pip_gap), 14)
		r.color = Color(0.9, 0.25, 0.3)
		add_child(r)
		_pips.append(r)
	_refresh(player.hp)
	player.damaged.connect(func(_a: int, hp: int) -> void: _refresh(hp))


func _refresh(hp: int) -> void:
	for i in _pips.size():
		_pips[i].color = Color(0.9, 0.25, 0.3) if i < hp else Color(0.16, 0.17, 0.24, 0.8)

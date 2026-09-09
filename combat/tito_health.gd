## Health component. Attach to any Node (body) that can take damage.
class_name TitoHealth
extends Node

signal died
signal damaged(amount: int, hp: int)

@export var max_hp := 3
var hp := 3


func _ready() -> void:
	hp = max_hp


func take_damage(amount: int) -> void:
	hp -= amount
	damaged.emit(amount, hp)
	if hp <= 0:
		died.emit()

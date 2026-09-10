## Damage-receiving volume. Lives as a child of an actor that implements
## take_damage(amount, from_pos). Enemies' HitBox2D equivalents scan for
## these; the actor's own take_damage decides (parry, i-frames, shields...).
class_name HurtBox2D
extends Area2D


func _ready() -> void:
	collision_layer = 4         # hurtbox layer
	collision_mask = 0
	monitoring = false
	monitorable = true

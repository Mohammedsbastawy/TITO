## Zone-3 lesson: a sentry with a full-body barrier. Frontal punches CLANG
## off — dash-roll behind him, or drop a ground-pound over the shield top.
## He never staggers from blocked hits; his own swing leaves him open.
class_name ShieldSentry
extends Enemy2D

var _plate: Polygon2D


func _ready() -> void:
	walk_speed = 42.0
	run_speed = 110.0
	attack_range = 42.0
	attack_cooldown = 1.4
	windup_time = 0.55
	recover_time = 0.65
	armor = true          # light hits never stagger him
	max_hp = 5
	tint = Color(0.4, 0.45, 0.6)
	super()
	_build_shield()


func _build_shield() -> void:
	_plate = Polygon2D.new()
	_plate.polygon = PackedVector2Array([
		Vector2(12, -62), Vector2(24, -58), Vector2(26, -8), Vector2(14, -2)])
	_plate.color = Color(0.12, 0.14, 0.2)
	_visual.add_child(_plate)
	# glowing visor slit so the front face reads at a glance
	var slit := Polygon2D.new()
	slit.polygon = PackedVector2Array([
		Vector2(22, -48), Vector2(25, -48), Vector2(25, -44), Vector2(22, -44)])
	slit.color = Color(1.0, 0.35, 0.2)
	_visual.add_child(slit)


## Frontal = blocked. Overhead (pound from above) or backside = connects.
func take_damage(amount: int, from_pos = null) -> void:
	if state == State.DEAD:
		return
	var exposed := state == State.STAGGER \
		or (state == State.ATTACK and _phase in [Phase.WINDUP, Phase.STRIKE])
	if not exposed and from_pos is Vector2:
		var fp := from_pos as Vector2
		var overhead := fp.y < global_position.y - 48.0
		var frontal := absf(fp.x - global_position.x) > 4.0 \
			and signf(fp.x - global_position.x) == _dir
		if not overhead and frontal:
			_block_hit()
			return
	super(amount, from_pos)


func _block_hit() -> void:
	_flash_t = 0.1
	velocity.x = -_dir * 60.0
	if is_instance_valid(_player):
		_seen = true
		_last_seen = _player.global_position
	var ih := get_node_or_null("/root/InputHelper")
	if ih != null and ih.has_method("rumble_small"):
		ih.rumble_small()  # the CLANG travels up your wrists


func _begin_strike() -> void:
	# shield bash: heavy shove
	_hit_shape.position = Vector2(22.0 * _dir, -26)
	(_hit_shape.shape as RectangleShape2D).size = Vector2(34, 34)
	_hitbox.arm(attack_damage, Vector2(420.0 * _dir, -120.0), attack_active)

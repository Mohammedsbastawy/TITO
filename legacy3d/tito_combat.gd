## Shared 3D combat primitives for Tito: The Crow's Curse.
class_name TitoCombat
extends Object

const GROUP_HITBOX := "hitbox"
const GROUP_HURTBOX := "hurtbox"

## Apply damage from the attacker's HitBox to every overlapping hurtbox.
## already_hit (optional) dedupes victims across one swing's active frames.
## damage <= 0 reads attack_damage off the attacker (defaulting to 1).
## The attacker's position is passed along so victims can be knocked back
## AWAY from the blow. Returns the number of NEW victims hit this call.
static func try_hit(attacker: Node3D, hitbox_name := "HitBox", victim_groups := ["player"], already_hit := {}, damage := -1) -> int:
	var hits := 0
	var hb := attacker.get_node_or_null(NodePath(hitbox_name))
	if hb == null or not (hb is Area3D):
		return 0
	var dmg := damage
	if dmg <= 0:
		var dv = attacker.get("attack_damage")
		dmg = int(dv) if dv != null else 1
	for area in (hb as Area3D).get_overlapping_areas():
		if not area.is_in_group(GROUP_HURTBOX):
			continue
		var victim := _owner_of(area)
		if victim == null or victim == attacker:
			continue
		if not _in_groups(victim, victim_groups):
			continue
		var key := victim.get_instance_id()
		if already_hit.has(key):
			continue
		already_hit[key] = true
		if victim.has_method("take_damage"):
			victim.take_damage(dmg, attacker.global_position)
			hits += 1
	return hits

static func _owner_of(hurtbox: Node) -> Node:
	var n := hurtbox
	while n != null:
		if n.has_method("take_damage"):
			return n
		n = n.get_parent()
	return null

static func _in_groups(node: Node, groups: Array) -> bool:
	for g in groups:
		if node.is_in_group(g):
			return true
	return false

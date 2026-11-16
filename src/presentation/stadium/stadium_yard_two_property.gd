class_name StadiumYardTwoProperty
extends StadiumPropertyGeometry
## Candidate membership guard. owned_copy is only the authentic NPC contact alias, never human
## stock.

const MEMBERS: Dictionary = {
	"npc-candidate:AY-02:RECEIVER-PRIMARY": "ST-079",
	"npc-candidate:AY-02:SIDE-SEAT-L": "ST-027",
	"npc-candidate:AY-02:SIDE-SEAT-R": "ST-027",
	"npc-candidate:AY-02:O-R1": "ST-001"
}

var lab_ref: WeakRef
var actor_cutaway: StadiumNpcRetainedActorCutaway = StadiumNpcRetainedActorCutaway.new()

var _members: Dictionary = {}
var _bodies: Dictionary = {}
var _containers: Dictionary = {}
var _model_bodies: Dictionary = {}


func bind_model(identity: String, model: Node3D) -> bool:
	if (
		not MEMBERS.has(identity)
		or _members.has(identity)
		or model == null
		or model.get_parent() != self
		or not is_same(objects.get(identity), model)
		or not model.has_node("Collision")
		or not _meta_equals(model, "candidate_instance", identity)
		or not _meta_equals(model, "candidate_site", identity.trim_prefix("npc-candidate:AY-02:"))
		or not _meta_equals(model, "candidate_host", "field")
		or not _meta_equals(model, "stadium_item", MEMBERS.get(identity, ""))
	):
		return false
	var container: Node = model.get_node("Collision")
	if container.get_child_count() == 0:
		return false
	_members[identity] = model
	_containers[identity] = container
	_model_bodies[identity] = container.get_children()
	model.set_meta("owned_copy", identity)
	for body: StaticBody3D in model.get_node("Collision").get_children():
		body.set_meta("candidate_instance", identity)
		body.set_meta("owned_copy", identity)
		body.set_meta(
			"ball_surface",
			(
				&"stadium_receiver"
				if model.get_meta("stadium_item") == "ST-079"
				else (
					&"stadium_live_object"
					if model.get_meta("stadium_item") == "ST-001"
					else &"stadium_scenery"
				)
			)
		)
		_bodies[body] = {
			"instance": identity,
			"model": model,
			"surface": body.get_meta("surface_id"),
			"role": body.get_meta("surface_role"),
			"item": model.get_meta("stadium_item"),
			"children": body.get_children()
		}

	return true


func model_intact(identity: String) -> bool:
	var model: Node3D = _members.get(identity)
	var container: Node = _containers.get(identity)
	return (
		is_instance_valid(model)
		and is_instance_valid(container)
		and is_same(objects.get(identity), model)
		and model.get_parent() == self
		and model.get_node_or_null("Collision") == container
		and container.get_children() == _model_bodies[identity]
	)


func contact_identity(body: Node) -> Dictionary:
	if not _bodies.has(body):
		return {}
	var row: Dictionary = _bodies[body]
	var model: Node3D = row.model
	if (
		not is_instance_valid(model)
		or not is_same(objects.get(row.instance), model)
		or _members.get(row.instance) != model
		or model.get_parent() != self
		or not model_intact(row.instance)
		or body.get_children() != row.children
		or not _meta_equals(body, "owned_copy", row.instance)
		or not _meta_equals(model, "owned_copy", row.instance)
		or not _meta_equals(model, "candidate_instance", row.instance)
		or not _meta_equals(body, "candidate_instance", row.instance)
		or not _meta_equals(model, "stadium_item", row.item)
		or not _meta_equals(body, "stadium_item", row.item)
		or not _meta_equals(body, "surface_id", row.surface)
		or not _meta_equals(body, "surface_role", row.role)
	):
		return {}
	return row


func _ball_contact(body: Node, ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	var row: Dictionary = contact_identity(body)
	if row.is_empty():
		return
	super._ball_contact(body, ball, resolver)


static func _meta_equals(node: Node, key: String, expected: String) -> bool:
	if not node.has_meta(key):
		return false
	var value: Variant = node.get_meta(key)
	return value is String and value == expected


func _exit_tree() -> void:
	actor_cutaway.restore_all()
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab == null:
		return
	if lab._camera_director is StadiumYardTwoCameraDirector:
		var camera: StadiumYardTwoCameraDirector = (
			lab._camera_director as StadiumYardTwoCameraDirector
		)
		if camera.actor_cutaway == actor_cutaway:
			camera.actor_cutaway = null

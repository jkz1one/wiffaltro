class_name StadiumNpcYardThreeV1
extends RefCounted
## Detached correspondence ONLY. No property adapter, lab installer, receiver or runtime wrapper.
## Retained AY-01 infrastructure is reused without editing its literal or geometry.


static func build() -> StadiumNpcYardV1:
	var property: StadiumNpcYardV1 = StadiumNpcYardV1.build()
	property.name = "AY03Revision1Correspondence"
	property.field.id = &"field.npc_venue"
	property.field.display_name = "NPC Venue"
	property.set_meta("ay03_candidate_correspondence_only", true)
	var objects: Dictionary = {}
	var beams: Dictionary = StadiumNpcYardThreePosesV1.beams()
	for row: Dictionary in StadiumNpcYardThreeCandidateV1.definition().instances:
		var model: Node3D
		if row.item == "ST-080":
			model = property.objects["npc:AY-01:r1:" + row.site]
		else:
			model = StadiumNpcYardThreeLightV1.create()
			model.name = row.site
			model.set_meta("site", row.site)
			model.get_node("FieldLight").transform = StadiumNpcYardThreePosesV1.transform(
				beams[row.site])
			property.add_child(model)
		model.transform = StadiumNpcYardThreePosesV1.transform(row.transform)
		model.set_meta("npc_instance", row.instance)
		model.set_meta("npc_site", row.site)
		model.set_meta("npc_host", row.host)
		for body: StaticBody3D in model.get_node("Collision").get_children():
			body.set_meta("npc_instance", row.instance)
		objects[row.instance] = model
	property.objects = objects
	return property


static func surface() -> Dictionary:
	# The reused node class still exposes its historical AY-01 constant. This explicit new
	# semantic recipe binds AY-03 without revising that retained constant or physical surface.
	var result: Dictionary = StadiumNpcYardV1.SURFACE.duplicate(true)
	result.id = "AY-03-default-backyard-v1"
	return result


static func receiver() -> Dictionary:
	return StadiumNpcYardV1.RECEIVER.duplicate(true)


static func routing() -> Dictionary:
	return StadiumNpcYardV1.ROUTING.duplicate(true)

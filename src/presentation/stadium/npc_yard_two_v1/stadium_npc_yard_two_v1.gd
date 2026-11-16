class_name StadiumNpcYardTwoV1
extends Node3D
## Detached AY02/r1 construction only. Not StadiumPropertyGeometry or a runtime installer.
## Retained AY01 ground/boundary/seating plus exact qualified starter-model leaf.

const PREFIX: String = "npc:AY-02:r1:"
const ORDER: Array[String] = ["RECEIVER-PRIMARY", "SIDE-SEAT-L", "SIDE-SEAT-R", "O-R1"]
var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "backyard"


static func build() -> StadiumNpcYardTwoV1:
	var property: StadiumNpcYardTwoV1 = StadiumNpcYardTwoV1.new()
	property.name = "AY02Revision1Correspondence"
	property.set_meta("npc_correspondence_only", true)
	property._build()
	return property


static func surface() -> Dictionary:
	return StadiumNpcYardTwoContractV1.canonical().surface


static func receiver() -> Dictionary:
	return StadiumNpcYardTwoContractV1.canonical().receiver


static func routing() -> Dictionary:
	# Archival source identity is deliberately retained in this descriptive recipe.
	return StadiumNpcYardTwoContractV1.canonical().routing


func route_obstacles() -> Array[Dictionary]:
	# Same original field-local blocker centers/radii, with explicit immutable identity mapping.
	# The paid receiver has clearance but contributes no extra live-capacity unit.
	var result: Array[Dictionary] = []
	for site: String in ["RECEIVER-PRIMARY", "O-R1"]:
		var model: Node3D = objects[PREFIX + site]
		var half: Vector2 = Vector2(0.30, 0.43) if site == "RECEIVER-PRIMARY" else Vector2(0.175, 0.175)
		result.append({"center": model.position, "radius": half.length() + 0.32,
			"copy": PREFIX + site})
	return result


func _build() -> void:
	field = FieldDefinition.new()
	for key: String in StadiumNpcYardV1.FIELD:
		field.set(key, StadiumNpcYardV1.FIELD[key])
	field.id = &"field.npc_venue"
	field.display_name = "NPC Venue"
	# Reuse retained surface geometry directly, without reconstructing dimensions/materials.
	var infrastructure: StadiumNpcYardV1 = StadiumNpcYardV1.new()
	infrastructure.field = field
	infrastructure._surface()
	for child: Node in infrastructure.get_children():
		infrastructure.remove_child(child)
		add_child(child)
	infrastructure.free()
	var boundary: StadiumNpcYardBoundaryV1 = StadiumNpcYardBoundaryV1.new()
	boundary.name = "BoundaryGraph"
	boundary.build()
	add_child(boundary)
	var rows: Dictionary = {}
	for row: Dictionary in StadiumNpcYardTwoCandidateV1.definition().instances:
		rows[row.site] = row
	for site: String in ORDER:
		var row: Dictionary = rows[site]
		var model: Node3D = StadiumNpcYardSeatingV1.create(row.item) if row.item == "ST-027" else (
			StadiumNpcYardTwoStarterV1.create(row.item))
		model.name = site
		model.transform = StadiumNpcYardTwoContractV1.transform(row.transform)
		model.set_meta("npc_instance", row.instance)
		model.set_meta("npc_site", site)
		model.set_meta("npc_host", row.host)
		add_child(model)
		objects[row.instance] = model
		for body: StaticBody3D in model.get_node("Collision").get_children():
			body.set_meta("npc_instance", row.instance)
			body.set_meta("ball_surface", &"stadium_receiver" if row.item == "ST-079" else (
				&"stadium_live_object" if row.item == "ST-001" else &"stadium_scenery"))

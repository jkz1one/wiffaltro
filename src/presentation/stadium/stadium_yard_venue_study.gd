class_name StadiumYardVenueStudy
extends RefCounted
## Working AY-01. Authoring content only; never a human purchase, grant or season registry.

const VERSION: int = 1
const SITES: Array[String] = ["SC-L1", "SC-L2", "SC-R1", "SC-R2"]
const SOURCES: Dictionary = {
	"chair": "res://src/presentation/stadium/stadium_seating_models.gd",
	"template": "res://src/presentation/stadium/stadium_property_geometry.gd",
	"boundary": "res://src/presentation/stadium/stadium_boundary_prototype.gd",
	"camera": "res://src/presentation/stadium/stadium_yard_field_visibility.gd",
	"receiver": "res://src/presentation/ball/pitch_flight_actor.gd",
	"receiver_visual": "res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd",
	"field": "res://src/content/fields/starter_field.tres"
}


static func pose(site: String) -> Transform3D:
	if not SITES.has(site):
		return Transform3D.IDENTITY
	# Exact quarter turns, without trigonometric residue in persisted transforms.
	var sign_value: float = 1.0 if site.begins_with("SC-L") else -1.0
	return Transform3D(Basis(Vector3(0, 0, -sign_value), Vector3.UP,
		Vector3(sign_value, 0, 0)), StadiumSeatingLayout.SITES[site].position)


static func canonical() -> Dictionary:
	var rows: Array[Dictionary] = []
	for site: String in SITES:
		rows.append({"instance": "npc-candidate:AY-01:" + site, "item": "ST-080", "site": site,
			"model": "spectator-chair-v%d" % StadiumSeatingModels.VERSION,
			"transform": components(pose(site)), "role": "DECORATIVE_AFTER_TERMINAL"})
	var segments: Array[Dictionary] = []
	for segment: Dictionary in StadiumBoundaryGraph.segments():
		segments.append({"id": segment.id, "a": [segment.a.x, segment.a.y],
			"b": [segment.b.x, segment.b.y], "height": segment.height,
			"role": segment.role, "priority": segment.priority})
	var hashes: Dictionary = {}
	for key: String in SOURCES:
		hashes[key] = FileAccess.get_sha256(SOURCES[key])
	var prices: Dictionary = StadiumCatalog.item("ST-080")
	var blueprint: int = int(prices.blueprint_price)
	var copies: int = int(prices.copy_price) * 4
	return {"version": VERSION, "id": "AY-01", "status": "CANDIDATE", "mapping": "WORKING",
		"kind": "npc-authored-candidate", "property": "backyard", "items": rows,
		"blueprint_entitlements": ["ST-080"], "live_units": 0, "model_sources": hashes,
		"boundary": {"id": StadiumBoundaryGraph.ID, "signature": StadiumBoundaryGraph.signature(),
			"segments": segments, "thickness": StadiumBoundaryGraph.THICKNESS},
		"receiver": {"id": "RX-PRIMARY-DEFAULT-v1", "configuration": "RX-DEFAULT-00",
			"site": "RECEIVER-PRIMARY", "catalog_item": "", "pitch_surfaces": [],
			"batted_surfaces": [], "transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -1.05],
			"plane_z": PitchFlightActor.RECEIVER_PLANE_Z, "visible_model": "debug-only",
			"min_travel": PitchFlightActor.MIN_RECEIVER_TRAVEL_SECONDS,
			"max_travel": PitchFlightActor.MAX_RECEIVER_TRAVEL_SECONDS,
			"hold": PitchFlightActor.RECEIVER_HOLD_SECONDS},
		"surface": {"version": 1, "id": "AY-01-default-backyard-v1", "grass": "default",
			"ground": "default", "lines": "default", "geometry": "flat", "styles": [],
			"bounds": [-26, -10, 52, 42], "physics": "unchanged-reference-field"},
		"routing": {"version": 1, "boundary": StadiumBoundaryGraph.ID,
			"defender_radius": StadiumBoundaryGraph.DEFENDER_RADIUS, "live_obstacles": []},
		"environment": {"target_slots": ["13:10", "16:10"], "target_weather": ["clear"],
			"certificates": [], "night_eligible": false},
		"endowment": {"price_version": StadiumCatalog.signature(), "blueprint_value": blueprint,
			"copy_value": copies, "land_value": 0, "total_value": blueprint + copies,
			"spendable": false, "purpose": "content-comparison-only"}}


static func build() -> StadiumPropertyGeometry:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	property.name = "AY01Candidate"
	# Empty human grammar is used only to build free infrastructure. No starter/purchase is minted.
	if not property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new()):
		property.free()
		return null
	if StadiumBoundaryRuntime.assemble(property) == null:
		property.free()
		return null
	for row: Dictionary in canonical().items:
		var model: Node3D = StadiumSeatingModels.create(row.item)
		model.name = row.site
		model.transform = pose(row.site)
		model.set_meta("candidate_instance", row.instance)
		model.set_meta("candidate_site", row.site)
		property.add_child(model)
		property.objects[row.instance] = model
		for body: Node in model.get_node("Collision").get_children():
			body.set_meta("candidate_instance", row.instance)
	property.set_meta("candidate_venue", canonical())
	return property


static func components(transform: Transform3D) -> Array[float]:
	var result: Array[float] = []
	for vector: Vector3 in [transform.basis.x, transform.basis.y, transform.basis.z, transform.origin]:
		result.append_array([vector.x, vector.y, vector.z])
	return result

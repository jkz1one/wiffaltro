class_name StadiumExpandedVenueStudy
extends RefCounted
## Working AE-01 Deeper Center. Exact NPC candidate, without human ownership or paid receipts.

const COUNTS: Dictionary = {"ST-024": 22, "ST-026": 1, "ST-025": 1, "ST-028": 2, "ST-039": 1}
const SITES: Array[String] = [
	"RECEIVER-PRIMARY", "RECEIVER-CATCH", "SIDE-SEAT-L", "SIDE-SEAT-R", "SCORE-SMALL"
]
const ITEMS: Array[String] = ["ST-026", "ST-025", "ST-028", "ST-028", "ST-039"]
const SOURCES: Array[String] = [
	"stadium_wall_panel_models",
	"stadium_recipe_boundary_body",
	"stadium_target_models",
	"stadium_net_models",
	"stadium_paired_receiver",
	"stadium_bleacher_models",
	"stadium_club_models",
	"stadium_expanded_boundary",
	"stadium_expanded_property",
	"stadium_expanded_camera_director",
	"stadium_expanded_lab",
	"stadium_expanded_venue_study"
]


static func pose(site: String) -> Transform3D:
	match site:
		"RECEIVER-PRIMARY":
			return Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.05))
		"RECEIVER-CATCH":
			return Transform3D(Basis.IDENTITY, Vector3(0, 0, -2.20))
		"SIDE-SEAT-L":
			return Transform3D(
				Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT), Vector3(-24, 0, 12.5)
			)
		"SIDE-SEAT-R":
			return Transform3D(
				Basis(Vector3(0, 0, 1), Vector3.UP, Vector3.LEFT), Vector3(24, 0, 12.5)
			)
		"SCORE-SMALL":
			return Transform3D(
				Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(-20, 0, 30)
			)
	return Transform3D.IDENTITY


static func canonical() -> Dictionary:
	var rows: Array[Dictionary] = []
	for row: Dictionary in StadiumWallRecipes.back("deeper_center", "ST-024"):
		rows.append(_row(row.item, row.socket, StadiumWallRecipes.placement(row), row.span))
	for index in range(SITES.size()):
		rows.append(_row(ITEMS[index], SITES[index], pose(SITES[index])))
	var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create("deeper_center")
	var intersections: Array[Dictionary] = []
	for socket: Dictionary in StadiumFoulPoleSites.rows(graph):
		intersections.append(
			{
				"side": socket.site,
				"position": [socket.position.x, 0, socket.position.z],
				"segment": socket.segment,
				"physical_pole": false
			}
		)
	var hashes: Dictionary = {}
	for source: String in SOURCES:
		hashes[source] = FileAccess.get_sha256("res://src/presentation/stadium/" + source + ".gd")
	for source: String in [
		"stadium_wall_recipes", "stadium_recipe_boundary", "stadium_expanded_fixture_study"
	]:
		hashes[source] = FileAccess.get_sha256("res://src/gameplay/stadium/" + source + ".gd")
	return {
		"version": 1,
		"id": "AE-01",
		"status": "CANDIDATE",
		"mapping": "WORKING",
		"kind": "npc-authored-candidate",
		"property": "expanded",
		"items": rows,
		"live_units": 0,
		"blueprint_entitlements": COUNTS.keys(),
		"model_sources": hashes,
		"boundary":
		{
			"id": graph.identity(),
			"signature": graph.signature(),
			"recipe": "deeper_center",
			"paid": "back-only",
			"template": ["sides", "rear"],
			"foul_intersections": intersections
		},
		"receiver":
		{
			"id": "RX-TARGET-NET-026025-v2",
			"archival_net_site": "RECEIVER-CATCH",
			"runtime_net_alias": "RECEIVER-NET",
			"blockout": StadiumNetModels.BLOCKOUT,
			"net_world_z": [-3.05, -2.16],
			"clearance": 0.435
		},
		"surface":
		{
			"geometry": "flat",
			"grass": "default",
			"ground": "default",
			"markings": "default",
			"bounds": [-32, -16, 64, 54]
		},
		"environment":
		{
			"target_slots": ["13:10", "16:10"],
			"target_weather": ["clear"],
			"certificates": [],
			"night_eligible": false
		},
		"endowment":
		{
			"blueprint_value": 1710,
			"copy_value": 1220,
			"land_value": 600,
			"total_value": 3530,
			"price_version": StadiumCatalog.signature(),
			"spendable": false,
			"purpose": "content-comparison-only"
		}
	}


static func _row(
	item: String, site: String, transform: Transform3D, span: String = ""
) -> Dictionary:
	var components: Array[float] = []
	for vector: Vector3 in [
		transform.basis.x, transform.basis.y, transform.basis.z, transform.origin
	]:
		components.append_array([vector.x, vector.y, vector.z])
	return {
		"instance": "npc-candidate:AE-01:" + site,
		"item": item,
		"site": site,
		"transform": components,
		"span": span
	}


static func build() -> StadiumExpandedProperty:
	var property: StadiumExpandedProperty = StadiumExpandedProperty.new()
	if not property.build("expanded", StadiumStarterLayout.empty(), StadiumStock.new()):
		property.free()
		return null
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumExpandedBoundary = StadiumExpandedBoundary.new()
	boundary.name = "BoundaryGraph"
	property.add_child(boundary)
	if not boundary.build():
		property.free()
		return null
	for socket: Dictionary in StadiumFoulPoleSites.rows(boundary.graph):
		var side: int = -1 if socket.site == "FOUL-POLE-L" else 1
		var line: Node3D = property.get_node("FoulLine" + str(side))
		var end: Vector3 = socket.position
		line.position = end / 2 + Vector3(0, 0.02, 0)
		line.rotation.y = atan2(end.x, end.z)
		var mesh: MeshInstance3D = line.get_child(0)
		(mesh.mesh as BoxMesh).size = Vector3(0.055, 0.025, end.length())
	for index in range(SITES.size()):
		var item: String = ITEMS[index]
		var site: String = SITES[index]
		var model: Node3D = (
			StadiumTargetModels.create()
			if item == "ST-026"
			else (
				StadiumNetModels.create()
				if item == "ST-025"
				else (
					StadiumBleacherModels.create(item)
					if item == "ST-028"
					else StadiumClubModels.create(item)
				)
			)
		)
		var id: String = "npc-candidate:AE-01:" + site
		model.transform = pose(site)
		model.set_meta("candidate_instance", id)
		model.set_meta("candidate_site", site)
		# Existing receiver APIs use this key as a contact identity, never as purchase authority.
		model.set_meta("owned_copy", id)
		model.set_meta("site", "RECEIVER-NET" if site == "RECEIVER-CATCH" else site)
		property.add_child(model)
		property.objects[id] = model
		for body: StaticBody3D in model.get_node("Collision").get_children():
			body.set_meta("owned_copy", id)
		if item == "ST-039":
			property.display = model.get_node("Visual/ScoreDisplay")
	property.set_meta("candidate_venue", canonical())
	return property

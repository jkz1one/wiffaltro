class_name StadiumClubVenueStudy
extends RefCounted
## AC-01 complete candidate assembly. No human unlock history, wallet or active venue eligibility.

const VERSION: int = 1
const COUNTS: Dictionary = {"ST-065": 23, "ST-022": 16, "ST-023": 16,
	"ST-074": 2, "ST-021": 2, "ST-026": 1, "ST-073": 1, "ST-029": 4, "ST-053": 2, "ST-039": 1}


static func build(host: Node3D,
	supplied: StadiumPropertyGeometry = null) -> StadiumPropertyGeometry:
	if host == null or not host.is_inside_tree():
		return null
	var property: StadiumPropertyGeometry = supplied if supplied != null else (
		StadiumPropertyGeometry.new())
	property.name = "AC01Candidate"
	host.add_child(property)
	if not property.build("club", StadiumStarterLayout.empty(), StadiumStock.new_club()):
		property.queue_free()
		return null
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumClubBoundaryStudy = StadiumClubBoundaryStudy.new()
	boundary.name = "ClubBoundary"
	property.add_child(boundary)
	if not boundary.build("straight"):
		property.queue_free()
		return null
	var models: Array[Node3D] = boundary.items.duplicate()
	for site: String in StadiumBaselineSites.SITES:
		var stand: Node3D = StadiumBaselineStandModels.lower()
		property.add_child(stand)
		stand.transform = StadiumBaselineSites.pose(site)
		stand.set_meta("candidate_site", site)
		models.append(stand)
		if site.ends_with("2"):
			var roof: Node3D = StadiumBaselineStandModels.lower_canopy()
			property.add_child(roof)
			roof.transform = stand.transform
			roof.set_meta("candidate_site", site + ".ROOF-LOWER")
			models.append(roof)
	var board: Node3D = StadiumClubModels.create("ST-039")
	property.add_child(board)
	board.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-20, 0, 30))
	board.set_meta("candidate_site", "SCORE-SMALL")
	models.append(board)
	var record: Dictionary = _record(models, boundary)
	if record.is_empty():
		property.queue_free()
		return null
	property.set_meta("candidate_venue", record)
	return property


static func _record(models: Array[Node3D], boundary: StadiumClubBoundaryStudy) -> Dictionary:
	var counts: Dictionary = {}
	var rows: Array[Dictionary] = []
	for model: Node3D in models:
		var item: String = model.get_meta("stadium_item", "")
		var site: String = model.get_meta("candidate_site", "")
		if not COUNTS.has(item) or site.is_empty():
			return {}
		counts[item] = counts.get(item, 0) + 1
		var id: String = "npc-candidate:AC-01:%s:%02d" % [item, counts[item]]
		model.set_meta("candidate_instance", id)
		var pose: Transform3D = model.global_transform
		var transform: Array[float] = []
		for vector: Vector3 in [pose.basis.x, pose.basis.y, pose.basis.z, pose.origin]:
			transform.append_array([vector.x, vector.y, vector.z])
		rows.append({"instance": id, "item": item, "site": site, "transform": transform})
	if not ClubCareer.same(counts, COUNTS):
		return {}
	var blueprint_cost: int = 0
	var copy_cost: int = 0
	for item: String in COUNTS:
		var entry: Dictionary = StadiumCatalog.item(item)
		blueprint_cost += int(entry.blueprint_price)
		copy_cost += int(entry.copy_price) * int(COUNTS[item])
	var land_cost: int = int(StadiumCatalog.LAND.expanded.price) + int(StadiumCatalog.LAND.club.price)
	return {"version": VERSION, "id": "AC-01", "status": "CANDIDATE", "property": "club",
		"source": "npc-authored-candidate", "live_units": 0, "items": rows,
		"boundary": boundary.graph.signature(), "catalog": StadiumCatalog.signature(),
		"models": {"net": StadiumReceiverNetModels.VERSION, "pole": StadiumFoulPoleModels.VERSION,
			"dugout": StadiumConcreteDugoutModels.VERSION, "lower": StadiumBaselineStandModels.VERSION},
		"environment_certificates": [], "blueprint_value": blueprint_cost, "copy_value": copy_cost,
		"land_value": land_cost, "endowment_value": blueprint_cost + copy_cost + land_cost}


static func encode(record: Dictionary) -> String:
	# Exact authored transforms must not lose precision in the default short JSON representation.
	return JSON.stringify(record, "", true, true)

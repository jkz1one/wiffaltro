class_name StadiumGrandIIVenueStudy
extends RefCounted
## Exact CY Grand II composition. Unqualified19:10/clear; no production admission.

const VERSION: int = 1
const ID: String = "GRAND-II"
const OWNER: String = "npc-venue:grandstand-gardens:grand-ii-v1"
const BOARD_SITE: String = "SCORE-SMALL"
const COUNTS: Dictionary = {
	"ST-065": 23,
	"ST-022": 16,
	"ST-023": 16,
	"ST-074": 2,
	"ST-021": 2,
	"ST-026": 1,
	"ST-073": 1,
	"ST-029": 4,
	"ST-081": 5,
	"ST-083": 3,
	"ST-082": 3,
	"ST-085": 1,
	"ST-088": 1,
	"ST-039": 1,
	"ST-038": 6
}
const SOURCES: Array[String] = [
	"src/presentation/stadium/stadium_grand_ii_venue_study.gd",
	"src/presentation/stadium/stadium_grand_ii_property.gd",
	"src/presentation/stadium/stadium_grand_ii_lab.gd",
	"src/gameplay/stadium/stadium_grand_ii_fixture_study.gd",
	"src/presentation/stadium/stadium_curved_stack_models.gd",
	"src/gameplay/stadium/stadium_curved_stack_sites.gd",
	"src/presentation/stadium/stadium_lower_transition_models.gd",
	"src/gameplay/stadium/stadium_lower_transition_sites.gd"
]


static func canonical() -> Dictionary:
	# Reuse the exact qualified shared infrastructure, guard-v2 and dormant rig.
	# Old canonical source and its75-copy guard remain frozen and distinct.
	var record: Dictionary = StadiumGrandIVenueStudy.canonical()
	record.id = ID
	record.owner = OWNER
	var rows: Array = record.items
	for row: Dictionary in rows:
		row.instance = "npc-candidate:GRAND-II:v1:" + row.site
		row.host = OWNER
		row["supports"] = []
		row["interface"] = ""
	for site: String in ["BOWL-01", "BOWL-05"]:
		rows.append(_row("ST-081", site, StadiumCurvedLowerSites.pose(site)))
	for site: String in StadiumCurvedStackSites.CENTRAL:
		rows.append(_row("ST-083", site + ":CONCOURSE", StadiumCurvedLowerSites.pose(site)))
		rows.append(_row("ST-082", site + ":UPPER", StadiumCurvedLowerSites.pose(site)))
	for site: String in StadiumLowerTransitionSites.SITES:
		rows.append(
			_row(
				StadiumLowerTransitionSites.item(site), site, StadiumLowerTransitionSites.pose(site)
			)
		)
	record.empty_sites = ["LANDMARK-A", "SCORE-LARGE-A"]
	for path: String in SOURCES:
		record.model_sources[path] = FileAccess.get_sha256("res://" + path)
	record["qualification_sources"] = qualification_sources()
	record["source_contract"] = "Blueprint-v114:CY15475-15606:CM14400-14560:corrected-ST073-v2"
	record["structural_layers"] = {
		"baseline": "BASE-LOWER-SIGHTLINE-v2",
		"outer_bowl": "BOWL-LOWER-v1",
		"central_bowl": "BOWL-UPPER-v1",
		"transitions": "lower-only",
		"roofs": 0,
		"transition_concourses": 0
	}
	record["crowd"] = {
		"baseline": 200,
		"bowl_lower": 180,
		"bowl_upper": 48,
		"transitions": 36,
		"total": 464,
		"sway": 0.04,
		"status": "Working-art-density"
	}
	# Same physical towers do not confer the separately required upper-deck night profile.
	record.lighting["qualification"] = "unqualified-upper-deck-profile"
	return record


static func qualification_sources() -> Dictionary:
	# All authored runtime source/resources and test scenes bind together. Generated
	# import caches/UID sidecars are excluded; executable/build/device/run are root evidence.
	# The verifier lives outside its staged res:// tree; root source_digest binds tools.
	var hashes: Dictionary = {}
	_hash_tree("res://src", hashes)
	for path: String in ["project.godot"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return {
		"scope": "staged-src-authored-resources-plus-project",
		"files": hashes,
		"sha256": JSON.stringify(hashes, "", true, true).sha256_text(),
		"execution_evidence": "pending-root-engine-native-and-device-evidence"
	}


static func _hash_tree(path: String, hashes: Dictionary) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		hashes[path.trim_prefix("res://")] = "UNREADABLE"
		return
	for file: String in directory.get_files():
		if not file.ends_with(".import") and not file.ends_with(".uid"):
			var full: String = path.path_join(file)
			hashes[full.trim_prefix("res://")] = FileAccess.get_sha256(full)
	for child: String in directory.get_directories():
		_hash_tree(path.path_join(child), hashes)


static func _row(item: String, site: String, pose: Transform3D, span: String = "") -> Dictionary:
	var row: Dictionary = StadiumGrandIVenueStudy._row(item, site, pose, span)
	row.instance = "npc-candidate:GRAND-II:v1:" + site
	row.host = OWNER
	row.model_version = model_version(item)
	row["supports"] = []
	row["interface"] = ""
	if item in ["ST-083", "ST-082"]:
		var lower_site: String = site.get_slice(":", 0)
		row.supports.append("npc-candidate:GRAND-II:v1:" + lower_site)
		row.interface = StadiumCurvedStackSites.INTERFACE
		if item == "ST-082":
			row.supports.append("npc-candidate:GRAND-II:v1:" + lower_site + ":CONCOURSE")
			row.interface = StadiumCurvedStackSites.UPPER_INTERFACE
	return row


static func model_version(item: String) -> int:
	if item in ["ST-083", "ST-082"]:
		return StadiumCurvedStackModels.VERSION
	if item in ["ST-085", "ST-088"]:
		return StadiumLowerTransitionModels.VERSION
	return StadiumGrandIVenueStudy.model_version(item)


static func identity_chain(host: Node) -> bool:
	return StadiumGrandIVenueStudy.identity_chain(host)


static func field_snapshot(field: FieldDefinition) -> Dictionary:
	return StadiumGrandIVenueStudy.field_snapshot(field)


static func board_pose() -> Transform3D:
	return StadiumGrandIVenueStudy.board_pose()


static func head_rays(site: String) -> Array[Dictionary]:
	return StadiumGrandIVenueStudy.head_rays(site)


static func encode(record: Dictionary) -> String:
	return StadiumGrandIVenueStudy.encode(record)


static func build(
	host: Node3D, supplied: StadiumPropertyGeometry = null
) -> StadiumPropertyGeometry:
	if host == null or not host.is_inside_tree() or not identity_chain(host):
		return null
	if (
		supplied != null
		and (
			supplied.get_parent() != null
			or supplied.get_child_count() != 0
			or supplied.transform != Transform3D.IDENTITY
		)
	):
		return null
	var property: StadiumPropertyGeometry = (
		supplied if supplied != null else StadiumGrandIIProperty.new()
	)
	if StadiumGrandIVenueStudy.build(host, property) == null:
		return null
	property.name = "GrandIIAuthoringCandidate"
	var models: Array[Node3D] = []
	for model: Node3D in property.objects.values():
		models.append(model)
	for site: String in ["BOWL-01", "BOWL-05"]:
		var lower: Node3D = StadiumCurvedLowerModels.create()
		property.add_child(lower)
		lower.transform = StadiumCurvedLowerSites.pose(site)
		lower.set_meta("candidate_site", site)
		models.append(lower)
	for site: String in StadiumCurvedStackSites.CENTRAL:
		var lower: Node3D = property.objects["npc-candidate:GRAND-I:v1:" + site]
		var concourse: Node3D = StadiumCurvedStackModels.create_concourse(lower, site)
		if concourse == null:
			StadiumGrandIVenueStudy._discard(property)
			return null
		property.add_child(concourse)
		concourse.set_meta("candidate_site", site + ":CONCOURSE")
		models.append(concourse)
		var upper: Node3D = StadiumCurvedStackModels.create_upper(lower, concourse, site)
		if upper == null:
			StadiumGrandIVenueStudy._discard(property)
			return null
		property.add_child(upper)
		upper.set_meta("candidate_site", site + ":UPPER")
		models.append(upper)
	for site: String in StadiumLowerTransitionSites.SITES:
		var transition: Node3D = (
			StadiumLowerTransitionModels.create_right()
			if site == "JOIN-R"
			else StadiumLowerTransitionModels.create_left()
		)
		property.add_child(transition)
		transition.transform = StadiumLowerTransitionSites.pose(site)
		transition.set_meta("candidate_site", site)
		models.append(transition)
	var record: Dictionary = canonical()
	if not _bind_and_verify(property, models, record):
		StadiumGrandIVenueStudy._discard(property)
		return null
	property.set_meta("candidate_venue", record)
	return property


static func _bind_and_verify(
	property: StadiumPropertyGeometry, models: Array[Node3D], record: Dictionary
) -> bool:
	if models.size() != 85 or record.items.size() != 85:
		return false
	var sites: Dictionary = {}
	for row: Dictionary in record.items:
		sites[row.site] = row
	var counts: Dictionary = {}
	property.objects.clear()
	for model: Node3D in models:
		var site: String = model.get_meta("candidate_site", "")
		var item: String = model.get_meta("stadium_item", "")
		if not sites.has(site) or sites[site].item != item:
			return false
		var row: Dictionary = sites[site]
		if not ClubCareer.same(_row(item, site, model.global_transform, row.span), row):
			return false
		if item in ["ST-083", "ST-082"]:
			if model.get_meta("interface", "") != row.interface:
				return false
			var lower: Node3D = property.objects.get(row.supports[0])
			if lower == null or model.get_meta("lower_instance", 0) != lower.get_instance_id():
				return false
			if item == "ST-082":
				var concourse: Node3D = property.objects.get(row.supports[1])
				if (
					concourse == null
					or model.get_meta("concourse_instance", 0) != concourse.get_instance_id()
				):
					return false
		model.set_meta("candidate_instance", row.instance)
		model.set_meta("candidate_host", OWNER)
		model.set_meta("candidate_model_version", row.model_version)
		property.objects[row.instance] = model
		sites.erase(site)
		counts[item] = counts.get(item, 0) + 1
	return sites.is_empty() and ClubCareer.same(counts, COUNTS)

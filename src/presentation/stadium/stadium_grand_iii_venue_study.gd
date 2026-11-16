class_name StadiumGrandIIIVenueStudy
extends RefCounted
## CY107-copy composition with explicit video-v2 reservation revision; daytime study only.

const VERSION: int = 2
const ID: String = "GRAND-III-VIDEO-v2"
const OWNER: String = "npc-venue:grandstand-gardens:grand-iii-video-v2"
const BOARD_SITE: String = "BOARD-LARGE-v2"
const PREFIX: String = "npc-candidate:GRAND-III-VIDEO:v2:"
const COUNTS: Dictionary = {
	"ST-065": 23,
	"ST-022": 16,
	"ST-023": 16,
	"ST-074": 2,
	"ST-021": 2,
	"ST-026": 1,
	"ST-073": 1,
	"ST-029": 4,
	"ST-031": 4,
	"ST-030": 4,
	"ST-053": 4,
	"ST-081": 5,
	"ST-083": 5,
	"ST-082": 5,
	"ST-084": 5,
	"ST-085": 1,
	"ST-088": 1,
	"ST-086": 1,
	"ST-089": 1,
	"ST-040": 1,
	"ST-076": 4,
	"ST-046": 1
}
const SOURCES: Array[String] = [
	"src/presentation/stadium/stadium_grand_iii_venue_study.gd",
	"src/presentation/stadium/stadium_grand_iii_property.gd",
	"src/presentation/stadium/stadium_grand_iii_lab.gd",
	"src/presentation/stadium/stadium_grand_iii_camera_director.gd",
	"src/presentation/stadium/stadium_grand_iii_field_visibility.gd",
	"src/presentation/stadium/stadium_npc_retained_actor_cutaway.gd",
	"src/gameplay/stadium/stadium_grand_iii_fixture_study.gd",
	"src/presentation/stadium/stadium_grand_three_stack_models.gd",
	"src/gameplay/stadium/stadium_grand_three_stack_sites.gd",
	"src/presentation/stadium/stadium_curved_canopy_models.gd",
	"src/gameplay/stadium/stadium_curved_canopy_sites.gd",
	"src/presentation/stadium/stadium_premium_light_tower_models.gd",
	"src/presentation/stadium/stadium_premium_light_tower_sites.gd",
	"src/presentation/stadium/stadium_waterfall_models.gd",
	"src/presentation/stadium/stadium_waterfall_sites.gd",
	"src/presentation/stadium/stadium_scoreboard_models.gd",
	"src/presentation/stadium/stadium_scoreboard_tiers.gd",
	"src/gameplay/stadium/stadium_scoreboard_sites.gd"
]


static func canonical() -> Dictionary:
	var record: Dictionary = StadiumGrandIIVenueStudy.canonical()
	record.id = ID
	record.version = VERSION
	record["archive_layout"] = "GRAND-III-v1"
	record["layout_revision"] = {
		"id": ID,
		"status": "Working-owner-acceptance-pending",
		"change": "ST040-video-v2-at-qualified-BOARD-LARGE-v2-replaces-historic-SCORE-LARGE-A",
		"original_reservation": [30, 0, 29, 13, 12, 5],
		"reservation": [29, 0, 30.5, 15, 14, 2],
		"field_changed": false,
		"land_changed": false
	}
	record["board"] = {
		"item": "ST-040",
		"model": "video-v2",
		"factory_version": 1,
		"art_version": 2,
		"site": BOARD_SITE,
		"mount": "upright",
		"collision": "none-after-terminal-only"
	}
	record.owner = OWNER
	var rows: Array[Dictionary] = []
	for old: Dictionary in record.items:
		if old.item not in ["ST-039", "ST-038"]:
			rows.append(_row(old.item, old.site, _pose(old.transform), old.span))
	for site: String in StadiumBaselineSites.SITES:
		for layer: String in ["CONCOURSE", "UPPER", "ROOF"]:
			rows.append(
				_row(
					{"CONCOURSE": "ST-031", "UPPER": "ST-030", "ROOF": "ST-053"}[layer],
					site + ":" + layer,
					StadiumBaselineSites.pose(site)
				)
			)
	for site: String in StadiumCurvedLowerSites.SITES:
		if site in ["BOWL-01", "BOWL-05"]:
			rows.append(_row("ST-083", site + ":CONCOURSE", StadiumCurvedLowerSites.pose(site)))
			rows.append(_row("ST-082", site + ":UPPER", StadiumCurvedLowerSites.pose(site)))
		rows.append(_row("ST-084", site + ":ROOF", StadiumCurvedLowerSites.pose(site)))
	for site: String in StadiumTransitionConcourseSites.SITES:
		rows.append(
			_row(
				StadiumTransitionConcourseSites.item(site),
				site + ":CONCOURSE",
				Transform3D.IDENTITY
			)
		)
	rows.append(_row("ST-040", BOARD_SITE, board_pose()))
	var towers: Array[Dictionary] = []
	for site: String in StadiumPremiumLightTowerSites.SITES:
		rows.append(_row("ST-076", site, tower_pose(site)))
		var target: Vector3 = StadiumPremiumLightTowerSites.TARGETS[site]
		towers.append(
			{
				"site": site,
				"profile": StadiumPremiumLightTowerSites.PROFILE,
				"target": [target.x, target.y, target.z],
				"heads": head_rays(site)
			}
		)
	rows.append(
		_row("ST-046", "LANDMARK-A", Transform3D(Basis.IDENTITY, StadiumWaterfallSites.CENTER))
	)
	record.items = rows
	record.empty_sites = ["SCORE-SMALL", "MLIGHT-ML", "MLIGHT-MR"]
	record.lighting = {
		"preset": StadiumPremiumLightTowerSites.PRESET,
		"dormant": true,
		"active_lights": 0,
		"towers": towers,
		"qualification": "unqualified-nine-canopy-video-waterfall"
	}
	record.structural_layers = {
		"baseline": "BASE-UPPER-ROOF-v1:guard-v2",
		"bowl": "BOWL-UPPER-ROOF-v1",
		"transitions": "roofless-concourse-v2",
		"roofs": 9,
		"transition_concourses": 2
	}
	record.crowd = {
		"baseline_lower": 200,
		"baseline_upper": 64,
		"bowl_lower": 180,
		"bowl_upper": 80,
		"transitions": 36,
		"total": 560,
		"sway": 0.04,
		"status": "Working-art-density"
	}
	record["source_contract"] = "Blueprint-v114:CY15475-15606:BI:CL:CM:BQ:corrected-ST073-v2"
	for path: String in SOURCES:
		record.model_sources[path] = FileAccess.get_sha256("res://" + path)
	record.qualification_sources = qualification_sources()
	return record


static func qualification_sources() -> Dictionary:
	return StadiumGrandIIVenueStudy.qualification_sources()


static func _pose(values: Array) -> Transform3D:
	return Transform3D(
		Basis(
			Vector3(values[0], values[1], values[2]),
			Vector3(values[3], values[4], values[5]),
			Vector3(values[6], values[7], values[8])
		),
		Vector3(values[9], values[10], values[11])
	)


static func _row(item: String, site: String, pose: Transform3D, span: String = "") -> Dictionary:
	var row: Dictionary = StadiumGrandIIVenueStudy._row(item, site, pose, span)
	row.instance = PREFIX + site
	row.host = OWNER
	row.model_version = model_version(item)
	row.model_variant = model_variant(item)
	row.supports = []
	row.interface = ""
	var base: String = site.get_slice(":", 0)
	if item in ["ST-031", "ST-030", "ST-053", "ST-083", "ST-082", "ST-084"]:
		row.supports.append(PREFIX + base)
		if item in ["ST-030", "ST-053", "ST-082", "ST-084"]:
			row.supports.append(PREFIX + base + ":CONCOURSE")
		if item in ["ST-053", "ST-084"]:
			row.supports.append(PREFIX + base + ":UPPER")
		row.interface = {
			"ST-031": StadiumGrandThreeStackSites.INTERFACE,
			"ST-030": StadiumGrandThreeStackSites.UPPER_INTERFACE,
			"ST-053": StadiumGrandThreeStackSites.ROOF_INTERFACE,
			"ST-083": StadiumCurvedStackSites.INTERFACE,
			"ST-082": StadiumCurvedStackSites.UPPER_INTERFACE,
			"ST-084": StadiumCurvedCanopySites.INTERFACE
		}[item]
	if item in ["ST-086", "ST-089"]:
		var bowl: String = StadiumTransitionConcourseSites.bowl_site(base)
		var straight: String = StadiumTransitionConcourseSites.base_site(base)
		row.supports = [
			PREFIX + base,
			PREFIX + bowl,
			PREFIX + bowl + ":CONCOURSE",
			PREFIX + straight,
			PREFIX + straight + ":CONCOURSE"
		]
		row.interface = StadiumGrandThreeStackSites.TRANSITION_INTERFACE
	return row


static func model_variant(item: String) -> String:
	return (
		{
			"ST-029": StadiumBaselineSightlineModels.VARIANT,
			"ST-031": "STRAIGHT-CONCOURSE-GUARD-v2",
			"ST-030": "STRAIGHT-UPPER-GUARD-v2",
			"ST-053": "STRAIGHT-UPPER-CANOPY-v2",
			"ST-086": "TRANSITION-ROOF-NEIGHBOR-v2",
			"ST-089": "TRANSITION-ROOF-NEIGHBOR-v2",
			"ST-040": "video-v2"
		}
		. get(item, "")
	)


static func model_version(item: String) -> int:
	if item in ["ST-031", "ST-030", "ST-053", "ST-086", "ST-089"]:
		return StadiumGrandThreeStackModels.VERSION
	if item == "ST-040":
		return StadiumScoreboardModels.VERSION
	if item == "ST-084":
		return StadiumCurvedCanopyModels.VERSION
	if item == "ST-076":
		return StadiumPremiumLightTowerModels.VERSION
	if item == "ST-046":
		return 1  # Frozen factory geometry_version; no VERSION constant exists.
	return StadiumGrandIIVenueStudy.model_version(item)


static func identity_chain(host: Node) -> bool:
	return StadiumGrandIVenueStudy.identity_chain(host)


static func field_snapshot(field: FieldDefinition) -> Dictionary:
	return StadiumGrandIVenueStudy.field_snapshot(field)


static func board_pose() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), Vector3(36.5, 0, 31.5))


static func tower_pose(site: String) -> Transform3D:
	var toward: Vector3 = (
		StadiumPremiumLightTowerSites.TARGETS[site] - StadiumPremiumLightTowerSites.SITES[site]
	)
	return Transform3D(
		Basis(Vector3.UP, atan2(toward.x, toward.z)), StadiumPremiumLightTowerSites.SITES[site]
	)


static func head_rays(site: String) -> Array[Dictionary]:
	var pose: Transform3D = tower_pose(site)
	var target: Vector3 = pose.affine_inverse() * StadiumPremiumLightTowerSites.TARGETS[site]
	var result: Array[Dictionary] = []
	for index in range(8):
		var center: Vector3 = Vector3(
			StadiumPremiumLightTowerModels.HEAD_X[index % 4],
			StadiumPremiumLightTowerModels.HEAD_HEIGHT + (0.8 if index >= 4 else 0.0),
			0
		)
		var direction: Vector3 = (target - center).normalized()
		var origin: Vector3 = pose * (center + direction * 0.154)
		direction = (pose.basis * direction).normalized()
		result.append(
			{
				"id": "HEAD-%d" % (index + 1),
				"origin": [origin.x, origin.y, origin.z],
				"direction": [direction.x, direction.y, direction.z]
			}
		)
	return result


static func encode(record: Dictionary) -> String:
	return StadiumGrandIVenueStudy.encode(record)


static func build(
	host: Node3D, supplied: StadiumPropertyGeometry = null
) -> StadiumPropertyGeometry:
	if host == null or not host.is_inside_tree() or not identity_chain(host):
		return null
	var property: StadiumPropertyGeometry = (
		supplied if supplied != null else StadiumGrandIIIProperty.new()
	)
	if StadiumGrandIIVenueStudy.build(host, property) == null:
		return null
	property.name = "GrandIIIRevision2AuthoringCandidate"
	var models: Array[Node3D] = []
	var sites: Dictionary = {}
	for model: Node3D in property.objects.values():
		if model.get_meta("stadium_item") in ["ST-039", "ST-038"]:
			model.free()
		else:
			models.append(model)
			sites[model.get_meta("candidate_site")] = model
	property.objects.clear()
	if not _add_structures(property, models, sites) or not _add_exterior(property, models):
		StadiumGrandIVenueStudy._discard(property)
		return null
	var record: Dictionary = canonical()
	if not _bind_and_verify(property, models, record):
		StadiumGrandIVenueStudy._discard(property)
		return null
	property.set_meta("candidate_venue", record)
	return property


static func _add(
	property: StadiumPropertyGeometry,
	models: Array[Node3D],
	sites: Dictionary,
	model: Node3D,
	site: String
) -> bool:
	if model == null:
		return false
	property.add_child(model)
	model.set_meta("candidate_site", site)
	models.append(model)
	sites[site] = model
	return true


static func _add_structures(
	property: StadiumPropertyGeometry, models: Array[Node3D], sites: Dictionary
) -> bool:
	for site: String in StadiumBaselineSites.SITES:
		var lower: Node3D = sites[site]
		var concourse: Node3D = StadiumGrandThreeStackModels.create_concourse(lower, site)
		if not _add(property, models, sites, concourse, site + ":CONCOURSE"):
			return false
		var upper: Node3D = StadiumGrandThreeStackModels.create_upper(lower, concourse, site)
		if not _add(property, models, sites, upper, site + ":UPPER"):
			return false
		var roof: Node3D = StadiumGrandThreeStackModels.create_roof(lower, concourse, upper, site)
		if not _add(property, models, sites, roof, site + ":ROOF"):
			return false
	for site: String in StadiumCurvedLowerSites.SITES:
		var lower: Node3D = sites[site]
		if site in ["BOWL-01", "BOWL-05"]:
			var concourse: Node3D = StadiumCurvedStackModels.create_concourse(lower, site)
			if not _add(property, models, sites, concourse, site + ":CONCOURSE"):
				return false
			var upper: Node3D = StadiumCurvedStackModels.create_upper(lower, concourse, site)
			if not _add(property, models, sites, upper, site + ":UPPER"):
				return false
		var roof: Node3D = StadiumCurvedCanopyModels.create(
			lower, sites[site + ":CONCOURSE"], sites[site + ":UPPER"], site
		)
		if not _add(property, models, sites, roof, site + ":ROOF"):
			return false
	for site: String in StadiumTransitionConcourseSites.SITES:
		var bowl: String = StadiumTransitionConcourseSites.bowl_site(site)
		var base: String = StadiumTransitionConcourseSites.base_site(site)
		var transition: Node3D = StadiumGrandThreeStackModels.create_transition(
			site,
			sites[site],
			sites[bowl],
			sites[bowl + ":CONCOURSE"],
			sites[base],
			sites[base + ":CONCOURSE"]
		)
		if not _add(property, models, sites, transition, site + ":CONCOURSE"):
			return false
	return true


static func _add_exterior(property: StadiumPropertyGeometry, models: Array[Node3D]) -> bool:
	var board_check: Dictionary = StadiumScoreboardSites.inspect(
		"ST-040", BOARD_SITE, "mogul", StadiumDugoutBoundary.candidate("straight")
	)
	if not board_check.get("ok", false):
		return false
	var board: Node3D = StadiumScoreboardModels.create("ST-040", "video-v2")
	if board == null:
		return false
	property.add_child(board)
	board.transform = board_pose()
	board.set_meta("candidate_site", BOARD_SITE)
	board.set_meta("site", BOARD_SITE)
	board.set_meta("surface_role", &"DECORATIVE_AFTER_TERMINAL")
	models.append(board)
	for site: String in StadiumPremiumLightTowerSites.SITES:
		var tower: Node3D = StadiumPremiumLightTowerModels.create()
		property.add_child(tower)
		if not StadiumPremiumLightTowerSites.place(tower, site):
			return false
		tower.set_meta("candidate_site", site)
		models.append(tower)
	var waterfall: Node3D = StadiumWaterfallModels.create()
	if waterfall == null:
		return false
	property.add_child(waterfall)
	if not StadiumWaterfallSites.place(waterfall):
		return false
	waterfall.set_meta("candidate_site", "LANDMARK-A")
	models.append(waterfall)
	return true


static func _bind_and_verify(
	property: StadiumPropertyGeometry, models: Array[Node3D], record: Dictionary
) -> bool:
	if models.size() != 107 or record.items.size() != 107:
		return false
	var sites: Dictionary = {}
	var counts: Dictionary = {}
	for row: Dictionary in record.items:
		sites[row.site] = row
	property.objects.clear()
	for model: Node3D in models:
		var site: String = model.get_meta("candidate_site", "")
		var item: String = model.get_meta("stadium_item", "")
		if not sites.has(site) or sites[site].item != item:
			return false
		var row: Dictionary = sites[site]
		if not ClubCareer.same(_row(item, site, model.global_transform, row.span), row):
			return false
		model.set_meta("candidate_instance", row.instance)
		model.set_meta("candidate_host", OWNER)
		model.set_meta("candidate_model_version", row.model_version)
		property.objects[row.instance] = model
		sites.erase(site)
		counts[item] = counts.get(item, 0) + 1
	if not sites.is_empty() or not ClubCareer.same(counts, COUNTS):
		return false
	for row: Dictionary in record.items:
		var model: Node3D = property.objects[row.instance]
		if not row.supports.is_empty():
			var keys: Array[String] = ["lower_instance", "concourse_instance", "upper_instance"]
			if row.item in ["ST-086", "ST-089"]:
				keys.assign(
					[
						"lower_instance",
						"bowl_instance",
						"curved_concourse_instance",
						"baseline_instance",
						"straight_concourse_instance"
					]
				)
			if model.get_meta("interface", "") != row.interface:
				return false
			for index in range(row.supports.size()):
				var dependency: Node3D = property.objects.get(row.supports[index])
				if (
					dependency == null
					or model.get_meta(keys[index], 0) != dependency.get_instance_id()
				):
					return false
	return true

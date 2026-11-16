class_name StadiumMogulOneStudy
extends RefCounted
## Working AM-01 Deeper Center daylight authoring; no production or ownership grant.

const VERSION: int = 1
const ID: String = "AM-01"
const PREFIX: String = "npc-candidate:AM-01:deeper-center-v1:"
const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")
const BASE_SITES: Array[String] = ["BASE-L1", "BASE-R1"]
const OWNER: String = "npc-venue:AM-01:deeper-center-v1"
const BOARD_SITE: String = "SCORE-SMALL"
const COUNTS: Dictionary = {
	"ST-065": 22,
	"ST-022": 16,
	"ST-023": 16,
	"ST-074": 2,
	"ST-021": 2,
	"ST-026": 1,
	"ST-073": 1,
	"ST-029": 2,
	"ST-081": 3,
	"ST-039": 1,
	"ST-038": 6
}
const FIELD_KEYS: Array[String] = [
	"environment_style",
	"fair_half_angle_degrees",
	"safe_hit_z_m",
	"deep_air_z_m",
	"back_wall_z_m",
	"home_run_height_m",
	"dead_ball_z_m",
	"shallow_anchor_z_m",
	"middle_anchor_z_m",
	"middle_center_anchor_z_m",
	"deep_anchor_z_m",
	"side_anchor_x_m",
	"shallow_center_available",
	"middle_center_available"
]


static func canonical() -> Dictionary:
	var rows: Array[Dictionary] = []
	var panels: Array[Dictionary] = StadiumWallRecipes.back("deeper_center", "ST-065")
	panels.append_array(StadiumDugoutRecipe.panels(false))
	panels.append_array(StadiumDugoutRecipe.panels(true))
	for panel: Dictionary in panels:
		rows.append(_row(panel.item, panel.socket, StadiumWallRecipes.placement(panel), panel.span))
	for left in [false, true]:
		rows.append(
			_row("ST-074", "DUGOUT-L" if left else "DUGOUT-R", StadiumDugoutRecipe.placement(left))
		)
	var graph: StadiumDugoutBoundary = StadiumDugoutBoundary.candidate("deeper_center")
	for socket: Dictionary in StadiumFoulPoleSites.rows(graph):
		rows.append(_row("ST-021", socket.site, Transform3D(Basis.IDENTITY, socket.position)))
	rows.append(
		_row(
			"ST-026", "RECEIVER-PRIMARY", Transform3D(Basis.IDENTITY, StadiumTargetModels.POSITION)
		)
	)
	rows.append(_row("ST-073", "RECEIVER-CATCH", Transform3D.IDENTITY))
	for site: String in BASE_SITES:
		rows.append(_row("ST-029", site, StadiumBaselineSites.pose(site)))
	for site: String in StadiumCurvedLowerSites.GRAND_I:
		rows.append(_row("ST-081", site, StadiumCurvedLowerSites.pose(site)))
	rows.append(_row("ST-039", BOARD_SITE, board_pose()))
	var towers: Array[Dictionary] = []
	for site: String in StadiumFourHeadTowerSites.SITES:
		var toward: Vector3 = (
			StadiumFourHeadTowerSites.TARGETS[site] - StadiumFourHeadTowerSites.SITES[site]
		)
		rows.append(
			_row(
				"ST-038",
				site,
				Transform3D(
					Basis(Vector3.UP, atan2(toward.x, toward.z)),
					StadiumFourHeadTowerSites.SITES[site]
				)
			)
		)
		var target: Vector3 = StadiumFourHeadTowerSites.TARGETS[site]
		towers.append(
			{
				"site": site,
				"profile": StadiumFourHeadTowerSites.PROFILE,
				"target": [target.x, target.y, target.z],
				"heads": head_rays(site)
			}
		)
	var blueprint_value: int = 0
	var copy_value: int = 0
	var blueprints: Array = COUNTS.keys()
	blueprints.sort()
	for item: String in COUNTS:
		var price: Dictionary = StadiumCatalog.item(item)
		blueprint_value += int(price.blueprint_price)
		copy_value += int(price.copy_price) * int(COUNTS[item])
	var land_value: int = (
		int(StadiumCatalog.LAND.expanded.price)
		+ int(StadiumCatalog.LAND.club.price)
		+ int(StadiumCatalog.LAND.mogul.price)
	)
	var sources: Dictionary = qualification_sources()

	return {
		"version": VERSION,
		"id": ID,
		"status": "CANDIDATE",
		"mapping": "WORKING",
		"kind": "npc-authored-candidate",
		"property": "mogul",
		"items": rows,
		"owner": OWNER,
		"batting_home": "ordinary-match-role-independent-of-venue-owner",
		"live_units": 0,
		"field": field_snapshot(FIELD as FieldDefinition),
		"qualification_sources": sources,
		"camera_profile":
		{
			"id": StadiumMogulOneCamera.PROFILE,
			"scope": "installed-AM01-precontact-batting-entry-only",
			"right_entry": [0.18, 2.10, StadiumMogulOneCamera.ENTRY_Z],
			"left_entry": [-0.18, 2.10, StadiumMogulOneCamera.ENTRY_Z],
			"focus": [0, 1.10, 7.1],
			"optics": "unchanged-inherited-75-degree-base-and-Club-live-FOV",
			"live_motion": "unchanged-inherited-continuous-motion-turn-and-collision",
			"acquisition": "pre-pitch-only-no-pitch-no-batted-body-no-contact-cut",
			"predecessor": "inherited-Club-batting-entry-v1:z=-3.38",
			"predecessor_failed_source":
			"247d9a744292550e16cf658240d2d00cfc7e42048522bf6cee6fad580045a2e6"
		},
		"render_profile":
		{
			"id": "STADIUM-WALL-MSAA4X-v1",
			"native_minimum_msaa_3d": "4x",
			"helper": "res://src/presentation/stadium/stadium_wall_render_quality.gd",
			"helper_sha256":
			FileAccess.get_sha256("res://src/presentation/stadium/stadium_wall_render_quality.gd"),
			"ownership": "installed-property-viewport-lifetime",
			"headless": "no-op",
			"higher_quality": "preserve",
			"restore": "last-owner-if-unchanged"
		},
		"catalog": StadiumCatalog.signature(),
		"blueprint_entitlements": blueprints,
		"endowment":
		{
			"blueprint_value": blueprint_value,
			"copy_value": copy_value,
			"land_value": land_value,
			"total_value": blueprint_value + copy_value + land_value
		},
		"boundary": graph.signature(),
		"graph": graph_record(graph),
		"receiver":
		{
			"id": "RX-TARGET-026-073-v1:corrected-ST073-v2",
			"primary": PREFIX + "RECEIVER-PRIMARY",
			"catch": PREFIX + "RECEIVER-CATCH",
			"pair_version": StadiumClubPitchReceiver.PAIR_VERSION,
			"role": "RECEIVER_CONTAINMENT_FOUL"
		},
		"source_contract":
		"Blueprint-v114:DE15891:CY15484-15505:CM14400-14560:Working-shaped-away:corrected-ST073-v2",
		"empty_sites":
		[
			"BASE-L2",
			"BASE-R2",
			"BOWL-01",
			"BOWL-05",
			"JOIN-L",
			"JOIN-R",
			"LANDMARK-A",
			"SCORE-LARGE-A"
		],
		"surface":
		{
			"geometry": "flat",
			"grass": "default",
			"ground": "default",
			"markings": "default",
			"bounds": [-52, -30, 104, 88]
		},
		"environment":
		{
			"target_slots": ["13:10", "16:10"],
			"target_weather": ["clear"],
			"certificates": [],
			"night_eligible": false,
			"qualification": "requires-complete-ordinary-layout-profile",
			"future_night_profile": "MOGUL6-STANDARD"
		},
		"lighting":
		{
			"preset": StadiumFourHeadTowerSites.PRESET,
			"profile": StadiumFourHeadTowerSites.PROFILE,
			"dormant": true,
			"active_lights": 0,
			"towers": towers
		},
		"crowd":
		{
			"baseline_lower": 100,
			"bowl_lower": 108,
			"total": 208,
			"sway": 0.04,
			"status": "Working-art-density"
		},
		"structural_layers":
		{
			"baseline": "BASE-LOWER-SIGHTLINE-v2",
			"bowl": "BOWL-LOWER-v1",
			"roofs": 0,
			"transition_concourses": 0
		}
	}


static func field_snapshot(field: FieldDefinition) -> Dictionary:
	var result: Dictionary = {"id": String(field.id)}
	for key: String in FIELD_KEYS:
		result[key] = field.get(key)
	var mound: Vector3 = PitchBatLab.MOUND_ORIGIN
	result["mound_origin"] = [mound.x, mound.y, mound.z]
	return result


static func graph_record(graph: StadiumDugoutBoundary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for row: Dictionary in graph.segments():
		rows.append(
			{
				"id": row.id,
				"a": [row.a.x, row.a.y],
				"b": [row.b.x, row.b.y],
				"height": row.height,
				"role": row.role,
				"priority": row.priority
			}
		)
	var poles: Array[Dictionary] = []
	for pole: Dictionary in StadiumFoulPoleSites.rows(graph):
		poles.append(
			{
				"site": pole.site,
				"position": [pole.position.x, pole.position.y, pole.position.z],
				"split": pole.split,
				"segment": pole.segment,
				"radius": pole.radius,
				"height": pole.height
			}
		)
	return {
		"id": graph.identity(),
		"version": StadiumRecipeBoundary.VERSION,
		"signature": graph.signature(),
		"segments": rows,
		"poles": poles,
		"thickness": StadiumRecipeBoundary.THICKNESS,
		"defender_radius": StadiumRecipeBoundary.DEFENDER_RADIUS,
		"prism_margin": 0.0,
		"ball_radius": 0.0365,
		"query_layer": StadiumClubBoundaryStudy.QUERY_MASK,
		"ordering": "first-sphere-contact-or-clear-v1"
	}


static func head_rays(site: String) -> Array[Dictionary]:
	var toward: Vector3 = (
		StadiumFourHeadTowerSites.TARGETS[site] - StadiumFourHeadTowerSites.SITES[site]
	)
	var pose: Transform3D = Transform3D(
		Basis(Vector3.UP, atan2(toward.x, toward.z)), StadiumFourHeadTowerSites.SITES[site]
	)
	var target: Vector3 = pose.affine_inverse() * StadiumFourHeadTowerSites.TARGETS[site]
	var result: Array[Dictionary] = []
	for index in range(4):
		var center: Vector3 = Vector3(
			StadiumFourHeadTowerModels.HEAD_X[index], StadiumFourHeadTowerModels.HEAD_HEIGHT, 0
		)
		var direction: Vector3 = (target - center).normalized()
		var origin: Vector3 = pose * (center + direction * 0.139)
		direction = (pose.basis * direction).normalized()
		result.append(
			{
				"id": "HEAD-%d" % (index + 1),
				"origin": [origin.x, origin.y, origin.z],
				"direction": [direction.x, direction.y, direction.z]
			}
		)
	return result


static func _row(item: String, site: String, pose: Transform3D, span: String = "") -> Dictionary:
	var components: Array[float] = []
	for vector: Vector3 in [pose.basis.x, pose.basis.y, pose.basis.z, pose.origin]:
		components.append_array([vector.x, vector.y, vector.z])
	return {
		"instance": PREFIX + site,
		"item": item,
		"site": site,
		"host": OWNER,
		"transform": components,
		"span": span,
		"model_version": model_version(item),
		"model_variant": StadiumBaselineSightlineModels.VARIANT if item == "ST-029" else ""
	}


static func model_version(item: String) -> int:
	match item:
		"ST-073":
			return StadiumReceiverNetModels.VERSION
		"ST-074":
			return StadiumConcreteDugoutModels.VERSION
		"ST-021":
			return StadiumFoulPoleModels.VERSION
		"ST-029":
			return StadiumBaselineSightlineModels.VERSION
		"ST-081":
			return StadiumCurvedLowerModels.VERSION
		"ST-038":
			return StadiumFourHeadTowerModels.VERSION
		"ST-065", "ST-022", "ST-023":
			return StadiumWallPanelModels.VERSION
		"ST-026":
			return StadiumTargetModels.VERSION
		"ST-039":
			return StadiumClubModels.VERSION
	return 0


static func board_pose() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), Vector3(-20, 0, 30))


static func identity_chain(host: Node) -> bool:
	while host != null:
		if host is Node3D and host.transform != Transform3D.IDENTITY:
			return false
		host = host.get_parent()
	return true


static func build(
	host: Node3D, supplied: StadiumPropertyGeometry = null
) -> StadiumPropertyGeometry:
	if (
		host == null
		or not host.is_inside_tree()
		or not identity_chain(host)
		or (
			supplied != null
			and (
				supplied.get_parent() != null
				or supplied.get_child_count() != 0
				or supplied.transform != Transform3D.IDENTITY
			)
		)
	):
		return null
	var property: StadiumPropertyGeometry = (
		supplied if supplied != null else StadiumMogulOneProperty.new()
	)
	property.name = "AM01AuthoringCandidate"
	host.add_child(property)
	# Empty unresolved ownership validates the template only; never fabricate a starter grant.
	if not property.build("mogul", StadiumStarterLayout.empty(), StadiumStock.new()):
		_discard(property)
		return null
	property.field = FIELD.duplicate(true) as FieldDefinition
	# Template guide stripes have width0.08; center them inside the exact land footprint.
	# No item site or sport dimension moves. The unchanged generic helper centers its
	# guide on the mathematical property edge, extending4cm beyond that footprint.
	for child: Node in property.get_children():
		if not child is Node3D:
			continue
		var edge: Node3D = child as Node3D
		if absf(edge.position.x) == 52:
			edge.position.x = signf(edge.position.x) * 51.96
		elif edge.position.z == -30:
			edge.position.z = -29.96
		elif edge.position.z == 58:
			edge.position.z = 57.96
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumClubBoundaryStudy = StadiumClubBoundaryStudy.new()
	boundary.name = "ClubBoundary"
	property.add_child(boundary)
	if not boundary.build("deeper_center"):
		_discard(property)
		return null
	for socket: Dictionary in StadiumFoulPoleSites.rows(boundary.graph):
		var side: int = -1 if socket.site == "FOUL-POLE-L" else 1
		var line: Node3D = property.get_node("FoulLine" + str(side))
		var end: Vector3 = socket.position
		line.position = end / 2 + Vector3(0, 0.02, 0)
		line.rotation.y = atan2(end.x, end.z)
		var mesh: MeshInstance3D = line.get_child(0) as MeshInstance3D
		(mesh.mesh as BoxMesh).size = Vector3(0.055, 0.025, end.length())
	var models: Array[Node3D] = boundary.items.duplicate()
	for site: String in BASE_SITES:
		var stand: Node3D = StadiumBaselineSightlineModels.lower()
		if stand == null:
			_discard(property)
			return null
		property.add_child(stand)
		stand.transform = StadiumBaselineSites.pose(site)
		stand.set_meta("candidate_site", site)
		models.append(stand)
	for site: String in StadiumCurvedLowerSites.GRAND_I:
		var bowl: Node3D = StadiumCurvedLowerModels.create()
		property.add_child(bowl)
		bowl.transform = StadiumCurvedLowerSites.pose(site)
		bowl.set_meta("candidate_site", site)
		models.append(bowl)
	var board: Node3D = StadiumClubModels.create("ST-039")
	property.add_child(board)
	board.transform = board_pose()
	board.set_meta("candidate_site", BOARD_SITE)
	models.append(board)
	for site: String in StadiumFourHeadTowerSites.SITES:
		var tower: Node3D = StadiumFourHeadTowerModels.create()
		property.add_child(tower)
		if not StadiumFourHeadTowerSites.place(tower, site):
			_discard(property)
			return null
		tower.set_meta("candidate_site", site)
		models.append(tower)
	var record: Dictionary = canonical()
	if not _bind_and_verify(property, models, record):
		_discard(property)
		return null
	if not ClubCareer.same(field_snapshot(property.field), record.field):
		_discard(property)
		return null
	property.set_meta("candidate_venue", record)
	return property


static func _bind_and_verify(
	property: StadiumPropertyGeometry, models: Array[Node3D], record: Dictionary
) -> bool:
	if models.size() != 72:
		return false
	var sites: Dictionary = {}
	for row: Dictionary in record.items:
		sites[row.site] = row
	var counts: Dictionary = {}
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
	return sites.is_empty() and ClubCareer.same(counts, COUNTS)


static func _discard(property: StadiumPropertyGeometry) -> void:
	if property.get_parent() != null:
		property.get_parent().remove_child(property)
	property.queue_free()


static func encode(record: Dictionary) -> String:
	return JSON.stringify(record, "", true, true)


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

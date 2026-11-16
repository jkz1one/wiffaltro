class_name StadiumGrandIVenueStudy
extends RefCounted
## Working Grand I daylight authoring composition; never a production finals definition.

const VERSION: int = 1
const ID: String = "GRAND-I"
const OWNER: String = "npc-venue:grandstand-gardens:grand-i-v1"
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
	"ST-081": 3,
	"ST-039": 1,
	"ST-038": 6
}
const PRESENTATION_SOURCES: Array[String] = [
	"stadium_grand_i_venue_study",
	"stadium_grand_i_lab",
	"stadium_grand_i_property",
	"stadium_grand_i_camera_director",
	"stadium_grand_i_actor_presentation",
	"stadium_actor_cutaway_study",
	"stadium_property_geometry",
	"stadium_club_property_geometry",
	"stadium_club_boundary_study",
	"stadium_club_pitch_receiver",
	"stadium_club_receiver_visibility",
	"stadium_receiver_visibility",
	"stadium_pitch_receiver",
	"stadium_property_runtime",
	"stadium_base_marker_visibility",
	"stadium_club_camera_director",
	"stadium_club_field_visibility",
	"stadium_wall_panel_models",
	"stadium_concrete_dugout_models",
	"stadium_foul_pole_models",
	"stadium_target_models",
	"stadium_target_receiver",
	"stadium_receiver_net_models",
	"stadium_baseline_stand_models",
	"stadium_baseline_sightline_models",
	"stadium_club_models",
	"stadium_scoreboard_display",
	"stadium_curved_lower_models",
	"stadium_four_head_tower_models",
	"stadium_four_head_tower_sites",
	"stadium_seating_models",
	"stadium_starter_models"
]
const GAMEPLAY_SOURCES: Array[String] = [
	"stadium_grand_i_fixture_study",
	"stadium_wall_recipes",
	"stadium_dugout_recipe",
	"stadium_dugout_boundary",
	"stadium_recipe_boundary",
	"stadium_foul_pole_sites",
	"stadium_baseline_sites",
	"stadium_curved_lower_sites",
	"stadium_club_boundary_sweep"
]

const SEMANTIC_SOURCES: Array[String] = [
	"src/content/fields/starter_field.tres",
	"src/content/definitions/field_definition.gd",
	"src/content/definitions/definition_base.gd",
	"src/labs/pitch_bat_lab/pitch_bat_lab.gd",
	"src/presentation/players/player_avatar.gd",
	"src/presentation/equipment/bat_actor.gd",
	"src/presentation/camera/ball_tracking_visibility.gd",
	"src/presentation/camera/stadium_wall_view_prisms.gd",
	"src/presentation/camera/match_camera_director.gd",
	"src/presentation/camera/ball_in_play_camera.gd",
	"src/presentation/camera/match_presentation_director.gd"
]
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
	var panels: Array[Dictionary] = StadiumWallRecipes.back("straight", "ST-065")
	panels.append_array(StadiumDugoutRecipe.panels(false))
	panels.append_array(StadiumDugoutRecipe.panels(true))
	for panel: Dictionary in panels:
		rows.append(_row(panel.item, panel.socket, StadiumWallRecipes.placement(panel), panel.span))
	for left in [false, true]:
		rows.append(
			_row("ST-074", "DUGOUT-L" if left else "DUGOUT-R", StadiumDugoutRecipe.placement(left))
		)
	var graph: StadiumDugoutBoundary = StadiumDugoutBoundary.candidate("straight")
	for socket: Dictionary in StadiumFoulPoleSites.rows(graph):
		rows.append(_row("ST-021", socket.site, Transform3D(Basis.IDENTITY, socket.position)))
	rows.append(
		_row(
			"ST-026", "RECEIVER-PRIMARY", Transform3D(Basis.IDENTITY, StadiumTargetModels.POSITION)
		)
	)
	rows.append(_row("ST-073", "RECEIVER-CATCH", Transform3D.IDENTITY))
	for site: String in StadiumBaselineSites.SITES:
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
	var hashes: Dictionary = {}
	for source: String in PRESENTATION_SOURCES:
		hashes[source] = FileAccess.get_sha256("res://src/presentation/stadium/" + source + ".gd")
	for source: String in GAMEPLAY_SOURCES:
		hashes[source] = FileAccess.get_sha256("res://src/gameplay/stadium/" + source + ".gd")
	for source: String in SEMANTIC_SOURCES:
		hashes[source] = FileAccess.get_sha256("res://" + source)

	return {
		"version": VERSION,
		"id": ID,
		"status": "CANDIDATE",
		"mapping": "WORKING",
		"kind": "npc-authored-candidate",
		"property": "mogul",
		"items": rows,
		"owner": OWNER,
		"batting_home": "higher-seed-separate-from-neutral-venue-owner",
		"live_units": 0,
		"field": field_snapshot(ContentDB.get_field(PitchBatLab.FIELD_ID)),
		"model_sources": hashes,
		"boundary": graph.signature(),
		"source_contract": "Blueprint-v114:CY15475-15576:CM14400-14560:corrected-ST073-v2",
		"empty_sites": ["BOWL-01", "BOWL-05", "JOIN-L", "JOIN-R", "LANDMARK-A"],
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
			"target_slots": ["19:10"],
			"target_weather": ["clear"],
			"certificates": [],
			"night_eligible": false,
			"qualification": "requires-step3-full-night"
		},
		"lighting":
		{
			"preset": StadiumFourHeadTowerSites.PRESET,
			"dormant": true,
			"active_lights": 0,
			"towers": towers
		},
		"crowd": {"bowl_per_copy": 36, "bowl_sway": 0.04, "status": "Working-art-density"}
	}


static func field_snapshot(field: FieldDefinition) -> Dictionary:
	var result: Dictionary = {"id": String(field.id)}
	for key: String in FIELD_KEYS:
		result[key] = field.get(key)
	var mound: Vector3 = PitchBatLab.MOUND_ORIGIN
	result["mound_origin"] = [mound.x, mound.y, mound.z]
	return result


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
		"instance": "npc-candidate:GRAND-I:v1:" + site,
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
		supplied if supplied != null else StadiumGrandIProperty.new()
	)
	property.name = "GrandIAuthoringCandidate"
	host.add_child(property)
	# Empty unresolved ownership validates the template only; never fabricate a starter grant.
	if not property.build("mogul", StadiumStarterLayout.empty(), StadiumStock.new()):
		_discard(property)
		return null
	# Template guide stripes have width0.08; center them inside the exact land footprint.
	# No item site or sport dimension moves. The unchanged generic helper centers its
	# guide on the mathematical property edge, extending4cm beyond that footprint.
	for edge: Node3D in property.get_children():
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
	if not boundary.build("straight"):
		_discard(property)
		return null
	var models: Array[Node3D] = boundary.items.duplicate()
	for site: String in StadiumBaselineSites.SITES:
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
	if models.size() != 75:
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

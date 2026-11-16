class_name StadiumSmallYardGeometryRebuildChecks
extends RefCounted
## One finite adapter/parity helper. Original factories and their live contracts stay frozen.
## Successful path: 2 entry + 4 frozen-source + 5*(1+16) + 5 site/camera = 96.

const M = preload("res://src/presentation/stadium/stadium_small_yard_scenery_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const ITEMS: Array[String] = ["ST-001", "ST-003", "ST-004", "ST-008", "ST-009"]
const COMMON_CHECKS: int = 16
const SITE_CHECKS: int = 5
const EXPECTED_CHECKS: int = 96
const EPS: float = 0.0002
const TOPS: Dictionary = {
	"ST-001": 0.50, "ST-003": 0.95, "ST-004": 1.04, "ST-008": 1.1375, "ST-009": 0.55
}
const FROZEN: Dictionary = {
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
	"stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4"
}


class GeometryProbe:
	extends "res://src/tests/stadium_grand_three_stack_geometry_test_support.gd"

	func _ready() -> void:
		pass


static func expected_checks() -> int:
	return 2 + FROZEN.size() * 2 + ITEMS.size() * (1 + COMMON_CHECKS) + SITE_CHECKS


static func run(parent: Node3D, check: Callable) -> void:
	var probe: GeometryProbe = GeometryProbe.new()
	parent.add_child(probe)
	probe.position = Vector3(1800, 0, 0)
	_emit(
		check,
		M.VERSION == 1 and M.ITEMS == ITEMS and expected_checks() == EXPECTED_CHECKS,
		"one scenery-only adapter covers exactly five accepted item identities"
	)
	_emit(
		check,
		(
			M.create("ST-002") == null
			and M.create("ST-079") == null
			and M.create("") == null
			and M.envelope("ST-079") == AABB()
			and M.reservation("ST-079") == AABB()
			and M.yaws("ST-079").is_empty()
		),
		"beach ball, receiver chair and unknown IDs are never substituted"
	)
	_frozen(check)
	for item: String in ITEMS:
		var model: Node3D = M.create(item)
		_emit(check, model != null, "accepted exact item creates its scenery use", {"item": item})
		if model == null:
			continue
		probe.add_child(model)
		await _common(probe, model, item, check)
		model.free()
	_sites(check)
	_frozen(check)
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"SMALL_YARD_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _frozen(check: Callable) -> void:
	for filename: String in FROZEN:
		_emit(
			check,
			FileAccess.get_sha256("res://src/presentation/stadium/" + filename) == FROZEN[filename],
			"accepted live factory remains byte-for-byte unchanged",
			{"file": filename}
		)


static func _common(probe: GeometryProbe, model: Node3D, item: String, check: Callable) -> void:
	var source: Node3D = M.source(item)
	probe.add_child(source)
	var source_before: String = _branches(probe, source)
	var visual: Node3D = model.get_node("Visual")
	var collision: Node3D = model.get_node("Collision")
	_emit(
		check,
		(
			model.get_child_count() == 2
			and model.transform == Transform3D.IDENTITY
			and visual.transform == Transform3D.IDENTITY
			and collision.transform == Transform3D.IDENTITY
		),
		"scenery keeps the original identity root and the same two named branches",
		{"item": item}
	)
	var before: String = probe._grand_snapshot(visual)
	_emit(
		check,
		before == probe._grand_snapshot(source.get_node("Visual")),
		"every original visible resource material pose and mesh array is preserved exactly",
		{"item": item}
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item") == item
			and model.get_meta("scenery_adapter_version") == 1
			and model.get_meta("scenery_only")
			and model.get_meta("static_geometry")
			and _no_events(model)
		),
		"scenery identity is explicit without any live surface or event metadata",
		{"item": item}
	)
	_emit(
		check,
		(
			collision.get_child_count() == 0
			and model.find_children("*", "CollisionObject3D", true, false).is_empty()
			and model.find_children("*", "CollisionShape3D", true, false).is_empty()
		),
		"all rigid bodies, shapes and sensors are absent from scenery",
		{"item": item}
	)
	_emit(
		check,
		SCAN._static_failure(model).is_empty(),
		"these five accepted visuals have no animation scripts particles lights or ambient motion",
		{"item": item}
	)
	var scan: Dictionary = SCAN._scan(model)
	_emit(
		check,
		str(scan.failure).is_empty() and int(scan.meshes) > 0 and int(scan.vertices) > 50,
		"every native mesh surface vertex normal and index array is inspected",
		{"item": item, "scan": scan}
	)
	_emit(
		check,
		SCAN._appearance_failure(model).is_empty(),
		"all accepted opaque materials remain intact without new shader or rendering effects",
		{"item": item}
	)
	var points: PackedVector3Array = POINTS._points(model)
	var actual: AABB = SCAN._bounds(points)
	_emit(
		check,
		M.envelope(item).grow(EPS).encloses(actual),
		"complete actual visible geometry fits its source-derived scenery envelope",
		{"item": item, "actual": str(actual)}
	)
	_emit(
		check,
		actual.position.y >= -EPS and absf(actual.end.y - float(TOPS[item])) < EPS,
		"full-scale source height and grounded base are retained without shrinking or floating",
		{"item": item, "actual": str(actual)}
	)
	var all_yaws: bool = M.yaws(item) == ([0] if item == "ST-001" else [0, 90, 180, 270])
	var measured: Array[Dictionary] = []
	for yaw: int in M.yaws(item):
		var turn: Basis = Basis(Vector3.UP, deg_to_rad(float(yaw)))
		var radius: float = 0.0
		var rotated: PackedVector3Array = []
		for point: Vector3 in points:
			var at: Vector3 = turn * point
			radius = maxf(radius, Vector2(at.x, at.z).length())
			all_yaws = (
				all_yaws
				and radius <= M.RADIUS + EPS
				and at.y >= -EPS
				and at.y <= M.HEIGHT + EPS
				and M.reservation(item).grow(EPS).has_point(at)
			)
			rotated.append(at)
		measured.append({"yaw": yaw, "radius": radius, "bounds": str(SCAN._bounds(rotated))})
	_emit(
		check,
		all_yaws,
		"all listed yaw poses fit the actual radius-one cylinder and one-and-a-half-metre height",
		{"item": item, "poses": measured}
	)
	print(
		(
			"SMALL_YARD_GEOMETRY_MEASUREMENT "
			+ JSON.stringify(
				{
					"item": item,
					"mesh_count": scan.meshes,
					"static_animation_envelope": true,
					"poses": measured
				},
				"",
				true,
				true
			)
		)
	)
	var second: Node3D = M.create(item)
	probe.add_child(second)
	_emit(
		check,
		probe._grand_snapshot(second.get_node("Visual")) == before,
		"fresh scenery copies reproduce the full accepted visual subtree deterministically",
		{"item": item}
	)
	_emit(
		check,
		SCAN._independent(model, second) and SCAN._independent(model, source),
		"all visible meshes and materials are independent between live and scenery copies",
		{"item": item}
	)
	SCAN._mutate(second)
	_emit(
		check,
		(
			probe._grand_snapshot(visual) == before
			and _branches(probe, source) == source_before
			and probe._grand_snapshot(second.get_node("Visual")) != before
		),
		"mutating another scenery copy changes neither live art and collision nor neighboring scenery",
		{"item": item}
	)
	second.free()
	var fresh: Node3D = M.create(item)
	probe.add_child(fresh)
	_emit(
		check,
		probe._grand_snapshot(fresh.get_node("Visual")) == before,
		"regeneration stays identical after destructive copy mutation",
		{"item": item}
	)
	fresh.free()
	await probe.get_tree().process_frame
	_emit(
		check,
		probe._grand_snapshot(visual) == before,
		"a rendered idle frame leaves the full static animation envelope unchanged",
		{"item": item}
	)
	var fresh_live: Node3D = M.source(item)
	_emit(
		check,
		(
			_branches(probe, source) == source_before
			and _branches(probe, fresh_live) == source_before
			and source.get_node("Collision").get_child_count() > 0
		),
		"existing and freshly regenerated live copies retain their original physical contracts",
		{"item": item}
	)
	fresh_live.free()
	source.free()


static func _branches(probe: GeometryProbe, root: Node3D) -> String:
	return (
		probe._grand_snapshot(root.get_node("Visual"))
		+ probe._grand_snapshot(root.get_node("Collision"))
	)


static func _no_events(node: Node) -> bool:
	for key: String in M.EVENT_KEYS:
		if node.has_meta(key):
			return false
	for child: Node in node.get_children():
		if not _no_events(child):
			return false
	return true


static func _sites(check: Callable) -> void:
	var cells: Dictionary = {}
	for id: String in StadiumLiveFurnishingItems.SITES:
		if id.begins_with("YS-"):
			cells[id] = StadiumLiveFurnishingItems.SITES[id].position
	var source_sites: bool = cells.size() == 8
	for side: int in [-1, 1]:
		for index in range(1, 5):
			var id: String = "YS-%s%d" % ["L" if side == -1 else "R", index]
			var expected: Vector3 = Vector3(
				side * (21.25 if index in [1, 3] else 23.75), 0, -6.75 if index < 3 else -4.25
			)
			source_sites = source_sites and cells.get(id) == expected
	_emit(check, source_sites, "all eight BL scenery cells retain their exact source centers")
	var field_clear: bool = true
	for id: String in cells:
		var row: Dictionary = {"item": "ST-002", "position": cells[id], "yaw": 0}
		var box: AABB = Transform3D(Basis.IDENTITY, cells[id]) * M.reservation("ST-001")
		field_clear = field_clear and StadiumProperty.contains("backyard", box)
		for shape: String in ["straight", "deeper_center"]:
			field_clear = (
				field_clear
				and StadiumLiveFurnishingItems._outside_play(
					row, StadiumRecipeBoundary.create(shape)
				)
			)
	_emit(
		check,
		field_clear,
		"complete YS reservations fit Backyard land and stay outside both physical field shapes"
	)
	var separated: bool = true
	for first: String in cells:
		for second: String in cells:
			if first != second:
				separated = (
					separated and (cells[first] as Vector3).distance_to(cells[second]) >= 2.5
				)
	_emit(
		check,
		separated,
		"adjacent radius-one reservations retain at least half a metre of clear separation"
	)
	var conflict: String = ""
	var structures: Array[Dictionary] = _structures()
	for id: String in cells:
		var pose: Transform3D = Transform3D(Basis.IDENTITY, cells[id])
		for structure: Dictionary in structures:
			if _overlaps(pose, M.reservation("ST-001"), structure.pose, structure.bounds):
				conflict = id + ":" + structure.id
	_emit(
		check,
		conflict.is_empty(),
		(
			"measured BASE and service/access/plant/light/large-pocket reservations clear YS "
			+ "cells; curved BOWL exclusions are tested by the owned-layout fixture"
		),
		{"conflict": conflict, "structure_count": structures.size()}
	)
	var camera_clear: bool = true
	var director: MatchCameraDirector = MatchCameraDirector.new()
	for shot: int in MatchCameraDirector.Shot.values():
		if shot == MatchCameraDirector.Shot.BALL_IN_PLAY:
			continue
		director.shot = shot as MatchCameraDirector.Shot
		for motion: int in MatchCameraDirector.PresentationMotion.values():
			director._presentation_motion = motion as MatchCameraDirector.PresentationMotion
			for progress: float in [0.0, 1.0]:
				director._presentation_progress = progress
				for left: bool in [false, true]:
					director.set_batter_handedness(left)
					var view: Transform3D = director._desired_transform(Vector3.ZERO, 0.0)
					for id: String in cells:
						var box: AABB = (
							Transform3D(Basis.IDENTITY, cells[id]) * M.reservation("ST-001")
						)
						camera_clear = (
							camera_clear
							and not box.has_point(view.origin)
							and (
								box.intersects_segment(
									view.origin, view.origin - view.basis.z * 80.0
								)
								== null
							)
						)
	_emit(
		check,
		camera_clear,
		(
			"all existing fixed-shot focus rays and presentation endpoints clear YS cells; this is "
			+ "not dynamic-flight camera certification"
		)
	)


static func _structures() -> Array[Dictionary]:
	# Clear-only measured scope. Curved BOWL-01/05 and handed JOIN reservations
	# can conflict and are subject to the owned-layout fixture's explicit exclusion.
	var result: Array[Dictionary] = []
	for site: String in StadiumBaselineSites.SITES:
		for item: String in ["ST-029", "ST-031", "ST-030"]:
			result.append(
				{
					"id": site + ":" + item,
					"pose": StadiumBaselineSites.pose(site),
					"bounds": StadiumStraightOwnedModels.envelope(item)
				}
			)
		result.append(
			{
				"id": site + ":ROOM-ACCESS",
				"pose": StadiumBaselineSites.pose(site),
				"bounds": StadiumFacilityOwnedModels.ROOM_RESERVATION
			}
		)
	for site: String in StadiumFacilityItems.GROUND_SITES:
		result.append(
			{
				"id": site,
				"pose": StadiumFacilityItems.pose(site),
				"bounds": StadiumFacilityItems.reserved(site)
			}
		)
	for site: String in StadiumGroundPropsItems.SITES:
		var row: Dictionary = StadiumGroundPropsItems.SITES[site]
		if site.begins_with("PLANT") or site.begins_with("BED"):
			result.append(
				{
					"id": site,
					"pose": Transform3D(Basis.IDENTITY, row.position),
					"bounds": StadiumGroundPropsModels.envelope(row.items[0])
				}
			)
	for site: String in StadiumClubSites.SITES:
		var row: Dictionary = StadiumClubSites.SITES[site]
		result.append(
			{
				"id": site,
				"pose": Transform3D(Basis(Vector3.UP, deg_to_rad(row.yaw)), row.position),
				"bounds": StadiumClubSites.envelope(row.item)
			}
		)
	for site: String in StadiumYardLightModels.SITES:
		result.append(
			{
				"id": site,
				"pose":
				Transform3D(
					Basis(Vector3.UP, deg_to_rad(StadiumYardLightSites.yaw(site))),
					StadiumYardLightModels.SITES[site]
				),
				"bounds": StadiumYardLightModels.ENVELOPE
			}
		)
	for site: String in StadiumFlagItems.SITES:
		result.append(
			{
				"id": site,
				"pose": Transform3D(Basis.IDENTITY, StadiumFlagItems.SITES[site].position),
				"bounds": StadiumFlagModels.ENVELOPE
			}
		)
	for site: String in ["YL-L", "YL-R"]:
		result.append(
			{
				"id": site + ":FULL-POCKET",
				"pose":
				Transform3D(Basis.IDENTITY, StadiumLiveFurnishingItems.SITES[site].position),
				"bounds": AABB(Vector3(-3, 0, -4), Vector3(6, 3.5, 8))
			}
		)
	for profile: String in StadiumFloodlightOwnedItems.PROFILES:
		var sites: Dictionary = StadiumFloodlightOwnedItems.sites(profile)
		for site: String in sites:
			var row: Dictionary = StadiumFloodlightOwnedItems.row("GEOMETRY", profile, site)
			result.append(
				{
					"id": site,
					"pose": Transform3D.IDENTITY,
					"bounds": StadiumFloodlightOwnedItems.bounds(row)
				}
			)
	result.append(
		{
			"id": "RECEIVER-CATCH",
			"pose": Transform3D.IDENTITY,
			"bounds": StadiumReceiverOwnedItems.RESERVE
		}
	)
	result.append(
		{
			"id": "ENTRY-GATE",
			"pose": Transform3D(Basis.IDENTITY, StadiumStraightItems.ENTRY),
			"bounds": StadiumStraightOwnedModels.envelope("ST-035")
		}
	)
	return result


static func _overlaps(at: Transform3D, ab: AABB, bt: Transform3D, bb: AABB) -> bool:
	var ac: Vector3 = at * ab.get_center()
	var bc: Vector3 = bt * bb.get_center()
	if absf(ac.y - bc.y) >= (ab.size.y + bb.size.y) * 0.5 - EPS:
		return false
	for axis: Vector3 in [at.basis.x, at.basis.z, bt.basis.x, bt.basis.z]:
		var ae: float = (
			(absf(axis.dot(at.basis.x)) * ab.size.x + absf(axis.dot(at.basis.z)) * ab.size.z) * 0.5
		)
		var be: float = (
			(absf(axis.dot(bt.basis.x)) * bb.size.x + absf(axis.dot(bt.basis.z)) * bb.size.z) * 0.5
		)
		if absf(axis.dot(ac - bc)) >= ae + be - EPS:
			return false
	return true

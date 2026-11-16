extends Node3D
## New whole-composition geometry contract, independent of rendered or gameplay acceptance.

const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")

var _native: NativeCapture
var _failures: int = 0


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var graph: StadiumClubOffsetGraph = StadiumClubOffsetGraph.new()
	_graph(graph)
	var baseline: StadiumPropertyGeometry = StadiumClubVenueStudy.build(self)
	var old: Dictionary = baseline.get_meta("candidate_venue").duplicate(true)
	var old_bytes: String = StadiumClubFixtureStudy.encode(StadiumClubFixtureStudy.capture(old))
	await _draw_before_free()
	baseline.free()
	var property: StadiumPropertyGeometry = StadiumClubOffsetVenueStudy.build(self)
	_check(property != null, "new shaped assembly builds")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue")
	_check(
		record.version == 2 and record.items.size() == 72 and record.live_units == 0,
		"distinct v2 has exactly seventy-two copies and no live obstacle grant"
	)
	_check(
		record.environment_certificates.is_empty() and record.status == "CANDIDATE",
		"no environment certificate or production eligibility inferred"
	)
	var boundary: StadiumClubOffsetBoundary = property.get_node("ClubBoundary")
	_check(
		boundary.items.size() == 65 and boundary.graph.signature() == graph.signature(),
		"sixty-five shared infrastructure copies use the composed graph"
	)
	_check(not property.has_node("TemplateBackWall"), "infinite old back collider absent")
	_compare(old, record)
	_panels(boundary)
	_bounds(property, graph)
	var frozen: Dictionary = StadiumClubOffsetFixtureStudy.capture(record)
	_check(
		(
			StadiumClubOffsetFixtureStudy.valid(frozen)
			and not StadiumClubFixtureStudy.valid(frozen)
			and not StadiumClubOffsetFixtureStudy.valid(StadiumClubFixtureStudy.capture(old))
		),
		"old and new fixture families reject each other's envelopes"
	)
	_check(
		not StadiumLayoutSnapshot.valid(frozen), "authoring envelope has no production authority"
	)
	_check(
		StadiumClubFixtureStudy.encode(StadiumClubFixtureStudy.capture(old)) == old_bytes,
		"new assembly does not mutate held straight-v1 serialized bytes"
	)
	if DisplayServer.get_name() != "headless":
		_check(
			await _native.resize(Vector2i(1280, 720)),
			"overview starts from acknowledged normal native window and content extent"
		)
	_check(
		await StadiumAssetCapture.save(
			self,
			AABB(Vector3(-33, 0, -8), Vector3(66, 10, 40)),
			"AC-01-offset-v2-overview",
			Vector3(-1, 1.25, -1)
		),
		"native shaped Club overview captured"
	)
	if DisplayServer.get_name() != "headless" and not StadiumAssetCapture.directory().is_empty():
		var image: Image = Image.load_from_file(
			StadiumAssetCapture.directory().path_join("AC-01-offset-v2-overview.png")
		)
		_check(
			(
				image != null
				and not image.is_empty()
				and image.get_size() == Vector2i(1280, 720)
				and get_window().size == Vector2i(1280, 720)
				and (
					DisplayServer.window_get_size(get_window().get_window_id())
					== Vector2i(1280, 720)
				)
			),
			"saved overview contains actual 1280x720 pixels from the acknowledged native window"
		)
	_check(_native._failures == 0, "overview capture handshake failures propagate to this scene")
	await _draw_before_free()
	property.free()
	baseline = StadiumClubVenueStudy.build(self)
	_check(
		(
			StadiumClubFixtureStudy.encode(
				StadiumClubFixtureStudy.capture(baseline.get_meta("candidate_venue"))
			)
			== old_bytes
		),
		"rebuilding straight-v1 after shaped assembly preserves exact bytes"
	)
	await _draw_before_free()
	baseline.free()
	position.x = 1
	_check(
		StadiumClubOffsetVenueStudy.build(self) == null,
		"transformed host rejects before building ambiguous world poses"
	)
	position.x = 0
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Offset Club assembly passed: composed graph, copies, poses and frozen baseline."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _graph(graph: StadiumClubOffsetGraph) -> void:
	var rows: Array[Dictionary] = graph.segments()
	_check(
		rows.size() == 19 and rows.size() == graph.polygon().size(),
		"eleven original edges plus eight dugout subdivisions form one closed boundary"
	)
	var ids: Array[String] = []
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		_check(
			not ids.has(row.id) and row.b.is_equal_approx(rows[(index + 1) % rows.size()].a),
			"unique segment ownership and contiguous polygon"
		)
		ids.append(row.id)
		_check(graph.outer_vertex(index).is_finite(), "finite convex and concave miters")
		if row.id.begins_with("BACK-"):
			_check(
				ClubCareer.same(row, StadiumOffsetBoundary.new().segment(row.id)),
				"back segment remains exact Offset geometry"
			)
	for left in [false, true]:
		var prefix: String = "DUGOUT-L" if left else "DUGOUT-R"
		_check(
			graph.segment(prefix + "-OPEN").role == "DUGOUT_OPENING_DEAD",
			"each central dead aperture has independent ownership"
		)
		var start: Vector3 = StadiumDugoutRecipe.rail_point(13, -2, left)
		var end: Vector3 = StadiumDugoutRecipe.rail_point(13, 3, left)
		var clipped: Vector3 = graph.clip(start, end)
		_check(
			clipped.distance_to(end) > 1 and graph.contains(Vector2(clipped.x, clipped.z)),
			"open dugout is closed to defender navigation"
		)
	var poles: Array[Dictionary] = StadiumFoulPoleSites.rows(graph)
	_check(poles.size() == 2, "two recomputed foul-ray intersections")
	for pole: Dictionary in poles:
		var point: Vector2 = Vector2(pole.position.x, pole.position.z)
		var row: Dictionary = graph.segment(pole.segment)
		_check(
			(
				absf(absf(point.x) / point.y - tan(deg_to_rad(42))) < 0.00001
				and (
					point.distance_to(Geometry2D.get_closest_point_to_segment(point, row.a, row.b))
					< 0.00001
				)
				and pole.split == row.height
			),
			"pole site and scoring cap match actual back segment"
		)
	_check(
		(
			StadiumDugoutBoundary.candidate("offset_gables") == null
			and StadiumRecipeBoundary.create("offset_gables") == null
		),
		"frozen public graph factories remain closed"
	)


func _compare(old: Dictionary, record: Dictionary) -> void:
	var old_sites: Dictionary = {}
	for row: Dictionary in old.items:
		old_sites[row.site] = row
	var unchanged: int = 0
	var counts: Dictionary = {}
	for row: Dictionary in record.items:
		counts[row.item] = counts.get(row.item, 0) + 1
		if row.item in ["ST-065", "ST-021", "ST-039"]:
			continue
		_check(
			(
				old_sites.has(row.site)
				and old_sites[row.site].item == row.item
				and ClubCareer.same(old_sites[row.site].transform, row.transform)
			),
			"all non-back, non-pole, non-board copies preserve old site and exact transform"
		)
		unchanged += 1
	_check(
		unchanged == 42 and ClubCareer.same(counts, StadiumClubOffsetVenueStudy.COUNTS),
		"forty-two unchanged poses, two recomputed poles and one manual-board pose retain 45 copies"
	)
	_check(
		(
			record.blueprint_value == old.blueprint_value
			and record.land_value == old.land_value
			and (
				record.copy_value
				== old.copy_value + 4 * int(StadiumCatalog.item("ST-065").copy_price)
			)
		),
		"only four additional padded panels change endowment valuation"
	)


func _panels(boundary: StadiumClubOffsetBoundary) -> void:
	var recipes: Array[Dictionary] = StadiumOffsetWallRecipes.back("ST-065")
	var total: float = 0
	for recipe: Dictionary in recipes:
		var found: Node3D = null
		for model: Node3D in boundary.items:
			if model.get_meta("candidate_site", "") == recipe.socket:
				found = model
		_check(found != null, "each shaped panel socket has one installed model")
		if found == null:
			continue
		var length: float = StadiumOffsetWallModels.dimensions(recipe.item, recipe.span).x
		_check(
			(
				found.transform == StadiumWallRecipes.placement(recipe)
				and not found.has_node("PanelCollision")
			),
			"exact pose; joined graph alone owns collision"
		)
		var first: Vector3 = found.transform * Vector3(-length / 2, 0, 0)
		var last: Vector3 = found.transform * Vector3(length / 2, 0, 0)
		_check(
			(
				(
					Vector2(first.x, first.z).is_equal_approx(recipe.a)
					and Vector2(last.x, last.z).is_equal_approx(recipe.b)
				)
				or (
					Vector2(first.x, first.z).is_equal_approx(recipe.b)
					and Vector2(last.x, last.z).is_equal_approx(recipe.a)
				)
			),
			"actual mesh frame endpoints meet recipe front face"
		)
		total += length
	var graph_length: float = 0
	for row: Dictionary in boundary.graph.segments():
		if row.role == "BACK_WALL_TERMINAL":
			graph_length += row.a.distance_to(row.b)
		if row.role.begins_with("DUGOUT"):
			_check(
				not boundary.has_node(NodePath(row.id)), "no hidden slab spans dugout replacement"
			)
	_check(
		recipes.size() == 27 and absf(total - graph_length) < 0.0001,
		"twenty-seven fixed panels exactly close all six back segments"
	)


func _bounds(property: StadiumPropertyGeometry, graph: StadiumClubOffsetGraph) -> void:
	for node: MeshInstance3D in property.find_children("*", "MeshInstance3D", true, false):
		# Property boundary marker strokes straddle land edges by design; test catalog art only.
		var owner_node: Node = node
		while owner_node != property and not owner_node.has_meta("candidate_instance"):
			owner_node = owner_node.get_parent()
		if owner_node == property:
			continue
		_check(
			StadiumProperty.contains("club", node.global_transform * node.get_aabb()),
			"actual mesh stays inside Club land: " + str(node.get_path())
		)
	for site: String in StadiumBaselineSites.SITES:
		_check(
			StadiumBaselineSites.fits(site, "club", site.ends_with("2")),
			"unchanged lower-host and canopy reservations remain contained"
		)
	for left in [false, true]:
		_check(StadiumDugoutRecipe.fits(left, "club"), "full concrete dugout envelope fits")
	var pose: Transform3D = StadiumClubOffsetVenueStudy.board_pose()
	var board: AABB = pose * StadiumClubSites.envelope("ST-039")
	var installed: Node3D = null
	for model: Node3D in property.find_children("*", "Node3D", true, false):
		if model.get_meta("stadium_item", "") == "ST-039" and model.has_meta("candidate_instance"):
			installed = model
	_check(
		(
			installed != null
			and installed.transform == pose
			and pose.origin.y == 0
			and installed.get_meta("candidate_site", "") == StadiumClubOffsetVenueStudy.BOARD_SITE
		),
		"one original grounded manual board occupies the intentional v2-only corner site"
	)
	# Axis-aligned reservation separation is conservative for both independently rotated assets.
	for site: String in StadiumBaselineSites.SITES:
		var host: Transform3D = StadiumBaselineSites.pose(site)
		_check(
			not board.grow(0.5).intersects(host * StadiumBaselineSites.LOWER_BOUNDS),
			"manual board retains half-meter stand reservation clearance"
		)
		if site.ends_with("2"):
			_check(
				not board.grow(0.5).intersects(host * StadiumBaselineSites.LOWER_ROOF_BOUNDS),
				"manual board retains half-meter lower-canopy reservation clearance"
			)
	for left in [false, true]:
		_check(
			not board.grow(0.5).intersects(
				StadiumDugoutRecipe.placement(left) * StadiumDugoutRecipe.ENVELOPE
			),
			"manual board retains half-meter dugout reservation clearance"
		)
	var maximum_play_x: float = -INF
	for index in range(graph.polygon().size()):
		maximum_play_x = maxf(maximum_play_x, graph.outer_vertex(index).x)
	_check(
		board.position.x > maximum_play_x + 0.1,
		"entire board envelope clears every exact outer wall miter by at least ten centimeters"
	)

	_check(StadiumProperty.contains("club", board), "manual outfield-corner reservation fits")
	for index in range(8):
		var point: Vector3 = board.get_endpoint(index)
		_check(
			not graph.contains(Vector2(point.x, point.z)), "manual board stays outside shaped play"
		)
	for row: Dictionary in graph.segments():
		var a: Vector2 = Vector2(board.position.x, board.position.z)
		var b: Vector2 = Vector2(board.end.x, board.end.z)
		_check(not Rect2(a, b - a).has_point(row.a), "wall vertices do not enter board reservation")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _draw_before_free() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

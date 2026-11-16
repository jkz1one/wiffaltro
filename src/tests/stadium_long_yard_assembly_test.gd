extends Node3D
## Independent LONG-YARD-v2 proof, with preserved v1 guard and canopy-support controls.
# gdlint: disable=max-returns

const AssemblyProof = preload("res://src/tests/stadium_long_yard_assembly_proof.gd")
const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
const Evidence = preload("res://src/tests/stadium_long_yard_evidence.gd")
const PREFIX: String = "finals-candidate:LONG-YARD:v2:"
const OWNER: String = "finals-venue:long-yard:v2"
const EXPECTED: Dictionary = {
	"ST-065": 22,
	"ST-022": 16,
	"ST-023": 16,
	"ST-074": 2,
	"ST-021": 2,
	"ST-026": 1,
	"ST-073": 1,
	"ST-029": 4,
	"ST-053": 2,
	"ST-039": 1
}
const VERSIONS: Dictionary = {
	"ST-065": 2,
	"ST-022": 2,
	"ST-023": 2,
	"ST-074": 1,
	"ST-021": 1,
	"ST-026": 1,
	"ST-073": 2,
	"ST-029": 2,
	"ST-053": 2,
	"ST-039": 1
}
const BASE_SITES: Array[String] = ["BASE-L1", "BASE-L2", "BASE-R1", "BASE-R2"]
const ROOF_SITES: Array[String] = ["ROOF:BASE-L2", "ROOF:BASE-R2"]
var _proof: AssemblyProof
var _failures: int = 0
var _native: NativeCapture
var _camera: Camera3D


func _ready() -> void:
	_proof = AssemblyProof.new(self)
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var property: StadiumPropertyGeometry = StadiumLongYardStudy.build(self)
	_check(property != null, "complete independent Long Yard assembly builds")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue")
	_contract(property, record)
	_manifest(property, record)
	_graph(property, record)
	_geometry(property, record)
	var stands: Array[Node3D] = []
	for site: String in BASE_SITES:
		var stand: Node3D = property.objects[PREFIX + site]
		stands.append(stand)
		_lower(stand, site)
	for site: String in ROOF_SITES:
		_roof(property, record, site)
	var net: Node3D = property.objects[PREFIX + "RECEIVER-CATCH"]
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _ray_controls(net)
	await _proof.v1_predecessor(stands)
	_spectator_clearance(stands, net)
	_check(
		property.find_children("*", "Light3D", true, false).is_empty(),
		"zero tower lights in the real property"
	)
	_setup_view()
	await _capture("LONG-YARD-whole-layout", Vector3(62, 56, -64), Vector3(0, 3, 10), 99)
	await _capture("LONG-YARD-roof-context", Vector3(39, 24, -14), Vector3(0, 4, 10), 69)
	await _capture("LONG-YARD-board-context", Vector3(-7, 13, 8), Vector3(-19, 3, 27), 27)
	await _capture("LONG-YARD-board-detail", Vector3(-20, 5, 17), Vector3(-20, 4, 30), 10)
	_check(_native._failures == 0, "native resize and capture failures propagate")
	property.queue_free()
	await get_tree().process_frame
	position.x = 1
	_check(StadiumLongYardStudy.build(self) == null, "transformed authoring host fails closed")
	position.x = 0
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro LONG-YARD assembly passed: exact 67 copies, 200 people, two owned roofs.")
	get_tree().quit(0 if _failures == 0 else 1)


func _contract(property: StadiumPropertyGeometry, record: Dictionary) -> void:
	_check(property is StadiumLongYardProperty, "independent Long Yard property class")
	_check(
		record.id == "LONG-YARD" and record.version == 2 and record.property == "club",
		"exact Long Yard version and Club land"
	)
	_check(
		(
			record.owner == OWNER
			and record.kind == "finals-authored-candidate"
			and record.status == "CANDIDATE"
			and record.mapping == "WORKING"
			and record.live_units == 0
		),
		"unqualified isolated authoring never grants a live obstacle or finals route"
	)
	_check(
		(
			record.environment.target_slots == ["16:10"]
			and record.environment.target_weather == ["clear"]
			and record.environment.certificates.is_empty()
			and not record.environment.night_eligible
		),
		"only fixed 16:10 clear, without qualification certificates"
	)
	_check(
		(
			record.lighting.towers.is_empty()
			and record.lighting.active_lights == 0
			and record.lighting.preset == "NONE"
			and record.lighting.profile == "NONE"
		),
		"no tower recipe is inherited"
	)
	_check(
		(
			record.endowment
			== {
				"blueprint_value": 3750, "copy_value": 2950, "land_value": 2200, "total_value": 8900
			}
		),
		"independent current catalog endowment"
	)
	_check(
		(
			record.surface
			== {
				"geometry": "flat",
				"grass": "default",
				"ground": "default",
				"markings": "default",
				"bounds": [-40, -22, 80, 68]
			}
		),
		"exact flat Club footprint"
	)
	_check(
		(
			record.crowd.total == 200
			and record.crowd.baseline_lower == 200
			and record.crowd.bowl_lower == 0
		),
		"four fifty-person baseline art crowds only"
	)
	_check(
		(
			record.structural_layers
			== {
				"baseline": "BASE-LOWER-SIGHTLINE-v2",
				"roof_mount": "BASE-LOWER-ROOF-v1",
				"roof_interface": "ST029-guard-v2_LOWER-CANOPY-v2",
				"bowl": "NONE",
				"roofs": 2,
				"transition_concourses": 0
			}
		),
		"explicit guard-v2 lower and two independently owned support-corrected canopies"
	)
	_check(
		(
			record.camera_profile.id == "LY-BATTING-BEHIND-RECEIVER-v1"
			and record.camera_profile.right_entry == [0.18, 2.10, -6.5]
			and record.camera_profile.left_entry == [-0.18, 2.10, -6.5]
			and (
				record.camera_profile.live_motion
				== "unchanged-inherited-continuous-motion-turn-and-collision"
			)
		),
		"independent Long Yard entry identity preserves inherited continuous motion"
	)
	_check(
		(
			record.render_profile.native_minimum_msaa_3d == "4x"
			and record.render_profile.ownership == "installed-property-viewport-lifetime"
			and record.render_profile.restore == "last-owner-if-unchanged"
		),
		"render quality is a scoped reversible property lease"
	)
	var source: FieldDefinition = load("res://src/content/fields/npc_venue_field.tres")
	_check(
		(
			property.field != source
			and property.field.get_script() == source.get_script()
			and ClubCareer.same(
				StadiumLongYardStudy.field_snapshot(property.field),
				StadiumLongYardStudy.field_snapshot(source)
			)
		),
		"private exact unchanged field semantics"
	)
	for key: String in {
		"safe_hit_z_m": 11.25,
		"deep_air_z_m": 17.0,
		"back_wall_z_m": 23.4,
		"home_run_height_m": 3.25,
		"fair_half_angle_degrees": 42.0,
		"dead_ball_z_m": 29.0
	}:
		var expected: Dictionary = {
			"safe_hit_z_m": 11.25,
			"deep_air_z_m": 17.0,
			"back_wall_z_m": 23.4,
			"home_run_height_m": 3.25,
			"fair_half_angle_degrees": 42.0,
			"dead_ball_z_m": 29.0
		}
		_check(record.field[key] == expected[key], "unscaled rule dimension " + key)
	_proof.mound_precision(record)
	var blueprints: Array = EXPECTED.keys()
	blueprints.sort()
	_check(
		(
			record.blueprint_entitlements == blueprints
			and record.catalog == StadiumCatalog.signature()
		),
		"ten exact blueprint types with independently counted copies"
	)


func _manifest(property: StadiumPropertyGeometry, record: Dictionary) -> void:
	var counts: Dictionary = {}
	var sites: Array[String] = []
	var instances: Array[String] = []
	_check(record.items.size() == 67 and property.objects.size() == 67, "exact 67 complete copies")
	for row: Dictionary in record.items:
		_check(not sites.has(row.site) and not instances.has(row.instance), "unique site and copy")
		sites.append(row.site)
		instances.append(row.instance)
		counts[row.item] = counts.get(row.item, 0) + 1
		_check(
			row.instance == PREFIX + row.site and row.model_version == VERSIONS.get(row.item, -1),
			"independent namespace and source factory version"
		)
		var roof: bool = row.item == "ST-053"
		var expected_host: String = PREFIX + row.site.trim_prefix("ROOF:") if roof else OWNER
		_check(
			row.host == expected_host and row.mount == ("BASE-LOWER-ROOF-v1" if roof else ""),
			"each canopy belongs to its own exact lower copy and mount"
		)
		_check(
			row.interface == ("ST029-guard-v2_LOWER-CANOPY-v2" if roof else ""),
			"exact lower-only interface is serialized only for its two roof copies"
		)
		var variant: String = (
			"BASE-LOWER-SIGHTLINE-v2"
			if row.item == "ST-029"
			else ("BASE-LOWER-CANOPY-GUARD-v2" if roof else "")
		)
		_check(
			row.model_variant == variant, "explicit guard-v2 and revised lower-only canopy identity"
		)
		_check(row.transform.size() == 12, "complete rigid transform is serialized")
		var model: Node3D = property.objects.get(row.instance)
		_check(model != null, "every manifest copy has physical geometry")
		if model == null:
			continue
		_check(
			(
				model.get_meta("candidate_site") == row.site
				and model.get_meta("candidate_host") == row.host
				and model.get_meta("candidate_mount", "") == row.mount
				and model.get_meta("candidate_model_version") == row.model_version
			),
			"real geometry carries exact copy ownership and host"
		)
		_check(
			ClubCareer.same(_components(model.global_transform), row.transform),
			"every global transform equals the full serialized pose"
		)
		_check(
			(
				is_equal_approx(model.global_basis.determinant(), 1.0)
				and model.global_basis.get_scale().is_equal_approx(Vector3.ONE)
			),
			"no hidden scale or mirror"
		)
		if row.item == "ST-039":
			_check(
				(
					row.site == "SCORE-SMALL"
					and model.transform == Transform3D(Basis(Vector3.UP, PI), Vector3(-20, 0, 30))
				),
				"independent historical scoreboard exact grounded180degree pose"
			)
		if row.item == "ST-026":
			_check(
				model.transform == Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.05)),
				"target keeps the unchanged primary-receiver socket"
			)
		if row.item == "ST-073":
			_check(
				model.transform == Transform3D.IDENTITY, "corrected net keeps unchanged catch pose"
			)
		if row.item == "ST-029":
			_check(row.site in BASE_SITES, "only the four authored lower sites")
		if roof:
			_check(row.site in ROOF_SITES, "canopies only on second lower hosts")
		if row.item == "ST-065":
			var index: int = int(String(row.site).get_slice("-", 2))
			_check(
				row.span == ("angled_end" if index in [1, 22] else "full"),
				"twenty full back panels and the two original short shoulders"
			)
	_check(ClubCareer.same(counts, EXPECTED), "independent 67-copy inventory")
	for site: String in [
		"BOWL-01",
		"BOWL-02",
		"BOWL-03",
		"BOWL-04",
		"BOWL-05",
		"JOIN-L",
		"JOIN-R",
		"LANDMARK-A",
		"SCORE-LARGE-A",
		"SIDE-SEAT-L",
		"SIDE-SEAT-R"
	]:
		_check(
			not sites.has(site) and site in record.empty_sites, "optional site stays empty: " + site
		)
	for side: String in ["ST-022", "ST-023"]:
		for index in range(1, 20):
			var removed: bool = index in ([12, 13, 14] if side == "ST-022" else [6, 7, 8])
			_check(
				sites.has("%s-%02d" % [side, index]) != removed,
				"CI opening replaces exactly its three paid side panels"
			)


func _graph(property: StadiumPropertyGeometry, record: Dictionary) -> void:
	var boundary: StadiumClubBoundaryStudy = property.get_node("ClubBoundary")
	_check(
		boundary.items.size() == 60 and not property.has_node("TemplateBackWall"),
		"complete 60-copy Club infrastructure replaces the obsolete continuous wall"
	)
	_check(
		(
			boundary.get_script()
			== preload("res://src/presentation/stadium/stadium_club_boundary_study.gd")
		),
		"unchanged Club boundary factory"
	)
	var rows: Array[Dictionary] = boundary.graph.segments()
	var ids: Array[String] = [
		"REAR-01",
		"SIDE-R-01-IN",
		"DUGOUT-R-FACE-IN",
		"DUGOUT-R-OPEN",
		"DUGOUT-R-FACE-OUT",
		"SIDE-R-01-OUT",
		"RETURN-R-01",
		"BACK-01",
		"BACK-02",
		"BACK-03",
		"RETURN-L-01",
		"SIDE-L-01-OUT",
		"DUGOUT-L-FACE-OUT",
		"DUGOUT-L-OPEN",
		"DUGOUT-L-FACE-IN",
		"SIDE-L-01-IN"
	]
	var points: Array[Vector2] = [
		Vector2(-8, -6),
		Vector2(8, -6),
		_rail(10, false),
		_rail(12, false),
		_rail(14, false),
		_rail(16, false),
		Vector2(24, 23.4),
		Vector2(21.519454636569, 23.4),
		Vector2(10, 26),
		Vector2(-10, 26),
		Vector2(-21.519454636569, 23.4),
		Vector2(-24, 23.4),
		_rail(16, true),
		_rail(14, true),
		_rail(12, true),
		_rail(10, true)
	]
	_check(rows.size() == 16 and record.graph.segments.size() == 16, "exact sixteen CI graph edges")
	for index in range(mini(rows.size(), 16)):
		var row: Dictionary = rows[index]
		var back: bool = index in [7, 8, 9]
		var opening: bool = index in [3, 13]
		var face: bool = index in [2, 4, 12, 14]
		var role: String = (
			"REAR_PERIMETER_DEAD"
			if index == 0
			else (
				"BACK_WALL_TERMINAL"
				if back
				else (
					"DUGOUT_OPENING_DEAD"
					if opening
					else ("DUGOUT_FACE_LIVE" if face else "SIDE_RETURN_LIVE")
				)
			)
		)
		var priority: int = (
			300
			if index == 0
			else (
				200
				if back
				else 250 if opening else (350 if face else 100 if index in [6, 10] else 50)
			)
		)
		_check(
			(
				row.id == ids[index]
				and row.a.is_equal_approx(points[index])
				and row.b.is_equal_approx(points[(index + 1) % 16])
				and row.role == role
				and row.priority == priority
				and row.height == (3.25 if back else 2.4 if opening else 1.2)
			),
			"independently frozen graph endpoint role height and priority " + ids[index]
		)
		var frozen: Dictionary = record.graph.segments[index]
		_check(
			(
				frozen.id == row.id
				and frozen.a == [row.a.x, row.a.y]
				and frozen.b == [row.b.x, row.b.y]
				and frozen.role == row.role
				and frozen.height == row.height
				and frozen.priority == row.priority
			),
			"serialized graph equals real graph, including both openings"
		)
	_check(
		(
			record.graph.id == "PROTOTYPE-CLUB-DUGOUT-DEEPER-CENTER-v1"
			and record.graph.signature == boundary.graph.signature()
			and record.boundary == boundary.graph.signature()
			and record.graph.thickness == 0.35
			and record.graph.defender_radius == 0.54
			and record.graph.ball_radius == 0.0365
			and record.graph.prism_margin == 0.0
			and record.graph.query_layer == 32
		),
		"complete exact source-bound graph contract"
	)
	_check(record.graph.poles.size() == 2, "two explicit angled foul-pole sockets")
	for pole: Dictionary in record.graph.poles:
		var model: Node3D = property.objects[PREFIX + pole.site]
		var point: Vector3 = model.global_position
		_check(
			(
				is_equal_approx(absf(point.x), point.z * tan(deg_to_rad(42.0)))
				and point.z > 23.4
				and point.z < 26.0
				and pole.split == 3.25
				and pole.radius == 0.09
				and pole.height == 8.0
				and pole.position == [point.x, point.y, point.z]
				and pole.segment in ["BACK-01", "BACK-03"]
			),
			"angled pole stays on unchanged fair ray"
		)
	var rear: MeshInstance3D = boundary.get_node("TemplateRearWall")
	_check(
		(
			rear.position == Vector3(0, 0.6, -6.175)
			and (rear.mesh as BoxMesh).size == Vector3(16, 1.2, 0.35)
		),
		"unchanged rear reference infrastructure is not a paid copy"
	)


func _geometry(property: StadiumPropertyGeometry, record: Dictionary) -> void:
	var counts: Dictionary = {}
	for model: Node3D in property.find_children("*", "Node3D", true, false):
		if not model.has_meta("candidate_instance"):
			continue
		var item: String = model.get_meta("stadium_item", "")
		counts[item] = counts.get(item, 0) + 1
		var row: Dictionary = _row(record, model.get_meta("candidate_site"))
		var reference: Node3D = _factory(row)
		_check(reference != null, "only ten intended physical factories")
		if reference != null:
			_check(
				_members_match(reference, model),
				"complete unchanged visible and collision factory: " + row.site
			)
			if item in ["ST-029", "ST-053", "ST-065"]:
				_factory_controls(reference, model)
			reference.free()
	_check(
		ClubCareer.same(counts, EXPECTED), "actual descendant counts equal the independent manifest"
	)
	for mesh: MeshInstance3D in property.find_children("*", "MeshInstance3D", true, false):
		_check(
			StadiumProperty.contains("club", mesh.global_transform * mesh.get_aabb()),
			"every real visible mesh fits Club land: " + str(mesh.get_path())
		)
	for shape: CollisionShape3D in property.find_children("*", "CollisionShape3D", true, false):
		_check(
			(
				shape.shape != null
				and StadiumProperty.contains(
					"club", shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
				)
			),
			"every real collider fits Club land"
		)


func _factory(row: Dictionary) -> Node3D:
	match String(row.item):
		"ST-065", "ST-022", "ST-023":
			var panel: Node3D = StadiumWallPanelModels.create(row.item, row.span)
			panel.get_node("PanelCollision").free()
			return panel
		"ST-074":
			return StadiumConcreteDugoutModels.create()
		"ST-021":
			return StadiumFoulPoleModels.create(3.25)
		"ST-026":
			return StadiumTargetModels.create()
		"ST-073":
			return StadiumReceiverNetModels.create()
		"ST-029":
			return _proof.approved_lower()
		"ST-053":
			return _proof.approved_canopy()
		"ST-039":
			return StadiumClubModels.create("ST-039")
	return null


func _members_match(expected: Node, actual: Node) -> bool:
	if (
		actual == null
		or actual.get_class() != expected.get_class()
		or actual.get_child_count() != expected.get_child_count()
	):
		return false
	for index in range(expected.get_child_count()):
		var source: Node = expected.get_child(index)
		var found: Node = actual.get_child(index)
		if source.get_class() != found.get_class():
			return false
		if source is Node3D and (found as Node3D).transform != source.transform:
			return false
		if source is MeshInstance3D:
			var mesh: MeshInstance3D = found as MeshInstance3D
			if (
				mesh.mesh == null
				or mesh.visible != source.visible
				or mesh.transparency != source.transparency
				or mesh.cast_shadow != source.cast_shadow
				or mesh.mesh.get_surface_count() != source.mesh.get_surface_count()
			):
				return false
			for surface in range(source.mesh.get_surface_count()):
				if mesh.mesh.surface_get_arrays(surface) != source.mesh.surface_get_arrays(surface):
					return false
			var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
			var original: StandardMaterial3D = source.material_override as StandardMaterial3D
			if (material == null) != (original == null):
				return false
			if (
				material != null
				and (
					material.albedo_color != original.albedo_color
					or material.transparency != original.transparency
					or material.cull_mode != original.cull_mode
				)
			):
				return false
		if source is CollisionShape3D:
			var shape: CollisionShape3D = found as CollisionShape3D
			if (
				shape.disabled != source.disabled
				or shape.shape == null
				or shape.shape.get_class() != source.shape.get_class()
				or (
					shape.shape.get_debug_mesh().get_faces()
					!= source.shape.get_debug_mesh().get_faces()
				)
			):
				return false
		if source is Label3D:
			var label: Label3D = found as Label3D
			if (
				label.text != source.text
				or label.font_size != source.font_size
				or label.pixel_size != source.pixel_size
				or label.modulate != source.modulate
			):
				return false
		if not _members_match(source, found):
			return false
	return true


func _factory_controls(reference: Node3D, model: Node3D) -> void:
	var first: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var original_pose: Transform3D = first.transform
	first.position.x += 0.0125
	_check(not _members_match(reference, model), "source check rejects actual displaced mesh")
	first.transform = original_pose
	var original_mesh: Mesh = first.mesh
	var tiny: BoxMesh = BoxMesh.new()
	tiny.size = Vector3.ONE * 0.001
	first.mesh = tiny
	_check(not _members_match(reference, model), "source check rejects substituted geometry")
	first.mesh = original_mesh
	first.visible = false
	_check(not _members_match(reference, model), "source check rejects hiding an opaque blocker")
	first.visible = true
	_check(_members_match(reference, model), "bounded controls restore exact physical factory")


func _lower(stand: Node3D, site: String) -> void:
	_check(
		stand.transform.is_equal_approx(_base_pose(site)),
		"independent positive-handed baseline pose"
	)
	_check(stand.get_meta("represented_seats") == 50, "each lower has fifty represented seats")
	var guard: MeshInstance3D = stand.get_node("Visual/FrontGuard")
	var body: StaticBody3D = stand.get_node("Collision/FrontGuard")
	var shape: CollisionShape3D = body.get_child(0)
	_check(
		(
			guard.position == Vector3(-0.35, 3.45, 0.06)
			and (guard.mesh as BoxMesh).size == Vector3(5.3, 0.9, 0.12)
			and body.position == guard.position
			and (shape.shape as BoxShape3D).size == guard.mesh.size
		),
		"explicit v2 changes only guard height by0.10m and center by0.05m"
	)
	for row in range(10):
		var deck: MeshInstance3D = stand.get_node("Visual/SolidRow%d" % row)
		_check(
			is_zero_approx(deck.position.y - (deck.mesh as BoxMesh).size.y / 2),
			"every complete lower row has solid ground support"
		)
		for column in range(5):
			var index: int = row * 5 + column
			var person: Node3D = stand.get_node("Visual/CrowdAnchor%d" % index)
			var point: Vector3 = Vector3(-2.55 + column * 0.8, 3.46 + row / 3.0, row * 0.7 + 0.35)
			_check(
				(
					person.position.is_equal_approx(point)
					and person.get_meta("represented_audience", false)
				),
				"every represented person retains authored seat position"
			)
	_bounds(stand, AABB(Vector3(-3, 0, 0), Vector3(6, 7.4, 7)))


func _roof(property: StadiumPropertyGeometry, record: Dictionary, site: String) -> void:
	var row: Dictionary = _row(record, site)
	var roof: Node3D = property.objects[PREFIX + site]
	var host: Node3D = property.objects[PREFIX + site.trim_prefix("ROOF:")]
	_check(
		(
			roof != host
			and row.host == host.get_meta("candidate_instance")
			and row.instance != row.host
			and roof.transform == host.transform
		),
		"separate roof copy has identical pose and exact owned lower host"
	)
	_check(
		roof.get_meta("candidate_mount") == "BASE-LOWER-ROOF-v1",
		"actual canopy uses the lower-only mount"
	)
	for side: int in [-1, 1]:
		var column: MeshInstance3D = roof.get_node("Visual/RearColumn%d" % side)
		var beam: MeshInstance3D = roof.get_node("Visual/RoofBeam%d" % side)
		_check(
			(
				is_equal_approx(
					column.position.y - (column.mesh as BoxMesh).size.y / 2,
					6.0 if side == -1 else 5.7
				)
				and is_equal_approx(beam.position.y - (beam.mesh as BoxMesh).size.y / 2, 8.4)
			),
			"left post keeps deck support; right post extends to stair support; roof top is fixed"
		)
	_bounds(roof, AABB(Vector3(-3.25, 5.7, 0), Vector3(6.5, 2.94, 7)))
	_proof.roof_support(host, roof)
	_proof.host_controls(property, site)
	_check(
		roof.find_children("CrowdAnchor*", "Node3D", true, false).is_empty(),
		"purchased roof grants no extra represented crowd"
	)


func _bounds(root: Node3D, envelope: AABB) -> void:
	var inverse: Transform3D = root.global_transform.affine_inverse()
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[
				Mesh.ARRAY_VERTEX
			]
			for point: Vector3 in vertices:
				_check(
					envelope.grow(0.0001).has_point(inverse * mesh.global_transform * point),
					"every real head mesh support and roof vertex stays in its complete envelope"
				)
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		for point: Vector3 in shape.shape.get_debug_mesh().get_faces():
			_check(
				envelope.grow(0.0001).has_point(inverse * shape.global_transform * point),
				"every real collider vertex stays in the complete host envelope"
			)


func _spectator_clearance(stands: Array[Node3D], net: Node3D) -> void:
	var total: int = 0
	var blocked: int = 0
	var first_rows: int = 0
	for stand: Node3D in stands:
		var site: String = stand.get_meta("candidate_site")
		var originals: Array[Transform3D] = []
		for index in range(50):
			originals.append(stand.get_node("Visual/CrowdAnchor%d" % index).transform)
		for sway: float in [-0.04, 0.0, 0.04]:
			for index in range(50):
				var person: Node3D = stand.get_node("Visual/CrowdAnchor%d" % index)
				person.transform = originals[index]
				person.position.y += sway
				var eye: Vector3 = person.global_position + Vector3.UP * 0.57
				var target: Vector3 = Vector3(0, 1, 8)
				var obstruction: Dictionary = _opaque_hit(eye, target, net)
				total += 1
				if not obstruction.is_empty():
					blocked += 1
					first_rows += int(index < 5)
					print(
						"LONG_YARD_SPECTATOR_BLOCKED site=",
						site,
						" anchor=",
						person.name,
						" sway=",
						sway,
						" eye=",
						eye,
						" target=",
						target,
						" hit=",
						obstruction.position,
						" collider=",
						obstruction.collider.get_path()
					)
				# Never exempt the guard, canopy, posts, beams or another opaque member.
				_check(
					obstruction.is_empty(),
					(
						"actual spectator-to-pitch clearance "
						+ site
						+ ":"
						+ str(index)
						+ " sway="
						+ str(sway)
					)
				)
			_bounds(stand, AABB(Vector3(-3, 0, 0), Vector3(6, 7.4, 7)))
			_check(
				StadiumLongYardLowerRoofSites.valid_lower(stand, site),
				"bounded0.04m real crowd sway remains authenticated without moving the host"
			)
		for index in range(50):
			var person: Node3D = stand.get_node("Visual/CrowdAnchor%d" % index)
			person.transform = originals[index]
			_check(
				person.transform == originals[index],
				"every tested crowd transform restores exactly"
			)
	_check(total == 600, "all200 people tested at rest and both0.04m vertical sway extrema")
	print(
		"LONG_YARD_SIGHTLINE_SUMMARY samples=",
		total,
		" blocked=",
		blocked,
		" blocked_first_row=",
		first_rows,
		" qualified=",
		blocked == 0
	)
	for side: int in [-1, 1]:
		_check(
			_opaque_hit(Vector3(side * 1.2, 1.6, -1), Vector3(0, 1.1, 9), net).is_empty(),
			"both protected batting-side pitch corridors remain clear"
		)


func _opaque_hit(from: Vector3, to: Vector3, net: Node3D) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	var excluded: Array[RID] = []
	for index in range(StadiumReceiverNetModels.PANELS.size() + 1):
		query.exclude = excluded
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or not _verified_panel(hit, net):
			return hit
		var body: StaticBody3D = hit.collider
		if body.get_rid() in excluded:
			return hit
		excluded.append(body.get_rid())
	return {"position": from, "collider": net}


func _verified_panel(hit: Dictionary, net: Node3D) -> bool:
	var body: StaticBody3D = hit.collider as StaticBody3D
	if body == null or hit.shape != 0:
		return false
	var id: String = body.get_meta("surface_id", "")
	if (
		id not in StadiumReceiverNetModels.PANELS
		or body != net.get_node("Collision/" + id)
		or body.get_child_count() != 1
	):
		return false
	var shape: CollisionShape3D = body.get_child(0)
	var mesh: MeshInstance3D = net.get_node("Visual/" + id)
	return (
		shape.shape is BoxShape3D
		and is_equal_approx(shape.shape.size.z, 0.006)
		and mesh.has_meta("rest_vertices")
		and mesh.has_meta("panel_width")
		and is_equal_approx(shape.shape.size.x, mesh.get_meta("panel_width"))
		and body.get_meta("surface_role", "") == "RECEIVER_CONTAINMENT_FOUL"
	)


func _ray_controls(net: Node3D) -> void:
	var from: Vector3 = Vector3(0, 3, -6)
	var to: Vector3 = Vector3(0, 3, 0)
	_check(_opaque_hit(from, to, net).is_empty(), "authentic strand net transmits a clear ray")
	var blocker: Node3D = Node3D.new()
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		blocker.add_child(child)
	blocker.set_meta("stadium_item", "ST-073")
	add_child(blocker)
	StadiumSeatingModels._box(
		blocker, "ST073_CENTER_NET", Vector3(0, 3, -3.5), Vector3(0.5, 0.5, 0.5), Color.RED
	)
	var opaque: StaticBody3D = blocker.get_node("Collision/ST073_CENTER_NET")
	opaque.set_meta("surface_role", "RECEIVER_CONTAINMENT_FOUL")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		not _opaque_hit(from, to, net).is_empty(),
		"spoofed transparent labels cannot hide an opaque blocker behind the real net"
	)
	blocker.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(_opaque_hit(from, to, net).is_empty(), "removing the blocker restores actual clear ray")


func _rail(distance: float, left: bool) -> Vector2:
	var point: Vector2 = Vector2(8, -6) + Vector2(16, 29.4).normalized() * distance
	return Vector2(-point.x if left else point.x, point.y)


func _base_pose(site: String) -> Transform3D:
	var left: bool = site.begins_with("BASE-L")
	var along: Vector2 = Vector2(16, 29.4).normalized()
	var point: Vector2 = _rail(15 if site.ends_with("1") else 21, false)
	point += Vector2(along.y, -along.x) * 3.5
	var x: Vector3 = Vector3(-along.x, 0, along.y) if left else Vector3(-along.x, 0, -along.y)
	return Transform3D(
		Basis(x, Vector3.UP, x.cross(Vector3.UP)),
		Vector3(-point.x if left else point.x, 0, point.y)
	)


func _row(record: Dictionary, site: String) -> Dictionary:
	for row: Dictionary in record.items:
		if row.site == site:
			return row
	_check(false, "required exact site exists " + site)
	return {}


func _components(pose: Transform3D) -> Array[float]:
	var result: Array[float] = []
	for vector: Vector3 in [pose.basis.x, pose.basis.y, pose.basis.z, pose.origin]:
		result.append_array([vector.x, vector.y, vector.z])
	return result


func _setup_view() -> void:
	StadiumWallRenderQuality.attach(self)
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("263b37")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b6ccbe")
	world.environment.ambient_light_energy = 0.7
	add_child(world)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	add_child(light)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true


func _capture(label: String, eye: Vector3, target: Vector3, size_value: float) -> void:
	if StadiumAssetCapture.directory().is_empty() or DisplayServer.get_name() == "headless":
		return
	_camera.position = eye
	_camera.look_at(target)
	_camera.size = size_value
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(extent), "native window resize acknowledged")
		_check(
			await Evidence.capture(self, _native, StadiumAssetCapture.directory(), label),
			"Long Yard-only source-bound native capture at both content sizes"
		)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

extends Node3D
## Canonical source-bound LONG-YARD-v2 records, negative guards, and atomic authoring IO.


class AlternateField:
	extends FieldDefinition

	func is_fair_point(_point: Vector3) -> bool:
		return false


class FailedTemplate:
	extends StadiumPropertyGeometry

	func build(property_tier: String, layout: Dictionary, stock: StadiumStock) -> bool:
		super.build(property_tier, layout, stock)
		return false


class TransformedTemplate:
	extends StadiumPropertyGeometry

	func build(property_tier: String, layout: Dictionary, stock: StadiumStock) -> bool:
		if not super.build(property_tier, layout, stock):
			return false
		position.x = 0.25
		return true


var _failures: int = 0


func _ready() -> void:
	var property: StadiumPropertyGeometry = StadiumLongYardStudy.build(self)
	_check(property != null, "complete LONG-YARD-v2 builds for fixture capture")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue").duplicate(true)
	property.queue_free()
	await get_tree().process_frame
	var fixture: Dictionary = StadiumLongYardFixture.capture(record)
	_check(StadiumLongYardFixture.valid(fixture), "canonical complete fixture accepted")
	if fixture.is_empty():
		get_tree().quit(1)
		return
	_independent_identity(fixture)
	_source_packet(fixture)
	_cross_profile(fixture)
	_typed_envelope(fixture)
	_check(
		ClubCareer.same(
			fixture, StadiumLongYardFixture.decode(StadiumLongYardFixture.encode(fixture))
		),
		"full precision canonical JSON roundtrip"
	)
	record.items[0].site = "caller-mutation"
	_check(
		(
			StadiumLongYardFixture.valid(fixture)
			and fixture.venue.items[0].site != record.items[0].site
		),
		"capture owns a deep copy"
	)
	_check(
		(
			StadiumLongYardFixture.decode("{").is_empty()
			and StadiumLongYardFixture.decode(" ".repeat(1048577)).is_empty()
		),
		"malformed and oversized input fail closed"
	)
	_check(
		not StadiumLayoutSnapshot.valid(fixture) and not StadiumClubFixtureStudy.valid(fixture),
		"Long Yard authoring has no production or AC identity"
	)
	var path: String = "user://long-yard-fixture-%d.json" % OS.get_process_id()
	_check(
		StadiumLongYardFixture.save(path, fixture) and StadiumLongYardFixture.save(path, fixture),
		"canonical saves and replaces atomically"
	)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(
		ClubCareer.same(StadiumLongYardFixture.load_file(path), fixture),
		"saved complete fixture reloads exactly"
	)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_long_yard_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var old: Node = lab.get_node("StarterFieldGeometry/BackWall")
	await _stage_failures(lab)
	_install_guards(lab)
	for edit in range(85):
		var bad: Dictionary = fixture.duplicate(true)
		_tamper(bad, edit)
		_check(not StadiumLongYardFixture.valid(bad), "tamper rejects " + str(edit))
		_check(
			(
				not StadiumLongYardFixture.save(path, bad)
				and FileAccess.get_file_as_string(path) == bytes
			),
			"failed write preserves original"
		)
		_check(
			(
				not StadiumLongYardLab.install_frozen(lab, bad)
				and old == lab.get_node_or_null("StarterFieldGeometry/BackWall")
				and not lab.has_meta("stadium_property")
			),
			"failed install preserves old geometry"
		)
		bad.sha256 = JSON.stringify(bad.venue, "", true, true).sha256_text()
		_check(
			(
				not StadiumLongYardFixture.valid(bad)
				and not StadiumLongYardFixture.save(path, bad)
				and FileAccess.get_file_as_string(path) == bytes
				and not StadiumLongYardLab.install_frozen(lab, bad)
			),
			"manually rehashed noncanonical envelope still rejects " + str(edit)
		)
		_check(
			(
				old == lab.get_node_or_null("StarterFieldGeometry/BackWall")
				and not lab.has_meta("stadium_property")
			),
			"rehash rejection preserves exact original field"
		)
		if edit not in [0, 1]:
			_check(
				StadiumLongYardFixture.capture(bad.venue).is_empty(),
				"recomputed checksum cannot bless noncanonical record " + str(edit)
			)
	var source_field: FieldDefinition = load("res://src/content/fields/npc_venue_field.tres")
	var original_safe: float = source_field.safe_hit_z_m
	source_field.safe_hit_z_m += 0.5
	_check(
		not StadiumLongYardFixture.valid(fixture),
		"actual in-memory field mutation invalidates an earlier fixture even with unchanged files"
	)
	source_field.safe_hit_z_m = original_safe
	_check(
		StadiumLongYardFixture.valid(fixture),
		"restoring the exact field restores original source-bound fixture validity"
	)

	_check(
		not StadiumLongYardLab.install_frozen(lab, {}), "empty frozen means failure, never defaults"
	)
	remove_child(lab)
	var orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check(
		(
			not StadiumLongYardLab.install(lab)
			and Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == orphans
		),
		"detached host fails without allocating orphan assembly"
	)
	add_child(lab)
	_check(StadiumLongYardLab.install_frozen(lab, fixture), "exact frozen candidate installs")
	_check(
		ClubCareer.same(
			fixture.venue, lab.get_meta("stadium_property").get_meta("candidate_venue")
		),
		"installed identity stays exact"
	)
	_check(PhysicalMatchReport.capture(lab).is_empty(), "no reward report authority")
	DirAccess.remove_absolute(path)
	lab.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro LONG-YARD fixture passed: source identity, atomic IO, fail-closed install."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _stage_failures(lab: PitchBatLab) -> void:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var previous: Array[Node] = host.get_children()
	var router: Callable = lab._pitch_actor.receiver_router
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	var obstacles: Array[Dictionary] = lab._primary_fielder.stadium_obstacles.duplicate(true)
	var actual_field: FieldDefinition = lab._field_definition
	for candidate: StadiumPropertyGeometry in [FailedTemplate.new(), TransformedTemplate.new()]:
		_check(
			StadiumLongYardStudy.build(host, candidate) == null,
			"partially constructed template failure aborts the whole assembly"
		)
		_check(
			(
				host.get_children() == previous
				and not lab.has_meta("stadium_property")
				and lab._pitch_actor.receiver_router == router
			),
			"mid-stage failure retains every original node and receiver adapter"
		)
		await get_tree().process_frame
		_check(not is_instance_valid(candidate), "failed staging releases its temporary property")
	var staged: StadiumLongYardProperty = StadiumLongYardProperty.new()
	_check(
		StadiumLongYardStudy.build(host, staged) == staged,
		"receiver rejection probe builds the real complete staged assembly"
	)
	if staged.objects.is_empty():
		_check(false, "failed build stops dependent receiver probe")
		return
	var net: Node3D = staged.objects["finals-candidate:LONG-YARD:v2:RECEIVER-CATCH"]
	var observer: Callable = lab._ball_play_resolver.segment_observer
	net.position.x += 0.01
	_check(
		not staged.configure_candidate(lab),
		"actual displaced ST073 rejects receiver configuration despite unchanged metadata"
	)
	for original: Node in previous:
		_check(
			is_instance_valid(original) and original.get_parent() == host,
			"receiver configuration failure retains each original geometry object"
		)
	_check(
		(
			lab._pitch_actor.receiver_router == router
			and lab._ball_play_resolver.segment_observer == observer
			and lab._primary_fielder.stadium_boundary_clip == clip
			and lab._primary_fielder.stadium_obstacles == obstacles
			and lab._field_definition == actual_field
			and not lab.has_meta("stadium_property")
		),
		"failed staged pair never changes original receiver or physical observer callbacks"
	)
	host.remove_child(staged)
	staged.queue_free()
	await get_tree().process_frame
	_check(
		not is_instance_valid(staged) and host.get_children() == previous,
		"failed staged receiver assembly fully releases without removing prior geometry"
	)

	var transformed: Node3D = Node3D.new()
	transformed.position.x = 1
	add_child(transformed)
	var child: Node3D = Node3D.new()
	transformed.add_child(child)
	_check(
		StadiumLongYardStudy.build(child) == null and child.get_child_count() == 0,
		"nonidentity ancestor fails before allocating any candidate"
	)
	transformed.queue_free()


func _row_for_site(venue: Dictionary, site: String) -> Dictionary:
	for row: Dictionary in venue.items:
		if row.site == site:
			return row
	_check(false, "required tamper target exists: " + site)
	return {}


func _source_packet(fixture: Dictionary) -> void:
	var packet: Dictionary = fixture.venue.qualification_sources
	_check(
		(
			packet.scope == "staged-src-authored-resources-plus-project"
			and not packet.files.has("tools/verify.py")
		),
		"external verifier identity belongs only to root run evidence, never a guessed res hash"
	)
	var expected: Array[String] = []
	_source_paths("res://src", expected)
	expected.append("project.godot")
	_check(
		packet.files.size() == expected.size(),
		"source packet contains exactly staged authored src resources plus project"
	)
	for path: String in expected:
		_check(
			(
				packet.files.has(path)
				and packet.files[path] == FileAccess.get_sha256("res://" + path)
				and packet.files[path].length() == 64
			),
			"source packet binds actual complete current bytes: " + path
		)
	_check(
		packet.sha256 == JSON.stringify(packet.files, "", true, true).sha256_text(),
		"complete execution-source manifest digest is independently recomputed"
	)
	_check(
		packet.execution_evidence == "pending-root-engine-native-and-device-evidence",
		"a source manifest never fabricates engine native target-device or night evidence"
	)
	for kind: String in ["assembly", "fixture", "sweep", "lab", "tracking", "game"]:
		_check(
			(
				packet.files.has("src/tests/stadium_long_yard_%s_test.gd" % kind)
				and packet.files.has("src/tests/stadium_long_yard_%s_test.tscn" % kind)
			),
			"all six complete new test implementations and execution scenes are source-bound"
		)


func _source_paths(path: String, result: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(path)
	_check(directory != null, "source inventory directory can be independently read")
	if directory == null:
		return
	for file: String in directory.get_files():
		if file.get_extension() not in ["uid", "import"]:
			result.append(path.path_join(file).trim_prefix("res://"))
	for child: String in directory.get_directories():
		_source_paths(path.path_join(child), result)


func _install_guards(lab: PitchBatLab) -> void:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var previous: Array[Node] = host.get_children()
	var camera: MatchCameraDirector = lab._camera_director
	var router: Callable = lab._pitch_actor.receiver_router
	var observer: Callable = lab._ball_play_resolver.segment_observer
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	var obstacles: Array[Dictionary] = lab._primary_fielder.stadium_obstacles.duplicate(true)
	var actual_field: FieldDefinition = lab._field_definition
	var cadence: AtBatCadenceController.State = lab._at_bat_cadence.state
	_check(not StadiumLongYardLab.install(null), "null host fails closed")
	for invalid_flag: Variant in [false, [], {}, "true", 1]:
		lab.set_meta("stadium_long_yard_lab_only", invalid_flag)
		_check(
			not StadiumLongYardLab.install(lab) and host.get_children() == previous,
			"only the exact boolean true grants isolated authoring opt-in"
		)
	lab.set_meta("stadium_long_yard_lab_only", true)
	lab._automation = MatchAutomation.new()
	_check(
		not StadiumLongYardLab.install(lab), "preexisting automation cannot authorize a candidate"
	)
	lab._automation = null
	lab._field_id = &"field.not-long-yard"
	_check(not StadiumLongYardLab.install(lab), "wrong field identity cannot install")
	lab._field_id = PitchBatLab.FIELD_ID
	lab._field_definition = actual_field.duplicate(true)
	lab._field_definition.safe_hit_z_m += 0.25
	var changed_field: FieldDefinition = lab._field_definition
	_check(
		(
			not StadiumLongYardLab.install(lab)
			and lab._field_definition == changed_field
			and host.get_children() == previous
		),
		"mismatched actual gameplay resource rejects without replacing field or geometry"
	)
	lab._field_definition = AlternateField.new()
	lab._field_definition.id = actual_field.id
	for key: String in StadiumLongYardStudy.FIELD_KEYS:
		lab._field_definition.set(key, actual_field.get(key))
	var alternate: FieldDefinition = lab._field_definition
	_check(
		ClubCareer.same(
			StadiumLongYardStudy.field_snapshot(alternate),
			StadiumLongYardStudy.field_snapshot(actual_field)
		),
		"alternate script control keeps exact field scalar values"
	)
	_check(
		(
			not StadiumLongYardLab.install(lab)
			and lab._field_definition == alternate
			and host.get_children() == previous
		),
		"changed gameplay behavior script cannot impersonate canonical field semantics"
	)
	lab._field_definition = actual_field
	var protected_observer: Callable = func(
		_resolver: BallPlayResolver, _from: Vector3, _to: Vector3
	) -> void:
		_check(false, "rejected observer must never be invoked")
	lab._ball_play_resolver.segment_observer = protected_observer
	_check(
		(
			not StadiumLongYardLab.install(lab)
			and lab._ball_play_resolver.segment_observer == protected_observer
			and host.get_children() == previous
		),
		"preexisting observer remains exact and blocks installation"
	)
	lab._ball_play_resolver.segment_observer = observer
	var protected_clip: Callable = func(_from: Vector3, _to: Vector3) -> Vector3:
		_check(false, "rejected defender clip must never be invoked")
		return _from
	lab._primary_fielder.stadium_boundary_clip = protected_clip
	_check(
		(
			not StadiumLongYardLab.install(lab)
			and lab._primary_fielder.stadium_boundary_clip == protected_clip
			and host.get_children() == previous
		),
		"preexisting defender callback remains exact and blocks installation"
	)
	lab._primary_fielder.stadium_boundary_clip = clip
	lab._primary_fielder.stadium_obstacles = [{"center": Vector3(2, 0, 3), "radius": 0.75}]
	var protected_obstacles: Array[Dictionary] = lab._primary_fielder.stadium_obstacles.duplicate(
		true
	)
	_check(
		(
			not StadiumLongYardLab.install(lab)
			and lab._primary_fielder.stadium_obstacles == protected_obstacles
			and host.get_children() == previous
		),
		"existing route obstacles retain exact values and block installation"
	)
	lab._primary_fielder.stadium_obstacles = obstacles
	lab._pitch_actor.running = true
	_check(not StadiumLongYardLab.install(lab), "running physical pitch rejects candidate swap")
	lab._pitch_actor.running = false
	lab._release_controller.active = true
	_check(not StadiumLongYardLab.install(lab), "active release rejects candidate swap")
	lab._release_controller.active = false
	lab._at_bat_cadence.state = AtBatCadenceController.State.DELIVERY
	_check(not StadiumLongYardLab.install(lab), "delivery cadence rejects candidate swap")
	lab._at_bat_cadence.state = cadence
	lab._batted_ball = BattedBallBody.new()
	_check(not StadiumLongYardLab.install(lab), "existing game ball rejects candidate swap")
	lab._batted_ball.free()
	lab._batted_ball = null
	lab._pitch_actor.receiver_router = _unexpected_router
	_check(not StadiumLongYardLab.install(lab), "existing receiver callback cannot be overwritten")
	lab._pitch_actor.receiver_router = router
	host.position.x = 0.25
	_check(not StadiumLongYardLab.install(lab), "translated geometry host rejects installation")
	host.position.x = 0
	_check(
		(
			host.get_children() == previous
			and lab._camera_director == camera
			and lab._pitch_actor.receiver_router == router
			and lab._ball_play_resolver.segment_observer == observer
			and lab._primary_fielder.stadium_boundary_clip == clip
			and lab._primary_fielder.stadium_obstacles == obstacles
			and lab._field_definition == actual_field
			and not lab.has_meta("stadium_property")
		),
		"every rejected lifecycle start preserves all prior geometry and adapters"
	)


func _unexpected_router(_from: Vector3, _to: Vector3) -> Dictionary:
	_check(false, "a rejected installation must never invoke the existing receiver callback")
	return {}


func _typed_envelope(fixture: Dictionary) -> void:
	_check(StadiumLongYardFixture.MAX_BYTES == 1048576, "exact one MiB bounded fixture contract")
	var encoded: String = StadiumLongYardFixture.encode(fixture)
	_check(
		encoded.to_utf8_buffer().size() > 0 and encoded.to_utf8_buffer().size() <= 1048576,
		"entire expanded fixture fits strict read bound"
	)
	for key: String in ["kind", "version", "venue", "sha256"]:
		for malformed: Variant in [null, [], {}, true, "", -1]:
			var bad: Dictionary = fixture.duplicate(true)
			bad[key] = malformed
			_check(
				(
					not StadiumLongYardFixture.valid(bad)
					and StadiumLongYardFixture.decode(JSON.stringify(bad)).is_empty()
				),
				"mixed malformed envelope rejects without Variant comparison failure"
			)
	var extra: Dictionary = fixture.duplicate(true)
	extra["production_eligible"] = true
	_check(
		not StadiumLongYardFixture.valid(extra), "unexpected envelope keys cannot grant authority"
	)
	_check(
		(
			StadiumLongYardFixture.decode("[]").is_empty()
			and StadiumLongYardFixture.decode("null").is_empty()
		),
		"nonobject JSON rejects without fallback"
	)


func _cross_profile(fixture: Dictionary) -> void:
	_check(
		(
			not StadiumGrandIFixtureStudy.valid(fixture)
			and not StadiumGrandIIFixtureStudy.valid(fixture)
			and not StadiumGrandIIIFixtureStudy.valid(fixture)
			and not StadiumClubOffsetFixtureStudy.valid(fixture)
		),
		"Long Yard never inherits Grand or Club authoring authority"
	)
	for other: Dictionary in [
		StadiumGrandIFixtureStudy.capture(StadiumGrandIVenueStudy.canonical()),
		StadiumGrandIIFixtureStudy.capture(StadiumGrandIIVenueStudy.canonical())
	]:
		_check(
			not other.is_empty() and not StadiumLongYardFixture.valid(other),
			"foreign frozen authoring profiles cannot install Long Yard"
		)


func _independent_identity(fixture: Dictionary) -> void:
	_check(
		(
			fixture.kind == "UNQUALIFIED_LONG_YARD_V2_AUTHORING_FIXTURE"
			and fixture.version == 1
			and fixture.venue.id == "LONG-YARD"
			and fixture.venue.version == 2
			and fixture.venue.property == "club"
			and fixture.venue.owner == "finals-venue:long-yard:v2"
		),
		"independent exact v2 venue and v1 transport envelope"
	)
	_check(
		(
			fixture.venue.items.size() == 67
			and fixture.venue.live_units == 0
			and fixture.venue.crowd.total == 200
			and fixture.venue.environment.target_slots == ["16:10"]
			and fixture.venue.environment.target_weather == ["clear"]
		),
		"fixed daylight source contract"
	)
	for site: String in ["ROOF:BASE-L2", "ROOF:BASE-R2"]:
		var row: Dictionary = _row_for_site(fixture.venue, site)
		_check(
			(
				row.item == "ST-053"
				and row.instance == "finals-candidate:LONG-YARD:v2:" + site
				and row.host == "finals-candidate:LONG-YARD:v2:" + site.trim_prefix("ROOF:")
				and row.mount == "BASE-LOWER-ROOF-v1"
				and row.interface == "ST029-guard-v2_LOWER-CANOPY-v2"
				and row.model_version == 2
				and row.model_variant == "BASE-LOWER-CANOPY-GUARD-v2"
			),
			"independent roof copy host mount interface and revision"
		)
		_check(
			row.transform == _row_for_site(fixture.venue, site.trim_prefix("ROOF:")).transform,
			"fixture keeps every canopy at its exact lower-host pose"
		)
	_check(
		fixture.sha256 == JSON.stringify(fixture.venue, "", true, true).sha256_text(),
		"venue digest independently recomputed from the full source-bound record"
	)


func _tamper(bad: Dictionary, edit: int) -> void:
	match edit:
		0:
			bad.kind = "PRODUCTION"
		1:
			bad.version = 2
		2:
			bad.venue.id = "AM-01"
		3:
			bad.venue.property = "mogul"
		4:
			bad.venue.items.pop_back()
		5:
			bad.venue.items[1].instance = bad.venue.items[0].instance
		6:
			bad.venue.items[1].site = bad.venue.items[0].site
		7:
			bad.venue.items[0].transform[9] += 0.125
		8:
			bad.venue.items[0].transform[0] = NAN
		9:
			bad.venue.items[0].item = "ST-082"
		10:
			bad.venue.environment.night_eligible = true
		11:
			bad.venue.environment.certificates = ["fabricated-daylight-pass"]
		12:
			var changed_source: String = "src/presentation/stadium/stadium_baseline_sightline_models.gd"
			bad.venue.qualification_sources.files[changed_source] = "f".repeat(64)
		13:
			bad.venue.items[0].host = "untrusted-owner"
		14:
			bad.venue.lighting.dormant = false
		15:
			bad.venue.field.safe_hit_z_m += 0.5
		16:
			bad.venue.field.deep_air_z_m += 0.5
		17:
			bad.venue.field.fair_half_angle_degrees += 1.0
		18:
			bad.venue.field.middle_anchor_z_m += 0.5
		19:
			bad.venue.qualification_sources.files["src/content/fields/npc_venue_field.tres"] = (
				"f".repeat(64)
			)
		20:
			bad.venue.qualification_sources.files["project.godot"] = "f".repeat(64)
		21:
			bad.venue.qualification_sources.files.erase("src/labs/pitch_bat_lab/pitch_bat_lab.gd")
		22:
			bad.venue.qualification_sources.files["injected-resource.gd"] = "f".repeat(64)
		23:
			bad.venue.qualification_sources.sha256 = "f".repeat(64)
		24:
			bad.venue.endowment.copy_value += 1
		25:
			bad.venue.endowment.land_value = 6400
		26:
			bad.venue.environment.target_slots = ["13:10", "16:10"]
		27:
			bad.venue.environment.target_weather = ["rain"]
		28:
			bad.venue.structural_layers.roofs = 0
		29:
			bad.venue.surface.grass = "striped"
		30:
			bad.venue.crowd.total = 208
		31:
			bad.venue.lighting.active_lights = 24
		32:
			_row_for_site(bad.venue, "BASE-L1").model_version = 1
		33:
			_row_for_site(bad.venue, "BASE-L1").model_variant = "BASE-LOWER-v1"
		34:
			bad.venue.qualification_sources.execution_evidence = "fabricated-pass"
		35:
			_row_for_site(bad.venue, "SCORE-SMALL").transform[9] += 1
		36:
			bad.venue.boundary = StadiumDugoutBoundary.candidate("straight").signature()
		37:
			bad.venue.lighting.towers = [{"site": "MLIGHT-HL"}]
		38:
			bad.venue.render_profile.id = "unqualified-AA-profile"
		39:
			bad.venue.erase("render_profile")
		40:
			bad.venue.render_profile.native_minimum_msaa_3d = "2x"
		41:
			bad.venue.render_profile = true
		42:
			bad.venue.render_profile.helper_sha256 = "f".repeat(64)
		43:
			bad.venue.render_profile.helper += ".foreign"
		44:
			bad.venue.erase("camera_profile")
		45:
			bad.venue.camera_profile.id = "AM01-BATTING-BEHIND-RECEIVER-v1"
		46:
			bad.venue.camera_profile.right_entry[2] = -3.38
		47:
			bad.venue.camera_profile.left_entry[2] = -3.38
		48:
			bad.venue.camera_profile.focus[1] += 0.25
		49:
			bad.venue.camera_profile.optics = "unqualified-optics"
		50:
			bad.venue.camera_profile.live_motion = "contact-cut"
		51:
			bad.venue.camera_profile.acquisition = "allow-live"
		52:
			bad.venue.camera_profile.predecessor = "foreign-pass"
		53:
			bad.venue.camera_profile = true
		54:
			_row_for_site(bad.venue, "ROOF:BASE-L2").host = "finals-venue:long-yard:v2"
		55:
			_row_for_site(bad.venue, "ROOF:BASE-L2").host = "finals-candidate:LONG-YARD:v2:BASE-R2"
		56:
			_row_for_site(bad.venue, "ROOF:BASE-L2").host = "finals-candidate:LONG-YARD:v2:BASE-L1"
		57:
			_row_for_site(bad.venue, "ROOF:BASE-R2").mount = "BASE-UPPER-ROOF-v1"
		58:
			_row_for_site(bad.venue, "ROOF:BASE-L2").transform[10] += 0.3
		59:
			_row_for_site(bad.venue, "ROOF:BASE-R2").model_variant = "BASE-LOWER-ROOF-v1"
		60:
			_row_for_site(bad.venue, "ROOF:BASE-R2").model_version = 1
		61:
			_row_for_site(bad.venue, "ROOF:BASE-L2").site = "ROOF:BASE-L1"
		62:
			_row_for_site(bad.venue, "ROOF:BASE-R2").interface = "ST029-upper-service-v1"
		63:
			bad.venue.items.append(_row_for_site(bad.venue, "ROOF:BASE-L2").duplicate(true))
		64:
			_row_for_site(bad.venue, "BASE-L2").mount = "BASE-LOWER-ROOF-v1"
		65:
			_row_for_site(bad.venue, "BASE-R2").host = "finals-candidate:LONG-YARD:v2:BASE-L2"
		66:
			bad.venue.graph.segments[8].a[1] = 23.4
		67:
			bad.venue.graph.segments[3].role = "SIDE_RETURN_LIVE"
		68:
			bad.venue.graph.segments[3].priority = 999
		69:
			bad.venue.graph.segments[3].height = 1.2
		70:
			bad.venue.graph.poles[0].position[2] = 23.4
		71:
			bad.venue.graph.defender_radius = 0.0
		72:
			bad.venue.graph.prism_margin = 0.05
		73:
			bad.venue.graph.ball_radius = 0.073
		74:
			bad.venue.live_units = 1
		75:
			bad.venue.empty_sites.erase("BOWL-01")
		76:
			bad.venue.blueprint_entitlements.append("ST-038")
		77:
			bad.venue.receiver.catch = "npc-candidate:AM-01:deeper-center-v1:RECEIVER-CATCH"
		78:
			bad.venue.source_contract = "AM-01-qualification-transfer"
		79:
			bad.venue.version = 1
		80:
			bad.venue.owner = "finals-venue:long-yard:v1"
		81:
			bad.venue.structural_layers.roof_interface = "BASE-UPPER-ROOF-v1"
		82:
			bad.venue.qualification_sources.files.erase(
				"src/presentation/stadium/stadium_long_yard_lower_roof_models.gd"
			)
		83:
			_row_for_site(bad.venue, "ST-065-01").span = "full"
		84:
			_row_for_site(bad.venue, "ST-023-09").transform[0] *= -1.0

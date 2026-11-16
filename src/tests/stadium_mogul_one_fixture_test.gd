extends Node3D
## Canonical source-bound AM-01 records, negative guards, and atomic authoring IO.


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
	var property: StadiumPropertyGeometry = StadiumMogulOneStudy.build(self)
	_check(property != null, "complete AM-01 builds for fixture capture")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue").duplicate(true)
	property.queue_free()
	await get_tree().process_frame
	var fixture: Dictionary = StadiumMogulOneFixture.capture(record)
	_check(StadiumMogulOneFixture.valid(fixture), "canonical complete fixture accepted")
	if fixture.is_empty():
		get_tree().quit(1)
		return
	_source_packet(fixture)
	_cross_profile(fixture)
	_typed_envelope(fixture)
	_check(
		ClubCareer.same(
			fixture, StadiumMogulOneFixture.decode(StadiumMogulOneFixture.encode(fixture))
		),
		"full precision canonical JSON roundtrip"
	)
	record.items[0].site = "caller-mutation"
	_check(
		(
			StadiumMogulOneFixture.valid(fixture)
			and fixture.venue.items[0].site != record.items[0].site
		),
		"capture owns a deep copy"
	)
	_check(
		(
			StadiumMogulOneFixture.decode("{").is_empty()
			and StadiumMogulOneFixture.decode(" ".repeat(1048577)).is_empty()
		),
		"malformed and oversized input fail closed"
	)
	_check(
		not StadiumLayoutSnapshot.valid(fixture) and not StadiumClubFixtureStudy.valid(fixture),
		"authoring has no production or AC identity"
	)
	var path: String = "user://mogul-one-fixture-%d.json" % OS.get_process_id()
	_check(
		StadiumMogulOneFixture.save(path, fixture) and StadiumMogulOneFixture.save(path, fixture),
		"canonical saves and replaces atomically"
	)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(
		ClubCareer.same(StadiumMogulOneFixture.load_file(path), fixture),
		"saved complete fixture reloads exactly"
	)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_mogul_one_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var old: Node = lab.get_node("StarterFieldGeometry/BackWall")
	await _stage_failures(lab)
	_install_guards(lab)
	for edit in range(54):
		var bad: Dictionary = fixture.duplicate(true)
		match edit:
			0:
				bad.kind = "PRODUCTION"
			1:
				bad.version = 999
			2:
				bad.venue.id = "AC-01"
			3:
				bad.venue.property = "club"
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
				bad.venue.environment.certificates = ["free-night"]
			12:
				var changed_source: String = "src/presentation/stadium/stadium_curved_lower_models.gd"
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
				bad.venue.qualification_sources.files.erase(
					"src/labs/pitch_bat_lab/pitch_bat_lab.gd"
				)
			22:
				bad.venue.qualification_sources.files["injected-resource.gd"] = "f".repeat(64)
			23:
				bad.venue.qualification_sources.sha256 = "f".repeat(64)
			24:
				bad.venue.endowment.copy_value += 1
			25:
				bad.venue.endowment.land_value = 4200
			26:
				bad.venue.environment.target_slots = ["19:10"]
			27:
				bad.venue.environment.target_weather = ["rain"]
			28:
				bad.venue.structural_layers.roofs = 1
			29:
				bad.venue.surface.grass = "striped"
			30:
				bad.venue.crowd.total = 308
			31:
				bad.venue.lighting.active_lights = 24
			32:
				_row_for_site(bad.venue, "BOWL-02").model_version = 999
			33:
				_row_for_site(bad.venue, "BASE-L1").model_variant = "BASE-LOWER-v1"
			34:
				bad.venue.qualification_sources.execution_evidence = "fabricated-pass"
			35:
				_row_for_site(bad.venue, "SCORE-SMALL").transform[9] += 1
			36:
				bad.venue.boundary = StadiumDugoutBoundary.candidate("straight").signature()
			37:
				bad.venue.lighting.towers[0].heads[0].direction[0] += 0.1
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
				bad.venue.camera_profile.id = "unqualified-entry"
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
				bad.venue.camera_profile.predecessor_failed_source = "f".repeat(64)
			53:
				bad.venue.camera_profile = true
		_check(not StadiumMogulOneFixture.valid(bad), "tamper rejects " + str(edit))
		_check(
			(
				not StadiumMogulOneFixture.save(path, bad)
				and FileAccess.get_file_as_string(path) == bytes
			),
			"failed write preserves original"
		)
		_check(
			(
				not StadiumMogulOneLab.install_frozen(lab, bad)
				and old == lab.get_node_or_null("StarterFieldGeometry/BackWall")
				and not lab.has_meta("stadium_property")
			),
			"failed install preserves old geometry"
		)
		bad.sha256 = JSON.stringify(bad.venue, "", true, true).sha256_text()
		_check(
			(
				not StadiumMogulOneFixture.valid(bad)
				and not StadiumMogulOneLab.install_frozen(lab, bad)
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
		if edit >= 2:
			_check(
				StadiumMogulOneFixture.capture(bad.venue).is_empty(),
				"recomputed checksum cannot bless noncanonical record " + str(edit)
			)
	var source_field: FieldDefinition = load("res://src/content/fields/npc_venue_field.tres")
	var original_safe: float = source_field.safe_hit_z_m
	source_field.safe_hit_z_m += 0.5
	_check(
		not StadiumMogulOneFixture.valid(fixture),
		"actual in-memory field mutation invalidates an earlier fixture even with unchanged files"
	)
	source_field.safe_hit_z_m = original_safe
	_check(
		StadiumMogulOneFixture.valid(fixture),
		"restoring the exact field restores original source-bound fixture validity"
	)

	_check(
		not StadiumMogulOneLab.install_frozen(lab, {}), "empty frozen means failure, never defaults"
	)
	remove_child(lab)
	var orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check(
		(
			not StadiumMogulOneLab.install(lab)
			and Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == orphans
		),
		"detached host fails without allocating orphan assembly"
	)
	add_child(lab)
	_check(StadiumMogulOneLab.install_frozen(lab, fixture), "exact frozen candidate installs")
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
			"Wiffaltro AM-01 fixture passed: canonical source identity, atomic IO, fail-closed install."
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
			StadiumMogulOneStudy.build(host, candidate) == null,
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
	var staged: StadiumMogulOneProperty = StadiumMogulOneProperty.new()
	_check(
		StadiumMogulOneStudy.build(host, staged) == staged,
		"receiver rejection probe builds the real complete staged assembly"
	)
	if staged.objects.is_empty():
		_check(false, "failed build stops dependent receiver probe")
		return
	var net: Node3D = staged.objects["npc-candidate:AM-01:deeper-center-v1:RECEIVER-CATCH"]
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
		StadiumMogulOneStudy.build(child) == null and child.get_child_count() == 0,
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
				packet.files.has("src/tests/stadium_mogul_one_%s_test.gd" % kind)
				and packet.files.has("src/tests/stadium_mogul_one_%s_test.tscn" % kind)
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
	_check(not StadiumMogulOneLab.install(null), "null host fails closed")
	for invalid_flag: Variant in [false, [], {}, "true", 1]:
		lab.set_meta("stadium_mogul_one_lab_only", invalid_flag)
		_check(
			not StadiumMogulOneLab.install(lab) and host.get_children() == previous,
			"only the exact boolean true grants isolated authoring opt-in"
		)
	lab.set_meta("stadium_mogul_one_lab_only", true)
	lab._automation = MatchAutomation.new()
	_check(
		not StadiumMogulOneLab.install(lab), "preexisting automation cannot authorize a candidate"
	)
	lab._automation = null
	lab._field_id = &"field.not-am01"
	_check(not StadiumMogulOneLab.install(lab), "wrong field identity cannot install")
	lab._field_id = PitchBatLab.FIELD_ID
	lab._field_definition = actual_field.duplicate(true)
	lab._field_definition.safe_hit_z_m += 0.25
	var changed_field: FieldDefinition = lab._field_definition
	_check(
		(
			not StadiumMogulOneLab.install(lab)
			and lab._field_definition == changed_field
			and host.get_children() == previous
		),
		"mismatched actual gameplay resource rejects without replacing field or geometry"
	)
	lab._field_definition = AlternateField.new()
	lab._field_definition.id = actual_field.id
	for key: String in StadiumMogulOneStudy.FIELD_KEYS:
		lab._field_definition.set(key, actual_field.get(key))
	var alternate: FieldDefinition = lab._field_definition
	_check(
		ClubCareer.same(
			StadiumMogulOneStudy.field_snapshot(alternate),
			StadiumMogulOneStudy.field_snapshot(actual_field)
		),
		"alternate script control keeps exact field scalar values"
	)
	_check(
		(
			not StadiumMogulOneLab.install(lab)
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
			not StadiumMogulOneLab.install(lab)
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
			not StadiumMogulOneLab.install(lab)
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
			not StadiumMogulOneLab.install(lab)
			and lab._primary_fielder.stadium_obstacles == protected_obstacles
			and host.get_children() == previous
		),
		"existing route obstacles retain exact values and block installation"
	)
	lab._primary_fielder.stadium_obstacles = obstacles
	lab._pitch_actor.running = true
	_check(not StadiumMogulOneLab.install(lab), "running physical pitch rejects candidate swap")
	lab._pitch_actor.running = false
	lab._release_controller.active = true
	_check(not StadiumMogulOneLab.install(lab), "active release rejects candidate swap")
	lab._release_controller.active = false
	lab._at_bat_cadence.state = AtBatCadenceController.State.DELIVERY
	_check(not StadiumMogulOneLab.install(lab), "delivery cadence rejects candidate swap")
	lab._at_bat_cadence.state = cadence
	lab._batted_ball = BattedBallBody.new()
	_check(not StadiumMogulOneLab.install(lab), "existing game ball rejects candidate swap")
	lab._batted_ball.free()
	lab._batted_ball = null
	lab._pitch_actor.receiver_router = _unexpected_router
	_check(not StadiumMogulOneLab.install(lab), "existing receiver callback cannot be overwritten")
	lab._pitch_actor.receiver_router = router
	host.position.x = 0.25
	_check(not StadiumMogulOneLab.install(lab), "translated geometry host rejects installation")
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
	_check(StadiumMogulOneFixture.MAX_BYTES == 1048576, "exact one MiB bounded fixture contract")
	var encoded: String = StadiumMogulOneFixture.encode(fixture)
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
					not StadiumMogulOneFixture.valid(bad)
					and StadiumMogulOneFixture.decode(JSON.stringify(bad)).is_empty()
				),
				"mixed malformed envelope rejects without Variant comparison failure"
			)
	var extra: Dictionary = fixture.duplicate(true)
	extra["production_eligible"] = true
	_check(
		not StadiumMogulOneFixture.valid(extra), "unexpected envelope keys cannot grant authority"
	)
	_check(
		(
			StadiumMogulOneFixture.decode("[]").is_empty()
			and StadiumMogulOneFixture.decode("null").is_empty()
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
		"AM-01 never inherits Grand or Club authoring authority"
	)
	for other: Dictionary in [
		StadiumGrandIFixtureStudy.capture(StadiumGrandIVenueStudy.canonical()),
		StadiumGrandIIFixtureStudy.capture(StadiumGrandIIVenueStudy.canonical())
	]:
		_check(
			not other.is_empty() and not StadiumMogulOneFixture.valid(other),
			"foreign frozen authoring profiles cannot install AM-01"
		)

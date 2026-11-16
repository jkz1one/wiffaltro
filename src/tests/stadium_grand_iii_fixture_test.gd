extends "res://src/tests/stadium_grand_i_fixture_test.gd"
## Exact Grand I helper inheritance; only explicit Grand III orchestration is overridden.
## Frozen predecessor assertions and thresholds remain unchanged.


class AlternateField:
	extends FieldDefinition

	func is_fair_point(_point: Vector3) -> bool:
		return false


func _ready() -> void:
	var property: StadiumPropertyGeometry = StadiumGrandIIIVenueStudy.build(self)
	_check(property != null, "complete Grand III builds for fixture capture")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue").duplicate(true)
	property.queue_free()
	await get_tree().process_frame
	var fixture: Dictionary = StadiumGrandIIIFixtureStudy.capture(record)
	var captured: bool = StadiumGrandIIIFixtureStudy.valid(fixture)
	_check(captured, "canonical complete fixture accepted")
	if not captured:
		print(
			"GRAND_III_CAPTURE_DIAGNOSTIC ", StadiumGrandIIIFixtureStudy.capture_diagnostic(record)
		)
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	_source_packet(fixture)
	var encoded: String = StadiumGrandIIIFixtureStudy.encode(fixture)
	var encoded_bytes: int = encoded.to_utf8_buffer().size()
	print(
		"GRAND_III_FIXTURE_BYTES payload=",
		encoded_bytes,
		" limit=",
		StadiumGrandIIIFixtureStudy.MAX_BYTES
	)
	_check(
		encoded_bytes > 0 and encoded_bytes <= StadiumGrandIIIFixtureStudy.MAX_BYTES,
		"complete exact fixture fits unchanged bounded read contract"
	)
	if encoded_bytes == 0 or encoded_bytes > StadiumGrandIIIFixtureStudy.MAX_BYTES:
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	_check(
		(
			not StadiumGrandIFixtureStudy.valid(fixture)
			and not StadiumGrandIIFixtureStudy.valid(fixture)
			and not StadiumGrandIIIFixtureStudy.valid(
				StadiumGrandIFixtureStudy.capture(StadiumGrandIVenueStudy.canonical())
			)
		),
		"Grand I and Grand III fixtures never cross-authorize each other"
	)
	_check(
		ClubCareer.same(
			fixture, StadiumGrandIIIFixtureStudy.decode(StadiumGrandIIIFixtureStudy.encode(fixture))
		),
		"full precision canonical JSON roundtrip"
	)
	record.items[0].site = "caller-mutation"
	_check(
		(
			StadiumGrandIIIFixtureStudy.valid(fixture)
			and fixture.venue.items[0].site != record.items[0].site
		),
		"capture owns a deep copy"
	)
	_check(
		(
			StadiumGrandIIIFixtureStudy.decode("{").is_empty()
			and StadiumGrandIIIFixtureStudy.decode(" ".repeat(1048577)).is_empty()
		),
		"malformed and oversized input fail closed"
	)
	_check(
		not StadiumLayoutSnapshot.valid(fixture) and not StadiumClubFixtureStudy.valid(fixture),
		"authoring has no production or AC identity"
	)
	var path: String = "user://grand-iii-fixture-%d.json" % OS.get_process_id()
	_check(
		(
			StadiumGrandIIIFixtureStudy.save(path, fixture)
			and StadiumGrandIIIFixtureStudy.save(path, fixture)
		),
		"canonical saves and replaces atomically"
	)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(
		ClubCareer.same(StadiumGrandIIIFixtureStudy.load_file(path), fixture),
		"saved complete fixture reloads exactly"
	)
	for key: String in ["kind", "sha256"]:
		for malformed: Variant in [null, [], {}, 1, true]:
			var wrong_type: Dictionary = fixture.duplicate(true)
			wrong_type[key] = malformed
			_check(
				(
					not StadiumGrandIIIFixtureStudy.valid(wrong_type)
					and StadiumGrandIIIFixtureStudy.decode(JSON.stringify(wrong_type)).is_empty()
				),
				"malformed typed fixture header rejects without mixed-Variant comparison errors"
			)
			_check(
				(
					not StadiumGrandIIIFixtureStudy.save(path, wrong_type)
					and FileAccess.get_file_as_string(path) == bytes
				),
				"malformed header cannot alter the previous atomic saved fixture"
			)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_grand_iii_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var old: Node = lab.get_node("StarterFieldGeometry/BackWall")
	_check(
		not StadiumGrandILab.install(lab),
		"Grand III opt-in does not authorize the frozen Grand I installer"
	)
	_check(not StadiumGrandIILab.install(lab), "Grand III opt-in never authorizes frozen Grand II")
	_install_guards(lab)
	await _stage_failures(lab)
	await _visibility_stage_failure(lab)
	for edit in range(41):
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
				bad.venue.model_sources.stadium_curved_lower_models = "f".repeat(64)
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
				bad.venue.model_sources["src/content/fields/starter_field.tres"] = "f".repeat(64)
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
				_row_for_site(bad.venue, "BOWL-02:UPPER").supports = ["wrong-lower"]
			25:
				_row_for_site(bad.venue, "BOWL-02:CONCOURSE").interface = "wrong-interface"
			26:
				bad.venue.environment.target_slots = ["12:00"]
			27:
				bad.venue.environment.target_weather = ["rain"]
			28:
				bad.venue.structural_layers.roofs = 1
			29:
				bad.venue.model_sources["src/presentation/stadium/stadium_curved_stack_models.gd"] = (
					"f".repeat(64)
				)
			30:
				bad.venue.crowd.total = 999
			31:
				bad.venue.lighting.qualification = "night-approved"
			32:
				_row_for_site(bad.venue, "BOWL-02:UPPER").model_version = 999
			33:
				_row_for_site(bad.venue, "BASE-L1").model_variant = "BASE-LOWER-v1"
			34:
				bad.venue.qualification_sources.execution_evidence = "fabricated-pass"
			35:
				bad.venue.layout_revision.id = "GRAND-III-v1"
			36:
				bad.venue.board.model = "video-v1"
			37:
				bad.venue.layout_revision.reservation[3] = 13
			38:
				_row_for_site(bad.venue, "BASE-R1:ROOF").supports.pop_back()
			39:
				_row_for_site(bad.venue, "JOIN-L:CONCOURSE").supports[4] = "wrong-straight"
			40:
				bad.venue.lighting.towers[0].heads[7].direction[0] += 0.1
		_check(not StadiumGrandIIIFixtureStudy.valid(bad), "tamper rejects " + str(edit))
		_check(
			(
				not StadiumGrandIIIFixtureStudy.save(path, bad)
				and FileAccess.get_file_as_string(path) == bytes
			),
			"failed write preserves original"
		)
		_check(
			(
				not StadiumGrandIIILab.install_frozen(lab, bad)
				and old == lab.get_node_or_null("StarterFieldGeometry/BackWall")
				and not lab.has_meta("stadium_property")
			),
			"failed install preserves old geometry"
		)
		if edit >= 2:
			_check(
				StadiumGrandIIIFixtureStudy.capture(bad.venue).is_empty(),
				"recomputed checksum cannot bless noncanonical record " + str(edit)
			)
	var source_field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var original_safe: float = source_field.safe_hit_z_m
	source_field.safe_hit_z_m += 0.5
	_check(
		not StadiumGrandIIIFixtureStudy.valid(fixture),
		"actual in-memory field mutation invalidates an earlier fixture even with unchanged files"
	)
	source_field.safe_hit_z_m = original_safe
	_check(
		StadiumGrandIIIFixtureStudy.valid(fixture),
		"restoring the exact field restores original source-bound fixture validity"
	)

	_check(
		not StadiumGrandIIILab.install_frozen(lab, {}), "empty frozen means failure, never defaults"
	)
	remove_child(lab)
	var orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check(
		(
			not StadiumGrandIIILab.install(lab)
			and Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == orphans
		),
		"detached host fails without allocating orphan assembly"
	)
	add_child(lab)
	_check(StadiumGrandIIILab.install_frozen(lab, fixture), "exact frozen candidate installs")
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
			"Wiffaltro Grand III fixture passed: canonical source identity, atomic IO, fail-closed install."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _stage_failures(lab: PitchBatLab) -> void:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var previous: Array[Node] = host.get_children()
	var router: Callable = lab._pitch_actor.receiver_router
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	var obstacles: Array[Dictionary] = lab._primary_fielder.stadium_obstacles.duplicate(true)
	var actual_field: FieldDefinition = lab._field_definition
	for candidate: StadiumPropertyGeometry in [FailedTemplate.new(), TransformedTemplate.new()]:
		_check(
			StadiumGrandIIIVenueStudy.build(host, candidate) == null,
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
	var staged: StadiumGrandIIIProperty = StadiumGrandIIIProperty.new()
	_check(
		StadiumGrandIIIVenueStudy.build(host, staged) == staged,
		"receiver rejection probe builds the real complete staged assembly"
	)
	if staged.objects.is_empty():
		_check(false, "failed build stops dependent receiver probe")
		return
	var net: Node3D = staged.objects["npc-candidate:GRAND-III-VIDEO:v2:RECEIVER-CATCH"]
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
		StadiumGrandIIIVenueStudy.build(child) == null and child.get_child_count() == 0,
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
	for kind: String in ["assembly", "fixture", "lab", "tracking", "game"]:
		_check(
			(
				packet.files.has("src/tests/stadium_grand_iii_%s_test.gd" % kind)
				and packet.files.has("src/tests/stadium_grand_iii_%s_test.tscn" % kind)
			),
			"all five complete new test implementations and execution scenes are source-bound"
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
	_check(not StadiumGrandIIILab.install(null), "null host fails closed")
	for invalid_flag: Variant in [false, [], {}, "true", 1]:
		lab.set_meta("stadium_grand_iii_lab_only", invalid_flag)
		_check(
			not StadiumGrandIIILab.install(lab) and host.get_children() == previous,
			"only the exact boolean true grants isolated authoring opt-in"
		)
	lab.set_meta("stadium_grand_iii_lab_only", true)
	lab._automation = MatchAutomation.new()
	_check(
		not StadiumGrandIIILab.install(lab), "preexisting automation cannot authorize a candidate"
	)
	lab._automation = null
	lab._field_id = &"field.not-grand-iii"
	_check(not StadiumGrandIIILab.install(lab), "wrong field identity cannot install")
	lab._field_id = PitchBatLab.FIELD_ID
	lab._field_definition = actual_field.duplicate(true)
	lab._field_definition.safe_hit_z_m += 0.25
	var changed_field: FieldDefinition = lab._field_definition
	_check(
		(
			not StadiumGrandIIILab.install(lab)
			and lab._field_definition == changed_field
			and host.get_children() == previous
		),
		"mismatched actual gameplay resource rejects without replacing field or geometry"
	)
	lab._field_definition = AlternateField.new()
	lab._field_definition.id = actual_field.id
	for key: String in StadiumGrandIVenueStudy.FIELD_KEYS:
		lab._field_definition.set(key, actual_field.get(key))
	var alternate: FieldDefinition = lab._field_definition
	_check(
		ClubCareer.same(
			StadiumGrandIIIVenueStudy.field_snapshot(alternate),
			StadiumGrandIIIVenueStudy.field_snapshot(actual_field)
		),
		"alternate script control keeps exact field scalar values"
	)
	_check(
		(
			not StadiumGrandIIILab.install(lab)
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
			not StadiumGrandIIILab.install(lab)
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
			not StadiumGrandIIILab.install(lab)
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
			not StadiumGrandIIILab.install(lab)
			and lab._primary_fielder.stadium_obstacles == protected_obstacles
			and host.get_children() == previous
		),
		"existing route obstacles retain exact values and block installation"
	)
	lab._primary_fielder.stadium_obstacles = obstacles
	lab._pitch_actor.running = true
	_check(not StadiumGrandIIILab.install(lab), "running physical pitch rejects candidate swap")
	lab._pitch_actor.running = false
	lab._release_controller.active = true
	_check(not StadiumGrandIIILab.install(lab), "active release rejects candidate swap")
	lab._release_controller.active = false
	lab._at_bat_cadence.state = AtBatCadenceController.State.DELIVERY
	_check(not StadiumGrandIIILab.install(lab), "delivery cadence rejects candidate swap")
	lab._at_bat_cadence.state = cadence
	lab._batted_ball = BattedBallBody.new()
	_check(not StadiumGrandIIILab.install(lab), "existing game ball rejects candidate swap")
	lab._batted_ball.free()
	lab._batted_ball = null
	lab._pitch_actor.receiver_router = _unexpected_router
	_check(not StadiumGrandIIILab.install(lab), "existing receiver callback cannot be overwritten")
	lab._pitch_actor.receiver_router = router
	host.position.x = 0.25
	_check(not StadiumGrandIIILab.install(lab), "translated geometry host rejects installation")
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


func _visibility_stage_failure(lab: PitchBatLab) -> void:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var previous: Array[Node] = host.get_children()
	var camera: MatchCameraDirector = lab._camera_director
	var router: Callable = lab._pitch_actor.receiver_router
	var observer: Callable = lab._ball_play_resolver.segment_observer
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	var obstacles: Array[Dictionary] = lab._primary_fielder.stadium_obstacles.duplicate(true)
	var field: FieldDefinition = lab._field_definition
	var staged: StadiumGrandIIIProperty = StadiumGrandIIIProperty.new()
	if (
		StadiumGrandIIIVenueStudy.build(host, staged) != staged
		or not staged.configure_candidate(lab)
	):
		_check(false, "visibility failure probe requires actual complete configured candidate")
		if is_instance_valid(staged):
			StadiumGrandIVenueStudy._discard(staged)
		return
	var board: Node3D = staged.objects[StadiumGrandIIIVenueStudy.PREFIX + "BOARD-LARGE-v2"]
	var visual: Node = board.get_node("Visual")
	visual.name = "MissingVisualControl"
	var visibility: StadiumGrandIIIFieldVisibility = StadiumGrandIIIFieldVisibility.new()
	_check(
		(
			not visibility.configure_candidate(staged)
			and not visibility.ready
			and visibility.last_error.contains("missing required Visual branch for ST-040")
			and visibility._groups.is_empty()
			and visibility.model_meshes.is_empty()
			and visibility._rails.is_empty()
			and visibility._recipe == null
			and visibility._wall_prisms == null
		),
		"missing visual preflight fails atomically before any usable camera groups exist"
	)
	for node: Node in previous:
		_check(
			is_instance_valid(node) and node.get_parent() == host,
			"visibility preflight rejection retains every original field node"
		)
	_check(
		(
			lab._camera_director == camera
			and lab._pitch_actor.receiver_router == router
			and lab._ball_play_resolver.segment_observer == observer
			and lab._primary_fielder.stadium_boundary_clip == clip
			and lab._primary_fielder.stadium_obstacles == obstacles
			and lab._field_definition == field
			and not lab.has_meta("stadium_property")
		),
		"visibility preflight cannot alter original camera field callbacks routes or installation flags"
	)
	visual.name = "Visual"
	_check(
		visibility.configure_candidate(staged) and visibility.ready,
		"restored real hierarchy passes the same exact preflight"
	)
	host.remove_child(staged)
	staged.queue_free()
	await get_tree().process_frame
	_check(
		host.get_children() == previous and lab._camera_director == camera,
		"rejected staging leaves exact original child order and camera intact after release"
	)

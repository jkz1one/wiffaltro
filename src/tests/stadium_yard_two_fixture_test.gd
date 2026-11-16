extends Node3D
## Canonical records reject even correctly rehashed edits; public admission stays closed.

var _failures: int = 0


func _ready() -> void:
	var fixture: Dictionary = StadiumYardTwoFixture.capture(StadiumYardTwoStudy.canonical())
	if fixture.is_empty() or not StadiumYardTwoFixture.valid(fixture):
		_check(false, "canonical candidate captures")
		get_tree().quit(1)
		return
	var encoded: String = StadiumYardTwoFixture.encode(fixture)
	if (
		encoded.is_empty()
		or StadiumYardTwoFixture.encode(StadiumYardTwoFixture.decode(encoded)) != encoded
	):
		_check(false, "full-precision JSON roundtrip keeps the exact canonical record")
		get_tree().quit(1)
		return
	_check(
		(
			StadiumYardTwoFixture.decode("{").is_empty()
			and StadiumYardTwoFixture.decode(" ".repeat(32769)).is_empty()
		),
		"bounded decoding"
	)
	for edit in range(19):
		var bad: Dictionary = fixture.duplicate(true)
		match edit:
			0:
				bad.venue.items[0].transform[9] += 0.125
			1:
				bad.venue.items[0].item = "ST-080"
			2:
				bad.venue.items[0].site = "SC-L3"
			3:
				bad.venue.items.pop_back()
			4:
				bad.venue.items[1].instance = bad.venue.items[0].instance
			5:
				bad.venue.environment.certificates = ["night"]
			6:
				bad.venue.endowment.spendable = true
			7:
				bad.venue.status = "VALIDATED"
			8:
				bad.venue.boundary.segments[0].height = 5
			9:
				bad.venue.receiver.catalog_item = "ST-026"
			10:
				bad.venue.surface.styles = ["ST-063e"]
			11:
				bad.venue.model_sources.starter_models = "foreign"
			12:
				bad.venue.items[3].host = "SC-L1"
			13:
				bad.venue.receiver.cleanup_z -= 0.0001
			14:
				bad.venue.live_units = 0
			15:
				bad.venue.field.values.safe_hit_z_m += 0.0001
			16:
				bad.venue.field.id = "field.starter_backyard"
			17:
				bad.venue.items[3].transform[9] += 0.0001
			18:
				bad.venue.environment.night_eligible = true
		bad.sha256 = JSON.stringify(bad.venue, "", true, true).sha256_text()
		_check(not StadiumYardTwoFixture.valid(bad), "rehashed edit rejected " + str(edit))
	_malformed(fixture)
	for field: String in ["kind", "sha256"]:
		for value: Variant in [null, true, 1, [], {}]:
			var bad: Dictionary = fixture.duplicate(true)
			bad[field] = value
			_check(
				(
					not StadiumYardTwoFixture.valid(bad)
					and StadiumYardTwoFixture.encode(bad).is_empty()
					and StadiumYardTwoFixture.decode(JSON.stringify(bad)).is_empty()
				),
				"typed malformed envelope rejects without invalid Variant comparison"
			)
	_check(
		not StadiumYardTwoFixture.valid(
			StadiumYardFixtureStudy.capture(StadiumYardVenueStudy.canonical())
		),
		"AY-01 authoring fixture cannot alias AY-02"
	)
	_check(not StadiumLayoutSnapshot.valid(fixture), "authoring record is not a human snapshot")
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(not StadiumYardTwoLab.install(lab, fixture), "explicit opt-in required")
	lab.set_meta("stadium_yard_two_lab_only", true)
	lab._managed_match = true
	_check(not StadiumYardTwoLab.install(lab, fixture), "managed fixture cannot opt in")
	lab._managed_match = false
	_preflight(lab, fixture)
	_check(
		(
			not StadiumYardTwoLab.install(lab, {})
			and lab.get_node("StarterFieldGeometry").has_node("BackWall")
			and not lab.has_meta("stadium_property")
		),
		"invalid fixture preserves prior complete scene"
	)
	if not StadiumYardTwoLab.install(lab, fixture):
		_check(false, "canonical fixture installs")
		lab.queue_free()
		await get_tree().process_frame
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	_check(not StadiumYardTwoLab.install(lab, fixture), "canonical fixture installs only once")
	_check(
		(
			lab._field_id == &"field.npc_venue"
			and lab._field_definition.id == &"field.npc_venue"
			and lab._field_definition == lab.get_meta("stadium_property").field
		),
		"ordinary controller and assembly share the exact private NPC field"
	)
	_check(
		PhysicalMatchReport.capture(lab).is_empty(), "candidate cannot issue a production report"
	)
	_check(
		lab._match_state.stadium.is_empty(), "no human paid history or production fixture assigned"
	)
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property")
	var receiver: StadiumYardTwoReceiver = property.get_node("PitchReceiverPresentation")
	_check(
		receiver.bound() and lab._pitch_actor.receiver_router == receiver.route,
		"callback is the actual bound candidate chair receiver"
	)
	_check(
		(
			StadiumStock.new().copies.is_empty()
			and not StadiumStock.new().copies.has(StadiumYardTwoStudy.PREFIX + "O-R1")
		),
		"candidate aliases cannot mint a human stock copy"
	)
	var human_layout: Dictionary = StadiumStarterLayout.empty()
	human_layout.receiver = StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY"
	human_layout.obstacles = [
		{"copy": StadiumYardTwoStudy.PREFIX + "O-R1", "site": "O-R1", "yaw": 0}
	]
	_check(
		not StadiumHomeLayout.validate(human_layout, StadiumStock.new(), "backyard").ok,
		"NPC contact aliases never satisfy real human ownership or construction entitlement"
	)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro yard-two fixture passed: "
				+ "canonical identity, no promotion and public rejection."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _malformed(fixture: Dictionary) -> void:
	for edit in range(11):
		# Decode first so raw JSON containers do not inherit typed Array[float] coercions.
		var bad: Dictionary = JSON.parse_string(StadiumYardTwoFixture.encode(fixture))
		match edit:
			0:
				bad.venue.version = true
			1:
				bad.venue.endowment.land_value = false
			2:
				bad.venue.items[0].transform[0] = false
			3:
				bad.venue.items[0].transform = {"x": 0}
			4:
				bad.venue.items[0].transform = []
			5:
				bad.venue.items = {}
			6:
				bad.venue.items[0] = null
			7:
				bad.venue.items[0].transform[9] = NAN
			8:
				bad.venue.items[0]["extra"] = "unapproved"
			9:
				bad.venue.receiver["extra"] = 0
			10:
				bad.venue.boundary.segments = false
		bad.sha256 = JSON.stringify(bad.venue, "", true, true).sha256_text()
		_check(
			(
				StadiumYardTwoFixture.capture(bad.venue).is_empty()
				and not StadiumYardTwoFixture.valid(bad)
				and StadiumYardTwoFixture.decode(JSON.stringify(bad, "", true, true)).is_empty()
			),
			"raw malformed nested candidate rejects through capture/valid/decode " + str(edit)
		)


func _preflight(lab: PitchBatLab, fixture: Dictionary) -> void:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var field: FieldDefinition = lab._field_definition
	var camera: BallTrackingVisibility = lab._camera_director.tracking_visibility
	var children: Array[Node] = host.get_children()
	for edit in range(10):
		match edit:
			0:
				host.position.x = 0.000001
			1:
				lab._field_definition = field.duplicate(true)
				lab._field_definition.safe_hit_z_m += 0.000001
			2:
				lab._field_definition = (
					preload("res://src/tests/stadium_npc_candidate_v2_forged_field.gd").new()
				)
				for key: String in StadiumNpcYardV1.FIELD:
					lab._field_definition.set(key, field.get(key))
			3:
				lab._ball_play_resolver.segment_observer = StadiumBoundaryObserver.observe
			4:
				lab._primary_fielder.stadium_boundary_clip = StadiumBoundaryGraph.clip
			5:
				lab._primary_fielder.stadium_obstacles.append(
					{"center": Vector3.ZERO, "radius": 1.0}
				)
			6:
				lab._camera_director.tracking_visibility = StadiumYardFieldVisibility.new()
			7:
				lab._automation = MatchAutomation.new()
			8:
				var foreign: StaticBody3D = StaticBody3D.new()
				foreign.name = "ForeignCollider"
				host.add_child(foreign)
			9:
				camera._obstacles.append(AABB(Vector3.ZERO, Vector3.ONE))
		_check(
			(
				not StadiumYardTwoLab.install(lab, fixture)
				and not lab.has_meta("stadium_property")
				and host.has_node("BackWall")
			),
			"foreign host/field/hooks reject without replacing geometry " + str(edit)
		)
		host.transform = Transform3D.IDENTITY
		lab._field_definition = field
		lab._ball_play_resolver.segment_observer = Callable()
		lab._primary_fielder.stadium_boundary_clip = Callable()
		lab._primary_fielder.stadium_obstacles.clear()
		camera.configure(host)
		lab._camera_director.tracking_visibility = camera
		lab._automation = null
		if host.has_node("ForeignCollider"):
			host.get_node("ForeignCollider").free()
		_check(
			host.get_children() == children, "failed install preserves exact original host children"
		)

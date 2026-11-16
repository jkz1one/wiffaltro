extends Node3D
## Canonical records reject even correctly rehashed edits; public admission stays closed.

var _failures: int = 0


func _ready() -> void:
	var fixture: Dictionary = StadiumYardFixtureStudy.capture(StadiumYardVenueStudy.canonical())
	_check(StadiumYardFixtureStudy.valid(fixture), "canonical candidate captures")
	var encoded: String = StadiumYardFixtureStudy.encode(fixture)
	_check(StadiumYardFixtureStudy.encode(StadiumYardFixtureStudy.decode(encoded)) == encoded,
		"full-precision JSON roundtrip keeps the exact canonical record")
	_check(StadiumYardFixtureStudy.decode("{").is_empty()
		and StadiumYardFixtureStudy.decode(" ".repeat(32769)).is_empty(), "bounded decoding")
	for edit in range(12):
		var bad: Dictionary = fixture.duplicate(true)
		match edit:
			0: bad.venue.items[0].transform[9] += 0.125
			1: bad.venue.items[0].item = "ST-079"
			2: bad.venue.items[0].site = "SC-L3"
			3: bad.venue.items.pop_back()
			4: bad.venue.items[1].instance = bad.venue.items[0].instance
			5: bad.venue.environment.certificates = ["night"]
			6: bad.venue.endowment.spendable = true
			7: bad.venue.status = "VALIDATED"
			8: bad.venue.boundary.segments[0].height = 5
			9: bad.venue.receiver.catalog_item = "ST-026"
			10: bad.venue.surface.styles = ["ST-063e"]
			11: bad.venue.model_sources.chair = "foreign"
		bad.sha256 = JSON.stringify(bad.venue, "", true, true).sha256_text()
		_check(not StadiumYardFixtureStudy.valid(bad), "rehashed edit rejected " + str(edit))
	_malformed(fixture)
	_check(not StadiumLayoutSnapshot.valid(fixture), "authoring record is not a human snapshot")
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(not StadiumYardLab.install(lab, fixture), "explicit opt-in required")
	lab.set_meta("stadium_yard_lab_only", true)
	lab._managed_match = true
	_check(not StadiumYardLab.install(lab, fixture), "managed fixture cannot opt in")
	lab._managed_match = false
	_check(not StadiumYardLab.install(lab, {})
		and lab.get_node("StarterFieldGeometry").has_node("BackWall")
		and not lab.has_meta("stadium_property"), "invalid fixture preserves prior complete scene")
	_check(StadiumYardLab.install(lab, fixture) and not StadiumYardLab.install(lab, fixture),
		"canonical fixture installs once")
	_check(PhysicalMatchReport.capture(lab).is_empty(), "candidate cannot issue a production report")
	_check(lab._match_state.stadium.is_empty(), "no human paid history or production fixture assigned")
	_check(not lab._pitch_actor.receiver_router.is_valid()
		and lab.get_node("StarterFieldGeometry").has_node("PitchReceiverDebug"),
		"functional free receiver is preserved without an unowned paid substitute")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro yard fixture passed: canonical identity, no promotion and public rejection.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _malformed(fixture: Dictionary) -> void:
	for edit in range(11):
		# Decode first so raw JSON containers do not inherit typed Array[float] coercions.
		var bad: Dictionary = JSON.parse_string(StadiumYardFixtureStudy.encode(fixture))
		match edit:
			0: bad.venue.version = true
			1: bad.venue.endowment.land_value = false
			2: bad.venue.items[0].transform[0] = false
			3: bad.venue.items[0].transform = {"x": 0}
			4: bad.venue.items[0].transform = []
			5: bad.venue.items = {}
			6: bad.venue.items[0] = null
			7: bad.venue.items[0].transform[9] = NAN
			8: bad.venue.items[0]["extra"] = "unapproved"
			9: bad.venue.receiver["extra"] = 0
			10: bad.venue.boundary.segments = false
		bad.sha256 = JSON.stringify(bad.venue, "", true, true).sha256_text()
		_check(StadiumYardFixtureStudy.capture(bad.venue).is_empty()
			and not StadiumYardFixtureStudy.valid(bad)
			and StadiumYardFixtureStudy.decode(JSON.stringify(bad, "", true, true)).is_empty(),
			"raw malformed nested candidate rejects through capture/valid/decode " + str(edit))

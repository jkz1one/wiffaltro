extends Node3D
## Frozen authoring-only records: strict shape, canonical identity, edit detection and atomic IO.

var _failures: int = 0


func _ready() -> void:
	var property: StadiumPropertyGeometry = StadiumClubVenueStudy.build(self)
	var record: Dictionary = property.get_meta("candidate_venue").duplicate(true)
	property.queue_free()
	await get_tree().process_frame
	var fixture: Dictionary = StadiumClubFixtureStudy.capture(record)
	_check(
		StadiumClubFixtureStudy.valid(fixture),
		"actual complete record becomes an authoring fixture"
	)
	record.items[0].site = "caller-mutation"
	_check(
		(
			StadiumClubFixtureStudy.valid(fixture)
			and fixture.venue.items[0].site != record.items[0].site
		),
		"caller changes cannot rewrite a captured fixture"
	)
	_check(
		ClubCareer.same(
			fixture, StadiumClubFixtureStudy.decode(StadiumClubFixtureStudy.encode(fixture))
		),
		"full precision fixture JSON retains every copy and transform"
	)
	_check(
		(
			StadiumClubFixtureStudy.decode("{").is_empty()
			and (
				StadiumClubFixtureStudy
				. decode(" ".repeat(StadiumClubFixtureStudy.MAX_BYTES + 1))
				. is_empty()
			)
		),
		"malformed and oversized serialized fixtures reject without fallback"
	)
	for key: String in ["kind", "version", "venue", "sha256"]:
		var bad: Dictionary = fixture.duplicate(true)
		bad[key] = false
		_check(not StadiumClubFixtureStudy.valid(bad), "malformed envelope field " + key)
	for key: String in ["id", "status", "property", "source"]:
		var bad: Dictionary = fixture.venue.duplicate(true)
		bad[key] = false
		_check(StadiumClubFixtureStudy.capture(bad).is_empty(), "typed venue identity " + key)
	var changed: Dictionary = fixture.duplicate(true)
	changed.venue.items[0].transform[9] += 0.125
	_check(not StadiumClubFixtureStudy.valid(changed), "edit is detected by the held checksum")
	for edit in range(8):
		var bad: Dictionary = fixture.venue.duplicate(true)
		match edit:
			0:
				bad.items.pop_back()
			1:
				bad.items[1].instance = bad.items[0].instance
			2:
				bad.items[1].site = bad.items[0].site
			3:
				bad.items[0].transform[0] = NAN
			4:
				bad.items[0].item = "foreign"
			5:
				bad.environment_certificates = ["free-night"]
			6:
				bad.models.net = false
			7:
				bad.copy_value = -1
		_check(StadiumClubFixtureStudy.capture(bad).is_empty(), "malformed venue edit " + str(edit))
	var path: String = "user://club-study-atomic-%d.json" % OS.get_process_id()
	_check(
		StadiumClubFixtureStudy.save(path, fixture) and StadiumClubFixtureStudy.save(path, fixture),
		"valid fixture saves and replaces atomically"
	)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(
		StadiumClubFixtureStudy.encode(StadiumClubFixtureStudy.load_file(path)) == bytes,
		"canonical integer and float32 scene values retain a stable serialized checksum"
	)
	_check(
		(
			not StadiumClubFixtureStudy.save(path, changed)
			and FileAccess.get_file_as_string(path) == bytes
		),
		"failed update preserves the previous good file"
	)
	_check(
		ClubCareer.same(StadiumClubFixtureStudy.load_file(path), fixture),
		"file reload preserves value"
	)
	DirAccess.remove_absolute(path)
	await _canonical_rejection(fixture, changed.venue)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Club fixture study passed: frozen IO, tamper rejection and no template fallback."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _canonical_rejection(fixture: Dictionary, edited_venue: Dictionary) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_club_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	remove_child(lab)
	var orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check(
		(
			not StadiumClubLab.install(lab)
			and Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == orphans
		),
		"detached host rejection does not allocate an orphan property"
	)
	add_child(lab)
	_check(
		not StadiumClubLab.install_frozen(lab, {}), "an invalid loaded envelope cannot mean default"
	)
	var forged: Dictionary = StadiumClubFixtureStudy.capture(edited_venue)
	_check(
		StadiumClubFixtureStudy.valid(forged),
		"self-consistent edit exercises authority beyond hashing"
	)
	_check(
		(
			not StadiumClubLab.install_frozen(lab, forged)
			and not lab.has_meta("stadium_property")
			and lab.get_node("StarterFieldGeometry").has_node("BackWall")
			and not lab.get_node("StarterFieldGeometry").has_node("AC01Candidate")
		),
		"recomputed checksum cannot alter the canonical model or partially replace the current field"
	)
	_check(StadiumClubLab.install_frozen(lab, fixture), "exact frozen canonical fixture installs")
	_check(
		ClubCareer.same(
			fixture.venue, lab.get_meta("stadium_property").get_meta("candidate_venue")
		),
		"installed model record exactly matches the loaded fixture"
	)
	_check(
		PhysicalMatchReport.capture(lab).is_empty(),
		"saved authoring fixture grants no reward report"
	)
	lab.queue_free()
	await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

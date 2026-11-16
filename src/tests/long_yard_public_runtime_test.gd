extends Node3D
## Reconstructed 2026-11-05 public lifecycle regression, NOT recovered historical test bytes.
## Five fresh installations, no pitches, earned progression, rendering or game-result claims.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const FIXTURE = preload("res://src/tests/long_yard_public_fixture.gd")
const CASES: Array[String] = ["lifecycle-away", "lifecycle-home", "binding", "record", "sun"]
var _checks: int = 0
var _failures: int = 0
var _installs: int = 0
var _completed: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_check(R.source_qualified() and FIXTURE.ready(), "current sources and explicit fixture qualify")
	if _failures == 0:
		for label: String in CASES:
			print("LONG_YARD_RECONSTRUCTED_RUNTIME_BEGIN case=" + label)
			await _case(label)
	_check(_installs == CASES.size() and _completed == CASES.size(),
		"all five distinct positive installations and completed cases are required")
	await TestAudioDrain.finish(get_tree())
	print("LONG_YARD_RECONSTRUCTED_RUNTIME_RESULT checks=%d failures=%d installs=%d cases=%d games=0" %
		[_checks, _failures, _installs, _completed])
	get_tree().quit(0 if _failures == 0 else 1)


func _case(label: String) -> void:
	var original: SeasonState = FIXTURE.season()
	_check(original != null, "real draft and explicit record exist: " + label)
	if original == null:
		return
	var saved: Dictionary = SeasonSave.snapshot(original)
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(
		JSON.stringify(saved, "", true, true)))
	_check(season != null and ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"exact full-precision saved record restores: " + label)
	if season == null:
		return
	var home: bool = label == "lifecycle-home"
	var fixture: Dictionary = FIXTURE.fixture(season, home)
	var before: Dictionary = SeasonSave.snapshot(season)
	var prior_msaa: int = get_viewport().msaa_3d
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = SeasonPhysicalFixtures.match_for(season, fixture)
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	lab._player_home = home
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var property: StadiumNpcPublicProperty = R._property(lab)
	var admitted: bool = not lab.yard_bound_startup_failed and property != null \
		and property.issued and R.installed_bound(lab, lab._match_state.stadium)
	_check(admitted, "fresh genuine neutral public installation: " + label)
	if not admitted:
		lab.free()
		return
	_installs += 1
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._at_bat_cadence.stop()
	_check(property.venue_id == "LONG-YARD" and property.objects.size() == 67
		and property.field == lab._field_definition and property.field.id == &"field.npc_venue"
		and lab._stadium_ledger == null and property.public_bound,
		"67 public copies own the actual field without human stock")
	_check(property.receiver.get_script() == StadiumLongYardPublicReceiver
		and property.boundary.get_script() == StadiumLongYardPublicBoundary
		and property.presentation_director.get_script() == StadiumLongYardPublicCamera
		and lab._camera_director == property.presentation_director
		and lab._ball_play_resolver.segment_observer == property.observe,
		"concrete receiver, boundary, camera and resolver belong to issued owner")
	_check(property.callback_intact() and StadiumLongYardEnvironmentV1.installed(
		lab, property.environment_lease), "positive callbacks and environment precede negatives")
	_check(not R.install_bound(lab) and R.installed_bound(lab, lab._match_state.stadium),
		"duplicate install refuses without revoking original")
	var snapshot: Dictionary = lab._match_state.stadium.duplicate(true)
	var record: Dictionary = season.final_venue.duplicate(true)
	var sun_energy: float = property.environment_lease.sun.light_energy
	match label:
		"binding":
			lab._match_state.stadium.binding.venue_owner = "foreign-owner"
		"record":
			season.final_venue = {}
		"sun":
			property.environment_lease.sun.light_energy += 0.25
	if not label.begins_with("lifecycle"):
		_check(not property.callback_intact() and property.suspended
			and lab.process_mode == Node.PROCESS_MODE_DISABLED,
			"changed authority or environment retires callback owner: " + label)
		lab._match_state.stadium = snapshot
		season.final_venue = record
		property.environment_lease.sun.light_energy = sun_energy
		_check(StadiumLongYardEnvironmentV1.installed(lab, property.environment_lease),
			"exact environment restored before sticky-retirement probe: " + label)
		_check(not property.callback_intact() and not R.install_bound(lab),
			"restoring input bytes cannot revive retired installation: " + label)
	_check(ClubCareer.same(before, SeasonSave.snapshot(season))
		and lab._throw_number == 0 and lab._play_records.is_empty()
		and PhysicalMatchReport.capture(lab).is_empty(), "probes fabricate no game or save changes")
	await _teardown(lab, property, prior_msaa)
	_completed += 1
	print("LONG_YARD_RECONSTRUCTED_RUNTIME_END case=" + label)


func _teardown(lab: PitchBatLab, property: StadiumNpcPublicProperty, prior_msaa: int) -> void:
	var lease: Dictionary = property.environment_lease
	var prior: Dictionary = lease.duplicate(false)
	var old_camera: MatchCameraDirector = property.old_camera
	var old_field: FieldDefinition = property.old_field
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	_check(R.teardown(lab), "idle issued or retired owner tears down")
	_check(lease.is_empty() and lab._world_environment.environment == prior.before_environment
		and prior.sun.rotation == prior.before_rotation and prior.sun.light_color == prior.before_color
		and prior.sun.light_energy == prior.before_energy
		and prior.sun.shadow_enabled == prior.before_shadows,
		"same-origin environment and sun restore exactly, including mutated sun")
	await get_tree().process_frame
	_check(lab._camera_director == old_camera and lab._field_definition == old_field
		and lab.has_meta("stadium_npc_runtime_interrupted")
		and not lab.has_meta("stadium_snapshot") and not R.install_bound(lab),
		"exact original camera/field restored but interrupted fixture cannot restart")
	lab.free()
	await get_tree().process_frame
	_check(get_viewport().msaa_3d == prior_msaa, "last owner restores original MSAA")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("LONG_YARD_RECONSTRUCTED_RUNTIME: " + label)

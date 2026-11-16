extends Node3D
## Physical-idle guards apply only to opt-in authoring, never production bootstrap.

var _failures: int = 0
var _club_fixture: Dictionary = {}
var _advanced_fixture: Dictionary = {}
var _ledger: ClubAssetLedger


func _ready() -> void:
	_check(not StadiumPropertyRuntime.authoring_delivery_idle(null), "null lab is not idle authoring")
	_fixtures()
	for kind: String in ["property", "boundary", "advanced", "club", "advanced-frozen", "club-frozen"]:
		await _adapter(kind)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro authoring guards passed: "
			+ "live deliveries reject and idle mechanics still installs.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fixtures() -> void:
	var property: StadiumPropertyGeometry = StadiumClubVenueStudy.build(self)
	_club_fixture = StadiumClubFixtureStudy.capture(property.get_meta("candidate_venue"))
	property.free()
	_ledger = ClubAssetLedger.new(19, [], [])
	var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(StadiumSurfaceLayout.upgrade(
		StadiumStarterLayout.empty(), _ledger.surface_owned(), true))
	_check(_ledger.commit({"id": "draft", "rev": 0, "op": "stadium_draft", "layout": layout}).ok,
		"synthetic empty authoring field draft")
	_check(_ledger.commit({"id": "apply", "rev": 1, "op": "stadium_apply", "layout": layout,
		"geometry": StadiumOwnedLayout.geometry("backyard", layout)}).ok,
		"synthetic exact empty authoring field apply")
	_advanced_fixture = StadiumAdvancedSnapshot.fixture(
		StadiumAdvancedSnapshot.capture(_ledger), 47, 0)
	_check(StadiumAdvancedSnapshot.matches(_advanced_fixture, _ledger)
		and StadiumClubFixtureStudy.valid(_club_fixture), "valid positive-control authoring fixtures")


func _adapter(kind: String) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var install: Callable = _installer(lab, kind)
	_check(lab._match_state.phase == MatchState.Phase.PRE_PITCH, "idle initial match for " + kind)
	lab._match_mode = false
	lab._throw_pitch()
	_check(lab._pitch_actor.running and lab._match_state.phase == MatchState.Phase.PRE_PITCH,
		"actual mechanics flight retains suspended match phase: " + kind)
	_refused(lab, install, kind + " mechanics flight")
	lab._match_mode = true
	_refused(lab, install, kind + " inconsistent phase during physical flight")
	lab._pitch_actor.reset_pitch()
	lab._release_controller.begin()
	_refused(lab, install, kind + " active release gesture")
	lab._release_controller.cancel()
	for state: int in [AtBatCadenceController.State.DELIVERY, AtBatCadenceController.State.PITCH_LIVE,
		AtBatCadenceController.State.DEAD_BALL_HOLD]:
		lab._at_bat_cadence.state = state as AtBatCadenceController.State
		_refused(lab, install, kind + " busy cadence")
	lab._at_bat_cadence.stop()
	lab._match_mode = false
	_check(install.call(), "explicit idle mechanics authoring remains supported: " + kind)
	lab.free()
	await get_tree().process_frame


func _installer(lab: PitchBatLab, kind: String) -> Callable:
	lab.set_meta("stadium_lab_only", true)
	lab.set_meta("stadium_boundary_lab_only", true)
	lab.set_meta("stadium_advanced_lab_only", true)
	lab.set_meta("stadium_club_lab_only", true)
	if kind == "property":
		return func() -> bool:
			return StadiumPropertyRuntime.install_lab(
				lab, StadiumStarterLayout.empty(), StadiumStock.new_club())
	if kind == "boundary":
		_check(StadiumPropertyRuntime.install_lab(
			lab, StadiumStarterLayout.empty(), StadiumStock.new_club()),
			"valid base property before boundary authoring")
		return func() -> bool: return StadiumBoundaryLab.install(lab)
	if kind == "advanced":
		return func() -> bool:
			return StadiumAdvancedLab.install(lab, _advanced_fixture.layout,
				_ledger.construction(), _ledger.wall_pieces(), _ledger.surface_owned(), "backyard")
	if kind == "advanced-frozen":
		return func() -> bool: return StadiumAdvancedLab.install_frozen(lab, _advanced_fixture, _ledger)
	if kind == "club-frozen":
		return func() -> bool: return StadiumClubLab.install_frozen(lab, _club_fixture)
	return func() -> bool: return StadiumClubLab.install(lab)


func _refused(lab: PitchBatLab, install: Callable, reason: String) -> void:
	var before: Dictionary = _field_state(lab)
	_check(not install.call(), "reject " + reason)
	_check(before == _field_state(lab), "preserve geometry, routers and camera for " + reason)


func _field_state(lab: PitchBatLab) -> Dictionary:
	var nodes: Array[int] = []
	for child: Node in lab.get_node("StarterFieldGeometry").find_children("*", "", true, false):
		nodes.append(child.get_instance_id())
	return {"nodes": nodes, "property": (lab.get_meta("stadium_property")
		if lab.has_meta("stadium_property") else null),
		"observer": lab._ball_play_resolver.segment_observer,
		"receiver": lab._pitch_actor.receiver_router,
		"clip": lab._primary_fielder.stadium_boundary_clip,
		"obstacles": lab._primary_fielder.stadium_obstacles.duplicate(true),
		"camera": lab._camera.global_transform, "director": lab._camera_director,
		"shot": lab._camera_director.shot}


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

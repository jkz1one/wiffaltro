extends Node
const ATTEMPT = preload("res://src/presentation/stadium/stadium_npc_ac02_startup_preparing_v1.gd")
var failed: bool = false


func _ready() -> void:
	print("STARTUP_PREPARING parse/load complete")
	var lab: PitchBatLab = PitchBatLab.new()
	var property: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
	_check(not lab.ac02_startup_pending(), "fresh lab retains historical dispatch")
	lab._ac02_startup_enrolled = true
	_check(lab.ac02_startup_pending(), "lost attempt retains lab denial")
	_check(not StadiumNpcPublicRuntime.install_bound(lab), "pending install never falls back")
	_check(
		not StadiumNpcPublicRuntime.installed(lab), "pending installed denied before owner reads"
	)
	_check(not StadiumNpcPublicRuntime.installed_bound(lab, {}), "pending deep boundary denied")
	_check(
		not StadiumPropertyRuntime.npc_installed_bound(lab, {}),
		"pending NPC export boundary denied"
	)
	_check(not PitchBatLabFeelSupport._public_export_intact(lab), "pending export denied")
	_check(not StadiumNpcAc02IssuedStateV1.before_settlement(lab), "pending settlement denied")
	_check(
		StadiumNpcAc02IssuedStateV1.complete_manual_record(lab, &"OUT"),
		"pending completion consumed without fallback"
	)
	_check(lab._active_play_record == null and lab._play_records.is_empty(), "no record created")
	property._ac02_startup_enrolled = true
	_check(not property.callback_intact(), "lost property attempt retains callback denial")
	_check(
		not StadiumNpcAc02IssuedWritersV1.preissue_only(property, "control"),
		"pending supported writer denied"
	)
	_check(
		property.suspended and not property.issued,
		"lost attempt fail-closed without cleanup adoption"
	)
	var attempt: RefCounted = ATTEMPT.new()
	attempt.abort("first failure")
	attempt.abort("second failure")
	_check(attempt.reason == "first failure" and not attempt.committed(), "abort is sticky")
	var app: SeasonApp = SeasonApp.new()
	app.lab = lab
	app._open_match(null, false, false)
	_check(
		app.lab == lab and lab._match_state == null,
		"pending open never starts replacement or fallback"
	)
	app.lab = null
	_check(not attempt.enroll(app, lab), "aborted attempt cannot enroll again")
	var fresh: RefCounted = ATTEMPT.new()
	var custom: PitchBatLab = PitchBatLab.new()
	_check(
		not fresh.enroll(app, custom) and not custom._ac02_startup_enrolled,
		"ineligible custom route has no enrollment side effect"
	)
	var discarded: PitchBatLab = PitchBatLab.new()
	var replacement: PitchBatLab = PitchBatLab.new()
	var cleanup: RefCounted = ATTEMPT.new()
	cleanup.app = app
	cleanup.lab = discarded
	app.add_child(discarded)
	app.lab = discarded
	cleanup.dispose()
	_check(
		discarded.is_queued_for_deletion() and app.lab == null,
		"captured lost-token lab disposed and app pointer cleared"
	)
	var old: PitchBatLab = PitchBatLab.new()
	var replaced_cleanup: RefCounted = ATTEMPT.new()
	replaced_cleanup.app = app
	replaced_cleanup.lab = old
	app.add_child(old)
	app.lab = replacement
	replaced_cleanup.dispose()
	_check(
		(
			old.is_queued_for_deletion()
			and app.lab == replacement
			and not replacement.is_queued_for_deletion()
		),
		"replacement is not adopted by disposal"
	)
	var adopter: Node = Node.new()
	var adopted: PitchBatLab = PitchBatLab.new()
	var adopted_cleanup: RefCounted = ATTEMPT.new()
	adopted_cleanup.app = app
	adopted_cleanup.lab = adopted
	adopter.add_child(adopted)
	adopted_cleanup.dispose()
	_check(
		not adopted.is_queued_for_deletion() and adopted.get_parent() == adopter,
		"foreign-adopted captured lab left untouched"
	)
	adopter.free()
	replacement.free()
	property.free()
	lab.free()
	custom.free()
	app.free()
	for phase: int in [ATTEMPT.State.PREPARING, ATTEMPT.State.VALIDATING]:
		for kind: String in ["writer", "capture", "guide", "close", "reentry"]:
			_pending_retirement_component(phase, kind)
	print("STARTUP_PREPARING controls complete failed=", failed)
	get_tree().quit(1 if failed else 0)


func _check(ok: bool, label: String) -> void:
	print("STARTUP_PREPARING ", "PASS " if ok else "FAIL ", label)
	failed = failed or not ok


func _pending_retirement_component(phase: int, kind: String) -> void:
	# Explicit rejection-only components, NOT a valid installed owner or proof injection.
	var lab: PitchBatLab = PitchBatLab.new()
	var property: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
	var app: SeasonApp = SeasonApp.new()
	var attempt: RefCounted = ATTEMPT.new()
	attempt.state = phase
	attempt.app = app
	attempt.lab = lab
	attempt.property = property
	app.lab = lab
	lab._ac02_startup_enrolled = true
	lab._ac02_startup_attempt = attempt
	property._ac02_startup_enrolled = true
	property._ac02_startup_attempt = attempt
	var mesh: BoxMesh = BoxMesh.new()
	var guides: StadiumNpcAc02PublicGuides = StadiumNpcAc02PublicGuides.new()
	var expected_reason: String = ""
	if kind in ["capture", "guide"]:
		# Realize native arrays before listening: a fresh lazy mesh need not emit on edits.
		_check(
			not mesh.surface_get_arrays(0).is_empty(),
			"component native mesh realized before capture " + kind
		)
	match kind:
		"writer":
			expected_reason = "component-supported-writer"
			_check(
				not StadiumNpcAc02IssuedWritersV1.preissue_only(property, expected_reason),
				"component supported writer rejected phase=" + str(phase)
			)
		"capture":
			expected_reason = "captured installation changed"
			mesh.changed.connect(property._installation_changed)
			mesh.size = Vector3(2, 1, 1)
			mesh.changed.disconnect(property._installation_changed)
		"guide":
			expected_reason = "guide-resource-retired"
			guides._property_ref = weakref(property)
			guides._guides = [
				{
					"mesh": mesh,
					"material": StandardMaterial3D.new(),
					"bar": true,
					"mesh_profile": guides._profile(mesh)
				}
			]
			mesh.changed.connect(guides._resource_changed.bind(0, false))
			mesh.size = Vector3(2, 1, 1)
			_check(
				(
					guides._retired
					and attempt.state == ATTEMPT.State.ABORTED
					and attempt.reason == expected_reason
				),
				"component actual guide changed callback retired BEFORE cleanup"
			)
			guides.cleanup_local()
		"close":
			expected_reason = "SeasonApp close during startup"
			_check(
				not app._close_match() and app.lab == lab,
				"component close refused without current-owner disposal"
			)
		"reentry":
			expected_reason = "new match reentered startup"
			lab._match_state = MatchState.new()
			lab._start_new_match()
	_check(
		attempt.state == ATTEMPT.State.ABORTED and attempt.reason == expected_reason,
		"component real retirement latch " + kind + " phase=" + str(phase)
	)
	attempt.abort("second failure")
	_check(
		(
			attempt.reason == expected_reason
			and not attempt.validate_and_publish()
			and not StadiumNpcPublicRuntime.installed(lab)
			and not PitchBatLabFeelSupport._public_export_intact(lab)
			and not StadiumNpcAc02IssuedStateV1.before_settlement(lab)
			and attempt.issue == null
			and lab._active_play_record == null
			and lab._play_records.is_empty()
		),
		"component sticky failure denies publication/export/settlement without issuer or records"
	)
	var view: StadiumNpcAc02PublicVisibility = StadiumNpcAc02PublicVisibility.new()
	_check(
		not view._configure_startup(null, property) and view.property == null,
		"component visibility missing attempt cannot initialize"
	)
	app.lab = null
	property.free()
	lab.free()
	app.free()

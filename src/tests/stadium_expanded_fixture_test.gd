extends Node3D
## Canonical records reject even correctly rehashed edits; public admission stays closed.

var _failures: int = 0


func _ready() -> void:
	var fixture: Dictionary = StadiumExpandedFixtureStudy.capture(
		StadiumExpandedVenueStudy.canonical()
	)
	_check(StadiumExpandedFixtureStudy.valid(fixture), "canonical candidate captures")
	var encoded: String = StadiumExpandedFixtureStudy.encode(fixture)
	_check(
		StadiumExpandedFixtureStudy.encode(StadiumExpandedFixtureStudy.decode(encoded)) == encoded,
		"full-precision JSON roundtrip keeps the exact canonical record"
	)
	_check(
		(
			StadiumExpandedFixtureStudy.decode("{").is_empty()
			and StadiumExpandedFixtureStudy.decode(" ".repeat(65537)).is_empty()
		),
		"bounded decoding"
	)
	for edit in range(12):
		var bad: Dictionary = fixture.duplicate(true)
		match edit:
			0:
				bad.venue.items[0].transform[9] += 0.125
			1:
				bad.venue.items[0].item = "ST-079"
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
				bad.venue.boundary.recipe = "straight"
			9:
				bad.venue.receiver.runtime_net_alias = "foreign"
			10:
				bad.venue.surface.styles = ["ST-063e"]
			11:
				bad.venue.model_sources.stadium_net_models = "foreign"
		bad.sha256 = JSON.stringify(bad.venue, "", true, true).sha256_text()
		_check(not StadiumExpandedFixtureStudy.valid(bad), "rehashed edit rejected " + str(edit))
	_check(not StadiumLayoutSnapshot.valid(fixture), "authoring record is not a human snapshot")
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(not StadiumExpandedLab.install(lab, fixture), "explicit opt-in required")
	lab.set_meta("stadium_expanded_lab_only", true)
	lab._managed_match = true
	_check(not StadiumExpandedLab.install(lab, fixture), "managed fixture cannot opt in")
	lab._managed_match = false
	_check(
		(
			not StadiumExpandedLab.install(lab, {})
			and lab.get_node("StarterFieldGeometry").has_node("BackWall")
			and not lab.has_meta("stadium_property")
		),
		"invalid fixture preserves prior complete scene"
	)
	var staged: StadiumExpandedProperty = StadiumExpandedVenueStudy.build()
	var original_host: Node = lab.get_node("StarterFieldGeometry")
	var original_count: int = original_host.get_child_count()
	var net: Node3D = staged.objects["npc-candidate:AE-01:RECEIVER-CATCH"]
	net.set_meta("owned_copy", "npc-candidate:AE-01:RECEIVER-PRIMARY")
	_check(not staged.prepare_receiver(lab), "real configure_pair rejection is propagated")
	_check(
		(
			not staged.has_node("PitchReceiverPresentation")
			and original_host.has_node("BackWall")
			and original_host.get_child_count() == original_count
			and not lab.has_meta("stadium_property")
			and not lab._pitch_actor.receiver_router.is_valid()
		),
		"failed detached receiver staging leaves original scene and callbacks untouched"
	)
	staged.free()
	lab._automation = MatchAutomation.new()
	_check(not StadiumExpandedLab.install(lab, fixture), "automated startup rejected")
	lab._automation = null
	lab.position.x = 0.0000001
	_check(not StadiumExpandedLab.install(lab, fixture), "transformed startup rejected")
	lab.position.x = 0
	lab._pitch_actor.running = true
	_check(not StadiumExpandedLab.install(lab, fixture), "live delivery rejected")
	lab._pitch_actor.running = false
	remove_child(lab)
	_check(not StadiumExpandedLab.install(lab, fixture), "detached startup rejected")
	add_child(lab)
	var path: String = "user://expanded-fixture-%d.json" % OS.get_process_id()
	_check(StadiumExpandedFixtureStudy.save(path, fixture), "bounded atomic authoring persistence")
	_check(
		ClubCareer.same(StadiumExpandedFixtureStudy.load_file(path), fixture), "exact disk reload"
	)
	DirAccess.remove_absolute(path)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var previous_shot: int = lab._camera_director.shot
	_check(
		StadiumExpandedLab.install(lab, fixture) and not StadiumExpandedLab.install(lab, fixture),
		"canonical fixture installs once"
	)
	_check(lab._camera_director.shot == previous_shot, "paused inspection shot preserved")
	lab._camera_director.restore_after_pause()
	_check(
		lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING,
		"paused role restores after isolated install"
	)
	_check(
		PhysicalMatchReport.capture(lab).is_empty(), "candidate cannot issue a production report"
	)
	_check(
		lab._match_state.stadium.is_empty(), "no human paid history or production fixture assigned"
	)
	_check(lab._pitch_actor.receiver_router.is_valid(), "explicit two-copy receiver installed")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro expanded fixture passed: canonical identity, no promotion and public rejection."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

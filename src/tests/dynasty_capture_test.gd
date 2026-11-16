extends "res://src/tests/dynasty_foundation_test.gd"
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")


func _ready() -> void:
	var base: Dictionary = Lineage.close(Lineage.create(semantic_profile()), "win")
	var advanced: Dictionary = Lineage.advance(
		base, Lineage.request_for(base, "roll:1", 443, overflow_choice())
	)
	check(not advanced.is_empty(), "controlled lineage initialized")
	if advanced.is_empty():
		_finish()
		return
	var lineage: Dictionary = advanced.lineage
	var season: SeasonState = Bridge.create(lineage.start_profile)
	check(season != null, "source79 initial carried season")
	if season == null:
		_finish()
		return
	var initial: Dictionary = SeasonSave.snapshot(season)
	var captured: Dictionary = Lineage.capture_current(lineage, cold(initial))
	check(
		not captured.is_empty() and captured.get("version") == 2,
		"source-replayed capture upgrades explicit lineage v2"
	)
	if captured.is_empty():
		_finish()
		return
	check(
		Lineage.capture_transition_valid(lineage, captured), "bounded exact capture successor valid"
	)
	check(
		Profile.same(Lineage.capture_current(captured, cold(initial)), captured),
		"same source capture idempotent"
	)
	var app: SeasonApp = SeasonApp.new()
	app.season = season
	SeasonSave.path = "user://dynasty-capture-source79.json"
	check(SeasonPregameCommit.save(app), "actual pregame source extension checkpoints")
	var next_source: Dictionary = SeasonSave.snapshot(season)
	var latest: Dictionary = Lineage.capture_current(captured, cold(next_source))
	check(
		not latest.is_empty() and latest.capture.revision > captured.capture.revision,
		"append-only source journal capture accepted"
	)
	if not latest.is_empty():
		check(
			Lineage.capture_transition_valid(captured, latest),
			"capture transition links prior prefix"
		)
		check(
			Lineage.capture_current(latest, cold(initial)).is_empty(),
			"older source cannot undo accepted capture"
		)
		var branch: Dictionary = cold(next_source)
		branch.checkpoint.checkpoint.build.events[-1].id = "alternate-attempt"
		check(
			SeasonSave._decode(branch) != null, "alternate attempt is independently valid source79"
		)
		check(
			Lineage.capture_current(latest, branch).is_empty(),
			"same-length alternate accepted journal rejects as lineage extension"
		)
		var wrong: Dictionary = cold(latest)
		wrong.capture.previous_revision = wrong.capture.revision
		check(
			Lineage.normalize(wrong).is_empty(),
			"nonempty previous prefix requires strict revision advance"
		)
		wrong = cold(latest)
		wrong.current_profile.source.season_key = "%s:1" % wrong.id
		wrong.capture.profile_hash = Lineage.fingerprint(wrong.current_profile)
		check(
			Lineage.normalize(wrong).is_empty(), "current capture source must name current season"
		)
		wrong = cold(latest)
		wrong.current_profile.source.seed += 1
		wrong.capture.profile_hash = Lineage.fingerprint(wrong.current_profile)
		check(Lineage.normalize(wrong).is_empty(), "current capture source seed binds start")
		wrong = cold(latest)
		wrong.current_profile.players[ALEX].trained.contact += 1
		wrong.current_profile.players[ALEX].stats.contact += 1
		check(
			Lineage.normalize(wrong).is_empty(),
			"compact profile hash rejects inconsistent extra growth"
		)
		wrong = cold(latest)
		wrong.version = 1
		wrong.erase("capture")
		check(
			Lineage.normalize(wrong).is_empty(), "v2 capture cannot silently downgrade to inert v1"
		)
		var paused: Dictionary = Lineage.pause(latest)
		check(
			Profile.same(Lineage.resume(paused), latest),
			"pause/resume preserves capture and prefix lock"
		)
		var closed: Dictionary = Lineage.close(latest, "abandon")
		var roll: Dictionary = Lineage.advance(closed, Lineage.request_for(closed, "roll:2", 444))
		check(
			not roll.is_empty() and roll.lineage.ordinal == 3,
			"current captured profile advances once"
		)
		if not roll.is_empty():
			check(
				roll.lineage.version == 1 and not roll.lineage.has("capture"),
				"new season resets capture frontier without carrying old journal"
			)
			check(
				Profile.same(
					(
						Lineage
						. advance(roll.lineage, Lineage.request_for(closed, "roll:2", 444))
						. lineage
					),
					roll.lineage
				),
				"rollover retry exact after source capture"
			)
	app.free()
	_finish()


func _finish() -> void:
	print("Dynasty current capture checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

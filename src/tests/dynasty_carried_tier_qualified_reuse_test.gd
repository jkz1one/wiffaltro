extends "res://src/tests/dynasty_career_tier_test.gd"
## Synthetic title operands and explicit valid D1 authority, never earned play or public admission.
const HomeLive = preload("res://src/gameplay/season/dynasty_carried_home_live.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Reuse = preload("res://src/tests/dynasty_league_qualified_reuse_controls.gd")
func _ready() -> void:
	var source: SeasonState = _origin()
	var origin: Dictionary = SeasonSave.snapshot(source)
	var authority: Dictionary = Authority.create(origin, "tier-owner")
	var grant: Dictionary = Grant.capture(authority)
	var start: Dictionary = Profile.capture_access_season(origin, "tier-lineage", "tier-owner")
	for game in range(12):
		if source.phase == SeasonState.Phase.COMPLETE: break
		var fixture: Dictionary = source.pending_fixture()
		check(source.record_player_result(fixture.id, 0 if fixture.home == 0 else 1,
			1 if fixture.home == 0 else 0), "synthetic prerequisite result only")
	check(source.career.sync(source), "synthetic prerequisite metrics")
	authority = _synthetic_title(authority, source.career.runs[-1], 0)
	if authority.is_empty():
		check(false, "synthetic prerequisite normalizes")
		_finish_tiers()
		return
	start = start.duplicate(true)
	start.access = Authority.access(authority)
	var season: SeasonState = Bridge.create(start, true, 1)
	var session: Dictionary = Save.binding_for(season, "tier-owner", "tier-lineage", 0, 1, "tier-lineage:1")
	var bound: Dictionary = Save.wrap_checkpoint(SeasonSave.snapshot(season), session)
	authority = Authority.open_session(authority, bound)
	check(not authority.is_empty(), "genuine D1 raw replay admitted after synthetic prerequisite")
	if authority.is_empty():
		_finish_tiers()
		return
	var header: Dictionary = {"version": 92, "owner_id": "tier-owner", "owner_revision": 1,
		"owner_reference": Save.snapshot_reference({"synthetic_owner": true}),
		"source_reference": Save.snapshot_reference(bound),
		"lineage": preload("res://src/gameplay/season/dynasty_lineage.gd").create(start),
		"session": session, "grant": grant,
		"home_property": StadiumLayoutSnapshot.capture(ClubPlayers.assets(ClubCareer.from_data(grant.history)), true)}
	var snapshot: Dictionary = header.duplicate(true)
	snapshot["checkpoint"] = bound
	check(HomeLive.header_valid(header, session), "explicit tier92 header valid with earlier frozen asset grant")
	var entry: Dictionary = authority.sessions[session.session_id]
	entry["dynasty_home"] = header
	entry.reference = Save.snapshot_reference(snapshot)
	authority.version = Authority.DYNASTY_HOME_AUTHORITY
	authority = Authority.normalize(authority)
	check(not authority.is_empty(), "synthetic carried D1 authority normalizes without bypass")
	var checked: Dictionary = Authority._qualify_session(authority, session.session_id, snapshot)
	check(not checked.is_empty(), "full carried D1 replay")
	if not checked.is_empty():
		var prior: Dictionary = Authority.checkpoint_session(authority, session.session_id, snapshot)
		check(not prior.is_empty() and Profile.same(prior, Reuse.reuse(authority, session.session_id, snapshot, checked)),
			"tier92 exact full and reused normalized output")
		for version in [83, 84, 86, 92]:
			var bad: Dictionary = snapshot.duplicate(true)
			bad.checkpoint.version = version
			check(Authority.checkpoint_session(authority, session.session_id, bad).is_empty()
				and Reuse.reuse(authority, session.session_id, bad, checked).is_empty(), "tier92 binding downgrade rejects " + str(version))
		var cold: Dictionary = JSON.parse_string(JSON.stringify(snapshot, "", true, true))
		check(not Authority.checkpoint_session(authority, session.session_id, cold).is_empty()
			and Profile.same(prior, Reuse.reuse(authority, session.session_id, cold, checked)), "tier92 JSON reference identity")
	print("CARRIED_TIER_REUSE: %d checks, %d failures, synthetic_history=true, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

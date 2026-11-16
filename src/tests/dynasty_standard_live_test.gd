extends Node
## Synthetic live-grant semantics; no physical earned-source claim.
const Live = preload("res://src/gameplay/season/dynasty_standard_live.gd")
const Proposal = preload("res://src/gameplay/season/dynasty_standard_proposal.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var source: SeasonState = SeasonState.create(40102, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "ordinary origin starts")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "ordinary origin picks")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var authority: Dictionary = Authority.create(origin, "live-owner")
	var dynasty: SeasonState = Bridge.create(Profile.capture_access_season(origin, "live-lineage", "live-owner"))
	var original: Dictionary = Save.wrap_checkpoint(SeasonSave.snapshot(dynasty), Save.binding_for(
		dynasty, "live-owner", "live-lineage", 0, 1, "live-lineage:1"))
	authority = Authority.open_session(authority, original)
	check(not authority.is_empty(), "source-qualified original owner")
	if authority.is_empty():
		_finish()
		return
	var live: Dictionary = authority.duplicate(true)
	live.sessions["live-lineage:1"].contribution.rain_earned = true
	live = Authority.normalize(live)
	check(not live.is_empty(), "synthetic live eligibility contract")
	if live.is_empty():
		_finish()
		return
	check(Authority.validate_snapshot(live, "live-lineage:1", original) == null, "synthetic gains not physical source")
	check(Proposal.prepare(live, 40200, 0).is_empty(), "old projection refuses to drop live grants")
	var before: Dictionary = live.duplicate(true)
	var grant: Dictionary = Grant.capture(live)
	var context: Dictionary = Bound.binding({"owner_id": "live-owner", "lineage_id": "live-lineage",
		"generation": 0, "ordinal": 1, "session_id": "live-standard:1", "seed": 40200,
		"tier": 0, "league": "standard", "format": Bound.LIVE_VERSION, "grant_sha256": Save.snapshot_reference(grant).sha256})
	var season: SeasonState = Live.create(grant, context)
	check(season != null, "grant-aware owned Standard construction")
	if season == null:
		_finish()
		return
	check(season.career == null, "no duplicate sequential wallet")
	check(season.build._rain_start, "live grant installed")
	check(not Authority._history(live).rain_access(), "settled history not fabricated")
	check(not season.home_property.is_empty() and not season.npc_venues.is_empty(), "owned/away venues preserved")
	var raw: Dictionary = Live.capture_raw(season)
	check(not raw.is_empty(), "live Standard raw capture")
	check(SeasonSave._decode(raw) == null, "ordinary decoder cannot authorize live grant")
	var decoded: SeasonState = Live.decode(JSON.parse_string(JSON.stringify(raw, "", true, true)), grant, context)
	check(decoded != null, "explicit live Standard cold decode")
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "grant-aware Standard draft")
	var drafted: Dictionary = Live.capture_raw(season)
	var restored: SeasonState = Live.decode(JSON.parse_string(JSON.stringify(drafted, "", true, true)), grant, context)
	check(restored != null, "four-pick cold decode")
	if restored != null:
		check(restored.picks.size() == 4 and restored.build._rain_start, "draft and live grant survive")
		check(restored.career == null and SeasonVenues.matches_season(restored), "venue context without fake career")
		check(restored.make_match() != null, "grant-aware Standard match model constructs")
		var fork: SeasonState = SeasonRoundSettlement._fork_replayed_standard(restored)
		check(fork != null, "Standard replay-qualified projection fork")
		if fork != null:
			var audit: Node = preload("res://src/tests/pending_validation_fork_test.gd").new()
			audit._audit_isolation(restored, fork, "Standard replay fork", ["physical"])
			checks += audit._checks
			failures += audit._failures
			audit.free()
			check(ClubCareer.same(Live.capture_raw(restored), Live.capture_raw(fork)), "fork preserves settled replay snapshot")
		check(SeasonSave.snapshot(restored).is_empty(), "unadmitted live context still cannot public snapshot")
	var bad: Dictionary = drafted.duplicate(true)
	bad.home_property = {}
	check(Live.decode(bad, grant, context) == null, "changed owned field rejected")
	bad = drafted.duplicate(true)
	bad.career = {}
	check(Live.decode(bad, grant, context) == null, "changed venue witness rejected")
	bad = drafted.duplicate(true)
	bad.build.rain_start = false
	check(Live.decode(bad, grant, context) == null, "missing live grant rejected")
	var envelope: Dictionary = Bound.capture(season, context, grant, live)
	check(not envelope.is_empty(), "live-grant89 envelope captures")
	if not envelope.is_empty():
		var qualified: Dictionary = Bound.qualify(JSON.parse_string(JSON.stringify(envelope, "", true, true)), live)
		check(not qualified.is_empty(), "live-grant89 envelope cold qualifies")
		check(SeasonSave._decode(envelope) == null, "unbound public decoder cannot adopt envelope witness")
		var forged: Dictionary = envelope.duplicate(true)
		forged.version = Bound.VERSION
		check(Bound.qualify(forged, live).is_empty(), "no implicit89 to88 conversion")
		forged = envelope.duplicate(true)
		forged.grant.access.progress.rain_start = false
		check(Bound._qualify_bound(forged, context, grant).is_empty(), "committed witness cannot be replaced")
		forged = envelope.duplicate(true)
		forged.checkpoint.physical.pending = {"unvalidated": true}
		check(Bound.qualify(forged, live).is_empty(), "malformed physical pending fails replay validation")
		var opened: Dictionary = Authority.open_session(live, Bound.capture(Live.create(grant, context), context, grant, live))
		check(not opened.is_empty(), "semantic live89 authority admission")
		if not opened.is_empty():
			var checkpointed: Dictionary = Authority.checkpoint_session(opened, context.session_id, envelope)
			check(not checkpointed.is_empty(), "live89 contribution replaces current session")
			if not checkpointed.is_empty():
				check(Authority.validate_snapshot(checkpointed, context.session_id, envelope) != null, "frozen live89 replay witness")
	check(ClubCareer.same(before, live), "construction/replay does not credit shared owner")
	_finish()
func _finish() -> void:
	print("DYNASTY_STANDARD_LIVE: %d checks, %d failures, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

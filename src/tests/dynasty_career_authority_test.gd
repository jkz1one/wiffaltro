extends Node
## Focused source-qualified enrollment and pause-safe shared authority contracts.
## No physical games, completed-title or naturally earned-growth claims.

const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const LegacyOwner = preload("res://src/gameplay/season/dynasty_owner.gd")
const Progress = preload("res://src/gameplay/season/dynasty_career_progress.gd")
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var source: SeasonState = SeasonState.create(13002, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "ordinary origin starts")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "ordinary origin picks")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var authority: Dictionary = Authority.create(origin, "career-owner")
	check(not authority.is_empty(), "origin fully replays into shared closed prefix")
	var profile: Dictionary = Profile.capture_access_season(origin, "career-lineage", "career-owner")
	var dynasty: SeasonState = Bridge.create(profile)
	check(dynasty != null, "retained roster constructed through original bridge")
	if authority.is_empty() or dynasty == null:
		_finish()
		return
	var raw: Dictionary = SeasonSave.snapshot(dynasty)
	var context: Dictionary = Save.binding_for(dynasty,
		"career-owner", "career-lineage", 0, 1, "career-lineage:1")
	var wrapped: Dictionary = Save.wrap_checkpoint(raw, context)
	check(wrapped.get("version") == 83 and wrapped.checkpoint == raw, "raw80 remains unchanged")
	var restored: SeasonState = SeasonSave._decode(wrapped)
	check(restored != null, "Save83 source qualification")
	if restored == null:
		_finish()
		return
	check(restored.career == null and not restored.league_career,
		"session does not pretend to own a sequential global career")
	check(ClubCareer.same(SeasonSave.snapshot(restored), wrapped), "exact Save83 roundtrip")
	check(not SeasonRoundSettlement._physical_payload(wrapped).is_empty(),
		"round projection locates actual Save83 access80 physical payload")
	check(LegacyOwner._decode(wrapped, true) == null, "legacy owner refuses new wrapper")
	var before: Dictionary = authority.duplicate(true)
	authority = Authority.open_session(authority, wrapped)
	check(not authority.is_empty() and before.sessions.is_empty(),
		"open proposal leaves old value intact")
	if authority.is_empty():
		_finish()
		return
	check(Authority.open_session(authority, wrapped).is_empty(), "duplicate session identity refused")
	check(ClubCareer.same(
		Authority.checkpoint_session(authority, context.session_id, wrapped), authority),
		"same checkpoint replaces nothing and adds no progress")
	check(Authority.view(authority).balance == 0, "unplayed sessions grant no CB")
	for field: String in ["seed", "owner_id", "access_sha256", "ordinal"]:
		var bad: Dictionary = wrapped.duplicate(true)
		bad.session[field] = "wrong"
		check(SeasonSave._decode(bad) == null, "malformed binding refuses " + field)
	var other: SeasonState = SeasonState.create_closed_league(
		13003, LeagueRules.capture("dugout"), true, Authority.access(authority))
	for pick in range(4):
		check(other.choose_player(other.offers()[0]), "other session draft")
	check(SeasonInventoryRules.enable(other), "other inventory contract")
	var other_context: Dictionary = Save.binding_for(other,
		"career-owner", "career-lineage", 0, 1, "career-other:1")
	var other_snapshot: Dictionary = Save.wrap_checkpoint(SeasonSave.snapshot(other), other_context)
	authority = Authority.open_session(authority, other_snapshot)
	check(not authority.is_empty(), "two distinct live owner sessions admitted")
	if authority.is_empty():
		_finish()
		return
	_synthetic_receipt_order(authority, other_snapshot)
	var own_baseline: Dictionary = Authority.session(authority, context.session_id).baseline
	authority = Authority.settle_session(authority, "career-other:1", "abandon", other_snapshot)
	check(not authority.is_empty(), "other closes independently with zero reward")
	if authority.is_empty():
		_finish()
		return
	check(Authority.validate_snapshot(authority, context.session_id, wrapped) != null,
		"resuming old Dynasty snapshot cannot roll global history backward")
	check(Authority.view(authority).history.size() == before.origin.career.runs.size() + 1
		and Authority.view(authority).balance == 0, "other history survives Dynasty resume")
	check(Authority.session(authority, context.session_id).baseline == own_baseline,
		"resume never changes the old session start grant")
	authority = Authority.settle_session(authority, context.session_id, "abandon", wrapped)
	check(not authority.is_empty(), "Dynasty abandon settles without roster deletion")
	if not authority.is_empty():
		check(ClubCareer.same(authority,
			Authority.settle_session(authority, context.session_id, "abandon", wrapped)),
			"same settlement retry credits nothing twice")
		check(Authority.settle_session(authority, context.session_id, "complete", wrapped).is_empty(),
			"abandon cannot be relabeled completed")
		check(Authority.validate_snapshot(authority, context.session_id, wrapped).picks == profile.roster,
			"closed Dynasty exact retained roster still qualifies")
	_finish()


func _synthetic_receipt_order(authority: Dictionary, original_snapshot: Dictionary) -> void:
	# This separately labeled semantic unit does NOT qualify a completed Save83.
	# Only the ordinary legacy score-only route supplies compact score/stat operands.
	var source: SeasonState = SeasonState.create(13003, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "synthetic receipt-unit source starts")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "synthetic receipt-unit draft")
	for game in range(12):
		if source.phase == SeasonState.Phase.COMPLETE:
			break
		var fixture: Dictionary = source.pending_fixture()
		check(source.record_player_result(fixture.id,
			0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0),
			"legacy score-only unit result, not physical source evidence")
	check(source.phase == SeasonState.Phase.COMPLETE and source.career.sync(source),
		"synthetic compact title operands complete")
	if source.phase != SeasonState.Phase.COMPLETE:
		return
	var row: Dictionary = source.career.runs[-1]
	var delta: Dictionary = {"version": Progress.VERSION}
	for field: String in Progress.FIELDS:
		if field != "version":
			delta[field] = row[field]
	for flag: String in Progress.FLAGS:
		delta[flag + "_earned"] = row[flag + "_earned"]
	delta = delta.duplicate(true)
	delta.proof["version"] = ClubSeasonRecord.LEAGUE_VERSION
	delta.proof["league_rules"] = LeagueRules.capture("dugout")
	var candidate: Dictionary = authority.duplicate(true)
	var entry: Dictionary = candidate.sessions["career-other:1"]
	check(Progress.valid(delta, entry.baseline), "synthetic incremental metric contract")
	entry.contribution = delta
	entry.settled = 1
	var receipt: Dictionary = ClubSeasonRecord.receipt(delta.proof, true)
	candidate.settlements.append({"session_id": "career-other:1", "reason": "complete",
		"receipt": receipt})
	candidate.pennants.eras[str(candidate.origin.career.runs.size() + 1)] = entry.era
	var validated: Dictionary = Authority.normalize(candidate)
	check(not validated.is_empty() and receipt.first_bonus == 25,
		"semantic canonical first title includes one bonus")
	if validated.is_empty():
		return
	check(Authority.validate_snapshot(validated, "career-other:1", original_snapshot) == null,
		"synthetic completed operands are NOT the original live source")
	var repeat: Dictionary = entry.duplicate(true)
	repeat.session.session_id = "career-other:2"
	repeat.settled = 2
	candidate.sessions["career-other:2"] = repeat
	var repeated: Dictionary = ClubSeasonRecord.receipt(delta.proof, false)
	candidate.settlements.append({"session_id": "career-other:2", "reason": "complete",
		"receipt": repeated})
	candidate.pennants.eras[str(candidate.origin.career.runs.size() + 2)] = repeat.era
	validated = Authority.normalize(candidate)
	check(not validated.is_empty() and repeated.first_bonus == 0,
		"semantic canonical second same-League title has no first bonus")
	if not validated.is_empty():
		check(Authority.view(validated).balance == receipt.total + repeated.total,
			"semantic shared CB equals each unique settlement once")


func _finish() -> void:
	print("Dynasty career authority checks: %d, failures: %d, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

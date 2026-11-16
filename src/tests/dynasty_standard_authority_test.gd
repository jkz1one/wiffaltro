extends Node
const Proposal = preload("res://src/gameplay/season/dynasty_standard_proposal.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Closed = preload("res://src/gameplay/season/dynasty_career_save.gd")
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
	var source: SeasonState = SeasonState.create(37102, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "origin starts")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin picks")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var authority: Dictionary = Authority.create(origin, "standard-owner")
	var dynasty: SeasonState = Bridge.create(Profile.capture_access_season(origin, "standard-lineage", "standard-owner"))
	var dynasty_context: Dictionary = Closed.binding_for(dynasty, "standard-owner", "standard-lineage", 0, 1, "standard-lineage:1")
	var dynasty_snapshot: Dictionary = Closed.wrap_checkpoint(SeasonSave.snapshot(dynasty), dynasty_context)
	authority = Authority.open_session(authority, dynasty_snapshot)
	check(not authority.is_empty(), "real paused Dynasty opens")
	if authority.is_empty():
		_finish()
		return
	var admission: Dictionary = authority.duplicate(true)
	var grant: Dictionary = Grant.capture(admission)
	var proposal: Dictionary = Proposal.prepare(admission, 37200, 0)
	check(not proposal.is_empty(), "Standard proposal prepares beside Dynasty")
	if proposal.is_empty():
		_finish()
		return
	var season: SeasonState = SeasonSave._decode(proposal.snapshot)
	var context: Dictionary = Bound.binding_for(season, grant, "standard-owner", "standard-lineage", 0, 1, "standard-other:1")
	var wrapped: Dictionary = Bound.capture(season, context, grant, admission)
	check(not wrapped.is_empty(), "Standard bound snapshot")
	authority = Authority.open_session(authority, wrapped)
	check(not authority.is_empty(), "Standard owner authority admission")
	if authority.is_empty():
		_finish()
		return
	check(authority.version == Authority.STANDARD_VERSION, "explicit authority31")
	check(Authority.open_session(authority, wrapped).is_empty(), "duplicate Standard admission rejected")
	check(Authority.validate_snapshot(authority, context.session_id, wrapped) != null, "owner validates exact Standard snapshot")
	check(Authority.validate_snapshot(authority, dynasty_context.session_id, dynasty_snapshot) != null, "paused Dynasty still validates")
	check(Authority.view(authority).balance == Authority.view(admission).balance, "admission cannot duplicate wallet")
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "Standard draft")
	var drafted: Dictionary = Bound.capture(season, context, grant, admission)
	authority = Authority.checkpoint_session(authority, context.session_id, drafted)
	check(not authority.is_empty(), "draft checkpoint updates unique contribution")
	if authority.is_empty():
		_finish()
		return
	check(Authority.validate_snapshot(authority, context.session_id, wrapped) == null, "old Standard checkpoint stale")
	check(Authority.validate_snapshot(authority, context.session_id, drafted).picks.size() == 4, "new snapshot exact")
	check(ClubCareer.same(Authority.checkpoint_session(authority, context.session_id, drafted), authority), "retry unchanged checkpoint idempotent")
	var cold: Dictionary = Authority.normalize(JSON.parse_string(JSON.stringify(authority, "", true, true)))
	check(not cold.is_empty(), "authority JSON cold normalization")
	check(Authority.validate_snapshot(cold, context.session_id, drafted) != null, "cold historical grant replay")
	authority = Authority.settle_session(cold, context.session_id, "abandon", drafted)
	check(not authority.is_empty(), "abandon Standard independently")
	if authority.is_empty():
		_finish()
		return
	check(Authority.view(authority).history.size() == Authority.view(admission).history.size() + 1, "one Standard row, no copied history")
	check(Authority.view(authority).balance == Authority.view(admission).balance, "abandon pays nothing")
	check(ClubCareer.same(authority, Authority.settle_session(authority, context.session_id, "abandon", drafted)), "settlement retry exactly idempotent")
	check(Authority.settle_session(authority, context.session_id, "complete", drafted).is_empty(), "abandon cannot relabel complete")
	check(Authority.validate_snapshot(authority, dynasty_context.session_id, dynasty_snapshot) != null, "Dynasty survives Standard settlement")
	check(Authority._history(authority).runs[-1].league == "standard", "ordinary Standard history identity")
	check(not authority.sessions[context.session_id].contribution.has("assets"), "no embedded wallet imported")
	_finish()
func _finish() -> void:
	print("DYNASTY_STANDARD_AUTHORITY: %d checks, %d failures, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

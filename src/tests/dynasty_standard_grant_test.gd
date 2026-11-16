extends Node
## Synthetic witness semantics only. No physical source/owner admission claim.
const Proposal = preload("res://src/gameplay/season/dynasty_standard_proposal.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
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
	var source: SeasonState = SeasonState.create(34102, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "ordinary origin starts")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "ordinary origin picks")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var authority: Dictionary = Authority.create(origin, "grant-owner")
	var profile: Dictionary = Profile.capture_access_season(origin, "grant-lineage", "grant-owner")
	var dynasty: SeasonState = Bridge.create(profile)
	check(not authority.is_empty() and dynasty != null, "source-qualified baseline")
	if authority.is_empty() or dynasty == null:
		_finish()
		return
	var context: Dictionary = Save.binding_for(dynasty, "grant-owner", "grant-lineage", 0, 1, "grant-lineage:1")
	var snapshot: Dictionary = Save.wrap_checkpoint(SeasonSave.snapshot(dynasty), context)
	authority = Authority.open_session(authority, snapshot)
	check(not authority.is_empty(), "paused live session opens")
	if authority.is_empty():
		_finish()
		return
	var before: Dictionary = authority.duplicate(true)
	var witness: Dictionary = Grant.capture(authority)
	check(not witness.is_empty(), "grant captures")
	check(not Grant.qualify(witness, authority).is_empty(), "exact source qualifies")
	check(not Grant.qualify(JSON.parse_string(JSON.stringify(witness, "", true, true)), authority).is_empty(), "JSON witness qualifies")
	check(Grant.qualify(witness, {}).is_empty(), "witness cannot self-authorize")
	var proposal: Dictionary = Proposal.prepare(authority, 34200, 0)
	check(not proposal.is_empty(), "Standard fresh proposal")
	if not proposal.is_empty():
		var standard: SeasonState = SeasonSave._decode(proposal.snapshot)
		check(Grant.matches_start(standard, witness, authority), "pristine Standard start matches actual grant")
		standard.build._rain_start = not standard.build._rain_start
		check(not Grant.matches_start(standard, witness, authority), "modified Standard start refused")
	for field: String in ["authority_reference", "history_reference", "assets_reference"]:
		var bad: Dictionary = witness.duplicate(true)
		bad[field].sha256 = "0".repeat(64)
		check(Grant.qualify(bad, authority).is_empty(), "forged " + field + " rejected")
	var bad: Dictionary = witness.duplicate(true)
	bad.access.progress.rain_start = not bad.access.progress.rain_start
	check(Grant.qualify(bad, authority).is_empty(), "forged eligibility rejected")
	bad = witness.duplicate(true)
	bad.owner_id = "other-owner"
	check(Grant.qualify(bad, authority).is_empty(), "cross-owner rejected")
	bad = witness.duplicate(true)
	bad.version = 1.5
	check(Grant.qualify(bad, authority).is_empty(), "fractional version rejected")
	# Semantic fixture changes a compact live contribution, not its physical
	# source snapshot. It must NOT be presented as a qualified runtime checkpoint.
	var live: Dictionary = authority.duplicate(true)
	live.sessions[context.session_id].contribution.rain_earned = true
	live = Authority.normalize(live)
	check(not live.is_empty(), "synthetic live-gain authority semantics valid")
	if not live.is_empty():
		var expanded: Dictionary = Grant.capture(live)
		check(expanded.access.progress.rain_start, "live eligibility retained")
		check(not Authority._history(live).rain_access(), "no fabricated sequential gain row")
		check(ClubCareer.same(expanded.history_reference, witness.history_reference), "live gain leaves settled history unchanged")
		check(ClubCareer.same(expanded.assets_reference, witness.assets_reference), "live gain does not mint assets")
		check(Grant.qualify(witness, live).is_empty(), "old witness stale for new admission")
		check(not Grant.qualify(witness, authority).is_empty(), "old witness valid with exact historical authority")
		check(Grant.qualify(expanded, authority).is_empty(), "new gains cannot leak into old session")
		check(Authority.validate_snapshot(live, context.session_id, snapshot) == null, "synthetic fixture is not physical checkpoint")
	check(ClubCareer.same(before, authority), "all witness operations preserve source authority")
	_finish()
func _finish() -> void:
	print("DYNASTY_STANDARD_GRANT: %d checks, %d failures, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

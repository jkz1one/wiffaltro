extends Node
const Proposal = preload("res://src/gameplay/season/dynasty_standard_proposal.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Closed = preload("res://src/gameplay/season/dynasty_career_save.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var source: SeasonState = SeasonState.create(36102, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "origin starts")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin picks")
	var authority: Dictionary = Authority.create(SeasonSave.snapshot(source), "save-owner")
	var grant: Dictionary = Grant.capture(authority)
	var proposal: Dictionary = Proposal.prepare(authority, 36200, 0)
	check(not proposal.is_empty(), "Standard proposal prepares")
	if proposal.is_empty():
		_finish()
		return
	var before: Dictionary = authority.duplicate(true)
	var season: SeasonState = SeasonSave._decode(proposal.snapshot)
	var context: Dictionary = Bound.binding_for(season, grant, "save-owner", "save-lineage", 0, 1, "standard:1")
	var wrapped: Dictionary = Bound.capture(season, context, grant, authority)
	check(not wrapped.is_empty(), "explicit bound Standard envelope")
	if wrapped.is_empty():
		_finish()
		return
	check(SeasonSave._decode(wrapped) == null, "public dispatcher remains gated")
	check(Closed.qualify(wrapped).is_empty(), "closed session decoder refuses Standard envelope")
	check(Bound.qualify(wrapped, {}).is_empty(), "bound envelope cannot self-authorize")
	var cold: Dictionary = Bound.qualify(JSON.parse_string(JSON.stringify(wrapped, "", true, true)), authority)
	check(not cold.is_empty(), "full JSON envelope cold qualification")
	if not cold.is_empty():
		check(ClubCareer.same(cold.reference, Closed.snapshot_reference(wrapped)), "cold reference stable")
		check(not cold.season.home_property.is_empty() and not cold.season.npc_venues.is_empty(), "cold owned/away fields retained")
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "bound candidate draft")
	var drafted: Dictionary = Bound.capture(season, context, grant, authority)
	check(not drafted.is_empty(), "drafted envelope captures")
	if not drafted.is_empty():
		var restored: Dictionary = Bound.qualify(JSON.parse_string(JSON.stringify(drafted, "", true, true)), authority)
		check(not restored.is_empty() and restored.season.picks.size() == 4, "drafted cold resume")
	for field: String in ["seed", "tier", "owner_id", "generation", "grant_sha256"]:
		var bad: Dictionary = wrapped.duplicate(true)
		bad.session[field] = "wrong"
		check(Bound.qualify(bad, authority).is_empty(), "malformed session " + field)
	var bad: Dictionary = wrapped.duplicate(true)
	bad.session.tier = 4
	check(Bound.qualify(bad, authority).is_empty(), "tier rebinding rejected")
	bad = wrapped.duplicate(true)
	bad.session.owner_id = "other-owner"
	check(Bound.qualify(bad, authority).is_empty(), "cross-owner rejected")
	bad = wrapped.duplicate(true)
	bad.checkpoint = wrapped
	check(Bound.qualify(bad, authority).is_empty(), "recursive envelope rejected")
	bad = wrapped.duplicate(true)
	bad.grant.access.progress.rain_start = not bad.grant.access.progress.rain_start
	check(Bound.qualify(bad, authority).is_empty(), "forged grant rejected")
	for malformed: Variant in ["88", true, null, 88.5]:
		bad = wrapped.duplicate(true)
		bad.version = malformed
		check(Bound.qualify(bad, authority).is_empty(), "malformed outer version rejected")
		bad = wrapped.duplicate(true)
		bad.checkpoint.version = malformed
		check(Bound.qualify(bad, authority).is_empty(), "malformed raw version rejected")
	check(ClubCareer.same(authority, before), "capture/restore cannot mutate shared owner")
	_finish()
func _finish() -> void:
	print("DYNASTY_STANDARD_SAVE: %d checks, %d failures, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

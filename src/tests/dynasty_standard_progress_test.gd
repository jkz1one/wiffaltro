extends Node
const Proposal = preload("res://src/gameplay/season/dynasty_standard_proposal.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Delta = preload("res://src/gameplay/season/dynasty_standard_progress.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var source: SeasonState = SeasonState.create(35102, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "origin starts")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin picks")
	var authority: Dictionary = Authority.create(SeasonSave.snapshot(source), "progress-owner")
	var grant: Dictionary = Grant.capture(authority)
	var proposal: Dictionary = Proposal.prepare(authority, 35200, 0)
	check(not proposal.is_empty(), "Standard proposal prepares")
	if proposal.is_empty():
		_finish()
		return
	var before: Dictionary = authority.duplicate(true)
	var season: SeasonState = SeasonSave._decode(proposal.snapshot)
	var initial: Dictionary = Delta.capture(season, grant, authority)
	check(not initial.is_empty(), "unplayed Standard delta qualifies")
	if initial.is_empty():
		_finish()
		return
	check(not initial.proof.has("league_rules"), "Standard proof remains ordinary")
	check(not initial.has("assets") and not initial.has("receipt") and not initial.has("history"), "delta cannot import wallet or earlier rows")
	check(Delta.receipt(initial, grant, authority, true).is_empty(), "unplayed season earns no receipt")
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "Standard draft picks")
	var after: Dictionary = Delta.capture(season, grant, authority)
	check(not after.is_empty(), "post-draft contribution")
	check(Delta.extends_progress(initial, after, grant, authority), "draft extends same proof")
	check(Delta.valid(JSON.parse_string(JSON.stringify(after, "", true, true)), grant, authority), "JSON delta valid")
	var bad: Dictionary = after.duplicate(true)
	bad.proof["version"] = 2
	bad.proof["league_rules"] = LeagueRules.capture("standard")
	check(not Delta.valid(bad, grant, authority), "closed Standard proof cannot masquerade as ordinary")
	bad = after.duplicate(true)
	bad.tier = 0.5
	check(not Delta.valid(bad, grant, authority), "fractional tier rejected")
	bad = after.duplicate(true)
	bad.tier = 4
	check(not Delta.valid(bad, grant, authority), "locked tier receipt rejected")
	bad = after.duplicate(true)
	bad.grant_reference.sha256 = "0".repeat(64)
	check(not Delta.valid(bad, grant, authority), "wrong grant rejected")
	bad = after.duplicate(true)
	bad["assets"] = authority.assets
	check(not Delta.valid(bad, grant, authority), "wallet injection rejected")
	check(Delta.capture(source, grant, authority).is_empty(), "unrelated career prefix rejected")
	check(ClubCareer.same(before, authority), "capture cannot credit owner")
	_finish()
func _finish() -> void:
	print("DYNASTY_STANDARD_PROGRESS: %d checks, %d failures, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

extends Node
const Proposal = preload("res://src/gameplay/season/dynasty_standard_proposal.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var source: SeasonState = SeasonState.create(33102, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "origin starts")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin picks")
	var authority: Dictionary = Authority.create(SeasonSave.snapshot(source), "proposal-owner")
	check(not authority.is_empty(), "authority created")
	var before: Dictionary = authority.duplicate(true)
	var proposal: Dictionary = Proposal.prepare(authority, 33200, 0)
	check(not proposal.is_empty(), "Base owned Standard proposal prepares")
	if not proposal.is_empty():
		var season: SeasonState = SeasonSave._decode(proposal.snapshot)
		check(season != null, "proposal decodes with original validators")
		check(not season.home_property.is_empty(), "owned stadium retained")
		check(not season.npc_venues.is_empty(), "away parks retained")
		check(not season.final_venue.is_empty(), "Standard final retained")
		check(season.career.active_tier() == 0, "original tier authority retained")
		check(Proposal.current(authority, proposal), "exact proposal revalidates")
		check(Proposal.current(authority, JSON.parse_string(JSON.stringify(proposal, "", true, true))), "JSON proposal revalidates")
		check(Save.qualify(proposal.snapshot).is_empty(), "ordinary proposal is NOT owner admission")
		for pick in range(4):
			check(season.choose_player(season.offers()[0]), "Standard proposal draft")
		var replay: SeasonState = SeasonSave._decode(SeasonSave.snapshot(season))
		check(replay != null and replay.picks.size() == 4, "original draft save roundtrip")
		var bad: Dictionary = proposal.duplicate(true)
		bad.seed += 1
		check(not Proposal.current(authority, bad), "altered seed rejected")
		bad = proposal.duplicate(true)
		bad.tier = 0.5
		check(not Proposal.current(authority, bad), "fractional tier rejected")
		bad = proposal.duplicate(true)
		bad.authority_reference.sha256 = "0".repeat(64)
		check(not Proposal.current(authority, bad), "stale authority rejected")
	for tier in range(1, 5):
		check(Proposal.prepare(authority, 33200, tier).is_empty(), "locked tier rejected")
	check(Proposal.prepare({}, 33200, 0).is_empty(), "invalid owner rejected")
	check(Proposal.prepare(authority, -1, 0).is_empty(), "invalid seed rejected")
	check(ClubCareer.same(before, authority), "owner untouched by all proposals")
	print("DYNASTY_STANDARD_PROPOSAL: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

extends "res://src/tests/league_tier_career_test.gd"
## Frozen owned-pool replay, not physical completion. Higher-tier title prefixes
## are explicitly synthetic, as in the inherited focused tier test.

const Owned = preload("res://src/gameplay/season/league_owned_draft_save.gd")
const Shared = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Bound = preload("res://src/gameplay/season/dynasty_career_save.gd")


func _ready() -> void:
	for bad: Variant in [null, [], "invalid"]:
		check(Owned.unpack(bad).is_empty(), "mistyped owned wrapper refuses without dereference")
	for league: String in ClubLeagueCareer.IDS:
		for tier: int in [0, 2, 4]:
			_owned_roundtrip(league, tier)
	_large_pool_refusals()
	print("League owned draft checks: %d, failures: %d, synthetic_history=true, physical_games=0"
		% [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _owned_roundtrip(league: String, tier: int) -> void:
	var club: ClubCareer = UnlockFixture.for_league(league) if tier == 0 else _prefix(league, tier - 1)
	if club == null:
		check(false, "synthetic tier prefix validates")
		return
	var owned: Array[String] = ClubPlayers.owned(club)
	var season: SeasonState = SeasonState.create_closed_league(8107,
		LeagueRules.capture_tier(league, tier, 8107 if league == "scramble" else null), true)
	check(season != null and ClubPlayerDraft.apply(season, owned), "freeze owned before entry")
	if season == null or season.player_access.is_empty():
		return
	check(club.start_league(season), "owned-pool League career starts")
	if season.career == null:
		return
	if tier == 0 and league == "dugout":
		check(owned.size() == 12, "fresh club has exact authored twelve starters")
	_roundtrip_owned(season)
	for pick in range(4):
		check(season.offers().all(func(id: String) -> bool: return id in owned),
			"offers never widen ownership")
		check(season.choose_player(season.offers()[0]), "actual owned draft pick")
	check(season.opponents.clubs.size() == 5, "full NPC allocation after fourth pick")
	var available: Array[String] = ClubPlayerDraft.opponents(season)
	check(available.size() == 44, "NPC pool is full forty-eight minus human four")
	var scramble: Dictionary = season.league_rules if league == "scramble" else {}
	var expected: Dictionary = (
		SeasonOpponentDraft.allocate_d2(8107, available, scramble) if tier >= 2
		else SeasonOpponentDraft.allocate(8107, available, scramble))
	check(not expected.is_empty(), "captured full-pool AI allocation remains feasible")
	if not expected.is_empty():
		for team in range(1, 6):
			check(season.teams[team].roster == expected.rosters[team], "exact full-pool NPC roster")
	check(SeasonInventoryRules.enable(season), "owned live inventory enable")
	_roundtrip_owned(season)


func _roundtrip_owned(season: SeasonState) -> void:
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	check(snapshot.get("version") == 87 and snapshot.checkpoint.get("version") == 81,
		"explicit owned87 outside full career81")
	var loaded: SeasonState = SeasonSave._decode(snapshot)
	check(loaded != null, "owned initial/fourth-pick cold decode")
	if loaded != null:
		check(ClubCareer.same(SeasonSave.snapshot(loaded), snapshot), "exact owned save roundtrip")
	check(SeasonSave._decode(snapshot.checkpoint) == null, "stripping owned wrapper rejects")
	check(not SeasonRoundSettlement._physical_payload(snapshot).is_empty(),
		"physical lookup retains complete owned wrapper for final decode")
	var bad: Dictionary = snapshot.duplicate(true)
	Owned.closed(bad.checkpoint).owned_draft = "wrong"
	check(SeasonSave._decode(bad) == null, "mismatched closed marker refuses")
	bad = snapshot.duplicate(true)
	bad.player_access.reverse()
	check(SeasonSave._decode(bad) == null, "unsorted owned access refuses")
	bad = snapshot.duplicate(true)
	bad.checkpoint = snapshot
	check(SeasonSave._decode(bad) == null, "nested owned envelope refuses")


func _large_pool_refusals() -> void:
	var origin: SeasonState = _new("dugout")
	if origin == null:
		return
	var authority: Dictionary = Shared.create(SeasonSave.snapshot(origin), "owned-owner")
	check(not authority.is_empty(), "shared source origin validates")
	if authority.is_empty():
		return
	var all: Array[String] = SeasonPlayerCatalog.ids()
	for count: int in [24, 48]:
		# Deliberately unowned extra cards, for stripping/entitlement refusal only.
		var players: Array[String] = ClubPlayerCatalog.initial_owned()
		for id: String in all:
			if players.size() == count:
				break
			if id not in players:
				players.append(id)
		players.sort()
		var season: SeasonState = SeasonState.create_closed_league(8108,
			LeagueRules.capture("dugout"), true, Shared.access(authority))
		check(ClubPlayerDraft.apply(season, players), "explicit malformed entitlement fixture")
		for ready: bool in [false, true]:
			if ready:
				for pick in range(4):
					check(season.choose_player(season.offers()[0]), "large pool fixture fourth pick")
				check(SeasonInventoryRules.enable(season), "large pool fixture inventory")
			var setup: Dictionary = SeasonSave.snapshot(season)
			check(SeasonSave._decode(setup) == null, "unbound raw87 is setup-only")
			check(SeasonSave._decode(setup.checkpoint) == null,
				"stripped marker rejects even twenty-four/full forty-eight pool")
			var context: Dictionary = Bound.binding_for(season, "owned-owner", "owned-lineage",
				0, 1, "owned-other:1")
			var bound: Dictionary = Bound.wrap_checkpoint(setup, context)
			check(not Bound.qualify(bound).is_empty(), "full explicit structural source replay")
			check(Shared.open_session(authority, bound).is_empty(),
				"global owner refuses unearned cards even in replay-valid source")

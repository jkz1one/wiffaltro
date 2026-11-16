extends Node
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	print("LIVE_REPLAY_CHECK ", label, " ", ok)
	if not ok:
		failures += 1
func _ready() -> void:
	for league: String in ["sponsorship", "academy", "equipment", "earnings", "doubleheader", "scramble"]:
		_run(league)
	print("BASE_HOME_REPLAY: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _run(league: String) -> void:
	var source: SeasonState = SeasonState.create(97001, false, true, true)
	source.career = preload("res://src/tests/league_unlock_fixture.gd").prefix([
		{"league": "standard", "tier": 0}, {"league": "sponsorship", "tier": 0},
		{"league": "sponsorship", "tier": 1}, {"league": "sponsorship", "tier": 2},
		{"league": "dugout", "tier": 0}, {"league": "equipment", "tier": 0}])
	source.career.start(source)
	for index in range(4): source.choose_player(source.offers()[0])
	var authority: Dictionary = Authority.create(SeasonSave.snapshot(source), "live-home-owner")
	var access: Dictionary = Authority.access(authority)
	var session: Dictionary = Save.binding({"owner_id": "live-home-owner", "lineage_id": "live-home-lineage",
		"generation": 0, "ordinal": 1, "session_id": "live-home:1", "seed": 97002,
		"tier": 0, "league": league, "access_sha256": ClosedContentAccess.digest(access)})
	var snapshot: Dictionary = Live.prepare(authority, session)
	check(not snapshot.is_empty(), league + " qualified live proposal")
	if not snapshot.is_empty():
		var checked: Dictionary = Live.qualify(snapshot, authority)
		var season: SeasonState = checked.get("season")
		check(season != null, "live decode")
		if season != null:
			for index in range(4): check(season.choose_player(season.offers()[0]), "live draft")
			check(SeasonInventoryRules.enable(season), "inventory enabled")
			var saved: Dictionary = Live.capture(season)
			check(not saved.is_empty(), "live capture")
			var restored: Dictionary = Live.qualify(JSON.parse_string(JSON.stringify(saved, "", true, true)), authority)
			check(not restored.is_empty() and restored.season.picks == season.picks, "JSON replay")
			season._dynasty_career_session.session_id = "foreign-live"
			check(not Live.matches(season), "live session substitution refused")
			check(Live.capture(season).is_empty(), "changed live session capture refused")
			season._dynasty_career_session = session.duplicate(true)
			var bad: Dictionary = saved.duplicate(true)
			bad.session.session_id = "foreign"
			check(Live.qualify(bad, authority).is_empty(), "session substitution refused")
			for old_version: int in [75, 76 if league == "doubleheader" else 77]:
				bad = saved.duplicate(true)
				bad.checkpoint.checkpoint.checkpoint.checkpoint.version = old_version
				check(Live.qualify(bad, authority).is_empty(), "historical closed version substitution refused")
			season.physical.pending = {"human": [0, 1, 0, {}, [], [], {}, [], [], {}, {}, [], {}, [], ""],
				"reports": [], "unrecognized": true}
			check(not SeasonRoundSettlement._pending_shape(season), "extra pending key refused")
			season.physical.pending = {}


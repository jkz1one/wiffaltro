extends RefCounted
## Dedicated staged92 envelope. Not accepted by historical saves/public playback.
## Preserve carried source access/build; current assets are a separate frozen grant.
const VERSION: int = 92
const Owner = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Home = preload("res://src/gameplay/season/dynasty_league_home_save.gd")

static func prepare(value: Dictionary, source: Dictionary) -> Dictionary:
	var owner: Dictionary = Owner.normalize(value)
	if owner.is_empty() or owner.selected != "dynasty" or owner.lineage.state != "active" \
		or not ClubCareer.same(Save.snapshot_reference(source), owner.dynasty.reference):
		return {}
	var season: SeasonState = Owner.validate_selected(owner, source)
	var checked: Dictionary = Save.qualify(source)
	if season == null or checked.is_empty() or not Home.prephysical(season) \
		or not LeagueRules.dynasty(season.league_rules) or season.picks.size() != 4 \
		or season.phase != SeasonState.Phase.REGULAR \
		or not ClubCareer.same(season._dynasty_start, owner.lineage.start_profile) \
		or not ClubCareer.same(checked.session, season._dynasty_career_session) \
		or checked.session.session_id != owner.dynasty.session_id \
		or checked.session.generation != owner.lineage.generation:
		return {}
	var grant: Dictionary = Grant.capture(owner.career)
	if grant.is_empty():
		return {}
	var paid: ClubAssetLedger = ClubPlayers.assets(preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(grant.history))
	var home: Dictionary = StadiumLayoutSnapshot.capture(paid, true) if paid != null else {}
	if home.is_empty() or not StadiumLayoutSnapshot.matches(home, paid):
		return {}
	return {"version": VERSION, "owner_id": owner.owner_id, "owner_revision": owner.revision,
		"owner_reference": Save.snapshot_reference(owner), "source_reference": owner.dynasty.reference.duplicate(true),
		"lineage": owner.lineage.duplicate(true), "session": checked.session.duplicate(true),
		"grant": grant, "home_property": home, "checkpoint": source.duplicate(true)}

static func qualify(value: Variant, owner: Dictionary) -> Dictionary:
	if not Profile.keys(value, ["version", "owner_id", "owner_revision", "owner_reference",
		"source_reference", "lineage", "session", "grant", "home_property", "checkpoint"]) \
		or not Profile.whole(value.version, VERSION, VERSION) or not value.checkpoint is Dictionary:
		return {}
	var expected: Dictionary = prepare(owner, value.checkpoint)
	if expected.is_empty() or not ClubCareer.same(value, expected):
		return {}
	var checked: Dictionary = Save.qualify(value.checkpoint)
	if checked.is_empty():
		return {}
	# Prephysical-only staging may install a frozen home after source replay.
	# Future played replay must inject this before results, under a new adapter.
	checked.season.home_property = value.home_property.duplicate(true)
	checked.season._league_home_context = {"format": VERSION, "session": value.session.duplicate(true),
		"grant": value.grant.duplicate(true), "home_property": value.home_property.duplicate(true)}
	checked["proposal"] = expected
	return checked


static func prepare_create(payload: Dictionary) -> Dictionary:
	# A canonical detached old-create projection supplies source identity. No
	# historical owner is committed or exposed between review and the92 commit.
	if not payload.get("snapshot") is Dictionary or payload.snapshot.get("version") == VERSION:
		return {}
	var request: Dictionary = {"op": "create", "request_id": "create:" + Owner.Legacy.fingerprint(payload),
		"expected_revision": 0, "payload": payload.duplicate(true)}
	var projected: Dictionary = Owner.project({}, request)
	if projected.is_empty(): return {}
	var proposal: Dictionary = prepare(projected.owner, payload.snapshot)
	if proposal.is_empty() or load("res://src/gameplay/season/dynasty_carried_home_live.gd").qualify(
		proposal, load("res://src/gameplay/season/dynasty_carried_home_live.gd").header(proposal)).is_empty(): return {}
	var result: Dictionary = payload.duplicate(true)
	result.snapshot = proposal
	return result

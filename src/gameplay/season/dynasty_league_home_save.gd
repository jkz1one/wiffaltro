extends RefCounted
## Save90: explicit, owner-qualified alternate home envelope. Pre-physical stage.
## No historical checkpoint accepts venue fields. Played/pending games fail shut
## until combined league/inventory/stadium report replay is implemented.
const VERSION: int = 90
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Proposal = preload("res://src/gameplay/season/dynasty_league_home_proposal.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")


static func prepare(authority: Dictionary, context: Dictionary) -> Dictionary:
	var session: Dictionary = Save.binding(context)
	if session.is_empty() or session.league not in Proposal.LEAGUES:
		return {}
	var proposal: Dictionary = Proposal.prepare(authority, session.league, session.seed, session.tier)
	if proposal.is_empty() or session.owner_id != proposal.grant.owner_id \
		or session.access_sha256 != ClosedContentAccess.digest(proposal.grant.access):
		return {}
	var inner: Dictionary = Save.wrap_checkpoint(proposal.checkpoint, session)
	var value: Dictionary = {"version": VERSION, "session": session, "grant": proposal.grant,
		"home_property": proposal.home_property, "checkpoint": inner}
	return value if not qualify(value, authority).is_empty() else {}


static func qualify(value: Variant, authority: Dictionary) -> Dictionary:
	if value is Dictionary and Profile.whole(value.get("version"), 91, 91):
		return load("res://src/gameplay/season/dynasty_league_home_live.gd").qualify(value, authority)
	if not value is Dictionary or not value.get("home_property") is Dictionary:
		return {}
	var grant: Dictionary = Grant.qualify(value.get("grant"), authority)
	var checked: Dictionary = Save.qualify(value.get("checkpoint"))
	if grant.is_empty() or checked.is_empty():
		return {}
	return _qualify_bound(value, checked.session, grant, value.get("home_property", {}))


static func _qualify_bound(value: Variant, session: Dictionary, grant: Dictionary, home: Dictionary, expected_format: int = VERSION) -> Dictionary:
	if expected_format == 91:
		return load("res://src/gameplay/season/dynasty_league_home_live.gd").qualify_bound(value, session, grant, home)
	if expected_format != VERSION:
		return {}
	if not Profile.keys(value, ["version", "session", "grant", "home_property", "checkpoint"]) \
		or not Profile.whole(value.version, VERSION, VERSION) \
		or not value.checkpoint is Dictionary or not value.home_property is Dictionary \
		or Save.snapshot_reference(value).bytes > 8 * 1024 * 1024 \
		or not ClubCareer.same(value.session, session) \
		or not ClubCareer.same(value.grant, grant) or not ClubCareer.same(value.home_property, home):
		return {}
	var witness: Dictionary = Grant._claim(grant)
	var checked: Dictionary = Save.qualify(value.checkpoint)
	if witness.is_empty() or checked.is_empty() or not ClubCareer.same(checked.session, session) \
		or session.league not in Proposal.LEAGUES or session.owner_id != witness.owner_id \
		or session.access_sha256 != ClosedContentAccess.digest(witness.access):
		return {}
	var season: SeasonState = checked.season
	if not prephysical(season) or not ClubCareer.same(season.player_access, witness.player_access) \
		or not ClubCareer.same(season._closed_access, witness.access):
		return {}
	var paid: ClubAssetLedger = ClubPlayers.assets(preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(witness.history))
	if paid == null or not ClubCareer.same(home, StadiumLayoutSnapshot.capture(paid, true)):
		return {}
	# The closed replay above has no games. This explicit envelope installs its
	# qualified venue before any future physical work, never after played replay.
	season.home_property = home.duplicate(true)
	season._league_home_context = {"grant": witness.duplicate(true), "home_property": home.duplicate(true)}
	checked["home_grant"] = witness
	checked["home_property"] = home.duplicate(true)
	checked.reference = Save.snapshot_reference(value)
	return checked


static func prephysical(season: SeasonState) -> bool:
	return season != null and season.results.is_empty() and season.player_results.is_empty() \
		and season.physical != null and season.physical.reports.is_empty() \
		and season.physical.pending.is_empty() and season.physical.cursor == 0 \
		and season.npc_venues.is_empty() and season.final_venue.is_empty() \
		and season.owned_surface_night.is_empty()


static func capture(season: SeasonState) -> Dictionary:
	if season != null and season._league_home_context.get("format") == 92:
		return load("res://src/gameplay/season/dynasty_carried_home_live.gd").capture(season)
	if season != null and season._league_home_context.get("format") == 91:
		return load("res://src/gameplay/season/dynasty_league_home_live.gd").capture(season)
	if not prephysical(season) or season._league_home_context.is_empty():
		return {}
	var context: Dictionary = season._league_home_context
	if not Profile.keys(context, ["grant", "home_property"]) \
		or not context.grant is Dictionary or not context.home_property is Dictionary \
		or not ClubCareer.same(season.home_property, context.home_property):
		return {}
	var detached: SeasonState = SeasonState.new()
	for property: Dictionary in season.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			detached.set(property.name, season.get(property.name))
	detached.home_property = {}
	detached._league_home_context = {}
	var inner: Dictionary = Save.capture(detached)
	var value: Dictionary = {"version": VERSION, "session": season._dynasty_career_session.duplicate(true),
		"grant": context.grant.duplicate(true),
		"home_property": context.home_property.duplicate(true), "checkpoint": inner}
	return value if not _qualify_bound(value, season._dynasty_career_session,
		context.grant, context.home_property).is_empty() else {}


static func decode_current(value: Dictionary) -> SeasonState:
	if not SeasonSave.dynasty_owner_bound():
		return null
	var found: Dictionary = SeasonSave.DYNASTY_OWNER_STORE.inspect(SeasonSave._dynasty_owner_path)
	var owner: Dictionary = found.get("owner", {})
	if found.get("status") not in ["ready", "recoverable"] or owner.get("version") != 2:
		return null
	var slot: Dictionary = owner.get(str(owner.get("selected", "")), {})
	var entry: Dictionary = owner.get("career", {}).get("sessions", {}).get(slot.get("session_id", ""), {})
	if not entry.has("league_home_grant"):
		return null
	return _qualify_bound(value, entry.session, entry.league_home_grant, entry.home_property, int(entry.get("home_format", VERSION))).get("season")

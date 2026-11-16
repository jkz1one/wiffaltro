extends RefCounted
## Owner-bound shared history. Live sessions are NOT sequential Career27 rows.
## Latest unique session contributions are replaced, never cumulatively re-added.
# gdlint: disable=max-returns

const VERSION: int = 28
const TIER_VERSION: int = 29
const OWNED_VERSION: int = 30
const STANDARD_VERSION: int = 31
const LEAGUE_HOME_VERSION: int = 32
const LEAGUE_HOME_LIVE_AUTHORITY: int = 33
const DYNASTY_HOME_AUTHORITY: int = 34
const TIME_ALTERNATE_AUTHORITY: int = 35
const TIME_CARRIED_AUTHORITY: int = 36
const LEAGUE_HOME_LIVE_SAVE: int = 91
const LEAGUE_HOME_SAVE_VERSION: int = 90
const STANDARD_SAVE_VERSION: int = 88
const STANDARD_LIVE_SAVE_VERSION: int = 89
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Progress = preload("res://src/gameplay/season/dynasty_career_progress.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Unlocks = preload("res://src/gameplay/season/league_unlocks.gd")


static func create(origin_snapshot: Dictionary, owner_id: String) -> Dictionary:
	if not Profile.token(owner_id):
		return {}
	var origin: Dictionary = JSON.parse_string(JSON.stringify(origin_snapshot, "", true, true))
	var season: SeasonState = SeasonSave._decode(origin)
	if season == null or season.career == null or not season.career.matches(season):
		return {}
	var club: ClubCareer = season.career.fork()
	if not club.close(season):
		return {}
	var start: Dictionary = ClosedContentAccess._capture_checked(club, origin, owner_id)
	var imported: Dictionary = club.to_data()
	if start.is_empty() or imported.get("assets") == null:
		return {}
	return normalize({"version": VERSION, "owner_id": owner_id,
		"origin": {"career": imported, "access": start, "reference": Save.snapshot_reference(origin)},
		"sessions": {}, "settlements": [], "assets": imported.assets.duplicate(true),
		"plaques": imported.get("plaques", {}).duplicate(true),
		"pennants": imported.get("pennants", {}).duplicate(true)})


static func normalize(value: Variant) -> Dictionary:
	if (
		not Profile.keys(value, ["version", "owner_id", "origin", "sessions", "settlements", "assets",
			"plaques", "pennants"])
		or not Profile.whole(value.version, VERSION, TIME_CARRIED_AUTHORITY) or not Profile.token(value.owner_id)
		or not Profile.keys(value.origin, ["career", "access", "reference"])
		or not value.sessions is Dictionary or not value.settlements is Array
		or not value.assets is Dictionary or not value.plaques is Dictionary
		or not value.pennants is Dictionary
		or value.sessions.size() > ClubCareer.MAX_RUNS
		or value.settlements.size() > value.sessions.size()
	):
		return {}
	var imported: ClubCareer = ClubCareer.from_data(value.origin.career)
	var origin: Dictionary = ClosedContentAccess.normalize(value.origin.access)
	if (
		imported == null or imported.current != 0 or origin.is_empty()
		or origin.owner_id != value.owner_id or not _reference_valid(value.origin.reference)
		or origin.source.sha256 != value.origin.reference.sha256
		or imported.runs.size() + value.sessions.size() > ClubCareer.MAX_RUNS
		or not ClubCareer.same(origin.progress, _origin_progress(imported, origin))
	):
		return {}
	var has_tier: bool = false
	var has_owned: bool = false
	var has_standard: bool = false
	var has_home: bool = false
	var has_live_home: bool = false
	var has_dynasty_home: bool = false
	var has_time_alternate: bool = false
	var has_time_carried: bool = false
	for id: Variant in value.sessions:
		var entry: Variant = value.sessions[id]
		if not id is String or not _entry_valid(entry, id, origin, value.settlements.size()):
			return {}
		has_time_alternate = has_time_alternate or entry.get("time_home", {}).get("version") == 95
		has_time_carried = has_time_carried or entry.get("time_home", {}).get("version") == 96
		has_tier = has_tier or entry.session.tier > 0
		has_owned = has_owned or entry.has("player_access")
		has_standard = has_standard or entry.has("standard_grant")
		has_home = has_home or entry.has("league_home_grant")
		has_dynasty_home = has_dynasty_home or entry.has("dynasty_home")
		has_live_home = has_live_home or entry.get("home_format") == LEAGUE_HOME_LIVE_SAVE
	if value.version != (TIME_CARRIED_AUTHORITY if has_time_carried else TIME_ALTERNATE_AUTHORITY if has_time_alternate else DYNASTY_HOME_AUTHORITY if has_dynasty_home else (LEAGUE_HOME_LIVE_AUTHORITY if has_live_home else (LEAGUE_HOME_VERSION if has_home else (STANDARD_VERSION if has_standard else
		(OWNED_VERSION if has_owned else (TIER_VERSION if has_tier else VERSION)))))):
		return {}
	var seen: Array[String] = []
	var titles: Dictionary = imported._title_history()
	for index in range(value.settlements.size()):
		var settled: Variant = value.settlements[index]
		if (
			not Profile.keys(settled, ["session_id", "reason", "receipt"])
			or not settled.session_id is String or settled.session_id in seen
			or not value.sessions.has(settled.session_id) or settled.reason not in ["complete", "abandon"]
			or not settled.receipt is Dictionary
		):
			return {}
		seen.append(settled.session_id)
		var entry: Dictionary = value.sessions[settled.session_id]
		var summary: Dictionary = ClubSeasonRecord.analyze(entry.contribution.proof)
		var key: String = _title_key(entry.session)
		var receipt: Dictionary = {}
		if settled.reason == "complete":
			receipt = ClubSeasonRecord.receipt(entry.contribution.proof,
				not titles.get(key, false), int(entry.session.tier))
			if receipt.is_empty():
				return {}
			if summary.finish == "champion":
				titles[key] = true
		elif summary.finish != "unfinished":
			return {}
		if entry.settled != index + 1 or not ClubCareer.same(receipt, settled.receipt):
			return {}
	for id: String in value.sessions:
		if (value.sessions[id].settled != 0) != (id in seen):
			return {}
		if not _tier_admitted(value, value.sessions[id], imported._title_history()):
			return {}
	var result: Dictionary = value.duplicate(true)
	var club: ClubCareer = _history(result)
	var ledger: ClubAssetLedger = ClubPlayers.assets(club)
	if not ClubCareer.same(club._pennants, result.pennants) \
		or ledger == null or not StadiumPennantRewards.delivered(club, ledger) \
		or not StadiumPlaqueRewards.delivered(club, ledger):
		return {}
	if has_owned:
		var owned: Array = _player_view(result).get("owned", [])
		for entry: Dictionary in result.sessions.values():
			for id: String in entry.get("player_access", []):
				if id not in owned:
					return {}
	return result


static func _origin_progress(club: ClubCareer, origin: Dictionary) -> Dictionary:
	# Source hash remains immutable. Only extract the validated imported prefix's counters.
	return ClosedContentAccess._capture_checked(club, {}, origin.owner_id).get("progress", {})


static func _reference_valid(value: Variant) -> bool:
	return Profile.keys(value, ["sha256", "bytes"]) \
		and ClosedContentAccess._digest_valid(value.sha256) \
		and Profile.whole(value.bytes, 1, 8 * 1024 * 1024)


static func _entry_valid(entry: Variant, id: String, origin: Dictionary, count: int) -> bool:
	var fields: Array = ["session", "baseline", "reference", "contribution",
		"settled", "era", "admission_frontier"]
	if entry is Dictionary and entry.has("player_access"):
		fields.append("player_access")
		if not ClubPlayerCatalog.valid_ids(entry.player_access):
			return false
	if entry is Dictionary and entry.has("standard_grant"):
		fields.append("standard_grant")
	if entry is Dictionary and entry.has("league_home_grant"):
		if entry.has("standard_grant"):
			return false
		fields.append_array(["league_home_grant", "home_property"])
		if entry.has("home_format"):
			fields.append("home_format")
			if not Save.Owned.version_in(entry.home_format, [LEAGUE_HOME_LIVE_SAVE, 95]) \
					or (entry.home_format == 95 and not entry.has("time_home")):
				return false
	if entry is Dictionary and entry.has("dynasty_home"):
		fields.append("dynasty_home")
		if entry.has("league_home_grant") or entry.has("standard_grant") \
			or not load("res://src/gameplay/season/dynasty_carried_home_live.gd").header_valid(entry.dynasty_home, Save.binding(entry.get("session"))):
			return false
	if entry is Dictionary and entry.has("time_home"):
		fields.append("time_home")
		if not load("res://src/gameplay/season/dynasty_shared_time_authority.gd").entry_valid(entry): return false
	if not Profile.keys(entry, fields):
		return false
	if entry is Dictionary and entry.has("standard_grant"):
		return _standard_entry_valid(entry, id, origin, count)
	if entry.has("league_home_grant") and not _league_home_entry(entry):
		return false
	var context: Dictionary = Save.binding(entry.session)
	var baseline: Dictionary = ClosedContentAccess.normalize(entry.baseline)
	if (
		context.is_empty() or context.session_id != id or context.owner_id != origin.owner_id
		or (entry.has("player_access") and context.league == "dynasty")
		or baseline.is_empty() or not ClosedContentAccess.same_origin(baseline, origin)
		or context.access_sha256 != ClosedContentAccess.digest(baseline)
		or not _reference_valid(entry.reference) or not Profile.whole(entry.settled, 0, count)
		or not StadiumClubIdentity.valid(entry.era) or not entry.admission_frontier is Dictionary
		or not Progress.valid(entry.contribution, baseline)
		or entry.contribution.proof.league_rules.league != context.league
		or entry.contribution.proof.league_rules.tier != context.tier
		or not LeagueRules.season_matches(entry.contribution.proof.league_rules, context.seed)
	):
		return false
	for key: Variant in entry.admission_frontier:
		if not key is String or not Profile.token(key) \
			or not _reference_valid(entry.admission_frontier[key]):
			return false
	return true


static func session(value: Dictionary, id: String) -> Dictionary:
	var authority: Dictionary = normalize(value)
	return authority.get("sessions", {}).get(id, {}).duplicate(true)


static func access(value: Dictionary) -> Dictionary:
	var authority: Dictionary = normalize(value)
	return {} if authority.is_empty() else _access(authority)


static func _access(authority: Dictionary) -> Dictionary:
	var contributions: Array = []
	var ids: Array = authority.sessions.keys()
	ids.sort()
	for id: String in ids:
		var entry: Dictionary = authority.sessions[id]
		if not entry.has("standard_grant"):
			contributions.append({"baseline": entry.baseline, "progress": entry.contribution})
	var result: Dictionary = Progress.access(authority.origin.access, contributions).duplicate(true)
	if result.is_empty():
		return {}
	for id: String in ids:
		if authority.sessions[id].has("standard_grant"):
			Progress._fold(result.progress, authority.sessions[id].contribution)
	return ClosedContentAccess.normalize(result)


# Deterministic projection also replays already-persisted pre-policy intents.
# Fresh public requests are gated by the owner Store before intent publication.
static func open_session(value: Dictionary, snapshot: Dictionary) -> Dictionary:
	if Save.Owned.version_in(snapshot.get("version"), [95]):
		return load("res://src/gameplay/season/dynasty_shared_time_authority.gd").open_alternate(value, snapshot)
	if Save.Owned.version_in(snapshot.get("version"), [LEAGUE_HOME_SAVE_VERSION, LEAGUE_HOME_LIVE_SAVE]):
		return _open_league_home(value, snapshot)
	if Save.Owned.version_in(snapshot.get("version"), [STANDARD_SAVE_VERSION, STANDARD_LIVE_SAVE_VERSION]):
		return _open_standard(value, snapshot)
	var authority: Dictionary = normalize(value)
	var checked: Dictionary = Save.qualify(snapshot)
	if authority.is_empty() or checked.is_empty():
		return {}
	var context: Dictionary = checked.session
	var season: SeasonState = checked.season
	if (
		authority.sessions.has(context.session_id) or context.owner_id != authority.owner_id
		or context.tier not in available_tiers(authority, context.league)
		or not _fresh(season)
		or not ClubCareer.same(season._closed_access, _access(authority))
		or (not season.player_access.is_empty()
			and not ClubCareer.same(season.player_access, _player_view(authority).get("owned")))
		or (authority.version >= OWNED_VERSION and context.league != "dynasty"
			and season.player_access.is_empty())
	):
		return {}
	for entry: Dictionary in authority.sessions.values():
		if entry.settled == 0 and ((entry.session.league == "dynasty") == (context.league == "dynasty")):
			return {}  # At most one unfinished session in each durable owner slot.
	var progress: Dictionary = Progress.capture(season)
	if progress.is_empty():
		return {}
	var frontier: Dictionary = {}
	for id: String in authority.sessions:
		frontier[id] = authority.sessions[id].reference.duplicate(true)
	authority.sessions[context.session_id] = {"session": context,
		"baseline": season._closed_access.duplicate(true), "reference": checked.reference,
		"contribution": progress, "settled": 0, "era": StadiumClubIdentity.current(),
		"admission_frontier": frontier}
	if not season.player_access.is_empty():
		authority.sessions[context.session_id]["player_access"] = season.player_access.duplicate()
		authority.version = maxi(int(authority.version), OWNED_VERSION)
	elif context.tier > 0 and authority.version < TIER_VERSION:
		authority.version = TIER_VERSION
	return normalize(authority)


static func available_leagues(value: Dictionary) -> Array[String]:
	var authority: Dictionary = normalize(value)
	return [] if authority.is_empty() else Unlocks.from_titles(_history(authority)._title_history())


static func available_tiers(value: Dictionary, league: String) -> Array[int]:
	var authority: Dictionary = normalize(value)
	if authority.is_empty() or LeagueRules.capture(league,
		0, 0 if league == "scramble" else null).is_empty():
		return []
	var result: Array[int] = [0]
	var titles: Dictionary = _history(authority)._title_history()
	for tier in range(1, 5):
		if not titles.get(_title_key({"league": league, "tier": tier - 1}), false):
			break
		result.append(tier)
	return result


static func _tier_admitted(authority: Dictionary, entry: Dictionary, imported: Dictionary) -> bool:
	if entry.session.tier == 0:
		return true
	var key: String = _title_key({"league": entry.session.league, "tier": entry.session.tier - 1})
	if imported.get(key, false):
		return true
	for settled: Dictionary in authority.settlements:
		var prior: Dictionary = authority.sessions[settled.session_id]
		if settled.reason != "complete" or _title_key(prior.session) != key \
			or (entry.settled > 0 and prior.settled >= entry.settled):
			continue
		if ClubCareer.same(entry.admission_frontier.get(settled.session_id), prior.reference) \
			and ClubSeasonRecord.analyze(prior.contribution.proof).get("finish") == "champion":
			return true
	return false


static func _fresh(season: SeasonState) -> bool:
	if not season.results.is_empty() or season.physical == null \
		or not season.physical.pending.is_empty() or not season.physical.reports.is_empty():
		return false
	var builds: Array[SeasonBuild] = [season.build]
	for club: Dictionary in season.opponents.clubs.values():
		builds.append(club.build)
	var expected: Array = []
	if not season.inventory_rules.is_empty():
		expected.append({"id": "inventory-rules-v1", "rev": 0,
			"op": SeasonInventoryResale.ENABLE_OP})
	for build: SeasonBuild in builds:
		if not ClubCareer.same(build._events, expected) \
			or not ClubCareer.same(build._bank._events, expected) \
			or int(build._visit.number) != 0 or build._visit.get("open", false) \
			or not build._bank.view().rewards.is_empty():
			return false
	return true


static func checkpoint_session(value: Dictionary, id: String, snapshot: Dictionary) -> Dictionary:
	var authority: Dictionary = normalize(value)
	var checked: Dictionary = _qualify_session(authority, id, snapshot)
	return _checkpoint_checked(authority, id, checked)


# Internal synchronous reuse only: OwnerV2._qualified supplies its direct result
# from _qualify_session, before any yield or mutation. Never a public admission
# route or a serialized/cached witness. The public checkpoint above still fully
# qualifies independently. Retain normalization and exact operand binding here.
static func _checkpoint_standard_checked(
	value: Dictionary, id: String, snapshot: Dictionary, checked: Dictionary
) -> Dictionary:
	var authority: Dictionary = normalize(value)
	var entry: Dictionary = authority.get("sessions", {}).get(id, {})
	if not SeasonOwnership._whole(snapshot.get("version"), STANDARD_LIVE_SAVE_VERSION, STANDARD_LIVE_SAVE_VERSION) \
		or not checked.has("grant") or not checked.get("inner") is Dictionary \
		or not entry.has("standard_grant") \
		or not Profile.same(checked.get("grant"), entry.standard_grant) \
		or not Profile.same(checked.get("session"), entry.session) \
		or not Profile.same(checked.get("reference"), Save.snapshot_reference(snapshot)) \
		or not Profile.same(checked.get("raw_reference"), Save.snapshot_reference(checked.inner)) \
		or not Profile.same(snapshot.get("checkpoint"), checked.inner):
		return {}
	return _checkpoint_checked(authority, id, checked)


# Same direct-result lifetime as _checkpoint_standard_checked. This is the
# explicit91 owned/bound envelope, not Standard's raw checkpoint layout. Keep
# the supplied qualified grant (including its history format) intact.
static func _checkpoint_league_home_checked(
	value: Dictionary, id: String, snapshot: Dictionary, checked: Dictionary
) -> Dictionary:
	var authority: Dictionary = normalize(value)
	var entry: Dictionary = authority.get("sessions", {}).get(id, {})
	if not Profile.keys(snapshot, ["version", "session", "grant", "home_property", "checkpoint"]) \
		or not Profile.whole(snapshot.version, LEAGUE_HOME_LIVE_SAVE, LEAGUE_HOME_LIVE_SAVE) \
		or not snapshot.checkpoint is Dictionary or not checked.get("inner") is Dictionary \
		or entry.get("home_format") != LEAGUE_HOME_LIVE_SAVE \
		or not entry.has("league_home_grant") or not entry.has("home_property") \
		or not Profile.same(snapshot.session, entry.session) \
		or not Profile.same(checked.get("session"), entry.session) \
		or not Profile.same(snapshot.grant, entry.league_home_grant) \
		or not Profile.same(checked.get("home_grant"), entry.league_home_grant) \
		or not Profile.same(snapshot.home_property, entry.home_property) \
		or not Profile.same(checked.get("home_property"), entry.home_property) \
		or not Profile.same(checked.get("reference"), Save.snapshot_reference(snapshot)) \
		or not Profile.same(checked.get("raw_reference"), Save.snapshot_reference(checked.inner)):
		return {}
	var live = load("res://src/gameplay/season/dynasty_league_home_live.gd")
	if not Profile.same(checked.inner, live.unbound(snapshot.checkpoint, entry.session)):
		return {}
	return _checkpoint_checked(authority, id, checked)


# Explicit92 carries a complete immutable header and an unowned83/85 bound
# checkpoint. Never reuse across a yield, mutation, operation or disk read.
static func _checkpoint_dynasty_home_checked(
	value: Dictionary, id: String, snapshot: Dictionary, checked: Dictionary
) -> Dictionary:
	var authority: Dictionary = normalize(value)
	var entry: Dictionary = authority.get("sessions", {}).get(id, {})
	var live = load("res://src/gameplay/season/dynasty_carried_home_live.gd")
	if not Profile.whole(snapshot.get("version"), live.VERSION, live.VERSION) \
		or not snapshot.get("checkpoint") is Dictionary or not checked.get("inner") is Dictionary \
		or not entry.has("dynasty_home") \
		or not Profile.same(live.header(snapshot), entry.dynasty_home) \
		or not Profile.same(checked.get("dynasty_home"), entry.dynasty_home) \
		or not Profile.same(checked.get("session"), entry.session) \
		or not Profile.same(checked.get("reference"), Save.snapshot_reference(snapshot)) \
		or not Profile.same(checked.get("raw_reference"), Save.snapshot_reference(checked.inner)):
		return {}
	var bound: Dictionary = snapshot.checkpoint
	var version: int = Save.TIER_VERSION if int(entry.session.tier) > 0 else Save.VERSION
	if not Profile.keys(bound, ["version", "session", "checkpoint"]) \
		or not Profile.whole(bound.version, version, version) \
		or not Profile.same(bound.session, entry.session) \
		or not Profile.same(bound.checkpoint, checked.inner):
		return {}
	return _checkpoint_checked(authority, id, checked)


static func _checkpoint_checked(authority: Dictionary, id: String, checked: Dictionary) -> Dictionary:
	if authority.is_empty() or checked.is_empty() or not authority.sessions.has(id):
		return {}
	var entry: Dictionary = authority.sessions[id]
	if not ClubCareer.same(entry.session, checked.session) \
		or not ClubCareer.same(entry.get("player_access", []), checked.season.player_access) \
		or not ClubCareer.same(entry.baseline, _checked_baseline(checked)):
		return {}
	if entry.settled != 0:
		return authority if ClubCareer.same(entry.reference, checked.reference) else {}
	var progress: Dictionary = checked.get("contribution", {}) if entry.has("standard_grant") else Progress.capture(checked.season)
	if progress.is_empty() or not _proof_extends(entry.contribution.proof, progress.proof):
		return {}
	entry.contribution = progress
	entry.reference = checked.reference
	return normalize(authority)


static func _proof_extends(before: Dictionary, after: Dictionary) -> bool:
	return ClubCareer.same(before.draws, after.draws) \
		and ClubCareer.same(before.get("league_rules", {}), after.get("league_rules", {})) \
		and before.scores.size() <= after.scores.size() \
		and ClubCareer.same(before.scores, after.scores.slice(0, before.scores.size()))


static func settle_session(
	value: Dictionary, id: String, reason: String, snapshot: Dictionary
) -> Dictionary:
	if reason not in ["complete", "abandon"]:
		return {}
	var authority: Dictionary = checkpoint_session(value, id, snapshot)
	if authority.is_empty():
		return {}
	var entry: Dictionary = authority.sessions[id]
	if entry.settled > 0:
		return authority if authority.settlements[int(entry.settled) - 1].reason == reason else {}
	var club: ClubCareer = _history(authority)
	var summary: Dictionary = ClubSeasonRecord.analyze(entry.contribution.proof)
	var receipt: Dictionary = {}
	if reason == "complete":
		receipt = ClubSeasonRecord.receipt(entry.contribution.proof,
			not club._title_history().get(_title_key(entry.session), false), int(entry.session.tier))
		if receipt.is_empty():
			return {}
	elif summary.finish != "unfinished":
		return {}
	entry.settled = authority.settlements.size() + 1
	authority.settlements.append({"session_id": id, "reason": reason, "receipt": receipt})
	club = _history(authority)
	# Capture prospective shared achievements at this canonical settlement boundary.
	club.current = club.runs.size()
	StadiumPennantRewards.adopt(club)
	club._pennants.eras[str(club.current)] = entry.era.duplicate(true)
	StadiumPlaqueRewards.adopt(club)
	if not StadiumPlaqueRewards.capture(club):
		return {}
	club.current = 0
	if not StadiumPennantRewards.deliver(club) or not StadiumPlaqueRewards.deliver(club):
		return {}
	authority.assets = club._assets.duplicate(true)
	authority.plaques = club._plaques.duplicate(true)
	authority.pennants = club._pennants.duplicate(true)
	return normalize(authority)


static func validate_snapshot(value: Dictionary, id: String, snapshot: Dictionary) -> SeasonState:
	var authority: Dictionary = normalize(value)
	var checked: Dictionary = _qualify_session(authority, id, snapshot)
	if authority.is_empty() or checked.is_empty() or not authority.sessions.has(id):
		return null
	var entry: Dictionary = authority.sessions[id]
	if not ClubCareer.same(entry.session, checked.session) \
		or not ClubCareer.same(entry.get("player_access", []), checked.season.player_access) \
		or not ClubCareer.same(entry.reference, checked.reference) \
		or not ClubCareer.same(entry.baseline, _checked_baseline(checked)) \
		or not ClubCareer.same(entry.contribution, checked.get("contribution", {})
			if entry.has("standard_grant") else Progress.capture(checked.season)):
		return null
	return checked.season


static func _title_key(context: Dictionary) -> String:
	return str(int(context.tier)) if context.league == "standard" else "%s:%d" % [
		context.league, context.tier]


static func _history(authority: Dictionary) -> ClubCareer:
	var club: ClubCareer = ClubCareer.from_data(authority.origin.career)
	club._pennants = authority.pennants.duplicate(true)
	for settled: Dictionary in authority.settlements:
		var entry: Dictionary = authority.sessions[settled.session_id]
		var row: Dictionary = entry.contribution.duplicate(true)
		row.erase("version")
		row.erase("grant_reference")
		row.merge({"id": club.runs.size() + 1, "seed": entry.session.seed,
			"league": entry.session.league, "tier": entry.session.tier,
			"status": "completed" if settled.reason == "complete" else "abandoned",
			"receipt": settled.receipt.duplicate(true)})
		if row.league == "standard":
			row.proof.erase("version")
			row.proof.erase("league_rules")
		else:
			row["league_rules"] = row.proof.league_rules.duplicate(true)
			if row.league == "dynasty":
				row["dynasty_session"] = entry.session.duplicate(true)
		club.runs.append(row)
		if not club._pennants.is_empty():
			club._pennants.eras[str(row.id)] = entry.era.duplicate(true)
	club._assets = authority.assets.duplicate(true)
	club._plaques = authority.plaques.duplicate(true)
	return club


static func view(value: Dictionary) -> Dictionary:
	var authority: Dictionary = normalize(value)
	if authority.is_empty():
		return {}
	var club: ClubCareer = _history(authority)
	return {"balance": club.balance(), "history": club.runs.duplicate(true),
		"access": _access(authority), "sessions": authority.sessions.duplicate(true)}


static func player_view(value: Dictionary) -> Dictionary:
	var authority: Dictionary = normalize(value)
	if authority.is_empty():
		return {}
	return _player_view(authority)


static func _player_view(authority: Dictionary) -> Dictionary:
	var club: ClubCareer = _history(authority)
	var ledger: ClubAssetLedger = ClubPlayers.assets(club)
	if ledger == null:
		return {}
	# Metrics consume each latest session exactly once. This is not a fabricated
	# sequential career or an abandonment of a paused season.
	var records: Array = authority.origin.career.runs.duplicate(true)
	for entry: Dictionary in authority.sessions.values():
		var record: Dictionary = entry.contribution.duplicate(true)
		record["status"] = "active" if entry.settled == 0 else (
			"completed" if authority.settlements[entry.settled - 1].reason == "complete"
			else "abandoned")
		records.append(record)
	var metrics: Dictionary = ClubPlayerProgress.metrics(records)
	return {"owned": ledger.owned(ClubPlayerCatalog.earned(metrics)), "metrics": metrics,
		"ledger": ledger.view(), "through": ClubPlayers.income_through(club)}


static func player_command(value: Dictionary, command: Dictionary) -> Dictionary:
	var authority: Dictionary = normalize(value)
	if authority.is_empty() or command.get("op") not in ["player_pack_open", "player_pack_pick"]:
		return {"authority": {}, "applied": ClubAssetLedger._error("Invalid player transaction.")}
	var club: ClubCareer = _history(authority)
	var applied: Dictionary = ClubPlayers.command(club, command)
	if not applied.ok:
		return {"authority": {}, "applied": applied}
	authority.assets = club._assets.duplicate(true)
	var result: Dictionary = normalize(authority)
	if result.is_empty():
		return {"authority": {}, "applied": ClubAssetLedger._error("Player ledger did not validate.")}
	return {"authority": result, "applied": applied}


static func _standard_save() -> GDScript:
	return load("res://src/gameplay/season/dynasty_standard_save.gd")


static func _standard_grant() -> GDScript:
	return load("res://src/gameplay/season/dynasty_standard_grant.gd")


static func _standard_progress() -> GDScript:
	return load("res://src/gameplay/season/dynasty_standard_progress.gd")


static func _standard_entry_valid(entry: Dictionary, id: String, origin: Dictionary, count: int) -> bool:
	var context: Dictionary = _standard_save().binding(entry.session)
	var grant: Dictionary = _standard_grant()._claim(entry.standard_grant)
	var baseline: Dictionary = ClosedContentAccess.normalize(entry.baseline)
	if context.is_empty() or grant.is_empty() or baseline.is_empty() \
		or context.session_id != id or context.owner_id != origin.owner_id \
		or grant.owner_id != origin.owner_id \
		or context.grant_sha256 != Save.snapshot_reference(grant).sha256 \
		or not ClosedContentAccess.same_origin(baseline, origin) \
		or not ClubCareer.same(baseline, grant.access) \
		or not ClubCareer.same(entry.get("player_access"), grant.player_access) \
		or not _reference_valid(entry.reference) or not Profile.whole(entry.settled, 0, count) \
		or not StadiumClubIdentity.valid(entry.era) or not entry.admission_frontier is Dictionary \
		or not _standard_progress()._valid_bound(entry.contribution, grant) \
		or entry.contribution.tier != context.tier:
		return false
	for key: Variant in entry.admission_frontier:
		if not key is String or not Profile.token(key) or not _reference_valid(entry.admission_frontier[key]):
			return false
	return true


static func _open_standard(value: Dictionary, snapshot: Dictionary) -> Dictionary:
	var authority: Dictionary = normalize(value)
	if authority.is_empty():
		return {}
	var checked: Dictionary = _standard_save().qualify(snapshot, authority)
	if checked.is_empty():
		return {}
	var context: Dictionary = checked.session
	if context.owner_id != authority.owner_id or authority.sessions.has(context.session_id) \
		or context.tier not in available_tiers(authority, "standard") or not _fresh(checked.season):
		return {}
	for entry: Dictionary in authority.sessions.values():
		if entry.settled == 0 and entry.session.league != "dynasty":
			return {}
	var frontier: Dictionary = {}
	for id: String in authority.sessions:
		frontier[id] = authority.sessions[id].reference.duplicate(true)
	authority.sessions[context.session_id] = {"session": context,
		"baseline": checked.grant.access.duplicate(true), "reference": checked.reference,
		"contribution": checked.contribution, "settled": 0, "era": StadiumClubIdentity.current(),
		"admission_frontier": frontier, "player_access": checked.grant.player_access.duplicate(),
		"standard_grant": checked.grant.duplicate(true)}
	authority.version = maxi(int(authority.version), STANDARD_VERSION)
	return normalize(authority)


static func _qualify_session(authority: Dictionary, id: String, snapshot: Dictionary) -> Dictionary:
	var entry: Dictionary = authority.get("sessions", {}).get(id, {})
	if entry.has("time_home"):
		return load("res://src/gameplay/season/dynasty_shared_time.gd").qualify(snapshot, entry.time_home)
	if entry.has("dynasty_home"):
		return load("res://src/gameplay/season/dynasty_carried_home_live.gd").qualify(snapshot, entry.dynasty_home)
	if entry.has("league_home_grant"):
		return _league_home_save()._qualify_bound(snapshot, entry.session, entry.league_home_grant, entry.home_property, int(entry.get("home_format", LEAGUE_HOME_SAVE_VERSION)))
	if entry.has("standard_grant"):
		return _standard_save()._qualify_bound(snapshot, entry.session, entry.standard_grant)
	return Save.qualify(snapshot)


static func _checked_baseline(checked: Dictionary) -> Dictionary:
	return checked.grant.access if checked.has("grant") else checked.season._closed_access


static func _league_home_save() -> GDScript:
	return load("res://src/gameplay/season/dynasty_league_home_save.gd")


static func _league_home_entry(entry: Dictionary) -> bool:
	if entry.has("standard_grant") or not entry.has("player_access"):
		return false
	var grant: Dictionary = _standard_grant()._claim(entry.league_home_grant)
	var session: Dictionary = Save.binding(entry.session)
	if grant.is_empty() or session.is_empty() or session.league not in _league_home_save().Proposal.LEAGUES \
		or session.owner_id != grant.owner_id \
		or not ClubCareer.same(entry.baseline, grant.access) \
		or not ClubCareer.same(entry.player_access, grant.player_access) \
		or not entry.home_property is Dictionary:
		return false
	var paid: ClubAssetLedger = ClubPlayers.assets(preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(grant.history))
	return paid != null and ClubCareer.same(entry.home_property, StadiumLayoutSnapshot.capture(paid, true))


static func _open_league_home(value: Dictionary, snapshot: Dictionary) -> Dictionary:
	var authority: Dictionary = normalize(value)
	var checked: Dictionary = _league_home_save().qualify(snapshot, authority)
	if authority.is_empty() or checked.is_empty() \
		or checked.session.league not in available_leagues(authority):
		return {}
	# Reuse existing league admission with its exact bound checkpoint; only this
	# explicitly versioned envelope adds the frozen home witness afterwards.
	var initial: Dictionary = snapshot.checkpoint
	var opened: Dictionary = open_session(authority, initial)
	if opened.is_empty():
		return {}
	var entry: Dictionary = opened.sessions[checked.session.session_id]
	entry["league_home_grant"] = checked.home_grant.duplicate(true)
	entry["home_property"] = checked.home_property.duplicate(true)
	entry.reference = checked.reference
	if snapshot.version == LEAGUE_HOME_LIVE_SAVE:
		entry["home_format"] = LEAGUE_HOME_LIVE_SAVE
	opened.version = maxi(int(opened.version), LEAGUE_HOME_LIVE_AUTHORITY if snapshot.version == LEAGUE_HOME_LIVE_SAVE else LEAGUE_HOME_VERSION)
	return normalize(opened)


static func bind_dynasty_home(value: Dictionary, owner: Dictionary, snapshot: Dictionary) -> Dictionary:
	var authority: Dictionary = normalize(value)
	var proposal = load("res://src/gameplay/season/dynasty_carried_home_proposal.gd")
	var live = load("res://src/gameplay/season/dynasty_carried_home_live.gd")
	if authority.is_empty() or not ClubCareer.same(authority, owner.get("career")) \
		or proposal.qualify(snapshot, owner).is_empty(): return {}
	var id: String = snapshot.session.session_id
	var entry: Dictionary = authority.sessions.get(id, {})
	if entry.is_empty() or entry.settled != 0 or entry.has("dynasty_home") \
		or not ClubCareer.same(entry.session, snapshot.session): return {}
	var expected: Dictionary = live.header(snapshot)
	var checked: Dictionary = live.qualify(snapshot, expected)
	if checked.is_empty(): return {}
	entry["dynasty_home"] = expected
	authority.version = maxi(int(authority.version), DYNASTY_HOME_AUTHORITY)
	return _checkpoint_checked(normalize(authority), id, checked)

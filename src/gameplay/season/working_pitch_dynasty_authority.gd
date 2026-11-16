extends RefCounted
## Owner-bound shared history. Live sessions are NOT sequential Career27 rows.
## Latest unique session contributions are replaced, never cumulatively re-added.
# gdlint: disable=max-returns

const VERSION: int = 37
const Save = preload("res://src/gameplay/season/working_pitch_dynasty_save.gd")
const Progress = preload("res://src/gameplay/season/working_pitch_dynasty_progress.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Unlocks = preload("res://src/gameplay/season/league_unlocks.gd")


static func create(origin_snapshot: Dictionary, owner_id: String) -> Dictionary:
	if not Profile.token(owner_id):
		return {}
	var origin: Dictionary = JSON.parse_string(JSON.stringify(origin_snapshot, "", true, true))
	var season: SeasonState = SeasonSave._decode(origin)
	if season == null or season.career == null or not season.career.matches(season) \
		or season.career._pitch_catalog != WorkingPitchCatalog.signature():
		return {}
	var club: ClubCareer = season.career.fork()
	if not club.close(season):
		return {}
	var start: Dictionary = ClosedContentAccess._capture_checked(club, origin, owner_id)
	var imported: Dictionary = club.to_data()
	if start.is_empty() or imported.get("assets") == null:
		return {}
	return normalize({"version": VERSION, "pitch_catalog": WorkingPitchCatalog.signature(), "owner_id": owner_id,
		"origin": {"career": imported, "access": start, "reference": Save.snapshot_reference(origin)},
		"sessions": {}, "settlements": [], "assets": imported.assets.duplicate(true),
		"plaques": imported.get("plaques", {}).duplicate(true),
		"pennants": imported.get("pennants", {}).duplicate(true)})


static func normalize(value: Variant) -> Dictionary:
	if (
		not Profile.keys(value, ["version", "owner_id", "origin", "sessions", "settlements", "assets",
			"plaques", "pennants", "pitch_catalog"])
		or not Profile.whole(value.version, VERSION, VERSION) or value.pitch_catalog != WorkingPitchCatalog.signature() or not Profile.token(value.owner_id)
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
		imported == null or imported._pitch_catalog != WorkingPitchCatalog.signature() or imported.current != 0 or origin.is_empty()
		or origin.owner_id != value.owner_id or not _reference_valid(value.origin.reference)
		or origin.source.sha256 != value.origin.reference.sha256
		or imported.runs.size() + value.sessions.size() > ClubCareer.MAX_RUNS
		or not ClubCareer.same(origin.progress, _origin_progress(imported, origin))
	):
		return {}
	var ordinals: Array[int] = []
	var lineage_id: String = ""
	for id: Variant in value.sessions:
		if not id is String or not _entry_valid(value.sessions[id], id, origin, value.settlements.size()):
			return {}
		var context: Dictionary = value.sessions[id].session
		if int(context.ordinal) in ordinals or context.session_id != "%s:%d" % [context.lineage_id, int(context.ordinal)] \
			or (not lineage_id.is_empty() and lineage_id != context.lineage_id):
			return {}
		lineage_id = context.lineage_id
		ordinals.append(int(context.ordinal))
	ordinals.sort()
	for index in range(ordinals.size()):
		if ordinals[index] != index + 1:
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
		if not _tier_admitted(value, value.sessions[id], imported._title_history()) or not _prefix_valid(value, value.sessions[id]):
			return {}
	var result: Dictionary = value.duplicate(true)
	var club: ClubCareer = _history(result)
	var ledger: ClubAssetLedger = ClubPlayers.assets(club)
	if not ClubCareer.same(club._pennants, result.pennants) \
		or ledger == null or not StadiumPennantRewards.delivered(club, ledger) \
		or not StadiumPlaqueRewards.delivered(club, ledger):
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
	if not Profile.keys(entry, ["session", "baseline", "reference", "contribution",
		"settled", "era", "admission_frontier", "exotic_start"]):
		return false
	var context: Dictionary = Save.binding(entry.session)
	var baseline: Dictionary = ClosedContentAccess.normalize(entry.baseline)
	if context.is_empty() or context.session_id != id or context.owner_id != origin.owner_id \
		or context.league != "dynasty" or baseline.is_empty() \
		or not ClosedContentAccess.same_origin(baseline, origin) \
		or context.access_sha256 != ClosedContentAccess.digest(baseline) \
		or not _reference_valid(entry.reference) or not Profile.whole(entry.settled, 0, count) \
		or not StadiumClubIdentity.valid(entry.era) or not entry.admission_frontier is Dictionary \
		or not WorkingExoticAccess.valid_history(entry.exotic_start) \
		or not Progress.valid(entry.contribution, baseline) \
		or entry.contribution.proof.league_rules.league != context.league \
		or entry.contribution.proof.league_rules.tier != context.tier \
		or not LeagueRules.season_matches(entry.contribution.proof.league_rules, context.seed):
		return false
	for key: Variant in entry.admission_frontier:
		if not key is String or not Profile.token(key) or not _reference_valid(entry.admission_frontier[key]):
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
		contributions.append({"baseline": entry.baseline, "progress": entry.contribution})
	return Progress.access(authority.origin.access, contributions)


static func open_session(value: Dictionary, snapshot: Dictionary) -> Dictionary:
	if not WorkingPitchProgression.is_version(snapshot.get("version"), Save.BOUND_VERSION):
		return {}
	var authority: Dictionary = normalize(value)
	var checked: Dictionary = Save.qualify(snapshot)
	if authority.is_empty() or checked.is_empty():
		return {}
	var context: Dictionary = checked.session
	if context.league != "dynasty":
		return {}
	var season: SeasonState = checked.season
	if (
		authority.sessions.has(context.session_id) or context.owner_id != authority.owner_id
		or context.tier not in available_tiers(authority, context.league)
		or not _fresh(season)
		or not ClubCareer.same(season.build._book._exotic_start, WorkingExoticAccess.history(_history(authority)))
		or not WorkingExoticAccess.current_matches(season)
		or not ClubCareer.same(season._closed_access, _access(authority))
		or (not season.player_access.is_empty()
			and not ClubCareer.same(season.player_access, _player_view(authority).get("owned")))
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
		"admission_frontier": frontier, "exotic_start": WorkingExoticAccess.history(_history(authority))}
	return normalize(authority)


static func available_leagues(value: Dictionary) -> Array[String]:
	var authority: Dictionary = normalize(value)
	var result: Array[String] = []
	if not authority.is_empty() and "dynasty" in Unlocks.from_titles(_history(authority)._title_history()):
		result.append("dynasty")
	return result


static func available_tiers(value: Dictionary, league: String) -> Array[int]:
	var authority: Dictionary = normalize(value)
	if authority.is_empty() or league != "dynasty" or LeagueRules.capture(league,
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
static func _checkpoint_checked(authority: Dictionary, id: String, checked: Dictionary) -> Dictionary:
	if authority.is_empty() or checked.is_empty() or not authority.sessions.has(id):
		return {}
	var entry: Dictionary = authority.sessions[id]
	if not ClubCareer.same(entry.session, checked.session) \
		or not ClubCareer.same(entry.get("player_access", []), checked.season.player_access) \
		or not ClubCareer.same(entry.baseline, _checked_baseline(checked)) \
		or not ClubCareer.same(entry.exotic_start, checked.season.build._book._exotic_start) \
		or not WorkingExoticAccess.current_matches(checked.season):
		return {}
	if entry.settled != 0:
		return authority if ClubCareer.same(entry.reference, checked.reference) else {}
	var progress: Dictionary = checked.get("contribution", {}) if entry.has("standard_grant") else Progress.capture(checked.season)
	if progress.is_empty() or not _proof_extends(entry.contribution.proof, progress.proof) \
		or not WorkingExoticAccess.prefix(entry.contribution.player_progress, progress.player_progress):
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
		row.erase("pitch_catalog")
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
	var metrics: Dictionary = ClubPlayerProgress.metrics(records, true)
	return {"owned": ledger.owned(ClubPlayerCatalog.earned(metrics)), "metrics": metrics,
		"ledger": ledger.view(), "through": ClubPlayers.income_through(club)}


static func _qualify_session(_authority: Dictionary, _id: String, snapshot: Dictionary) -> Dictionary:
	return Save.qualify(snapshot)


static func _checked_baseline(checked: Dictionary) -> Dictionary:
	return checked.grant.access if checked.has("grant") else checked.season._closed_access




static func install_start(value: Dictionary, season: SeasonState) -> bool:
	var authority: Dictionary = normalize(value)
	return not authority.is_empty() and Save.supported(season) and _fresh(season) \
		and season.build._book.install_exotic_start(WorkingExoticAccess.history(_history(authority)))


static func _prefix_valid(authority: Dictionary, entry: Dictionary) -> bool:
	if entry.admission_frontier.size() != int(entry.session.ordinal) - 1:
		return false
	for other: Dictionary in authority.sessions.values():
		if other.session.lineage_id != entry.session.lineage_id:
			return false
		if other.session.ordinal < entry.session.ordinal and (
			other.settled == 0 or not ClubCareer.same(entry.admission_frontier.get(other.session.session_id), other.reference)):
			return false
	var expected: Array = WorkingExoticAccess.history(ClubCareer.from_data(authority.origin.career))
	var seen: Array = []
	for settled: Dictionary in authority.settlements:
		if not entry.admission_frontier.has(settled.session_id):
			continue
		var prior: Dictionary = authority.sessions[settled.session_id]
		if settled.session_id == entry.session.session_id \
			or (entry.settled > 0 and prior.settled >= entry.settled) \
			or not ClubCareer.same(entry.admission_frontier[settled.session_id], prior.reference):
			return false
		seen.append(settled.session_id)
		expected.append(prior.contribution.player_progress.exotic.duplicate(true))
	return seen.size() == entry.admission_frontier.size() \
		and ClubCareer.same(expected, entry.exotic_start)

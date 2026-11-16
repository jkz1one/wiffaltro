class_name SeasonRoundSettlement
extends RefCounted
## Rebuild a disposable candidate; neither discovery nor a failed job pays the live season.


static func project(season: SeasonState) -> Dictionary:
	var data: Dictionary = SeasonSave.snapshot(season)
	if data.is_empty() or season.physical == null:
		return {"error": "The pending round is invalid."}
	if not _pending_shape(season):
		return {"error": "The pending round is invalid."}
	var payload: Dictionary = _physical_payload(data)
	if payload.is_empty():
		return {"error": "The pending round checkpoint envelope is invalid."}
	var pending: Dictionary = payload.physical.pending.duplicate(true)
	payload.physical.pending = {}
	# Replay the complete original envelope, including career/session authority.
	# The leaf accessor above grants no validation or independent save admission.
	var candidate: SeasonState = SeasonSave._decode(data)
	if candidate == null:
		return {"error": "The round checkpoint could not be restored."}
	candidate._dynasty_owner_binding = season._dynasty_owner_binding
	return _project_candidate(candidate, pending)


static func _physical_payload(data: Dictionary) -> Dictionary:
	# Serialized layout only. Keep these exact layer groups aligned with Save81/83/85;
	# arbitrary recursion could accidentally strip an unrecognized authority layer.
	var payload: Dictionary = data
	if WorkingPitchProgression.is_version(payload.get("version"), ExpandedSeasonProgression.SEASON_VERSION):
		if not ExpandedSeasonProgression.season_envelope_valid(payload):
			return {}
		payload = payload.checkpoint
	if WorkingPitchProgression.is_version(payload.get("version"), WorkingPitchLeagueSave.VERSION):
		if WorkingPitchLeagueSave.parts(payload).is_empty():
			return {}
		payload = payload.checkpoint
	if SeasonSave.OwnedDraftSave.version_in(payload.get("version"), [WorkingPitchDynastySave.VERSION, WorkingPitchDynastySave.BOUND_VERSION]):
		if payload.version == WorkingPitchDynastySave.BOUND_VERSION:
			var checked: Dictionary = WorkingPitchDynastySave.qualify(payload)
			return {} if checked.is_empty() else WorkingPitchDynastySave.core(payload.checkpoint)
		return WorkingPitchDynastySave.core(payload)
	if WorkingPitchProgression.is_version(payload.get("version"), WorkingPitchCareerSave.VERSION):
		if WorkingPitchCareerSave.parts(payload).is_empty():
			return {}
		payload = payload.checkpoint
	if WorkingPitchProgression.is_version(payload.get("version"), WorkingPitchProgression.SEASON_VERSION):
		if not WorkingPitchProgression.season_envelope_valid(payload):
			return {}
		payload = payload.checkpoint
	if SeasonSave.OwnedDraftSave.version_in(payload.get("version"), [91, 92, 93, 94, 95, 96]):
		if not payload.get("checkpoint") is Dictionary:
			return {}
		payload = payload.checkpoint
	if SeasonSave.OwnedDraftSave.version_in(payload.get("version"), [88, 89]):
		if not payload.get("checkpoint") is Dictionary:
			return {}
		payload = payload.checkpoint
		if SeasonSave.OwnedDraftSave.version_in(payload.get("version"), [81]):
			if not payload.get("checkpoint") is Dictionary:
				return {}
			payload = payload.checkpoint
		if not SeasonOwnership._whole(payload.get("version"), 59, 74):
			return {}
	for versions: Array in [[87], [81, 83, 85], [78, 79, 80, 84], [76, 77, 82, 86]]:
		if SeasonSave.OwnedDraftSave.version_in(payload.get("version"), versions):
			if not payload.get("checkpoint") is Dictionary:
				return {}
			payload = payload.checkpoint
	if not payload.get("physical") is Dictionary \
		or not payload.physical.get("pending") is Dictionary:
		return {}
	return payload


static func _project_candidate(candidate: SeasonState, pending: Dictionary) -> Dictionary:
	candidate.physical.reports.append_array(pending.reports.duplicate(true))
	candidate.physical.projecting = true
	var ok: bool = (
		load("res://src/gameplay/season/league_home_result.gd").record(candidate, pending.human)
		if candidate._league_home_context.get("format") in [91, 92, 93, 94, 95, 96] else
		candidate.record_inventory_result(pending.human)
		if not candidate.inventory_rules.is_empty() and inventory_result(pending.human)
		else (
			candidate.record_doubleheader_result(pending.human)
			if LeagueRules.doubleheader(candidate.league_rules)
			else (
				candidate.record_surface_night_result(pending.human)
				if (StadiumSurfaceNightSnapshot.expected(candidate, candidate.pending_fixture()))
				else (candidate.callv("record_player_result", pending.human))
			)
		)
	)
	if candidate.physical.cursor != candidate.physical.reports.size():
		return {"error": "The pending round contains an unexpected physical fixture."}
	if ok:
		if not _receipts(candidate):
			return {"error": "The round did not settle every club's own fixture exactly once."}
		candidate.physical.projecting = false
		return {"candidate": candidate}
	if not candidate.physical.needed.is_empty() and candidate.physical.error.is_empty():
		return {"candidate": candidate, "fixture": candidate.physical.needed.duplicate(true)}
	return {"error": "The completed game or saved physical evidence failed validation."}


static func valid_pending(season: SeasonState) -> bool:
	return not project(season).has("error")


static func _pending_shape(season: SeasonState) -> bool:
	var pitch_catalog: String = SeasonPhysicalFixtures.catalog_for(season)
	if season._league_home_context.get("format") in [91, 92, 93, 94, 95, 96]:
		if season.physical == null or not SeasonOwnership._keys(season.physical.pending, ["human", "reports"]):
			return false
		if season._league_home_context.get("format") in [94, 95, 96] and StadiumSurfaceNightSnapshot.expected(season, season.pending_fixture()):
			return load("res://src/gameplay/season/league_home_night_result.gd").shape(
				season.physical.pending.get("human"), season.physical.pending.get("reports"),
				LeagueRules.doubleheader(season.league_rules), pitch_catalog)
		return load("res://src/gameplay/season/league_home_result.gd").shape(
			season.physical.pending.get("human"), season.physical.pending.get("reports"),
			LeagueRules.doubleheader(season.league_rules),
			StadiumPoolOwnedHumanEvidence.expected(season, season.pending_fixture()), pitch_catalog)
	if (
		not season.inventory_rules.is_empty()
		and inventory_result(season.physical.pending.get("human", []))
	):
		return _inventory_shape(
			season.physical.pending, LeagueRules.doubleheader(season.league_rules), pitch_catalog
		)
	if LeagueRules.doubleheader(season.league_rules):
		return _doubleheader_shape(season.physical.pending, pitch_catalog)
	if StadiumSurfaceNightSnapshot.expected(season, season.pending_fixture()):
		return _night_shape(season.physical.pending, pitch_catalog)
	return _shape(
		season.physical.pending,
		season.opponents._format >= 9,
		not season.home_property.is_empty() or not season.npc_venues.is_empty(),
		StadiumPoolOwnedHumanEvidence.expected(season, season.pending_fixture()),
		StadiumNpcYardTwoHumanEvidence.expected(season, season.pending_fixture()), pitch_catalog
	)


# Only SeasonSave may use this after replaying and validating the entire settled
# prefix in THIS decode call. Public project()/valid_pending() still decode a
# snapshot: an arbitrary live object is never treated as validated save evidence.
# Old Standard/career/venue profiles keep their historical path unchanged.
static func _valid_pending_replayed(season: SeasonState) -> bool:
	if season != null and season._league_home_context.get("format") in [91, 92, 93, 94, 95, 96]:
		if not load("res://src/gameplay/season/dynasty_league_home_live.gd").matches(season) or not _pending_shape(season):
			return false
		var candidate: SeasonState = _fork_replayed_state(season)
		return candidate != null and not _project_candidate(candidate, season.physical.pending.duplicate(true)).has("error")
	var standard: bool = season != null and not season._standard_live_context.is_empty()
	var candidate: SeasonState = _fork_replayed_standard(season) if standard else _fork_replayed_league(season)
	if candidate == null:
		return false if standard else valid_pending(season)
	if not _pending_shape(season):
		return false
	return not _project_candidate(candidate, season.physical.pending.duplicate(true)).has("error")


static func _valid_expanded_pending_replayed(season: SeasonState) -> bool:
	# Decoder-only: Operations1 has replayed and checked the settled prefix in
	# this call. This is not admission for an arbitrary live SeasonState/cache.
	# Full cold entry, Build/history/NPC checks and final v6 checks stay intact.
	if season == null or season.physical == null or season.opponents == null:
		return false
	if not _pending_shape(season):
		return false
	var candidate: SeasonState = _fork_replayed_expanded(season)
	if candidate == null:
		return valid_pending(season)  # Unknown scope/fields retain full replay.
	return not _project_candidate(candidate, season.physical.pending.duplicate(true)).has("error")


static func _fork_replayed_expanded(season: SeasonState) -> SeasonState:
	# Only the current standalone v6 leaf. No owner, career, venue or other
	# retained authority can enter through this optimization.
	if season == null or season.get_script() != SeasonState \
		or season.build == null or not season.build.pitch_catalog_expanded() \
		or season.build._format != 41 or season.build._market != 0 \
		or season.ownership == null or season.opponents == null \
		or season.opponents._format != 13 or season.physical == null \
		or season.physical.cursor != season.physical.reports.size() \
		or season.career != null or season.league_career or season.league_live \
		or not season.league_rules.is_empty() or not season.inventory_rules.is_empty() \
		or not season._dynasty_start.is_empty() or not season._closed_access.is_empty() \
		or not season._dynasty_owner_binding.is_empty() \
		or not season._dynasty_career_session.is_empty() \
		or not season._standard_live_context.is_empty() \
		or not season._standard_bound_grant.is_empty() \
		or not season._league_home_context.is_empty() \
		or not season.home_property.is_empty() or not season.owned_surface_night.is_empty() \
		or not season.npc_venues.is_empty() or not season.final_venue.is_empty() \
		or not season.player_access.is_empty() or season._heat_replay_team != null \
		or season._doubleheader_replay_build != null or season._pool_replay_ledger != null \
		or season._npc_replay_run != -1:
		return null
	# Includes exact current catalog and exotic-prefix correspondence, matching
	# the outer standalone restore's final checks without recursively decoding.
	if ExpandedSeasonProgression.capture_season(season).is_empty():
		return null
	# Existing exhaustive property inventory fails closed on unknown fields.
	# Nested builds/books/banks/progress are detached; pending transients reset.
	return _fork_replayed_state(season)


static func _fork_replayed_league(season: SeasonState) -> SeasonState:
	if (
		season == null
		or season.league_rules.is_empty()
		or season.career != null
		or season.league_career
		or not season.league_live
		or not season.league_context_consistent()
		or not SeasonSave._closed_league_shape(season)
		or season._heat_replay_team != null
		or season._doubleheader_replay_build != null
		or season._pool_replay_ledger != null
		or season._npc_replay_run != -1
		or not season._standard_live_context.is_empty()
		or not season._standard_bound_grant.is_empty()
		or season.physical.cursor != season.physical.reports.size()
	):
		return null
	return _fork_replayed_state(season)


static func _fork_replayed_standard(season: SeasonState) -> SeasonState:
	# Decoder-only: caller has replayed the settled prefix in this decode call.
	if season == null or not load("res://src/gameplay/season/dynasty_standard_live.gd").matches(season) \
		or season.league_live or season.league_career or not season.league_rules.is_empty() \
		or season.career != null or not season._closed_access.is_empty() \
		or not season.inventory_rules.is_empty() \
		or not season._dynasty_start.is_empty() or season._heat_replay_team != null \
		or season._doubleheader_replay_build != null or season._pool_replay_ledger == null \
		or season.physical == null or season.physical.cursor != season.physical.reports.size():
		return null
	return _fork_replayed_state(season)


static func _fork_replayed_state(season: SeasonState) -> SeasonState:
	# Exhaustive list, checked against script variables below: future state fields
	# must be reviewed before using this shortcut, otherwise fall back to replay.
	var fields: Array[String] = [
		"league_rules",
		"_dynasty_start",
		"_closed_access",
		"_dynasty_owner_binding",
		"_dynasty_career_session",
		"_standard_live_context",
		"_league_home_context",
		"_standard_bound_grant",
		"inventory_rules",
		"league_live",
		"league_career",
		"season_seed",
		"phase",
		"round_index",
		"draft_pool",
		"player_access",
		"home_property",
		"owned_surface_night",
		"npc_venues",
		"final_venue",
		"picks",
		"teams",
		"schedule",
		"results",
		"player_results",
		"playoff_seeds",
		"semifinals",
		"final_fixture",
		"champion",
		"starter_index",
		"fielder_index",
		"difficulty",
		"_npc_replay_run"
	]
	var objects: Array[String] = [
		"ownership",
		"build",
		"opponents",
		"career",
		"physical",
		"_heat_replay_team",
		"_doubleheader_replay_build",
		"_pool_replay_ledger"
	]
	for property: Dictionary in season.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			if not fields.has(property.name) and not objects.has(property.name):
				return null
	var result: SeasonState = SeasonState.new()
	for field: String in fields:
		result.set(field, _detached_value(season.get(field)))
	if season._pool_replay_ledger != null:
		result._pool_replay_ledger = season._pool_replay_ledger.fork()
	result.ownership = season.ownership.fork()
	result.build = _fork_build(season.build)
	result.opponents = SeasonOpponents.new()
	result.opponents.draft_order = season.opponents.draft_order.duplicate()
	result.opponents.draft_rule = season.opponents.draft_rule
	result.opponents._format = season.opponents._format
	result.opponents.clubs = season.opponents.clubs.duplicate(true)
	# Dictionary.duplicate(true) alone does NOT detach contained RefCounteds.
	for key: String in result.opponents.clubs:
		result.opponents.clubs[key].build = _fork_build(season.opponents.clubs[key].build)
	# Ordinary Save93/94 carry Career27 through this decoder-only fork.
	# Shared91/92 and historical closed replay must retain their null-career path.
	if season._league_home_context.get("format") in [93, 94]:
		if season.career == null or not season.league_career:
			return null
		result.career = season.career.fork()
		if result.career == null:
			return null
	result.physical = SeasonPhysicalFixtures.new()
	result.physical.reports = season.physical.reports.duplicate(true)
	result.physical.cursor = season.physical.cursor
	# Match decoding a snapshot with pending removed, not a live job's transient
	# needed/error state. _project_candidate performs the SAME remaining checks.
	result.physical.pending = {}
	result.physical.projecting = false
	return result


static func _detached_value(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


static func _fork_build(build: SeasonBuild) -> SeasonBuild:
	var result: SeasonBuild = build._fork()
	# Existing transaction forks intentionally share immutable start metadata.
	# Detach those containers too, so projection cannot alias its validated input.
	result._dynasty_start = build._dynasty_start.duplicate(true)
	for field: String in [
		"_order_start",
		"_rain_start",
		"_transfer_start",
		"_checkout_start",
		"_association_start",
		"_freezer_start",
		"_sides_start",
		"_field_start",
		"_sure_start",
		"_jump_start",
		"_batch_start",
		"_supply_start"
	]:
		result.set(field, _detached_value(build.get(field)))
	result._abilities.start = _detached_value(build._abilities.start)
	result._major.start = _detached_value(build._major.start)
	result._copy.start = _detached_value(build._copy.start)
	return result


static func _receipts(season: SeasonState) -> bool:
	for index in range(1, 6):
		var expected: Dictionary = {}
		for fixture: Dictionary in season.results:
			if fixture.home == index or fixture.away == index:
				expected[str(int(fixture.id))] = SeasonState._winner(fixture) == index
		if not ClubCareer.same(
			season.opponents.clubs[str(index)].build._bank.view().rewards, expected
		):
			return false
	return true


static func _shape(
	value: Variant,
	tactics: bool = false,
	property: bool = false,
	owned_pool: bool = false,
	yard_two: bool = false,
	pitch_catalog: String = ""
) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, ["human", "reports"]):
		return false
	if (
		not value.human is Array
		or (
			value.human.size()
			!= (17 if yard_two else 16 if owned_pool else 15 if property else 13 if tactics else 12)
		)
		or not value.reports is Array
	):
		return false
	if value.reports.size() > 5:
		return false
	for index in range(3):
		if not SeasonOwnership._whole(value.human[index], 0, 9999):
			return false
	for index in [3, 6, 9, 10]:
		if not value.human[index] is Dictionary:
			return false
	for index in [4, 5, 7, 8, 11]:
		if not value.human[index] is Array:
			return false
	if tactics and not value.human[12] is Dictionary:
		return false
	if (
		property
		and (
			not tactics
			or not value.human[13] is Array
			or not value.human[13].is_empty()
			or not value.human[14] is String
		)
	):
		return false
	if (
		owned_pool
		and (
			not property
			or not value.human[15] is Dictionary
			or not StadiumPoolOwnedHumanEvidence.valid(value.human[15], pitch_catalog)
		)
	):
		return false
	if (
		yard_two
		and (
			owned_pool
			or not property
			or value.human[15] != null
			or not StadiumNpcYardTwoHumanEvidence.valid(value.human[16])
		)
	):
		return false
	for row: Variant in value.reports:
		if not SeasonPhysicalFixtures.envelope(row, pitch_catalog):
			return false
	return true


static func _doubleheader_shape(value: Variant, pitch_catalog: String = "") -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, ["human", "reports"])
		or not value.human is Array
		or value.human.size() != 14
		or not value.human[13] is Array
		or value.human[13].size() != 2
	):
		return false
	return _shape({"human": value.human.slice(0, 13), "reports": value.reports}, true, false, false, false, pitch_catalog)


static func _night_shape(value: Variant, pitch_catalog: String = "") -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, ["human", "reports"])
		or not value.human is Array
		or value.human.size() != 18
		or value.human[15] != null
		or value.human[16] != null
		or not StadiumSurfaceNightHumanEvidence.valid(value.human[17])
	):
		return false
	return _shape({"human": value.human.slice(0, 15), "reports": value.reports},
		true, true, false, false, pitch_catalog)


static func inventory_result(human: Variant) -> bool:
	return human is Array and human.size() in [14, 15] and human[-1] is Dictionary


static func _inventory_shape(value: Variant, doubleheader: bool, pitch_catalog: String = "") -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, ["human", "reports"])
		or not value.human is Array
		or value.human.size() != (15 if doubleheader else 14)
		or not value.human[-1] is Dictionary
		or value.human[-1].is_empty()
	):
		return false
	var original: Dictionary = {
		"human": value.human.slice(0, value.human.size() - 1), "reports": value.reports
	}
	return _doubleheader_shape(original, pitch_catalog) if doubleheader \
		else _shape(original, true, false, false, false, pitch_catalog)

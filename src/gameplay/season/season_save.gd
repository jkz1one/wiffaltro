class_name SeasonSave
extends RefCounted

const ClubLeagueCareer = preload("res://src/gameplay/season/club_league_career.gd")
const LeagueCareerSave = preload("res://src/gameplay/season/league_career_save.gd")
const DynastyCareerSave = preload("res://src/gameplay/season/dynasty_career_save.gd")
const OwnedDraftSave = preload("res://src/gameplay/season/league_owned_draft_save.gd")

const AC02_PASSIVE_15 = preload("res://src/diagnostics/ac02_passive_attribution.gd")

# Closed owner sessions use their own exact manifest authority. Legacy path and
# backup recovery remain unchanged when no explicit owner binding is present.
const DYNASTY_OWNER_STORE = preload("res://src/gameplay/season/dynasty_owner_store.gd")

const Operations1: GDScript = preload("res://src/gameplay/season/season_save_operations_1.gd")

const Operations2: GDScript = preload("res://src/gameplay/season/season_save_operations_2.gd")

const Operations3: GDScript = preload("res://src/gameplay/season/season_save_operations_3.gd")

static var path: String = "user://season-v1.json"
static var last_error: String = ""

static var _dynasty_owner_path: String = ""
static var _dynasty_owner_content_blocked: bool = false


static func bind_dynasty_owner(owner_path: String) -> bool:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		last_error = "A result save is in progress. No competing operation was made."
		return false
	if owner_path.is_empty():
		return false
	_dynasty_owner_path = owner_path
	var outcome: Dictionary = DYNASTY_OWNER_STORE.inspect(owner_path)
	last_error = str(outcome.get("reason", ""))
	return outcome.get("status") in ["ready", "recoverable", "pending"]

static func dynasty_owner_bound() -> bool:
	return not _dynasty_owner_path.is_empty()

static func _owner_checkpoint(season: SeasonState) -> bool:
	var found: Dictionary = DYNASTY_OWNER_STORE.inspect(_dynasty_owner_path)
	var owner: Dictionary = found.get("owner", {})
	if owner.is_empty() or found.get("status") not in ["ready", "pending"]:
		last_error = str(found.get("reason", "Dynasty session is unavailable."))
		return false
	var data: Dictionary = snapshot(season)
	if data.is_empty():
		last_error = "The current session could not be validated."
		return false
	var slot: Dictionary = owner.get(str(owner.get("selected", "")), {})
	if slot.is_empty():
		last_error = "The selected session is unavailable."
		return false
	var binding: Dictionary = season._dynasty_owner_binding
	if binding.get("path") != _dynasty_owner_path or binding.get("session_id") != slot.session_id:
		last_error = "This session is not the current saved owner. Reopen it before saving."
		return false
	var request_id: String = _owner_checkpoint_id(data, owner, slot)
	var previous: Dictionary = owner.get("last_action", {})
	var revision: int = int(binding.get("revision", -1))
	if previous.get("id") == request_id and revision == int(found.get("revision", 0)):
		revision = int(previous.get("expected_revision", -1))
	var request: Dictionary = {
		"op": "checkpoint",
		"request_id": request_id,
		"expected_revision": revision,
		"session_id": slot.session_id,
		"snapshot": data
	}
	var outcome: Dictionary = DYNASTY_OWNER_STORE.commit(request, _dynasty_owner_path)
	last_error = str(outcome.get("reason", ""))
	if outcome.get("playability") == "blocked":
		_dynasty_owner_content_blocked = true
		return false
	if outcome.get("status") == "committed":
		_dynasty_owner_content_blocked = false
		_bind_owner_season(season, outcome)
		return true
	return false

static func _owner_checkpoint_id(data: Dictionary, owner: Dictionary, slot: Dictionary) -> String:
	# Legacy owner-v1 request identity remains byte-for-byte unchanged.
	if owner.get("version") not in [2, 3]:
		return "save:" + JSON.stringify(data, "", true, true).sha256_text()
	var reference: Dictionary = DynastyCareerSave.snapshot_reference(data)
	var previous: Dictionary = owner.get("last_action", {})
	var operands: Dictionary = owner.get("operands", {})
	# Existing v2 checkpoints may have raw, pre-transport save IDs. Reuse only
	# the exact compact checkpoint operand; Store still validates its complete
	# fingerprint, revision, source authority and replay before accepting retry.
	if previous.get("kind") == "checkpoint" and operands.get("op") == "checkpoint" \
		and previous.get("id") == operands.get("request_id") \
		and operands.get("session_id") == slot.get("session_id") \
		and ClubCareer.same(operands.get("snapshot"), reference) \
		and ClubCareer.same(slot.get("reference"), reference):
		return str(previous.id)
	return "save:" + reference.sha256


static func _bind_owner_season(season: SeasonState, outcome: Dictionary) -> void:
	var owner: Dictionary = outcome.get("owner", {})
	if season == null or owner.is_empty():
		return
	var slot: Dictionary = owner.get(str(owner.get("selected", "")), {})
	var binding: Dictionary = {
		"path": _dynasty_owner_path,
		"revision": int(outcome.get("revision", 0)),
		"session_id": str(slot.get("session_id", ""))
	}
	binding.make_read_only()
	season._dynasty_owner_binding = binding

static func _owner_restore() -> SeasonState:
	var outcome: Dictionary = DYNASTY_OWNER_STORE.restore(_dynasty_owner_path)
	last_error = str(outcome.get("reason", ""))
	var selected: SeasonState = (
		outcome.get("qualified_selected_season") if outcome.get("status") == "committed" else null
	)
	_dynasty_owner_content_blocked = selected == null
	if selected != null:
		_bind_owner_season(selected, outcome)
	return selected

static func snapshot(season: SeasonState) -> Dictionary:
	if season != null and season.build != null and season.build.pitch_catalog_expanded():
		return ExpandedSeasonProgression.capture_season(season)
	if season != null and season.build != null and season.build.pitch_catalog_current():
		if LeagueRules.dynasty(season.league_rules):
			return WorkingPitchDynastySave.capture(season)
		if season.league_career:
			return WorkingPitchLeagueSave.capture(season)
		return WorkingPitchCareerSave.capture(season) if season.career != null else WorkingPitchProgression.capture_season(season)
	if season != null and season._league_home_context.get("format") in [95, 96]:
		return load("res://src/gameplay/season/dynasty_shared_time.gd").capture(season)
	if season != null and season._league_home_context.get("format") == 94:
		return load("res://src/gameplay/season/normal_league_time_candidate.gd").capture(season)
	if season != null and season._league_home_context.get("format") == 93:
		return load("res://src/gameplay/season/normal_league_home.gd").capture(season)
	if season != null and not season._league_home_context.is_empty():
		return load("res://src/gameplay/season/dynasty_league_home_save.gd").capture(season)
	if season != null and not season._dynasty_career_session.is_empty():
		if season._dynasty_career_session.has("grant_sha256"):
			return load("res://src/gameplay/season/dynasty_standard_save.gd")._capture_bound(season)
		return DynastyCareerSave.capture(season)
	if season != null and not season._standard_live_context.is_empty():
		return {}  # Not admitted: never serialize a live-grant session as ordinary.
	var ac02_token: int = AC02_PASSIVE_15.enter("season_save.snapshot")
	var ac02_result: Dictionary = _ac02_passive_15_snapshot(season)
	AC02_PASSIVE_15.leave(ac02_token)
	return LeagueCareerSave.wrap(ac02_result)

static func _ac02_passive_15_snapshot(season: SeasonState) -> Dictionary:
	if not season.league_rules.is_empty() and not season.player_access.is_empty():
		return OwnedDraftSave.snapshot(season)
	if (
		not season.league_context_consistent()
		or (not season.league_rules.is_empty() and not _closed_league_shape(season))
	):
		return {}
	var data: Dictionary = {
		"version": 4,
		"ownership": season.ownership.to_data(),
		"seed": season.season_seed,
		"picks": season.picks,
		"results": season.player_results,
		"lineup": season.teams[0]["roster"],
		"starter": season.starter_index,
		"fielder": season.fielder_index,
		"pool": season.draft_pool,
		"difficulty": season.difficulty,
		"draws": season.teams.map(func(team: Dictionary) -> float: return team["draw"]),
		"strengths":
		season.teams.map(func(team: Dictionary) -> float: return team.get("strength", -1.0)),
	}
	if season.build != null:
		data.version = 4 + season.build._format
		data.erase("ownership")
		data["build"] = season.build.to_data()
	if season.opponents != null:
		data["opponents"] = season.opponents.to_data()
	if season.physical != null:
		var policy: int = season.opponents._format if season.opponents != null else 0
		data.version = 44 + policy if policy >= 3 else 46
		data["physical"] = season.physical.to_data()
	if not season.player_access.is_empty():
		data.version = 58
		data["player_access"] = season.player_access.duplicate()
	if not season.home_property.is_empty():
		data.version = 59
		data["home_property"] = season.home_property.duplicate(true)
		if season.home_property.get("version") == StadiumPoolOwnedSnapshot.VERSION:
			data.version = 60
	if not season.npc_venues.is_empty():
		var venues: Dictionary = SeasonVenues.normalized(
			season.npc_venues, season.season_seed, SeasonVenues.run_for(season)
		)
		if (
			venues.is_empty()
			or not SeasonVenues.matches_season(season)
			or data.version not in [59, 60]
		):
			last_error = "The saved away-park assignment is invalid. The previous save was preserved."
			return {}
		data.version = 61
		data["npc_venues"] = venues
	if not season.final_venue.is_empty():
		var final_record: Dictionary = SeasonFinalVenue.normalized(
			season.final_venue, season.season_seed, SeasonVenues.run_for(season)
		)
		if (
			data.version != 61
			or final_record.is_empty()
			or not SeasonFinalVenue.matches_season(season)
		):
			last_error = "The saved neutral-final record is invalid. The previous save was preserved."
			return {}
		data.version = (
			67
			if final_record.version == SeasonFinalVenue.HILLSIDE_VERSION
			else (
				66
				if final_record.version == SeasonFinalVenue.POOL_PARTY_VERSION
				else (
					65
					if final_record.version == SeasonFinalVenue.GRAND_III_VERSION
					else (
						64
						if final_record.version == SeasonFinalVenue.GRAND_II_VERSION
						else (63 if final_record.version == SeasonFinalVenue.GRAND_VERSION else 62)
					)
				)
			)
		)
		data["final_venue"] = final_record
	var career: ClubCareer
	if season.career != null:
		career = season.career.fork()
		if not career.sync(season):
			last_error = "Club history does not match this season. The previous save was preserved."
			return {}
		data["career"] = career.to_data()
	var standard_version: int = (
		career.standard_version()
		if career != null and season.league_rules.is_empty()
		else 0
	)
	if standard_version == 26:
		data.version = 71
		data["draft_rule"] = season.opponents.draft_rule if season.opponents != null else ""
		data["sponsor_rule"] = season.build._sponsor_rule if season.build != null else ""
		if not (
			_legacy_d4_envelope_valid(data, career)
			if career.current == 0
			else _standard_d4_envelope_valid(WorkingPitchCareerSave.header_projection(data) if season.build.pitch_catalog_current() else data, career)
		):
			last_error = (
				"The Standard tier and saved sponsor/draft/price/venue context do not match. "
				+ "The previous save was preserved."
			)
			return {}
	elif standard_version == 25:
		# Save70 retains D3 history while active mode owns its exact inherited rules.
		data.version = 70
		data["draft_rule"] = season.opponents.draft_rule if season.opponents != null else ""
		data["sponsor_rule"] = season.build._sponsor_rule if season.build != null else ""
		if not (
			_legacy_d3_envelope_valid(data, career)
			if career.current == 0
			else _standard_d3_envelope_valid(WorkingPitchCareerSave.header_projection(data) if season.build.pitch_catalog_current() else data, career)
		):
			last_error = (
				"The Standard tier and saved sponsor/draft/price/venue context do not match. "
				+ "The previous save was preserved."
			)
			return {}
	elif standard_version == 24:
		# Save69 persists after lower-tier replay; the selected tier still owns every rule.
		data.version = 69
		data["draft_rule"] = season.opponents.draft_rule if season.opponents != null else ""
		if not (
			_legacy_d2_envelope_valid(data, career)
			if career.current == 0
			else _standard_d2_envelope_valid(WorkingPitchCareerSave.header_projection(data) if season.build.pitch_catalog_current() else data, career)
		):
			last_error = (
				"The Standard tier and saved draft/price/venue context do not match. "
				+ "The previous save was preserved."
			)
			return {}
	elif standard_version == 23:
		# Save68 is an explicit cross-record format, never final-version arithmetic.
		data.version = 68
		if (
			not (
				_legacy_d1_envelope_valid(data, career)
				if career.current == 0
				else _standard_d1_envelope_valid(WorkingPitchCareerSave.header_projection(data) if season.build.pitch_catalog_current() else data, career)
			)
			or data.get("opponents", {}).has("draft_rule")
		):
			last_error = (
				"The Standard tier and saved price/venue context do not match. "
				+ "The previous save was preserved."
			)
			return {}
	elif not LeagueRules.tiered(season.league_rules) and (
		data.get("build", {}).get("version") == SeasonBuild.D1_VERSION
		or data.get("build", {}).get("version") == SeasonBuild.D3_VERSION
		or data.get("build", {}).get("version") == SeasonBuild.D4_VERSION
		or data.get("build", {}).has("sponsor_rule")
		or data.get("build", {}).has("pricing_rule")
		or data.get("opponents", {}).has("draft_rule")
		or (
			data.get("final_venue", {}).get("selection")
			in [
				SeasonFinalVenue.STANDARD_D1_SELECTION,
				SeasonFinalVenue.STANDARD_D2_SELECTION,
				SeasonFinalVenue.STANDARD_D3_SELECTION,
				SeasonFinalVenue.STANDARD_D4_SELECTION
			]
		)
	):
		last_error = (
			"Standard tier rules require their validated career history. "
			+ "The previous save was preserved."
		)
		return {}
	if season.owned_surface_night.get("version") == StadiumSurfaceNightSnapshot.TIME_VERSION:
		if (
			not _integer(data.version, 59, 71)
			or not StadiumSurfaceNightSnapshot.valid_policy(
				season.owned_surface_night, season, StadiumSurfaceNightSnapshot.ledger(season)
			)
		):
			last_error = "The starting profile does not match the immutable paid home field."
			return {}
		data["legacy_save_version"] = int(data.version)
		data["owned_surface_night"] = season.owned_surface_night.duplicate(true)
		data.version = 73
		return _terrain_envelope(data)
	if not season.owned_surface_night.is_empty():
		if (
			not _integer(data.version, 59, 71)
			or not StadiumSurfaceNightSnapshot.valid_policy(
				season.owned_surface_night, season, StadiumSurfaceNightSnapshot.ledger(season)
			)
		):
			last_error = "The night policy does not match the immutable paid home field."
			return {}
		data["legacy_save_version"] = int(data.version)
		data["owned_surface_night"] = season.owned_surface_night.duplicate(true)
		data.version = 72
	if not season.league_rules.is_empty():
		if data.version != 57:
			return {}
		if LeagueRules.tiered(season.league_rules) and not (
			ClubLeagueCareer.admitted(season) or not season._closed_access.is_empty()
		):
			return {}
		var closed: Dictionary = {
			"version":
			(
				(DynastyCareerSave.TIER_CHECKPOINT_VERSION if not season._closed_access.is_empty()
					else LeagueCareerSave.TIER_CHECKPOINT_VERSION)
				if LeagueRules.tiered(season.league_rules)
				else (
					(77 if LeagueRules.doubleheader(season.league_rules) else 76)
					if season.league_live else 75
				)
			),
			"league_rules": season.league_rules.duplicate(true),
			"checkpoint": data
		}
		if not season._closed_access.is_empty():
			var access_save: Dictionary = {
				"version": DynastyCareerSave.RAW_TIER_VERSION
					if LeagueRules.tiered(season.league_rules) else 80,
				"access": season._closed_access.duplicate(true),
				"inventory_rules": season.inventory_rules.duplicate(true),
				"checkpoint": closed
			}
			if LeagueRules.dynasty(season.league_rules):
				access_save["dynasty_start"] = season._dynasty_start.duplicate(true)
			return access_save
		if LeagueRules.dynasty(season.league_rules):
			return {
				"version": 79,
				"dynasty_start": season._dynasty_start.duplicate(true),
				"inventory_rules": season.inventory_rules.duplicate(true),
				"checkpoint": closed
			}
		return (
			{
				"version": 78,
				"inventory_rules": season.inventory_rules.duplicate(true),
				"checkpoint": closed
			}
			if not season.inventory_rules.is_empty()
			else closed
		)
	return _terrain_envelope(data)


static func save(season: SeasonState, _ac02_career_write: Variant = null) -> bool:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		last_error = "A result save is in progress. No competing operation was made."
		return false
	if not WorkingPitchDynastySave.owner_context_valid(season):
		last_error = "Current Dynasty requires its exact durable selected owner. Raw checkpoints are internal only."
		return false
	if season != null and not season._dynasty_career_session.is_empty() and not dynasty_owner_bound():
		last_error = "Shared Dynasty sessions must be saved through their joint owner."
		return false
	return Operations2._public_save(season, _ac02_career_write)


static func _same_save_career(source: Variant, checked: ClubCareer) -> ClubCareer:
	# Private proof consumer: checked must come from this call's successful _decode.
	# Never reconstruct assets with to_data(), retain a cache, or authorize a cold
	# read here. Comparison includes every raw career field, including nested proof
	# and purchase history. A recovered/migrated value is not the original value.
	if (
		not source is Dictionary
		or not _integer(source.get("version"), 22, ClubLeagueCareer.VERSION)
		or checked == null
		or checked.get_script() != ClubCareer
	):
		return null
	var expected: Array = [
		source.get("current"),
		source.get("runs"),
		source.get("assets"),
		source.get("pennants", {}),
		source.get("plaques", {})
	]
	var actual: Array = [
		checked.current, checked.runs, checked._assets, checked._pennants, checked._plaques
	]
	return (
		checked
		if JSON.stringify(expected, "", true, true) == JSON.stringify(actual, "", true, true)
		else null
	)


static func restore() -> SeasonState:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		last_error = "A result save is in progress. No competing operation was made."
		return null
	var ac02_token: int = AC02_PASSIVE_15.enter("season_save.restore")
	var ac02_result: SeasonState = _ac02_passive_15_restore()
	AC02_PASSIVE_15.leave(ac02_token)
	return ac02_result


static func _ac02_passive_15_restore() -> SeasonState:
	last_error = ""
	if dynasty_owner_bound():
		return _owner_restore()
	var season: SeasonState = _read(path)
	if season == null:
		season = _read(path + ".bak")
		if season != null:
			last_error = "Recovered the previous checkpoint. The unreadable save was left untouched."
		elif FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			last_error = "Season save is invalid or incompatible. It has been left untouched."
	return season


static func _read(file_path: String) -> SeasonState:
	var ac02_token: int = AC02_PASSIVE_15.enter("season_save._read")
	var ac02_result: SeasonState = _ac02_passive_15_private_read(file_path)
	AC02_PASSIVE_15.leave(ac02_token)
	return ac02_result


static func _ac02_passive_15_private_read(file_path: String) -> SeasonState:
	if not FileAccess.file_exists(file_path):
		return null
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > 8 * 1024 * 1024:
		return null
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	return _decode_public(json.data) if parse_error == OK else null


static func _decode_public(value: Variant) -> SeasonState:
	# Standalone files never supply Owner3 authority, even when a session header
	# or a structurally valid inherited proof has been copied into the file.
	if value is Dictionary and OwnedDraftSave.version_in(value.get("version"),
		[WorkingPitchDynastySave.VERSION, WorkingPitchDynastySave.BOUND_VERSION]):
		return null
	var season: SeasonState = _decode(value)
	return null if WorkingPitchDynastySave.requires_owner(season) else season


static func _decode(value: Variant) -> SeasonState:
	if value is Dictionary and WorkingPitchProgression.is_version(value.get("version"), ExpandedSeasonProgression.SEASON_VERSION):
		return ExpandedSeasonProgression.restore_season(value)
	if ExpandedSeasonProgression.contains_current_build(value):
		return null
	if value is Dictionary and OwnedDraftSave.version_in(value.get("version"),
		[WorkingPitchDynastySave.VERSION, WorkingPitchDynastySave.BOUND_VERSION]):
		return WorkingPitchDynastySave.restore(value)
	if value is Dictionary and WorkingPitchProgression.is_version(value.get("version"), WorkingPitchLeagueSave.VERSION):
		return WorkingPitchLeagueSave.restore(value)
	if value is Dictionary and WorkingPitchProgression.is_version(value.get("version"), WorkingPitchCareerSave.VERSION):
		return WorkingPitchCareerSave.restore(value)
	if value is Dictionary and _integer(value.get("version"), 97, 97):
		return WorkingPitchProgression.restore_season(value)
	if WorkingPitchProgression.contains_current_build(value):
		return null  # Current catalogs require their explicit outer admission.
	if value is Dictionary and OwnedDraftSave.version_in(value.get("version"), [95, 96]):
		return load("res://src/gameplay/season/dynasty_shared_time.gd").decode_current(value)
	if value is Dictionary and _integer(value.get("version"), 94, 94):
		return load("res://src/gameplay/season/normal_league_time_candidate.gd").decode(value)
	if value is Dictionary and _integer(value.get("version"), 93, 93):
		return load("res://src/gameplay/season/normal_league_home.gd").decode(value)
	if value is Dictionary and _integer(value.get("version"), 92, 92):
		return load("res://src/gameplay/season/dynasty_carried_home_live.gd").decode_current(value)
	if value is Dictionary and _integer(value.get("version"), 90, 91):
		return load("res://src/gameplay/season/dynasty_league_home_save.gd").decode_current(value)
	if value is Dictionary and OwnedDraftSave.version_in(value.get("version"), [88, 89]):
		return load("res://src/gameplay/season/dynasty_standard_save.gd").decode_current(value)
	if value is Dictionary and value.get("version") == OwnedDraftSave.VERSION:
		return OwnedDraftSave.decode(value)
	if value is Dictionary and OwnedDraftSave.version_in(
		value.get("version"), [DynastyCareerSave.VERSION, DynastyCareerSave.TIER_VERSION]):
		return DynastyCareerSave.decode(value)
	if value is Dictionary and value.get("version") == DynastyCareerSave.RAW_TIER_VERSION:
		return DynastyCareerSave.decode_raw(value)
	if value is Dictionary and _integer(
		value.get("version"), LeagueCareerSave.VERSION, LeagueCareerSave.VERSION
	):
		return LeagueCareerSave.decode(value)
	if LeagueCareerSave.contains_mixed_career(value):
		return null
	var ac02_token: int = AC02_PASSIVE_15.enter("season_save._decode")
	var ac02_result: SeasonState = _ac02_passive_15_private_decode(value)
	AC02_PASSIVE_15.leave(ac02_token)
	return ac02_result


static func _ac02_passive_15_private_decode(value: Variant) -> SeasonState:
	if value is Dictionary and _integer(value.get("version"), 80, 80):
		var fields: Array = ["version", "access", "inventory_rules", "checkpoint"]
		if value.has("dynasty_start"):
			if not value.dynasty_start is Dictionary:
				return null
			fields.append("dynasty_start")
		if (
			not SeasonOwnership._keys(value, fields)
			or not value.checkpoint is Dictionary
			or not _integer(value.checkpoint.get("version"), 75, 77)
			or not value.inventory_rules is Dictionary
			or (
				not value.inventory_rules.is_empty()
				and not SeasonInventoryRules.valid(value.inventory_rules)
			)
		):
			return null
		var access: Dictionary = ClosedContentAccess.normalize(value.access)
		if access.is_empty():
			return null
		return _decode_closed_league(
			value.checkpoint, value.inventory_rules, value.get("dynasty_start"), access
		)
	if value is Dictionary and _integer(value.get("version"), 79, 79):
		if (
			not SeasonOwnership._keys(
				value, ["version", "dynasty_start", "inventory_rules", "checkpoint"]
			)
			or not value.dynasty_start is Dictionary
			or not value.inventory_rules is Dictionary
			or (
				not value.inventory_rules.is_empty()
				and not SeasonInventoryRules.valid(value.inventory_rules)
			)
			or not value.checkpoint is Dictionary
			or not _integer(value.checkpoint.get("version"), 75, 76)
		):
			return null
		return _decode_closed_league(value.checkpoint, value.inventory_rules, value.dynasty_start)
	if value is Dictionary and _integer(value.get("version"), 78, 78):
		if (
			not SeasonOwnership._keys(value, ["version", "inventory_rules", "checkpoint"])
			or not SeasonInventoryRules.valid(value.inventory_rules)
			or not value.checkpoint is Dictionary
			or not _integer(value.checkpoint.get("version"), 76, 77)
		):
			return null
		return _decode_closed_league(value.checkpoint, value.inventory_rules)
	if SeasonInventoryRules.contains(value):
		return null
	if value is Dictionary and _integer(value.get("version"), 75, 77):
		return _decode_closed_league(value)
	if value is Dictionary and _integer(value.get("version"), 74, 74):
		return _decode_terrain(value)
	if value is Dictionary and _integer(value.get("version"), 73, 73):
		return _decode_surface_time(value)
	if value is Dictionary and _integer(value.get("version"), 72, 72):
		return _decode_surface_night(value)
	return _decode_payload(value)


static func _closed_league_shape(season: SeasonState) -> bool:
	if not SeasonInventoryRules.consistent(season) or season.opponents == null:
		return false
	for club: Dictionary in season.opponents.clubs.values():
		if (
			not club.get("build") is SeasonBuild
			or not club.build.league_context_valid()
			or club.build._league_rules != season.league_rules
			or club.build._market != 12
		):
			return false
	return (
		not LeagueRules.normalized(season.league_rules).is_empty()
		and (season.career == null or ClubLeagueCareer.admitted(season))
		and (season.player_access.is_empty() or ClubPlayerDraft.frozen_matches(season))
		and season.home_property.is_empty()
		and season.npc_venues.is_empty()
		and season.final_venue.is_empty()
		and season.owned_surface_night.is_empty()
		and (season.league_live or season.player_results.is_empty())
		and season.build != null
		and season.build.league_context_valid()
		and season.build._league_rules == season.league_rules
		and season.opponents != null
		and season.opponents._format == 13
		and season.physical != null
		and (
			season.league_live
			or (
				season.physical.reports.is_empty()
				and season.physical.pending.is_empty()
				and season.physical.cursor == 0
			)
		)
	)


static func _decode_closed_league(
	value: Dictionary,
	inventory_rules: Dictionary = {},
	dynasty_start: Variant = null,
	access: Dictionary = {},
	league_career: ClubCareer = null,
	player_access: Array = [],
	normal_home: Dictionary = {},
	pitch_catalog: String = "",
	pitch_admission: int = 0
) -> SeasonState:
	if not normal_home.is_empty() and (normal_home.get("format") not in [93, 94] or league_career == null):
		return null
	if normal_home.get("format") == 94 and (not SeasonOwnership._keys(normal_home, ["format", "header"]) \
		or not load("res://src/gameplay/season/normal_league_time_candidate.gd")._header_valid(normal_home.header)):
		return null
	var fields: Array = ["version", "league_rules", "checkpoint"]
	if not player_access.is_empty():
		fields.append("owned_draft")
		if not ClubPlayerCatalog.valid_ids(player_access) \
			or value.get("owned_draft") != OwnedDraftSave.marker(player_access):
			return null
	if not SeasonOwnership._keys(value, fields):
		return null
	var rules: Dictionary = LeagueRules.normalized(value.league_rules)
	if not player_access.is_empty() and LeagueRules.dynasty(rules):
		return null
	var data: Variant = value.checkpoint
	var owner_tier: bool = value.get("version") == DynastyCareerSave.TIER_CHECKPOINT_VERSION
	var tiered: bool = owner_tier or value.get("version") == LeagueCareerSave.TIER_CHECKPOINT_VERSION
	if tiered != LeagueRules.tiered(rules) or (
		tiered and not owner_tier and league_career == null
	) or (owner_tier and (access.is_empty() or league_career != null)):
		return null
	if league_career != null and (
		not ClubLeagueCareer.rules_valid(rules, data.get("seed") if data is Dictionary else null)
		or league_career.current <= 0
		or league_career.current != league_career.runs.size()
		or not ClubCareer.same(league_career.runs[-1].get("league_rules"), rules)
		or not access.is_empty()
		or dynasty_start != null
		or not OwnedDraftSave.version_in(
			value.version, [76, 77, LeagueCareerSave.TIER_CHECKPOINT_VERSION])
		or not data is Dictionary
		or data.has("career")
	):
		return null
	if LeagueRules.dynasty(rules) != (dynasty_start != null):
		return null
	if (
		dynasty_start != null
		and (
			not dynasty_start is Dictionary
			or (
				not dynasty_start.is_empty()
				and (
					preload("res://src/gameplay/season/dynasty_start_profile.gd")
					. normalize(dynasty_start)
					. is_empty()
				)
			)
		)
	):
		return null
	if dynasty_start != null and not ClubCareer.same(dynasty_start.get("access", {}), access):
		return null
	if (
		not access.is_empty()
		and (
			ClosedContentAccess.normalize(access).is_empty()
			or not data is Dictionary
			or not data.get("build") is Dictionary
			or not ClosedContentAccess.matches_data(data.build, access)
		)
	):
		return null
	if not tiered and (
		(value.version == 77) != (LeagueRules.doubleheader(rules) and value.version != 75)
	):
		return null
	if (
		rules.is_empty()
		or not data is Dictionary
		or not LeagueRules.season_matches(rules, data.get("seed"))
		or data.get("version") != 57
		or not data.get("results") is Array
		or (value.version == 75 and not data.results.is_empty())
		or not data.get("build") is Dictionary
		or LeagueRules.normalized(data.build.get("league_rules")) != rules
	):
		return null
	var season: SeasonState = Operations1._ac02_passive_15_private_decode_payload_terrain(
		data,
		normal_home.get("header", {}).get("owned_surface_night", {}) if normal_home.get("format") == 94 else {},
		false,
		rules,
		int(value.version) in [76, 77, LeagueCareerSave.TIER_CHECKPOINT_VERSION,
			DynastyCareerSave.TIER_CHECKPOINT_VERSION],
		inventory_rules,
		dynasty_start,
		access,
		league_career,
		player_access, {}, normal_home, null, pitch_catalog, pitch_admission
	)
	var shape: SeasonState = season
	if season != null and not normal_home.is_empty():
		shape = load("res://src/gameplay/season/normal_league_time_candidate.gd").detached(season) if normal_home.get("format") == 94 \
			else load("res://src/gameplay/season/normal_league_home.gd").detached(season)
	return season if shape != null and _closed_league_shape(shape) else null


# The explicit wrapper selects the unchanged day/economy validator before any replay.
# This is not a legacy migration: old envelopes cannot carry the new family.
static func _decode_surface_night(value: Dictionary) -> SeasonState:
	if (
		not value.get("owned_surface_night") is Dictionary
		or not _integer(
			value.owned_surface_night.get("version"),
			StadiumSurfaceNightSnapshot.VERSION,
			StadiumSurfaceNightSnapshot.VERSION
		)
	):
		return null
	if (
		not _integer(value.get("legacy_save_version"), 59, 71)
		or not StadiumSurfaceNightSnapshot.policy_shape(value.get("owned_surface_night"))
		or value.has("ownership")
	):
		return null
	var data: Dictionary = value.duplicate(true)
	var policy: Dictionary = data.owned_surface_night.duplicate(true)
	data.version = int(data.legacy_save_version)
	data.erase("legacy_save_version")
	data.erase("owned_surface_night")
	return _decode_payload(data, policy)


static func _decode_payload(value: Variant, night_policy: Dictionary = {}) -> SeasonState:
	return _decode_payload_terrain(value, night_policy, false)


static func _decode_payload_terrain(
	value: Variant, night_policy: Dictionary, terrain_authorized: bool
) -> SeasonState:
	var ac02_token: int = AC02_PASSIVE_15.enter("season_save._decode_payload_terrain")
	var ac02_result: SeasonState = _ac02_passive_15_private_decode_payload_terrain(
		value, night_policy, terrain_authorized
	)
	AC02_PASSIVE_15.leave(ac02_token)
	return ac02_result


static func _ac02_passive_15_private_decode_payload_terrain(
	value: Variant,
	night_policy: Dictionary,
	terrain_authorized: bool,
	expected_rules: Dictionary = {},
	league_live: bool = false,
	inventory_rules: Dictionary = {},
	dynasty_start: Variant = null,
	access: Dictionary = {},
	league_career: ClubCareer = null,
	player_access: Array = []
) -> SeasonState:
	return Operations1._ac02_passive_15_private_decode_payload_terrain(
		value,
		night_policy,
		terrain_authorized,
		expected_rules,
		league_live,
		inventory_rules,
		dynasty_start,
		access,
		league_career,
		player_access
	)


static func _legacy_d1_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return (
		career != null
		and career.current == 0
		and data.get("career") is Dictionary
		and career.standard_version() == 23
		and SeasonOwnership._keys(
			data,
			[
				"version",
				"ownership",
				"seed",
				"picks",
				"results",
				"lineup",
				"starter",
				"fielder",
				"pool",
				"difficulty",
				"draws",
				"strengths",
				"career"
			]
		)
	)


static func _decode_legacy_d1(data: Dictionary) -> SeasonState:
	var career: ClubCareer = ClubCareer.from_data(data.get("career"))
	if not _legacy_d1_envelope_valid(data, career):
		return null
	var legacy: Dictionary = data.duplicate(true)
	legacy.version = 4
	legacy.erase("career")
	# Reuse the frozen save4 ownership/result checks without admitting career23 to
	# any old envelope. Only the already-validated explicit68 branch reattaches it.
	var season: SeasonState = _decode(legacy)
	if season == null:
		return null
	season.career = career
	if not career.matches(season) or not ClubPlayerDraft.matches(season):
		return null
	return season


# A career24 remains explicit69 even when its owner selects the old non-progression mode.
# The empty rule is only an envelope discriminator; the old save4 semantics stay exact.
static func _legacy_d2_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return (
		career != null
		and career.current == 0
		and data.get("career") is Dictionary
		and career.standard_version() == 24
		and data.get("draft_rule") is String
		and data.draft_rule.is_empty()
		and SeasonOwnership._keys(
			data,
			[
				"version",
				"ownership",
				"seed",
				"picks",
				"results",
				"lineup",
				"starter",
				"fielder",
				"pool",
				"difficulty",
				"draws",
				"strengths",
				"career",
				"draft_rule"
			]
		)
	)


static func _decode_legacy_d2(data: Dictionary) -> SeasonState:
	var career: ClubCareer = ClubCareer.from_data(data.get("career"))
	if not _legacy_d2_envelope_valid(data, career):
		return null
	var legacy: Dictionary = data.duplicate(true)
	legacy.version = 4
	legacy.erase("career")
	legacy.erase("draft_rule")
	var season: SeasonState = _decode(legacy)
	if season == null:
		return null
	season.career = career
	if not career.matches(season) or not ClubPlayerDraft.matches(season):
		return null
	return season


# Career25 remains explicit70 even in the old non-progression mode. Neither
# envelope rule installs a build/bank or changes the underlying save4 replay.
static func _legacy_d3_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return (
		career != null
		and career.current == 0
		and data.get("career") is Dictionary
		and career.standard_version() == 25
		and data.get("draft_rule") is String
		and data.draft_rule.is_empty()
		and data.get("sponsor_rule") is String
		and data.sponsor_rule.is_empty()
		and SeasonOwnership._keys(
			data,
			[
				"version",
				"ownership",
				"seed",
				"picks",
				"results",
				"lineup",
				"starter",
				"fielder",
				"pool",
				"difficulty",
				"draws",
				"strengths",
				"career",
				"draft_rule",
				"sponsor_rule"
			]
		)
	)


static func _decode_legacy_d3(data: Dictionary) -> SeasonState:
	var career: ClubCareer = ClubCareer.from_data(data.get("career"))
	if not _legacy_d3_envelope_valid(data, career):
		return null
	var legacy: Dictionary = data.duplicate(true)
	legacy.version = 4
	legacy.erase("career")
	legacy.erase("draft_rule")
	legacy.erase("sponsor_rule")
	var season: SeasonState = _decode(legacy)
	if season == null:
		return null
	season.career = career
	if not career.matches(season) or not ClubPlayerDraft.matches(season):
		return null
	return season


# Save70 joins active D3 sponsor terms before replay. Later old-tier runs keep
# their exact old build/bank semantics while retaining the validated D3 history.
# Career26 retains the old non-progression payload through explicit Save71.
static func _legacy_d4_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return (
		career != null
		and career.current == 0
		and data.get("career") is Dictionary
		and career.standard_version() == 26
		and data.get("draft_rule") is String
		and data.draft_rule.is_empty()
		and data.get("sponsor_rule") is String
		and data.sponsor_rule.is_empty()
		and SeasonOwnership._keys(
			data,
			[
				"version",
				"ownership",
				"seed",
				"picks",
				"results",
				"lineup",
				"starter",
				"fielder",
				"pool",
				"difficulty",
				"draws",
				"strengths",
				"career",
				"draft_rule",
				"sponsor_rule"
			]
		)
	)


static func _decode_legacy_d4(data: Dictionary) -> SeasonState:
	var career: ClubCareer = ClubCareer.from_data(data.get("career"))
	if not _legacy_d4_envelope_valid(data, career):
		return null
	var legacy: Dictionary = data.duplicate(true)
	legacy.version = 4
	legacy.erase("career")
	legacy.erase("draft_rule")
	legacy.erase("sponsor_rule")
	var season: SeasonState = _decode(legacy)
	if season == null:
		return null
	season.career = career
	if not career.matches(season) or not ClubPlayerDraft.matches(season):
		return null
	return season


# Save71 joins exact D4 contexts before any draft or result replay; retained
# D4 history never retrofits timed terms into a lower-tier active season.
static func _standard_d4_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return Operations3._standard_d4_envelope_valid(data, career)


static func _standard_d3_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return Operations3._standard_d3_envelope_valid(data, career)


static func _standard_d2_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return Operations3._standard_d2_envelope_valid(data, career)


static func _standard_d1_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return Operations3._standard_d1_envelope_valid(data, career)


static func _standard_build_header(value: Variant, tier: int, market: int) -> bool:
	return Operations3._standard_build_header(value, tier, market)


static func _yard_replay_roster(result: Dictionary, historical: Array, human_home: bool) -> Array:
	return Operations3._yard_replay_roster(result, historical, human_home)


static func _home_replay_roster(proof: Dictionary, historical: Array) -> Array:
	return Operations3._home_replay_roster(proof, historical)


static func _build_history_valid(season: SeasonState, build: SeasonBuild) -> bool:
	return Operations3._build_history_valid(season, build)


static func _restore_pool(season: SeasonState, data: Dictionary) -> bool:
	return Operations3._restore_pool(season, data)


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return Operations3._integer(value, minimum, maximum)


static func _contains_surface_night(data: Dictionary) -> bool:
	return Operations3._contains_surface_night(data)


static func _night_report_row(value: Variant) -> bool:
	return Operations3._night_report_row(value)


static func _decode_surface_time(value: Dictionary) -> SeasonState:
	return Operations3._decode_surface_time(value)


static func _contains_terrain(data: Dictionary) -> bool:
	return Operations3._contains_terrain(data)


static func _terrain_report_row(row: Variant) -> bool:
	return Operations3._terrain_report_row(row)


static func _terrain_envelope(data: Dictionary) -> Dictionary:
	return Operations3._terrain_envelope(data)


static func _decode_terrain(value: Dictionary) -> SeasonState:
	return Operations3._decode_terrain(value)

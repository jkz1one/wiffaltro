extends "res://src/tests/ac02_receipt_legacy_season_save_fixture_base.gd"
static func _decode(value: Variant) -> SeasonState:
	if value is Dictionary and _integer(value.get("version"), 74, 74):
		return _decode_terrain(value)
	if value is Dictionary and _integer(value.get("version"), 73, 73):
		return _decode_surface_time(value)
	if value is Dictionary and _integer(value.get("version"), 72, 72):
		return _decode_surface_night(value)
	return _decode_payload(value)


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
	if not value is Dictionary:
		return null
	var data: Dictionary = value
	if not terrain_authorized and _contains_terrain(data):
		return null
	if (
		data.has("owned_surface_night")
		or data.has("legacy_save_version")
		or (night_policy.is_empty() and _contains_surface_night(data))
	):
		return null
	if not _integer(data.get("version"), 1, 71) or not _integer(data.get("seed"), 0, 2147483647):
		return null
	if data.version == 71 and data.has("ownership"):
		return _decode_legacy_d4(data)
	if data.version == 70 and data.has("ownership"):
		return _decode_legacy_d3(data)
	if data.version == 69 and data.has("ownership"):
		return _decode_legacy_d2(data)
	if data.version == 68 and data.has("ownership"):
		return _decode_legacy_d1(data)
	# Unknown ownership/storage fields require an explicit migration, never deletion.
	var allowed: Array[String] = [
		"version",
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
		"ownership",
		"build",
		"opponents",
		"career",
		"physical",
		"player_access",
		"home_property",
		"npc_venues",
		"final_venue"
	]
	if data.version == 70 or data.version == 71:
		allowed.append("sponsor_rule")
	if data.version == 69 or data.version == 70 or data.version == 71:
		allowed.append("draft_rule")
	if (data.version == 70 or data.version == 71) != data.has("sponsor_rule"):
		return null
	if (data.version == 69 or data.version == 70 or data.version == 71) != data.has("draft_rule"):
		return null
	if (
		data.version < 69
		and data.get("opponents") is Dictionary
		and data.opponents.has("draft_rule")
	):
		return null
	if (data.version >= 61) != data.has("npc_venues"):
		return null
	if (
		(
			data.version == 62
			or data.version == 63
			or data.version == 64
			or data.version == 65
			or data.version == 66
			or data.version == 67
			or data.version == 68
			or data.version == 69
			or data.version == 70
			or data.version == 71
		)
		!= data.has("final_venue")
	):
		return null
	var owned_pool: bool = (
		data.version == 60
		or (
			data.version >= 61
			and data.get("home_property") is Dictionary
			and data.home_property.get("version") == StadiumPoolOwnedSnapshot.VERSION
		)
	)
	if (data.version >= 59) != data.has("home_property"):
		return null
	var ordinary_property_save: bool = (
		data.version == 59
		or data.version == 61
		or data.version == 62
		or data.version == 63
		or data.version == 64
		or data.version == 65
		or data.version == 66
		or data.version == 67
		or data.version == 68
		or data.version == 69
		or data.version == 70
		or data.version == 71
	)
	if (
		ordinary_property_save
		and not owned_pool
		and (
			not StadiumLayoutSnapshot.valid(data.home_property)
			or (
				int(data.home_property.version)
				in [
					5,
					7,
					9,
					StadiumScoreboardSnapshot.FIXTURE_VERSION,
					StadiumMountedScoreboardSnapshot.FIXTURE_VERSION,
					StadiumLayoutSnapshot.TERRAIN_FIXTURE_VERSION,
					StadiumLowWallSnapshot.FIXTURE_VERSION,
					StadiumWaterfallAnimationSnapshot.FIXTURE_VERSION
				]
			)
			or StadiumNpcSnapshot.is_public(data.home_property)
			or StadiumSurfaceNightSnapshot.is_family(data.home_property)
		)
	):
		return null
	if (
		ordinary_property_save
		and not owned_pool
		and (
			data.home_property.get("version") == StadiumPoolOwnedSnapshot.VERSION
			or data.home_property.get("version") == StadiumPoolOwnedSnapshot.FIXTURE_VERSION
		)
	):
		return null
	if (
		owned_pool
		and (
			not StadiumPoolOwnedSnapshot.valid(data.home_property)
			or data.home_property.version != StadiumPoolOwnedSnapshot.VERSION
		)
	):
		return null
	if (data.version >= 58) != data.has("player_access"):
		return null
	if (
		data.version >= 58
		and (not data.has("career") or not ClubPlayerCatalog.valid_ids(data.player_access))
	):
		return null
	if (data.version >= 46) != data.has("physical"):
		return null
	if data.has("physical") and not data.has("opponents"):
		return null
	if data.has("opponents") and (data.version < 23 or not data.opponents is Dictionary):
		return null
	if data.has("career") and data.version < 4:
		return null
	if data.version < 68 and data.get("career") is Dictionary and data.career.get("version") == 23:
		return null
	if data.version < 71 and data.get("career") is Dictionary and data.career.get("version") == 26:
		return null
	if (
		data.version < 71
		and data.get("final_venue") is Dictionary
		and data.final_venue.get("selection") == SeasonFinalVenue.STANDARD_D4_SELECTION
	):
		return null
	if data.version < 70 and data.get("career") is Dictionary and data.career.get("version") == 25:
		return null
	if (
		data.version < 70
		and data.get("final_venue") is Dictionary
		and data.final_venue.get("selection") == SeasonFinalVenue.STANDARD_D3_SELECTION
	):
		return null
	if data.version < 69 and data.get("career") is Dictionary and data.career.get("version") == 24:
		return null
	if (
		data.version < 69
		and data.get("final_venue") is Dictionary
		and data.final_venue.get("selection") == SeasonFinalVenue.STANDARD_D2_SELECTION
	):
		return null
	if (
		data.version < 68
		and data.get("final_venue") is Dictionary
		and data.final_venue.get("selection") == SeasonFinalVenue.STANDARD_D1_SELECTION
	):
		return null
	for key: Variant in data:
		if not key is String or not allowed.has(key):
			return null
	if data["version"] < 4 and data.has("ownership"):
		return null
	if (data.version < 5 and data.has("build")) or (data.version >= 5 and data.has("ownership")):
		return null
	if not data.get("picks") is Array or data["picks"].size() > 4:
		return null
	if not data.get("results") is Array or data["results"].size() > 12:
		return null
	var season: SeasonState = SeasonState.create(
		int(data["seed"]), data["version"] == 1, data["version"] >= 5, data.has("opponents")
	)
	if data.has("opponents"):
		if not _integer(data.opponents.get("policy"), 1, 13):
			return null
		if (data.version >= 47) != (data.opponents.policy >= 3):
			return null
		var expected_policy: int = 13 if data.version >= 58 else int(data.version) - 44
		if data.version >= 47 and data.opponents.policy != expected_policy:
			return null
		# Choose the historical allocator before replaying even a partially completed draft.
		season.opponents._format = int(data.opponents.policy)
	if data.has("physical"):
		season.physical = SeasonPhysicalFixtures.from_data(data.physical)
		if season.physical == null:
			return null
	if data.version >= 58:
		season.player_access.assign(data.player_access)
	if data.version >= 59:
		season.home_property = StadiumLayoutSnapshot.normalized(data.home_property)
	var venue_career: ClubCareer
	if data.version >= 61:
		venue_career = ClubCareer.from_data(data.career)
		if (
			venue_career == null
			or venue_career.current <= 0
			or venue_career.runs[-1].seed != season.season_seed
		):
			return null
		if data.version == 68 or data.version == 69 or data.version == 70 or data.version == 71:
			if not (
				_standard_d4_envelope_valid(data, venue_career)
				if data.version == 71
				else (
					_standard_d3_envelope_valid(data, venue_career)
					if data.version == 70
					else (
						_standard_d2_envelope_valid(data, venue_career)
						if data.version == 69
						else _standard_d1_envelope_valid(data, venue_career)
					)
				)
			):
				return null
			# Pick4 reconstructs the build and initializes all five opponents. Establish
			# all validated rules before any draft or result/AI journal replay.
			if data.version == 69 or data.version == 70 or data.version == 71:
				season.opponents.draft_rule = data.draft_rule
			if venue_career.active_tier() == 4:
				if not season.build.enable_d4_sponsors():
					return null
			elif venue_career.active_tier() == 3:
				if not season.build.enable_d3_sponsors():
					return null
			elif venue_career.active_tier() > 0 and not season.build.enable_d1_pricing():
				return null
		season._npc_replay_run = venue_career.current
		season.npc_venues = SeasonVenues.normalized(
			data.npc_venues, season.season_seed, season._npc_replay_run
		)
		if season.npc_venues.is_empty():
			return null
		if (
			data.version == 62
			or data.version == 63
			or data.version == 64
			or data.version == 65
			or data.version == 66
			or data.version == 67
			or data.version == 68
			or data.version == 69
			or data.version == 70
			or data.version == 71
		):
			# Restore the exact advertised record before draft/result replay, never reroll it.
			season.final_venue = SeasonFinalVenue.normalized(
				data.final_venue, season.season_seed, season._npc_replay_run
			)
			var final_version: int = int(data.version) - 61
			if data.version == 68 or data.version == 69 or data.version == 70 or data.version == 71:
				final_version = (
					SeasonFinalVenue.GRAND_III_VERSION
					if venue_career.active_tier() == 4
					else (
						SeasonFinalVenue.GRAND_II_VERSION
						if venue_career.active_tier() >= 2
						else SeasonFinalVenue.GRAND_VERSION
					)
				)
			if season.final_venue.is_empty() or season.final_venue.version != final_version:
				return null
			if (
				season.final_venue.selection == SeasonFinalVenue.STANDARD_BASE_SELECTION
				and not SeasonFinalVenue.standard_base_context(season, venue_career)
			):
				return null
			if (
				season.final_venue.selection == SeasonFinalVenue.STANDARD_D1_SELECTION
				and not SeasonFinalVenue.standard_d1_context(season, venue_career)
			):
				return null
			if (
				season.final_venue.selection == SeasonFinalVenue.STANDARD_D4_SELECTION
				and not SeasonFinalVenue.standard_d4_context(season, venue_career)
			):
				return null
			if (
				season.final_venue.selection == SeasonFinalVenue.STANDARD_D3_SELECTION
				and not SeasonFinalVenue.standard_d3_context(season, venue_career)
			):
				return null
			if (
				season.final_venue.selection == SeasonFinalVenue.STANDARD_D2_SELECTION
				and not SeasonFinalVenue.standard_d2_context(season, venue_career)
			):
				return null
	if not night_policy.is_empty():
		var paid_career: ClubCareer = ClubCareer.from_data(data.get("career"))
		if paid_career == null or paid_career.current <= 0:
			return null
		season._pool_replay_ledger = ClubPlayers.assets(paid_career)
		season._npc_replay_run = paid_career.current
		season.owned_surface_night = StadiumSurfaceNightSnapshot.normalized_policy(night_policy)
		if not StadiumSurfaceNightSnapshot.valid_policy(
			night_policy, season, season._pool_replay_ledger
		):
			return null
	if owned_pool:
		var paid_career: ClubCareer = ClubCareer.from_data(data.career)
		if paid_career == null:
			return null
		season._pool_replay_ledger = ClubPlayers.assets(paid_career)
		if not StadiumPoolOwnedSnapshot.matches(season.home_property, season._pool_replay_ledger):
			return null
	if data["version"] >= 2:
		if not _restore_pool(season, data):
			return null
	for id: Variant in data["picks"]:
		if not id is String or not season.choose_player(id):
			return null
	if data["version"] >= 2:
		for index in range(6):
			var strength: Variant = data["strengths"][index]
			if not strength is float and not strength is int:
				return null
			if not is_finite(float(strength)) or strength < -1 or strength > 10:
				return null
			if (season.phase == SeasonState.Phase.DRAFT) != (strength == -1):
				return null
			if season.phase != SeasonState.Phase.DRAFT:
				season.teams[index]["strength"] = float(strength)
	var restored: SeasonBuild
	if data.version >= 5:
		var build_version: int = (
			(
				SeasonBuild.D4_VERSION
				if venue_career.active_tier() == 4
				else (
					SeasonBuild.D3_VERSION
					if venue_career.active_tier() == 3
					else (SeasonBuild.D1_VERSION if venue_career.active_tier() > 0 else 41)
				)
			)
			if (
				data.version == 68 or data.version == 69 or data.version == 70 or data.version == 71
			)
			else (41 if data.version >= 46 else int(data.version) - 4)
		)
		if not data.get("build") is Dictionary or data.build.get("version") != build_version:
			return null
		var roster: Array[String] = []
		if season.picks.size() == 4:
			roster.assign(season.picks)
		restored = SeasonBuild.from_data(
			data.build, season.season_seed, roster, season.draft_pool, season.recruit_blocked()
		)
		if restored == null or restored._market != 0:
			return null
	for result: Variant in data["results"]:
		if not result is Dictionary:
			return null
		for key in ["id", "away_runs", "home_runs"]:
			if not _integer(result.get(key), 0, 9999):
				return null
		var performance: Variant = result.get("performance", {}) if data["version"] >= 3 else {}
		if not performance is Dictionary or (result.has("performance") and performance.is_empty()):
			return null
		if restored != null:
			var actual_roster: Array = restored.roster_for_game(int(result.id))
			if actual_roster.size() != 4:
				return null
			if data.version >= 61 and result.has("yard_evidence"):
				var recorded_fixture: Dictionary = season.pending_fixture()
				if recorded_fixture.is_empty():
					return null
				actual_roster = _yard_replay_roster(
					result, actual_roster, recorded_fixture.home == 0
				)
				if actual_roster.is_empty():
					return null
			season.teams[0].roster = actual_roster
		var ai_tactics: Dictionary = {}
		if data.version >= 53:
			var fixture: Dictionary = season.pending_fixture()
			if fixture.is_empty():
				return null
			var index: int = fixture.away if fixture.home == 0 else fixture.home
			if (
				not result.get("ai_tactics") is Dictionary
				or not SeasonOwnership._keys(result.ai_tactics, [str(index)])
				or not result.ai_tactics[str(index)] is Dictionary
			):
				return null
			ai_tactics = result.ai_tactics[str(index)]
			if (
				data.version >= 61
				and fixture.home == 0
				and int(fixture.id) < 32
				and not result.has("yard_evidence")
				and not result.has("pool_evidence")
			):
				var home_roster: Array = _home_replay_roster(ai_tactics, season.teams[0].roster)
				if home_roster.is_empty():
					return null
				season.teams[0].roster = home_roster
		elif result.has("ai_tactics"):
			return null
		if data.version >= 54:
			season._heat_replay_team = PhysicalHeatEvidence.replay_team(
				restored, int(result.id), season.teams[0].roster
			)
			if season._heat_replay_team == null:
				return null
		var property_key: String = ""
		if data.version >= 59:
			if not result.get("property") is String:
				return null
			property_key = result.property
		elif result.has("property"):
			return null
		var replayed_tactics: Array = []
		if data.version >= 57:
			if not result.get("tactics", []) is Array:
				return null
			replayed_tactics = result.get("tactics", [])
		elif data.version >= 54 and ai_tactics.has("terminal"):
			if not result.get("tactics") is Array:
				return null
			replayed_tactics = result.tactics
		if not night_policy.is_empty():
			if not StadiumSurfaceNightHumanEvidence.replay_result(
				season, result, performance, ai_tactics, replayed_tactics, property_key
			):
				return null
		elif data.version >= 61:
			if not StadiumNpcYardTwoHumanEvidence.replay_result(
				season, result, performance, ai_tactics, replayed_tactics, property_key
			):
				return null
		elif result.has("yard_evidence"):
			return null
		elif data.version == 60:
			if not StadiumPoolOwnedHumanEvidence.replay_result(
				season, result, performance, ai_tactics, replayed_tactics, property_key
			):
				return null
		elif result.has("pool_evidence"):
			return null
		elif not season.record_player_result(
			int(result["id"]),
			int(result["away_runs"]),
			int(result["home_runs"]),
			performance,
			[],
			[],
			{},
			[],
			[],
			{},
			{},
			[],
			ai_tactics,
			replayed_tactics,
			property_key
		):
			return null
		season._heat_replay_team = null
		if result.has("used_gear"):
			if data.version < 14 or not result.used_gear is Array:
				return null
			season.player_results[-1]["used_gear"] = result.used_gear.duplicate()
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["used_gear"] = result.used_gear.duplicate()
		if result.has("tactics"):
			if data.version < 18 or not result.tactics is Array:
				return null
			season.player_results[-1]["tactics"] = result.tactics.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["tactics"] = result.tactics.duplicate(true)
		if result.has("batting"):
			if data.version < 33 or not result.batting is Dictionary:
				return null
			season.player_results[-1]["batting"] = result.batting.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["batting"] = result.batting.duplicate(true)
		if result.has("stances"):
			if data.version < 34 or not result.stances is Array:
				return null
			if not SeasonLeftRight.own_halves(result.stances, season.player_results[-1].home == 0):
				return null
			season.player_results[-1]["stances"] = result.stances.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["stances"] = result.stances.duplicate(true)
		if result.has("fielding"):
			if data.version < 35 or not result.fielding is Array:
				return null
			if not SeasonLeftRight.own_halves(result.fielding, season.player_results[-1].home != 0):
				return null
			season.player_results[-1]["fielding"] = result.fielding.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["fielding"] = result.fielding.duplicate(true)
		if result.has("pitching"):
			if data.version < 37 or not result.pitching is Dictionary:
				return null
			if not SeasonSureShot.own_halves(result.pitching, season.player_results[-1].home != 0):
				return null
			season.player_results[-1]["pitching"] = result.pitching.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["pitching"] = result.pitching.duplicate(true)
		if result.has("field_supply"):
			if data.version < 38 or not result.field_supply is Dictionary:
				return null
			season.player_results[-1]["field_supply"] = result.field_supply.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["field_supply"] = result.field_supply.duplicate(true)
		if result.has("frozen"):
			if data.version < 45 or not result.frozen is Array:
				return null
			if not SeasonLeftRight.own_halves(result.frozen, season.player_results[-1].home == 0):
				return null
			season.player_results[-1]["frozen"] = result.frozen.duplicate(true)
			for played: Dictionary in season.results:
				if played.id == result.id:
					played["frozen"] = result.frozen.duplicate(true)
	var lineup: Variant = data.get("lineup")
	if not lineup is Array:
		return null
	if season.picks.size() == 4:
		if lineup.size() != 4:
			return null
		var unique: Array = []
		var active: Array = season.picks if restored == null else restored.roster()
		for id: Variant in lineup:
			if not id is String or not active.has(id) or unique.has(id):
				return null
			unique.append(id)
		season.teams[0]["roster"] = unique
	elif not lineup.is_empty():
		return null
	if not _integer(data.get("starter"), 0, 3) or not _integer(data.get("fielder"), 0, 3):
		return null
	season.starter_index = int(data["starter"])
	season.fielder_index = int(data["fielder"])
	if season.starter_index == season.fielder_index:
		return null
	if data["version"] == 4:
		var owned: SeasonOwnership = SeasonOwnership.from_data(data.get("ownership"))
		# Production currently has result income only. Require the exact derived journal;
		# fixture items or invented rewards cannot enter a real season save.
		if owned == null or owned.to_data() != season.ownership.to_data():
			return null
		season.ownership = owned
	if restored != null:
		if not _build_history_valid(season, restored):
			return null
		restored.migrate()
		season.build = restored
	if data.has("opponents"):
		var expected: Variant = JSON.parse_string(JSON.stringify(season.opponents.to_data()))
		if JSON.parse_string(JSON.stringify(data.opponents)) != expected:
			return null
	if data.has("career"):
		season.career = (
			venue_career if venue_career != null else ClubCareer.from_data(data.career)
		)
		if season.career == null or not season.career.matches(season):
			return null
		if season.career.current > 0 and season.career.runs[-1].player_progress == null:
			season.career.runs[-1].player_progress = ClubPlayerProgress.capture(season)
		if not ClubPlayerDraft.matches(season):
			return null
		if (
			not season.home_property.is_empty()
			and not StadiumLayoutSnapshot.matches(
				season.home_property, ClubPlayers.assets(season.career)
			)
		):
			return null
		if not season.npc_venues.is_empty() and not SeasonVenues.matches_season(season):
			return null
		if (
			(data.version == 68 or data.version == 69 or data.version == 70 or data.version == 71)
			and not SeasonFinalVenue.matches_season(season)
		):
			return null
		# Recover only the current run from its validated, replayed purchase journal.
		if season.career.current > 0 and season.career.runs[-1].collection == null:
			season.career.runs[-1].collection = ClubCollection.acquired(season.build)
	elif (
		season.build != null
		and (
			season.build._gear_progress.enabled
			or season.build._sponsor_progress.enabled
			or season.build._order_start != null
			or season.build._rain_start != null
			or season.build._transfer_start != null
			or season.build._supply_start != null
			or season.build._checkout_start != null
			or season.build._association_start != null
			or season.build._freezer_start != null
			or season.build._sides_start != null
			or season.build._copy.start != null
			or season.build._major.start != null
			or season.build._abilities.start != null
			or season.build._field_start != null
			or season.build._sure_start != null
			or season.build._jump_start != null
			or season.build._batch_start != null
		)
	):
		return null
	if season.physical != null:
		if season.physical.cursor != season.physical.reports.size():
			return null
		if (
			not season.physical.pending.is_empty()
			and not SeasonRoundSettlement.valid_pending(season)
		):
			return null
		season.physical.projecting = false
	if (
		not night_policy.is_empty()
		and not StadiumSurfaceNightSnapshot.valid_policy(
			season.owned_surface_night, season, ClubPlayers.assets(season.career)
		)
	):
		return null
	season._pool_replay_ledger = null
	season._npc_replay_run = -1
	return season


# A retained career23 may still use the existing non-progression choice. This
# explicit68 branch has precisely the old save4 payload plus its validated career.
# No build, opponents, physical journals, price rules or venue context are admitted.
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
static func _decode_surface_time(value: Dictionary) -> SeasonState:
	if (
		not _integer(value.get("legacy_save_version"), 59, 71)
		or not value.get("owned_surface_night") is Dictionary
		or not _integer(
			value.owned_surface_night.get("version"),
			StadiumSurfaceNightSnapshot.TIME_VERSION,
			StadiumSurfaceNightSnapshot.TIME_VERSION
		)
		or not StadiumSurfaceNightSnapshot.policy_shape(value.owned_surface_night)
		or value.has("ownership")
	):
		return null
	var data: Dictionary = value.duplicate(true)
	var policy: Dictionary = data.owned_surface_night.duplicate(true)
	data.version = int(data.legacy_save_version)
	data.erase("legacy_save_version")
	data.erase("owned_surface_night")
	return _decode_payload(data, policy)


# The wrapper is required only after explicit adoption; no historical save is bumped.
static func _decode_terrain(value: Dictionary) -> SeasonState:
	if not _integer(value.get("terrain_save_version"), 4, 73) or not _contains_terrain(value):
		return null
	var data: Dictionary = value.duplicate(true)
	data.version = int(data.terrain_save_version)
	data.erase("terrain_save_version")
	var policy: Dictionary = {}
	if data.version in [72, 73]:
		var version: int = (
			StadiumSurfaceNightSnapshot.VERSION
			if data.version == 72
			else StadiumSurfaceNightSnapshot.TIME_VERSION
		)
		if (
			not _integer(data.get("legacy_save_version"), 59, 71)
			or not data.get("owned_surface_night") is Dictionary
			or not _integer(data.owned_surface_night.get("version"), version, version)
			or not StadiumSurfaceNightSnapshot.policy_shape(data.owned_surface_night)
			or StadiumLayoutSnapshot.is_terrain(data.get("home_property"))
			or data.has("ownership")
		):
			return null
		policy = data.owned_surface_night.duplicate(true)
		data.version = int(data.legacy_save_version)
		data.erase("owned_surface_night")
		data.erase("legacy_save_version")
	return _decode_payload_terrain(data, policy, true)
static func _read(file_path: String) -> SeasonState:
	if not FileAccess.file_exists(file_path):
		return null
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > 8 * 1024 * 1024:
		return null
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	return _decode(json.data) if parse_error == OK else null


static func _same_save_career(source: Variant, checked: ClubCareer) -> ClubCareer:
	# Private proof consumer: checked must come from this call's successful _decode.
	# Never reconstruct assets with to_data(), retain a cache, or authorize a cold
	# read here. Comparison includes every raw career field, including nested proof
	# and purchase history. A recovered/migrated value is not the original value.
	if (
		not source is Dictionary
		or not _integer(source.get("version"), 22, 26)
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

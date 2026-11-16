extends RefCounted
## Stateless operations for the original SeasonSave script.


static func _standard_d4_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	if (
		career == null
		or career.current <= 0
		or career.current != career.runs.size()
		or not data.get("career") is Dictionary
		or career.standard_version() != 26
		or career.runs[-1].seed != data.get("seed")
		or career.runs[-1].league != "standard"
		or not data.get("picks") is Array
		or data.picks.size() > 4
		or not data.get("physical") is Dictionary
		or not data.get("player_access") is Array
		or not data.get("home_property") is Dictionary
		or not data.get("npc_venues") is Dictionary
		or not data.get("final_venue") is Dictionary
		or not data.get("opponents") is Dictionary
		or not data.get("draft_rule") is String
		or not data.get("sponsor_rule") is String
	):
		return false
	var tier: int = career.active_tier()
	var priced_tier: int = tier if tier >= 3 else (1 if tier > 0 else 0)
	var sponsor_rule: String = (
		SeasonSponsorCatalog.D4_RULE
		if tier == 4
		else (SeasonSponsorCatalog.D3_RULE if tier == 3 else "")
	)
	var rule: String = SeasonOpponentDraft.D2_RULE if tier >= 2 else ""
	var final_version: int = (
		SeasonFinalVenue.GRAND_III_VERSION
		if tier == 4
		else (SeasonFinalVenue.GRAND_II_VERSION if tier >= 2 else SeasonFinalVenue.GRAND_VERSION)
	)
	var selection: String = (
		SeasonFinalVenue.STANDARD_D4_SELECTION
		if tier == 4
		else (
			SeasonFinalVenue.STANDARD_D3_SELECTION
			if tier == 3
			else (
				SeasonFinalVenue.STANDARD_D2_SELECTION
				if tier == 2
				else (
					SeasonFinalVenue.STANDARD_D1_SELECTION
					if tier == 1
					else SeasonFinalVenue.STANDARD_BASE_SELECTION
				)
			)
		)
	)
	if (
		tier not in [0, 1, 2, 3, 4]
		or data.draft_rule != rule
		or data.sponsor_rule != sponsor_rule
		or not SeasonSave._standard_build_header(data.get("build"), priced_tier, 0)
		or not SeasonSave._integer(data.opponents.get("policy"), 13, 13)
		or not data.opponents.get("clubs") is Dictionary
		or not SeasonSave._integer(
			data.npc_venues.get("version"), SeasonVenues.FIVE_VERSION, SeasonVenues.FIVE_VERSION
		)
		or not SeasonSave._integer(data.npc_venues.get("venue_ordinal"), tier, tier)
		or not SeasonSave._integer(data.final_venue.get("version"), final_version, final_version)
		or data.final_venue.get("league") != SeasonFinalVenue.GRAND_LEAGUE
		or data.final_venue.get("selection") != selection
	):
		return false
	if (
		(
			tier >= 2
			and (
				not data.opponents.get("draft_rule") is String or data.opponents.draft_rule != rule
			)
		)
		or (tier < 2 and data.opponents.has("draft_rule"))
	):
		return false
	if data.picks.size() < 4:
		return data.opponents.clubs.is_empty()
	if not SeasonOwnership._keys(data.opponents.clubs, ["1", "2", "3", "4", "5"]):
		return false
	for key: String in data.opponents.clubs:
		var club: Variant = data.opponents.clubs[key]
		if (
			not club is Dictionary
			or not SeasonSave._standard_build_header(club.get("build"), priced_tier, 12)
		):
			return false
	return true


static func _standard_d3_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	if (
		career == null
		or career.current <= 0
		or career.current != career.runs.size()
		or not data.get("career") is Dictionary
		or career.standard_version() != 25
		or career.runs[-1].seed != data.get("seed")
		or career.runs[-1].league != "standard"
		or not data.get("picks") is Array
		or data.picks.size() > 4
		or not data.get("physical") is Dictionary
		or not data.get("player_access") is Array
		or not data.get("home_property") is Dictionary
		or not data.get("npc_venues") is Dictionary
		or not data.get("final_venue") is Dictionary
		or not data.get("opponents") is Dictionary
		or not data.get("draft_rule") is String
		or not data.get("sponsor_rule") is String
	):
		return false
	var tier: int = career.active_tier()
	var priced_tier: int = 3 if tier == 3 else (1 if tier > 0 else 0)
	var sponsor_rule: String = SeasonSponsorCatalog.D3_RULE if tier == 3 else ""
	var rule: String = SeasonOpponentDraft.D2_RULE if tier >= 2 else ""
	var final_version: int = (
		SeasonFinalVenue.GRAND_II_VERSION if tier >= 2 else SeasonFinalVenue.GRAND_VERSION
	)
	var selection: String = (
		SeasonFinalVenue.STANDARD_D3_SELECTION
		if tier == 3
		else (
			SeasonFinalVenue.STANDARD_D2_SELECTION
			if tier == 2
			else (
				SeasonFinalVenue.STANDARD_D1_SELECTION
				if tier == 1
				else SeasonFinalVenue.STANDARD_BASE_SELECTION
			)
		)
	)
	if (
		tier not in [0, 1, 2, 3]
		or data.draft_rule != rule
		or data.sponsor_rule != sponsor_rule
		or not SeasonSave._standard_build_header(data.get("build"), priced_tier, 0)
		or not SeasonSave._integer(data.opponents.get("policy"), 13, 13)
		or not data.opponents.get("clubs") is Dictionary
		or not SeasonSave._integer(
			data.npc_venues.get("version"), SeasonVenues.FIVE_VERSION, SeasonVenues.FIVE_VERSION
		)
		or not SeasonSave._integer(data.npc_venues.get("venue_ordinal"), tier, tier)
		or not SeasonSave._integer(data.final_venue.get("version"), final_version, final_version)
		or data.final_venue.get("league") != SeasonFinalVenue.GRAND_LEAGUE
		or data.final_venue.get("selection") != selection
	):
		return false
	if (
		(
			tier >= 2
			and (
				not data.opponents.get("draft_rule") is String or data.opponents.draft_rule != rule
			)
		)
		or (tier < 2 and data.opponents.has("draft_rule"))
	):
		return false
	if data.picks.size() < 4:
		return data.opponents.clubs.is_empty()
	if not SeasonOwnership._keys(data.opponents.clubs, ["1", "2", "3", "4", "5"]):
		return false
	for key: String in data.opponents.clubs:
		var club: Variant = data.opponents.clubs[key]
		if (
			not club is Dictionary
			or not SeasonSave._standard_build_header(club.get("build"), priced_tier, 12)
		):
			return false
	return true


# Save69 joins the retained career24 to rules for the actual selected tier, never
# the highest unlocked tier. Canonical records and exact opponent regeneration follow.


static func _standard_d2_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	if (
		career == null
		or career.current <= 0
		or career.current != career.runs.size()
		or not data.get("career") is Dictionary
		or career.standard_version() != 24
		or career.runs[-1].seed != data.get("seed")
		or career.runs[-1].league != "standard"
		or not data.get("picks") is Array
		or data.picks.size() > 4
		or not data.get("physical") is Dictionary
		or not data.get("player_access") is Array
		or not data.get("home_property") is Dictionary
		or not data.get("npc_venues") is Dictionary
		or not data.get("final_venue") is Dictionary
		or not data.get("opponents") is Dictionary
		or not data.get("draft_rule") is String
	):
		return false
	var tier: int = career.active_tier()
	var priced_tier: int = 1 if tier > 0 else 0
	var rule: String = SeasonOpponentDraft.D2_RULE if tier == 2 else ""
	var final_version: int = (
		SeasonFinalVenue.GRAND_II_VERSION if tier == 2 else SeasonFinalVenue.GRAND_VERSION
	)
	var selection: String = (
		SeasonFinalVenue.STANDARD_D2_SELECTION
		if tier == 2
		else (
			SeasonFinalVenue.STANDARD_D1_SELECTION
			if tier == 1
			else SeasonFinalVenue.STANDARD_BASE_SELECTION
		)
	)
	if (
		tier not in [0, 1, 2]
		or data.draft_rule != rule
		or not SeasonSave._standard_build_header(data.get("build"), priced_tier, 0)
		or not SeasonSave._integer(data.opponents.get("policy"), 13, 13)
		or not data.opponents.get("clubs") is Dictionary
		or not SeasonSave._integer(
			data.npc_venues.get("version"), SeasonVenues.FIVE_VERSION, SeasonVenues.FIVE_VERSION
		)
		or not SeasonSave._integer(data.npc_venues.get("venue_ordinal"), tier, tier)
		or not SeasonSave._integer(data.final_venue.get("version"), final_version, final_version)
		or data.final_venue.get("league") != SeasonFinalVenue.GRAND_LEAGUE
		or data.final_venue.get("selection") != selection
	):
		return false
	if (
		(
			tier == 2
			and (
				not data.opponents.get("draft_rule") is String or data.opponents.draft_rule != rule
			)
		)
		or (tier != 2 and data.opponents.has("draft_rule"))
	):
		return false
	if data.picks.size() < 4:
		return data.opponents.clubs.is_empty()
	if not SeasonOwnership._keys(data.opponents.clubs, ["1", "2", "3", "4", "5"]):
		return false
	for key: String in data.opponents.clubs:
		var club: Variant = data.opponents.clubs[key]
		if (
			not club is Dictionary
			or not SeasonSave._standard_build_header(club.get("build"), priced_tier, 12)
		):
			return false
	return true


# Only the new career23 combination uses save68. Canonical venue/build validation
# and complete opponent regeneration still happen in the existing decode path.


static func _standard_d1_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	if (
		career == null
		or career.current <= 0
		or career.current != career.runs.size()
		or not data.get("career") is Dictionary
		or career.standard_version() != 23
		or career.runs[-1].seed != data.get("seed")
		or career.runs[-1].league != "standard"
		or not data.get("picks") is Array
		or data.picks.size() > 4
		or not data.get("physical") is Dictionary
		or not data.get("player_access") is Array
		or not data.get("home_property") is Dictionary
		or not data.get("npc_venues") is Dictionary
		or not data.get("final_venue") is Dictionary
		or not data.get("opponents") is Dictionary
	):
		return false
	var tier: int = career.active_tier()
	if (
		tier not in [0, 1]
		or not SeasonSave._standard_build_header(data.get("build"), tier, 0)
		or not SeasonSave._integer(data.opponents.get("policy"), 13, 13)
		or not data.opponents.get("clubs") is Dictionary
		or not SeasonSave._integer(
			data.npc_venues.get("version"), SeasonVenues.FIVE_VERSION, SeasonVenues.FIVE_VERSION
		)
		or not SeasonSave._integer(data.npc_venues.get("venue_ordinal"), tier, tier)
		or not SeasonSave._integer(
			data.final_venue.get("version"),
			SeasonFinalVenue.GRAND_VERSION,
			SeasonFinalVenue.GRAND_VERSION
		)
		or data.final_venue.get("league") != SeasonFinalVenue.GRAND_LEAGUE
		or (
			data.final_venue.get("selection")
			!= (
				SeasonFinalVenue.STANDARD_D1_SELECTION
				if tier == 1
				else SeasonFinalVenue.STANDARD_BASE_SELECTION
			)
		)
	):
		return false
	if data.picks.size() < 4:
		return data.opponents.clubs.is_empty()
	if not SeasonOwnership._keys(data.opponents.clubs, ["1", "2", "3", "4", "5"]):
		return false
	for key: String in data.opponents.clubs:
		var club: Variant = data.opponents.clubs[key]
		if (
			not club is Dictionary
			or not SeasonSave._standard_build_header(club.get("build"), tier, 12)
		):
			return false
	return true


static func _standard_build_header(value: Variant, tier: int, market: int) -> bool:
	if not value is Dictionary or not SeasonSave._integer(value.get("market"), market, market):
		return false
	if tier == 4:
		return (
			SeasonSave._integer(
				value.get("version"), SeasonBuild.D4_VERSION, SeasonBuild.D4_VERSION
			)
			and value.get("pricing_rule") is String
			and value.pricing_rule == SeasonBuild.D1_PRICE_RULE
			and value.get("sponsor_rule") is String
			and value.sponsor_rule == SeasonSponsorCatalog.D4_RULE
		)
	if tier == 3:
		return (
			SeasonSave._integer(
				value.get("version"), SeasonBuild.D3_VERSION, SeasonBuild.D3_VERSION
			)
			and value.get("pricing_rule") is String
			and value.pricing_rule == SeasonBuild.D1_PRICE_RULE
			and value.get("sponsor_rule") is String
			and value.sponsor_rule == SeasonSponsorCatalog.D3_RULE
		)
	if value.has("sponsor_rule"):
		return false
	if tier == 1:
		return (
			SeasonSave._integer(
				value.get("version"), SeasonBuild.D1_VERSION, SeasonBuild.D1_VERSION
			)
			and value.get("pricing_rule") is String
			and value.pricing_rule == SeasonBuild.D1_PRICE_RULE
		)
	return SeasonSave._integer(value.get("version"), 41, 41) and not value.has("pricing_rule")


static func _yard_replay_roster(result: Dictionary, historical: Array, human_home: bool) -> Array:
	# The build journal proves membership; the result records that game's batting order.
	# Full Yard/Heat/tactical validation still runs before this replay can be accepted.
	var evidence: Variant = result.get("yard_evidence")
	if (
		historical.size() != 4
		or not evidence is Dictionary
		or not evidence.get("teams") is Array
		or evidence.teams.size() != 2
	):
		return []
	var ordered: Variant = evidence.teams[1 if human_home else 0]
	if not ordered is Array or ordered.size() != 4:
		return []
	var roster: Array = []
	for id: Variant in ordered:
		if not id is String or not historical.has(id) or roster.has(id):
			return []
		roster.append(id)
	return roster


static func _home_replay_roster(proof: Dictionary, historical: Array) -> Array:
	# Current ordinary-home evidence records order; the build journal proves membership.
	# Full Base/Heat/stance chronology validation still follows this reconstruction.
	if (
		historical.size() != 4
		or not SeasonOwnership._whole(proof.get("version"), 5, 5)
		or not proof.get("opposition") is Dictionary
	):
		return []
	var ordered: Variant = proof.opposition.get("roster")
	if not ordered is Array or ordered.size() != 4:
		return []
	var roster: Array = []
	for id: Variant in ordered:
		if not id is String or not historical.has(id) or roster.has(id):
			return []
		roster.append(id)
	return roster


static func _build_history_valid(season: SeasonState, build: SeasonBuild) -> bool:
	if SeasonInventoryResale.enabled(build._bank):
		var fixture: Dictionary = season.pending_fixture()
		if not fixture.is_empty():
			var opponent: int = int(fixture.away if fixture.home == 0 else fixture.home)
			if not SeasonInventoryRules.fixture_prefixes(
				build, int(fixture.id), season.teams[opponent].roster, 0 if fixture.away == 0 else 1
			):
				return false
	var cursor: int = 0
	for event: Dictionary in build.to_data().events:
		if (
			event.op
			in [
				"pregame",
				"scout",
				"insure",
				"copy_select",
				"match_inventory",
				"match_sell",
				"match_supply_sell",
				SeasonInventoryRules.CLOSE_OP
			]
		):
			var expected: int = (
				int(season.player_results[cursor].id)
				if cursor < season.player_results.size()
				else int(season.pending_fixture().get("id", -1))
			)
			if event.game != expected:
				return false
			if event.op == "scout":
				var fixture: Dictionary = (
					season.player_results[cursor]
					if cursor < season.player_results.size()
					else season.pending_fixture()
				)
				if not SeasonFilmRoom.choices(season, fixture).has(event.recipe):
					return false
		elif event.op == "reward":
			var inventory_result_row: Dictionary = {}
			for inventory_played: Dictionary in season.player_results:
				if inventory_played.id == event.game:
					inventory_result_row = inventory_played
					break
			if (
				event.has("inventory_final") != inventory_result_row.has("inventory_final")
				or (
					event.has("inventory_final")
					and not ClubCareer.same(
						event.inventory_final, inventory_result_row.inventory_final
					)
				)
			):
				return false
			if cursor >= season.player_results.size():
				return false
			var result: Dictionary = season.player_results[cursor]
			if event.game != result.id or event.win != (SeasonState._winner(result) == 0):
				return false
			if LeagueRules.doubleheader(season.league_rules):
				if (
					not result.get("doubleheader_evidence") is Array
					or result.doubleheader_evidence.size() != 2
					or not ClubCareer.same(
						event.get("doubleheader_workload"),
						result.doubleheader_evidence[0 if result.away == 0 else 1]
					)
				):
					return false
			if LeagueRules.earnings(season.league_rules):
				var own: int = int(result.home_runs if result.home == 0 else result.away_runs)
				var opponent: int = int(result.away_runs if result.home == 0 else result.home_runs)
				if event.get("own_runs") != own or event.get("opponent_runs") != opponent:
					return false
			if event.get("used_gear", []) != result.get("used_gear", []):
				return false
			if event.get("tactics", []) != result.get("tactics", []):
				return false
			if event.get("batting", {}) != result.get("batting", {}):
				return false
			if event.get("stances", []) != result.get("stances", []):
				return false
			if event.get("field_supply", {}) != result.get("field_supply", {}):
				return false
			if not WorkingPitchCalledProof.same_retained(event, result):
				return false
			if event.get("pitching", {}) != result.get("pitching", {}):
				return false
			if event.get("fielding", []) != result.get("fielding", []):
				return false
			if not SeasonGapCommit.same(event.get("frozen", []), result.get("frozen", [])):
				return false
			if event.has("performance"):
				var saved: Variant = JSON.parse_string(JSON.stringify(event.performance))
				var actual: Variant = JSON.parse_string(
					JSON.stringify(result.get("performance", {}))
				)
				if saved != actual:
					return false
			cursor += 1
		elif event.op == "exotic_admit" and (build.pitch_catalog_current() or build.pitch_catalog_expanded()):
			# Final settlement may retain access, but never opens another shop.
			if event.proof.games.size() != cursor:
				return false
		elif cursor == season.player_results.size() and season.phase == SeasonState.Phase.COMPLETE:
			# Final income is retained, but creates no new purchasing window.
			return false
	return cursor == season.player_results.size() and (ExpandedExoticAccess.current_matches(season, build) if build.pitch_catalog_expanded() else (not build.pitch_catalog_current() or WorkingExoticAccess.current_matches(season, build)))


static func _restore_pool(season: SeasonState, data: Dictionary) -> bool:
	var pool: Variant = data.get("pool")
	if not pool is Array or pool.size() < (
		12 if data.version >= 58 or not season.player_access.is_empty() else 24
	) or pool.size() > 256:
		return false
	var ids: Array[String] = []
	for id: Variant in pool:
		if not id is String or ids.has(id) or id == String(PitchBatLab.DEBUG_PLAYER_ID):
			return false
		if not ContentDB.player_by_id.has(StringName(id)):
			return false
		ids.append(id)
	if not SeasonSave._integer(data.get("difficulty"), 0, 2):
		return false
	for key in ["draws", "strengths"]:
		if not data.get(key) is Array or data[key].size() != 6:
			return false
	for index in range(6):
		var draw: Variant = data["draws"][index]
		if not draw is float and not draw is int:
			return false
		if not is_finite(float(draw)) or draw < 0 or draw > 1:
			return false
		season.teams[index]["draw"] = float(draw)
	season.draft_pool = ids
	season.difficulty = int(data["difficulty"])
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= minimum
		and value <= maximum
		and float(value) == floorf(float(value))
	)


static func _contains_surface_night(data: Dictionary) -> bool:
	if StadiumSurfaceNightSnapshot.is_family(data.get("home_property")):
		return true
	var results: Variant = data.get("results", [])
	if results is Array:
		for row: Variant in results:
			if row is Dictionary and row.has("night_evidence"):
				return true
	var physical: Variant = data.get("physical", {})
	if not physical is Dictionary:
		return false
	var reports: Variant = physical.get("reports", [])
	if reports is Array:
		for row: Variant in reports:
			if SeasonSave._night_report_row(row):
				return true
	var pending: Variant = physical.get("pending", {})
	if pending is Dictionary:
		if pending.get("human") is Array and pending.human.size() == 18:
			return true
		if pending.get("reports") is Array:
			for row: Variant in pending.reports:
				if SeasonSave._night_report_row(row):
					return true
	return false


static func _night_report_row(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.get("report") is Dictionary
		and (
			SeasonSave._integer(
				value.report.get("version"),
				StadiumSurfaceNightReport.VERSION,
				StadiumSurfaceNightReport.VERSION
			)
			or value.report.has("night")
			or StadiumSurfaceNightSnapshot.is_family(value.report.get("property"))
		)
	)


# Policy2 is selected explicitly before the historical payload replays any result.


static func _decode_surface_time(value: Dictionary) -> SeasonState:
	if (
		not SeasonSave._integer(value.get("legacy_save_version"), 59, 71)
		or not value.get("owned_surface_night") is Dictionary
		or not SeasonSave._integer(
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
	return SeasonSave._decode_payload(data, policy)


# The wrapper is required only after explicit adoption; no historical save is bumped.


static func _contains_terrain(data: Dictionary) -> bool:
	if StadiumLayoutSnapshot.is_terrain(data.get("home_property")):
		return true
	var career: Variant = data.get("career")
	if (
		career is Dictionary
		and career.get("assets") is Dictionary
		and (
			SeasonSave._integer(
				career.assets.get("version"),
				ClubAssetLedger.TERRAIN_VERSION,
				ClubAssetLedger.TERRAIN_VERSION
			)
			or (
				SeasonSave._integer(
					career.assets.get("version"),
					ClubAssetLedger.FLAG_VERSION,
					ClubAssetLedger.PENNANT_VERSION
				)
				and ClubAssetLedger._has_terrain_events(career.assets.get("events"))
			)
		)
	):
		return true
	var physical: Variant = data.get("physical")
	if physical is Dictionary:
		var rows: Variant = physical.get("reports", [])
		if rows is Array:
			for row: Variant in rows:
				if SeasonSave._terrain_report_row(row):
					return true
		var pending: Variant = physical.get("pending")
		if pending is Dictionary and pending.get("reports") is Array:
			for row: Variant in pending.reports:
				if SeasonSave._terrain_report_row(row):
					return true
	return false


static func _terrain_report_row(row: Variant) -> bool:
	return (
		row is Dictionary
		and row.get("report") is Dictionary
		and (
			SeasonSave._integer(
				row.report.get("version"),
				PhysicalStadiumReport.TERRAIN_VERSION,
				PhysicalStadiumReport.TERRAIN_VERSION
			)
			or StadiumLayoutSnapshot.is_terrain(row.report.get("property"))
		)
	)


static func _terrain_envelope(data: Dictionary) -> Dictionary:
	if not SeasonSave._contains_terrain(data):
		return data
	if (
		StadiumLayoutSnapshot.is_terrain(data.get("home_property"))
		and data.has("owned_surface_night")
	):
		SeasonSave.last_error = "Owned dirt terrain requires an ordinary daylight season."
		return {}
	data["terrain_save_version"] = int(data.version)
	data.version = 74
	return data


# One closed74 envelope; only the already defined72/73 policy payloads are unpacked.


static func _decode_terrain(value: Dictionary) -> SeasonState:
	if (
		not SeasonSave._integer(value.get("terrain_save_version"), 4, 73)
		or not SeasonSave._contains_terrain(value)
	):
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
			not SeasonSave._integer(data.get("legacy_save_version"), 59, 71)
			or not data.get("owned_surface_night") is Dictionary
			or not SeasonSave._integer(data.owned_surface_night.get("version"), version, version)
			or not StadiumSurfaceNightSnapshot.policy_shape(data.owned_surface_night)
			or StadiumLayoutSnapshot.is_terrain(data.get("home_property"))
			or data.has("ownership")
		):
			return null
		policy = data.owned_surface_night.duplicate(true)
		data.version = int(data.legacy_save_version)
		data.erase("owned_surface_night")
		data.erase("legacy_save_version")
	return SeasonSave._decode_payload_terrain(data, policy, true)

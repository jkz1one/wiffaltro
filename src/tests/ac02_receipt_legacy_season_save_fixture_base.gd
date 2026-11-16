extends RefCounted

static var path: String = "user://season-v1.json"
static var last_error: String = ""


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= minimum
		and value <= maximum
		and float(value) == floorf(float(value))
	)


static func _legacy_d1_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return (
		career != null
		and career.current == 0
		and data.get("career") is Dictionary
		and _integer(data.career.get("version"), 23, 23)
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


static func _legacy_d2_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return (
		career != null
		and career.current == 0
		and data.get("career") is Dictionary
		and _integer(data.career.get("version"), 24, 24)
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


static func _legacy_d3_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return (
		career != null
		and career.current == 0
		and data.get("career") is Dictionary
		and _integer(data.career.get("version"), 25, 25)
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


static func _legacy_d4_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	return (
		career != null
		and career.current == 0
		and data.get("career") is Dictionary
		and _integer(data.career.get("version"), 26, 26)
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


static func _standard_build_header(value: Variant, tier: int, market: int) -> bool:
	if not value is Dictionary or not _integer(value.get("market"), market, market):
		return false
	if tier == 4:
		return (
			_integer(value.get("version"), SeasonBuild.D4_VERSION, SeasonBuild.D4_VERSION)
			and value.get("pricing_rule") is String
			and value.pricing_rule == SeasonBuild.D1_PRICE_RULE
			and value.get("sponsor_rule") is String
			and value.sponsor_rule == SeasonSponsorCatalog.D4_RULE
		)
	if tier == 3:
		return (
			_integer(value.get("version"), SeasonBuild.D3_VERSION, SeasonBuild.D3_VERSION)
			and value.get("pricing_rule") is String
			and value.pricing_rule == SeasonBuild.D1_PRICE_RULE
			and value.get("sponsor_rule") is String
			and value.sponsor_rule == SeasonSponsorCatalog.D3_RULE
		)
	if value.has("sponsor_rule"):
		return false
	if tier == 1:
		return (
			_integer(value.get("version"), SeasonBuild.D1_VERSION, SeasonBuild.D1_VERSION)
			and value.get("pricing_rule") is String
			and value.pricing_rule == SeasonBuild.D1_PRICE_RULE
		)
	return _integer(value.get("version"), 41, 41) and not value.has("pricing_rule")


static func _standard_d1_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	if (
		career == null
		or career.current <= 0
		or career.current != career.runs.size()
		or not data.get("career") is Dictionary
		or not _integer(data.career.get("version"), 23, 23)
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
		or not _standard_build_header(data.get("build"), tier, 0)
		or not _integer(data.opponents.get("policy"), 13, 13)
		or not data.opponents.get("clubs") is Dictionary
		or not _integer(
			data.npc_venues.get("version"), SeasonVenues.FIVE_VERSION, SeasonVenues.FIVE_VERSION
		)
		or not _integer(data.npc_venues.get("venue_ordinal"), tier, tier)
		or not _integer(
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
		if not club is Dictionary or not _standard_build_header(club.get("build"), tier, 12):
			return false
	return true


static func _standard_d2_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	if (
		career == null
		or career.current <= 0
		or career.current != career.runs.size()
		or not data.get("career") is Dictionary
		or not _integer(data.career.get("version"), 24, 24)
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
		or not _standard_build_header(data.get("build"), priced_tier, 0)
		or not _integer(data.opponents.get("policy"), 13, 13)
		or not data.opponents.get("clubs") is Dictionary
		or not _integer(
			data.npc_venues.get("version"), SeasonVenues.FIVE_VERSION, SeasonVenues.FIVE_VERSION
		)
		or not _integer(data.npc_venues.get("venue_ordinal"), tier, tier)
		or not _integer(data.final_venue.get("version"), final_version, final_version)
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
		if not club is Dictionary or not _standard_build_header(club.get("build"), priced_tier, 12):
			return false
	return true


# Only the new career23 combination uses save68. Canonical venue/build validation
# and complete opponent regeneration still happen in the existing decode path.
static func _standard_d3_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	if (
		career == null
		or career.current <= 0
		or career.current != career.runs.size()
		or not data.get("career") is Dictionary
		or not _integer(data.career.get("version"), 25, 25)
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
		or not _standard_build_header(data.get("build"), priced_tier, 0)
		or not _integer(data.opponents.get("policy"), 13, 13)
		or not data.opponents.get("clubs") is Dictionary
		or not _integer(
			data.npc_venues.get("version"), SeasonVenues.FIVE_VERSION, SeasonVenues.FIVE_VERSION
		)
		or not _integer(data.npc_venues.get("venue_ordinal"), tier, tier)
		or not _integer(data.final_venue.get("version"), final_version, final_version)
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
		if not club is Dictionary or not _standard_build_header(club.get("build"), priced_tier, 12):
			return false
	return true


# Save69 joins the retained career24 to rules for the actual selected tier, never
# the highest unlocked tier. Canonical records and exact opponent regeneration follow.
static func _standard_d4_envelope_valid(data: Dictionary, career: ClubCareer) -> bool:
	if (
		career == null
		or career.current <= 0
		or career.current != career.runs.size()
		or not data.get("career") is Dictionary
		or not _integer(data.career.get("version"), 26, 26)
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
		or not _standard_build_header(data.get("build"), priced_tier, 0)
		or not _integer(data.opponents.get("policy"), 13, 13)
		or not data.opponents.get("clubs") is Dictionary
		or not _integer(
			data.npc_venues.get("version"), SeasonVenues.FIVE_VERSION, SeasonVenues.FIVE_VERSION
		)
		or not _integer(data.npc_venues.get("venue_ordinal"), tier, tier)
		or not _integer(data.final_venue.get("version"), final_version, final_version)
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
		if not club is Dictionary or not _standard_build_header(club.get("build"), priced_tier, 12):
			return false
	return true


static func _terrain_report_row(row: Variant) -> bool:
	return (
		row is Dictionary
		and row.get("report") is Dictionary
		and (
			_integer(
				row.report.get("version"),
				PhysicalStadiumReport.TERRAIN_VERSION,
				PhysicalStadiumReport.TERRAIN_VERSION
			)
			or StadiumLayoutSnapshot.is_terrain(row.report.get("property"))
		)
	)


static func _contains_terrain(data: Dictionary) -> bool:
	if StadiumLayoutSnapshot.is_terrain(data.get("home_property")):
		return true
	var career: Variant = data.get("career")
	if (
		career is Dictionary
		and career.get("assets") is Dictionary
		and (
			_integer(
				career.assets.get("version"),
				ClubAssetLedger.TERRAIN_VERSION,
				ClubAssetLedger.TERRAIN_VERSION
			)
			or (
				_integer(
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
				if _terrain_report_row(row):
					return true
		var pending: Variant = physical.get("pending")
		if pending is Dictionary and pending.get("reports") is Array:
			for row: Variant in pending.reports:
				if _terrain_report_row(row):
					return true
	return false


static func _terrain_envelope(data: Dictionary) -> Dictionary:
	if not _contains_terrain(data):
		return data
	if (
		StadiumLayoutSnapshot.is_terrain(data.get("home_property"))
		and data.has("owned_surface_night")
	):
		last_error = "Owned dirt terrain requires an ordinary daylight season."
		return {}
	data["terrain_save_version"] = int(data.version)
	data.version = 74
	return data


# One closed74 envelope; only the already defined72/73 policy payloads are unpacked.
static func snapshot(season: SeasonState) -> Dictionary:
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
		data.version = 4 + season.build.to_data().version
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
	if career != null and data.career.version == 26:
		data.version = 71
		data["draft_rule"] = season.opponents.draft_rule if season.opponents != null else ""
		data["sponsor_rule"] = season.build._sponsor_rule if season.build != null else ""
		if not (
			_legacy_d4_envelope_valid(data, career)
			if career.current == 0
			else _standard_d4_envelope_valid(data, career)
		):
			last_error = (
				"The Standard tier and saved sponsor/draft/price/venue context do not match. "
				+ "The previous save was preserved."
			)
			return {}
	elif career != null and data.career.version == 25:
		# Save70 retains D3 history while active mode owns its exact inherited rules.
		data.version = 70
		data["draft_rule"] = season.opponents.draft_rule if season.opponents != null else ""
		data["sponsor_rule"] = season.build._sponsor_rule if season.build != null else ""
		if not (
			_legacy_d3_envelope_valid(data, career)
			if career.current == 0
			else _standard_d3_envelope_valid(data, career)
		):
			last_error = (
				"The Standard tier and saved sponsor/draft/price/venue context do not match. "
				+ "The previous save was preserved."
			)
			return {}
	elif career != null and data.career.version == 24:
		# Save69 persists after lower-tier replay; the selected tier still owns every rule.
		data.version = 69
		data["draft_rule"] = season.opponents.draft_rule if season.opponents != null else ""
		if not (
			_legacy_d2_envelope_valid(data, career)
			if career.current == 0
			else _standard_d2_envelope_valid(data, career)
		):
			last_error = (
				"The Standard tier and saved draft/price/venue context do not match. "
				+ "The previous save was preserved."
			)
			return {}
	elif career != null and data.career.version == 23:
		# Save68 is an explicit cross-record format, never final-version arithmetic.
		data.version = 68
		if (
			not (
				_legacy_d1_envelope_valid(data, career)
				if career.current == 0
				else _standard_d1_envelope_valid(data, career)
			)
			or data.get("opponents", {}).has("draft_rule")
		):
			last_error = (
				"The Standard tier and saved price/venue context do not match. "
				+ "The previous save was preserved."
			)
			return {}
	elif (
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
	return _terrain_envelope(data)


static func _build_history_valid(season: SeasonState, build: SeasonBuild) -> bool:
	var cursor: int = 0
	for event: Dictionary in build.to_data().events:
		if (
			event.op
			in ["pregame", "scout", "insure", "copy_select", "match_inventory", "match_sell"]
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
			if cursor >= season.player_results.size():
				return false
			var result: Dictionary = season.player_results[cursor]
			if event.game != result.id or event.win != (SeasonState._winner(result) == 0):
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
		elif cursor == season.player_results.size() and season.phase == SeasonState.Phase.COMPLETE:
			# Final income is retained, but creates no new purchasing window.
			return false
	return cursor == season.player_results.size()


static func _night_report_row(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.get("report") is Dictionary
		and (
			_integer(
				value.report.get("version"),
				StadiumSurfaceNightReport.VERSION,
				StadiumSurfaceNightReport.VERSION
			)
			or value.report.has("night")
			or StadiumSurfaceNightSnapshot.is_family(value.report.get("property"))
		)
	)


# Policy2 is selected explicitly before the historical payload replays any result.
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
			if _night_report_row(row):
				return true
	var pending: Variant = physical.get("pending", {})
	if pending is Dictionary:
		if pending.get("human") is Array and pending.human.size() == 18:
			return true
		if pending.get("reports") is Array:
			for row: Variant in pending.reports:
				if _night_report_row(row):
					return true
	return false


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


static func _restore_pool(season: SeasonState, data: Dictionary) -> bool:
	var pool: Variant = data.get("pool")
	if not pool is Array or pool.size() < (12 if data.version >= 58 else 24) or pool.size() > 256:
		return false
	var ids: Array[String] = []
	for id: Variant in pool:
		if not id is String or ids.has(id) or id == String(PitchBatLab.DEBUG_PLAYER_ID):
			return false
		if not ContentDB.player_by_id.has(StringName(id)):
			return false
		ids.append(id)
	if not _integer(data.get("difficulty"), 0, 2):
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

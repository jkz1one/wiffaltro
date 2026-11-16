class_name CurrentPhysicalStadiumEvidence
extends RefCounted
## Internal venue components for Report29. Context is supplied by its admitted boundary,
## never obtained from a venue's own fields. Legacy public validators remain context-free.
# gdlint: disable=max-returns


static func context_valid(context: Dictionary) -> bool:
	return SeasonOwnership._keys(context, ["pitch_catalog", "league_rules", "ownership"]) \
		and context.pitch_catalog is String and not context.pitch_catalog.is_empty() and PhysicalPitchEvidence.context_valid(context.pitch_catalog) \
		and context.league_rules is Dictionary and context.ownership is Array \
		and (context.pitch_catalog == WorkingPitchCatalog.signature() or context.league_rules.is_empty()) \
		and (context.ownership.is_empty() if context.league_rules.is_empty()
			else context.ownership.size() == 2)


static func for_state(state: MatchState) -> Dictionary:
	return {"pitch_catalog": state.pitch_catalog, "league_rules": state.league_rules,
		"ownership": [] if state.league_rules.is_empty() else
		[state.away_team.league_ownership, state.home_team.league_ownership]}


static func for_report(value: Dictionary, pitch_catalog: String) -> Dictionary:
	return {"pitch_catalog": pitch_catalog, "league_rules": value.league_rules,
		"ownership": [] if value.league_rules.is_empty() else value.ownership}


static func base_valid(value: Variant, context: Dictionary) -> bool:
	if context.is_empty():
		return PhysicalMatchReport.valid(value)
	return context_valid(context) and value is Dictionary \
		and PhysicalMatchReport._valid_core(value, context.league_rules, context.ownership,
			LeagueRules.doubleheader(context.league_rules), context.pitch_catalog)


static func capture_base(lab: PitchBatLab, context: Dictionary) -> Dictionary:
	if not is_instance_valid(lab) or lab._match_state == null:
		return {}
	var state: MatchState = lab._match_state
	if context.is_empty():
		return PhysicalMatchReport._capture_core(lab) if state.pitch_catalog.is_empty() else {}
	if not context_valid(context) or not ClubCareer.same(context, for_state(state)):
		return {}
	var result: Dictionary = PhysicalMatchReport._capture_core(lab)
	result["current_pitch_bound"] = context.pitch_catalog
	if not state.league_rules.is_empty():
		result["league_bound"] = true
	if LeagueRules.doubleheader(state.league_rules):
		result["doubleheader_bound"] = true
	return result


static func supported(snapshot: Dictionary) -> bool:
	if snapshot.is_empty() or not StadiumLayoutSnapshot.valid(snapshot):
		return false
	if StadiumNpcSnapshot.is_public(snapshot):
		return PhysicalStadiumReport.npc_resolver(snapshot) not in ["",
			StadiumNpcYardTwoReport.RESOLVER, StadiumNpcYardThreeReport.RESOLVER]
	return true


static func capture(lab: PitchBatLab) -> Dictionary:
	if not is_instance_valid(lab) or lab._match_state == null \
		or not supported(lab._match_state.stadium):
		return {}
	var context: Dictionary = for_state(lab._match_state)
	if not context_valid(context):
		return {}
	var result: Dictionary = PhysicalMatchReport._ac02_passive_10_capture(lab, context)
	return result if valid(result, context) else {}


static func valid(value: Variant, context: Dictionary) -> bool:
	if not context_valid(context) or not value is Dictionary \
		or not SeasonOwnership._whole(value.get("version"), 8, 26):
		return false
	match int(value.version):
		8, 9, 10, 11, 12, 13:
			return PhysicalStadiumReport._valid_context(value, context)
		14:
			return StadiumPoolOwnedReport._valid_context(value, context)
		17:
			return StadiumNpcPublicReport._valid_context(value, context)
		18:
			return StadiumLongYardPublicReport._valid_context(value, context)
		19:
			return StadiumGrandIPublicReport._valid_context(value, context)
		20:
			return StadiumGrandIIPublicReport._valid_context(value, context)
		21:
			return StadiumGrandIIIPublicReport._valid_context(value, context)
		22:
			return StadiumPoolPartyPublicReport._valid_context(value, context)
		23:
			return StadiumHillsidePublicReport._valid_context(value, context)
		24, 25:
			return StadiumSurfaceNightReport._valid_context(value, context)
		26:
			return PhysicalStadiumReport._terrain_valid_context(value, context)
	return false # Retired NPC15/16 require their own current admission review.


static func core(value: Dictionary, context: Dictionary) -> Dictionary:
	if not valid(value, context):
		return {}
	match int(value.version):
		14:
			return StadiumPoolOwnedReport._core(value)
		22:
			return StadiumPoolPartyPublicReport._core(value)
		17, 18, 19, 20, 21, 23:
			return StadiumNpcYardTwoReport._core(value)
		24:
			return StadiumSurfaceNightReport._core(value)
		25:
			return StadiumSurfaceNightReport._time_core(value)
	return PhysicalStadiumReport._core_validated(value)


static func matches(value: Dictionary, expected: Dictionary, context: Dictionary) -> bool:
	return valid(value, context) and supported(expected) \
		and StadiumLayoutSnapshot.key(value.property) == StadiumLayoutSnapshot.key(expected)


static func matches_source(value: Dictionary, season: SeasonState, fixture: Dictionary,
	state: MatchState) -> bool:
	if not matches(value, state.stadium, for_state(state)):
		return false
	if StadiumNpcSnapshot.is_public(state.stadium):
		return StadiumNpcSnapshot.matches_fixture(value.property, season, fixture)
	if StadiumSurfaceNightSnapshot.is_family(state.stadium):
		var ledger: ClubAssetLedger = StadiumSurfaceNightSnapshot.ledger(season)
		return ledger != null and StadiumSurfaceNightSnapshot.matches(state.stadium, ledger) \
			and StadiumSurfaceNightSnapshot.matches_fixture(value.property, season, fixture, ledger) \
			and ClubCareer.same(value.night,
				StadiumSurfaceNightSnapshot.proof(state.stadium, value.night.policy, ledger))
	if state.stadium.get("version") == StadiumPoolOwnedSnapshot.FIXTURE_VERSION:
		return StadiumPoolOwnedSnapshot.matches(state.stadium, StadiumPoolOwnedHumanEvidence.ledger(season)) \
			and value.seed == state.stadium.environment.seed
	return true

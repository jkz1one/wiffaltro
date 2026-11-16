extends "res://src/gameplay/season/dynasty_profile_contract.gd"
## Closed Dynasty source capture. The inherited contract retains exact semantic
## normalization/decay; these methods still replay the actual Build/Season source.

const _LINEAGE = preload("res://src/gameplay/season/dynasty_lineage.gd")


static func capture_build(
	build: SeasonBuild, lineage: String, owner: String, ordinal: int = 1
) -> Dictionary:
	if build == null or build._dynasty_start.has("access"):
		return {}
	var data: Dictionary = build.to_data()
	var checked: SeasonBuild = SeasonBuild.from_data(
		data, build._seed, build._initial_roster, build._pool, build._blocked
	)
	# Only the freshly replayed object is an extraction source. Mutable caches in
	# the supplied object cannot become checkpoint authority.
	return {} if checked == null else _capture(checked, lineage, owner, ordinal, "build-replay")


static func capture_season(
	value: Variant, lineage: String, owner: String, ordinal: int = 1
) -> Dictionary:
	var checked: SeasonState = SeasonSave._decode(value)
	if checked == null or checked.build == null or checked.picks.size() != 4:
		return {}
	return _capture(checked.build, lineage, owner, ordinal, "season-replay")


static func capture_access_season(
	value: Variant, lineage: String, owner: String, ordinal: int = 1
) -> Dictionary:
	# New owner access begins only at exact full career-season qualification.
	var checked: SeasonState = SeasonSave._decode(value)
	if (
		checked == null
		or checked.career == null
		or checked.build == null
		or checked.picks.size() != 4
		or ordinal != 1
		or not checked.career.matches(checked)
	):
		return {}
	var profile: Dictionary = (
		_capture(checked.build, lineage, owner, ordinal, "season-replay").duplicate(true)
	)
	var access: Dictionary = ClosedContentAccess._capture_checked(checked.career, value, owner)
	if profile.is_empty() or access.is_empty():
		return {}
	for id: String in profile.roster:
		if profile.players[id].temporary_fielding_slots != 1:
			return {}  # First admission is not the approved later-season forgetting transaction.
	profile.version = (WorkingPitchProgression.ACCESS_PROFILE_VERSION
		if profile.has("pitch_catalog") else ACCESS_VERSION)
	profile["access"] = access
	return normalize(profile)


static func _capture(
	build: SeasonBuild, lineage: String, owner: String, ordinal: int, authority: String
) -> Dictionary:
	if build.pitch_catalog_expanded() or LeagueRules.scramble(build._league_rules) or build.roster().size() != 4:
		return {}
	var inherited_start: Dictionary = build._book._dynasty_start
	if (
		not inherited_start.is_empty()
		and (
			inherited_start.lineage_id != lineage
			or inherited_start.owner_id != owner
			or inherited_start.season_ordinal != ordinal
		)
	):
		return {}
	var source_season: String = "%s:%d" % [lineage, ordinal]
	var players: Dictionary = {}
	for id: String in build.roster():
		var raw: Dictionary = build.player(id)
		var authored: Dictionary = SeasonPlayerCatalog.profile(id)
		if raw.is_empty() or raw.base != authored.base:
			return {}
		var trained: Dictionary = SeasonRetraining.points(build._book, id)
		var catchup_stats: Dictionary = {}
		for stat: String in SeasonPlayerCatalog.STATS:
			catchup_stats[stat] = (
				int(raw.stats[stat]) - int(authored.stats[stat]) - int(trained[stat])
			)
		var inherited: Dictionary = inherited_start.get("players", {}).get(id, {})
		var earned_mastery: Dictionary = {}
		var known: Dictionary = inherited.get("known_origin", {}).duplicate(true)
		for recipe: String in raw.mastery:
			earned_mastery[recipe] = int(inherited.get("earned_mastery", {}).get(recipe, 0))
			if authored.mastery.has(recipe):
				known[recipe] = {"source_season": "authored", "kind": "authored", "receipt": recipe}
		for event: Dictionary in build._book._events:
			if event.player == id and event.op in ["mastery", "round_out"]:
				earned_mastery[event.target] = int(earned_mastery.get(event.target, 0)) + 1
			var learned_recipe: String = ""
			if event.player == id and event.op == "learn":
				learned_recipe = event.target
			elif event.op == "exchange":
				if event.player == id:
					learned_recipe = event.second
				elif event.other == id:
					learned_recipe = event.first
			if not learned_recipe.is_empty() and not known.has(learned_recipe):
				known[learned_recipe] = {
					"source_season": source_season,
					"kind": "learn" if event.op == "learn" else "exchange",
					"receipt": event.id
				}
		var catchup_mastery: Dictionary = {}
		for recipe: String in raw.mastery:
			catchup_mastery[recipe] = (
				int(raw.mastery[recipe])
				- int(authored.mastery.get(recipe, 1))
				- int(earned_mastery[recipe])
			)
		var active_learning: Dictionary = {}
		var acquisitions: Dictionary = SeasonPitchExchange.learned(build._book, id)
		for recipe: String in acquisitions:
			var acquisition: Variant = acquisitions[recipe]
			active_learning[recipe] = (
				acquisition.duplicate(true)
				if acquisition is Dictionary
				else {"source_season": source_season, "receipt": acquisition}
			)
		var abilities: Array = []
		for receipt: Dictionary in build._abilities.learned.get(id, []):
			var retained: Dictionary = receipt.duplicate(true)
			# Runtime ability rows retain the ordinary four-field shape. Restore
			# their original season only from the matching validated start row.
			retained["source_season"] = source_season
			for previous: Dictionary in inherited.get("abilities", []):
				var original: Dictionary = previous.duplicate(true)
				original.erase("source_season")
				if same(original, receipt):
					retained.source_season = previous.source_season
					break
			abilities.append(retained)
		players[id] = {
			"authored":
			{"stats": authored.stats, "mastery": authored.mastery, "capacity": authored.capacity},
			"stats": raw.stats,
			"active": raw.active,
			"mastery": raw.mastery,
			"trained": trained,
			"catchup":
			{
				"origin": raw.get("catchup", {}).duplicate(true),
				"stats": catchup_stats,
				"mastery": catchup_mastery
			},
			"earned_mastery": earned_mastery,
			"known_origin": known,
			"active_learning": active_learning,
			"abilities": abilities,
			"temporary_fielding_slots": 2 if build._major.player == id else 1,
			"ever_earned": build._book.earned_players([id]).has(id)
		}
	var result: Dictionary = {
		"version": VERSION,
		"lineage_id": lineage,
		"owner_id": owner,
		"season_ordinal": ordinal,
		"seed": build._seed,
		"rule": rule(),
		"source":
		{
			"season_key": source_season,
			"seed": build._seed,
			"build_revision": build.revision(),
			"catalog": SeasonPlayerCatalog.signature(),
			"authority": authority
		},
		"roster": build.roster(),
		"players": players
	}
	if inherited_start.has("access"):
		if authority != "season-replay":
			return {}
		var access: Dictionary = ClosedContentAccess._fold_replayed(build, inherited_start.access)
		if access.is_empty():
			return {}
		result.version = ACCESS_VERSION
		result["access"] = access
	if build.pitch_catalog_current():
		result.version = (WorkingPitchProgression.ACCESS_PROFILE_VERSION
			if result.has("access") else WorkingPitchProgression.PROFILE_VERSION)
		result["pitch_catalog"] = WorkingPitchCatalog.signature()
	return normalize(result)


static func _capture_lineage_current(value: Variant, snapshot: Variant) -> Dictionary:
	var source: Dictionary = _LINEAGE.normalize(value)
	if (
		source.is_empty()
		or source.state == "closed"
		or (source.state == "paused" and source.resume_state != "active")
		or not snapshot is Dictionary
		or not whole(snapshot.get("version"), 79, 80)
	):
		return {}
	var season: SeasonState = SeasonSave._decode(snapshot)
	if (
		season == null
		or not LeagueRules.dynasty(season.league_rules)
		or not same(season._dynasty_start, source.start_profile)
		or season.build == null
		or season.season_seed != source.start_profile.seed
	):
		return {}
	# _decode has already replayed this exact Build; avoid a second full replay.
	var current: Dictionary = _capture(
		season.build, source.id, source.owner_id, int(source.ordinal), "season-replay"
	)
	if current.is_empty() or current.roster != source.start_profile.roster:
		return {}
	var data: Dictionary = season.build.to_data()
	var header: String = _LINEAGE._capture_header(data)
	var revision: int = season.build.revision()
	var previous: Dictionary = source.get("capture", {})
	if not previous.is_empty():
		if (
			revision < int(previous.revision)
			or header != previous.header_hash
			or _LINEAGE._capture_prefix(data, int(previous.revision)) != previous.prefix_hash
		):
			return {}
		if revision == int(previous.revision):
			return source if same(current, source.current_profile) else {}
	var next: Dictionary = source.duplicate(true)
	next.version = _LINEAGE.CAPTURE_VERSION
	next.current_profile = current
	next["capture"] = {
		"version": 1,
		"season_id": "%s:%d" % [source.id, int(source.ordinal)],
		"revision": revision,
		"header_hash": header,
		"prefix_hash": _LINEAGE._capture_prefix(data, revision),
		"profile_hash": _LINEAGE.fingerprint(current),
		"previous_revision": int(previous.get("revision", 0)),
		"previous_prefix": previous.get("prefix_hash", "")
	}
	return _LINEAGE.normalize(next)

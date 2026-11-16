class_name ClubPlayerProgress
extends RefCounted
## Compact human-club unlock evidence. Missing historic detail stays unknown, never invented.
# gdlint: disable=max-returns

const VERSION: int = 1
const HITS_VERSION: int = 2


static func capture_for(season: SeasonState, value: Variant) -> Dictionary:
	if WorkingPitchCareerProgress.is_current(value):
		return WorkingPitchCareerProgress.capture(season)
	if value is Dictionary and value.get("version") == ClubPlayerLegend.VERSION:
		return ClubPlayerLegend.capture(season)
	return (
		capture_with_hits(season)
		if value is Dictionary and value.get("version") == HITS_VERSION
		else capture(season)
	)


static func capture(season: SeasonState, current_pitches: bool = false) -> Dictionary:
	if season.build == null or season.build._market != 0:
		return {}
	var sponsors: Dictionary = _sponsor_counts(season.build)
	var development: Dictionary = _development(season.build, current_pitches)
	if development.is_empty():
		return {}
	var games: Array = []
	for game: Dictionary in season.player_results:
		var own: Array = game.get("club_roster", season.teams[0].roster)
		var stats: Variant = null
		if game.has("performance"):
			if not game.performance is Dictionary:
				return {}
			var source: Dictionary = game.performance
			if (
				source.size() != 8
				or own.size() != 4
				or not SeasonPerformance.valid(source, source.keys())
			):
				return {}
			stats = {"homers": 0, "hitters": 0, "strikeouts": 0, "three_k": 0}
			for id: String in own:
				if not source.has(id):
					return {}
				stats.homers += int(source[id].hr)
				stats.hitters += 1 if source[id].h > 0 else 0
				stats.strikeouts += int(source[id].p_k)
				stats.three_k += 1 if source[id].p_k >= 3 else 0
		# Pre-physical saves accepted score/stat combinations without this cross-check.
		# Preserve their original game journal, but do not infer any new stat unlocks.
		# Owned-player seasons and every physical season remain strictly validated.
		var own_runs: int = int(game.home_runs if game.home == 0 else game.away_runs)
		if (
			stats != null
			and stats.homers > own_runs
			and season.physical == null
			and season.player_access.is_empty()
		):
			stats = null
		var row: Dictionary = {
			"game": int(game.id),
			"stats": stats,
			"sponsors": int(sponsors.get(int(game.id), 0)),
			"end_half": -1,
			"deficit": 0
		}
		var proofs: Dictionary = game.get("ai_tactics", {})
		for proof: Dictionary in proofs.values():
			if not proof.has("base"):
				continue
			var flow: Dictionary = proof.base
			row.end_half = int(flow.final.half)
			for point: Dictionary in flow.ready:
				var deficit: int = int(
					point.away - point.home if game.home == 0 else point.home - point.away
				)
				row.deficit = maxi(row.deficit, deficit)
		games.append(row)
	var result: Dictionary = {"version": VERSION, "games": games, "development": development}
	return result if (WorkingPitchCareerProgress.valid_capture(result, ClubSeasonRecord.capture(season).scores) if current_pitches else valid(result, ClubSeasonRecord.capture(season).scores)) else {}


static func capture_with_hits(season: SeasonState, current_pitches: bool = false) -> Dictionary:
	# New runs opt into a new evidence schema; the original capture remains exact.
	# Historic missing/null game stats are still unknown and never get reconstructed.
	var result: Dictionary = capture(season, current_pitches)
	if result.is_empty():
		return {}
	for index in range(result.games.size()):
		var row: Dictionary = result.games[index]
		if row.stats == null:
			continue
		var game: Dictionary = season.player_results[index]
		var own: Array = game.get("club_roster", season.teams[0].roster)
		var source: Variant = game.get("performance")
		if (
			not source is Dictionary
			or source.size() != 8
			or own.size() != 4
			or not SeasonPerformance.valid(source, source.keys())
		):
			return {}
		var hits: int = 0
		var used: Dictionary = {}
		for id: String in own:
			if not source.has(id) or used.has(id):
				return {}
			used[id] = true
			hits += int(source[id].h)
		row.stats["hits"] = hits
	result.version = HITS_VERSION
	return result if (WorkingPitchCareerProgress.valid_capture(result, ClubSeasonRecord.capture(season).scores) if current_pitches else valid(result, ClubSeasonRecord.capture(season).scores)) else {}


static func _valid_with_hits(value: Dictionary, scores: Array) -> bool:
	if (
		not SeasonOwnership._keys(value, ["version", "games", "development"])
		or not value.games is Array
	):
		return false
	var legacy: Dictionary = value.duplicate(true)
	legacy.version = VERSION
	for row: Variant in legacy.games:
		if not row is Dictionary or not row.has("stats"):
			return false
		if row.stats == null:
			continue
		if (
			not row.stats is Dictionary
			or not SeasonOwnership._keys(
				row.stats, ["homers", "hitters", "strikeouts", "three_k", "hits"]
			)
			or not SeasonOwnership._whole(row.stats.hits, 0, 4 * 1000000)
			or not SeasonOwnership._whole(row.stats.homers, 0, 9999)
			or not SeasonOwnership._whole(row.stats.hitters, 0, 4)
			or row.stats.hits < row.stats.homers
			or row.stats.hits < row.stats.hitters
			or (row.stats.hits > 0) != (row.stats.hitters > 0)
		):
			return false
		row.stats.erase("hits")
	# Every original score, strikeout, sponsor, development and game constraint
	# still applies. A v1 record carrying hits or a relabeled v1 record is rejected.
	return valid(legacy, scores)


static func _sponsor_counts(build: SeasonBuild) -> Dictionary:
	var result: Dictionary = {}
	var bank: SeasonOwnership = build._bank.empty_fork()
	for event: Dictionary in build._bank._events:
		if not bank.commit(event).ok:
			return {}
		if event.op == "reward":
			result[int(event.game)] = bank.view().sponsors.size()
	return result


static func _development(build: SeasonBuild, current_pitches: bool = false) -> Dictionary:
	if current_pitches:
		return _current_development(build)
	var result: Dictionary = {"mastery": 0, "known": 0, "lessons": []}
	var book: SeasonDevelopment = SeasonDevelopment.new(build._book._season_key)
	for id: String in build._initial_roster:
		_profile(result, book.player(id))
	for event: Dictionary in build._book._events:
		var before: Dictionary = book.player(event.player)
		if not book.commit(event).ok:
			return {}
		if not build._contracts.has(event.player):
			continue
		if (
			event.op == "learn"
			and not before.mastery.has(event.target)
			and not result.lessons.has(event.target)
		):
			result.lessons.append(event.target)
		_profile(result, book.player(event.player))
		if event.has("other") and build._contracts.has(event.other):
			_profile(result, book.player(event.other))
	result.lessons.sort()
	return result


static func _current_development(build: SeasonBuild) -> Dictionary:
	if build == null or not build.pitch_catalog_current():
		return {}
	var trace: Dictionary = {"book": null, "count": 0,
		"contracts": build._contracts.duplicate(true),
		"result": {"mastery": 0, "known": 0, "lessons": []}}
	var observer: Callable = func(replayed: SeasonBuild) -> bool:
		return _observe_development(trace, replayed)
	# Full transaction replay, not a book carrying the final unlocked IDs. This
	# verifies prices, rewards and exotic_admit ordering before extracting lessons.
	var checked: SeasonBuild = SeasonBuildRestore.restore(build.to_data(), build._seed,
		build._initial_roster, build._pool, build._blocked, -1, observer)
	if checked == null or trace.book == null \
		or not ClubCareer.same(trace.book.to_data(), checked._book.to_data()) \
		or not ClubCareer.same(checked._book.to_data(), build._book.to_data()) \
		or not ClubCareer.same(checked._contracts, build._contracts):
		return {}
	trace.result.lessons.sort()
	return trace.result


static func _observe_development(trace: Dictionary, replayed: SeasonBuild) -> bool:
	# The replay observer receives only a freshly committed local Build, never a
	# serialized witness. All access comes from its exact replayed prefix.
	var source: SeasonDevelopment = replayed._book
	var book: SeasonDevelopment = trace.book
	if book == null:
		book = SeasonDevelopment.new(source._season_key)
		if not book.enable_pitch_catalog() or not book.install_exotic_start(source._exotic_start):
			return false
		if LeagueRules.dynasty(replayed._league_rules) \
			and not book.enable_dynasty(replayed._league_rules, source._dynasty_start):
			return false
		if LeagueRules.scramble(replayed._league_rules) and not book.enable_scramble(replayed._league_rules):
			return false
		trace.book = book
		for id: String in replayed._initial_roster:
			_profile(trace.result, book.player(id))
	# Build commit has already replayed the matching rewards and admitted this
	# proof. Later admission events are not visible at earlier buy boundaries.
	if not ClubCareer.same(book._exotic_start, source._exotic_start):
		return false
	if not ClubCareer.same(book._exotic_current, source._exotic_current):
		if source._exotic_current.is_empty() or not WorkingExoticEligibility.valid(source._exotic_current) \
			or source._exotic_current.season != book._season_key \
			or (not book._exotic_current.is_empty() and not WorkingExoticAccess.proof_prefix(
				book._exotic_current, source._exotic_current)):
			return false
		book.retain_exotic_current(source._exotic_current)
	if source._events.size() < int(trace.count):
		return false
	for index in range(int(trace.count), source._events.size()):
		var event: Dictionary = source._events[index]
		var before: Dictionary = book.player(event.player)
		var applied: Dictionary = book.commit(event)
		if not applied.ok or applied.replayed:
			return false
		if not trace.contracts.has(event.player):
			continue
		if event.op == "learn" and not before.mastery.has(event.target) \
			and not trace.result.lessons.has(event.target):
			trace.result.lessons.append(event.target)
		_profile(trace.result, book.player(event.player))
		if event.has("other") and trace.contracts.has(event.other):
			_profile(trace.result, book.player(event.other))
	trace.count = source._events.size()
	return true  # Exact complete book identity is checked once after full replay.


static func _profile(result: Dictionary, player: Dictionary) -> void:
	if player.is_empty():
		return
	result.known = maxi(result.known, player.active.size())
	for level: int in player.mastery.values():
		result.mastery = maxi(result.mastery, level)


static func valid(value: Variant, scores: Array) -> bool:
	if (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"), ClubPlayerLegend.VERSION, ClubPlayerLegend.VERSION
		)
	):
		return ClubPlayerLegend.valid(value, scores)
	if (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), HITS_VERSION, HITS_VERSION)
	):
		return _valid_with_hits(value, scores)
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, ["version", "games", "development"])
	):
		return false
	if (
		not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or not value.games is Array
		or not _valid_development(value.development)
	):
		return false
	var own: Array = []
	for score: Variant in scores:
		if not score is Array or score.size() != 5:
			return false
		for index in range(5):
			if not SeasonOwnership._whole(
				score[index], 0, 32 if index == 0 else 5 if index < 3 else 9999
			):
				return false
		if score[1] == score[2] or score[3] == score[4]:
			return false
		if 0 in [int(score[1]), int(score[2])]:
			own.append(score)
	if value.games.size() != own.size() or own.size() > 12:
		return false
	for index in range(own.size()):
		if not _valid_game(value.games[index], own[index]):
			return false
	return true


static func _valid_development(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, ["mastery", "known", "lessons"]):
		return false
	if (
		not SeasonOwnership._whole(value.mastery, 0, 5)
		or not SeasonOwnership._whole(value.known, 0, 8)
		or not value.lessons is Array
		or value.lessons.size() > SeasonPlayerCatalog.RECIPES.size()
	):
		return false
	var previous: String = ""
	for id: Variant in value.lessons:
		if not id is String or id <= previous or not SeasonPlayerCatalog.RECIPES.values().has(id):
			return false
		previous = id
	return true


static func _valid_game(value: Variant, score: Array) -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, ["game", "stats", "sponsors", "end_half", "deficit"])
	):
		return false
	if (
		not SeasonOwnership._whole(value.game, 0, 32)
		or value.game != score[0]
		or not SeasonOwnership._whole(value.sponsors, 0, 35)
		or not SeasonOwnership._whole(value.end_half, -1, 19997)
	):
		return false
	var own_runs: int = int(score[4] if score[2] == 0 else score[3])
	var other_runs: int = int(score[3] if score[2] == 0 else score[4])
	if not SeasonOwnership._whole(value.deficit, 0, other_runs):
		return false
	if value.end_half == -1 and value.deficit != 0:
		return false
	if (
		value.end_half >= 0
		and (value.end_half < 4 or (value.end_half < 8 and absi(own_runs - other_runs) < 10))
	):
		return false
	if value.stats == null:
		return true
	var stats: Variant = value.stats
	if (
		not stats is Dictionary
		or not SeasonOwnership._keys(stats, ["homers", "hitters", "strikeouts", "three_k"])
	):
		return false
	if (
		not SeasonOwnership._whole(stats.homers, 0, own_runs)
		or not SeasonOwnership._whole(stats.hitters, 0, 4)
		or not SeasonOwnership._whole(stats.strikeouts, 0, 9999)
		or not SeasonOwnership._whole(stats.three_k, 0, 4)
	):
		return false
	if value.end_half >= 0:
		var halves: int = (int(value.end_half) + (2 if score[2] == 0 else 1)) / 2
		if stats.strikeouts > halves * 3:
			return false
	return stats.three_k * 3 <= stats.strikeouts and (stats.homers == 0 or stats.hitters > 0)


static func metrics(runs: Array, current_pitches: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for run: Dictionary in runs:
		var summary: Dictionary = ClubSeasonRecord.analyze(run.proof)
		if summary.is_empty():
			return {}
		var complete: bool = run.status == "completed"
		result.completed_seasons = int(result.get("completed_seasons", 0)) + (1 if complete else 0)
		result.championships = (
			int(result.get("championships", 0))
			+ (1 if complete and summary.finish == "champion" else 0)
		)
		result.clean_total = (
			int(result.get("clean_total", 0))
			+ int(run.get("field_outs", 0) if (run.get("field_outs") != null) else 0)
		)
		var hits: Array = []
		if run.get("sponsors") is Array:
			for game: Dictionary in run.sponsors:
				for kind: String in game.hits:
					if not hits.has(kind):
						hits.append(kind)
		_max(result, "season_hit_types", hits.size())
		if complete and run.get("collection") is Array:
			var bats: Array = run.collection.filter(
				func(id: String) -> bool: return SeasonGearCatalog.item(id).get("slot") == "bat"
			)
			_max(result, "no_bat_season", 1 if bats.is_empty() else 0)
		var streak: int = 0
		var details: Variant = run.get("player_progress")
		var rows: Dictionary = {}
		if details != null:
			if not (WorkingPitchCareerProgress.valid(details, run.proof.scores) if current_pitches and WorkingPitchCareerProgress.is_current(details) else valid(details, run.proof.scores)):
				return {}
			_max(result, "mastery_max", int(details.development.mastery))
			_max(result, "repertoire_max", int(details.development.known))
			_max(result, "season_lessons", details.development.lessons.size())
			for row: Dictionary in details.games:
				rows[int(row.game)] = row
		for score: Array in run.proof.scores:
			if 0 not in [int(score[1]), int(score[2])]:
				continue
			var ours: int = int(score[4] if score[2] == 0 else score[3])
			var theirs: int = int(score[3] if score[2] == 0 else score[4])
			var won: bool = ours > theirs
			streak = streak + 1 if won else 0
			_max(result, "season_win_streak", streak)
			_max(result, "shutout", 1 if won and theirs == 0 else 0)
			if rows.has(int(score[0])):
				_game_metrics(result, rows[int(score[0])], score, won)
	return result


static func _game_metrics(result: Dictionary, row: Dictionary, score: Array, won: bool) -> void:
	_max(result, "game_sponsors", int(row.sponsors))
	_max(result, "comeback_deficit", int(row.deficit) if won else 0)
	_max(
		result,
		"walkoff",
		1 if (won and score[2] == 0 and row.end_half >= 9 and int(row.end_half) % 2 == 1) else 0
	)
	if row.stats == null:
		return
	var ours: int = int(score[4] if score[2] == 0 else score[3])
	_max(result, "game_homers", int(row.stats.homers))
	_max(result, "winning_hitters", int(row.stats.hitters) if won else 0)
	_max(result, "contact_runs", ours if row.stats.homers == 0 else 0)
	_max(result, "three_k_pitchers", int(row.stats.three_k))
	result.strikeouts_total = int(result.get("strikeouts_total", 0)) + int(row.stats.strikeouts)


static func _max(result: Dictionary, key: String, value: int) -> void:
	result[key] = maxi(int(result.get(key, 0)), value)

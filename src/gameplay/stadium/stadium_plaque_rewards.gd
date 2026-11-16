class_name StadiumPlaqueRewards
extends RefCounted
## BU3: earned ownership is independent of missing uniform-number presentation.
# gdlint: disable=max-returns

const VERSION: int = 1
const SOURCE: String = "club-legend-v1"
const MAX_AWARDS: int = 48
const FIELDS: Array = [
	"version",
	"player_id",
	"display_name",
	"uniform_number",
	"season_id",
	"award_game",
	"award_completed",
	"era",
	"stats"
]


static func signature() -> String:
	return (
		(
			"ST-066:club-legend-v1:3-completed-seasons-5-games:40H-or-60K-or-40-clean:known-evidenc"
			+ "e:unknown-number-storage-v1"
		)
		. sha256_text()
	)


static func key(player_id: String) -> String:
	return SOURCE + ":" + player_id


static func adopt(career: ClubCareer) -> void:
	if career._plaques.is_empty():
		career._plaques = {"version": VERSION, "from_season": career.current, "records": {}}


static func _text(value: Variant) -> bool:
	if not value is String or value.strip_edges().is_empty() or value.length() > 96:
		return false
	for index in range(value.length()):
		if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
			return false
	return true


static func valid_record(value: Variant) -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, FIELDS)
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or not value.player_id is String
		or not SeasonPlayerCatalog.ROWS.has(value.player_id)
		or not _text(value.display_name)
		or value.uniform_number != null
		or not SeasonOwnership._whole(value.season_id, 1, ClubCareer.MAX_RUNS)
		or not SeasonOwnership._whole(value.award_game, 1, 12)
		or not value.award_completed is bool
		or not StadiumClubIdentity.valid(value.era)
	):
		return false
	var stats: Variant = value.stats
	if (
		not stats is Dictionary
		or not SeasonOwnership._keys(
			stats,
			[
				"hits",
				"strikeouts",
				"clean_outs",
				"completed_seasons",
				"credited_games",
				"eligible",
				"evidence"
			]
		)
		or stats.eligible != true
		or not stats.eligible is bool
		or stats.evidence != "prospective-known-minimum"
		or not stats.completed_seasons is Array
		or stats.completed_seasons.size() < 3
		or not stats.credited_games is Dictionary
	):
		return false
	for metric: String in ["hits", "strikeouts", "clean_outs"]:
		if not SeasonOwnership._whole(stats[metric], 0, 12288000000):
			return false
	if stats.hits < 40 and stats.strikeouts < 60 and stats.clean_outs < 40:
		return false
	var prior: int = 0
	for season: Variant in stats.completed_seasons:
		if (
			not SeasonOwnership._whole(season, prior + 1, int(value.season_id))
			or not SeasonOwnership._whole(stats.credited_games.get(str(int(season))), 5, 12)
		):
			return false
		prior = int(season)
	for season: Variant in stats.credited_games:
		if (
			not season is String
			or not season.is_valid_int()
			or str(int(season)) != season
			or int(season) < 1
			or int(season) > value.season_id
			or not SeasonOwnership._whole(stats.credited_games[season], 1, 12)
		):
			return false
	return true


static func canonical(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.duplicate(true)
	for field: String in ["version", "season_id", "award_game"]:
		result[field] = int(result[field])
	result.era.version = int(result.era.version)
	for metric: String in ["hits", "strikeouts", "clean_outs"]:
		result.stats[metric] = int(result.stats[metric])
	for index in range(result.stats.completed_seasons.size()):
		result.stats.completed_seasons[index] = int(result.stats.completed_seasons[index])
	for season: String in result.stats.credited_games:
		result.stats.credited_games[season] = int(result.stats.credited_games[season])
	return result


static func _at(runs: Array, season_id: int, game_count: int, completed: bool, current_pitches: bool = false) -> Dictionary:
	var prefix: Array = runs.slice(0, season_id).duplicate(true)
	var last: Dictionary = prefix[-1]
	last.status = "completed" if completed else "active"
	last.player_progress.games.resize(game_count)
	return ClubPlayerLegend._evaluate_runs(prefix, current_pitches)


static func valid_history(value: Variant, runs: Array, current_pitches: bool = false) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if (
		not SeasonOwnership._keys(value, ["version", "from_season", "records"])
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or not SeasonOwnership._whole(value.from_season, 1, runs.size())
		or not value.records is Dictionary
		or value.records.size() > MAX_AWARDS
	):
		return false
	for id: Variant in value.records:
		var record: Variant = value.records[id]
		if (
			not valid_record(record)
			or id != key(record.player_id)
			or record.season_id < value.from_season
			or record.season_id > runs.size()
		):
			return false
		var run: Dictionary = runs[int(record.season_id) - 1]
		var progress: Variant = run.get("player_progress")
		if (
			not progress is Dictionary
			or not (WorkingPitchProgression.is_version(progress.get("version"), ClubPlayerLegend.VERSION) or (current_pitches and WorkingPitchCareerProgress.is_current(progress)))
			or record.award_game > progress.games.size()
			or (
				record.award_completed
				and (run.status != "completed" or record.award_game != progress.games.size())
			)
		):
			return false
		var metrics: Dictionary = _at(
			runs, int(record.season_id), int(record.award_game), record.award_completed, current_pitches
		)
		if (
			not metrics.has(record.player_id)
			or not ClubCareer.same(metrics[record.player_id], record.stats)
		):
			return false
	# Loading validates receipts but never invents a missing achievement. New records
	# are admitted only by capture() during a prospective game/settlement sync.
	return true


static func capture(career: ClubCareer) -> bool:
	if career._plaques.is_empty():
		return true
	if not valid_history(career._plaques, career.runs, not career._pitch_catalog.is_empty()) or career.current <= 0:
		return false
	var run: Dictionary = career.runs[-1]
	var progress: Variant = run.get("player_progress")
	if (
		not progress is Dictionary
		or not (WorkingPitchProgression.is_version(progress.get("version"), ClubPlayerLegend.VERSION) or (not career._pitch_catalog.is_empty() and WorkingPitchCareerProgress.is_current(progress)))
		or progress.games.is_empty()
		or run.id < career._plaques.from_season
	):
		return true
	var metrics: Dictionary = ClubPlayerLegend._evaluate_runs(career.runs, not career._pitch_catalog.is_empty())
	for player: String in metrics:
		if not metrics[player].eligible or career._plaques.records.has(key(player)):
			continue
		var definition: PlayerDefinition = ContentDB.get_player(StringName(player))
		if definition == null:
			return false
		var record: Dictionary = {
			"version": VERSION,
			"player_id": player,
			"display_name": definition.display_name,
			"uniform_number": null,
			"season_id": int(run.id),
			"award_game": progress.games.size(),
			"award_completed": run.status == "completed",
			"era": StadiumClubIdentity.current(),
			"stats": metrics[player].duplicate(true)
		}
		if not valid_record(record):
			return false
		career._plaques.records[key(player)] = canonical(record)
	return true


static func awards(career: ClubCareer) -> Variant:
	if career == null or not valid_history(career._plaques, career.runs, not career._pitch_catalog.is_empty()):
		return null
	return {} if career._plaques.is_empty() else career._plaques.records.duplicate(true)


static func deliver(career: ClubCareer) -> bool:
	var ledger: ClubAssetLedger = ClubPlayers.assets(career)
	var records: Variant = awards(career)
	if ledger == null or not records is Dictionary:
		return false
	for id: String in records:
		if ledger._stock.copies.has(id):
			if not ClubCareer.same(ledger._stock.copies[id].get("earned"), records[id]):
				return false
			continue
		if not (
			ledger
			. commit(
				{
					"id": id,
					"rev": ledger.revision(),
					"op": "stadium_plaque",
					"earned": records[id].duplicate(true)
				}
			)
			. ok
		):
			return false
	career._assets = ledger.to_data()
	return true


static func delivered(career: ClubCareer, ledger: ClubAssetLedger) -> bool:
	var records: Variant = awards(career)
	if ledger == null or not records is Dictionary:
		return false
	for id: String in records:
		if (
			not ledger._stock.copies.has(id)
			or not ClubCareer.same(ledger._stock.copies[id].get("earned"), records[id])
		):
			return false
	return true

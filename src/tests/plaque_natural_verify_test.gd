extends Node
var _checks: int = 0
var _failures: int = 0
var _games: int = 0
var _releases: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(label)


func _read(path: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(raw is Dictionary, "retained evidence exists " + path)
	return raw if raw is Dictionary else {}


func _ready() -> void:
	var root: String = OS.get_environment("PLAQUE_AUDIT_ROOT")
	var saved: Dictionary = _read(root.path_join("plaque-evidence/career-current.json"))
	var season: SeasonState = SeasonSave._decode(saved)
	_check(season != null, "fresh-process completed career independently cold validates")
	if season == null:
		get_tree().quit(1)
		return
	_check(
		season.phase == SeasonState.Phase.COMPLETE and season.career.runs.size() == 3,
		"three naturally completed seasons"
	)
	var pending: Dictionary = _read(root.path_join("plaque-evidence/pre-award-season.json"))
	var before_award: SeasonState = SeasonSave._decode(pending)
	_check(
		before_award != null and StadiumPlaqueRewards.awards(before_award.career).is_empty(),
		"real prior pending checkpoint has no premature plaque"
	)
	var id: String = "player.quinn_riley"
	var totals: Dictionary = {"hits": 0, "strikeouts": 0, "clean_outs": 0}
	var credits: Dictionary = {}
	for run: Dictionary in season.career.runs:
		var prefix: String = (
			root.path_join("prior-physical-evidence/%d" % int(run.seed))
			if run.id < 3
			else root.path_join("plaque-evidence/season-%d" % int(run.seed))
		)
		for score: Array in run.proof.scores:
			var envelope: Dictionary = _read(
				prefix.path_join("fixture-%d-envelope.json" % int(score[0]))
			)
			if envelope.is_empty():
				continue
			var report: Dictionary = envelope.report
			_check(PhysicalMatchReport.valid(report), "original physical envelope valid")
			var core: Dictionary = (
				PhysicalLeagueReport.core(report) if report.get("version") == 27 else report
			)
			_check(
				(
					core.away_runs == score[3]
					and core.home_runs == score[4]
					and not core.releases.is_empty()
				),
				"official result exactly matches actual physical game"
			)
			_games += 1
			_releases += core.releases.size()
			if not 0 in [int(score[1]), int(score[2])]:
				continue
			var own: int = 1 if score[2] == 0 else 0
			var rows: Array = run.player_progress.games.filter(
				func(row: Dictionary) -> bool: return row.game == score[0]
			)
			_check(rows.size() == 1, "exact individual official-game evidence")
			if rows.size() != 1 or not rows[0].players.has(id):
				continue
			var line: Dictionary = core.performance[id]
			var player: Dictionary = rows[0].players[id]
			var clean: int = 0
			for play: Dictionary in core.teams[own].fielding:
				if play.player == id and play.clean:
					clean += 1
			_check(
				(
					player.hits == line.h
					and player.strikeouts == line.p_k
					and player.clean_outs == clean
				),
				"individual metrics bind genuine own player performance"
			)
			totals.hits += int(line.h)
			totals.strikeouts += int(line.p_k)
			totals.clean_outs += clean
			if line.pa > 0 or line.pitches > 0 or player.fielded == true:
				credits[str(int(run.id))] = int(credits.get(str(int(run.id)), 0)) + 1
	var awards: Dictionary = StadiumPlaqueRewards.awards(season.career)
	var key: String = StadiumPlaqueRewards.key(id)
	_check(awards.size() == 1 and awards.has(key), "exactly one genuinely earned Quinn plaque")
	if awards.has(key):
		var receipt: Dictionary = awards[key]
		_check(
			(
				receipt.stats.completed_seasons == [1, 2, 3]
				and ClubCareer.same(receipt.stats.credited_games, credits)
			),
			"three earned tenure seasons match actual games"
		)
		for metric: String in totals:
			_check(receipt.stats[metric] == totals[metric], "frozen actual career " + metric)
		_check(
			receipt.uniform_number == null and receipt.award_completed and receipt.season_id == 3,
			"no invented number and exact third completion award"
		)
		var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
		var stock: StadiumStock = ledger.construction()
		_check(
			(
				stock.copies.has(key)
				and stock.copies[key].item == "ST-066"
				and stock.copies[key].paid == 0
			),
			"actual persistent earned ownership has no charge"
		)
		_check(
			(
				not stock.blueprints.has("ST-066")
				and not ledger.view().stadium_active.has("player_plaques")
			),
			"no invented shop access or mounted art"
		)
		var before: Dictionary = season.career.to_data()
		_check(
			(
				StadiumPlaqueRewards.capture(season.career)
				and StadiumPlaqueRewards.deliver(season.career)
				and ClubCareer.same(before, season.career.to_data())
			),
			"repeated delivery exactly preserves original receipt and wallet"
		)
		SeasonSave.path = "user://earned-plaque-cold.json"
		_check(SeasonSave.save(season), "earned career durable save")
		var restored: SeasonState = SeasonSave.restore()
		_check(
			restored != null and ClubCareer.same(restored.career.to_data(), before),
			"durable cold restore keeps exact earned ledger"
		)
	print(
		"PLAQUE_COLD_AUDIT checks=",
		_checks,
		" failures=",
		_failures,
		" actual_games=",
		_games,
		" releases=",
		_releases,
		" totals=",
		JSON.stringify(totals),
		" credits=",
		JSON.stringify(credits)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

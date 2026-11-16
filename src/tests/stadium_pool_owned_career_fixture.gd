extends RefCounted
## Deterministic simulated test career, not a played physical career.
## The caller selects a dedicated, empty SeasonSave.path and passes that same path.
## This helper never changes the save path, deletes files, buys anything or quits.
# gdlint: disable=max-returns

const SEED: int = 42
const MAX_COMPLETED_RUNS: int = 18
const MAX_HUMAN_FIXTURES: int = 12
const REQUIRED_SEASONS: int = 6
const REQUIRED_REGULAR_WINS: int = 18
const REQUIRED_BALANCE: int = 700


func fund(save_path: String) -> Dictionary:
	var history: Array = []
	if save_path.is_empty() or save_path == "user://season-v1.json" \
		or SeasonSave.path != save_path:
		return _report(false, null, history, "Caller must select a dedicated matching save path.")
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			return _report(false, null, history, "Dedicated save path must be empty before funding.")
	var club: ClubCareer = null
	var season: SeasonState = null
	for run_index in range(MAX_COMPLETED_RUNS):
		season = SeasonState.create(SEED, false, true, true)
		season.career = ClubCareer.new() if club == null else club
		if not season.career.start(season):
			return _report(false, season, history, "Could not start the next simulated career run.")
		var row: Dictionary = {"run": run_index + 1, "seed": SEED,
			"kind": "deterministic simulated test career", "generated_human_results": [],
			"draft_choices": [], "complete": false, "saved_and_restored": false}
		history.append(row)
		for pick in range(4):
			var offers: Array[String] = season.offers()
			if offers.is_empty() or not season.choose_player(offers[0]):
				return _report(false, season, history, "First available draft offer was rejected.")
			row.draft_choices.append(offers[0])
		var error: String = _finish(season, row)
		row["results"] = season.results.duplicate(true)
		row["player_results"] = season.player_results.duplicate(true)
		row["proof"] = ClubSeasonRecord.capture(season).duplicate(true)
		if not error.is_empty():
			return _report(false, season, history, error)
		if season.phase != SeasonState.Phase.COMPLETE or season.results.size() != 33:
			return _report(false, season, history, "Simulation did not complete the full 33-result bracket.")
		row.complete = true
		var snapshot: Dictionary = SeasonSave.snapshot(season).duplicate(true)
		row["snapshot"] = snapshot
		if snapshot.is_empty() or not SeasonSave.save(season):
			return _report(false, season, history, "Completion save failed: " + SeasonSave.last_error)
		var restored: SeasonState = SeasonSave.restore()
		if restored == null or not SeasonSave.last_error.is_empty():
			return _report(false, season, history, "Completion restore failed: " + SeasonSave.last_error)
		var restored_snapshot: Dictionary = SeasonSave.snapshot(restored).duplicate(true)
		row["restored_snapshot"] = restored_snapshot
		if not ClubCareer.same(snapshot, restored_snapshot) \
			or not ClubCareer.same(row.results, restored.results) \
			or not ClubCareer.same(row.player_results, restored.player_results) \
			or restored.phase != SeasonState.Phase.COMPLETE or restored.results.size() != 33:
			return _report(false, season, history, "Saved career did not restore exactly.")
		season = restored
		row.saved_and_restored = true
		var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
		if ledger == null or ledger.view().spent != 0 or not ledger._events.all(
			func(event: Dictionary) -> bool: return event.get("op") == "stadium_pennant"):
			return _report(false, season, history, "Funding must retain the unspent ordinary asset journal.")
		var progress: Array = StadiumCareerProgress.capture(season.career)
		var credits: Array[int] = ClubPlayers.income(season.career)
		if not StadiumCareerProgress.valid(progress, credits) \
			or progress.size() != run_index + 1 or credits.size() != run_index + 1:
			return _report(false, season, history, "Restored career progress or earned credits are invalid.")
		row["archive"] = season.career.runs[-1].duplicate(true)
		row["progress"] = progress.duplicate(true)
		row["metrics"] = StadiumCareerProgress.metrics(progress, progress.size())
		row["credits"] = credits.duplicate()
		row["balance"] = season.career.balance()
		row["journal"] = ledger.to_data().duplicate(true)
		if row.archive.status != "completed" \
			or not ClubCareer.same(row.proof, row.archive.proof):
			return _report(false, season, history, "Completed archive does not match generated results.")
		if _eligible(row.metrics, row.balance):
			return _report(true, season, history, "")
		club = season.career.fork()
		if not club.close(season) or club.current != 0 \
			or not ClubCareer.same(club.runs, season.career.runs) \
			or club.balance() != season.career.balance():
			return _report(false, season, history,
				"Could not close the restored run without changing history.")
	return _report(false, season, history,
		"Funding ceiling reached after 18 completed seed-42 runs; actual progress is below the gate.")


func _finish(season: SeasonState, row: Dictionary) -> String:
	for game in range(MAX_HUMAN_FIXTURES):
		if season.phase == SeasonState.Phase.COMPLETE:
			return ""
		var fixture: Dictionary = season.pending_fixture()
		if fixture.is_empty() or 0 not in [fixture.away, fixture.home]:
			return "The pending fixture is missing or does not involve the human club."
		for prior: Dictionary in row.generated_human_results:
			if prior.get("id") == fixture.id:
				return "The same human fixture was offered twice; no second simulation was attempted."
		var generated: Dictionary = season._simulate(fixture)
		row.generated_human_results.append(generated.duplicate(true))
		if generated.is_empty() or not generated.has("away_runs") or not generated.has("home_runs"):
			return "The ordinary simulator returned no complete score."
		for key: String in fixture:
			if not generated.has(key) or not ClubCareer.same(generated[key], fixture[key]):
				return "The generated result does not match the pending fixture."
		if not season.record_player_result(fixture.id, generated.away_runs, generated.home_runs):
			return "The ordinary result API rejected the simulator's unchanged score."
		if season.player_results.is_empty():
			return "The ordinary result API did not archive the human result."
		var recorded: Dictionary = season.player_results[-1]
		for key: String in generated:
			if not recorded.has(key) or not ClubCareer.same(generated[key], recorded[key]):
				return "The recorded human result changed generated evidence."
	return "" if season.phase == SeasonState.Phase.COMPLETE \
		else "A season exceeded the finite twelve-human-fixture ceiling."


func _eligible(metrics: Dictionary, balance: int) -> bool:
	return int(metrics.get("seasons", 0)) >= REQUIRED_SEASONS \
		and int(metrics.get("wins", 0)) >= REQUIRED_REGULAR_WINS \
		and balance >= REQUIRED_BALANCE


func _report(ok: bool, season: SeasonState, history: Array, error: String) -> Dictionary:
	var result: Dictionary = {"ok": ok, "season": season, "history": history,
		"error": error, "kind": "deterministic simulated test career", "seed": SEED,
		"max_completed_runs": MAX_COMPLETED_RUNS, "progress": [], "metrics": {},
		"credits": [], "balance": 0, "career": {}, "completed_runs": 0}
	if season != null and season.career != null:
		result.progress = StadiumCareerProgress.capture(season.career)
		result.metrics = StadiumCareerProgress.metrics(result.progress, result.progress.size())
		result.credits = ClubPlayers.income(season.career)
		result.balance = season.career.balance()
		result.career = season.career.to_data().duplicate(true)
		result.completed_runs = int(result.metrics.get("seasons", 0))
	return result

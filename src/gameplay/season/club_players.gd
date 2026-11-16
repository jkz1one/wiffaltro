class_name ClubPlayers
extends RefCounted

const AC02_PASSIVE_14 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Career-backed permanent access. Caller saves a fork before publishing a mutation.


static func income(career: ClubCareer) -> Array[int]:
	var result: Array[int] = []
	for run: Dictionary in career.runs:
		result.append(int(run.receipt.get("total", 0)))
	return result


static func income_through(career: ClubCareer) -> int:
	var credits: Array[int] = income(career)
	var through: int = credits.size()
	while through > 0 and credits[through - 1] == 0:
		through -= 1
	return through


static func assets(career: ClubCareer) -> ClubAssetLedger:
	var ac02_token: int = AC02_PASSIVE_14.enter("club_players.assets")
	var ac02_result: ClubAssetLedger = _ac02_passive_14_assets(career)
	AC02_PASSIVE_14.leave(ac02_token)
	return ac02_result


static func _ac02_passive_14_assets(career: ClubCareer) -> ClubAssetLedger:
	var awards: Variant = StadiumPennantRewards.awards(career)
	var plaques: Variant = StadiumPlaqueRewards.awards(career)
	if not awards is Dictionary or not plaques is Dictionary:
		return null
	awards.merge(plaques)
	var seed_value: int = int(career.runs[0].seed) if not career.runs.is_empty() else 0
	if career._assets.is_empty():
		return ClubAssetLedger.new(
			seed_value, income(career), StadiumCareerProgress.capture(career), awards
		)
	return ClubAssetLedger.from_data(
		career._assets, seed_value, income(career), StadiumCareerProgress.capture(career), awards
	)


static func command(career: ClubCareer, request: Dictionary) -> Dictionary:
	var ledger: ClubAssetLedger = assets(career)
	if ledger == null:
		return ClubAssetLedger._error("Permanent assets could not be validated.")
	var applied: Dictionary = ledger.commit(request)
	if applied.ok:
		career._assets = ledger.to_data()
	return applied


static func owned(career: ClubCareer) -> Array[String]:
	var ledger: ClubAssetLedger = assets(career)
	return (
		[]
		if ledger == null
		else ledger.owned(ClubPlayerCatalog.earned(ClubPlayerProgress.metrics(career.runs, not career._pitch_catalog.is_empty())))
	)


static func transact(season: SeasonState, request: Dictionary) -> Dictionary:
	if season == null or season.career == null:
		return ClubAssetLedger._error("A saved club career is required.")
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	if snapshot.is_empty():
		return ClubAssetLedger._error(SeasonSave.last_error)
	var candidate: SeasonState = SeasonSave._decode(snapshot)
	if candidate == null or candidate.career == null:
		return ClubAssetLedger._error(
			"The season could not be validated for this club transaction."
		)
	var applied: Dictionary = command(candidate.career, request)
	if not applied.ok:
		return applied
	if not SeasonSave.save(candidate):
		return ClubAssetLedger._error(SeasonSave.last_error)
	season.career = candidate.career
	return applied

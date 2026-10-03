class_name SeasonRoundSettlement
extends RefCounted
## Rebuild a disposable candidate; neither discovery nor a failed job pays the live season.


static func project(season: SeasonState) -> Dictionary:
	var data: Dictionary = SeasonSave.snapshot(season)
	if data.is_empty() or season.physical == null or not _shape(season.physical.pending):
		return {"error": "The pending round is invalid."}
	var pending: Dictionary = data.physical.pending
	data.physical.pending = {}
	var candidate: SeasonState = SeasonSave._decode(data)
	if candidate == null:
		return {"error": "The round checkpoint could not be restored."}
	candidate.physical.reports.append_array(pending.reports.duplicate(true))
	candidate.physical.projecting = true
	var ok: bool = candidate.callv("record_player_result", pending.human)
	if candidate.physical.cursor != candidate.physical.reports.size():
		return {"error": "The pending round contains an unexpected physical fixture."}
	if ok:
		if not _receipts(candidate):
			return {"error": "The round did not settle every club's own fixture exactly once."}
		candidate.physical.projecting = false
		return {"candidate": candidate}
	if not candidate.physical.needed.is_empty() and candidate.physical.error.is_empty():
		return {"candidate": candidate, "fixture": candidate.physical.needed.duplicate(true)}
	return {"error": "The completed game or saved physical evidence failed validation."}


static func valid_pending(season: SeasonState) -> bool:
	return not project(season).has("error")


static func _receipts(season: SeasonState) -> bool:
	for index in range(1, 6):
		var expected: Dictionary = {}
		for fixture: Dictionary in season.results:
			if fixture.home == index or fixture.away == index:
				expected[str(int(fixture.id))] = SeasonState._winner(fixture) == index
		if not ClubCareer.same(season.opponents.clubs[str(index)].build._bank.view().rewards, expected):
			return false
	return true


static func _shape(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, ["human", "reports"]):
		return false
	if not value.human is Array or value.human.size() != 12 or not value.reports is Array:
		return false
	if value.reports.size() > 5:
		return false
	for index in range(3):
		if not SeasonOwnership._whole(value.human[index], 0, 9999):
			return false
	for index in [3, 6, 9, 10]:
		if not value.human[index] is Dictionary:
			return false
	for index in [4, 5, 7, 8, 11]:
		if not value.human[index] is Array:
			return false
	for row: Variant in value.reports:
		if not SeasonPhysicalFixtures.envelope(row):
			return false
	return true

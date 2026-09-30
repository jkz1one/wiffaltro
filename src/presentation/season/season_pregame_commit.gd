class_name SeasonPregameCommit
extends RefCounted
## Stage departure and once-game supplies, then publish only after the save succeeds.


static func save(app: SeasonApp) -> bool:
	var previous: SeasonBuild = app.season.build
	if previous == null:
		return app._checkpoint()
	var next: SeasonBuild = previous._fork()
	if SeasonSchoolSponsors.has_credit(next.view().shop):
		var result: Dictionary = next.commit(
			{"id": "leave:%d" % next.revision(), "rev": next.revision(), "op": "leave_shop"}
		)
		if not result.ok:
			app.notice = result.error
			return false
	var fixture_id: int = int(app.season.pending_fixture().id)
	if next._format >= 17 and not next._pregames.has(str(fixture_id)):
		var result: Dictionary = next.commit(
			{
				"id": "pregame:%d" % fixture_id,
				"rev": next.revision(),
				"op": "pregame",
				"game": fixture_id
			}
		)
		if not result.ok:
			app.notice = result.error
			return false
	app.season.build = next
	if app._checkpoint():
		return true
	app.season.build = previous
	return false

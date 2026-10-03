class_name SeasonOpponents
extends RefCounted
## Policy3 adds paid passive Gear. Historical policies and markets stay frozen.

var draft_order: Array[int] = []
var clubs: Dictionary = {}
var _format: int = 2


func initialize(season: SeasonState) -> void:
	for index in range(1, 6):
		var roster: Array[String] = []
		roster.assign(season.teams[index].roster)
		var seed_value: int = (season.season_seed + index * 92821) & 0x7fffffff
		var build: SeasonBuild = SeasonBuild.new(seed_value, roster)
		build._format = 41 if _format == 3 else 19
		build._market = 2 if _format == 3 else 1
		clubs[str(index)] = {
			"build": build,
			"profile": SeasonOpponentPolicy.PROFILES[index],
			"roles": SeasonOpponentPolicy.roles(build),
			"cursor": 0,
			"decisions": []
		}


func settle(fixtures: Array, survivors: Array) -> void:
	for result: Dictionary in fixtures:
		for index: int in [int(result.home), int(result.away)]:
			if index == 0:
				continue
			var club: Dictionary = clubs[str(index)]
			var build: SeasonBuild = club.build
			if build._bank.view().rewards.has(str(int(result.id))):
				continue
			var reward: Dictionary = SeasonOpponentPolicy.command(
				build,
				"reward",
				{"game": result.id, "win": SeasonState._winner(result) == index, "performance": {}}
			)
			if not build.commit(reward).ok:
				continue
			if survivors.has(index):
				SeasonOpponentPolicy.checkout(build, club, int(result.id))


func definition(id: String) -> PlayerDefinition:
	for club: Dictionary in clubs.values():
		if club.build.roster().has(id):
			return club.build.definition(id)
	return null


func to_data() -> Dictionary:
	var rows: Dictionary = {}
	for key: String in clubs:
		var club: Dictionary = clubs[key]
		rows[key] = {
			"build": club.build.to_data(),
			"roles": club.roles.duplicate(true),
			"profile": club.profile,
			"cursor": club.cursor,
			"decisions": club.decisions.duplicate(true)
		}
	var data: Dictionary = {"policy": _format, "clubs": rows}
	if _format >= 2:
		data["draft_order"] = draft_order.duplicate()
	return data


func summary(index: int) -> Dictionary:
	var club: Dictionary = clubs.get(str(index), {})
	if club.is_empty():
		return {}
	var view: Dictionary = club.build.view()
	return {
		"cash": view.wallet.cash,
		"profile": club.profile,
		"purchases": club.decisions.size(),
		"roles": club.roles.duplicate(),
		"decisions": club.decisions.duplicate(true)
	}

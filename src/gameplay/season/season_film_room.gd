class_name SeasonFilmRoom
extends RefCounted
## Working exact-recipe choice. Saved as an event, never reconstructed from current stock.


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	if (
		build._format < 18
		or not build._keys(command, ["game", "recipe"])
		or not SeasonOwnership._whole(command.game, 0, 32)
		or not command.recipe is String
		or ContentDB.get_pitch(StringName(command.recipe)) == null
	):
		return "Invalid Film Room selection."
	var game: String = str(int(command.game))
	if build._scouts.has(game) or build._pregames.has(game) or build._bank.view().rewards.has(game):
		return "Film Room is already locked for this game."
	if SeasonSchoolSponsors.active(build, "J08").is_empty():
		return "Film Room must be active."
	build._scouts[game] = command.recipe
	return ""


static func choices(season: SeasonState, fixture: Dictionary) -> Array[String]:
	var starter: PlayerDefinition = season.player_definition(season.opposing_starter(fixture))
	var result: Array[String] = []
	for recipe: PitchDefinition in starter.starting_pitches:
		result.append(String(recipe.id))
	return result


static func target(season: SeasonState) -> StringName:
	if season.build == null or SeasonSchoolSponsors.active(season.build, "J08").is_empty():
		return &""
	var game: String = str(int(season.pending_fixture().get("id", -1)))
	return StringName(season.build._scouts.get(game, ""))

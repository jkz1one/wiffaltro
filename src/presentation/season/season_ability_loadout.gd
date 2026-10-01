class_name SeasonAbilityLoadout
extends RefCounted
## Shared read-only learning cards for shop and paused match inspection.


static func rows(app: SeasonApp, team: TeamMatchState, state: MatchState) -> Array:
	var players: Array[PlayerDefinition] = []
	if team != null:
		for player: PlayerMatchState in team.roster:
			players.append(player.definition)
	elif app.season != null and app.season.build != null:
		for id: String in app.season.build.roster():
			players.append(app.season.build.definition(id))
	var result: Array = []
	for player: PlayerDefinition in players:
		for id: String in player.season_abilities:
			if not SeasonAbilities.ITEMS.has(id):
				continue
			var item: Dictionary = SeasonAbilities.ITEMS[id]
			var effect: String = item.effect
			if (
				state != null
				and id == SeasonAbilities.COUNT
				and state.batter().definition == player
			):
				effect += "\n" + state.abilities.label(player)
			result.append(
				{
					"name": item.name,
					"label": player.display_name + " • " + item.slot,
					"effect": effect,
					"status": "Working • Learned this season • Not sellable"
				}
			)
	return result

class_name ProgressionMatchAdapter
extends RefCounted
## Explicit test-only bridge. No authored resource, ordinary season or wallet is mutated.


static func player(book: SeasonDevelopment, player_id: String) -> PlayerDefinition:
	var profile: Dictionary = book.player(player_id)
	var source: PlayerDefinition = ContentDB.get_player(StringName(player_id))
	if profile.is_empty() or source == null:
		return null
	var result: PlayerDefinition = source.duplicate() as PlayerDefinition
	result.progression_test = true
	result.contact = profile.stats.contact
	result.power = profile.stats.power
	result.fielding = profile.stats.fielding
	# Internal legacy consumers still call these command/stamina. Both now read
	# one Pitching rating. Retired Velocity/Break are bypassed in rated_pitch.
	result.control = profile.stats.pitching
	result.stamina = profile.stats.pitching
	result.velocity = 5
	result.break_rating = 5
	result.pitch_capacity = profile.capacity
	result.starting_pitches = []
	for recipe_id: String in profile.active:
		var recipe: PitchDefinition = PitchMastery.apply(
			ContentDB.get_pitch(StringName(recipe_id)), int(profile.mastery[recipe_id])
		)
		if recipe == null:
			return null
		result.starting_pitches.append(recipe)
	result.signature_pitch_index = mini(
		result.signature_pitch_index, result.starting_pitches.size() - 1
	)
	return result


static func exhibition(book: SeasonDevelopment, selected_player: String) -> MatchState:
	if not SeasonPlayerCatalog.ROWS.has(selected_player):
		return null
	var ids: Array[String] = SeasonPlayerCatalog.ids()
	ids.erase(selected_player)
	ids.push_front(selected_player)
	var own: Array[PlayerDefinition] = []
	var rival: Array[PlayerDefinition] = []
	for index in range(8):
		var definition: PlayerDefinition = player(book, ids[index])
		if definition == null:
			return null
		if index < 4:
			own.append(definition)
		else:
			rival.append(definition)
	return MatchState.create(
		TeamMatchState.create("Working Rival Lab", rival),
		TeamMatchState.create("Working Player Lab", own)
	)

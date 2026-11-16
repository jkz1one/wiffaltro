class_name StadiumPlaqueUI
extends RefCounted
## Storage disclosure only. No display mount or guessed uniform-number art.


static func description(earned: Dictionary) -> String:
	return (
		(
			"%s • Club Legend • %s • Earned season %d, club game %d. Frozen recorded career: %d "
			+ "hits / %d Ks / %d clean fielded outs; %d completed seasons with at least five "
			+ "credited games each."
		)
		% [
			earned.display_name,
			earned.era.name,
			earned.season_id,
			earned.award_game,
			earned.stats.hits,
			earned.stats.strikeouts,
			earned.stats.clean_outs,
			earned.stats.completed_seasons.size()
		]
	)


static func card(parent: Node, earned: Dictionary) -> void:
	SeasonPages.wrapped(parent, description(earned))
	(
		SeasonPages
		. wrapped(
			parent,
			(
				"OWNED • Safely stored. Uniform number was not recorded at the achievement. Plaque "
				+ "art and NUMBER-WALL mounting await an authoritative persistent display number. No "
				+ "number is invented, reserved or retired; your player stays available."
			)
		)
	)


static func awards(menu: SeasonMenu, parent: Node, season_id: int, game_count: int = -1) -> void:
	if menu.app.season == null or menu.app.season.career == null:
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	if ledger == null:
		return
	for copy: Dictionary in ledger.construction().copies.values():
		if copy.get("source") != StadiumPlaqueRewards.SOURCE:
			continue
		var earned: Dictionary = copy.earned
		if earned.season_id != season_id or (game_count >= 0 and earned.award_game != game_count):
			continue
		SeasonPages.wrapped(parent, "CLUB LEGEND PLAQUE EARNED • " + description(earned))
		(
			SeasonPages
			. wrapped(
				parent,
				(
					"Permanently owned and stored. Uniform number and finished display art remain "
					+ "pending; no mounting is required to keep it."
				)
			)
		)
		menu._button(parent, "VIEW OWNED PLAQUE", StadiumEditorUI.show.bind(menu, {}, -1))

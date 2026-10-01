class_name SeasonLoadoutData
extends RefCounted
## Read-only presentation projection. Match inventory comes from the pregame snapshot.


static func capture(season: SeasonState) -> Dictionary:
	if season == null or season.build == null:
		return {"gear": {}, "sponsors": [], "held": [], "capacity": {"sponsors": 5, "held": 2}}
	var wallet: Dictionary = season.build.view().wallet.duplicate(true)
	wallet["stamps"] = season.build._legends.duplicate(true)
	return wallet


static func pages(app: SeasonApp) -> Dictionary:
	var live: bool = app.lab != null
	var wallet: Dictionary = app.loadout.match_snapshot if live else capture(app.season)
	if wallet.is_empty():
		wallet = capture(null)
	var team: TeamMatchState
	var state: MatchState
	if live:
		state = app.lab._match_state
		team = state.home_team if app.lab._player_home else state.away_team
	var result: Dictionary = {"gear": [], "sponsors": [], "supplies": [], "used": []}
	for slot: String in SeasonOwnership.GEAR_SLOTS:
		var receipt: Dictionary = wallet.gear.get(slot, {})
		var item: Dictionary = SeasonGearCatalog.item(receipt.get("item", ""))
		(
			result
			. gear
			. append(
				{
					"receipt": receipt.get("id", ""),
					"name": item.get("name", "Empty" if slot == "misc" else "Standard " + slot),
					"label": slot.to_upper(),
					"effect": item.get("effect", "No equipped modifier."),
					"status": item.get("status", "Working") if not item.is_empty() else "Base",
				}
			)
		)
	for receipt: Dictionary in wallet.sponsors:
		var item: Dictionary = SeasonSponsorCatalog.item(receipt.item)
		var status: String = "Owned this season"
		if receipt.item == "E05":
			var stamps: int = wallet.get("stamps", {}).get(receipt.id, []).size()
			if live:
				stamps = int(team.roster[0].definition.season_sponsors.get("E05", 0))
			status = (
				"%d / 4 stamps • +%d%% Contact exit %s"
				% [stamps, stamps, "this game" if live else "next game"]
			)
		elif receipt.item == "F08" and live:
			status = "%d / 2 announcements left" % state.sure_shot.remaining(team)
			var call: Dictionary = state.sure_shot.current(state)
			if state.defensive_team() == team and not call.is_empty():
				status += " • " + ContentDB.get_pitch(StringName(call.recipe)).display_name
			else:
				status += " • Choose in FIELD before an opposing PA"
		elif receipt.item == "J04" and live:
			status = (
				"First step: " + state.jumpstart_mode.to_upper()
				if state.defensive_team() == team else "Choose in FIELD before an opposing PA"
			)
		elif receipt.item == "F06" and live:
			status = (
				state.sides.label(state)
				if state.batting_team() == team
				else "Next offensive half starts with no prior side"
			)
		elif receipt.item == "E10" and live:
			var lines: Array[String] = []
			for player: PlayerMatchState in team.roster:
				lines.append(player.definition.display_name + " • " + state.cold.label(player))
			item.effect += "\n" + "\n".join(lines)
			status = "Cold resets next game; each hitter keeps their own streak"
		elif receipt.item == "G03" and live:
			status = (
				"Transfer used this game" if team.tactics.checkout.used else "1 transfer remaining"
			)
			if not team.tactics.checkout.options(state, team).is_empty():
				status = "Choose or decline at the supply prompt"
		elif receipt.item == "G05" and live:
			status = "Return used this game" if team.encore_used else "1 pitcher return remaining"
		result.sponsors.append(
			{
				"name": item.name,
				"label": status,
				"effect": item.effect,
				"status": "Working",
				"receipt": receipt.id
			}
		)
	for receipt: Dictionary in wallet.held:
		if live and not SeasonTacticalCatalog.item(receipt.item).is_empty():
			continue
		result.supplies.append(_supply(receipt, live))
	if live:
		for receipt: Dictionary in team.tactics.held:
			var row: Dictionary = _supply(receipt, true)
			if receipt.id == team.tactics.insured_receipt:
				row.label += (
					" • Insured this game"
					if team.roster[0].definition.season_sponsors.get("E04", false)
					else " • Insurance ended"
				)
			result.supplies.append(row)
		for use: Dictionary in team.tactics.consumed:
			for receipt: Dictionary in wallet.held:
				if receipt.id == use.receipt:
					var row: Dictionary = _supply(receipt, true)
					row.label = "Used this game"
					if (
						use.pa == state.plate_appearance_number
						and _active(team.tactics, state, receipt.item)
					):
						row.label = "Active this plate appearance"
					if (
						team.tactics.checkout.inherited_pa == state.plate_appearance_number
						and use.receipt == team.tactics.checkout.inherited_receipt
						and _active(team.tactics, state, receipt.item)
					):
						row.label = "Inherited this PA • no extra copy consumed"
					if use.get("insured", false):
						row.label += " • Replacement after completion, if space"
					result.used.append(row)
	if live:
		for row: Dictionary in result.gear + result.sponsors:
			if app.sales.pending.has(row.get("receipt", "")):
				row.status = "SOLD • Effect ends after this plate appearance"
	result["capacity"] = wallet.capacity
	return result


static func _active(tactics: MatchTactics, state: MatchState, item: String) -> bool:
	# Do not call active(): it may retire Heat as a side effect of pitcher changes.
	if (
		tactics._active_pa != state.plate_appearance_number
		or state.phase == MatchState.Phase.GAME_END
	):
		return false
	if item == SeasonTacticalCatalog.HEAT:
		return tactics._active == item and tactics._heat_pitcher == state.pitcher()
	return (
		item in ["A10", "C03"]
		and (tactics._active == item or tactics._active == MatchTactics.COMBO)
	)


static func _supply(receipt: Dictionary, live: bool) -> Dictionary:
	var item: Dictionary = SeasonTacticalCatalog.item(receipt.item)
	var tactical: bool = not item.is_empty()
	if not tactical:
		item = DevelopmentShopCatalog.item(receipt.item)
	return {
		"name": item.get("name", "Held card"),
		"label":
		(
			"Held • use at the first-pitch prompt"
			if tactical
			else ("Between games only" if live else "Held • apply in the shop")
		),
		"effect": item.get("effect", "Apply to a player in the Season Shop."),
		"status": "Working",
	}

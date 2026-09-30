class_name SeasonBudgetBites
extends RefCounted
## Derived once-fixture grant; no client-supplied Cash, item or capacity override.


static func outcome(build: SeasonBuild) -> String:
	if SeasonSchoolSponsors.active(build, "E08").is_empty():
		return "inactive"
	if build.cash() > 4:
		return "cash"
	var wallet: Dictionary = build._bank.view()
	return "full" if wallet.held.size() >= wallet.capacity.held else "granted"


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	if (
		build._format < 17
		or not build._keys(command, ["game"])
		or not SeasonOwnership._whole(command.game, 0, 32)
		or build.roster().size() != 4
	):
		return "Invalid pregame commitment."
	var game: String = str(int(command.game))
	if build._pregames.has(game) or build._bank.view().rewards.has(game):
		return "This game was already committed or completed."
	if (
		build._format >= 18
		and not SeasonSchoolSponsors.active(build, "J08").is_empty()
		and not build._scouts.has(game)
	):
		return "Choose Film Room's exact recipe before committing this game."
	if build._format >= 26 and not SeasonSchoolSponsors.active(build, "E04").is_empty():
		if not build._insurance.has(game):
			return "Choose or skip Second Chance insurance before committing this game."
	var result: String = outcome(build)
	if result == "granted":
		var granted: Dictionary = build._bank.commit(
			{"id": "budget:" + game, "rev": build._bank.revision(), "op": "budget_grant"}
		)
		if not granted.ok:
			return granted.error
	build._pregames[game] = {"cash": build.cash(), "outcome": result}
	return ""


static func grant(next: Dictionary, command: Dictionary) -> String:
	if not SeasonOwnership._keys(command, ["id", "rev", "op"]):
		return "Invalid Budget Bites grant."
	if (
		next.cash > 4
		or not next.sponsors.any(func(copy: Dictionary) -> bool: return copy.item == "E08")
	):
		return "Budget Bites needs an active sponsor and at most 4 Cash."
	next.held.append({"id": command.id, "item": "C03", "paid": 0, "kind": "held"})
	return ""


static func describe(build: SeasonBuild, fixture_id: int) -> String:
	var previous: Dictionary = build._pregames.get(str(fixture_id), {})
	if not previous.is_empty():
		if previous.outcome == "inactive" and SeasonSchoolSponsors.active(build, "E08").is_empty():
			return ""
		return (
			"Budget Bites already checked this game at %d Cash: %s. No new grant on restart."
			% [
				previous.cash,
				"one Swing Plan granted" if previous.outcome == "granted" else "no grant"
			]
		)
	match outcome(build):
		"inactive":
			return ""
		"cash":
			return (
				"Budget Bites: no Plan at current %d Cash; requires 4 or less when Play Game commits."
				% build.cash()
			)
		"full":
			return (
				"Budget Bites: shared bag is full. Play Game forfeits this game's grant; "
				+ "no delayed queue."
			)
	return (
		"Budget Bites: Play Game will add one free Swing Plan to the shared bag. "
		+ "Unused copies carry. Once/game; opening this screen grants nothing."
	)

class_name SeasonEquipment
extends RefCounted
## Closed Equipment candidate: one inactive paid receipt, shop-bound atomic exchange.


static func owns(wallet: Dictionary, item: String) -> bool:
	for receipt: Dictionary in wallet.get("gear", {}).values() + [wallet.get("spare", {})]:
		if receipt.get("item", "") == item:
			return true
	return false


static func is_spare(build: SeasonBuild, receipt: String) -> bool:
	return (
		LeagueRules.equipment(build._league_rules)
		and not receipt.is_empty()
		and build._bank.view().get("spare", {}).get("id", "") == receipt
	)


static func between_games(build: SeasonBuild) -> bool:
	if (
		build == null
		or not LeagueRules.equipment(build._league_rules)
		or not build._visit.get("open", false)
		or not build._match_inventory.is_empty()
		or build.pack_pending()
	):
		return false
	for game: String in build._pregames:
		if not build._bank.view().rewards.has(game):
			return false
	return true


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	if not between_games(build) or build._visit.number < build._gear_from:
		return "Spare purchases and exchanges are between games in the open shop only."
	if command.op == "spare_swap":
		if not build._keys(command, ["spare", "active"]):
			return "Review the exact spare and matching active receipt."
		var swapped: Dictionary = build._bank.commit(
			{
				"id": "spare-swap:%d" % build.revision(),
				"rev": build._bank.revision(),
				"op": "spare_swap",
				"spare": command.spare,
				"active": command.active
			}
		)
		return "" if swapped.ok else swapped.error
	if (
		command.op != "spare_buy"
		or not build._keys(command, ["offer"])
		or not command.offer is String
	):
		return "Review an exact eligible Gear offer for the spare."
	var wallet: Dictionary = build._bank.view()
	if not wallet.get("spare", {}).is_empty():
		return "The spare is occupied. Sell it explicitly before buying another."
	var item_id: String = build._visit.offers.get(command.offer, "")
	if SeasonGearCatalog.item(item_id).is_empty() or owns(wallet, item_id):
		return "Choose current eligible Gear that is not already owned."
	var quote: String = "spare-quote:%d" % build.revision()
	var stocked: Dictionary = build._bank.commit(
		{"id": quote, "rev": build._bank.revision(), "op": "stock", "offers": {quote: item_id}}
	)
	if not stocked.ok:
		return stocked.error
	var bought: Dictionary = build._bank.commit(
		{
			"id": "spare-purchase:%d" % build.revision(),
			"rev": build._bank.revision(),
			"op": "spare_buy",
			"offer": quote,
			"replace": "",
			"discard": []
		}
	)
	if not bought.ok:
		return bought.error
	build._visit.offers.erase(command.offer)
	return ""


static func preferred_bat(build: SeasonBuild, club: Dictionary) -> String:
	# Provisional visible-roster heuristic, not a matchup optimizer. Ties do not churn.
	var players: Array[String] = build.roster()
	if club.get("profile", "") == "Featured hitter":
		var hitter: String = str(club.get("roles", {}).get("hitter", ""))
		if players.has(hitter):
			players.assign([hitter])
	var contact: int = 0
	var power: int = 0
	for player: String in players:
		contact += int(build.player(player).stats.contact)
		power += int(build.player(player).stats.power)
	if contact == power:
		return ""
	return "BAT-CON-01" if contact < power else "BAT-POW-01"


static func ai_checkout(build: SeasonBuild, club: Dictionary, game: int) -> bool:
	if not between_games(build):
		return false
	var desired: String = preferred_bat(build, club)
	var wallet: Dictionary = build._bank.view()
	if desired.is_empty() or wallet.gear.bat.get("item", "") == desired:
		return false
	var spare: Dictionary = wallet.get("spare", {})
	var request: Dictionary
	var paid: int = 0
	var kind: String
	if spare.get("item", "") == desired:
		request = SeasonOpponentPolicy.command(
			build, "spare_swap", {"spare": spare.id, "active": wallet.gear.bat.get("id", "")}
		)
		kind = "gear_swap"
	elif spare.is_empty() and not wallet.gear.bat.is_empty():
		paid = int(SeasonGearCatalog.item(desired).price)
		if build.cash() < paid + 6:
			return false  # Preserve one ordinary broad-stat purchase worth of Cash.
		for offer: String in build._visit.offers:
			if build._visit.offers[offer] == desired:
				request = SeasonOpponentPolicy.command(build, "spare_buy", {"offer": offer})
				break
		if request.is_empty():
			return false
		kind = "gear_spare"
	else:
		return false
	if not build.commit(request).ok:
		return false
	club.decisions.append(
		{
			"game": game,
			"request": request.id,
			"player": "",
			"stat": kind,
			"item": desired,
			"paid": paid,
			"reason": "visible roster's lower batting stat; provisional policy"
		}
	)
	return true

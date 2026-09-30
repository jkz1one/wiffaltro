class_name SeasonPitchExchange
extends RefCounted
## Replay paid acquisition provenance separately from personal mastery.


static func learned(book: SeasonDevelopment, player: String) -> Dictionary:
	var owners: Dictionary = {}
	for event: Dictionary in book._events:
		if not owners.has(event.player):
			owners[event.player] = {}
		if event.op == "recruit":
			owners[event.player] = {}
		elif event.op == "learn":
			owners[event.player].erase(event.replace)
			owners[event.player][event.target] = event.id
		elif event.op == "exchange":
			var first: String = owners[event.player][event.first]
			var second: String = owners[event.other][event.second]
			owners[event.player].erase(event.first)
			owners[event.other].erase(event.second)
			owners[event.player][event.second] = second
			owners[event.other][event.first] = first
	var result: Dictionary = owners.get(player, {}).duplicate()
	for recipe: String in result.keys():
		if (
			not book.player(player).active.has(recipe)
			or SeasonPlayerCatalog.profile(player).active.has(recipe)
		):
			result.erase(recipe)
	return result


static func prepare(book: SeasonDevelopment, command: Dictionary) -> Dictionary:
	if not SeasonOwnership._keys(
		command, ["id", "rev", "op", "player", "other", "first", "second"]
	):
		return SeasonDevelopment._error("Choose two exact players and learned recipes.")
	for key: String in ["other", "first", "second"]:
		if not command[key] is String:
			return SeasonDevelopment._error("Choose exact recipe identities.")
	if (
		command.player == command.other
		or command.first == command.second
		or not learned(book, command.player).has(command.first)
		or not learned(book, command.other).has(command.second)
	):
		return SeasonDevelopment._error("Exchange different season-learned pitches on two players.")
	var first: Dictionary = book.player(command.player)
	var second: Dictionary = book.player(command.other)
	for pair: Array in [
		[first, command.second, command.first], [second, command.first, command.second]
	]:
		var error: String = SeasonDevelopment._apply(
			pair[0],
			{
				"id": command.id,
				"rev": command.rev,
				"op": "learn",
				"player": pair[0].id,
				"target": pair[1],
				"replace": pair[2]
			}
		)
		if not error.is_empty():
			return SeasonDevelopment._error(error)
	return {"ok": true, "replayed": false, "after": first, "other_after": second}

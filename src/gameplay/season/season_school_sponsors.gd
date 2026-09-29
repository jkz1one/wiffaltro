class_name SeasonSchoolSponsors
extends RefCounted
# gdlint: disable=max-returns
## Working contracts with explicitly unapproved EE eligibility/acquisition mappings.


static func active(build: SeasonBuild, id: String) -> Dictionary:
	for receipt: Dictionary in build._bank.view().sponsors:
		if receipt.item == id:
			return receipt
	return {}


static func eligible_student(build: SeasonBuild, id: String) -> bool:
	return (
		build._roster.has(id)
		and build.player(id).get("catchup", {}).is_empty()
		and not build._book.earned_players([id]).has(id)
	)


static func scholarship(build: SeasonBuild) -> Dictionary:
	var receipt: Dictionary = active(build, "J10")
	return build._scholarships.get(receipt.get("id", ""), {}).duplicate(true)


static func qualifies_union(build: SeasonBuild, performance: Dictionary) -> bool:
	if active(build, "E06").is_empty():
		return false
	var hitters: int = 0
	for id: String in build._roster:
		var line: Dictionary = performance.get(id, {})
		if int(line.get("h", 0)) > 0:
			hitters += 1
	return hitters >= 3


static func concessions(build: SeasonBuild, item_id: String, command: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if (
		build._visit.get("union_credit", 0) > 0
		and (item_id == "pack" or DevelopmentShopCatalog.CARDS.has(item_id))
	):
		result["union"] = 3
	var student: Dictionary = scholarship(build)
	if (
		not student.is_empty()
		and command.get("mode") == "use"
		and command.get("player") == student.player
		and student.uses > 0
		and DevelopmentShopCatalog.item(item_id).get("op") == "stat"
	):
		result["scholarship"] = 4
	return result


static func discount(build: SeasonBuild, item_id: String, command: Dictionary) -> Dictionary:
	var options: Dictionary = concessions(build, item_id, command)
	var selected: Variant = command.get("concession", "")
	if not selected is String:
		return {"error": "Choose one applicable concession."}
	if selected.is_empty():
		if options.size() > 1:
			return {"error": "Choose Union Hall or Summer School; they cannot stack."}
		selected = options.keys()[0] if not options.is_empty() else ""
	if selected != "" and not options.has(selected):
		return {"error": "That concession is not available for this purchase."}
	return {"error": "", "kind": selected, "amount": options.get(selected, 0)}


static func consume(build: SeasonBuild, concession: Dictionary) -> String:
	if concession.kind == "union":
		build._visit["union_credit"] = 0
	elif concession.kind == "scholarship":
		var receipt: Dictionary = active(build, "J10")
		build._scholarships[receipt.id].uses -= 1
		if build._scholarships[receipt.id].uses == 0:
			return retire(build, receipt.id)
	return ""


static func retire(build: SeasonBuild, receipt_id: String) -> String:
	var result: Dictionary = build._bank.commit(
		{
			"id": "scholar-retire:%d" % build.revision(),
			"rev": build._bank.revision(),
			"op": "sell",
			"receipt": receipt_id,
			"discard": []
		}
	)
	if result.ok:
		build._scholarships.erase(receipt_id)
	return "" if result.ok else result.error


static func departure(build: SeasonBuild, player_id: String) -> String:
	var student: Dictionary = scholarship(build)
	if not student.is_empty() and student.player == player_id:
		return retire(build, active(build, "J10").id)
	return ""


static func pair_price(price: int) -> int:
	return price + ceili(float(price) / 2.0)


static func has_pair_targets(build: SeasonBuild, id: String) -> bool:
	var first: String = ""
	for target: Dictionary in build.targets(id):
		if not first.is_empty() and target.player != first:
			return true
		first = target.player
	return false


static func pair_available(build: SeasonBuild, id: String) -> bool:
	var item: Dictionary = DevelopmentShopCatalog.item(id)
	return (
		build._format >= 11
		and not active(build, "F04").is_empty()
		and not build._visit.get("pair_used", false)
		and item.get("op") == "learn"
		and ContentDB.get_pitch(StringName(item.recipe)).rarity != PitchDefinition.Rarity.EXOTIC
		and has_pair_targets(build, id)
	)


static func pair(build: SeasonBuild, command: Dictionary) -> String:
	if not SeasonBuild._keys(command, ["offer", "first", "second"]) or not command.offer is String:
		return "Choose one lesson offer and two exact recipients."
	var id: String = build._visit.offers.get(command.offer, "")
	if not pair_available(build, id):
		return "No eligible Open Book paired lesson remains this visit."
	for target: Variant in [command.first, command.second]:
		if (
			not target is Dictionary
			or not SeasonOwnership._keys(target, ["player", "pitch", "replace"])
		):
			return "Choose both legal recipients and replacements."
	if command.first.player == command.second.player:
		return "Open Book requires two distinct players."
	var error: String = build._develop(id, command.first, ":first")
	if error.is_empty():
		error = build._develop(id, command.second, ":second")
	if error.is_empty():
		error = build._charge(pair_price(DevelopmentShopCatalog.item(id).price))
	if not error.is_empty():
		return error
	build._visit.offers.erase(command.offer)
	build._visit["pair_used"] = true
	return ""


static func has_credit(shop: Dictionary) -> bool:
	return SeasonReclamation.credit(shop) > 0 or shop.get("union_credit", 0) > 0


static func review(before: Dictionary, after: Dictionary) -> String:
	var text: String = ""
	if before.shop.get("union_credit", 0) != after.shop.get("union_credit", 0):
		text += (
			"\nUnion credit: %d → %d, separate from Cash; consumed at acquisition."
			% [before.shop.get("union_credit", 0), after.shop.get("union_credit", 0)]
		)
	if before.scholarships != after.scholarships:
		var old_uses: int = (
			0 if before.scholarships.is_empty() else int(before.scholarships.values()[0].uses)
		)
		var next_uses: int = (
			0 if after.scholarships.is_empty() else int(after.scholarships.values()[0].uses)
		)
		text += "\nSummer School discounts remaining: %d → %d. " % [old_uses, next_uses]
		text += "Fixed student; retires after three uses or departure, for 0 Cash."
	return text

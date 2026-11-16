class_name SeasonTacticalDiscard
extends RefCounted
## Explicitly discarded used copies retain evidence only for this attempt, never inventory.


static func record(build: SeasonBuild, command: Dictionary) -> String:
	var uses: Variant = command.get("discarded_use", [])
	var selected: Variant = command.get("discard", [])
	if not uses is Array or not selected is Array:
		return "Review exact supply discards and completed activations."
	var proof: Dictionary = build._match_inventory.get("discarded", {}).duplicate(true)
	for action: Variant in uses:
		if not action is Dictionary or not action.get("receipt") is String:
			return "Invalid discarded activation."
		var id: String = action.receipt
		var copy: Dictionary = SeasonOwnership._owned(build._bank.view(), id)
		if not selected.has(id) or proof.has(id) or copy.get("kind") != "held":
			return "Discard each currently owned used copy once."
		if not SeasonTacticalCatalog.catalog().has(copy.item):
			return "Only tactical supplies have activation evidence."
		if not _valid_action(build, action, copy):
			return "Review an exact activation for this saved copy."
		proof[id] = {"copy": copy.duplicate(true), "action": action.duplicate(true)}
	build._match_inventory["discarded"] = proof
	return ""


static func copy_for(build: SeasonBuild, receipt: String, game: int) -> Dictionary:
	var owned: Dictionary = SeasonOwnership._owned(build._bank.view(), receipt)
	if not owned.is_empty():
		return owned
	if build._format < 32 or build._match_inventory.get("game", -2) != game:
		return {}
	if (
		build._format >= 34
		and receipt == SeasonFieldGrant.receipt(game)
		and build._match_inventory.get("field_grant", {}).get("outcome") == "granted"
	):
		return SeasonFieldGrant.copy(game)
	return build._match_inventory.get("discarded", {}).get(receipt, {}).get("copy", {})


static func valid(build: SeasonBuild, actions: Array, game: int) -> bool:
	if build._format < 32 or build._match_inventory.get("game", -2) != game:
		return true
	for proof: Dictionary in build._match_inventory.get("discarded", {}).values():
		var found: bool = false
		for action: Variant in actions:
			var settled: Variant = action.duplicate(true) if action is Dictionary else action
			if settled is Dictionary and not proof.action.has("walked"):
				settled.erase("walked")
			if ClubCareer.same(settled, proof.action):
				found = true
		if not found:
			return false
	return true


static func _valid_action(build: SeasonBuild, action: Dictionary, copy: Dictionary) -> bool:
	var fields: Array = ["receipt", "player", "pa", "swing"]
	for optional: String in ["walked", "insured", "combo"]:
		if action.has(optional):
			fields.append(optional)
			if action[optional] != true or not action[optional] is bool:
				return false
	if copy.item == SeasonTacticalCatalog.BASE:
		fields.append("advance")
		if not action.get("advance") is Dictionary:
			return false
	if not SeasonOwnership._keys(action, fields):
		return false
	return (
		action.player is String
		and build.roster().has(action.player)
		and SeasonOwnership._whole(action.pa, 1, 9999)
		and (
			action.swing in ["swing.contact", "swing.power"]
			if copy.item == "C03"
			else action.swing == ""
		)
	)

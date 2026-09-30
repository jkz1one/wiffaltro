class_name SeasonMatchInventory
extends RefCounted
## Replayable attempt snapshot: sold first-release copies still prove completed use.
# gdlint: disable=max-returns


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	var starting: bool = command.op == "match_inventory"
	var fields: Array = ["game"] if starting else ["game", "receipt", "first_pitch"]
	if (
		build._format < 22
		or build._market != 0
		or not build._keys(command, fields)
		or not SeasonOwnership._whole(command.game, 0, 32)
		or build.roster().size() != 4
		or build._bank.view().rewards.has(str(int(command.game)))
	):
		return "Invalid match inventory transaction."
	if starting:
		build._match_inventory = {
			"game": int(command.game),
			"gear": build._bank.view().gear.duplicate(true),
			"first_pitch": null
		}
		return ""
	var attempt: Dictionary = build._match_inventory
	if attempt.is_empty() or attempt.game != command.game or not command.receipt is String:
		return "Start the current match before selling."
	var owned: Dictionary = SeasonOwnership._owned(build._bank.view(), command.receipt)
	if owned.get("kind") not in ["gear", "sponsor"]:
		return "Choose Gear or a sponsor you still own."
	var first: Variant = command.first_pitch
	if first != null:
		if not first is Array or first != SeasonReclamation.receipts(attempt):
			return "First-release Gear evidence changed."
	elif attempt.first_pitch != null:
		return "This match already recorded its first release."
	var sold: Dictionary = build._bank.commit(
		{
			"id": "match-sale:%d" % build.revision(),
			"rev": build._bank.revision(),
			"op": "sell",
			"receipt": command.receipt,
			"discard": []
		}
	)
	if not sold.ok:
		return sold.error
	attempt.first_pitch = first.duplicate() if first is Array else null
	if first == null and owned.kind == "gear":
		attempt.gear[SeasonGearCatalog.item(owned.item).slot] = {}
	# Reclamation credit belongs to a shop visit; a live sale grants only its Cash refund.
	build._used_gear.erase(owned.id)
	build._scholarships.erase(owned.id)
	return ""


static func gear(build: SeasonBuild) -> Dictionary:
	return build._match_inventory.get("gear", build._bank.view().gear)

class_name SeasonReclamation
extends RefCounted
## Derived from receipt-specific completed-game evidence and the replayed journal.


static func receipts(wallet: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for receipt: Dictionary in wallet.gear.values():
		if not receipt.is_empty() and receipt.paid > 0:
			result.append(receipt.id)
	result.sort()
	return result


static func settle(build: SeasonBuild, evidence: Variant, performance: Dictionary) -> String:
	if not evidence is Array or evidence.size() > 3:
		return "Invalid first-pitch Gear evidence."
	if evidence.is_empty():
		return ""
	var actual: Array[String] = receipts(build._bank.view())
	var submitted: Array[String] = []
	for id: Variant in evidence:
		if not id is String or submitted.has(id):
			return "Invalid first-pitch Gear receipt."
		submitted.append(id)
	submitted.sort()
	if submitted != actual or performance.is_empty():
		return "Used Gear must match the completed game's equipped paid copies."
	for id: String in submitted:
		build._used_gear[id] = true
	return ""


static func sold(build: SeasonBuild, receipt: Dictionary) -> void:
	if receipt.is_empty():
		return
	var qualified: bool = build._used_gear.has(receipt.id) and receipt.paid > 0
	build._used_gear.erase(receipt.id)
	if not qualified or build._visit.get("reclamation_used", false):
		return
	for sponsor: Dictionary in build._bank.view().sponsors:
		if sponsor.item == "F05":
			build._visit["reclamation_used"] = true
			build._visit["reroll_credit"] = 2
			return


static func credit(shop: Dictionary) -> int:
	return int(shop.get("reroll_credit", 0))


static func price(shop: Dictionary) -> int:
	return maxi(0, 4 + 2 * int(shop.rerolls) - credit(shop))


static func review(before: Dictionary, after: Dictionary) -> String:
	var old: int = credit(before)
	var next: int = credit(after)
	if old == next:
		return ""
	return (
		(
			"\nReroll credit: %d → %d (separate from Cash). "
			+ "Next individual reroll only; expires when leaving the shop. "
			+ "Cannot fund this purchase, packs or recruiting."
		)
		% [old, next]
	)

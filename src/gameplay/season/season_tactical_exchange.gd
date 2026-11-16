class_name SeasonTacticalExchange
extends RefCounted
## Selected testing allowlist. The aggregate owns eligibility and once-visit use.

const TYPES: Array[String] = ["A10", "C03", "C02", SeasonTacticalCatalog.HEAT]


static func reason(build: SeasonBuild, receipt: String, target: String) -> String:
	if build._format < 16 or not build._visit.open:
		return "Exchange only in an open shop."
	if SeasonSchoolSponsors.active(build, "J07").is_empty():
		return "Pick & Mix Market must be active."
	if build._visit.get("mix_used", false):
		return "Pick & Mix was already used this visit."
	var old: Dictionary = SeasonOwnership._owned(build._bank.view(), receipt)
	if old.is_empty() or old.kind != "held" or not TYPES.has(old.item):
		return "Choose an owned Tape, Plan, Recovery or Heat copy."
	if target == old.item or not TYPES.has(target):
		return "Choose a different eligible tactical type; Take a Base is excluded."
	if not SeasonTacticalCatalog.catalog(build._tactical_catalog_version()).has(target):
		return "That tactical type is not available yet."
	if build.cash() < cost(old.item, target):
		return "Insufficient Cash for the list-price difference."
	return ""


static func cost(source: String, target: String) -> int:
	return maxi(
		0, SeasonTacticalCatalog.item(target).price - SeasonTacticalCatalog.item(source).price
	)


static func exchange(build: SeasonBuild, command: Dictionary) -> String:
	if (
		not build._keys(command, ["receipt", "item"])
		or not command.receipt is String
		or not command.item is String
	):
		return "Review an exact source copy and target type."
	var error: String = reason(build, command.receipt, command.item)
	if not error.is_empty():
		return error
	var result: Dictionary = build._bank.commit(
		{
			"id": "tactical-exchange:%d" % build.revision(),
			"rev": build._bank.revision(),
			"op": "tactical_exchange",
			"receipt": command.receipt,
			"item": command.item
		}
	)
	if not result.ok:
		return result.error
	build._visit["mix_used"] = true
	return ""


static func apply(next: Dictionary, command: Dictionary) -> String:
	if not SeasonOwnership._keys(command, ["id", "rev", "op", "receipt", "item"]):
		return "Invalid tactical exchange."
	if not command.receipt is String or not command.item is String:
		return "Invalid tactical exchange target."
	var old: Dictionary = SeasonOwnership._owned(next, command.receipt)
	if old.is_empty() or old.kind != "held" or not TYPES.has(old.item):
		return "Exchange only an eligible owned copy."
	if not TYPES.has(command.item) or command.item == old.item:
		return "Exchange only for a different eligible type."
	var amount: int = cost(old.item, command.item)
	next.held.erase(old)
	next.held.append({"id": command.id, "item": command.item, "kind": "held", "paid": amount})
	next.cash -= amount
	return ""

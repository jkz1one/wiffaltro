class_name SeasonSecondChance
extends RefCounted
# gdlint: disable=max-returns
## Selection is locked before play; a completed consumed-copy claim settles once.

const ITEMS: Dictionary = {
	"E04":
	{
		"name": "Second Chance Supply",
		"price": 14,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Before a game, insure one exact Tape, Plan, Recovery or Extra Heat copy. "
			+ "Consume it while this sponsor is active to restore one fresh copy after a completed game, "
			+ "only if space remains. No Take a Base, extra slot or same-game reuse."
		)
	}
}
const ELIGIBLE: Array[String] = ["A10", "C02", "C03", "tactical.extra_heat"]


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	if (
		build._format < 26
		or build._market != 0
		or not build._keys(command, ["game", "receipt"])
		or not SeasonOwnership._whole(command.game, 0, 32)
		or not command.receipt is String
	):
		return "Choose an exact insurance copy for this game."
	var game: String = str(int(command.game))
	if (
		build._insurance.has(game)
		or build._pregames.has(game)
		or build._bank.view().rewards.has(game)
	):
		return "Insurance is locked for this game."
	var sponsor: Dictionary = SeasonSchoolSponsors.active(build, "E04")
	if sponsor.is_empty():
		return "Second Chance must be active."
	var copy: Dictionary = SeasonOwnership._owned(build._bank.view(), command.receipt)
	if command.receipt != "" and (copy.get("kind") != "held" or copy.get("item") not in ELIGIBLE):
		return "Choose an owned Tape, Plan, Recovery or Extra Heat copy, or skip insurance."
	build._insurance[game] = {
		"receipt": command.receipt,
		"item": copy.get("item", ""),
		"sponsor": sponsor.id,
		"outcome": "pending"
	}
	return ""


static func choose(app: SeasonApp, build: SeasonBuild, game: int) -> String:
	if build._insurance.has(str(game)) or SeasonSchoolSponsors.active(build, "E04").is_empty():
		return ""
	if app.insurance_game != game or app.insurance_receipt == "?":
		return "Choose or skip Second Chance insurance in Prepare Next Game before playing."
	var result: Dictionary = build.commit(
		{
			"id": "insure:%d" % game,
			"rev": build.revision(),
			"op": "insure",
			"game": game,
			"receipt": app.insurance_receipt
		}
	)
	return "" if result.ok else result.error


static func target(build: SeasonBuild, game: int) -> String:
	var mark: Dictionary = build._insurance.get(str(game), {})
	if mark.is_empty() or mark.outcome != "pending":
		return ""
	if SeasonSchoolSponsors.active(build, "E04").get("id", "") != mark.sponsor:
		return ""
	return mark.receipt


static func valid_claim(build: SeasonBuild, game: int, action: Dictionary) -> bool:
	var mark: Dictionary = build._insurance.get(str(game), {})
	return (
		build._format >= 26
		and action.insured is bool
		and action.insured
		and not mark.is_empty()
		and mark.outcome == "pending"
		and mark.receipt == action.receipt
		and mark.item in ELIGIBLE
	)


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	var game: String = str(int(command.game))
	var mark: Dictionary = build._insurance.get(game, {})
	if mark.is_empty():
		return ""
	var claimed: bool = false
	for action: Dictionary in command.get("tactics", []):
		claimed = claimed or (action.receipt == mark.receipt and action.get("insured", false))
	mark.outcome = "not_used" if mark.receipt != "" else "skipped"
	if not claimed:
		return ""
	var wallet: Dictionary = build._bank.view()
	if wallet.held.size() >= wallet.capacity.held:
		mark.outcome = "full"
		return ""
	var result: Dictionary = build._bank.commit(
		{
			"id": "insurance:" + game,
			"rev": build._bank.revision(),
			"op": "insurance_grant",
			"item": mark.item
		}
	)
	if not result.ok:
		return result.error
	mark.outcome = "restored"
	return ""


static func grant(next: Dictionary, command: Dictionary) -> String:
	if (
		not SeasonOwnership._keys(command, ["id", "rev", "op", "item"])
		or command.item not in ELIGIBLE
	):
		return "Invalid completed-game insurance grant."
	next.held.append({"id": command.id, "item": command.item, "paid": 0, "kind": "held"})
	return ""

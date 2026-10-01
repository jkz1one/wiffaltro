class_name MatchFieldSupply
extends RefCounted
## Attempt-only generation. No acquired copy survives an abandoned/restarted match.

var clean: int = 0
var capacity: int = 2
var reserved: int = 0
var receipt: String = "field-supply:match"
var _pending: int = 0
var _delivery: Dictionary = {}


func record(state: MatchState, row: Dictionary) -> void:
	if clean >= 3 or not row.clean:
		return
	if not state.pitcher().definition.season_sponsors.get("B01", false):
		return
	clean += 1
	if clean == 3:
		_pending = int(row.pa)


func deliver(state: MatchState, team: TeamMatchState) -> void:
	if _pending == 0 or not state.between_batters:
		return
	var full: bool = team.tactics.held.size() + reserved >= capacity
	_delivery = {"after_pa": _pending, "outcome": "full" if full else "granted"}
	_pending = 0
	if not full:
		team.tactics.held.append({"id": receipt, "item": "A10", "paid": 0, "kind": "held"})


func evidence() -> Dictionary:
	return _delivery.duplicate(true)


func label() -> String:
	if _delivery.get("outcome") == "full":
		return "Bag full at delivery • this game's Tape forfeited; no queue"
	if _delivery.get("outcome") == "granted":
		return "Grip Tape delivered • this game's generation used"
	return "%d / 3 clean fielded outs • one Tape if the shared bag has room" % clean


static func sync_capacity(team: TeamMatchState, wallet: Dictionary) -> void:
	team.field_supply.capacity = int(wallet.capacity.held)
	team.field_supply.reserved = wallet.held.size() - SeasonTacticalCatalog.held(wallet).size()

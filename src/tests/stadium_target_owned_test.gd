extends Node
## Exact K-gated target receipts, one primary socket and frozen surface ownership.

var _failures: int = 0


func _ready() -> void:
	var credits: Array = [220, 195]
	var progress: Array = [{"seasons": 1, "wins": 10, "strikeouts": 39},
		{"seasons": 1, "wins": 10, "strikeouts": 1}]
	var ledger: ClubAssetLedger = ClubAssetLedger.new(9, credits, progress)
	var original: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var buy: Dictionary = _buy(ledger, 2)
	_check(ledger.commit(buy).ok and ledger.balance() == 45,
		"230 blueprint plus two seventy-CB copies")
	_check(ledger.commit(buy).replayed and ledger.balance() == 45, "paid target retry is idempotent")
	_check(ledger.construction().copies.size() == 5,
		"two targets grant no catching net or third target")
	var layout: Dictionary = StadiumTargetItems.upgrade(StadiumStarterLayout.empty())
	layout.target = "purchase:target:0:0"
	_check(ledger.commit({"id": "draft", "rev": 1, "op": "stadium_draft", "layout": layout}).ok,
		"one exact target-only configuration can be drafted")
	_check(ledger.commit({"id": "apply", "rev": 2, "op": "stadium_apply", "layout": layout,
		"geometry": StadiumHomeLayout.geometry("backyard", layout)}).ok, "saved target applies free")
	_check(StadiumLayoutSnapshot.matches(original, ledger), "old receiver snapshot prefix stays valid")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(snapshot.layout.version == 7 and StadiumLayoutSnapshot.matches(snapshot, ledger),
		"new snapshot binds exact target-only model and presentation policy")
	var next: Dictionary = layout.duplicate(true)
	next.target = "purchase:target:0:1"
	var preview: Dictionary = StadiumHomeLayout.preview(layout, next, ledger.construction())
	_check(preview.ok and preview.cost == 0 and preview.displaced == ["purchase:target:0:0"],
		"replacement stores the old exact copy without a fee")
	next = layout.duplicate(true)
	next.receiver = "starter-v1:ST-079"
	_check(not StadiumHomeLayout.validate(next, ledger.construction()).ok,
		"chair and target cannot occupy the same primary socket")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 9, credits, progress)
	_check(restored != null and ClubCareer.same(restored.view(), ledger.view()),
		"exact target receipts and saved layout replay")
	_tamper(ledger, credits, progress)
	_surfaces(ledger, layout)
	if _failures == 0:
		print("Wiffaltro owned target checks passed: K gate, exact socket, snapshots and named surfaces.")
	get_tree().quit(0 if _failures == 0 else 1)


func _buy(ledger: ClubAssetLedger, quantity: int = 1) -> Dictionary:
	return {"id": "target:%d" % ledger.revision(), "rev": ledger.revision(), "op": "stadium_buy",
		"item": "ST-026", "quantity": quantity, "price_version": 5, "through": 2, "progress_through": 2}


func _tamper(ledger: ClubAssetLedger, credits: Array, progress: Array) -> void:
	var fresh: ClubAssetLedger = ClubAssetLedger.new(9, credits, progress)
	for patch: Dictionary in [{"price_version": 4}, {"price_version": true}, {"item": "ST-025"},
		{"item": "ST-079"}, {"progress_through": 1}, {"strikeouts": 999}, {"quantity": 0}]:
		var command: Dictionary = _buy(fresh)
		command.merge(patch, true)
		_check(not fresh.commit(command).ok and fresh.revision() == 0,
			"unsupported recipe, forged statistic or stale prefix cannot buy a target")
	var short_progress: Array = progress.duplicate(true)
	short_progress[0].strikeouts = 38
	var short_club: ClubAssetLedger = ClubAssetLedger.new(9, credits, short_progress)
	_check(not short_club.commit(_buy(short_club)).ok, "thirty-nine recorded K remains locked")
	var data: Dictionary = ledger.to_data()
	data.version = 11
	data.erase("target_catalog")
	data.erase("target_layout_catalog")
	data.erase("net_catalog")
	data.erase("net_layout_catalog")
	data.erase("light_catalog")
	data.erase("light_layout_catalog")
	data.erase("infield_catalog")
	data.erase("infield_layout_catalog")
	data.erase("wall_catalog")
	data.erase("wall_layout_catalog")
	data.erase("surface_catalog")
	data.erase("surface_layout_catalog")
	data.erase("surface_origin")
	data.erase("wall_piece_catalog")
	data.erase("advanced_layout_catalog")
	data.erase("scoreboard_catalog")
	data.erase("scoreboard_layout_catalog")
	data.erase("mounted_scoreboard_layout_catalog")
	data.erase("pool_catalog")
	data.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(data, 9, credits, progress) == null,
		"old header cannot smuggle new target purchases")
	data = fresh.to_data()
	data.version = 11
	data.erase("target_catalog")
	data.erase("target_layout_catalog")
	data.erase("net_catalog")
	data.erase("net_layout_catalog")
	data.erase("light_catalog")
	data.erase("light_layout_catalog")
	data.erase("infield_catalog")
	data.erase("infield_layout_catalog")
	data.erase("wall_catalog")
	data.erase("wall_layout_catalog")
	data.erase("surface_catalog")
	data.erase("surface_layout_catalog")
	data.erase("surface_origin")
	data.erase("wall_piece_catalog")
	data.erase("advanced_layout_catalog")
	data.erase("scoreboard_catalog")
	data.erase("scoreboard_layout_catalog")
	data.erase("mounted_scoreboard_layout_catalog")
	data.erase("pool_catalog")
	data.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(data, 9, credits, progress) != null,
		"old larger-seating header stays readable")


func _surfaces(ledger: ClubAssetLedger, layout: Dictionary) -> void:
	var placed: Dictionary = StadiumHomeLayout.validate(layout, ledger.construction()).placements[0]
	var event: Dictionary = {"source": "item", "id": placed.copy, "surface": "ST026_PANEL",
		"role": "RECEIVER_CONTAINMENT_FOUL", "position": [0, 1.05, -1.05], "time": 0.1,
		"kind": "contact"}
	var placements: Dictionary = {placed.copy: placed}
	_check(PhysicalStadiumContacts._event(event, placements),
		"frozen target owns its actual panel event")
	for patch: Dictionary in [{"surface": "ST079_BACK"}, {"surface": "ST025_NET"},
		{"id": "foreign"}, {"role": "LIVE_RICOCHET"}, {"position": [0, 1, -3]}]:
		var bad: Dictionary = event.duplicate(true)
		bad.merge(patch, true)
		_check(not PhysicalStadiumContacts._event(bad, placements),
			"foreign or misplaced contact rejects")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

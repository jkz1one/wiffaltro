extends "res://src/tests/stadium_target_owned_test.gd"
## Separate receipts, exact paired placement, legacy headers and surface provenance.


func _ready() -> void:
	var credits: Array = [220, 195, 220, 195]
	var progress: Array = []
	for index in range(4):
		progress.append({"seasons": 1, "wins": 2, "strikeouts": 10})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(9, credits, progress)
	var original: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var target_buy: Dictionary = _buy_item(ledger, "ST-026", 5, 1)
	_check(ledger.commit(target_buy).ok and ledger.balance() == 530, "target costs 300 separately")
	var net_buy: Dictionary = _buy_item(ledger, "ST-025", 6, 2)
	_check(ledger.commit(net_buy).ok and ledger.balance() == 50,
		"net blueprint plus two copies costs 480")
	_check(ledger.commit(net_buy).replayed and ledger.balance() == 50, "net retry pays once")
	var layout: Dictionary = StadiumNetItems.upgrade(StadiumStarterLayout.empty())
	layout.target = "purchase:net-owned:0:0"
	layout.net = "purchase:net-owned:1:0"
	_check(ledger.commit({"id": "draft", "rev": 2, "op": "stadium_draft", "layout": layout}).ok,
		"paired layout drafts exact two paid copies")
	_check(ledger.commit({"id": "apply", "rev": 3, "op": "stadium_apply", "layout": layout,
		"geometry": StadiumHomeLayout.geometry("backyard", layout)}).ok, "pair applies free")
	_check(StadiumLayoutSnapshot.matches(original, ledger), "earlier snapshot prefix unchanged")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(snapshot.layout.version == 8 and StadiumLayoutSnapshot.matches(snapshot, ledger),
		"paired snapshot binds both exact copies and presentation")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 9, credits, progress)
	_check(restored != null and ClubCareer.same(restored.view(), ledger.view()),
		"paired receipts replay")
	for patch: Dictionary in [{"target": ""}, {"target": "starter-v1:ST-079"},
		{"net": "foreign"}, {"net": layout.target}, {"receiver": "starter-v1:ST-079"}]:
		var bad: Dictionary = layout.duplicate(true)
		bad.merge(patch, true)
		_check(not StadiumHomeLayout.validate(bad, ledger.construction()).ok,
			"net-only, wrong copy, duplicate identity or chair stack rejects")
	var replacement: Dictionary = layout.duplicate(true)
	replacement.net = "purchase:net-owned:1:1"
	var preview: Dictionary = StadiumHomeLayout.preview(layout, replacement, ledger.construction())
	_check(preview.ok and preview.cost == 0 and preview.displaced == [layout.net],
		"net swap stores only old net and keeps target")
	replacement.net = ""
	_check(StadiumHomeLayout.validate(replacement, ledger.construction()).placements.size() == 1,
		"net removal keeps supported target-only configuration")
	var old: Dictionary = ledger.to_data()
	old.version = 12
	old.erase("net_catalog")
	old.erase("net_layout_catalog")
	old.erase("light_catalog")
	old.erase("light_layout_catalog")
	old.erase("infield_catalog")
	old.erase("infield_layout_catalog")
	old.erase("wall_catalog")
	old.erase("wall_layout_catalog")
	old.erase("surface_catalog")
	old.erase("surface_layout_catalog")
	old.erase("surface_origin")
	old.erase("wall_piece_catalog")
	old.erase("advanced_layout_catalog")
	old.erase("scoreboard_catalog")
	old.erase("scoreboard_layout_catalog")
	old.erase("mounted_scoreboard_layout_catalog")
	old.erase("pool_catalog")
	old.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(old, 9, credits, progress) == null,
		"old header rejects net receipts")
	var fresh: ClubAssetLedger = ClubAssetLedger.new(9, credits, progress)
	old = fresh.to_data()
	old.version = 12
	old.erase("net_catalog")
	old.erase("net_layout_catalog")
	old.erase("light_catalog")
	old.erase("light_layout_catalog")
	old.erase("infield_catalog")
	old.erase("infield_layout_catalog")
	old.erase("wall_catalog")
	old.erase("wall_layout_catalog")
	old.erase("surface_catalog")
	old.erase("surface_layout_catalog")
	old.erase("surface_origin")
	old.erase("wall_piece_catalog")
	old.erase("advanced_layout_catalog")
	old.erase("scoreboard_catalog")
	old.erase("scoreboard_layout_catalog")
	old.erase("mounted_scoreboard_layout_catalog")
	old.erase("pool_catalog")
	old.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(old, 9, credits, progress) != null,
		"old target header still reads")
	for metrics: Dictionary in [{"seasons": 2, "wins": 8}, {"seasons": 3, "wins": 7}]:
		_check(not StadiumPurchases.quote(StadiumStock.new_club(), "ST-025", 1, "locked", 6,
			metrics).ok, "both completed seasons and wins required")
	_check(StadiumPurchases.quote(StadiumStock.new_club(), "ST-025", 1, "gate", 6,
		{"seasons": 3, "wins": 8}).cost == 390, "exact net gate and first-copy price")
	_net_surfaces(ledger, layout)
	if _failures == 0:
		print("Wiffaltro owned net checks passed: exact paid pair, gates, storage and frozen provenance.")
	get_tree().quit(0 if _failures == 0 else 1)


func _buy_item(ledger: ClubAssetLedger, item: String, family: int, quantity: int) -> Dictionary:
	return {"id": "net-owned:%d" % ledger.revision(), "rev": ledger.revision(), "op": "stadium_buy",
		"item": item, "quantity": quantity, "price_version": family, "through": 4, "progress_through": 4}


func _net_surfaces(ledger: ClubAssetLedger, layout: Dictionary) -> void:
	var placements: Dictionary = {}
	for row: Dictionary in StadiumHomeLayout.validate(layout, ledger.construction()).placements:
		placements[row.copy] = row
	var event: Dictionary = {"source": "item", "id": layout.net, "surface": "ST025_NET",
		"role": "RECEIVER_CONTAINMENT_FOUL", "position": [1.1, 1.3, -2.2], "time": 0.1,
		"kind": "contact"}
	_check(PhysicalStadiumContacts._event(event, placements), "exact net owns its contact")
	for patch: Dictionary in [{"surface": "ST026_PANEL"}, {"id": layout.target},
		{"id": "purchase:net-owned:1:1"}, {"position": [1.1, 1.3, -1]}, {"role": "LIVE_RICOCHET"}]:
		var bad: Dictionary = event.duplicate(true)
		bad.merge(patch, true)
		_check(not PhysicalStadiumContacts._event(bad, placements), "wrong net provenance rejects")

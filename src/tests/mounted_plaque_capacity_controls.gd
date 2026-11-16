extends Node
## Supplementary pure-data controls. Synthetic record, no authentic earned-history claim.
## No filesystem writes, save activation, production source mutation or original-default credit.

const ACCESS: Array[String] = StadiumSurfaceProgression.INITIAL_LEGACY
const PROGRESS: Dictionary = {"seasons": 50, "wins": 200}
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	_run()
	print(
		(
			"MOUNTED_PLAQUE_CAPACITY_SUPPLEMENT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"synthetic_records": 1,
					"authentic_achievements": 0,
					"original_default_credit": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures.append(label)
		push_error("MOUNTED_PLAQUE_CAPACITY_SUPPLEMENT: " + label)
	return ok


func _layout() -> Dictionary:
	return StadiumScoreboardLayout.upgrade(
		StadiumAdvancedWallLayout.upgrade(
			StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ACCESS, true)
		)
	)


func _valid(
	stock: StadiumStock, pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership
) -> bool:
	return bool(
		StadiumScoreboardLayout.validate(_layout(), stock, pieces, boards, ACCESS, "mogul").get(
			"ok", false
		)
	)


func _record() -> Dictionary:
	return {
		"version": 1,
		"player_id": "player.alex_finch",
		"display_name": "Synthetic capacity control",
		"uniform_number": null,
		"season_id": 3,
		"award_game": 5,
		"award_completed": true,
		"era": StadiumClubIdentity.current(),
		"stats":
		{
			"hits": 40,
			"strikeouts": 0,
			"clean_outs": 0,
			"completed_seasons": [1, 2, 3],
			"credited_games": {"1": 5, "2": 5, "3": 5},
			"eligible": true,
			"evidence": "prospective-known-minimum"
		}
	}


func _run() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	var boards: StadiumScoreboardOwnership = StadiumScoreboardOwnership.new()
	_check(
		stock.capacity_count() == stock.copies.size() and stock.plaque_count() == 0,
		"non-plaque legacy capacity equals exact inventory count"
	)
	var quote: Dictionary = stock.quote(
		"ST-001", StadiumStock.MAX_COPIES - 1 - stock.copies.size(), PROGRESS, "mounted-capacity"
	)
	if not _check(
		quote.get("ok", false), "normal purchase API creates synthetic boundary inventory"
	):
		return
	stock = StadiumStock.from_data(quote.state)
	if not _check(stock != null, "boundary inventory independently decodes"):
		return
	quote = boards.quote(1, "capacity-board", PROGRESS, stock.capacity_count())
	if not _check(quote.get("ok", false), "one ordinary electronic board fills combined capacity"):
		return
	boards = StadiumScoreboardOwnership.from_data(quote.state, stock.capacity_count())
	if not _check(boards != null, "boundary board independently decodes"):
		return
	_check(
		stock.capacity_count() == 4095 and boards.copies.size() == 1,
		"exact 4096 combined ordinary copy boundary is reached"
	)
	_check(_valid(stock, pieces, boards), "layout14 accepts exact capacity without plaques")
	var before: Dictionary = stock.to_data()
	var record: Dictionary = _record()
	if not _check(
		StadiumPlaqueRewards.valid_record(record),
		"explicit synthetic plaque record is structurally valid"
	):
		return
	quote = stock.plaque_quote(record)
	if not _check(
		quote.get("ok", false) and quote.get("cost", -1) == 0,
		"production pure proposal admits the separate plaque reserve"
	):
		return
	_plaque_inventory_readback(stock, pieces, boards, quote, before)


func _plaque_inventory_readback(
	stock: StadiumStock, pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership,
	quote: Dictionary, before: Dictionary
) -> void:
	var with_plaque: StadiumStock = StadiumStock.from_data(quote.state)
	if not _check(with_plaque != null, "plaque inventory decodes with current schema"):
		return
	_check(
		ClubCareer.same(before, stock.to_data()), "plaque proposal does not mutate original stock"
	)
	_check(
		(
			with_plaque.copies.size() == 4096
			and with_plaque.plaque_count() == 1
			and with_plaque.capacity_count() == stock.capacity_count()
		),
		"exactly the structurally valid plaque is outside ordinary capacity"
	)
	_check(
		StadiumScoreboardOwnership.from_data(boards.to_data(), with_plaque.copies.size()) == null,
		"old total-count expression rejects this discriminating boundary"
	)
	_check(
		(
			StadiumScoreboardOwnership.from_data(boards.to_data(), with_plaque.capacity_count())
			!= null
		),
		"current capacity-count expression accepts the same boundary"
	)
	var before_plaque: Dictionary = with_plaque.to_data()
	_check(
		_valid(with_plaque, pieces, boards),
		"actual current layout14 validation accepts plaque reserve"
	)
	var mounted: Dictionary = StadiumMountedScoreboardLayout.upgrade(
		_layout(), with_plaque, pieces, ACCESS, "mogul", boards
	)
	_check(
		(
			not mounted.is_empty()
			and (
				StadiumMountedScoreboardLayout
				. validate(mounted, with_plaque, pieces, ACCESS, "mogul", boards)
				. get("ok", false)
			)
		),
		"actual layout15 upgrade and validation retain the same capacity contract"
	)
	var cold: StadiumStock = StadiumStock.from_data(
		JSON.parse_string(JSON.stringify(before_plaque))
	)
	_check(
		cold != null and cold.capacity_count() == 4095 and _valid(cold, pieces, boards),
		"JSON cold stock5 preserves capacity and complete-layout acceptance"
	)
	_check(
		ClubCareer.same(before_plaque, with_plaque.to_data()),
		"validation leaves plaque inventory unchanged"
	)
	quote = with_plaque.quote("ST-001", 1, PROGRESS, "ordinary-overflow")
	if _check(quote.get("ok", false), "one extra ordinary copy remains independently valid stock"):
		var overflow: StadiumStock = StadiumStock.from_data(quote.state)
		_check(
			overflow != null and overflow.capacity_count() == 4096,
			"additional ordinary copy still consumes ordinary capacity"
		)
		_check(
			overflow != null and not _valid(overflow, pieces, boards),
			"existing board plus extra ordinary copy still rejects combined overflow"
		)
	quote = pieces.quote("ST-024-L", 1, "capacity-piece", PROGRESS, with_plaque.capacity_count())
	if _check(quote.get("ok", false), "one wall piece is independently valid at stock boundary"):
		var extra_piece: StadiumWallPieceOwnership = StadiumWallPieceOwnership.from_data(
			quote.state, with_plaque.capacity_count()
		)
		_check(
			extra_piece != null and not _valid(with_plaque, extra_piece, boards),
			"wall-piece count is not exempted by the plaque change"
		)
	_tamper(with_plaque, pieces, boards)


func _tamper(
	stock: StadiumStock, pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership
) -> void:
	var key: String = StadiumPlaqueRewards.key("player.alex_finch")
	for mutation: String in ["source", "paid", "item", "threshold", "identity", "legacy-version"]:
		var bad: Dictionary = stock.to_data()
		match mutation:
			"source":
				bad.copies[key].source = "purchase-v1"
			"paid":
				bad.copies[key].paid = 1
			"item":
				bad.copies[key].item = "ST-001"
			"threshold":
				bad.copies[key].earned.stats.hits = 39
			"identity":
				bad.copies[key].earned.player_id = "player.ari_banks"
			"legacy-version":
				bad.version = 4
		_check(StadiumStock.from_data(bad) == null, "tampered stock is rejected: " + mutation)
	var forged: StadiumStock = StadiumStock.from_data(stock.to_data())
	if not _check(forged != null, "source-label forgery starts from valid stock"):
		return
	forged.copies["purchase:mounted-capacity:0"].source = StadiumPlaqueRewards.SOURCE
	_check(
		forged.capacity_count() == stock.capacity_count() - 1,
		"forgery would reduce the raw helper count, making the negative control discriminating"
	)
	_check(
		StadiumStock.from_data(forged.to_data()) == null and not _valid(forged, pieces, boards),
		"source-only relabel cannot evade full typed-stock validation or gain capacity"
	)

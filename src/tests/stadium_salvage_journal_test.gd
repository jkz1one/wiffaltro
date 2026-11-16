extends "res://src/tests/stadium_net_ui_test.gd"
## Synthetic funding exercises the real journal and public atomic save route, not played games.

const SALVAGE_SEED: int = 175
var _salvage_checks: int = 0


func _check(ok: bool, message: String) -> void:
	_salvage_checks += 1
	if not ok:
		print("SALVAGE_JOURNAL_FAILURE " + message)
	super._check(ok, message)


func _ready() -> void:
	_origins()
	_clearance()
	_malformed()
	_ordinary_purchase()
	if _failures == 0:
		await _public_save()
	print(
		(
			"SALVAGE_JOURNAL_RESULT "
			+ JSON.stringify(
				{
					"checks": _salvage_checks,
					"failures": _failures,
					"synthetic_funding": true,
					"executed_games": 0
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _command(ledger: ClubAssetLedger, id: String = "salvage-test-clear") -> Dictionary:
	return {
		"id": id,
		"rev": ledger.revision(),
		"op": "stadium_salvage_clear",
		"copy": StadiumStock.SALVAGE_COPY,
		"price_version": 1,
		"through": 1
	}


func _origins() -> void:
	_check(
		(
			StadiumStock.grant_signature()
			== "ac1d1db9723a4fd6f70aa17db3f50e482a84093d42f10e0aba87c54e3cf442b6"
		),
		"frozen three-starter grant signature is unchanged"
	)
	var old: ClubAssetLedger = ClubAssetLedger.new(SALVAGE_SEED, [1000])
	var original: Dictionary = old.to_data()
	_check(
		(
			old.construction().copies.size() == 3
			and old.view().get("salvage_origin", {}).is_empty()
			and not original.has("salvage_origin")
		),
		"ordinary constructor has no surprise salvage origin or car"
	)
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(original)), SALVAGE_SEED, [1000]
	)
	_check(
		(
			restored != null
			and ClubCareer.same(restored.to_data(), original)
			and restored.construction().copies.size() == 3
		),
		"old journal cold round-trip stays exactly unchanged"
	)
	_check(
		not old.commit(_command(old)).ok and ClubCareer.same(old.to_data(), original),
		"old club cannot be charged or granted a starter salvage car by clearance"
	)
	var fresh: ClubAssetLedger = ClubAssetLedger.new_club(SALVAGE_SEED, [1000])
	var stock: StadiumStock = fresh.construction()
	_check(
		(
			stock != null
			and stock.copies.size() == 4
			and stock.blueprints.size() == 3
			and not stock.blueprints.has("ST-005")
			and stock.to_data().version == 3
		),
		"fresh club receives one separate salvage copy without its blueprint"
	)
	_check(
		ClubCareer.same(
			stock.copies[StadiumStock.SALVAGE_COPY],
			{"item": "ST-005", "paid": 0, "source": "starter-salvage-v1"}
		),
		"origin copy has exact immutable item, key and grant source"
	)
	_check(
		(
			fresh.to_data().version == 48
			and fresh.revision() == 0
			and fresh.balance() == 1000
			and ClubCareer.same(
				fresh.to_data().salvage_origin, ClubAssetLedger.salvage_origin_record()
			)
		),
		"fresh origin is independently versioned, not a purchase or extra starter grant"
	)
	_check(
		(
			fresh.view().stadium_active.version == 40
			and ClubAssetLedger._fixed_salvage_present(fresh.view().stadium_active)
			and ClubCareer.same(fresh.view().stadium_draft, fresh.view().stadium_active)
		),
		"new club initializes both exact active and draft fixed car layouts"
	)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(fresh.to_data())), SALVAGE_SEED, [1000]
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), fresh.to_data())
			and ClubCareer.same(cold.construction().to_data(), stock.to_data())
		),
		"cold load replays origin exactly once without blueprint or second copy"
	)
	_check(
		fresh.prefix(0) != null and ClubCareer.same(fresh.prefix(0).to_data(), fresh.to_data()),
		"zero-event prefix retains explicit origin rather than migrating to old semantics"
	)
	var award: Dictionary = {
		"version": 1,
		"season_id": 1,
		"league_id": "standard",
		"difficulty_id": "standard.d0",
		"season_number": 1,
		"era": StadiumClubIdentity.current()
	}
	var reward: Dictionary = stock.pennant_quote(award)
	var both: StadiumStock = StadiumStock.from_data(reward.state) if reward.ok else null
	_check(
		(
			both != null
			and both.earned_count() == 1
			and both.copies.has(StadiumStock.SALVAGE_COPY)
			and both.to_data().version == 3
		),
		"reward and salvage sources coexist under stock3"
	)
	var old_reward: Dictionary = StadiumStock.new_club().pennant_quote(award)
	_check(
		(
			old_reward.ok
			and old_reward.state.version == 2
			and StadiumStock.from_data(old_reward.state) != null
		),
		"old reward-only stock2 grammar stays valid"
	)


func _clearance() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(SALVAGE_SEED, [1000])
	var stock: Dictionary = ledger.construction().to_data()
	var before: Dictionary = ledger.to_data()
	var removed: Dictionary = ledger.view().stadium_draft
	removed.salvage_cars = []
	var escaped: Dictionary = ledger.commit(
		{"id": "salvage-bypass", "rev": 0, "op": "stadium_draft", "layout": removed}
	)
	_check(
		not escaped.ok and ClubCareer.same(before, ledger.to_data()),
		"generic draft cannot remove uncleared car free of charge"
	)
	var downgraded: Dictionary = StadiumSalvageCarItems.base(ledger.view().stadium_draft)
	_check(
		(
			not (
				ledger
				. commit(
					{
						"id": "salvage-downgrade",
						"rev": 0,
						"op": "stadium_draft",
						"layout": downgraded
					}
				)
				. ok
			)
			and ClubCareer.same(before, ledger.to_data())
		),
		"generic layout downgrade cannot evade the fixed starter car"
	)
	var poor: ClubAssetLedger = ClubAssetLedger.new_club(SALVAGE_SEED, [189])
	var poor_before: Dictionary = poor.to_data()
	_check(
		not poor.commit(_command(poor)).ok and ClubCareer.same(poor_before, poor.to_data()),
		"insufficient funds preserve active, draft, origin, copy and journal"
	)
	var command: Dictionary = _command(ledger)
	var quote: Dictionary = ledger.preview(command)
	_check(
		(
			quote.ok
			and quote.price == 190
			and quote.balance_after == 810
			and ClubCareer.same(before, ledger.to_data())
		),
		"190 CB quote is exact and read-only"
	)
	var result: Dictionary = ledger.commit(command)
	_check(
		(
			result.ok
			and not result.replayed
			and ledger.balance() == 810
			and ledger.revision() == 1
			and ledger.view().salvage_cleared
		),
		"clearance charges precisely 190 once in the shared journal"
	)
	_check(
		(
			ledger.view().stadium_active.salvage_cars.is_empty()
			and ledger.view().stadium_draft.salvage_cars.is_empty()
			and ClubCareer.same(ledger.construction().to_data(), stock)
		),
		"same atomic clearance stores exact permanent copy from both layouts without inventory mutation"
	)
	var cleared: Dictionary = ledger.to_data()
	_check(
		(
			ledger.commit(command).get("replayed", false)
			and ClubCareer.same(cleared, ledger.to_data())
		),
		"exact command retry is idempotent"
	)
	_check(
		(
			ledger.commit(_command(ledger, "salvage-test-again")).get("replayed", false)
			and ClubCareer.same(cleared, ledger.to_data())
		),
		"new clearance request cannot charge an already-cleared origin"
	)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(cleared)), SALVAGE_SEED, [1000]
	)
	_check(
		(
			cold != null
			and cold.balance() == 810
			and cold.view().salvage_cleared
			and cold.commit(command).get("replayed", false)
			and ClubCareer.same(cold.construction().to_data(), stock)
		),
		"cold clearance retry preserves payment and permanent copy"
	)
	var prefix: ClubAssetLedger = ledger.prefix(0)
	_check(
		(
			prefix != null
			and prefix.balance() == 1000
			and not prefix.view().salvage_cleared
			and ClubAssetLedger._fixed_salvage_present(prefix.view().stadium_active)
		),
		"prefix before clearance restores original car and unspent balance without losing origin"
	)
	var placed: Dictionary = StadiumSalvageCarItems.place(
		ledger.view().stadium_draft,
		ledger.construction(),
		StadiumStock.SALVAGE_COPY,
		"CAR-START",
		ledger.surface_owned()
	)
	var drafted: Dictionary = ledger.commit(
		{
			"id": "salvage-reuse-draft",
			"rev": ledger.revision(),
			"op": "stadium_draft",
			"layout": placed
		}
	)
	_check(
		drafted.ok and ledger.balance() == 810,
		"cleared car can be freely placed again using the same copy"
	)
	var applied: Dictionary = ledger.commit(
		{
			"id": "salvage-reuse-apply",
			"rev": ledger.revision(),
			"op": "stadium_apply",
			"layout": placed,
			"geometry": StadiumOwnedLayout.geometry("backyard", placed)
		}
	)
	_check(
		(
			applied.ok
			and ledger.balance() == 810
			and ledger.view().stadium_active.salvage_cars.size() == 1
		),
		"reusing salvaged car applies free through normal draft and Apply"
	)
	_check(ledger.fork() != null, "mixed origin clearance and layout40 events cold-replay")


func _malformed() -> void:
	var original: Dictionary = ClubAssetLedger.new_club(SALVAGE_SEED, [1000]).to_data()
	for key: String in ["version", "source", "copy", "item", "site"]:
		var broken: Dictionary = original.duplicate(true)
		broken.salvage_origin[key] = "invalid"
		_check(
			ClubAssetLedger.from_data(broken, SALVAGE_SEED, [1000]) == null,
			"malformed origin field fails closed: " + key
		)
	var boolean_origin: Dictionary = original.duplicate(true)
	boolean_origin.salvage_origin.version = true
	_check(
		ClubAssetLedger.from_data(boolean_origin, SALVAGE_SEED, [1000]) == null,
		"boolean origin version cannot masquerade as integer1"
	)
	var missing: Dictionary = original.duplicate(true)
	missing.erase("salvage_origin")
	_check(
		ClubAssetLedger.from_data(missing, SALVAGE_SEED, [1000]) == null,
		"ledger48 requires explicit origin record"
	)
	var injected: Dictionary = ClubAssetLedger.new(SALVAGE_SEED, [1000]).to_data()
	injected["salvage_origin"] = ClubAssetLedger.salvage_origin_record()
	_check(
		ClubAssetLedger.from_data(injected, SALVAGE_SEED, [1000]) == null,
		"old ledger header rejects silently injected origin"
	)
	for change: String in ["duplicate", "wrong_item", "charged", "downgrade"]:
		var data: Dictionary = (
			ClubAssetLedger.new_club(SALVAGE_SEED, [1000]).construction().to_data()
		)
		if change == "duplicate":
			data.copies["starter-salvage-v1:duplicate"] = (
				data.copies[StadiumStock.SALVAGE_COPY].duplicate(true)
			)
		elif change == "wrong_item":
			data.copies[StadiumStock.SALVAGE_COPY].item = "ST-006"
		elif change == "charged":
			data.copies[StadiumStock.SALVAGE_COPY].paid = 190
		else:
			data.version = 1
		_check(
			StadiumStock.from_data(data) == null, "malformed salvage stock fails closed: " + change
		)
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(SALVAGE_SEED, [1000])
	var bad: Dictionary = _command(ledger)
	bad.price_version = 31
	_check(
		not ledger.commit(bad).ok and ledger.revision() == 0,
		"purchase price version cannot masquerade as clearance"
	)
	bad = _command(ledger)
	bad.copy = "starter-v1:ST-005"
	_check(
		not ledger.commit(bad).ok and ledger.revision() == 0,
		"clearance cannot target a different or fabricated copy"
	)
	ledger.commit(_command(ledger))
	var duplicate: Dictionary = ledger.to_data()
	var extra: Dictionary = duplicate.events[0].duplicate(true)
	extra.id = "salvage-duplicate-receipt"
	extra.rev = 1
	duplicate.events.append(extra)
	_check(
		ClubAssetLedger.from_data(duplicate, SALVAGE_SEED, [1000]) == null,
		"malformed journal cannot persist a second clearance event"
	)


func _ordinary_purchase() -> void:
	var catalog: Dictionary = StadiumCatalog.item("ST-005")
	_check(
		(
			catalog.blueprint_price == 620
			and catalog.copy_price == 190
			and ClubCareer.same(catalog.requires, {"seasons": 7, "wins": 20})
		),
		"ordinary Working ST005 pricing and seven-season twenty-win unlock remain unchanged"
	)
	for metrics: Dictionary in [{"seasons": 6, "wins": 20}, {"seasons": 7, "wins": 19}]:
		_check(
			not (
				StadiumPurchases
				. quote(StadiumStock.new_club(), "ST-005", 1, "salvage-locked-buy", 31, metrics)
				. ok
			),
			"ordinary purchase retains both achievement gates"
		)
	var stock: StadiumStock = ClubAssetLedger.new_club(SALVAGE_SEED).construction()
	var quote: Dictionary = StadiumPurchases.quote(
		stock, "ST-005", 1, "salvage-ordinary-buy", 31, {"seasons": 7, "wins": 20}
	)
	_check(
		quote.ok and quote.cost == 810 and quote.blueprint_cost == 620 and quote.copy_cost == 190,
		"free salvage copy never silently grants ordinary blueprint discount"
	)
	var bought: StadiumStock = StadiumStock.from_data(quote.state) if quote.ok else null
	_check(
		(
			bought != null
			and bought.copies.has(StadiumStock.SALVAGE_COPY)
			and bought.copies.size() == 5
			and bought.blueprints.has("ST-005")
		),
		"ordinary purchased copy coexists with permanent salvaged identity"
	)

	var credits: Array = []
	var progress: Array = []
	for index in range(7):
		credits.append(1000)
		progress.append({"seasons": 1, "wins": 3})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(SALVAGE_SEED, credits, progress)
	var prior: Dictionary = ledger.to_data()
	var request: Dictionary = {
		"id": "salvage-ordinary-ledger",
		"rev": 0,
		"op": "stadium_buy",
		"item": "ST-005",
		"quantity": 1,
		"price_version": 31,
		"through": 7,
		"progress_through": 7
	}
	var paid: Dictionary = ledger.commit(request)
	_check(
		(
			paid.ok
			and ledger.balance() == 6190
			and ledger.to_data().version == 48
			and ledger.to_data().salvage_origin.is_empty()
			and not ledger.construction().copies.has(StadiumStock.SALVAGE_COPY)
		),
		"ordinary legacy club uses purchase31 and ledger48 without surprise origin grant"
	)
	_check(
		(
			ledger.fork() != null
			and ledger.prefix(0) != null
			and ClubCareer.same(ledger.prefix(0).to_data(), prior)
		),
		"purchase-only ledger48 cold loads and its prefix retains original legacy header"
	)
	var second: Dictionary = request.duplicate(true)
	second.id = "salvage-ordinary-copy-only"
	second.rev = 1
	_check(
		ledger.commit(second).ok and ledger.balance() == 6000,
		"subsequent ordinary car purchase costs only 190 after blueprint ownership"
	)


func _public_save() -> void:
	SeasonSave.path = "user://salvage-journal-%d.json" % OS.get_process_id()
	_cleanup()
	var fresh_app: SeasonApp = SeasonApp.new()
	add_child(fresh_app)
	await _frames()
	fresh_app.begin_season(SALVAGE_SEED, true, true, true, true, true)
	var pristine: SeasonState = fresh_app.season
	_check(
		(
			pristine != null
			and pristine.career != null
			and pristine.phase == SeasonState.Phase.DRAFT
			and pristine.picks.is_empty()
			and pristine.home_property.get("layout", {}).get("version") == 40
		),
		"pristine real public new-club entry installs the origin car before drafting"
	)
	if pristine != null:
		var origin: ClubAssetLedger = ClubPlayers.assets(pristine.career)
		_check(
			(
				origin != null
				and origin.construction().copies.size() == 4
				and origin.balance() == 0
				and not origin.construction().blueprints.has("ST-005")
			),
			"real new ClubCareer receives one salvage copy, no blueprint and no invented income"
		)
		StadiumEditorUI.show(fresh_app.menu)
		await _frames()
		var clear_button: Button = _salvage_clear_button(fresh_app)
		var locked_choice: OptionButton = _paid_choice(fresh_app, StadiumStock.SALVAGE_COPY)
		_check(
			clear_button != null and clear_button.disabled,
			"pristine Workshop shows disabled 190-CB clearance control with insufficient funds"
		)
		_check(
			locked_choice != null and locked_choice.disabled and locked_choice.selected == 1,
			"uncleared original copy is visibly installed and cannot use the free storage dropdown"
		)
		var untouched: Dictionary = SeasonSave.snapshot(pristine)
		_check(
			(
				not ClubConstruction.clear_salvage(pristine, origin.revision()).ok
				and ClubCareer.same(untouched, SeasonSave.snapshot(pristine))
			),
			"unfunded pristine public clearance refuses without changing saved club"
		)
	fresh_app.queue_free()
	await _frames()
	_cleanup()
	if _failures != 0:
		return
	var completed: SeasonState = _new(SALVAGE_SEED + 2)
	_finish(completed, "champion")
	_check(
		SeasonSave.save(completed),
		"synthetic scheduled completed season supplies real journal income"
	)
	completed.career._assets = (
		ClubAssetLedger
		. new_club(
			int(completed.career.runs[0].seed),
			ClubPlayers.income(completed.career),
			StadiumCareerProgress.capture(completed.career),
			StadiumPennantRewards.awards(completed.career)
		)
		. to_data()
	)
	_check(
		StadiumPennantRewards.deliver(completed.career),
		"synthetic origin reset explicitly restores prior earned pennant identities"
	)
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = completed
	app.begin_season(SALVAGE_SEED + 1, true)
	var season: SeasonState = app.season
	_check(
		(
			season != completed
			and season != null
			and season.phase == SeasonState.Phase.DRAFT
			and not season.home_property.is_empty()
			and SeasonSave.save(season)
		),
		(
			(
				"synthetic funded origin enters real public DRAFT with matching player and home "
				+ "metadata; notice="
			)
			+ app.notice
			+ "; save="
			+ SeasonSave.last_error
		)
	)
	if _failures != 0:
		app.queue_free()
		await _frames()
		_cleanup()
		return
	StadiumEditorUI.show(app.menu)
	await _frames()
	var funded_clear: Button = _salvage_clear_button(app)
	_check(
		funded_clear != null and not funded_clear.disabled,
		"funded DRAFT Workshop exposes enabled exact-price clearance control"
	)
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	var before: Dictionary = SeasonSave.snapshot(season)
	var balance: int = ClubPlayers.assets(season.career).balance()
	var revision: int = ClubPlayers.assets(season.career).revision()
	var previous_home: Dictionary = season.home_property.duplicate(true)
	SeasonSave.path = path + "/missing/profile.json"
	var failed: Dictionary = ClubConstruction.clear_salvage(season, revision)
	SeasonSave.path = path
	_check(
		(
			not failed.ok
			and ClubCareer.same(before, SeasonSave.snapshot(season))
			and bytes == FileAccess.get_file_as_string(path)
		),
		"failed public clearance save rolls back funds, journal, layouts, stock and saved bytes"
	)
	var result: Dictionary = ClubConstruction.clear_salvage(season, revision)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(
		(
			result.ok
			and not result.replayed
			and ledger.balance() == balance - 190
			and ledger.view().stadium_active.salvage_cars.is_empty()
			and ledger.view().stadium_draft.salvage_cars.is_empty()
		),
		"public DRAFT clearance atomically saves payment and stores the same permanent copy"
	)
	_check(
		(
			not ClubCareer.same(previous_home, season.home_property)
			and season.home_property.layout.salvage_cars.is_empty()
			and StadiumLayoutSnapshot.matches(season.home_property, ledger)
		),
		"DRAFT clearance recaptures exact car-free bound home snapshot before publishing"
	)
	StadiumEditorUI.show(app.menu)
	await _frames()
	var stored_choice: OptionButton = _paid_choice(app, StadiumStock.SALVAGE_COPY)
	_check(
		(
			stored_choice != null
			and not stored_choice.disabled
			and stored_choice.selected == 0
			and _salvage_clear_button(app) == null
		),
		"cleared Workshop shows same copy stored and freely selectable with no second clearance charge"
	)
	var cold: SeasonState = SeasonSave.restore()
	_check(
		(
			cold != null
			and ClubPlayers.assets(cold.career).view().salvage_cleared
			and cold.home_property.layout.salvage_cars.is_empty()
			and ClubPlayers.assets(cold.career).construction().copies.has(StadiumStock.SALVAGE_COPY)
		),
		"public cold save restores cleared field and exact owned salvage identity"
	)
	_check(
		(
			ClubConstruction.clear_salvage(season, revision).get("replayed", false)
			and ClubPlayers.assets(season.career).balance() == balance - 190
		),
		"public exact retry does not charge twice"
	)
	app.queue_free()
	await _frames()
	_cleanup()


func _salvage_clear_button(app: SeasonApp) -> Button:
	for button: Button in app.menu._body.find_children("*", "Button", true, false):
		if button.get_meta("stadium_salvage_clear", false):
			return button
	return null

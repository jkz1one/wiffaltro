extends Node3D
## Synthetic paid progression exercises existing production routes. No earned-season claim.
const SEED: int = 184
const FIRST: String = "purchase:waterfalls:0"
const SPARE: String = "purchase:waterfalls:1"
var checks: int = 0
var failures: Array[String] = []
var credits: Array = []
var progress: Array = []
var authority: Dictionary = {}
var _paid: ClubAssetLedger
var _layout: Dictionary
var _snapshot: Dictionary


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("OWNED_WATERFALL: " + label)


func _ready() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5})
	_gates()
	_case(false)
	_case(true)
	if _paid != null and not _snapshot.is_empty():
		_layout_controls()
		await _runtime()
	if "--waterfall-full-save" in OS.get_cmdline_user_args():
		_season_save()
	print(
		(
			"OWNED_WATERFALL_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_funding": true,
					"synthetic_progression": true,
					"physical_games": 0,
					"live_field_mechanics": false,
					"night_qualified": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _gates() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	for values: Array in [[23, 90, false], [24, 89, false], [24, 90, true]]:
		var quote: Dictionary = StadiumPurchases.quote(
			stock, "ST-046", 1, "waterfall-gate", 32, {"seasons": values[0], "wins": values[1]}
		)
		check(quote.ok == values[2], "exact S24/W90 gate " + str(values))
		if quote.ok:
			check(
				quote.blueprint_cost == 950 and quote.copy_cost == 260,
				"unchanged Working950/260 price"
			)
	check(
		not (
			StadiumPurchases
			. quote(stock, "ST-046", 1, "old-price", 26, {"seasons": 99, "wins": 999})
			. ok
		),
		"old apple price family cannot buy waterfall"
	)
	check(
		StadiumWaterfallItems.sites() == ["LANDMARK-A"] and StadiumWaterfallItems.yaws() == [0],
		"only archived decorative site/yaw"
	)
	check(
		(
			StadiumWaterfallItems.row(FIRST, "ST-046", "LEFT-FIELD").is_empty()
			and StadiumWaterfallItems.row(FIRST, "ST-046", "LANDMARK-A", 90).is_empty()
		),
		"no invented live site or rotation"
	)


func _case(with_salvage: bool) -> void:
	var label: String = "salvage" if with_salvage else "legacy"
	var ledger: ClubAssetLedger = (
		ClubAssetLedger.new_club(SEED, credits, progress)
		if with_salvage
		else ClubAssetLedger.new(SEED, credits, progress)
	)
	var initial: Dictionary = ledger.to_data()
	if with_salvage:
		check(
			(
				ledger
				. commit(
					{
						"id": "waterfall-clear",
						"rev": ledger.revision(),
						"op": "stadium_salvage_clear",
						"copy": StadiumStock.SALVAGE_COPY,
						"price_version": 1,
						"through": credits.size()
					}
				)
				. ok
			),
			label + " explicit paid original-car clearance"
		)
	for tier: String in ["expanded", "club", "mogul"]:
		var land: Dictionary = ledger.commit(
			{
				"id": "waterfall-land-" + tier,
				"rev": ledger.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": credits.size(),
				"progress_through": progress.size(),
				"price_version": StadiumLand.VERSION
			}
		)
		check(land.ok, label + " paid land " + tier + ": " + land.error)
		if not land.ok:
			return
	var before: Dictionary = ledger.to_data()
	var before_revision: int = ledger.revision()
	var cash: int = ledger.balance()
	var command: Dictionary = {
		"id": "waterfalls",
		"rev": ledger.revision(),
		"op": "stadium_buy",
		"item": "ST-046",
		"quantity": 2,
		"price_version": 32,
		"through": credits.size(),
		"progress_through": progress.size()
	}
	var bought: Dictionary = ledger.commit(command)
	check(
		bought.ok and ledger.balance() == cash - 1470,
		label + " paid one blueprint and two independent copies: " + bought.error
	)
	if not bought.ok:
		return
	check(
		(
			ledger.construction().copies.has(FIRST)
			and ledger.construction().copies.has(SPARE)
			and ledger.to_data().version == 51
		),
		label + " exact stock and additive journal51"
	)
	check(
		ledger.commit(command).get("replayed", false) and ledger.balance() == cash - 1470,
		label + " purchase retry never duplicates/charges"
	)
	check(
		ledger.view().stadium_active.get("waterfalls", []).is_empty(),
		label + " purchase does not auto-place"
	)
	check(
		ClubCareer.same(ledger.prefix(before_revision).to_data(), before),
		label + " exact old pre-purchase prefix"
	)
	var purchased: Dictionary = ledger.to_data()
	for key: String in ["waterfall_catalog", "waterfall_layout_catalog"]:
		var bad: Dictionary = purchased.duplicate(true)
		bad.erase(key)
		check(_load(bad) == null, label + " missing " + key + " rejected")
		bad = purchased.duplicate(true)
		bad[key] = "forged"
		check(_load(bad) == null, label + " forged " + key + " rejected")
	var bad: Dictionary = purchased.duplicate(true)
	bad.version = 50
	bad.erase("waterfall_catalog")
	bad.erase("waterfall_layout_catalog")
	check(_load(bad) == null, label + " old journal cannot accept new purchase")
	var layout: Dictionary = StadiumWaterfallItems.place(
		ledger.view().stadium_draft,
		ledger.construction(),
		FIRST,
		"LANDMARK-A",
		0,
		ledger.surface_owned()
	)
	check(
		(
			layout.get("version") == 42
			and StadiumHomeLayout.validate(layout, ledger.construction(), "mogul").ok
		),
		label + " exact family42 layout"
	)
	if not _apply(ledger, layout, label + " installation"):
		return
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger, true)
	check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.valid(snapshot)
			and StadiumLayoutSnapshot.matches(snapshot, ledger)
		),
		label + " applied exact-prefix snapshot"
	)
	check(
		(
			StadiumLayoutSnapshot.valid(_json(snapshot))
			and StadiumLayoutSnapshot.key(snapshot) == StadiumLayoutSnapshot.key(_json(snapshot))
		),
		label + " cold frozen replay key stable"
	)
	_cold(ledger, label + " mounted")
	bad = snapshot.duplicate(true)
	bad.layout.waterfalls[0].copy = SPARE
	check(
		(
			StadiumLayoutSnapshot.valid(bad)
			and not StadiumLayoutSnapshot.matches(bad, ledger)
			and StadiumLayoutSnapshot.key(bad) != StadiumLayoutSnapshot.key(snapshot)
		),
		label + " structurally owned spare still fails exact-prefix replay binding"
	)
	var frozen: Dictionary = ledger.to_data()
	var active_revision: int = ledger.revision()
	var stored: Dictionary = StadiumWaterfallItems.store_copy(layout, FIRST)
	check(
		ClubCareer.same(StadiumWaterfallItems.store_copy(layout, SPARE), layout),
		label + " stored spare cannot clear active waterfall"
	)
	check(
		StadiumHomeLayout.preview(layout, stored, ledger.construction(), "mogul").displaced.has(
			FIRST
		),
		label + " preview names exact displaced paid copy"
	)
	if not _apply(ledger, stored, label + " Store"):
		return
	check(
		(
			ledger.view().stadium_active.waterfalls.is_empty()
			and ledger.construction().copies.has(FIRST)
		),
		label + " Store retains paid copy"
	)
	check(
		(
			StadiumLayoutSnapshot.matches(snapshot, ledger)
			and ClubCareer.same(ledger.prefix(active_revision).to_data(), frozen)
		),
		label + " Store never rewrites earlier fixture or journal prefix"
	)
	if not _apply(ledger, layout, label + " explicit re-place"):
		return
	check(
		ledger.balance() == cash - 1470 and ClubCareer.same(ledger.prefix(0).to_data(), initial),
		label + " free lifecycle and exact original grant"
	)
	_cold(ledger, label + " restored")
	if not with_salvage:
		_paid = ledger
		_layout = layout
		_snapshot = StadiumLayoutSnapshot.capture(ledger, true)


func _layout_controls() -> void:
	var stock: StadiumStock = _paid.construction()
	var empty: Dictionary = StadiumWaterfallItems.store_copy(_layout, FIRST)
	var checked: Dictionary = StadiumHomeLayout.validate(_layout, stock, "mogul")
	check(
		checked.live_units == 0 and not checked.night_qualified and checked.stored.has(SPARE),
		"no live budget/Night claim and distinct stored spare"
	)
	check(
		(
			StadiumWaterfallItems.bounds(checked.waterfalls_placements[0])
			== AABB(Vector3(30, 0, 39), Vector3(13, 4, 10))
		),
		"whole archive reservation bound, not tightened to mesh"
	)
	for tier: String in ["backyard", "expanded", "club"]:
		check(
			not StadiumHomeLayout.validate(_layout, stock, tier).ok,
			"full reservation refuses lower tier " + tier
		)
	for change: Dictionary in [
		{"copy": SPARE},
		{"copy": "foreign"},
		{"site": "ODDITY-PLAZA"},
		{"site": "LEFT-FIELD"},
		{"yaw": 0},
		{"role": "LIVE_RICOCHET"}
	]:
		var bad: Dictionary = _layout.duplicate(true)
		bad.waterfalls[0].merge(change, true)
		check(
			StadiumHomeLayout.validate(bad, stock, "mogul").ok == (change == {"copy": SPARE}),
			"exact-only layout shape " + str(change)
		)
	var duplicate: Dictionary = StadiumWaterfallItems.place(_layout, stock, SPARE, "LANDMARK-A")
	check(
		(
			not StadiumHomeLayout.validate(duplicate, stock, "mogul").ok
			and duplicate.waterfalls.size() == 2
		),
		"occupied-site refusal never displaces either owned copy"
	)
	var before: Dictionary = _paid.to_data()
	_refuse(
		_paid,
		{
			"id": "waterfall-conflict",
			"rev": _paid.revision(),
			"op": "stadium_draft",
			"layout": duplicate
		},
		"conflicting transaction atomic"
	)
	check(
		ClubCareer.same(before, _paid.to_data()), "conflict preserves prior saved active and draft"
	)
	for item: String in ["ST-047", "ST-048", "ST-049", "ST-050", "ST-038"]:
		var quote: Dictionary = stock.quote(
			item,
			1,
			{"seasons": 99, "wins": 999, "homers": 999, "strikeouts": 999},
			"conflict-" + item
		)
		check(quote.ok, "synthetic conflict stock " + item)
		if not quote.ok:
			continue
		stock = StadiumStock.from_data(quote.state)
		var copy: String = "purchase:conflict-" + item + ":0"
		var occupant: Dictionary = empty.duplicate(true)
		var composed: Dictionary = _layout.duplicate(true)
		if item == "ST-038":
			occupant.floodlight_profile = "CLUB4-LOW"
			occupant.floodlights = [{"copy": copy, "item": "ST-038", "site": "CLIGHT-OR"}]
			composed.floodlight_profile = "CLUB4-LOW"
			composed.floodlights = occupant.floodlights.duplicate(true)
		elif item == "ST-047":
			occupant = StadiumRisingAppleItems.place(empty, stock, copy, "LANDMARK-A")
			composed = StadiumRisingAppleItems.place(_layout, stock, copy, "LANDMARK-A")
		else:
			occupant = StadiumLandmarkItems.place(empty, stock, copy, "LANDMARK-A")
			composed = StadiumLandmarkItems.place(_layout, stock, copy, "LANDMARK-A")
		check(
			StadiumHomeLayout.validate(occupant, stock, "mogul").ok,
			"existing occupant alone valid " + item
		)
		check(
			(
				not StadiumHomeLayout.validate(composed, stock, "mogul").ok
				and not (
					StadiumHomeLayout
					. validate(
						StadiumWaterfallItems.place(occupant, stock, FIRST, "LANDMARK-A"),
						stock,
						"mogul"
					)
					. ok
				)
			),
			"symmetric conflict without silent storage " + item
		)
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	for copy: String in [FIRST, SPARE]:
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumWaterfallItemsUI.card(menu, panel, _layout, copy, _paid.revision(), false)
		var choices: Array[Node] = panel.find_children("*", "OptionButton", true, false)
		check(
			(
				choices.size() == 1
				and choices[0].selected == (1 if copy == FIRST else 0)
				and choices[0].disabled
				and choices[0].item_count == 3
			),
			"Workshop exact placed/stored card " + copy
		)
	StadiumWaterfallItemsUI.purchases(menu, _paid, _layout, _paid.revision(), false)
	var text: String = ""
	for node: Node in menu._body.find_children("*", "Label", true, false):
		text += node.text + "\n"
	check(
		(
			text.contains("950")
			and text.contains("260")
			and text.contains("24 completed seasons")
			and text.contains("90 regular-season wins")
			and text.contains("no colliders")
			and text.contains("2 owned copies")
		),
		"Workshop honest price/gate/ownership/no-live disclosure"
	)
	menu.free()
	app.free()


func _runtime() -> void:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	check(
		property.build("mogul", _layout, _paid.construction()),
		"ordinary full property builds frozen direct-mesh waterfall"
	)
	if property.objects.has(FIRST):
		var model: Node3D = property.objects[FIRST]
		check(
			(
				StadiumWaterfallModels.valid(model)
				and model.get_child_count() == 21
				and not model.has_node("Visual")
				and not model.has_node("Collision")
			),
			"factory hierarchy unchanged and collider-free"
		)
		check(
			property.props_intact() and property.route_obstacles().is_empty(),
			"whole exact model sealed, no defender detour"
		)
		var original: Transform3D = model.get_node("Pool").transform
		model.get_node("Pool").position.x += 0.01
		check(not property.props_intact(), "installed visual mutation fails closed")
		model.get_node("Pool").transform = original
		check(property.props_intact(), "exact restoration recovers static seal")
	property.free()
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = _snapshot.duplicate(true)
	lab._match_state.stadium.layout.waterfalls[0].copy = SPARE
	lab._stadium_ledger = _paid
	check(
		not StadiumPropertyRuntime.install_bound(lab) and not lab.has_meta("stadium_property"),
		"actual installer rejects structurally valid but unbound spare substitution"
	)
	lab._match_state.stadium = _snapshot.duplicate(true)
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	check(installed, "ordinary frozen paid snapshot installs through match runtime")
	if installed:
		var actual: StadiumPropertyGeometry = lab.get_meta("stadium_property")
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(
			actual.props_intact() and StadiumBoundaryRuntime.installed(lab, _snapshot),
			"installed paid property/boundary remain sealed"
		)
		check(
			PhysicalStadiumContacts.valid([], [], _snapshot) and lab._play_records.is_empty(),
			"no fabricated scoring contacts or game evidence"
		)
		check(
			actual.objects.has(FIRST) and actual.route_obstacles().is_empty(),
			"actual match contains exact waterfall without live detour"
		)
		var tracking: BallTrackingVisibility = lab._camera_director.tracking_visibility
		var collected: bool = true
		for mesh: MeshInstance3D in actual.objects[FIRST].get_children():
			collected = (
				collected and tracking._obstacles.has(mesh.global_transform * mesh.get_aabb())
			)
		check(collected, "ordinary dynamic camera collects all21 direct waterfall meshes")
		for role: String in ["LIVE_RICOCHET", "DECORATIVE_AFTER_TERMINAL"]:
			var event: Dictionary = {
				"source": "item",
				"id": FIRST,
				"surface": "Pool",
				"role": role,
				"position": [36.5, 0.33, 43.05],
				"time": 0.1,
				"kind": "contact"
			}
			check(
				not PhysicalStadiumContacts.valid(
					[{"play": 0, "reason": "", "events": [event]}],
					[
						{
							"result": "double",
							"contact": ContactResult.Outcome.CONTACT,
							"exit_speed": 12.0
						}
					],
					_snapshot
				),
				"report rejects fabricated waterfall scoring contact " + role
			)
		await _native_views(lab, actual)
		check(actual.props_intact(), "views preserve exact paid model seal")
	lab.queue_free()
	await get_tree().process_frame


func _apply(ledger: ClubAssetLedger, layout: Dictionary, label: String) -> bool:
	var balance: int = ledger.balance()
	var stock_before: Dictionary = ledger.construction().to_data()
	var active_before: Dictionary = ledger.view().stadium_active
	var before: Dictionary = ledger.to_data()
	var draft: Dictionary = {
		"id": "waterfall-draft:%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_draft",
		"layout": layout
	}
	var preview: Dictionary = ledger.preview(draft)
	check(
		preview.ok and ClubCareer.same(ledger.to_data(), before),
		label + " draft preview is read-only"
	)
	var saved: Dictionary = ledger.commit(draft)
	check(
		(
			saved.ok
			and ClubCareer.same(ledger.view().stadium_active, active_before)
			and ClubCareer.same(ledger.view().stadium_draft, layout)
		),
		label + " draft saves without premature activation: " + saved.error
	)
	if not saved.ok:
		return false
	var apply: Dictionary = {
		"id": "waterfall-apply:%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_apply",
		"layout": layout,
		"geometry": StadiumWaterfallItems.geometry(ledger.view().land, layout)
	}
	var bad: Dictionary = apply.duplicate(true)
	bad.id += ":wrong-geometry"
	bad.geometry = "incorrect-family-signature"
	_refuse(ledger, bad, label + " wrong geometry refuses atomically")
	var result: Dictionary = ledger.commit(apply)
	check(
		(
			result.ok
			and ClubCareer.same(ledger.view().stadium_active, layout)
			and ledger.balance() == balance
			and ClubCareer.same(ledger.construction().to_data(), stock_before)
		),
		(
			label
			+ " Apply activates only exact saved draft without spending/ownership change: "
			+ result.error
		)
	)
	if not result.ok:
		return false
	var complete: Dictionary = ledger.to_data()
	check(
		(
			ledger.commit(draft).get("replayed", false)
			and ledger.commit(apply).get("replayed", false)
			and ClubCareer.same(ledger.to_data(), complete)
		),
		label + " exact draft/Apply retries are idempotent"
	)
	return true


func _refuse(ledger: ClubAssetLedger, command: Dictionary, label: String) -> void:
	var before: Dictionary = ledger.to_data()
	var generation: int = ledger.mutation_generation()
	var denied: Dictionary = ledger.commit(command)
	check(
		(
			not denied.ok
			and ClubCareer.same(before, ledger.to_data())
			and generation == ledger.mutation_generation()
		),
		label
	)


func _cold(ledger: ClubAssetLedger, label: String) -> void:
	var cold: ClubAssetLedger = _load(_json(ledger.to_data()))
	check(
		cold != null and ClubCareer.same(cold.to_data(), ledger.to_data()),
		label + " full cold journal replay retains canonical header/events"
	)
	if cold != null:
		check(
			(
				ClubCareer.same(cold.view(), ledger.view())
				and ClubCareer.same(cold.construction().to_data(), ledger.construction().to_data())
			),
			label + " full cold replay retains active/draft/wallet/inventory"
		)


func _load(value: Variant) -> ClubAssetLedger:
	return ClubAssetLedger.from_data(value, SEED, credits, progress, authority)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _season_save() -> void:
	# Reuse the existing deterministic score fixture, not physical games or authentic earnings.
	var career: ClubCareer = ClubCareer.new()
	var season: SeasonState
	var complete: bool = true
	for index in range(41):
		season = StadiumPennantRewardRebuildChecks._new(career)
		if (
			season == null
			or not StadiumPennantRewardRebuildChecks._finish(season)
			or not career.sync(season)
		):
			complete = false
			break
		if index < 40 and not career.close(season):
			complete = false
			break
	check(
		complete,
		"forty-one authored score-only completed seasons supply real validated funding/progress shape"
	)
	if not complete:
		return
	season.career = ClubCareer.from_data(_json(career.to_data()))
	check(season.career != null, "full synthetic career cold-validates before purchases")
	check(
		season.career != null and season.career.matches(season),
		"full-precision cold career retains exact season draw proof before purchases"
	)
	if season.career == null or not season.career.matches(season):
		return
	for tier: String in ["expanded", "club", "mogul"]:
		var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
		var result: Dictionary = ClubPlayers.command(
			season.career,
			{
				"id": "waterfall-save-land-" + tier,
				"rev": ledger.revision(),
				"op": "stadium_land",
				"tier": tier,
				"price_version": 1,
				"through": ClubPlayers.income_through(season.career),
				"progress_through": StadiumCareerProgress.capture(season.career).size()
			}
		)
		check(result.ok, "full-career paid land " + tier + ": " + result.error)
		if not result.ok:
			return
	var original_path: String = SeasonSave.path
	SeasonSave.path = "user://waterfall-full-save.json"
	var saved: bool = SeasonSave.save(season)
	check(saved, "actual pre-purchase file saves: " + SeasonSave.last_error)
	if not saved:
		SeasonSave.path = original_path
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var quote: Dictionary = StadiumPurchases.quote(
		ledger.construction(),
		"ST-046",
		2,
		"full-save-preview",
		32,
		StadiumCareerProgress.metrics(
			StadiumCareerProgress.capture(season.career),
			StadiumCareerProgress.capture(season.career).size()
		)
	)
	check(
		quote.ok and ledger.balance() >= 1470,
		"validated post-land wallet can afford the1470 two-copy transaction"
	)
	if not quote.ok or ledger.balance() < 1470:
		SeasonSave.path = original_path
		return
	var before: Dictionary = season.career.to_data()
	var previous_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = "user://waterfall-missing-directory/blocked.json"
	var failed: Dictionary = ClubConstruction.buy_copy(season, "ST-046", ledger.revision(), 2)
	check(
		(
			not failed.ok
			and failed.error.begins_with("Could not save season.")
			and ClubCareer.same(season.career.to_data(), before)
		),
		"failed actual file write rolls back waterfall purchase/wallet/inventory"
	)
	SeasonSave.path = "user://waterfall-full-save.json"
	check(
		FileAccess.get_file_as_string(SeasonSave.path) == previous_bytes,
		"failed purchase leaves prior saved bytes unchanged"
	)
	var bought: Dictionary = ClubConstruction.buy_copy(season, "ST-046", ledger.revision(), 2)
	check(
		bought.ok, "public ordinary purchase dispatch pays950+2x260 and persists: " + bought.error
	)
	if bought.ok:
		ledger = ClubPlayers.assets(season.career)
		var copy: String = "purchase:stadium-buy:%d:0" % (ledger.revision() - 1)
		var layout: Dictionary = StadiumWaterfallItems.place(
			ledger.view().stadium_draft,
			ledger.construction(),
			copy,
			"LANDMARK-A",
			0,
			ledger.surface_owned()
		)
		var drafted: Dictionary = ClubConstruction.save_draft(season, layout, ledger.revision())
		check(drafted.ok, "public Workshop draft persists exact copy: " + drafted.error)
		if drafted.ok:
			var applied: Dictionary = ClubConstruction.apply_draft(
				season, layout, ClubPlayers.assets(season.career).revision()
			)
			check(
				applied.ok, "public Workshop Apply persists exact active layout: " + applied.error
			)
			var cold: SeasonState = SeasonSave._decode(_json(SeasonSave.snapshot(season)))
			check(
				(
					cold != null
					and ClubCareer.same(
						ClubPlayers.assets(cold.career).view(),
						ClubPlayers.assets(season.career).view()
					)
				),
				"full SeasonSave cold envelope retains wallet/draft/active/stock"
			)
	SeasonSave.path = original_path


func _native_views(lab: PitchBatLab, property: StadiumPropertyGeometry) -> void:
	var directory: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			directory = argument.trim_prefix("--ui-capture-dir=")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	var capture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd").new()
	add_child(capture)
	await capture.initialize()
	lab._status_label.hide()
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.fov = 50
	camera.make_current()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		check(await capture.resize(size), "native viewport handshake " + str(size))
		camera.position = Vector3(52, 28, -18)
		camera.look_at(Vector3(6, 0, 20))
		check(
			await capture.capture(directory, "owned-waterfall-property"),
			"native complete paid-property view " + str(size)
		)
		camera.position = Vector3(44, 7.5, 29)
		camera.look_at(property.objects[FIRST].global_position + Vector3(0, 1.5, 0))
		check(
			await capture.capture(directory, "owned-waterfall-focus"),
			"native exact paid-waterfall focus " + str(size)
		)
	camera.free()
	capture.free()

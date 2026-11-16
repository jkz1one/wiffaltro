extends Node3D
## Synthetic progression/funding, real ledger, exact-copy layout and cold file paths.
const SEED: int = 216
const FIRST: String = "purchase:live-waterfalls:0"
const SPARE: String = "purchase:live-waterfalls:1"
const KIT: String = "purchase:live-plaza:0"
var checks: int = 0
var failures: Array[String] = []
var credits: Array = []
var progress: Array = []
var authority: Dictionary = {}


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("OWNED_LIVE_WATERFALL: " + label)


func _ready() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5, "homers": 5})
	await _owned()
	if "--live-waterfall-full-save" in OS.get_cmdline_user_args():
		_season_save()
	print(
		(
			"OWNED_LIVE_WATERFALL_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_funding": true,
					"synthetic_progression": true,
					"night_qualified": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _owned() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(SEED, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		check(
			(
				ledger
				. commit(
					{
						"id": "live-land-" + tier,
						"rev": ledger.revision(),
						"op": "stadium_land",
						"tier": tier,
						"through": credits.size(),
						"progress_through": progress.size(),
						"price_version": 1
					}
				)
				. ok
			),
			"paid land " + tier
		)
	var cash: int = ledger.balance()
	var buy: Dictionary = {
		"id": "live-waterfalls",
		"rev": ledger.revision(),
		"op": "stadium_buy",
		"item": "ST-046",
		"quantity": 2,
		"price_version": 32,
		"through": credits.size(),
		"progress_through": progress.size()
	}
	check(
		ledger.commit(buy).ok and ledger.balance() == cash - 1470,
		"unchanged950+2x260 paid transaction"
	)
	check(
		ledger.commit(buy).get("replayed", false) and ledger.balance() == cash - 1470,
		"paid retry idempotent"
	)
	check(
		(
			ledger
			. commit(
				{
					"id": "live-plaza",
					"rev": ledger.revision(),
					"op": "stadium_buy",
					"item": "ST-112",
					"quantity": 1,
					"price_version": 34,
					"through": credits.size(),
					"progress_through": progress.size()
				}
			)
			. ok
		),
		"paid plaza infrastructure"
	)
	var old: Dictionary = ledger.to_data()
	var old_revision: int = ledger.revision()
	var stock: StadiumStock = ledger.construction()
	var layout: Dictionary = StadiumWaterfallLiveItems.place(
		ledger.view().stadium_draft, stock, FIRST, "WF-LIVE-LF", 0, ledger.surface_owned()
	)
	var checked: Dictionary = StadiumHomeLayout.validate(layout, stock, "mogul")
	check(checked.ok, "family45 full-scale legal exact-copy site: " + checked.error)
	if not checked.ok:
		return
	check(
		(
			checked.live_units == 4
			and not checked.night_qualified
			and checked.stored.has(SPARE)
			and not checked.stored.has(FIRST)
		),
		"four units, no Night, exact stored spare"
	)
	for tier: String in ["backyard", "expanded", "club"]:
		check(
			not StadiumHomeLayout.validate(layout, stock, tier).ok,
			"smaller property rejected " + tier
		)
	var bad: Dictionary = layout.duplicate(true)
	bad.live_waterfalls.append({"copy": SPARE, "site": "WF-LIVE-LF"})
	check(not StadiumHomeLayout.validate(bad, stock, "mogul").ok, "second live unit rejected")
	bad = layout.duplicate(true)
	bad.live_waterfalls[0].site = "LANDMARK-A"
	check(
		not StadiumHomeLayout.validate(bad, stock, "mogul").ok,
		"no decorative site gets live authority"
	)
	bad = StadiumWaterfallItems.place(layout, stock, FIRST, "LANDMARK-A", 0, ledger.surface_owned())
	check(
		not StadiumHomeLayout.validate(bad, stock, "mogul").ok,
		"same copy cannot occupy decorative and live routes"
	)
	var decorative: Dictionary = StadiumWaterfallItems.place(
		StadiumWaterfallLiveItems.store_copy(layout, FIRST),
		stock,
		FIRST,
		"LANDMARK-A",
		0,
		ledger.surface_owned()
	)
	check(
		StadiumHomeLayout.validate(decorative, stock, "mogul").ok,
		"explicit Store then decorative placement remains legal"
	)
	bad = StadiumWaterfallLiveItems.place(
		decorative, stock, FIRST, "WF-LIVE-LF", 0, ledger.surface_owned()
	)
	check(
		not StadiumHomeLayout.validate(bad, stock, "mogul").ok,
		"decorative-first duplicate denied without silent move"
	)
	var coexist: Dictionary = StadiumOutfieldPlazaItems.place(
		layout, stock, KIT, "promenade_court", ledger.surface_owned()
	)
	coexist = StadiumOutfieldPlazaItems.place_occupant(coexist, SPARE, "PLAZA-W")
	check(
		StadiumHomeLayout.validate(coexist, stock, "mogul").ok,
		"actual merged validator permits live waterfall plus separate full-size decorative plaza copy"
	)
	var quote: Dictionary = StadiumPurchases.quote(
		stock, "ST-002", 1, "companion", 19, {"seasons": 999, "wins": 999}
	)
	check(quote.ok, "companion fixture paid stock")
	if quote.ok:
		bad = StadiumLiveFurnishingItems.place(
			layout, StadiumStock.from_data(quote.state), "purchase:companion:0", "O-R2", 0
		)
		check(
			not StadiumHomeLayout.validate(bad, StadiumStock.from_data(quote.state), "mogul").ok,
			"live companion rejected even spatially opposite"
		)
	if not _apply(ledger, coexist, "live plus decorative plaza"):
		return
	check(
		ledger.to_data().version == 54 and ledger.to_data().has("live_waterfall_layout_catalog"),
		"canonical additive journal54 header"
	)
	check(
		ClubCareer.same(ledger.prefix(old_revision).to_data(), old),
		"exact historical plaza prefix unchanged and header stripped"
	)
	_cold(ledger, "installed")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger, true)
	check(
		StadiumLayoutSnapshot.valid(snapshot) and StadiumLayoutSnapshot.matches(snapshot, ledger),
		"exact paid replay snapshot"
	)
	check(
		(
			StadiumLayoutSnapshot.valid(_json(snapshot))
			and StadiumLayoutSnapshot.key(_json(snapshot)) == StadiumLayoutSnapshot.key(snapshot)
		),
		"cold replay key stable"
	)
	for key: String in ["live_waterfall_layout_catalog"]:
		bad = ledger.to_data()
		bad.erase(key)
		check(_load(bad) == null, "missing live header rejected")
		bad = ledger.to_data()
		bad[key] = "forged"
		check(_load(bad) == null, "forged live header rejected")
	bad = ledger.to_data()
	bad.version = 53
	bad.erase("live_waterfall_layout_catalog")
	check(_load(bad) == null, "pre54 journal refuses family45 events")
	var prior: Dictionary = ledger.to_data()
	var revision: int = ledger.revision()
	var stored: Dictionary = StadiumWaterfallLiveItems.store_copy(coexist, FIRST)
	check(
		StadiumHomeLayout.preview(coexist, stored, stock, "mogul").displaced.has(FIRST),
		"preview reports exact live copy stored"
	)
	check(
		ClubCareer.same(StadiumWaterfallLiveItems.store_copy(coexist, SPARE), coexist),
		"stored spare cannot clear live copy"
	)
	if not _apply(ledger, stored, "Store live only"):
		return
	check(
		(
			ledger.construction().copies.has(FIRST)
			and ledger.view().stadium_active.live_waterfalls.is_empty()
			and ledger.view().stadium_active.outfield_plaza[0].occupants.size() == 1
		),
		"Store retains paid live copy and decorative plaza occupant"
	)
	check(
		(
			ClubCareer.same(ledger.prefix(revision).to_data(), prior)
			and StadiumLayoutSnapshot.matches(snapshot, ledger)
		),
		"Store leaves historical match prefix replayable"
	)
	_cold(ledger, "stored")
	_workshop(ledger, coexist)
	await _match_routes(ledger, snapshot)
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	check(property.build("mogul", coexist, stock), "full property reconstructs both exact roles")
	var boundary: Node3D = StadiumBoundaryRuntime.assemble(property)
	check(boundary != null and property.props_intact(), "whole property and boundary seal valid")
	if property.objects.has(FIRST) and property.objects.has(SPARE):
		check(
			(
				property.objects[FIRST].has_node("Collision/WATERFALL_STONE")
				and (
					property
					. objects[SPARE]
					. find_children("*", "CollisionObject3D", true, false)
					. is_empty()
				)
			),
			"only explicit live copy owns physical collision"
		)
		check(
			(
				property.objects[FIRST].scale == Vector3.ONE
				and StadiumWaterfallModels.valid(property.objects[SPARE])
			),
			"live is unshrunk and plaza retains frozen complete model"
		)
	property.queue_free()
	await get_tree().process_frame


func _apply(ledger: ClubAssetLedger, layout: Dictionary, label: String) -> bool:
	var balance: int = ledger.balance()
	var stock_before: Dictionary = ledger.construction().to_data()
	var active_before: Dictionary = ledger.view().stadium_active
	var before: Dictionary = ledger.to_data()
	var draft: Dictionary = {
		"id": "live-waterfall-draft:%d" % ledger.revision(),
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
		"id": "live-waterfall-apply:%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_apply",
		"layout": layout,
		"geometry": StadiumWaterfallLiveItems.geometry(ledger.view().land, layout)
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
		if index % 10 == 0:
			print("LIVE_WATERFALL_FULL_SAVE_STAGE seasons ", index, "/41")
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
	print("LIVE_WATERFALL_FULL_SAVE_STAGE cold career")
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
	SeasonSave.path = "user://live-waterfall-full-save.json"
	print("LIVE_WATERFALL_FULL_SAVE_STAGE initial disk save")
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
	SeasonSave.path = "user://live-waterfall-missing-directory/blocked.json"
	var failed: Dictionary = ClubConstruction.buy_copy(season, "ST-046", ledger.revision(), 2)
	check(
		(
			not failed.ok
			and failed.error.begins_with("Could not save season.")
			and ClubCareer.same(season.career.to_data(), before)
		),
		"failed actual file write rolls back waterfall purchase/wallet/inventory"
	)
	SeasonSave.path = "user://live-waterfall-full-save.json"
	check(
		FileAccess.get_file_as_string(SeasonSave.path) == previous_bytes,
		"failed purchase leaves prior saved bytes unchanged"
	)
	print("LIVE_WATERFALL_FULL_SAVE_STAGE paid purchase and Workshop")
	var bought: Dictionary = ClubConstruction.buy_copy(season, "ST-046", ledger.revision(), 2)
	check(
		bought.ok, "public ordinary purchase dispatch pays950+2x260 and persists: " + bought.error
	)
	if bought.ok:
		ledger = ClubPlayers.assets(season.career)
		var copy: String = "purchase:stadium-buy:%d:0" % (ledger.revision() - 1)
		var layout: Dictionary = StadiumWaterfallLiveItems.place(
			ledger.view().stadium_draft,
			ledger.construction(),
			copy,
			"WF-LIVE-LF",
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
			print("LIVE_WATERFALL_FULL_SAVE_STAGE cold SeasonSave envelope")
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


func _match_routes(ledger: ClubAssetLedger, snapshot: Dictionary) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = snapshot.duplicate(true)
	lab._stadium_ledger = ledger
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	check(installed, "ordinary paid match installer accepts historical exact live snapshot")
	if not installed:
		print(
			"LIVE_INSTALL_DIAGNOSTIC ",
			{
				"has_property": lab.has_meta("stadium_property"),
				"snapshot_valid": StadiumLayoutSnapshot.valid(snapshot),
				"matches": StadiumLayoutSnapshot.matches(snapshot, ledger),
				"fielder": lab._primary_fielder.global_position,
				"pitcher": lab._pitcher_marker.global_position
			}
		)
		if lab.has_meta("stadium_property"):
			var diagnostic: StadiumPropertyGeometry = lab.get_meta("stadium_property")
			print(
				"LIVE_PROPERTY_DIAGNOSTIC ",
				{
					"props": diagnostic.props_intact(),
					"live": diagnostic._props_live,
					"boundary": diagnostic.has_node("BoundaryGraph"),
					"step":
					lab._primary_fielder.stadium_waterfall_step == diagnostic.waterfall_step,
					"clip": lab._primary_fielder.stadium_waterfall_clip == diagnostic.waterfall_clip
				}
			)
	if installed:
		await get_tree().physics_frame
		await get_tree().physics_frame
		var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
		var boundary: StadiumBoundaryOwnedRuntime = property.get_node("BoundaryGraph")
		var fielder: FielderController = lab._primary_fielder
		check(
			property.props_intact() and StadiumBoundaryRuntime.installed(lab, snapshot),
			"actual live match route/seal installation intact"
		)
		fielder.active = false
		fielder.set_anchor(Vector3(-5.5, 0, 19.5))
		var start: Vector3 = fielder.global_position
		FielderFirstStep.advance(fielder, Vector3.LEFT, 0.3)
		check(
			(
				StadiumWaterfallLiveRoutes.clear(start, fielder.global_position, boundary.graph)
				and fielder.global_position.z == start.z
			),
			"actual forced first-step clips at full basin footprint without steering or crossing"
		)
		fielder.set_anchor(Vector3(0, 0, 14))
		fielder.active = true
		fielder.first_step = Vector3.ZERO
		fielder._play_elapsed_seconds = 1.0
		fielder.target_position = StadiumWaterfallLiveSites.CENTER + Vector3(0, 0, -1.075)
		var all_clear: bool = true
		for step in range(180):
			var before: Vector3 = fielder.global_position
			fielder._physics_process(1.0 / 60.0)
			all_clear = (
				all_clear
				and StadiumWaterfallLiveRoutes.clear(
					before, fielder.global_position, boundary.graph
				)
			)
		check(
			all_clear and property.props_intact(),
			"actual fielder controller follows legal full-scale approach segments"
		)
		check(
			(
				fielder.global_position.distance_to(fielder.target_position)
				> StadiumWaterfallLiveModels.MAX_DEFENDER_REACH
			),
			"grounded fielder cannot reach through the actual trapped-ball basin"
		)
		var pitcher_from: Vector3 = lab._pitcher_marker.global_position
		var pitcher_next: Vector3 = StadiumPropertyRuntime.pitcher_step(
			lab, fielder.target_position, 20, fielder.target_position
		)
		check(
			StadiumWaterfallLiveRoutes.clear(pitcher_from, pitcher_next, boundary.graph),
			"actual pitcher helper respects same physical waterfall route"
		)
		var original: Callable = fielder.stadium_waterfall_step
		fielder.stadium_waterfall_step = Callable()
		check(
			not property.props_intact() and not StadiumBoundaryRuntime.installed(lab, snapshot),
			"route callback replacement fails closed"
		)
		fielder.stadium_waterfall_step = original
		check(property.props_intact(), "exact route restoration recovers original seal")
	lab.queue_free()
	await get_tree().process_frame


func _workshop(ledger: ClubAssetLedger, layout: Dictionary) -> void:
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	var panel: VBoxContainer = VBoxContainer.new()
	menu._body.add_child(panel)
	StadiumWaterfallItemsUI.card(menu, panel, layout, FIRST, ledger.revision(), false)
	var choices: Array[Node] = panel.find_children("*", "OptionButton", true, false)
	check(
		(
			choices.size() == 1
			and choices[0].selected == 2
			and choices[0].disabled
			and choices[0].item_count == 3
		),
		"Workshop selects exact live copy without relabelling it Stored or decorative"
	)
	StadiumWaterfallItemsUI.purchases(menu, ledger, layout, ledger.revision(), false)
	var text: String = ""
	for node: Node in menu._body.find_children("*", "Label", true, false):
		text += node.text + "\n"
	check(
		(
			text.contains("live site: 1 of 1")
			and text.contains("all four live units")
			and text.contains("no companions")
			and text.contains("foul precedence")
		),
		"Workshop discloses installed live role, capacity and exact award policy"
	)
	check(
		(
			text.contains("950")
			and text.contains("260")
			and text.contains("24 completed seasons")
			and text.contains("90 regular-season wins")
			and text.contains("no colliders")
		),
		"Workshop preserves prices/unlocks and distinguishes decorative no-collision option"
	)
	menu.free()
	app.free()

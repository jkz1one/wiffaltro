extends Node3D
## Synthetic funding/progression; real paid journal, property and snapshot consumers.
const SEED: int = 194
const KIT: String = "purchase:plaza-kits:0"
const SPARE: String = "purchase:plaza-kits:1"
const APPLE: String = "purchase:plaza-apple:0"
const WATER: String = "purchase:plaza-water:0"
const ROCK: String = "purchase:plaza-rock:0"
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
		push_error("PLAZA: " + label)


func _ready() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5, "homers": 5})
	_gates()
	_paid = ClubAssetLedger.new(SEED, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		var result: Dictionary = _paid.commit(
			{
				"id": "plaza-land-" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": credits.size(),
				"progress_through": progress.size(),
				"price_version": StadiumLand.VERSION
			}
		)
		check(result.ok, "paid land " + tier + ": " + result.error)
	var old: Dictionary = _paid.to_data()
	var old_revision: int = _paid.revision()
	if (
		_buy("ST-112", "plaza-kits", 2, 34)
		and _buy("ST-047", "plaza-apple", 2, 26)
		and _buy("ST-046", "plaza-water", 2, 32)
		and _buy("ST-019", "plaza-rock", 2, 18)
		and _buy("ST-111", "plaza-light", 1, 33)
	):
		check(
			ClubCareer.same(_paid.prefix(old_revision).to_data(), old),
			"new extension preserves exact pre-purchase prefix"
		)
		for recipe: String in StadiumOutfieldPlazaRecipes.RECIPES:
			await _recipe(recipe)
		await _runtime()
	if "--plaza-full-save" in OS.get_cmdline_user_args():
		_season_save()
	print(
		(
			"OWNED_PLAZA_RESULT "
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


func _gates() -> void:
	for point: Array in [[23, 90, false], [24, 89, false], [24, 90, true]]:
		var quote: Dictionary = StadiumPurchases.quote(
			StadiumStock.new_club(),
			"ST-112",
			1,
			"gate",
			34,
			{"seasons": point[0], "wins": point[1]}
		)
		check(quote.ok == point[2], "plaza exact progress gate " + str(point))
		if quote.ok:
			check(quote.blueprint_cost == 1100 and quote.copy_cost == 420, "Working1100/420 quote")
	check(
		not (
			StadiumPurchases
			. quote(StadiumStock.new_club(), "ST-112", 1, "old", 33, {"seasons": 99, "wins": 999})
			. ok
		),
		"older price family cannot purchase plaza"
	)


func _buy(item: String, id: String, quantity: int, price: int) -> bool:
	var before: int = _paid.balance()
	var entry: Dictionary = StadiumCatalog.item(item)
	var command: Dictionary = {
		"id": id,
		"rev": _paid.revision(),
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": price,
		"through": credits.size(),
		"progress_through": progress.size()
	}
	var result: Dictionary = _paid.commit(command)
	check(result.ok, "paid purchase " + item + ": " + result.error)
	if result.ok:
		check(
			_paid.balance() == before - entry.blueprint_price - quantity * entry.copy_price,
			"exact debit " + item
		)
		var after: Dictionary = _paid.to_data()
		check(
			(
				_paid.commit(command).get("replayed", false)
				and ClubCareer.same(after, _paid.to_data())
			),
			"purchase retry exact " + item
		)
	return result.ok


func _recipe(recipe: String) -> void:
	var empty: Dictionary = StadiumOutfieldPlazaItems.upgrade(
		_paid.view().stadium_draft, _paid.surface_owned()
	)
	if not empty.outfield_plaza.is_empty():
		for child: Dictionary in empty.outfield_plaza[0].occupants.duplicate(true):
			empty = StadiumOutfieldPlazaItems.store_copy(empty, child.copy)
		empty = StadiumOutfieldPlazaItems.store_copy(empty, KIT)
	var layout: Dictionary = StadiumOutfieldPlazaItems.place(
		empty, _paid.construction(), KIT, recipe, _paid.surface_owned()
	)
	var validated: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), "mogul")
	check(validated.ok, recipe + " complete empty infrastructure valid: " + validated.error)
	if not validated.ok:
		return
	check(
		not validated.night_qualified and validated.live_units == 0,
		recipe + " no Night eligibility or live budget"
	)
	check(
		validated.stored.has(APPLE) and validated.stored.has(WATER) and validated.stored.has(ROCK),
		recipe + " no automatic optional copy placement"
	)
	for tier: String in ["backyard", "expanded", "club"]:
		check(
			not StadiumHomeLayout.validate(layout, _paid.construction(), tier).ok,
			recipe + " refuses smaller property " + tier
		)
	var conflict: Dictionary = StadiumLandscapeOwnedItems.place(
		empty, _paid.construction(), ROCK, "LAND-R"
	)
	check(
		StadiumHomeLayout.validate(conflict, _paid.construction(), "mogul").ok,
		recipe + " old rock site independently remains valid"
	)
	check(
		not (
			StadiumHomeLayout
			. validate(
				StadiumOutfieldPlazaItems.place(
					conflict, _paid.construction(), KIT, recipe, _paid.surface_owned()
				),
				_paid.construction(),
				"mogul"
			)
			. ok
		),
		recipe + " existing landscape blocks entrance in landscape-first order"
	)
	check(
		not (
			StadiumHomeLayout
			. validate(
				StadiumLandscapeOwnedItems.place(layout, _paid.construction(), ROCK, "LAND-R"),
				_paid.construction(),
				"mogul"
			)
			. ok
		),
		recipe + " same conflict rejects in plaza-first order"
	)
	var def: Dictionary = StadiumOutfieldPlazaRecipes.definition(recipe)
	if def.sites.has("PLAZA-W"):
		layout = StadiumOutfieldPlazaItems.place_occupant(
			layout, APPLE if recipe == "promenade_court" else WATER, "PLAZA-W"
		)
	if def.sites.has("PLAZA-E"):
		layout = StadiumOutfieldPlazaItems.place_occupant(layout, WATER, "PLAZA-E")
	if def.sites.has("GARDEN-1"):
		layout = StadiumOutfieldPlazaItems.place_occupant(layout, ROCK, "GARDEN-1")
	validated = StadiumHomeLayout.validate(layout, _paid.construction(), "mogul")
	check(validated.ok, recipe + " qualified explicit optional copies: " + validated.error)
	if not validated.ok or not _apply(_paid, layout, recipe):
		return
	_coexistence(empty, layout, recipe)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid, true)
	check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.valid(snapshot)
			and StadiumLayoutSnapshot.matches(snapshot, _paid)
		),
		recipe + " exact-prefix saved snapshot"
	)
	check(
		(
			StadiumLayoutSnapshot.valid(_json(snapshot))
			and StadiumLayoutSnapshot.key(snapshot) == StadiumLayoutSnapshot.key(_json(snapshot))
		),
		recipe + " cold snapshot key stable"
	)
	_cold(_paid, recipe)
	for key: String in ["outfield_plaza_catalog", "outfield_plaza_layout_catalog"]:
		var bad: Dictionary = _paid.to_data()
		bad.erase(key)
		check(_load(bad) == null, recipe + " missing seal rejects " + key)
		bad = _paid.to_data()
		bad[key] = "forged"
		check(_load(bad) == null, recipe + " forged seal rejects " + key)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.layout.outfield_plaza[0].copy = SPARE
	check(
		StadiumLayoutSnapshot.valid(bad) and not StadiumLayoutSnapshot.matches(bad, _paid),
		recipe + " owned spare cannot replace exact historical fixture"
	)
	bad = layout.duplicate(true)
	bad.outfield_plaza[0]["yaw"] = 0
	check(
		not StadiumHomeLayout.validate(bad, _paid.construction(), "mogul").ok,
		recipe + " unknown declaration field rejects"
	)
	bad = StadiumOutfieldPlazaItems.place_occupant(layout, "unowned", "PLAZA-W")
	check(
		not StadiumHomeLayout.validate(bad, _paid.construction(), "mogul").ok,
		recipe + " unowned occupant rejects"
	)
	check(
		ClubCareer.same(StadiumOutfieldPlazaItems.store_copy(layout, KIT), layout),
		recipe + " kit cannot silently drop paid occupants"
	)
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	check(
		property.build("mogul", layout, _paid.construction()),
		recipe + " complete actual property builds"
	)
	if property.objects.has(KIT):
		check(
			(
				property.props_intact()
				and (
					property
					. objects[KIT]
					. find_children("*", "CollisionObject3D", true, false)
					. is_empty()
				)
			),
			recipe + " sealed collider-free infrastructure"
		)
		var part: MeshInstance3D = property.objects[KIT].get_child(0)
		var original: Transform3D = part.transform
		part.position.x += 0.01
		check(not property.props_intact(), recipe + " mesh tamper fails closed")
		part.transform = original
		check(property.props_intact(), recipe + " exact geometry restoration restores seal")
	property.free()
	await _views(layout, recipe)
	if recipe == "promenade_court":
		_layout = layout.duplicate(true)
		_snapshot = snapshot.duplicate(true)


func _coexistence(empty: Dictionary, layout: Dictionary, recipe: String) -> void:
	for pattern: String in StadiumLightingKitItems.PATTERNS:
		var light: Dictionary = StadiumLightingKitItems.place(
			empty, _paid.construction(), "purchase:plaza-light:0", pattern
		)
		var alone: Dictionary = StadiumHomeLayout.validate(light, _paid.construction(), "mogul")
		check(alone.ok, recipe + " lighting alone valid " + pattern)
		var reverse: Dictionary = StadiumOutfieldPlazaItems.place(
			light, _paid.construction(), KIT, recipe, _paid.surface_owned()
		)
		for child: Dictionary in layout.outfield_plaza[0].occupants:
			reverse = StadiumOutfieldPlazaItems.place_occupant(reverse, child.copy, child.site)
		var forward: Dictionary = StadiumLightingKitItems.place(
			layout, _paid.construction(), "purchase:plaza-light:0", pattern
		)
		var expected: bool = true
		for reserve: AABB in StadiumOutfieldPlazaRecipes.reservations(recipe):
			for component: Dictionary in StadiumLightingKitModels.components(pattern):
				if reserve.intersects(component.bounds):
					expected = false
		var first: Dictionary = StadiumHomeLayout.validate(forward, _paid.construction(), "mogul")
		var second: Dictionary = StadiumHomeLayout.validate(reverse, _paid.construction(), "mogul")
		check(
			first.ok == expected and second.ok == expected and ClubCareer.same(forward, reverse),
			recipe + " symmetric component-verified lighting coexistence " + pattern
		)
		check(
			not first.get("night_qualified", false),
			recipe + " lighting never grants plaza Night " + pattern
		)
		print(
			(
				"PLAZA_LIGHTING_COEXISTENCE "
				+ JSON.stringify(
					{
						"recipe": recipe,
						"pattern": pattern,
						"allowed": first.ok,
						"error": first.error
					}
				)
			)
		)


func _runtime() -> void:
	if _snapshot.is_empty():
		return
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = _snapshot.duplicate(true)
	lab._stadium_ledger = _paid
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	check(
		installed,
		"ordinary match installs exact historical plaza snapshot after later recipe changes"
	)
	if installed:
		var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
		await get_tree().physics_frame
		check(
			property.props_intact() and StadiumBoundaryRuntime.installed(lab, _snapshot),
			"actual runtime boundary and paid resources remain sealed"
		)
		var apple: StadiumRisingAppleRuntime = StadiumRisingAppleRuntime.current(lab)
		check(
			apple != null and apple.intact() and apple.height() == 0,
			"relocated paid apple uses existing reset clock controller"
		)
		check(
			(
				property.objects[APPLE].position == Vector3(-17.5, 0, 44)
				and property.objects[WATER].position == Vector3(17.5, 0, 44)
			),
			"both complete landmarks occupy disjoint original-scale pads"
		)
		check(
			property.route_obstacles().is_empty(),
			"plaza adds no defender routes or live obstacle budget"
		)
		var tracking: BallTrackingVisibility = lab._camera_director.tracking_visibility
		var collected: bool = true
		for mesh: MeshInstance3D in property.objects[KIT].get_children():
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			if mesh.name.begins_with("Backdrop"):
				collected = collected and tracking._obstacles.has(box)
			if mesh.name.begins_with("Paving"):
				check(
					not tracking._obstacles.has(box),
					"flush plaza paving never causes false camera occlusion"
				)
		check(
			collected,
			"actual individual outer walls reach camera avoidance without a giant courtyard box"
		)
		if apple != null:
			lab.set_process(true)
			lab.set_physics_process(true)
			var outcomes: Array[BallPlayOutcome] = []
			lab._ball_play_resolver.play_resolved.connect(
				func(value: BallPlayOutcome) -> void: outcomes.append(value)
			)
			var score_before: int = (
				lab._match_state.away_team.runs + lab._match_state.home_team.runs
			)
			lab._active_play_record = PlayRecord.new()
			check(lab._match_state.begin_pitch(), "ordinary pitch state starts actual HR probe")
			await get_tree().process_frame
			var launch: BattedBallLaunch = BattedBallLaunch.new()
			launch.position = Vector3(0, 1, 0.28)
			launch.velocity = Vector3(-4, 18, 30)
			launch.orientation = Quaternion.IDENTITY
			launch.angular_velocity = Vector3.ZERO
			lab._start_ball_in_play(launch)
			check(
				apple.accepted_events == 0 and apple.height() == 0,
				"plaza apple stays concealed during undecided actual flight"
			)
			var saw_rise: bool = false
			for frame in range(480):
				await get_tree().physics_frame
				saw_rise = saw_rise or apple.height() > 0
				if saw_rise and not lab._home_run.active:
					break
			check(
				outcomes.size() == 1 and outcomes[0].result == BallPlayOutcome.Result.HOME_RUN,
				"actual flight still scores one HR at inner boundary"
			)
			check(
				apple.accepted_events == 1 and saw_rise and apple.intact(),
				"same existing clock raises relocated paid apple after confirmed HR"
			)
			check(
				(
					lab._play_records.size() == 1
					and lab._play_records[0].result == &"home_run"
					and (
						lab._match_state.away_team.runs + lab._match_state.home_team.runs
						== score_before + 1
					)
				),
				"plaza scenery creates no second outcome or changed score"
			)
	lab.queue_free()
	await get_tree().process_frame


func _views(layout_value: Dictionary, recipe: String) -> void:
	var directory: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			directory = argument.trim_prefix("--ui-capture-dir=")
	if DisplayServer.get_name() == "headless":
		return
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("res://../evidence/native")
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = StadiumLayoutSnapshot.capture(_paid, true)
	lab._stadium_ledger = _paid
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	check(
		installed and ClubCareer.same(lab._match_state.stadium.layout, layout_value),
		recipe + " native exact current paid snapshot"
	)
	if not installed:
		lab.queue_free()
		await get_tree().process_frame
		return
	var capture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd").new()
	add_child(capture)
	await capture.initialize()
	check(await capture.resize(Vector2i(1280, 720)), recipe + " native1280 handshake")
	lab._status_label.hide()
	lab._camera.make_current()
	check(
		await capture.capture(directory, recipe + "-ordinary-batting"),
		recipe + " actual batting view"
	)
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.fov = 50
	camera.position = Vector3(48, 36, -5)
	camera.look_at(Vector3(0, 0, 29))
	camera.make_current()
	check(
		await capture.capture(directory, recipe + "-complete-park"),
		recipe + " complete field and concourse"
	)
	camera.position = Vector3(-38, 15, 21)
	camera.look_at(Vector3(-5, 1, 41))
	check(
		await capture.capture(directory, recipe + "-concourse-detail"),
		recipe + " actual connecting paving and landmark pads"
	)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 104
	camera.position = Vector3(0, 80, 14)
	camera.look_at(Vector3(0, 0, 14), Vector3.FORWARD)
	check(
		await capture.capture(directory, recipe + "-overhead"),
		recipe + " native overhead full property"
	)
	check(
		(lab.get_meta("stadium_property") as StadiumPropertyGeometry).props_intact(),
		recipe + " captures preserve installed resource seal"
	)
	camera.free()
	capture.free()
	lab.queue_free()
	await get_tree().process_frame


func _apply(ledger: ClubAssetLedger, layout: Dictionary, label: String) -> bool:
	var balance: int = ledger.balance()
	var stock_before: Dictionary = ledger.construction().to_data()
	var active_before: Dictionary = ledger.view().stadium_active
	var before: Dictionary = ledger.to_data()
	var draft: Dictionary = {
		"id": "plaza-draft:%d" % ledger.revision(),
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
		"id": "plaza-apply:%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_apply",
		"layout": layout,
		"geometry": StadiumOutfieldPlazaItems.geometry(ledger.view().land, layout)
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
	for index in range(45):
		season = StadiumPennantRewardRebuildChecks._new(career)
		if (
			season == null
			or not StadiumPennantRewardRebuildChecks._finish(season)
			or not career.sync(season)
		):
			complete = false
			break
		if index < 44 and not career.close(season):
			complete = false
			break
	check(
		complete,
		"forty-five authored score-only completed seasons supply real validated funding/progress shape"
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
				"id": "plaza-save-land-" + tier,
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
	SeasonSave.path = "user://plaza-full-save.json"
	var saved: bool = SeasonSave.save(season)
	check(saved, "actual pre-purchase file saves: " + SeasonSave.last_error)
	if not saved:
		SeasonSave.path = original_path
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var quote: Dictionary = StadiumPurchases.quote(
		ledger.construction(),
		"ST-112",
		1,
		"full-save-preview",
		34,
		StadiumCareerProgress.metrics(
			StadiumCareerProgress.capture(season.career),
			StadiumCareerProgress.capture(season.career).size()
		)
	)
	check(
		quote.ok and ledger.balance() >= 1520,
		"validated post-land wallet can afford the1520 single-copy transaction"
	)
	if not quote.ok or ledger.balance() < 1520:
		SeasonSave.path = original_path
		return
	var before: Dictionary = season.career.to_data()
	var previous_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = "user://plaza-missing-directory/blocked.json"
	var failed: Dictionary = ClubConstruction.buy_copy(season, "ST-112", ledger.revision(), 1)
	check(
		(
			not failed.ok
			and failed.error.begins_with("Could not save season.")
			and ClubCareer.same(season.career.to_data(), before)
		),
		"failed actual file write rolls back plaza purchase/wallet/inventory"
	)
	SeasonSave.path = "user://plaza-full-save.json"
	check(
		FileAccess.get_file_as_string(SeasonSave.path) == previous_bytes,
		"failed purchase leaves prior saved bytes unchanged"
	)
	var bought: Dictionary = ClubConstruction.buy_copy(season, "ST-112", ledger.revision(), 1)
	check(bought.ok, "public ordinary purchase dispatch pays1100+420 and persists: " + bought.error)
	if bought.ok:
		ledger = ClubPlayers.assets(season.career)
		var copy: String = "purchase:stadium-buy:%d:0" % (ledger.revision() - 1)
		var layout: Dictionary = StadiumOutfieldPlazaItems.place(
			ledger.view().stadium_draft,
			ledger.construction(),
			copy,
			"promenade_court",
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
			if cold != null:
				_workshop(cold, copy)
	SeasonSave.path = original_path


func _workshop(season: SeasonState, copy: String) -> void:
	var app: SeasonApp = SeasonApp.new()
	app.season = season
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var layout: Dictionary = ledger.view().stadium_draft
	StadiumOutfieldPlazaItemsUI.purchases(menu, ledger, layout, ledger.revision(), false)
	var panel: VBoxContainer = VBoxContainer.new()
	menu._body.add_child(panel)
	StadiumOutfieldPlazaItemsUI.card(menu, panel, layout, copy, ledger.revision(), false)
	var options: Array[Node] = panel.find_children("*", "OptionButton", true, false)
	check(options.size() == 3, "actual Workshop kit and two optional pads appear")
	if options.size() == 3:
		var choice: OptionButton = options[0]
		check(
			choice.disabled and choice.item_count == 4 and choice.selected == 1,
			"locked Workshop names all recipes and exact installed one"
		)
		check(
			choice.is_item_disabled(2) and choice.is_item_disabled(3),
			"Workshop requires explicit Store before recipe switch"
		)
		check(
			(
				(options[1] as OptionButton).item_count == 1
				and (options[2] as OptionButton).item_count == 1
			),
			"unowned landmarks never offered as free occupants"
		)
	var buys: Array[Node] = menu._body.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return node.get_meta("stadium_buy", "") == "ST-112"
	)
	check(
		buys.size() == 1 and (buys[0] as Button).disabled,
		"actual locked purchase control respects policy"
	)
	menu.free()
	app.free()

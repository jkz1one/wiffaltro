extends "res://src/tests/season_special_order_test.gd"

const GearProgressFixture = preload("res://src/tests/season_gear_progress_test.gd")
const WholesaleFixture = preload("res://src/tests/season_wholesale_test.gd")
const AssociationFixture = preload("res://src/tests/season_association_test.gd")


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://collection-%d.json" % OS.get_process_id()
	_grouped_acquisitions()
	print("COLLECTION_STAGE groups complete")
	var season: SeasonState = _paid_discovery()
	print("COLLECTION_STAGE paid complete")
	_migration_collection(season)
	print("COLLECTION_STAGE migration complete")
	await _collection_ui(season)
	print("COLLECTION_STAGE UI complete")
	_carry_collection(season)
	print("COLLECTION_STAGE carry complete")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro collection checks passed: acquisition, history, migration, concealment and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _collection_order(buy: bool) -> SeasonState:
	# Recorded generated fixture, not injected stock or a search for a passing outcome.
	var season: SeasonState = _new_club(27)
	for game in range(3):
		_result(season, [])
	var build: SeasonBuild = season.build
	_check(build.commit(_command(build, "open")).ok, "earned order shop opens")
	for roll in range(4):
		_check(build.commit(_command(build, "reroll")).ok, "four paid ordinary rerolls")
	var offer: String = _offer(build, "J01")
	_check(not offer.is_empty(), "recorded seed generates actual Special Order offer")
	if buy:
		_check(
			build.commit(_command(build, "sponsor_buy", {"offer": offer, "replace": ""})).ok,
			"pay actual generated sponsor price"
		)
	return season


func _paid_discovery() -> SeasonState:
	print("COLLECTION_STAGE start order fixture")
	var season: SeasonState = _collection_order(false)
	print("COLLECTION_STAGE order fixture complete")
	var build: SeasonBuild = season.build
	_check(ClubCollection.catalog().size() == 58, "23 implemented Gear and 35 sponsors")
	_check(ClubCollection.acquired(build).is_empty(), "earn/display/reroll never acquires")
	_check(SeasonSave.save(season), "save earned access before purchase")
	_check(ClubCollection.access(season.career).has("J01"), "access distinct from discovery")
	var command: Dictionary = _command(
		build, "sponsor_buy", {"offer": _offer(build, "J01"), "replace": ""}
	)
	var before: Dictionary = build.to_data()
	_check(build.preview(command).ok, "purchase preview is legal")
	_check(ClubCollection.acquired(build).is_empty() and build.to_data() == before, "preview inert")
	var invalid: Dictionary = command.duplicate(true)
	invalid.replace = "not-owned"
	_check(
		not build.commit(invalid).ok and ClubCollection.acquired(build).is_empty(), "reject inert"
	)
	var candidate: SeasonBuild = build.candidate(command)
	_check(ClubCollection.acquired(candidate) == ["J01"], "detached candidate derives discovery")
	_check(ClubCollection.acquired(build).is_empty(), "candidate never publishes original")
	_check(build.commit(command).ok and build.commit(command).replayed, "buy/retry once")
	_check(ClubCollection.acquired(build) == ["J01"], "one successful acquisition")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	var career: Dictionary = season.career.to_data()
	SeasonSave.path = path + "/missing/save.json"
	_check(not SeasonSave.save(season), "failed save")
	SeasonSave.path = path
	_check(season.career.to_data() == career, "failed save cannot publish career discovery")
	_check(FileAccess.get_file_as_string(path) == bytes, "failed save preserves prior bytes")
	_check(SeasonSave.save(season), "durable discovery checkpoint")
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and restored.career.runs[-1].collection == ["J01"], "saved journal agrees"
	)
	var fork: SeasonBuild = build._fork()
	_check(ClubCollection.acquired(fork) == ["J01"], "fork preserves acquisition")
	_check(
		(
			build
			. commit(
				_command(
					build, "sponsor_sell", {"receipt": SeasonSchoolSponsors.active(build, "J01").id}
				)
			)
			. ok
		),
		"ordinary sale"
	)
	_check(ClubCollection.owned(build).is_empty(), "sold is not owned")
	_check(ClubCollection.acquired(build) == ["J01"], "sold remains acquired")
	_check(SeasonSave.save(season), "sold discovery persists")
	for value: Variant in [[], ["D01"], ["J01", "J01"], ["unknown"], null, "J01"]:
		var bad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		bad.career.runs[-1].collection = value
		_check(SeasonSave._decode(bad) == null, "reject missing/forged/noncanonical current record")
	_check(not ClubCollection.valid(["J01", "D01"]), "reject unsorted record")
	_check(not ClubCollection.valid(["development.contact"]), "exclude other collection categories")
	return season


func _grouped_acquisitions() -> void:
	var fixture: Node = WholesaleFixture.new()
	for pair: Array in [["BAT-CON-01", "BALL-MOV-01"], ["D01", "F02"]]:
		var build: SeasonBuild = fixture._unit_build(["J02"])
		var request: Dictionary = fixture._pair(build, pair[0], pair[1])
		_check(build.preview(request).ok, "pair preview")
		var initial: Array[String] = ClubCollection.acquired(build)
		_check(build.commit(request).ok, "ordinary Wholesale purchase")
		for id: String in pair:
			_check(
				not initial.has(id) and ClubCollection.acquired(build).has(id),
				"each pair discovered"
			)
		_check(build.commit(request).replayed, "pair retry")
		_check(ClubCollection.acquired(build).size() == initial.size() + 2, "pair distinct once")
	_check(fixture._failures == 0, "Wholesale unit fixture valid")
	fixture.free()
	fixture = AssociationFixture.new()
	var grouped: SeasonBuild = fixture._unit_association()
	for id: String in AssociationFixture.COMMONS:
		_check(grouped.commit(fixture._unit_buy(grouped, id)).ok, "Common acquisition")
	_check(grouped.commit(fixture._unit_buy(grouped, "J05")).ok, "grouped Association acquisition")
	_check(ClubCollection.acquired(grouped).size() == 6, "grouped sponsor purchases retained")
	var history: Array[String] = ClubCollection.acquired(grouped)
	var bad: Dictionary = fixture._unit_buy(grouped, "A07")
	_check(
		not grouped.commit(bad).ok and ClubCollection.acquired(grouped) == history,
		"whole group rollback"
	)
	_check(fixture._failures == 0, "Association fixture valid")
	fixture.free()
	fixture = GearProgressFixture.new()
	var paid: SeasonState = fixture._paid_pair(GearProgressFixture.BASE_PAIR)
	_check(fixture._failures == 0 and SeasonSave.save(paid), "real generated two-Gear paid fixture")
	_check(
		paid.career.runs[-1].collection == ["BALL-MOV-01", "BAT-CON-01"],
		"canonical sorted Gear proof"
	)
	print("COLLECTION_STAGE paid Gear saved")
	var restored: SeasonState = SeasonSave.restore()
	print("COLLECTION_STAGE paid Gear restored")
	_check(
		restored != null and restored.career.runs[-1].collection == paid.career.runs[-1].collection,
		"real Gear replay"
	)
	var opponent: SeasonBuild = paid.opponents.clubs["1"].build
	_check(ClubCollection.acquired(opponent).is_empty(), "AI purchases never human discoveries")
	fixture.free()


func _migration_collection(season: SeasonState) -> void:
	_check(SeasonSave.save(season), "migration starting checkpoint")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 18
	for run: Dictionary in data.career.runs:
		run.erase("collection")
	var old_build: Dictionary = data.build.duplicate(true)
	var restored: SeasonState = SeasonSave._decode(data)
	_check(restored != null, "prior career migrates")
	_check(
		restored.career.runs[-1].collection == ["J01"], "sold acquisition recovered from journal"
	)
	_check(
		ClubCareer.same(old_build, restored.build.to_data()),
		"migration leaves exact build/stock intact"
	)
	_check(SeasonSave.save(restored) and SeasonSave.restore() != null, "new career roundtrip")
	var archived: ClubCareer = restored.career.fork()
	_check(archived.close(restored), "archive acquired season")
	var old: Dictionary = archived.to_data()
	old.version = 18
	for run: Dictionary in old.runs:
		run.erase("collection")
	var legacy: ClubCareer = ClubCareer.from_data(old)
	_check(
		legacy != null and legacy.runs[0].collection == null,
		"archive has explicit missing evidence"
	)
	_check(ClubCollection.discoveries(legacy).is_empty(), "no fabricated historical acquisition")
	_check(
		ClubCareer.from_data(legacy.to_data()) != null, "unknown archived proof remains compatible"
	)


func _carry_collection(season: SeasonState) -> void:
	_check(season.career.close(season), "abandon retains committed discoveries")
	var fresh: SeasonState = _new_club(83, season.career)
	_check(ClubCollection.discoveries(fresh.career) == ["J01"], "carry distinct discovery")
	_check(ClubCollection.owned(fresh.build).is_empty(), "no free owned copy next season")
	_check(SeasonSave.save(fresh), "new season persists prior discovery")
	var duplicate: SeasonState = _collection_order(true)
	_check(SeasonSave.save(duplicate), "second real paid acquisition")
	# Isolated aggregation checks do not manufacture a playable season or unlock proof.
	var combined: ClubCareer = fresh.career.fork()
	combined.runs.append(duplicate.career.runs[0].duplicate(true))
	_check(ClubCollection.discoveries(combined) == ["J01"], "repeat identity counts once")
	var independent: ClubCareer = fresh.career.fork()
	independent.runs[0].collection.clear()
	_check(fresh.career.runs[0].collection == ["J01"], "career fork independent")


func _collection_ui(season: SeasonState) -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.show_season()
	await _frames()
	var center: Vector2 = app.loadout.entry.position
	ClubCareerUI.show(app.menu)
	await _frames()
	await _click(_button(app.menu, "COLLECTION"))
	_check(app.menu.page == "collection", "actual collection entry")
	var seen: Array[String] = []
	for category: String in ["Gear", "Sponsors"]:
		ClubCollectionUI.show(app.menu, category)
		await _frames()
		for page in range(3 if category == "Gear" else 5):
			await _menu_bounds(app, "collection-%s-%d" % [category, page])
			_check(app.loadout.entry.position == center, "Equipped remains in central position")
			for node: Node in app.menu._body.find_children("*", "VBoxContainer", true, false):
				if not node.has_meta("collection_item"):
					continue
				var id: String = node.get_meta("collection_item")
				_check(not seen.has(id), "pagination no duplicate")
				seen.append(id)
				var item: Dictionary = ClubCollection.catalog()[id]
				if id == "J01":
					_check(
						_text(node).contains(item.effect) and _text(node).contains("NOT OWNED"),
						"sold acquisition reveals full effect with honest ownership"
					)
				else:
					_check(
						(
							_text(node).contains(ClubCollectionUI.CONCEALED)
							and not _text(node).contains(item.effect)
						),
						"undiscovered effect concealed"
					)
			var next: Button = _button(app.menu, "NEXT")
			if next != null:
				await _click(next)
	_check(seen.size() == 58, "all implemented equipment reachable")
	ClubGearProgressUI.show(app.menu)
	await _frames()
	for id: String in SeasonEarnedGear.ITEMS:
		_check(
			not _text(app.menu).contains(SeasonGearCatalog.item(id).effect),
			"progress cannot leak Gear effect"
		)
	ClubSponsorProgressUI.show(app.menu)
	await _frames()
	for id: String in ClubCollection.catalog():
		if SeasonSponsorCatalog.item(id).is_empty():
			continue
		if id == "J01":
			_check(
				_text(app.menu).contains(SeasonSpecialOrder.ITEMS.J01.effect),
				"acquired progress reveals effect"
			)
		else:
			_check(
				not _text(app.menu).contains(SeasonSponsorCatalog.item(id).effect),
				"progress cannot leak sponsor effect"
			)
	await _click(app.loadout.entry)
	_check(app.loadout.panel.visible, "shared Equipped still opens")
	app.loadout.close()
	app.queue_free()
	await _frames()


func _text(parent: Node) -> String:
	var result: String = ""
	for child: Node in parent.find_children("*", "Label", true, false):
		result += child.text + "\n"
	return result

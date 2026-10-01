extends "res://src/tests/season_second_chance_test.gd"


func _ready() -> void:
	SeasonSave.path = "user://small-batch-%d.json" % OS.get_process_id()
	_capacity_contract()
	var season: SeasonState = _batch_fixture()
	if season != null:
		_persistence(season)
		await _resolution_ui(season)
	_batch_migration()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Small Batch checks passed: capacities, paid career access, discard, saves and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _batch_fixture() -> SeasonState:
	var season: SeasonState = _supply_fixture(["A10", "C03"])
	_check(not SeasonEarnedSponsors.eligible(season.build).has("G02"), "starts locked")
	_check(_supply_result(season), "two completed original types")
	_check(SeasonSave.save(season), "save partial type progress")
	season = SeasonSave.restore()
	_check(
		season != null and SeasonSmallBatch.access(season.career) == ["A10", "C03"],
		"partial replay"
	)
	_check(season.career.close(season), "retain partial on abandonment")
	season = _supply_fixture(["C02"], season.career)
	_check(_supply_result(season), "third original completed")
	_check(SeasonSave.save(season), "sync third type")
	_check(SeasonSmallBatch.access(season.career).size() == 3, "career union of three types")
	_check(season.career.close(season), "retain unlock on abandonment")
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	probe._batch_start = SeasonSmallBatch.TYPES.duplicate()
	probe._supply_start = 3
	probe._visit.number = 3
	for seed_value in range(60000):
		probe._seed = seed_value
		var stock: Array = probe._offers(0).values()
		if not (stock.has("G02") and stock.has("A10") and stock.has("C03")):
			continue
		season = _new_club(seed_value, season.career)
		for game in range(3):
			_result(season, [])
		var build: SeasonBuild = season.build
		_check(build.commit(_command(build, "open")).ok, "open generated batch stock")
		for id: String in ["G02", "A10", "C03"]:
			var fields: Dictionary = {"offer": _offer(build, id)}
			if id == "G02":
				fields["replace"] = ""
			_check(
				(
					build
					. commit(
						_command(build, "sponsor_buy" if id == "G02" else "tactical_buy", fields)
					)
					. ok
				),
				"paid " + id
			)
		_check(build.view().wallet.capacity == {"held": 3, "sponsors": 3}, "paid capacity applies")
		_check(build.commit(_command(build, "leave_shop")).ok, "leave shop")
		# Find a third real supply at the next visit, using paid rerolls when needed.
		_result(season, [])
		build = season.build
		_check(build.commit(_command(build, "open")).ok, "next shop")
		for roll in range(10):
			for offer: String in build.view().shop.offers:
				if SeasonTacticalCatalog.catalog().has(build.view().shop.offers[offer]):
					_check(
						build.commit(_command(build, "tactical_buy", {"offer": offer})).ok,
						"third paid held copy"
					)
					_check(SeasonSave.save(season), "save paid fixture")
					print("BATCH_FIXTURE seed=", seed_value)
					return season
			_check(build.commit(_command(build, "reroll")).ok, "paid reroll for third supply")
		break
	_check(false, "reachable batch stock")
	return null


func _capacity_contract() -> void:
	var build: SeasonBuild = _unit_build([])
	build._batch_start = SeasonSmallBatch.TYPES.duplicate()
	for id: String in ["D01", "J02", "F03"]:
		_check(
			(
				build
				. commit(
					_command(build, "sponsor_buy", {"offer": _unit_offer(build, id), "replace": ""})
				)
				. ok
			),
			"old sponsor"
		)
	var request: Dictionary = _command(
		build, "sponsor_buy", {"offer": _unit_offer(build, "G02"), "replace": ""}
	)
	var before: Dictionary = build.view()
	_check(not build.commit(request).ok and build.view() == before, "fourth rejects atomically")
	request["sales"] = [before.wallet.sponsors[0].id]
	_check(
		build.commit(request).ok and build.view().wallet.sponsors.size() == 3,
		"explicit one-sale resolution"
	)
	_check(build.commit(_hold(build, "A10")).ok, "hold one")
	_check(build.commit(_hold(build, "C03")).ok, "hold two")
	_check(build.commit(_hold(build, "C02")).ok, "hold three")
	var batch: String = SeasonSchoolSponsors.active(build, "G02").id
	_wholesale_discard(build, batch)
	request = _command(build, "sponsor_sell", {"receipt": batch})
	before = build.view()
	_check(not build.commit(request).ok and build.view() == before, "cannot silently overflow")
	request["sales"] = []
	request["discard"] = [before.wallet.held[0].id, before.wallet.held[0].id]
	_check(
		not build.commit(request).ok and build.view() == before,
		"duplicate discard rolls back refund"
	)
	request.discard = [before.wallet.held[0].id]
	_check(build.preview(request).ok and build.view() == before, "review does not destroy copy")
	_check(build.commit(request).ok, "exact explicit discard and sale")
	_check(
		build.cash() == before.wallet.cash + 6 and build.view().wallet.held.size() == 2,
		"six cash and two held"
	)
	_check(build.commit(request).replayed, "retry cannot double refund")
	_check(
		(
			SeasonSmallBatch.combine(
				["A10"], ["A10", SeasonTacticalCatalog.HEAT, SeasonTacticalCatalog.BASE]
			)
			== ["A10"]
		),
		"new supplies never substitute"
	)
	_check(not SeasonSmallBatch.valid(["A10", "A10"]), "no duplicate type evidence")
	# Future base and modifiers: a cap is not a delta; held modifiers remain additive.
	var catalog: Dictionary = SeasonSponsorCatalog.ownership_catalog()
	catalog.D01["sponsor_delta"] = 1
	catalog.F02["held_delta"] = -1
	var bank: SeasonOwnership = SeasonOwnership.new(catalog)
	var state: Dictionary = bank._state.duplicate(true)
	state.sponsors = [{"item": "D01"}, {"item": "G02"}, {"item": "F02"}]
	_check(
		bank._capacity(state) == {"sponsors": 3, "held": 2},
		"hard cap under base six; additive held loss"
	)
	state.sponsors = [{"item": "G02", "id": "b"}, {"item": "J05", "id": "a"}]
	_check(not SeasonSponsorSet.validate_peers(state, catalog).is_empty(), "Association conflict")


func _persistence(season: SeasonState) -> void:
	var exported: Dictionary = season.build.to_data()
	exported.batch_start.clear()
	_check(season.build._batch_start.size() == 3, "serialized progress cannot mutate live build")
	var fork: SeasonBuild = season.build._fork()
	fork._batch_start.clear()
	_check(season.build._batch_start.size() == 3, "fork progress cannot mutate original")
	_check(SeasonSave.save(season), "save batch career")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.build.view() == season.build.view(), "whole build replay")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var detached: SeasonState = SeasonSave._decode(data)
	data.build.batch_start.clear()
	_check(
		detached != null and detached.build._batch_start.size() == 3,
		"decoded progress owns its array"
	)
	data = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.runs[-1].batch_used = ["C02"]
	_check(SeasonSave._decode(data) == null, "reject invented career progress")
	data = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.build.batch_start = ["A10", "C03"]
	_check(SeasonSave._decode(data) == null, "inherited access cannot diverge")


func _resolution_ui(season: SeasonState) -> void:
	var build: SeasonBuild = season.build
	var request: Dictionary = _command(
		build, "sponsor_sell", {"receipt": SeasonSchoolSponsors.active(build, "G02").id}
	)
	var picked: Array = []
	var dialog: SeasonSponsorResolution = SeasonSponsorResolution.open(
		self, build, request, func(value: Dictionary) -> void: picked.append(value)
	)
	await get_tree().process_frame
	_check(dialog.get_ok_button().disabled, "UI requires explicit overflow choice")
	var before: Dictionary = build.view()
	for child: Node in dialog._choices.get_children():
		if child.has_meta("supply_discard"):
			child.button_pressed = true
			break
	_check(
		not dialog.get_ok_button().disabled and build.view() == before,
		"valid preview with no changes"
	)
	dialog._accept()
	await get_tree().process_frame
	_check(
		picked.size() == 1 and picked[0].discard.size() == 1,
		"exact reviewed discard passed to confirmation"
	)


func _batch_migration() -> void:
	var season: SeasonState = _new_club(81)
	season.build._batch_start = null
	season.build._sure_start = null
	season.build._field_start = null
	season.build._format = 31
	season.career.runs[-1].batch_used = null
	season.career.runs[-1].sure_earned = null
	season.career.runs[-1].field_outs = null
	_check(SeasonSave.save(season), "old build serializes")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 12
	data.career.runs[-1].erase("batch_used")
	data.career.runs[-1].erase("sure_earned")
	data.career.runs[-1].erase("field_outs")
	var restored: SeasonState = SeasonSave._decode(data)
	_check(restored != null and restored.build._batch_start == null, "old run prospective only")


func _unit_build(ids: Array) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(112, ROSTER)
	for game in range(8):
		build.commit(_command(build, "reward", {"game": game, "win": true}))
	build.commit(_command(build, "open"))
	for id: String in ids:
		build._visit.offers = {"sponsor": id}
		var extra: Dictionary = {"offer": "sponsor", "replace": ""}
		if id == "J10":
			extra["student"] = ROSTER[0]
		_check(
			build.commit(_command(build, "sponsor_buy", extra)).ok,
			"controlled paid sponsor fixture"
		)
	return build


func _unit_offer(build: SeasonBuild, id: String) -> String:
	var offer: String = "fixture:%d" % build.revision()
	build._visit.offers[offer] = id
	return offer


func _hold(build: SeasonBuild, id: String) -> Dictionary:
	return _command(build, "tactical_buy", {"offer": _unit_offer(build, id)})


func _wholesale_discard(source: SeasonBuild, batch: String) -> void:
	var build: SeasonBuild = source._fork()
	build._visit.offers["pair-a"] = "A07"
	build._visit.offers["pair-b"] = "F02"
	var request: Dictionary = _command(
		build,
		"wholesale",
		{
			"first": {"offer": "pair-a", "replace": batch},
			"second": {"offer": "pair-b", "replace": SeasonSchoolSponsors.active(build, "F03").id},
			"discounted": "pair-b",
			"sales": []
		}
	)
	var before: Dictionary = build.view()
	_check(
		not build.commit(request).ok and build.view() == before,
		"Wholesale cannot overflow held inventory"
	)
	request["discard"] = [before.wallet.held[0].id]
	_check(build.commit(request).ok, "Wholesale exact discard and both purchases atomic")
	_check(
		build.view().wallet.held.size() == 2 and build.view().wallet.sponsors.size() == 3,
		"complete legal Wholesale loadout"
	)
	_check(
		SeasonSchoolSponsors.active(build, "F02").paid == 6,
		"ordinary Wholesale discount receipt retained"
	)

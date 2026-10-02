extends "res://src/tests/season_gear_test.gd"
## Production quotes, refund affordability, blocked input and explicit resolution paths.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	await _quotes()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro shop quote checks passed: prices, refunds, capacity and resolution input.")
	get_tree().quit(0 if _failures == 0 else 1)


func _quotes() -> void:
	var prefix: String = "user://shop-quotes-%d" % OS.get_process_id()
	SeasonSave.path = prefix + ".json"
	PitchBatLabSettings.path = prefix + ".cfg"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(61, true)
	for _pick in range(4):
		app.choose_player(app.season.offers()[0])
	_record(app.season)
	app.season.teams[0].roster = ROSTER.duplicate()
	app.season.build = _two_bats(true)
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	_check(window != null, "completed fixture opens actual shop")
	if window == null:
		app.queue_free()
		return
	var build: SeasonBuild = app.season.build
	var first: String = _gear_offer(build, "bat")
	var second: String = _gear_offer(build, "bat", build.view().shop.offers[first])
	var before: Dictionary = build.to_data()
	build.last_error = "preserved diagnostic"
	window._refresh()
	_check(
		build.to_data() == before and build.last_error == "preserved diagnostic",
		"quotes are read-only"
	)
	var purchase: Button = _gear_button(window, "gear_offer", first)
	_check(
		not purchase.disabled and purchase.get_meta("shop_quote").after.wallet.cash == 8,
		"actual first price"
	)
	await _click(purchase)
	await _click(window._confirm.get_cancel_button())
	_check(build.to_data() == before, "quote and review cancellation retain exact stock and wallet")
	_check(
		build.commit(_command(build, "equip", {"offer": first, "replace": ""})).ok,
		"paid replacement fixture"
	)
	# Controlled wallet values must not insert a service debit outside the build journal.
	build._bank._state.cash = 5
	window._refresh()
	var replacement: Button = _gear_button(window, "gear_offer", second)
	_check(not replacement.disabled, "refund makes replacement affordable at exact boundary")
	_check(
		replacement.get_meta("shop_quote").after.wallet.cash == 0,
		"quote includes exact five-Cash resale"
	)
	await _click(replacement)
	_check(
		window._review_text.text.contains("Cash: 5 → 0"), "final review agrees with inline quote"
	)
	await _click(window._confirm.get_cancel_button())
	await _shop_bounds(window, "quote-refund-affordable")
	build._bank._state.cash = 4
	window._refresh()
	replacement = _gear_button(window, "gear_offer", second)
	_check(replacement.disabled, "unaffordable replacement disabled")
	_check(replacement.get_meta("shop_quote_message").contains("Not enough"), "visible Cash reason")
	before = build.to_data()
	await _click(replacement, false)
	_check(
		not window._confirm.visible and build.to_data() == before,
		"disabled actual input spends nothing"
	)
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "quote-insufficient-cash")
	# Controlled current stock/bag fixtures exercise legal production quoting, without saving them.
	build._visit.offers = {"supply": "A10"}
	build._bank._state.cash = 18
	build._bank._state.held = [
		{"id": "held-one", "item": "A10", "kind": "held", "paid": 3},
		{"id": "held-two", "item": "C03", "kind": "held", "paid": 3}
	]
	window._refresh()
	var supply: Button = _gear_button(window, "tactical_offer", "supply")
	_check(
		supply.disabled and supply.get_meta("shop_quote_message").contains("bag is full"),
		"shared capacity reason"
	)
	# Inspect the blocked card itself rather than the first enabled service below it.
	await _frames()
	window._back.grab_focus()
	window._scroll.scroll_vertical = 0
	await _shop_bounds(window, "quote-supply-full")
	build._bank._state.held.clear()
	window._refresh()
	supply = _gear_button(window, "tactical_offer", "supply")
	_check(
		not supply.disabled and supply.get_meta("shop_quote").after.wallet.cash == 15,
		"capacity refresh unblocks exact price"
	)
	build._visit.offers = {"sponsor": "D01"}
	build._bank._state.cash = 1
	window._refresh()
	var sponsor: Button = _gear_button(window, "sponsor_offer", "sponsor")
	_check(
		not sponsor.disabled and not sponsor.get_meta("shop_quote").ok,
		"Cash shortage retains sponsor-resolution entry"
	)
	before = build.to_data()
	await _click(sponsor)
	var resolution: SeasonSponsorResolution
	for child in window.get_children():
		if child is SeasonSponsorResolution:
			resolution = child
	_check(resolution != null and resolution.visible, "actual input opens explicit sale resolution")
	if resolution != null:
		await _click(resolution.get_cancel_button())
	_check(build.to_data() == before, "resolution cancellation is read-only")
	await _concessions(window)
	app.queue_free()
	await _frames()
	for path: String in [prefix + ".json", prefix + ".cfg"]:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)


func _concessions(window: SeasonShopWindow) -> void:
	var build: SeasonBuild = window.app.season.build
	build._visit.offers = {"training": "development.pitching"}
	build._visit["union_credit"] = 3
	build._bank._state.cash = 2
	build._bank._state.sponsors.append(
		{"id": "student-copy", "item": "J10", "kind": "sponsor", "paid": 6}
	)
	build._scholarships["student-copy"] = {"player": ROSTER[0], "uses": 3}
	var target: Dictionary = build.targets("development.pitching")[0]
	target.player = ROSTER[0]
	var command: Dictionary = window._request("buy", {"offer": "training", "mode": "use"})
	command.merge(target)
	window._refresh()
	window._clear()
	var action: Button = window._purchase("REVIEW CONCESSION", command, "Bullpen Coach")
	_check(
		not action.disabled, "multiple concessions remain an explicit choice even below list price"
	)
	var before: Dictionary = build.to_data()
	await _click(action)
	var student: Button
	var union: Button
	for child in window._body.find_children("*", "Button", true, false):
		if child.get_meta("concession", "") == "scholarship":
			student = child
		elif child.get_meta("concession", "") == "union":
			union = child
	_check(student != null and union != null, "both concession routes shown")
	if student != null and union != null:
		_check(
			not student.disabled and union.disabled,
			"individual quotes distinguish payable two from unaffordable three"
		)
		await _shop_bounds(window, "quote-concession-choice")
		await _click(student)
		_check(
			window._review_text.text.contains("Cash: 2 → 0"),
			"chosen concession reaches exact final review"
		)
		await _click(window._confirm.get_cancel_button())
	_check(build.to_data() == before, "concession selection and cancellation consume no allowance")

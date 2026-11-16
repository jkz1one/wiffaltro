extends Node
## Headless shipped-control assertions only, not native visual/feel acceptance.
## Draft is a real closed Scramble draft. Shop funding below is explicitly a
## synthetic completed-game Build fixture; no Season save or app commit occurs.

const ROOT_SEED: int = 443
var checks: int = 0
var failures: int = 0


func _ready() -> void:
	var rules: Dictionary = LeagueRules.capture("scramble", 0, ROOT_SEED)
	# Do not add the app: its _ready would restore an unrelated user's save.
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.create_closed_league(ROOT_SEED, rules, true)
	_check(app.season != null, "closed Scramble draft exists")
	if app.season == null:
		app.free()
		get_tree().quit(1)
		return
	var menu: SeasonMenu = SeasonMenu.new()
	app.menu = menu
	add_child(menu)
	menu.build(app)
	menu.show_draft()
	await _frames()
	var offered: Array[String] = app.season.offers()
	var before: Dictionary = app.season.build.to_data()
	for player_id: String in offered:
		var card: Control = _player_card(menu._body, player_id)
		_check(card != null, "actual draft card identifies exact offered player")
		if card == null:
			continue
		var stats: Dictionary = SeasonScramble.profile(player_id, rules).stats
		var bars: Array[Node] = card.find_children("*", "ProgressBar", true, false)
		_check(bars.size() == 4, "actual draft shows four league ratings")
		for index in range(mini(bars.size(), 4)):
			_check(
				int(bars[index].value) == stats[SeasonPlayerCatalog.STATS[index]],
				"actual draft bar equals transformed " + SeasonPlayerCatalog.STATS[index]
			)
		var name_button: Button = card.get_child(0)
		name_button.pressed.emit()
		await _frames()
		_check(
			menu.draft_selection == player_id and app.season.build.to_data() == before,
			"actual draft selection updates selected identity without training or mutating build"
		)
	# Complete actual domain draft without invoking app saves or claiming played games.
	for pick in range(4):
		_check(app.season.choose_player(app.season.offers()[0]), "closed draft choice accepted")
	var drafted: SeasonBuild = app.season.build
	var generated: SeasonBuild = null
	for shop_seed in range(64):
		var candidate: SeasonBuild = SeasonBuild.new(
			shop_seed, drafted._initial_roster, drafted._pool, drafted._blocked
		)
		_check(
			candidate.enable_league_rules(rules), "generated UI shop uses same root-season context"
		)
		for game in range(2):
			_check(
				candidate.commit(_command(candidate, "reward", {"game": game, "win": true})).ok,
				"synthetic completed-game reward funds display-only UI fixture"
			)
		_check(candidate.commit(_command(candidate, "open")).ok, "open generated early UI shop")
		if not candidate.view().shop.recruit.is_empty():
			generated = candidate
			break
	_check(generated != null, "generated eligible actual recruit UI fixture")
	if generated == null:
		menu.queue_free()
		app.free()
		await _frames()
		get_tree().quit(1)
		return
	app.season.build = generated
	var offer: Dictionary = generated.view().shop.recruit
	var state: Dictionary = generated.to_data()
	var window: SeasonShopWindow = SeasonShopWindow.new()
	window.app = app
	add_child(window)
	window.popup_centered()
	await _frames()
	_check(
		_text(window._body).contains("%d Cash" % offer.price),
		"actual recruit card shows full authored fee"
	)
	_assert_ratings(
		_player_card(window._body, offer.player), offer.profile.stats, "generated recruit card"
	)
	var review: Button = _button(window._body, "REVIEW RECRUIT REPLACEMENT")
	_check(review != null, "actual recruit review control exists")
	if review != null:
		review.pressed.emit()
		await _frames()
		_assert_ratings(
			_player_card(window._body, offer.player),
			offer.profile.stats,
			"incoming comparison card"
		)
		var replace: Button = _replacement(window._body, drafted.roster()[0])
		_check(
			replace != null and replace.has_meta("shop_quote"),
			"actual replacement exposes generated quote"
		)
		if replace != null and replace.has_meta("shop_quote"):
			var quote: Dictionary = replace.get_meta("shop_quote")
			var command: Dictionary = replace.get_meta("shop_command")
			_check(
				(
					quote.ok
					and not replace.disabled
					and quote.after.wallet.cash == generated.cash() - offer.price
				),
				"actual replacement quote charges the exact generated full price"
			)
			_check(
				(
					command.op == "sign"
					and command.offer == offer.id
					and command.replace == drafted.roster()[0]
				),
				"actual quote binds exact recruit and departing identity"
			)
			replace.pressed.emit()
			await _frames()
			_check(
				window._confirm.visible and window._pending == command,
				"actual replacement control reaches exact final review"
			)
			_check(
				window._review_text.text.contains(
					"Cash: %d → %d" % [generated.cash(), generated.cash() - offer.price]
				),
				"actual review agrees with displayed recruit price"
			)
			window._confirm.canceled.emit()
			window._confirm.hide()
			_check(
				window._pending.is_empty() and generated.to_data() == state,
				"actual cancellation preserves synthetic ledger and all transformed profiles"
			)
	_check(
		generated.player(offer.player) == SeasonScramble.profile(offer.player, rules),
		"review never silently signs or applies catchup"
	)
	window.queue_free()
	menu.queue_free()
	app.free()
	await _frames()
	await TestAudioDrain.finish(get_tree())
	print("Scramble headless draft/recruit UI checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _assert_ratings(card: Control, stats: Dictionary, label: String) -> void:
	_check(card != null, label + " identifies actual player")
	if card == null:
		return
	var grids: Array[Node] = card.find_children("*", "GridContainer", true, false)
	_check(
		grids.size() == 1 and grids[0].get_child_count() == 8,
		label + " has four exact rating labels"
	)
	if grids.size() != 1 or grids[0].get_child_count() != 8:
		return
	for index in range(4):
		var value: Label = grids[0].get_child(index + 4)
		_check(
			value.text == str(stats[SeasonPlayerCatalog.STATS[index]]),
			label + " actual " + SeasonPlayerCatalog.STATS[index] + " value"
		)


func _player_card(root: Node, player_id: String) -> Control:
	for node: Node in root.find_children("*", "Button", true, false):
		if node.get_meta("inspect_player", "") == player_id:
			return node.get_parent()
	return null


func _button(root: Node, label: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if node.text == label:
			return node
	return null


func _replacement(root: Node, player_id: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if node.get_meta("recruit_replace", "") == player_id:
			return node
	return null


func _command(build: SeasonBuild, operation: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"id": "scramble-ui:%d" % build.revision(), "rev": build.revision(), "op": operation
	}
	result.merge(fields)
	return result


func _text(node: Node) -> String:
	var result: String = ""
	if node is Label or node is Button:
		result += node.text + "\n"
	for child: Node in node.get_children():
		result += _text(child)
	return result


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

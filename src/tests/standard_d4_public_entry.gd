extends "res://src/tests/standard_d4_lifecycle.gd"
## Public D4 entry only, with the accepted authored eligibility helpers.
## The prior titles are synthetic structural fixtures, never newly earned credit.
## Four ordinary picks expose all six rule contexts; no physical game is started.

var _gardens_confirmed: int = 0


func _ready() -> void:
	var selectors: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--d4-entry-case="):
			selectors.append(argument)
	if not selectors.is_empty():
		if selectors != ["--d4-entry-case=gardens-night"]:
			_check(false, "closed Gardens selector refuses unsupported or repeated values")
			get_tree().quit(1)
			return
		await _gardens_ready()
		return
	var original_path: String = SeasonSave.path
	var original_error: String = SeasonSave.last_error
	SeasonSave.path = "user://standard-d4-public-entry-%d.json" % OS.get_process_id()
	_cleanup()
	_check(ClubCareer.D4_PUBLIC_ACTIVATION_ENABLED, "public D4 activation is enabled")
	_prefix = _synthetic_prefix("champion")
	var prefix_ready: bool = (
		_prefix != null
		and _prefix.current == 0
		and _prefix.runs.size() == 4
		and _prefix.cleared(3)
		and not _prefix.cleared(4)
	)
	_check(
		prefix_ready,
		"validated authored prior-title prefix is structural eligibility, not earned credit"
	)
	if prefix_ready:
		var app: SeasonApp = SeasonApp.new()
		add_child(app)
		app.set_process(false)
		app.season = _legacy_prefix(_prefix)
		await _entry_menu(app)
		_entry_refusals(app)
		_public_draft(app)
		app.queue_free()
		await get_tree().process_frame
	_cleanup()
	_check(_entry_files().is_empty(), "isolated primary, backup and temporary saves are cleaned")
	SeasonSave.path = original_path
	SeasonSave.last_error = original_error
	await TestAudioDrain.finish(get_tree())
	print(
		(
			(
				"STANDARD_D4_PUBLIC_ENTRY checks=%d failures=%d synthetic_history=true "
				+ "physical_games=0 public_activation=true"
			)
			% [_checks, _failures]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("STANDARD_D4_PUBLIC_ENTRY: " + label)


func _legacy_prefix(club: ClubCareer) -> SeasonState:
	# A genuine legacy container has no build, so current0 close/sync is valid.
	var previous: SeasonState = SeasonState.create(13)
	previous.career = club.fork()
	return previous


func _entry_files() -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SeasonSave.path + suffix):
			result[suffix] = FileAccess.get_file_as_string(SeasonSave.path + suffix)
	return result


func _entry_menu(app: SeasonApp) -> void:
	var previous: SeasonState = app.season
	var before: Dictionary = SeasonSave.snapshot(previous).duplicate(true)
	var career_before: Dictionary = previous.career.to_data().duplicate(true)
	var files_before: Dictionary = _entry_files()
	ClubCareerUI.show(app.menu)
	var entry: Button = null
	var count: int = 0
	for button: Button in app.menu._body.find_children("*", "Button", true, false):
		if button.text == "NEW STANDARD/d4 SEASON":
			entry = button as Button
			count += 1
	_check(
		count == 1 and entry != null and not entry.disabled,
		"validated d3 title exposes exactly one enabled public D4 menu button"
	)
	var text: String = ""
	for label: Label in app.menu._body.find_children("*", "Label", true, false):
		text += str(label.text) + "\n"
	_check(
		(
			text.contains("Working d4 rewards: 42 • 78 • 114 • 216.")
			and text.contains("Standard/d4 is available")
			and not text.contains("public entry held")
			and not text.contains("public entry is held")
		),
		"club record truthfully shows Working D4 availability"
	)
	if entry != null:
		entry.pressed.emit()
	_check(
		(
			app._dialog.visible
			and app._dialog.dialog_text.contains("Standard d4 (Working)")
			and app._dialog.dialog_text.contains("1 Backyard, 0 Expanded, 2 Club, 2 Mogul")
			and app._dialog.dialog_text.contains("two completed games")
			and app._dialog.dialog_text.contains("half paid")
			and app._dialog.dialog_text.contains("0 Cash")
			and app._dialog.dialog_text.contains("42/78/114/216")
			and app._dialog.dialog_text.contains("Grandstand Gardens III, 19:10, Clear")
		),
		"normal menu request opens exact Working D4 confirmation terms"
	)
	_check(
		(
			not before.is_empty()
			and app.season == previous
			and ClubCareer.same(before, SeasonSave.snapshot(previous))
			and ClubCareer.same(career_before, previous.career.to_data())
			and ClubCareer.same(files_before, _entry_files())
		),
		"asking changes no live state or save files"
	)
	app._dialog.get_cancel_button().pressed.emit()
	await get_tree().process_frame
	_check(
		(
			not app._dialog.visible
			and app.season == previous
			and ClubCareer.same(before, SeasonSave.snapshot(previous))
			and ClubCareer.same(career_before, previous.career.to_data())
			and ClubCareer.same(files_before, _entry_files())
		),
		"real Cancel preserves identity, state and save files"
	)


func _entry_refusals(app: SeasonApp) -> void:
	# A valid existing checkpoint makes refusal cover preservation as well as no new writes.
	_check(
		SeasonSave.save(app.season) and FileAccess.file_exists(SeasonSave.path),
		"valid authored legacy checkpoint exists before negative public-entry tests"
	)
	for prior_count: int in [0, 1, 2, 3]:
		var club: ClubCareer = _prefix.fork()
		club.runs.resize(prior_count)
		club._assets = {}
		var validated: ClubCareer = ClubCareer.from_data(club.to_data())
		if validated == null:
			_check(false, "missing-title fixture did not validate")
			continue
		_refuse_entry(
			app,
			validated,
			4,
			true,
			true,
			"Could not start another career season.",
			"prior title count %d cannot unlock d4" % prior_count
		)
	var forged: ClubCareer = _prefix.fork()
	forged.runs[3].receipt.total += 1
	# Regenerate disposable assets so the malformed receipt reaches career.start validation.
	forged._assets = {}
	_refuse_entry(
		app,
		forged,
		4,
		true,
		true,
		"Could not start another career season.",
		"malformed prior receipt cannot enter D4"
	)
	for tier: int in [-1, 5]:
		_refuse_entry(
			app,
			_prefix,
			tier,
			true,
			true,
			"That Standard tier is unavailable.",
			"unsupported public tier %d refuses" % tier
		)
	_refuse_entry(
		app,
		_prefix,
		4,
		false,
		true,
		"That Standard tier is unavailable.",
		"non-Working D4 entry refuses"
	)
	_refuse_entry(
		app,
		_prefix,
		4,
		true,
		false,
		"That Standard tier is unavailable.",
		"incomplete-boundary D4 entry refuses"
	)


func _refuse_entry(
	app: SeasonApp,
	club: ClubCareer,
	tier: int,
	working: bool,
	complete_boundary: bool,
	expected_notice: String,
	label: String
) -> void:
	app.season = _legacy_prefix(club)
	var previous: SeasonState = app.season
	var career_before: Dictionary = previous.career.to_data().duplicate(true)
	var before: Dictionary = SeasonSave.snapshot(previous).duplicate(true)
	var files_before: Dictionary = _entry_files()
	app.begin_season(6, working, true, true, complete_boundary, true, tier)
	_check(
		(
			app.season == previous
			and previous.build == null
			and previous.career.current == 0
			and app.notice.begins_with(expected_notice)
			and ClubCareer.same(career_before, previous.career.to_data())
			and ClubCareer.same(before, SeasonSave.snapshot(previous))
			and ClubCareer.same(files_before, _entry_files())
		),
		label + " without identity/state/file mutation"
	)


func _public_draft(app: SeasonApp) -> void:
	app.season = _legacy_prefix(_prefix)
	var previous: SeasonState = app.season
	var before: Dictionary = SeasonSave.snapshot(previous).duplicate(true)
	var prefix_before: Dictionary = _prefix.to_data().duplicate(true)
	var balance: int = previous.career.balance()
	app.begin_season(6, true, true, true, true, true, 4)
	var season: SeasonState = app.season
	_check(
		(
			season != null
			and season != previous
			and season.phase == SeasonState.Phase.DRAFT
			and season.picks.is_empty()
			and season.career != null
			and season.career.active_tier() == 4
			and season.build != null
			and season.opponents != null
			and season.physical != null
			and app.menu.page == "draft"
			and app.notice.contains("Standard d4 (Working)")
			and app.notice.contains("Frozen away parks")
		),
		"normal public begin_season commits a new D4 Draft"
	)
	if (
		season == null
		or season == previous
		or season.career == null
		or season.build == null
		or season.opponents == null
		or season.physical == null
	):
		return
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(previous))
			and ClubCareer.same(prefix_before, _prefix.to_data())
			and ClubCareer.same(prefix_before.runs, season.career.runs.slice(0, 4))
			and season.career.runs.size() == 5
			and season.career.current == 5
			and season.career.runs[-1].status == "active"
			and season.career.runs[-1].receipt.is_empty()
			and season.career.balance() == balance
			and not season.career.cleared(4)
		),
		"new Draft preserves authored prefix and balance without granting a D4 title or reward"
	)
	var data: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	_check(
		(
			data.get("version") == 71
			and data.get("career", {}).get("version") == 26
			and data.get("build", {}).get("version") == 44
			and data.get("draft_rule") == SeasonOpponentDraft.D2_RULE
			and data.get("sponsor_rule") == SeasonSponsorCatalog.D4_RULE
			and data.get("opponents", {}).get("policy") == 13
			and data.get("opponents", {}).get("draft_rule") == SeasonOpponentDraft.D2_RULE
		),
		"public Draft uses exact Save71, Career26, Build44 and shared D4/d2 contexts"
	)
	if data.is_empty():
		return
	_check(
		(
			_entry_build(season.build, 0)
			and season.build.revision() == 0
			and season.opponents.clubs.is_empty()
			and season.opponents.draft_order.is_empty()
		),
		"human rules and shared AI creation context are installed before pick1; no premature AI events"
	)
	var final_before: Dictionary = season.final_venue.duplicate(true)
	var away_before: Dictionary = season.npc_venues.duplicate(true)
	var expected_final: Dictionary = SeasonFinalVenue.capture_grand_iii_time(6, 5, "night")
	expected_final.selection = SeasonFinalVenue.STANDARD_D4_SELECTION
	_check(
		(
			not final_before.is_empty()
			and final_before.get("version") == 4
			and final_before.get("selection") == SeasonFinalVenue.STANDARD_D4_SELECTION
			and final_before.get("venue_owner") == SeasonFinalVenue.GRAND_III_OWNER
			and SeasonFinalVenue.matches_season(season)
			and ClubCareer.same(final_before, expected_final)
		),
		"ordinary D4 freezes exact Grand III record before drafting"
	)
	_check(
		(
			away_before.get("venue_ordinal") == 4
			and away_before.get("assignments", {}).size() == 5
			and ClubCareer.same(away_before, SeasonVenues.capture_five(6, 5, 4))
		),
		"ordinary D4 freezes exact ordinal4 five-club away assignment"
	)
	_entry_cold(season, "pick0")
	for pick: int in range(4):
		if season.offers().is_empty():
			_check(false, "ordinary public draft offers unexpectedly empty")
			return
		var offered: String = season.offers()[0]
		app.choose_player(offered)
		_check(
			season.picks.size() == pick + 1 and season.picks[pick] == offered,
			"ordinary public draft pick%d commits" % (pick + 1)
		)
	_check(_entry_build(season.build, 0), "human retains exact D4 context after pick4")
	for owner: String in SeasonVenues.OWNERS:
		var opponent: Dictionary = season.opponents.clubs.get(owner, {})
		_check(
			(
				opponent.get("build") is SeasonBuild
				and _entry_build(opponent.build, 12)
				and opponent.build.revision() == 0
				and opponent.cursor == 0
				and opponent.decisions.is_empty()
			),
			"AI club %s receives exact D4/Ownership3 and inherited pricing before any game" % owner
		)
	_check(
		(
			ClubCareer.same(final_before, season.final_venue)
			and ClubCareer.same(away_before, season.npc_venues)
			and season.results.is_empty()
			and season.player_results.is_empty()
			and season.physical.reports.is_empty()
			and season.physical.pending.is_empty()
			and app.lab == null
			and season.career.balance() == balance
			and not season.career.cleared(4)
		),
		"four picks retain frozen venues and create no game, physical report, payout or D4 title"
	)
	_entry_cold(season, "pick4")
	_final_guard(season)


func _entry_build(build: SeasonBuild, market: int) -> bool:
	return (
		build != null
		and build._format == 44
		and build._market == market
		and build.d1_pricing_valid()
		and build.d4_sponsors_valid()
		and not build.d3_sponsors_valid()
		and _bank_context(build, 3)
	)


func _entry_cold(season: SeasonState, label: String) -> void:
	var data: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	var files_before: Dictionary = _entry_files()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	_check(
		not data.is_empty() and parsed is Dictionary and ClubCareer.same(data, parsed),
		label + " native save bytes retain the whole full-precision snapshot"
	)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			restored != null
			and restored != season
			and SeasonSave.last_error.is_empty()
			and ClubCareer.same(data, SeasonSave.snapshot(restored))
			and ClubCareer.same(files_before, _entry_files())
		),
		label + " cold native restore preserves whole parsed canonical state without file mutation"
	)


func _gardens_ready() -> void:
	var original_path: String = SeasonSave.path
	var original_error: String = SeasonSave.last_error
	SeasonSave.path = "user://standard-d4-gardens-default-%d.json" % OS.get_process_id()
	_cleanup()
	_check(
		ClubCareer.D4_PUBLIC_ACTIVATION_ENABLED and StadiumSurfaceNightSnapshot.PUBLIC_READY,
		"normal D4 and independent owned-home profile entry are public"
	)
	_prefix = _synthetic_prefix("champion")
	var prefix_ready: bool = (
		_prefix != null
		and _prefix.current == 0
		and _prefix.runs.size() == 4
		and _prefix.cleared(3)
		and not _prefix.cleared(4)
	)
	_check(
		prefix_ready,
		"existing four-title structural eligibility validates without new earned history"
	)
	if prefix_ready:
		var app: SeasonApp = SeasonApp.new()
		add_child(app)
		app.set_process(false)
		app.season = _legacy_prefix(_prefix)
		app._dialog.confirmed.connect(func() -> void: _gardens_confirmed += 1)
		await _entry_menu(app)  # Five existing checks, including actual Cancel and no state writes.
		await _gardens_entry(app)
		app.queue_free()
		await get_tree().process_frame
	_cleanup()
	var cleaned: bool = _entry_files().is_empty()
	SeasonSave.path = original_path
	SeasonSave.last_error = original_error
	_check(
		cleaned and SeasonSave.path == original_path and SeasonSave.last_error == original_error,
		"isolated generated files are cleaned and save globals restored"
	)
	await TestAudioDrain.finish(get_tree())
	print(
		(
			(
				"STANDARD_D4_PUBLIC_ENTRY checks=%d failures=%d synthetic_history=true "
				+ "physical_games=0 public_activation=true"
			)
			% [_checks, _failures]
		)
	)
	print(
		(
			(
				"STANDARD_D4_GARDENS_DEFAULT checks=%d failures=%d confirmations=%d current_picks=0 "
				+ "physical_games=0 purchases=0 images=0 combined_paid_home_d4=false "
				+ "legacy_codec_projection=true"
			)
			% [_checks, _failures, _gardens_confirmed]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _gardens_entry(app: SeasonApp) -> void:
	var previous: SeasonState = app.season
	var before: Dictionary = SeasonSave.snapshot(previous).duplicate(true)
	var prefix_before: Dictionary = _prefix.to_data().duplicate(true)
	var files_before: Dictionary = _entry_files()
	var balance: int = previous.career.balance()
	var entries: Array[Button] = []
	for node: Node in app.menu._body.find_children("*", "Button", true, false):
		if node is Button and node.text == "NEW STANDARD/d4 SEASON":
			entries.append(node)
	if entries.size() == 1 and not entries[0].disabled:
		entries[0].pressed.emit()
	var choices: Array[OptionButton] = []
	for node: Node in app._dialog.find_children("*", "OptionButton", true, false):
		if node is OptionButton and not node.is_queued_for_deletion():
			choices.append(node)
	var reopened: bool = (
		entries.size() == 1
		and not entries[0].disabled
		and app._dialog.visible
		and choices.size() == 1
		and choices[0].selected == 0
		and choices[0].item_count == 3
		and choices[0].get_item_text(0) == "Day · 13:10"
		and choices[0].get_item_text(1) == "Sunset · 16:10 (paid four-pole field required)"
		and choices[0].get_item_text(2) == "Night · 19:10 (paid four-pole field required)"
		and _gardens_confirmed == 0
		and app.season == previous
		and ClubCareer.same(before, SeasonSave.snapshot(previous))
		and ClubCareer.same(files_before, _entry_files())
	)
	_check(reopened, "actual D4 menu reopens one unchanged default-Day confirmation")
	if not reopened:
		return
	app._dialog.get_ok_button().pressed.emit()
	await get_tree().process_frame
	var season: SeasonState = app.season
	var entered: bool = (
		season != null
		and season != previous
		and season.career != null
		and season.build != null
		and season.opponents != null
		and season.physical != null
		and season.phase == SeasonState.Phase.DRAFT
		and season.picks.is_empty()
		and season.career.active_tier() == 4
		and app.menu.page == "draft"
		and app.lab == null
		and season.owned_surface_night.is_empty()
		and _gardens_confirmed == 1
		and not app._dialog.visible
	)
	_check(entered, "actual OK signal starts normal unlit-Day D4 Draft without a game")
	if not entered:
		return
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(previous))
			and ClubCareer.same(prefix_before, _prefix.to_data())
			and ClubCareer.same(prefix_before.runs, season.career.runs.slice(0, 4))
			and season.career.runs.size() == 5
			and season.career.current == 5
			and season.career.runs[-1].status == "active"
			and season.career.runs[-1].receipt.is_empty()
			and season.career.balance() == balance
			and not season.career.cleared(4)
			and season.results.is_empty()
			and season.player_results.is_empty()
			and season.physical.reports.is_empty()
			and season.physical.pending.is_empty()
		),
		"normal entry preserves prior identity/history/balance and grants no current reward/result/title"
	)
	var data: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	_check(
		(
			data.get("version") == 71
			and data.get("career", {}).get("version") == 26
			and data.get("build", {}).get("version") == 44
			and _entry_build(season.build, 0)
			and data.get("draft_rule") == SeasonOpponentDraft.D2_RULE
			and data.get("sponsor_rule") == SeasonSponsorCatalog.D4_RULE
			and data.get("opponents", {}).get("policy") == 13
		),
		"unlit Day retains ordinary Save71/Career26/Build44 and D4 rule context"
	)
	if data.is_empty():
		return
	var expected: Dictionary = SeasonFinalVenue.capture_grand_iii_time(
		season.season_seed, season.career.current, "night"
	)
	if not expected.is_empty():
		expected.selection = SeasonFinalVenue.STANDARD_D4_SELECTION
	var environment: Dictionary = season.final_venue.get("environment", {})
	_check(
		(
			not expected.is_empty()
			and season.final_venue.get("version") == 4
			and SeasonFinalVenue.matches_season(season)
			and ClubCareer.same(season.final_venue, expected)
			and environment.get("version") == 8
			and environment.get("mode") == "night"
			and environment.get("profile") == "GRAND-III-TIME-NIGHT-v2"
			and environment.get("start_minute") == 1150
			and environment.get("render_profile") == 3
			and environment.get("rule") == StadiumSurfaceNightSnapshot.CLOCK_RULE
			and ClubCareer.same(
				season.npc_venues,
				SeasonVenues.capture_five(season.season_seed, season.career.current, 4)
			)
		),
		"ordinary D4 captures true-Night Gardens and unchanged ordinal4 away assignment before picks"
	)
	_entry_cold(season, "normal Gardens Night pick0")  # Two canonical no-write cold checks.
	# Structural old-save projection only: no mutation/migration of the live candidate or its history.
	var legacy_data: Dictionary = data.duplicate(true)
	var legacy_final: Dictionary = SeasonFinalVenue.capture_grand_iii(
		season.season_seed, season.career.current
	)
	if not legacy_final.is_empty():
		legacy_final.selection = SeasonFinalVenue.STANDARD_D4_SELECTION
	legacy_data.final_venue = legacy_final
	var checkpoint: Dictionary = _entry_files()
	var legacy: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(legacy_data, "", true, true))
	)
	_check(
		(
			not legacy_final.is_empty()
			and legacy_final.environment.version == 5
			and legacy != null
			and ClubCareer.same(SeasonSave.snapshot(legacy), legacy_data)
			and ClubCareer.same(legacy.final_venue, legacy_final)
			and SeasonFinalVenue.matches_season(legacy)
			and ClubCareer.same(SeasonSave.snapshot(season), data)
			and ClubCareer.same(checkpoint, _entry_files())
		),
		"labeled env5 codec projection stays exact without altering live env8 or checkpoint bytes"
	)

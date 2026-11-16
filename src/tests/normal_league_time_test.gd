extends "res://src/tests/season_same_save_night_test.gd"
## Prepared save/authority controls only. Retained funding is synthetic history.
## No physical games, installed runtime, optical or release qualification.
const NormalTime = preload("res://src/gameplay/season/normal_league_time_candidate.gd")
const NormalHome = preload("res://src/gameplay/season/normal_league_home.gd")


func _ready() -> void:
	if OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") != "1" or not StadiumNpcPublicRuntime.source_qualified():
		print("NORMAL_TIME94_REFUSED: exact reviewed source and serialized launcher are required")
		get_tree().quit(2)
		return
	var root: String = ""
	var funding: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--normal-time-root="):
			root = argument.trim_prefix("--normal-time-root=")
		if argument.begins_with("--funding-input="):
			funding = true
	if not funding or not root.is_absolute_path() or DirAccess.dir_exists_absolute(root):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	SeasonSave._dynasty_owner_path = ""
	SeasonSave.path = root.path_join("funding.json")
	var source: SeasonState = _retained_funding()
	_check(source != null, "retained synthetic funding decodes")
	if source != null:
		var paid: ClubAssetLedger = ClubPlayers.assets(source.career) \
			if OS.get_cmdline_user_args().has("--prepared-fixture") else _public_purchases(source)
		_check(paid != null and NormalTime.supported_home(StadiumLayoutSnapshot.capture(paid, true)),
			"exact publicly paid12 fixture")
		if paid != null:
			for mode: String in ["fixed_night", "day", "sunset", "night"]:
				_time_case(source, mode, root)
			_controller(source, root)
			_standard_freeze(source, root)
			_floodlight_land(source, root)
	_unlit()
	print("NORMAL_TIME94 checks=%d failures=%d physical_games=0 synthetic_funding=true" % [_checks, _failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _ordinary(source: SeasonState, seed_value: int = 94401) -> SeasonState:
	var club: ClubCareer = source.career.fork()
	if not club.close(source):
		return null
	var season: SeasonState = SeasonState.create_closed_league(seed_value, LeagueRules.capture("dugout"), true)
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(club)) or not club.start_league(season) \
		or not NormalHome.prepare(season):
		return null
	return season


func _time_case(source: SeasonState, mode: String, root: String) -> void:
	print("NORMAL_TIME94_PHASE mode=", mode, " checks=", _checks, " failures=", _failures)
	SeasonSave.path = root.path_join(mode + ".json")
	var ordinary: SeasonState = _ordinary(source)
	_check(ordinary != null, "independent Career27 starts " + mode)
	if ordinary == null:
		return
	var before: Dictionary = SeasonSave.snapshot(ordinary)
	var prepared: Dictionary = NormalTime.prepare(ordinary, mode)
	_check(not prepared.is_empty() and NormalTime.current(ordinary, prepared), "exact pristine94 " + mode)
	_check(ClubCareer.same(before, SeasonSave.snapshot(ordinary)), "preparation leaves93 unchanged " + mode)
	if prepared.is_empty():
		return
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(JSON.stringify(prepared, "", true, true)))
	_check(season != null, "canonical full94 decode " + mode)
	if season == null:
		return
	_check(ClubCareer.same(SeasonSave.snapshot(season), prepared), "exact94 capture " + mode)
	_check(season._dynasty_career_session.is_empty() and season._dynasty_owner_binding.is_empty()
		and season.career != null and season.league_career and season._npc_replay_run == season.career.current,
		"only ordinary Career27 run authority " + mode)
	_negative_envelopes(prepared)
	var fixture: Dictionary = season.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
	var property: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
	_check(property.get("version") == (26 if mode == "fixed_night" else 27), "exact fixture26/27 " + mode)
	_check(property.get("binding", {}).get("run_id") == season.career.current, "fixture run binding " + mode)
	_check(SeasonSave.save(season), "durable initial94 " + mode)
	var career: ClubCareer = season.career
	_check(SeasonSave.save(season) and season.career == career, "equal94 save retains runtime career identity " + mode)
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	DirAccess.make_dir_absolute(SeasonSave.path + ".tmp")
	_check(not SeasonSave.save(season) and season.career == career
		and FileAccess.get_file_as_string(SeasonSave.path) == bytes, "failed94 publication is unchanged " + mode)
	DirAccess.remove_absolute(SeasonSave.path + ".tmp")
	_check(SeasonSave.save(season), "exact94 publication retry " + mode)
	if mode == "night":
		season = SeasonSave.restore()
		_check(season != null and season._pool_replay_ledger != null, "restore94 before live Apply recapture")
		if season == null:
			return
		_recapture(season)
	_check(season.choose_player(season.offers()[0]), "first pick94 " + mode)
	_check(not NormalTime.recapture(season, season.home_property), "first pick locks home and policy " + mode)
	_locked_transactions(season, "first pick " + mode)
	_check(NormalTime.prepare(season, mode).is_empty(), "admission cannot reset a drafted run " + mode)
	for index in range(3):
		_check(season.choose_player(season.offers()[0]), "remaining pick94 " + mode)
	_check(SeasonInventoryRules.enable(season), "inventory94 " + mode)
	_check(SeasonSave.save(season), "drafted94 save " + mode)
	var cold: SeasonState = SeasonSave.restore()
	_check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(season)), "drafted94 cold exact " + mode)
	var request: Dictionary = PhysicalRoundProcess.request_for(season, "time94", "time94-key", 1)
	_check(request.get("version") == 1 and not request.has("owner")
		and PhysicalRoundProcess.decode_request(request, "time94") != null, "ordinary transport1 " + mode)
	var fork: SeasonState = SeasonRoundSettlement._fork_replayed_state(season)
	_check(fork != null and fork.career != season.career
		and ClubCareer.same(fork.career.to_data(), season.career.to_data())
		and ClubCareer.same(fork.owned_surface_night, season.owned_surface_night), "94 projection carries independent Career27 and policy " + mode)


func _negative_envelopes(value: Dictionary) -> void:
	_check(SeasonSave._decode(value.checkpoint) == null, "stripped94 fails historical grammar")
	for key: String in ["family", "starting_profile", "owned_surface_night", "home_property"]:
		var bad: Dictionary = value.duplicate(true)
		bad.erase(key)
		_check(SeasonSave._decode(bad) == null, "missing immutable field " + key)
	var bad: Dictionary = value.duplicate(true)
	bad.extra = true
	_check(SeasonSave._decode(bad) == null, "extra94 field refuses")
	bad = value.duplicate(true)
	bad.version = 93
	_check(SeasonSave._decode(bad) == null, "old93 cannot accept94 authority")
	bad = value.duplicate(true)
	bad.owned_surface_night.run_id += 1
	NormalTime._closed(bad.checkpoint).normal_time_home = NormalTime.header_key(bad)
	_check(SeasonSave._decode(bad) == null, "rehashed wrong run still refuses")
	bad = value.duplicate(true)
	bad.owned_surface_night.season_seed += 1
	NormalTime._closed(bad.checkpoint).normal_time_home = NormalTime.header_key(bad)
	_check(SeasonSave._decode(bad) == null, "rehashed wrong policy seed still refuses")
	bad = value.duplicate(true)
	bad.starting_profile = "sunset" if value.starting_profile != "sunset" else "night"
	NormalTime._closed(bad.checkpoint).normal_time_home = NormalTime.header_key(bad)
	_check(SeasonSave._decode(bad) == null, "rehashed mismatched named profile refuses")
	for version: int in [13, 17, 43, 44, 45, 46, 47]:
		bad = value.home_property.duplicate(true)
		bad.layout.version = version
		_check(not NormalTime.supported_home(bad), "unqualified family stays closed " + str(version))


func _recapture(season: SeasonState) -> void:
	var retired: ClubAssetLedger = season._pool_replay_ledger
	var retired_bytes: String = JSON.stringify(retired.to_data(), "", true, true)
	var frozen: Dictionary = season.home_property.duplicate(true)
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(NormalTime.workshop_editable(season), "exact94 pre-pick transaction exception")
	var unlit: Dictionary = frozen.layout.duplicate(true)
	unlit.lights.clear()
	_check(ClubConstruction.save_draft(season, unlit, paid.revision()).get("ok", false), "stage legal day-only edit")
	paid = ClubPlayers.assets(season.career)
	var revision: int = paid.revision()
	_check(ClubConstruction.apply_admission(season, unlit, true).get("ok", false),
		"94 Apply passes old blanket freeze before unsupported-profile validation")
	var before: Dictionary = _transaction_state(season)
	var refused: Dictionary = ClubConstruction.apply_draft(season, unlit, revision)
	_check(not refused.get("ok", false) and refused.get("error", "").begins_with("This updated field is not supported"),
		"actual Apply reaches recapture then refuses loss of selected profile")
	_unchanged(season, before, "unsupported Apply")
	# A real supported change, not only another Apply of unchanged bytes: exchange
	# two already-paid light copies while preserving all four qualified sites.
	var changed: Dictionary = frozen.layout.duplicate(true)
	var copy: String = changed.lights[0].copy
	changed.lights[0].copy = changed.lights[1].copy
	changed.lights[1].copy = copy
	_check(ClubConstruction.save_draft(season, changed, revision).get("ok", false), "stage changed exact supported lighting")
	revision = ClubPlayers.assets(season.career).revision()
	_check(ClubConstruction.apply_admission(season, changed, true).get("ok", false), "actual supported Apply admitted")
	before = _transaction_state(season)
	DirAccess.make_dir_absolute(SeasonSave.path + ".tmp")
	SeasonSave.last_error = ""
	var failed: Dictionary = ClubConstruction.apply_draft(season, changed, revision)
	_check(not failed.get("ok", false) and not SeasonSave.last_error.is_empty()
		and failed.get("error") == SeasonSave.last_error, "supported Apply reaches failed durable write")
	DirAccess.remove_absolute(SeasonSave.path + ".tmp")
	_unchanged(season, before, "failed supported Apply")
	var applied: Dictionary = ClubConstruction.apply_draft(season, changed, revision)
	_check(applied.get("ok", false) and not applied.get("replayed", true), "same supported Apply retry commits")
	_check(season.home_property.revision > frozen.revision
		and ClubCareer.same(season.home_property.layout, changed)
		and not ClubCareer.same(season.home_property.layout, frozen.layout)
		and ClubPlayers.assets(season.career).revision() == revision + 1,
		"actual changed paid layout publishes once")
	_live_recapture(season, retired, retired_bytes, "restored94 changed Apply")
	_current_cold(season, "changed supported Apply")
	_check(SeasonSave.save(season), "prime exact supported Apply retry files")
	before = _transaction_state(season)
	_check(ClubConstruction.apply_draft(season, changed, revision).get("replayed", false), "same successful Apply retry is idempotent")
	_unchanged(season, before, "idempotent Apply", false)
	# Expanded is the ONLY qualified four-pole tier. The next paid tier is a
	# valid ledger command but cannot retain this chosen Night composition.
	before = _transaction_state(season)
	paid = ClubPlayers.assets(season.career)
	var club_probe: ClubCareer = season.career.fork()
	var command: Dictionary = _land_command(club_probe, "club", paid.revision())
	_check(ClubPlayers.command(club_probe, command).get("ok", false), "unsupported94 land has affordable valid paid command")
	refused = ClubConstruction.buy_land(season, "club", paid.revision())
	_check(not refused.get("ok", false) and refused.get("error", "").begins_with("This updated field is not supported"),
		"actual land reaches recapture and refuses unsupported four-pole tier")
	_unchanged(season, before, "unsupported land")
	before = _transaction_state(season)
	refused = ClubConstruction.clear_salvage(season, paid.revision())
	_check(not refused.get("ok", false) and refused.get("error") == "This club has no starter junk car to clear.",
		"actual94 clearance reaches ledger and refuses absent car without manufacturing origin")
	_unchanged(season, before, "unsupported clearance")
	_guard_controls(season)


func _transaction_state(season: SeasonState) -> Dictionary:
	var raw: Dictionary = {
		"career": season.career.to_data(), "home": season.home_property,
		"policy": season.owned_surface_night, "context": season._league_home_context,
		"pool": season._pool_replay_ledger.to_data() if season._pool_replay_ledger != null else {},
		"phase": season.phase, "picks": season.picks, "results": season.results,
		"player_results": season.player_results,
		"pending": season.physical.pending if season.physical != null else {},
		"reports": season.physical.reports if season.physical != null else [],
		"cursor": season.physical.cursor if season.physical != null else -1
	}
	var files: Dictionary = {}
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = SeasonSave.path + suffix
		files[suffix] = {"exists": FileAccess.file_exists(path),
			"directory": DirAccess.dir_exists_absolute(path),
			"sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return {"career": season.career, "pool": season._pool_replay_ledger,
		"raw": JSON.stringify(raw, "", true, true), "files": files}


func _unchanged(season: SeasonState, before: Dictionary, label: String, identity: bool = true) -> void:
	var after: Dictionary = _transaction_state(season)
	_check((not identity or (season.career == before.career and season._pool_replay_ledger == before.pool))
		and after.raw == before.raw
		and ClubCareer.same(after.files, before.files),
		label + " preserves owner values balance revision pins and primary/backup/temp bytes")


func _live_recapture(season: SeasonState, retired: ClubAssetLedger, retired_bytes: String, label: String) -> void:
	# Inspect the SAME live season immediately after publication, BEFORE reload.
	# A cold decode alone would hide an omitted replay-ledger assignment.
	var current: ClubAssetLedger = ClubPlayers.assets(season.career)
	var lookup: ClubAssetLedger = StadiumSurfaceNightSnapshot.ledger(season)
	_check(lookup != null and lookup == season._pool_replay_ledger and lookup != retired
		and StadiumSurfaceNightHumanEvidence.ledger(season) == lookup
		and ClubCareer.same(lookup.to_data(), current.to_data()),
		label + " live policy/evidence lookup receives the newly paid ledger")
	_check(retired != null and JSON.stringify(retired.to_data(), "", true, true) == retired_bytes
		and not StadiumLayoutSnapshot.matches(season.home_property, retired)
		and not StadiumSurfaceNightSnapshot.valid_policy(season.owned_surface_night, season, retired),
		label + " retired cold-load ledger stays unchanged and cannot authorize the new home")
	var scheduled: Dictionary = season.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
	var property: Dictionary = StadiumLayoutSnapshot.for_fixture(season, scheduled)
	var proof: Dictionary = StadiumSurfaceNightSnapshot.proof(property, season.owned_surface_night, lookup)
	_check(not property.is_empty() and not proof.is_empty()
		and StadiumSurfaceNightSnapshot.valid_policy(season.owned_surface_night, season, lookup)
		and StadiumSurfaceNightSnapshot.matches_fixture(property, season, scheduled, lookup)
		and StadiumSurfaceNightSnapshot.proof_valid(proof, property),
		label + " same-instance fixture and runtime-entry proof validate before a second reload")
	season._pool_replay_ledger = retired
	_check(StadiumLayoutSnapshot.for_fixture(season, scheduled).is_empty(),
		label + " omitted-publication control rejects the stale replay ledger")
	season._pool_replay_ledger = lookup
	_check(ClubCareer.same(StadiumLayoutSnapshot.for_fixture(season, scheduled), property),
		label + " original live publication restores the same exact fixture")


func _current_cold(season: SeasonState, label: String) -> void:
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(ClubCareer.same(season.home_property, StadiumLayoutSnapshot.capture(paid, true))
		and season.owned_surface_night.entry_key == StadiumLayoutSnapshot.key(season.home_property)
		and ClubCareer.same(season.home_property, season._league_home_context.header.home_property)
		and ClubCareer.same(season.owned_surface_night, season._league_home_context.header.owned_surface_night)
		and NormalTime.matches(season), label + " binds exact current paid home and unchanged chosen policy")
	var cold: SeasonState = SeasonSave.restore()
	_check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(season)),
		label + " cold replays exact94")


func _locked_transactions(season: SeasonState, label: String) -> void:
	var before: Dictionary = _transaction_state(season)
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(not NormalTime.workshop_editable(season)
		and not ClubConstruction.apply_draft(season, season.home_property.layout, paid.revision()).get("ok", false)
		and not ClubConstruction.buy_land(season, StadiumLand.next_tier(paid.view().land), paid.revision()).get("ok", false)
		and not ClubConstruction.clear_salvage(season, paid.revision()).get("ok", false),
		label + " closes all actual transactions")
	_unchanged(season, before, label)


func _guard_controls(season: SeasonState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season)
	for condition: String in ["pending", "reports", "cursor", "results", "player_results", "policy", "home", "context"]:
		var probe: SeasonState = SeasonSave._decode(saved)
		if probe == null:
			_check(false, "guard control source decodes")
			return
		match condition:
			"pending": probe.physical.pending = {"unpublished": true}
			"reports": probe.physical.reports.append({"unpublished": true})
			"cursor": probe.physical.cursor = 1
			"results": probe.results.append({"unpublished": true})
			"player_results": probe.player_results.append({"unpublished": true})
			"policy": probe.owned_surface_night.run_id += 1
			"home": probe.home_property.revision += 1
			"context": probe._league_home_context.header = {"version": 94}
		_locked_transactions(probe, "94 " + condition + " lock")


func _standard_freeze(source: SeasonState, root: String) -> void:
	SeasonSave.path = root.path_join("standard-freeze.json")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.set_process(false)
	app.season = source
	app.begin_surface_time_season("night", 94404, 0)
	_check(app.season != null and app.season != source
		and app.season._league_home_context.is_empty() and not app.season.owned_surface_night.is_empty(),
		"actual original Standard Night starts separately")
	if app.season != null and app.season != source:
		_locked_transactions(app.season, "original Standard Night freeze")
	app.free()


func _land_command(club: ClubCareer, tier: String, revision: int) -> Dictionary:
	return {"id": "stadium-land:%d" % revision, "rev": revision, "op": "stadium_land",
		"tier": tier, "price_version": StadiumLand.VERSION,
		"through": ClubPlayers.income_through(club),
		"progress_through": StadiumCareerProgress.capture(club).size()}


func _floodlight_land(source: SeasonState, root: String) -> void:
	print("NORMAL_TIME94_PHASE paid25 checks=", _checks, " failures=", _failures)
	# Authored, isolated prerequisite history from one retained Standard proof.
	# These repeated rows are synthetic funding, not played or earned progress.
	# The retained input, its history, and its paid journal are never modified.
	var original: String = JSON.stringify(SeasonSave.snapshot(source), "", true, true)
	var row: Dictionary = {}
	for prior: Dictionary in source.career.runs:
		if prior.league == "standard" and prior.tier == 0 and prior.status == "completed" \
			and prior.receipt.get("finish") == "champion":
			row = prior
			break
	_check(not row.is_empty(), "retained synthetic Standard operand for paid25 funding")
	if row.is_empty():
		return
	var history: Array[Dictionary] = []
	for index in range(50):
		history.append({"id": index + 1, "seed": row.seed, "league": "standard", "tier": 0,
			"status": "completed", "proof": row.proof.duplicate(true),
			"receipt": ClubSeasonRecord.receipt(row.proof, index == 0, 0)})
	var club: ClubCareer = ClubCareer.from_data({"version": 1, "current": 0, "runs": history})
	_check(club != null, "synthetic50 funding passes original full career validation")
	if club == null:
		return
	var commands: Array[Dictionary] = [
		{"op": "stadium_land", "tier": "expanded", "price_version": StadiumLand.VERSION},
		{"op": "stadium_land", "tier": "club", "price_version": StadiumLand.VERSION},
		{"op": "stadium_buy", "item": "ST-038", "quantity": 4, "price_version": StadiumFloodlightOwnedItems.PRICE_VERSION},
		{"op": "stadium_style", "item": "ST-063b", "price_version": StadiumFieldStyles.VERSION},
		{"op": "stadium_style", "item": "ST-063i", "price_version": StadiumGroundStyles.PRICE_VERSION}
	]
	for command: Dictionary in commands:
		var revision: int = ClubPlayers.assets(club).revision()
		command.merge({"id": "synthetic25-setup:%d" % revision, "rev": revision,
			"through": ClubPlayers.income_through(club), "progress_through": StadiumCareerProgress.capture(club).size()})
		var purchased: Dictionary = ClubPlayers.command(club, command)
		_check(purchased.get("ok", false), "synthetic25 real priced setup " + command.op)
		if not purchased.get("ok", false):
			return
	var paid: ClubAssetLedger = ClubPlayers.assets(club)
	var layout: Dictionary = StadiumFloodlightOwnedItems.upgrade(paid.view().stadium_active, paid.surface_owned())
	layout.surface = {"foundation": "grass", "condition": "prepared", "height": "short"}
	layout.styles = {"grass": "ST-063b", "line": ""}
	layout.ground = "ST-063i"
	layout = StadiumFloodlightOwnedItems.select_preset(layout, paid.construction(), "CLUB4-LOW")
	for operation: String in ["stadium_draft", "stadium_apply"]:
		var revision: int = ClubPlayers.assets(club).revision()
		var command: Dictionary = {"id": "synthetic25-setup:%d" % revision, "rev": revision,
			"op": operation, "layout": layout.duplicate(true)}
		if operation == "stadium_apply":
			command.geometry = StadiumOwnedLayout.geometry("club", layout)
		var result: Dictionary = ClubPlayers.command(club, command)
		_check(result.get("ok", false), "synthetic25 paid fixture " + operation)
		if not result.get("ok", false):
			return
	var ordinary: SeasonState = SeasonState.create_closed_league(94405, LeagueRules.capture("dugout"), true)
	_check(ClubPlayerDraft.apply(ordinary, ClubPlayers.owned(club)) and club.start_league(ordinary)
		and NormalHome.prepare(ordinary), "paid25 ordinary93 source admitted")
	for mode: String in ["fixed_night", "day", "sunset", "night"]:
		SeasonSave.path = root.path_join("land25-" + mode + ".json")
		var season: SeasonState = NormalTime.admit(ordinary, mode)
		_check(season != null, "paid25 full94 " + mode)
		if season == null:
			continue
		_check(SeasonSave.save(season), "paid25 initial save " + mode)
		season = SeasonSave.restore()
		_check(season != null and season._pool_replay_ledger != null, "restore94 before live land recapture " + mode)
		if season == null:
			continue
		var retired: ClubAssetLedger = season._pool_replay_ledger
		var retired_bytes: String = JSON.stringify(retired.to_data(), "", true, true)
		paid = ClubPlayers.assets(season.career)
		var revision: int = paid.revision()
		var balance: int = paid.balance()
		var before: Dictionary = _transaction_state(season)
		var fork: ClubCareer = season.career.fork()
		_check(ClubPlayers.command(fork, _land_command(fork, "mogul", revision)).get("ok", false),
			"paid25 affordable next-tier command " + mode)
		DirAccess.make_dir_absolute(SeasonSave.path + ".tmp")
		SeasonSave.last_error = ""
		var failed: Dictionary = ClubConstruction.buy_land(season, "mogul", revision)
		_check(not failed.get("ok", false) and not SeasonSave.last_error.is_empty()
			and failed.get("error") == SeasonSave.last_error, "actual supported land reaches failed write " + mode)
		DirAccess.remove_absolute(SeasonSave.path + ".tmp")
		_unchanged(season, before, "failed supported land " + mode)
		var bought: Dictionary = ClubConstruction.buy_land(season, "mogul", revision)
		_check(bought.get("ok", false) and not bought.get("replayed", true), "actual supported land retry commits " + mode)
		paid = ClubPlayers.assets(season.career)
		_check(paid.revision() == revision + 1 and paid.balance() == balance - StadiumCatalog.LAND.mogul.price
			and season.home_property.tier == "mogul"
			and season._league_home_context.header.starting_profile == mode,
			"land debit revision and unchanged selected profile commit together " + mode)
		_live_recapture(season, retired, retired_bytes, "restored94 paid25 land " + mode)
		_current_cold(season, "paid25 land " + mode)
		_check(SeasonSave.save(season), "prime exact land retry files " + mode)
		before = _transaction_state(season)
		_check(ClubConstruction.buy_land(season, "mogul", revision).get("replayed", false), "same land retry cannot charge twice " + mode)
		_unchanged(season, before, "idempotent land " + mode, false)
	_check(JSON.stringify(SeasonSave.snapshot(source), "", true, true) == original,
		"synthetic25 fixture leaves retained source and paid journal unchanged")


func _controller(source: SeasonState, root: String) -> void:
	SeasonSave.path = root.path_join("chooser.json")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.set_process(false)
	app.season = source
	_check(app.league_career.prepare("dugout", 94402), "actual controller prepares ordinary93")
	var old_ticket: int = app.league_career.token()
	_check(app.league_career.starting_profile(old_ticket, "night"), "actual controller chooses explicit94 Night")
	_check(not app.league_career.commit(old_ticket), "stale93 review cannot commit new94 choice")
	var ticket: int = app.league_career.token()
	_check(app.league_career.candidate() != null and app.league_career.candidate()._league_home_context.format == 94,
		"candidate94 retained after stale callback")
	_check(app.league_career.cancel(ticket) and app.season == source
		and not FileAccess.file_exists(SeasonSave.path), "cancel94 leaves source and absent disk")
	_check(not app.league_career.starting_profile(ticket, "day"), "stale cancelled profile callback refuses")
	_check(not NormalTime.ENTRY_ENABLED, "unqualified public chooser controls disabled")
	app.free()


func _unlit() -> void:
	var club: ClubCareer = ClubCareer.new()
	var season: SeasonState = SeasonState.create_closed_league(94403, LeagueRules.capture("dugout"), true)
	_check(ClubPlayerDraft.apply(season, ClubPlayers.owned(club)) and club.start_league(season)
		and NormalHome.prepare(season), "unlit ordinary93 retained")
	for mode: String in ["fixed_night", "day", "sunset", "night"]:
		_check(NormalTime.prepare(season, mode).is_empty(), "unlit cannot manufacture94 " + mode)

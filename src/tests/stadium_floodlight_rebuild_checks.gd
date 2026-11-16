extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One shared owned floodlight qualification. Explicit synthetic funding, zero games.

const PHASE_CHECKS: Array[int] = [506, 76, 42]
const PHASE_CONFIGS: Array = [[0], [1, 2], [3]]
const PHASE_LABELS: Array[String] = [
	"club-sparse", "club-two-lower-canopies", "mogul-standard", "mogul-premium" ]
var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Dictionary = {}
var _configs: Array[Dictionary] = []
var _night_results: Array = []
var _captures: Dictionary = {}
var _optical: Dictionary = {}
var _occlusion: Dictionary = {}
var _geometry_checks: int = 0
var _ownership_checks: int = 0
var _night_checks: Array[int] = []
var _capture_checks: int = 0

var _part: int = 0
var _prior_checks: int = 0
var _prior_receipts: Array = []
var _input_dir: String = ""
var _input_tiles: Dictionary = {}
var _predecessor: Dictionary = {}
var _phase_started_ms: int = 0


func _check(ok: bool, message: String) -> void:
	if not ok:
		print( ( "FLOODLIGHT_REBUILD_FAILURE " + JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true ) ) )
	super._check(ok, message)


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_phase_started_ms = Time.get_ticks_msec()
	var input_sha: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--floodlight-phase="):
			var value: String = argument.trim_prefix("--floodlight-phase=")
			_part = value.to_int() if value in ["1", "2", "3"] else 0
		elif argument.begins_with("--floodlight-input-dir="):
			_input_dir = argument.trim_prefix("--floodlight-input-dir=")
		elif argument.begins_with("--floodlight-input-sha256="):
			input_sha = argument.trim_prefix("--floodlight-input-sha256=")
	if OS.get_cmdline_user_args().has("--floodlight-live-comparison"):
		return await _run_live_comparison(directory, input_sha)
	if _part < 1 or _part > 3:
		_check(false, "exact authorized floodlight phase is required")
		return {"checks": _checks, "failures": _failures}
	if _part == 1:
		_check( DisplayServer.get_name() != "headless" and not directory.is_empty(),
			"rendered shared floodlight qualification has explicit output directory" )
		if _failures == 0:
			_check( DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens" )
			_stage("shared-start")
			var before: int = _checks
			_ownership()
			_ownership_checks = _checks - before
			await _profile_cancel()
			if _configs.size() == 4:
				_phase = "bounded-floodlight-geometry"
				var root: Node3D = _world()
				before = _checks
				await StadiumFloodlightGeometryRebuildChecks.run(root, _check)
				_geometry_checks = _checks - before
				_check( _geometry_checks == StadiumFloodlightGeometryRebuildChecks.expected_checks(),
					"all source-derived geometry checks reached" )
				await _close_view()
			_stage("shared-complete")
	else:
		# Prior positive checks remain owned by their exact earlier process receipts.
		# These bounded input/I/O checks add failures only; they never claim repeated coverage.
		if ( DisplayServer.get_name() == "headless" or directory.is_empty()
			or DirAccess.make_dir_recursive_absolute(directory) != OK or not _load_previous(input_sha) ):
			_check(false, "exact prior phase bootstrap and view hashes are required")
	if _failures == 0 and _configs.size() == 4:
		for index: int in PHASE_CONFIGS[_part - 1]:
			var config: Dictionary = _configs[index]
			_phase = "night:" + config.label
			_stage(config.label + ":start")
			var root: Node3D = _world()
			var cold: ClubAssetLedger = ClubAssetLedger.from_data(
				JSON.parse_string(JSON.stringify(config.journal)), 91, _credits, _progress )
			_check( cold != null and StadiumLayoutSnapshot.matches(config.snapshot, cold),
				"runtime starts from exact cold configuration prefix" )
			var before: int = _checks
			var capture_before: int = _capture_checks
			var result: Dictionary = await StadiumFloodlightNightRebuildChecks.run(
				root, _check, cold, config, _collect_capture )
			var reached: int = _checks - before - (_capture_checks - capture_before)
			_night_checks.append(reached)
			_night_results.append(result)
			_check( reached == StadiumFloodlightNightRebuildChecks.expected_checks(config),
				"all finite runtime and policy checks reached" )
			await _close_view()
			_stage(config.label + ":complete")
	if _part == 3:
		_montages()
		_phase = "completion"
		_check( _images == ["floodlight-overview.png", "floodlight-night-views.png"],
			"exact two shared originals cover all owned alternatives and actionable night views" )
	var tiles: Array = _save_tiles()
	var bootstrap_sha: String = _save_bootstrap()
	var filename: String = (
		"floodlight-rebuild.json" if _part == 3 else "floodlight-phase%d.json" % _part )
	var file: FileAccess = FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
	if _part == 3:
		_check(file != null, "finite shared floodlight evidence opens")
	elif file == null:
		_check(false, "intermediate phase evidence opens")
	if _checks != PHASE_CHECKS[_part - 1]:
		_check(false, "exact source-derived phase check count reached")
	var receipts: Array = _prior_receipts.duplicate(true)
	receipts.append({"phase": _part, "checks": _checks, "failures": _failures})
	var payload: Dictionary = { "schema": 2, "phase": _part, "checks": _checks,
		"unique_checks": _prior_checks + _checks, "phase_receipts": receipts, "predecessor": _predecessor,
		"bootstrap_sha256": bootstrap_sha, "fixture_sha256":
		FileAccess.get_sha256("res://src/tests/stadium_floodlight_rebuild_checks.gd"), "tiles": tiles,
		"failures": _failures, "images": _images, "geometry_checks": _geometry_checks,
		"ownership_checks": _ownership_checks, "night_checks": _night_checks, "paid_copy_ids": _copies,
		"configurations": _configs.map( func(row: Dictionary) -> Dictionary: return { "label": row.label,
					"profile": row.profile, "layout": row.layout, "snapshot": row.snapshot } ),
		"night_results": _night_results, "optical": _optical, "occlusion": _occlusion,
		"phase_elapsed_ms": Time.get_ticks_msec() - _phase_started_ms, "games": 0,
		"synthetic_funding": true, "synthetic_fixture_cursor": true, "earned_career_claim": false,
		"full_season_save_resume_claim": false, "whole_game_acceptance_claim": false,
		"final_art_acceptance_claim": false }
	if file != null:
		var serialized: String = JSON.stringify(payload, "", true, true)
		if serialized.to_utf8_buffer().size() > 131072:
			_check(false, "phase evidence retains the exact existing byte cap")
		else:
			file.store_string(serialized)
			file.flush()
			if file.get_error() != OK:
				_check(false, "shared floodlight evidence fully writes")
		file.close()
	print( ( ( "FLOODLIGHT_REBUILD phase=%d checks=%d unique_checks=%d failures=%d images=%d games=0 "
				+ "synthetic_funding=true" )
			% [_part, _checks, _prior_checks + _checks, _failures, _images.size()] ) )
	return {"checks": _checks, "failures": _failures}


func _stage(label: String) -> void:
	print( ( "FLOODLIGHT_PHASE_STAGE " + JSON.stringify( { "phase": _part, "stage": label,
					"elapsed_ms": Time.get_ticks_msec() - _phase_started_ms }, "", true, true ) ) )


func _read_phase_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > 131072:
		file.close()
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}


func _load_previous(expected_sha: String) -> bool:
	var filename: String = "floodlight-phase%d.json" % (_part - 1)
	var path: String = _input_dir.path_join(filename)
	if ( _input_dir.is_empty() or expected_sha.length() != 64
		or FileAccess.get_sha256(path) != expected_sha ):
		return false
	var previous: Dictionary = _read_phase_json(path)
	if ( previous.get("schema") != 2 or previous.get("phase") != _part - 1
		or previous.get("checks") != PHASE_CHECKS[_part - 2] or previous.get("failures") != 0 or (
			previous.get("fixture_sha256")
			!= FileAccess.get_sha256("res://src/tests/stadium_floodlight_rebuild_checks.gd") ) ):
		return false
	var expected_unique: int = 506 if _part == 2 else 582
	var completed: int = 1 if _part == 2 else 3
	if ( previous.get("unique_checks") != expected_unique
		or not previous.get("phase_receipts") is Array or previous.phase_receipts.size() != _part - 1
		or not previous.get("night_results") is Array or previous.night_results.size() != completed
		or not previous.get("night_checks") is Array or previous.night_checks.size() != completed
		or not previous.get("tiles") is Array or previous.tiles.size() != completed * 2 ):
		return false
	for index in range(_part - 1):
		var receipt: Variant = previous.phase_receipts[index]
		if ( not receipt is Dictionary or receipt.get("phase") != index + 1
			or receipt.get("checks") != PHASE_CHECKS[index] or receipt.get("failures") != 0 ):
			return false
	var bootstrap_path: String = _input_dir.path_join("floodlight-bootstrap.json")
	if FileAccess.get_sha256(bootstrap_path) != previous.get("bootstrap_sha256"):
		return false
	var bootstrap: Dictionary = _read_phase_json(bootstrap_path)
	return _floodlight_previous_bootstrap_checks(
		expected_sha, filename, previous, expected_unique, completed, bootstrap )


func _floodlight_previous_bootstrap_checks(
	expected_sha: String, filename: String, previous: Dictionary, expected_unique: int,
	completed: int, bootstrap: Dictionary ) -> bool:
	if ( bootstrap.get("schema") != 1 or bootstrap.get("fixture_sha256") != previous.fixture_sha256
		or not bootstrap.get("credits") is Array or not bootstrap.get("progress") is Array
		or not bootstrap.get("configurations") is Array or bootstrap.configurations.size() != 4
		or not bootstrap.get("paid_copy_ids") is Dictionary ):
		return false
	for index in range(4):
		var config: Variant = bootstrap.configurations[index]
		if ( not config is Dictionary or config.get("label") != PHASE_LABELS[index]
			or not config.get("journal") is Dictionary or not config.get("snapshot") is Dictionary ):
			return false
	for index in range(completed):
		if ( not previous.night_results[index] is Dictionary
			or previous.night_results[index].get("label") != PHASE_LABELS[index] ):
			return false
	return _floodlight_previous_completion_checks(
		expected_sha, filename, previous, expected_unique, completed, bootstrap )


func _floodlight_previous_completion_checks(
	expected_sha: String, filename: String, previous: Dictionary, expected_unique: int,
	completed: int, bootstrap: Dictionary ) -> bool:
	for tile: Variant in previous.tiles:
		if ( not tile is Dictionary or not tile.get("key") is String or not tile.get("file") is String
			or not tile.get("sha256") is String or tile.get("width") != 1280 or tile.get("height") != 720 ):
			return false
		var valid_key: bool = false
		for index in range(completed):
			for tag: String in ["overview", "batting"]:
				valid_key = valid_key or tile.key == PHASE_LABELS[index] + ":" + tag
		if ( not valid_key or _input_tiles.has(tile.key) or tile.file != _tile_filename(tile.key)
			or FileAccess.get_sha256(_input_dir.path_join(tile.file)) != tile.sha256 ):
			return false
		var captured: Image = Image.load_from_file(_input_dir.path_join(tile.file))
		if captured == null or captured.is_empty() or captured.get_size() != SIZE:
			return false
		_captures[tile.key] = captured
		_input_tiles[tile.key] = tile.duplicate(true)
	_credits = bootstrap.credits.duplicate(true)
	_progress = bootstrap.progress.duplicate(true)
	_copies = bootstrap.paid_copy_ids.duplicate(true)
	_configs.assign(bootstrap.configurations)
	_geometry_checks = int(previous.geometry_checks)
	_ownership_checks = int(previous.ownership_checks)
	_night_checks.assign(previous.night_checks)
	_night_results = previous.night_results.duplicate(true)
	_optical = previous.optical.duplicate(true)
	_occlusion = previous.occlusion.duplicate(true)
	_prior_checks = expected_unique
	_prior_receipts = previous.phase_receipts.duplicate(true)
	_predecessor = {"phase": _part - 1, "file": filename, "sha256": expected_sha}
	return true


func _save_bootstrap() -> String:
	var path: String = _capture_dir.path_join("floodlight-bootstrap.json")
	if _part > 1:
		if DirAccess.copy_absolute(_input_dir.path_join("floodlight-bootstrap.json"), path) != OK:
			_check(false, "exact bootstrap bytes copied forward")
			return ""
	else:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_check(false, "finite paid bootstrap opens")
			return ""
		var value: Dictionary = { "schema": 1, "fixture_sha256":
			FileAccess.get_sha256("res://src/tests/stadium_floodlight_rebuild_checks.gd"),
			"credits": _credits, "progress": _progress, "paid_copy_ids": _copies, "configurations": _configs
		}
		var serialized: String = JSON.stringify(value, "", true, true)
		if serialized.to_utf8_buffer().size() > 131072:
			_check(false, "paid bootstrap retains the exact existing byte cap")
		else:
			file.store_string(serialized)
			file.flush()
			if file.get_error() != OK:
				_check(false, "finite paid bootstrap fully writes")
		file.close()
	return FileAccess.get_sha256(path)


static func _tile_filename(key: String) -> String:
	return "floodlight-tile-" + key.replace(":", "-") + ".png"


func _save_tiles() -> Array:
	var result: Array = []
	for index in range(_configs.size()):
		for tag: String in ["overview", "batting"]:
			var key: String = _configs[index].label + ":" + tag
			if not _captures.has(key):
				continue
			var filename: String = _tile_filename(key)
			var path: String = _capture_dir.path_join(filename)
			var error: Error = OK
			if _input_tiles.has(key):
				error = DirAccess.copy_absolute(_input_dir.path_join(filename), path)
			else:
				error = _captures[key].save_png(path)
			if error != OK:
				_check(false, "exact native phase tile persists " + key)
				continue
			var digest: String = FileAccess.get_sha256(path)
			if _input_tiles.has(key) and digest != _input_tiles[key].sha256:
				_check(false, "prior native tile bytes remain exact " + key)
			result.append( {"key": key, "file": filename, "sha256": digest, "width": 1280, "height": 720} )
	return result


func _buy(item: String, quantity: int, price: int) -> void:
	var revision: int = _paid.revision()
	var entry: Dictionary = StadiumCatalog.item(item)
	var cost: int = ( (0 if _paid.construction().blueprints.has(item) else int(entry.blueprint_price))
		+ int(entry.copy_price) * quantity )
	var balance: int = _paid.balance()
	var command: Dictionary = { "id": "floodlight-buy:%d" % revision, "rev": revision,
		"op": "stadium_buy", "item": item, "quantity": quantity, "price_version": price,
		"through": _credits.size(), "progress_through": _progress.size() }
	var result: Dictionary = _paid.commit(command)
	_operands = {"item": item, "quantity": quantity, "cost": cost, "error": result.get("error", "")}
	_check( result.ok and _paid.balance() == balance - cost,
		"unchanged blueprint and exact-copy cost " + item )
	_check( _paid.commit(command).get("replayed", false) and _paid.balance() == balance - cost,
		"purchase replay neither charges nor grants again " + item )
	if not _copies.has(item):
		_copies[item] = []
	for index in range(quantity):
		_copies[item].append("purchase:floodlight-buy:%d:%d" % [revision, index])


func _paid_command(command: Dictionary) -> void:
	command.id = "floodlight-paid:%d" % _paid.revision()
	command.rev = _paid.revision()
	command.through = _credits.size()
	if command.op != "stadium_surface":
		command.progress_through = _progress.size()
	var preview: Dictionary = _paid.preview(command)
	var result: Dictionary = _paid.commit(command)
	_operands = {"command": command, "error": result.get("error", "")}
	_check( preview.ok and result.ok and _paid.balance() == preview.get("balance_after", -1),
		"ordinary paid land/surface/style command" )


func _apply(layout: Dictionary) -> bool:
	var balance: int = _paid.balance()
	var draft: Dictionary = _paid.commit( { "id": "floodlight-draft:%d" % _paid.revision(),
			"rev": _paid.revision(), "op": "stadium_draft", "layout": layout } )
	if not draft.ok:
		_operands = {"stage": "draft", "error": draft.get("error", "")}
		return false
	var applied: Dictionary = _paid.commit( { "id": "floodlight-apply:%d" % _paid.revision(),
			"rev": _paid.revision(), "op": "stadium_apply", "layout": layout,
			"geometry": StadiumHomeLayout.geometry(_paid.view().land, layout) } )
	_operands = {"stage": "apply", "error": applied.get("error", "")}
	return applied.ok and _paid.balance() == balance


func _ownership() -> void:
	_phase = "paid-stock-presets-cold-and-night-eligibility"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5, "strikeouts": 5})
	_paid = ClubAssetLedger.new_club(91, _credits, _progress)
	var old_entry: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(_paid.construction().copies.size() == 3, "floodlights grant no starter copies")
	for item: String in ["ST-038", "ST-076"]:
		var gate: Dictionary = StadiumCatalog.item(item).requires
		_check( not ( StadiumFloodlightOwnedItems . quote( _paid.construction(), item, 1, "locked",
					{"seasons": int(gate.seasons) - 1, "wins": int(gate.wins)} ) . ok ),
			"unchanged career gate stays locked " + item )
	_buy("ST-038", 3, StadiumFloodlightOwnedItems.PRICE_VERSION)
	var partial_stock: StadiumStock = _paid.construction()
	_buy("ST-038", 3, StadiumFloodlightOwnedItems.PRICE_VERSION)
	_buy("ST-076", 4, StadiumFloodlightOwnedItems.PRICE_VERSION)
	_buy("ST-029", 2, StadiumStraightItems.PRICE_VERSION)
	_buy("ST-053", 2, StadiumRoofItems.PRICE_VERSION)
	_buy("ST-037", 4, StadiumPurchases.LIGHT_VERSION)
	_check( ( _paid.construction().copies.size() == 21
			and _paid.to_data().version == ClubAssetLedger.FLOODLIGHT_VERSION ),
		"ledger33 contains exactly eighteen paid copies and three historical starters" )
	_check( StadiumLayoutSnapshot.matches(old_entry, _paid),
		"old entry remains bound to its unchanged paid prefix" )
	_paid_command({"op": "stadium_land", "tier": "expanded", "price_version": StadiumLand.VERSION})
	for item: String in ["grass", "ground_prep"]:
		_paid_command( { "op": "stadium_surface", "item": item,
				"price_version": StadiumSurfaceProgression.VERSION } )
	_paid_command(
		{"op": "stadium_style", "item": "ST-063b", "price_version": StadiumFieldStyles.VERSION} )
	_paid_command( { "op": "stadium_style", "item": "ST-063i",
			"price_version": StadiumGroundStyles.PRICE_VERSION } )
	var yard: Dictionary = _paid.view().stadium_active
	yard.surface = {"foundation": "grass", "condition": "prepared", "height": "short"}
	yard.styles = {"grass": "ST-063b", "line": ""}
	yard.ground = "ST-063i"
	var yard_sites: Array = StadiumYardLightModels.SITES.keys()
	yard_sites.sort()
	for index in range(4):
		yard.lights.append({"copy": _copies["ST-037"][index], "site": yard_sites[index]})
	_check(_apply(yard), "ordinary historical four-pole layout applies")
	var yard_candidate: Dictionary = StadiumSurfaceNightLayout.capture(_paid)
	_check( ( not yard_candidate.is_empty() and yard_candidate.candidate_version == 1
			and StadiumSurfaceNightLayout.valid(yard_candidate, _paid) ),
		"candidate1 yard qualification stays on its original family" )
	_check( ( ( StadiumSurfaceNightSnapshot.signature_for(yard_candidate.get("entry", {}))
				== StadiumSurfaceNightSnapshot.signature() ) and (
				StadiumSurfaceNightSnapshot.time_signature_for(yard_candidate.get("entry", {}))
				== StadiumSurfaceNightSnapshot.time_signature() ) ),
		"yard night and shared-clock signatures stay on their original identity" )
	yard.lights = []
	_check(_apply(yard), "all four yard poles return to exact owned storage")
	_paid_command({"op": "stadium_land", "tier": "club", "price_version": StadiumLand.VERSION})
	var base: Dictionary = StadiumFloodlightOwnedItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned() )
	_check( not base.is_empty() and base.version == 25 and base.floodlights.is_empty(),
		"family25 wraps inherited current layout without installing towers" )
	if base.is_empty():
		return
	var partial: Dictionary = StadiumFloodlightOwnedItems.select_preset(
		base, partial_stock, "CLUB4-LOW" )
	var partial_check: Dictionary = StadiumFloodlightOwnedItems.validate(
		partial, _paid.construction(), "club" )
	_check( ( partial_check.ok and partial.floodlights.size() == 3
			and not partial_check.floodlight_complete and _apply(partial) ),
		"three actual copies may occupy partial daylight preset without phantom fourth" )
	_check( StadiumSurfaceNightLayout.capture(_paid).is_empty(),
		"partial installed towers cannot qualify for night" )
	var club: Dictionary = StadiumFloodlightOwnedItems.select_preset(
		base, _paid.construction(), "CLUB4-LOW" )
	_record("club-sparse", club)
	var canopy: Dictionary = club.duplicate(true)
	for index in range(2):
		var site: String = ["BASE-L2", "BASE-R2"][index]
		canopy = StadiumStraightItemsUI.select( canopy, _paid.construction(), _copies["ST-029"][index],
			{"copy": "", "site": site, "lower": "", "concourse": ""} )
		var options: Array = StadiumRoofItemsUI.options( canopy, _paid.construction(), "ST-053", "club" )
		var chosen: Dictionary = {}
		for option: Dictionary in options:
			if option.row.site == site and option.row.roof_state == "lower":
				chosen = option.row
		canopy = StadiumRoofItemsUI.select( canopy, _paid.construction(), _copies["ST-053"][index], chosen
		)
		_check( ( not chosen.is_empty()
				and StadiumHomeLayout.validate(canopy, _paid.construction(), "club").ok ),
			"existing exact support selectors preserve family25 and lower canopy " + site )
	_record("club-two-lower-canopies", canopy)
	_check( not StadiumFloodlightOwnedItems.night_profile(_configs[-1].snapshot).is_empty(),
		"only the measured two-lower-canopy exception qualifies" )
	var unsupported: Dictionary = canopy.duplicate(true)
	unsupported.roofs.pop_back()
	_check( _apply(unsupported) and StadiumSurfaceNightLayout.capture(_paid).is_empty(),
		"single lower canopy remains an unsupported night composition" )
	_check(_apply(club), "sparse Club preset restores after unsupported composition")
	_negatives(club)
	_paid_command({"op": "stadium_land", "tier": "mogul", "price_version": StadiumLand.VERSION})
	base = StadiumFloodlightOwnedItems.upgrade(_paid.view().stadium_active, _paid.surface_owned())
	var standard: Dictionary = StadiumFloodlightOwnedItems.select_preset(
		base, _paid.construction(), "MOGUL6-STANDARD" )
	_record("mogul-standard", standard)
	var premium: Dictionary = StadiumFloodlightOwnedItems.select_preset(
		standard, _paid.construction(), "MOGUL4-PREMIUM" )
	_record("mogul-premium", premium)
	var checked: Dictionary = StadiumHomeLayout.validate(premium, _paid.construction(), "mogul")
	_check( ( _copies["ST-038"].all(func(copy: String) -> bool: return checked.stored.has(copy))
			and premium.floodlights.size() == 4 ),
		"premium alternative stores every displaced standard tower with no head conversion" )
	_check( not StadiumHomeLayout.validate(premium, _paid.construction(), "club").ok,
		"premium sites retain Mogul property requirement" )
	var stored: Dictionary = StadiumFloodlightOwnedItems.select_preset(
		premium, _paid.construction(), "" )
	_check( _apply(stored) and StadiumSurfaceNightLayout.capture(_paid).is_empty(),
		"fully stored towers cannot qualify for night" )
	_check( _apply(premium) and _paid.construction().copies.size() == 21,
		"cold remount preserves all exact paid copies and no purchase is repeated" )
	var bad_journal: Dictionary = _paid.to_data().duplicate(true)
	bad_journal.floodlight_layout_catalog = "foreign"
	_check( ClubAssetLedger.from_data(bad_journal, 91, _credits, _progress) == null,
		"foreign floodlight catalog journal fails closed" )
	_check( _configs.size() == 4,
		"exactly four authorized sparse and two-canopy configurations are retained" )


func _record(label: String, layout: Dictionary) -> void:
	var checked: Dictionary = StadiumHomeLayout.validate(
		layout, _paid.construction(), _paid.view().land )
	_operands = {
		"label": label, "error": checked.get("error", ""), "profile": layout.floodlight_profile }
	_check( checked.ok and checked.floodlight_complete and checked.live_units == 0,
		"complete exact tower alternative validates without live-object capacity" )
	_check(_apply(layout), "ordinary free preset draft and apply " + label)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check( not snapshot.is_empty() and StadiumLayoutSnapshot.matches(snapshot, _paid),
		"current snapshot owns the exact complete tower declaration" )
	var candidate: Dictionary = StadiumSurfaceNightLayout.capture(_paid)
	_check( ( not candidate.is_empty() and candidate.candidate_version == 2
			and StadiumSurfaceNightLayout.valid(candidate, _paid) ),
		"candidate2 admits only this measured owned composition" )
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), 91, _credits, _progress )
	_check( ( cold != null and ClubCareer.same(cold.to_data(), _paid.to_data())
			and StadiumLayoutSnapshot.matches(snapshot, cold)
			and StadiumSurfaceNightLayout.valid(candidate, cold) ),
		"cold journal replay preserves exact copies layout and candidate" )
	_configs.append( { "label": label, "profile": layout.floodlight_profile,
			"layout": layout.duplicate(true), "snapshot": snapshot, "journal": _paid.to_data() } )


func _negatives(layout: Dictionary) -> void:
	for mode: String in [ "unowned", "wrong-item", "duplicate-copy", "duplicate-site", "foreign-site",
		"mixed-family", "extra-field", "wrong-profile", "wrong-family" ]:
		var bad: Dictionary = layout.duplicate(true)
		match mode:
			"unowned":
				bad.floodlights[0].copy = "purchase:foreign:0"
			"wrong-item":
				bad.floodlights[0].copy = _copies["ST-076"][0]
			"duplicate-copy":
				bad.floodlights[1].copy = bad.floodlights[0].copy
			"duplicate-site":
				bad.floodlights[1].site = bad.floodlights[0].site
			"foreign-site":
				bad.floodlights[0].site = "MLIGHT-HL"
			"mixed-family":
				bad.floodlights[0].item = "ST-076"
			"extra-field":
				bad.floodlights[0]["head_count"] = 16
			"wrong-profile":
				bad.floodlight_profile = "MOGUL-ARBITRARY"
			"wrong-family":
				bad.family = "foreign-family"
		_check( not StadiumHomeLayout.validate(bad, _paid.construction(), "club").ok,
			"malformed complete declaration rejected " + mode )
	var stored: Dictionary = StadiumFloodlightOwnedItems.store_copy( layout, layout.floodlights[0].copy
	)
	_check( _apply(stored) and StadiumSurfaceNightLayout.capture(_paid).is_empty(),
		"one stored matching copy does not complete installed night ownership" )
	_check(_apply(layout), "exact missing copy remounts free")
	var blocked: Dictionary = layout.duplicate(true)
	blocked.receiver = "starter-v1:ST-079"
	_check( ( _apply(blocked) and StadiumSurfaceNightLayout.capture(_paid).is_empty() and not (
				StadiumFloodlightOwnedItems . night_reason(StadiumLayoutSnapshot.capture(_paid)) . is_empty() )
		), "unmeasured additional physical composition denies night with clear reason" )
	_check(_apply(layout), "approved sparse composition restores after exclusion")


func _profile_cancel() -> void:
	_phase = "public-profile-cancel-and-save73-fail-closed"
	if _configs.is_empty():
		return
	var season: SeasonState = SeasonState.create(101, true)
	season.home_property = _configs[0].snapshot.duplicate(true)
	var paid: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_configs[0].journal)), 91, _credits, _progress )
	season._pool_replay_ledger = paid
	season._npc_replay_run = 0
	var policy: Dictionary = StadiumSurfaceNightSnapshot.capture_time_policy(season, paid, "night")
	_check( not policy.is_empty() and policy.version == 2 and policy.candidate.candidate_version == 2,
		"policy2 explicitly retains candidate2 instead of normalizing to yard" )
	for mode: String in [ "missing-policy", "fractional-save", "wrong-policy", "missing-legacy",
		"foreign-ownership", "invalid-history" ]:
		var value: Dictionary = {
			"version": 73, "legacy_save_version": 59, "owned_surface_night": policy.duplicate(true) }
		match mode:
			"missing-policy":
				value.erase("owned_surface_night")
			"fractional-save":
				value.version = 73.5
			"wrong-policy":
				value.owned_surface_night.version = 1
			"missing-legacy":
				value.erase("legacy_save_version")
			"foreign-ownership":
				value["ownership"] = {}
			"invalid-history":
				value["seed"] = -1
		_check( SeasonSave._decode(value) == null,
			"Save73 dispatch rejects invalid envelope without inventing earned history " + mode )
	var app: SeasonApp = SeasonApp.new()
	app.season = season
	app._dialog = ConfirmationDialog.new()
	add_child(app._dialog)
	var before: String = JSON.stringify(season.home_property)
	app.ask_progression_season()
	var choice: OptionButton
	for child: Node in app._dialog.find_children("*", "OptionButton", true, false):
		if child is OptionButton:
			choice = child
	_check( ( choice != null and choice.item_count == 3 and choice.selected == 0
			and choice.get_item_text(2).contains("floodlight preset") ),
		"real profile dialog exposes Day Sunset Night with owned preset requirement" )
	if choice != null:
		choice.select(2)
	app._dialog.hide()
	_check( ( app.season == season and season.owned_surface_night.is_empty()
			and JSON.stringify(season.home_property) == before ),
		"Cancel after Night selection preserves season policy and exact home entry" )
	app._dialog.queue_free()
	app.free()
	await get_tree().process_frame


func _collect_capture(lab: PitchBatLab, label: String, _viewtag: String) -> void:
	var checks_before: int = _checks
	await get_tree().physics_frame
	await get_tree().physics_frame
	_occlusion_check(lab, label)
	var viewport: SubViewport = lab.get_viewport() as SubViewport
	var camera: Camera3D = lab._camera
	var pose: Transform3D = camera.global_transform
	var projection: int = camera.projection
	var size: float = camera.size
	var fov: float = camera.fov
	var old_shot: int = lab._camera_director.shot
	var title: Label = Label.new()
	title.position = Vector2(22, 18)
	title.add_theme_font_size_override("font_size", 23)
	viewport.add_child(title)
	lab._status_label.hide()
	PitchBatLabPresentation.hide_match_presentation(lab)
	for viewtag: String in ["overview", "batting"]:
		if viewtag == "overview":
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 117.0 if label.begins_with("mogul") else 93.0
			camera.position = Vector3(65, 42, -55)
			camera.look_at(Vector3(0, 3, 16))
		else:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
			lab._camera_director.snap(camera)
			var ball: BattedBallBody = BattedBallBody.new()
			ball.freeze = true
			lab.add_child(ball)
			ball.global_position = POINT
			await get_tree().process_frame
			var contrast: Dictionary = await _contrast(camera, ball)
			_operands = { "label": label, "difference": contrast.get("difference", -1), "threshold": 0.03 }
			_check( not contrast.is_empty() and float(contrast.difference) >= 0.03,
				"actual night plate-sand ball contrast meets existing absolute minimum" )
			_optical[label] = { "difference": contrast.get("difference", -1), "threshold": 0.03,
				"point": [POINT.x, POINT.y, POINT.z], "operands": contrast.get("operands", {}) }
			ball.queue_free()
			await get_tree().process_frame
		title.text = label.replace("-", " ").to_upper() + " | NIGHT / " + viewtag.to_upper()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		_check( not image.is_empty() and image.get_size() == SIZE,
			"native owned floodlight view " + label + ":" + viewtag )
		_captures[label + ":" + viewtag] = image
	camera.global_transform = pose
	camera.projection = projection
	camera.size = size
	camera.fov = fov
	lab._camera_director.set_shot(old_shot as MatchCameraDirector.Shot)
	title.queue_free()
	await get_tree().process_frame
	_capture_checks += _checks - checks_before


func _occlusion_check(lab: PitchBatLab, label: String) -> void:
	var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	var points: Array[Vector3] = [ Vector3(0, 0.20, 1), Vector3(0, 1.1, 0), Vector3(0, 1.8, 14),
		Vector3(-15, 0.2, 22), Vector3(15, 0.2, 22), Vector3(0, 12, 20) ]
	var rows: Array = []
	var complete: bool = true
	for point: Vector3 in points:
		var clear: int = 0
		var blockers: Array = []
		for emitter: Dictionary in owner._emitters:
			var origin: Vector3 = emitter.beam.global_position
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create( origin, point, 1 )
			var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				clear += 1
			else:
				blockers.append( { "site": emitter.site, "item": hit.collider.get_meta("stadium_item", ""),
						"surface": hit.collider.get_meta("surface_id", "") } )
		rows.append( {"point": [point.x, point.y, point.z], "clear_emitters": clear, "blockers": blockers}
		)
		complete = complete and clear > 0
	_operands = {"label": label, "actual_occlusion": rows}
	_check( complete,
		"actual installed solids leave a clear light path to each bounded pitch field and fly sample" )
	_occlusion[label] = rows


func _montages() -> void:
	var overview: Image = Image.create(2560, 1440, false, Image.FORMAT_RGBA8)
	var details: Image = Image.create(2560, 1440, false, Image.FORMAT_RGBA8)
	var complete: bool = _captures.size() == 8
	for index in range(_configs.size()):
		for tag: String in ["overview", "batting"]:
			var key: String = _configs[index].label + ":" + tag
			if not _captures.has(key):
				complete = false
				continue
			var captured: Image = _captures[key]
			captured.convert(Image.FORMAT_RGBA8)
			var canvas: Image = overview if tag == "overview" else details
			canvas.blit_rect( captured, Rect2i(Vector2i.ZERO, SIZE),
				Vector2i((index % 2) * 1280, (index / 2) * 720) )
	_check(
		complete, "all four installed owned configurations supply overview and actual batting views" )
	if not complete:
		return
	for row: Array in [ ["floodlight-overview.png", overview], ["floodlight-night-views.png", details]
	]:
		_check( row[1].save_png(_capture_dir.path_join(row[0])) == OK,
			"combined native original saved " + str(row[0]) )
		_images.append(row[0])


func _run_live_comparison(directory: String, input_sha: String) -> Dictionary:
	_phase = "natural-time-comparison"
	var natural: bool = DisplayServer.get_name() != "headless" and not directory.is_empty()
	_check( natural,
		"dedicated matched live comparison has rendered output; natural-time argv is receipt-bound" )
	_check( not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK,
		"dedicated comparison output directory opens" )
	var bootstrap_path: String = _input_dir.path_join("floodlight-bootstrap.json")
	var exact: bool = ( not _input_dir.is_empty()
		and input_sha == "d25ef7dcde8fc9228672d391818a3c82932e4c6c85bfd255c2cb89a50b781f3b"
		and FileAccess.get_sha256(bootstrap_path) == input_sha )
	var bootstrap: Dictionary = _read_phase_json(bootstrap_path) if exact else {}
	exact = ( exact and bootstrap.get("schema") == 1 and ( bootstrap.get("fixture_sha256")
			== "310fd173f535c6d4db50b856fa51916395c95f379dfa409eac25ead1fbb563f4" )
		and bootstrap.get("credits") is Array and bootstrap.get("progress") is Array
		and bootstrap.get("configurations") is Array and bootstrap.configurations.size() == 4 )
	_check(exact, "exact accepted612 cold ownership bootstrap is bound")
	var comparison: Dictionary = {}
	if exact and natural and _failures == 0:
		var config: Dictionary = bootstrap.configurations[0]
		var cold: ClubAssetLedger = ClubAssetLedger.from_data(
			config.journal, 91, bootstrap.credits, bootstrap.progress )
		var cold_valid: bool = ( config.label == "club-sparse" and config.profile == "CLUB4-LOW"
			and cold != null and StadiumLayoutSnapshot.matches(config.snapshot, cold) )
		_check(cold_valid, "same exact cold Club4 scene supplies Day and Night")
		if cold_valid:
			var root: Node3D = _world()
			comparison = await StadiumFloodlightNightRebuildChecks.run_live_comparison(
				root, _check, cold, config )
			await _close_view()
	var payload: Dictionary = { "schema": 1, "scope": "owned-floodlight-natural-time-day-night",
		"checks": _checks + 1, "failures": _failures, "images": [], "games": 0,
		"bootstrap_sha256": input_sha, "fixture_sha256":
		FileAccess.get_sha256("res://src/tests/stadium_floodlight_rebuild_checks.gd"),
		"historical_correctness_checks": 612, "current_correctness_union_claim": false,
		"natural_time_proof": "exact runner process argv excludes --fixed-fps", "comparison": comparison,
		"elapsed_ms": Time.get_ticks_msec() - _phase_started_ms }
	var serialized: String = JSON.stringify(payload, "", true, true)
	var file: FileAccess = FileAccess.open(
		directory.path_join("floodlight-live-comparison.json"), FileAccess.WRITE )
	_check( _checks == 20 and file != null and serialized.to_utf8_buffer().size() <= 131072,
		"exact21 bounded comparison checks and finite evidence" )
	payload.checks = _checks
	payload.failures = _failures
	if file != null:
		serialized = JSON.stringify(payload, "", true, true)
		if serialized.to_utf8_buffer().size() <= 131072:
			file.store_string(serialized)
			file.flush()
			if file.get_error() != OK:
				_check(false, "natural-time comparison evidence fully writes")
		file.close()
	print( "FLOODLIGHT_LIVE_COMPARISON checks=%d failures=%d images=0 games=0" % [_checks, _failures] )
	return {"checks": _checks, "failures": _failures}

extends "res://src/tests/stadium_practice_facility_rebuild_checks_fixture_base.gd"
func _record(label: String, layout: Dictionary) -> void:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_operands = {
		"case": label,
		"paid_revision": _paid.revision(),
		"snapshot_version": snapshot.get("version", -1)
	}
	_check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.matches(snapshot, _paid)
			and ClubCareer.same(snapshot.layout, layout)
		),
		"exact frozen owned-parent snapshot " + label
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _paid.to_data())
			and StadiumLayoutSnapshot.matches(snapshot, cold)
		),
		"cold journal preserves exact purchased identity and placement " + label
	)
	_records.append(
		{
			"case": label,
			"layout": layout.duplicate(true),
			"paid_revision": _paid.revision(),
			"snapshot_version": snapshot.get("version", -1),
			"snapshot_sha256": JSON.stringify(snapshot, "", true, true).sha256_text(),
			"cold_exact": cold != null and StadiumLayoutSnapshot.matches(snapshot, cold)
		}
	)


func _initial_save73_context() -> Dictionary:
	# Retained _ordinary_fixture setup, bounded to its initial zero-game checkpoint.
	# Same frozen synthetic legacy proof and ordinary start/adopt/paid APIs.
	# The runtime-only cursor move is deliberately omitted, never reversed.
	var source: String = "res://src/tests/fixtures/frozen_v40.json"
	var source_sha: String = "d9b516d44b74dfa8ee5f4c68fc80f315fbd8541d28e45dfebfe3f84c818c6b65"
	if not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != source_sha:
		return {"ok": false, "stage": "ordinary-proof-source"}
	var archived: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
	if (
		not archived is Dictionary
		or not archived.get("career") is Dictionary
		or not archived.career.get("runs") is Array
		or archived.career.runs.is_empty()
	):
		return {"ok": false, "stage": "ordinary-proof-shape"}
	var row: Dictionary = archived.career.runs[0]
	if not row.get("proof") is Dictionary:
		return {"ok": false, "stage": "ordinary-proof-missing"}
	var proof: Dictionary = row.proof.duplicate(true)
	var summary: Dictionary = ClubSeasonRecord.analyze(proof)
	var receipt: Dictionary = ClubSeasonRecord.receipt(proof, false, 0)
	if (
		summary.get("finish") != "runner_up"
		or summary.get("wins") != 10
		or proof.scores.size() != 33
		or receipt.get("total") != 110
		or not ClubCareer.same(receipt, row.receipt)
	):
		return {"ok": false, "stage": "ordinary-proof-validation"}
	# Legacy grass/preparation are existing migration entitlements. Only these five
	# purchases are necessary: 600 + 1600 + (520 + 4*120) + 400 + 300 = 3900.
	var cost: int = (
		int(StadiumCatalog.LAND.expanded.price)
		+ int(StadiumCatalog.LAND.club.price)
		+ int(StadiumFloodlightOwnedItems.PRICES["ST-038"][0])
		+ 4 * int(StadiumFloodlightOwnedItems.PRICES["ST-038"][1])
		+ int(StadiumFieldStyles.PRICES["ST-063b"])
		+ int(StadiumGroundStyles.PRICES["ST-063i"])
	)
	var funding_rows: int = ceili(float(cost) / float(receipt.total))
	if cost != 3900 or funding_rows != 36:
		return {"ok": false, "stage": "ordinary-funding-bound"}
	var history: Array[Dictionary] = []
	for index in range(funding_rows):
		history.append(
			{
				"id": index + 1,
				"seed": int(row.seed),
				"league": "standard",
				"tier": 0,
				"status": "completed",
				"proof": proof.duplicate(true),
				"receipt": receipt.duplicate(true)
			}
		)
	var career: ClubCareer = ClubCareer.from_data({"version": 1, "current": 0, "runs": history})
	return _practice_career_save_context(source, source_sha, proof, cost, funding_rows, career)


func _practice_career_save_context(
	source: String, source_sha: String, proof: Dictionary, cost: int, funding_rows: int,
	career: ClubCareer
) -> Dictionary:
	if career == null:
		return {"ok": false, "stage": "ordinary-legacy-migration"}
	var season: SeasonState = SeasonState.create(101, false, true, true)
	# Same initial physical/player-access/policy13 sequence as SeasonApp entry.
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(career)):
		return {"ok": false, "stage": "ordinary-player-access"}
	season.career = career
	if not career.start(season) or career._pennants.get("from_season") != funding_rows + 1:
		return {"ok": false, "stage": "ordinary-start-adopt"}
	for pick in range(4):
		if season.offers().is_empty() or not season.choose_player(season.offers()[0]):
			return {"ok": false, "stage": "ordinary-draft"}
	return _practice_paid_ledger_context(source, source_sha, proof, cost, funding_rows, career, season)


func _practice_paid_ledger_context(
	source: String, source_sha: String, proof: Dictionary, cost: int, funding_rows: int,
	career: ClubCareer, season: SeasonState
) -> Dictionary:
	var paid: ClubAssetLedger = ClubPlayers.assets(career)
	var through: int = ClubPlayers.income_through(career)
	var progress: Array = StadiumCareerProgress.capture(career)
	if (
		paid == null
		or through != funding_rows
		or progress.size() != funding_rows
		or paid.balance() != 3960
		or paid.surface_owned() != ["grass", "ground_prep"]
	):
		return {"ok": false, "stage": "ordinary-derived-funding"}
	var layout_result: Dictionary = _practice_purchase_and_apply_layout(paid, through, progress)
	if not layout_result.is_empty():
		return layout_result
	career._assets = paid.to_data()
	if season.round_index != 0 or not career.sync(season) or not career.matches(season):
		return {"ok": false, "stage": "ordinary-initial-career-sync"}
	var cold: ClubCareer = ClubCareer.from_data(
		JSON.parse_string(JSON.stringify(career.to_data(), "", true, true))
	)
	if cold == null:
		return {"ok": false, "stage": "ordinary-career-cold"}
	season.career = cold
	paid = ClubPlayers.assets(cold)
	if paid == null or season._pool_replay_ledger != null or season._npc_replay_run != -1:
		return {"ok": false, "stage": "ordinary-assets-cold"}
	season.home_property = StadiumLayoutSnapshot.capture(paid)
	return _practice_cold_admission_context(
		source, source_sha, proof, cost, funding_rows, season, paid
	)


func _practice_cold_admission_context(
	source: String, source_sha: String, proof: Dictionary, cost: int, funding_rows: int,
	season: SeasonState, paid: ClubAssetLedger
) -> Dictionary:
	var scheduled: Dictionary = {}
	for fixture: Dictionary in season.schedule:
		if fixture.home == 0 and (scheduled.is_empty() or fixture.round < scheduled.round):
			scheduled = fixture.duplicate(true)
	if scheduled.is_empty():
		return {"ok": false, "stage": "ordinary-home-fixture"}
	# Keep the normal initial round0 from SeasonState.create throughout.
	season.owned_surface_night = StadiumSurfaceNightSnapshot.capture_time_policy(
		season, paid, "night"
	)
	var snapshot: Dictionary = StadiumSurfaceNightSnapshot.fixture(season, scheduled)
	if (
		season.owned_surface_night.is_empty()
		or snapshot.is_empty()
		or not StadiumSurfaceNightSnapshot.matches_fixture(snapshot, season, scheduled, paid)
		or not season.results.is_empty()
		or not season.player_results.is_empty()
	):
		return {"ok": false, "stage": "ordinary-full-admission"}
	return {
		"ok": true,
		"season": season,
		"paid": paid,
		"proof_sha256": source_sha,
		"stage": "ready",
		"source_proof_sha256": JSON.stringify(proof, "", true, true).sha256_text(),
		"source_file": source,
		"source_file_sha256": source_sha,
		"funding_rows": funding_rows,
		"synthetic_funding": true,
		"synthetic_history": true,
		"games": 0,
		"funding_credits": 3960,
		"spent": cost,
		"balance": paid.balance()
	}


func _save73_compatibility() -> void:
	_phase = "actual-save73-stored-progress-version-compatibility"
	var context: Dictionary = _initial_save73_context()
	_operands = {"stage": context.get("stage", ""), "error": context.get("error", "")}
	_check(
		context.get("ok", false),
		"retained zero-game paid-light setup supplies validated Save73 context"
	)
	if not context.get("ok", false):
		return
	var season: SeasonState = context.season
	var fresh: Dictionary = SeasonSave.snapshot(season)
	var cold: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(fresh, "", true, true))
	)
	_cold_operands("save73-v2", fresh, cold)
	_check(
		(
			fresh.get("version") == 73
			and season.round_index == 0
			and season.career.matches(season)
			and fresh.career.runs[-1].player_progress.version == ClubPlayerLegend.VERSION
			and cold != null
			and cold.career.matches(cold)
			and ClubCareer.same(SeasonSave.snapshot(cold), fresh)
			and season.results.is_empty()
			and season.player_results.is_empty()
		),
		"actual zero-game Save73 preserves new total-hit proof version through cold decode"
	)
	if fresh.is_empty():
		return
	var legacy: Dictionary = fresh.duplicate(true)
	legacy.career.runs[-1].player_progress.version = 1
	var legacy_cold: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(legacy, "", true, true))
	)
	_cold_operands("save73-v1", legacy, legacy_cold)
	_check(
		(
			legacy_cold != null
			and legacy_cold.career.matches(legacy_cold)
			and ClubCareer.same(SeasonSave.snapshot(legacy_cold), legacy)
		),
		"actual zero-game Save73 preserves stored legacy proof version without synthesizing hits"
	)
	var tampered: Dictionary = fresh.duplicate(true)
	tampered.career.runs[-1].player_progress.version = 4
	_check(
		SeasonSave._decode(tampered) == null,
		"actual Save73 refuses unsupported proof-version tampering"
	)
	_ownership_cases.append(
		{
			"case": "save73-progress-version-compatibility",
			"synthetic_history": true,
			"synthetic_funding": true,
			"funding_rows": context.funding_rows,
			"source_file_sha256": context.source_file_sha256,
			"source_proof_sha256": context.source_proof_sha256,
			"save_version": fresh.get("version"),
			"new_v2_cold_exact": cold != null,
			"legacy_v1_cold_exact": legacy_cold != null,
			"unsupported_version_rejected": true,
			"played_games": 0
		}
	)


func _ownership() -> void:
	_hit_source_contract()
	_save73_compatibility()
	_phase = "exact-source-metrics-gates-and-paid-copies"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5, "strikeouts": 3, "hits": 4})
	_check(
		(
			StadiumCareerProgress.valid(_progress, _credits)
			and ClubCareer.same(
				StadiumCareerProgress.metrics(_progress, 40),
				{"seasons": 40, "wins": 200, "strikeouts": 120, "hits": 160}
			)
		),
		"explicit synthetic closed rows satisfy the actual K and H source contract"
	)
	_paid = ClubAssetLedger.new_club(SEED, _credits, _progress)
	var starter: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"practice adoption grants no facility, bundled support, figure or ball inventory"
	)
	for item: String in ITEMS:
		var metric: String = "strikeouts" if item == "ST-060" else "hits"
		var threshold: int = 120 if item == "ST-060" else 160
		var entry: Dictionary = StadiumCatalog.item(item)
		var gate: Dictionary = {"seasons": 10, metric: threshold}
		_check(
			(
				entry.blueprint_price == 750
				and entry.copy_price == 220
				and ClubCareer.same(entry.requires, gate)
			),
			"unchanged 750 blueprint 220 copy and exact source progression gate " + item
		)
		for delta: Vector2i in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(0, -1)]:
			var progress: Dictionary = {"seasons": 10 + delta.x, metric: threshold + delta.y}
			var quote: Dictionary = StadiumPurchases.quote(
				_paid.construction(),
				item,
				1,
				"practice-gate:" + item + str(delta),
				StadiumPracticeFacilityItems.PRICE_VERSION,
				progress
			)
			_check(
				quote.ok == (delta == Vector2i.ZERO),
				"exact threshold and each just-below gate " + item + str(delta)
			)
		_check(
			not (
				StadiumPurchases
				. quote(
					_paid.construction(),
					item,
					1,
					"practice-wrong-price:" + item,
					StadiumGroundBoxItems.PRICE_VERSION,
					gate
				)
				. ok
			),
			"older complete-box price route cannot buy a practice facility " + item
		)
		_copies.append(_buy(item, StadiumPracticeFacilityItems.PRICE_VERSION, 970))
		_copies.append(_buy(item, StadiumPracticeFacilityItems.PRICE_VERSION, 220))
	_inherited["ST-052"] = _buy("ST-052", StadiumGroundBoxItems.PRICE_VERSION, 680)
	_inherited["ST-051"] = _buy("ST-051", StadiumMoldedSeatItems.PRICE_VERSION, 265)
	_inherited["ST-038"] = _buy("ST-038", StadiumFloodlightOwnedItems.PRICE_VERSION, 640)
	if _copies.has("") or _inherited.values().has(""):
		return
	_check(
		_paid.construction().copies.size() == 10 and StadiumLayoutSnapshot.matches(starter, _paid),
		"seven explicit purchased copies leave the exact starter journal prefix authenticated"
	)
	for tier: String in ["expanded", "club"]:
		var before_count: int = _paid.construction().copies.size()
		var result: Dictionary = _paid.commit(
			{
				"id": "practice-land:" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(
			result.ok and _paid.construction().copies.size() == before_count,
			"ordinary land purchase exposes sites without granting copies " + tier
		)
	var base28: Dictionary = StadiumSmallYardSceneryItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	var inherited: Dictionary = StadiumMoldedSeatItems.place(
		base28, _paid.construction(), _inherited["ST-051"], "SEAT-PAD-1", 0.0, _paid.surface_owned()
	)
	inherited = StadiumGroundBoxItems.place(
		inherited, _paid.construction(), _inherited["ST-052"], "BOX-L", 0.0, _paid.surface_owned()
	)
	_check(
		_checked(inherited, "club").ok and _apply(inherited),
		"accepted ground box and optional separately paid seat are installed before adoption"
	)
	_record("inherited-family30-box-and-optional-pad", inherited)
	_old_prefix = StadiumLayoutSnapshot.capture(_paid)
	var preserved: Dictionary = _place(inherited, _copies[0], SITES[0])
	_check(
		(
			preserved.version == 31
			and preserved.ground_box_base_version == 29
			and preserved.ground_boxes == inherited.ground_boxes
			and preserved.molded_seats == inherited.molded_seats
			and ClubCareer.same(StadiumPracticeFacilityItems.base(preserved), inherited)
			and _checked(preserved, "club").ok
			and _apply(preserved)
		),
		"practice parent retains full inherited ST-052 and optional ST-051 state"
	)
	_record("practice-retains-ground-box-and-optional-pad", preserved)
	_empty = StadiumPracticeFacilityItems.upgrade(base28, _paid.surface_owned())
	_check(
		(
			_empty.version == 31
			and _empty.ground_box_base_version == 28
			and _empty.ground_boxes.is_empty()
			and not _empty.has("molded_seats")
			and _empty.practice_facilities.is_empty()
			and _checked(_empty, "club").ok
			and _apply(_empty)
		),
		"empty practice-only family31 grants no copy or optional pad"
	)
	_record("empty-practice-only-no-pad", _empty)
	_check(
		(
			StadiumPracticeFacilityItems.sites("ST-060") == SITES
			and StadiumPracticeFacilityItems.sites("ST-061") == SITES
			and StadiumPracticeFacilityItems.yaws("ST-060") == [0]
			and StadiumPracticeFacilityItems.yaws("ST-061") == [0]
		),
		"two parent types share only three exact fixed-pose sites"
	)
	var balance: int = _paid.balance()
	var club: Dictionary = _place(_empty, _copies[0], SITES[0])
	_check(
		_checked(club, "club").ok and _apply(club) and _paid.balance() == balance,
		"one paid Club partial configuration applies without another charge"
	)
	_record("club-one-paid-bullpen", club)
	var stored: Dictionary = StadiumPracticeFacilityItems.store_copy(club, _copies[0])
	_check(
		(
			ClubCareer.same(stored, _empty)
			and _checked(stored, "club").stored.has(_copies[0])
			and _apply(stored)
		),
		"Club Store removes only placement and retains exact ownership"
	)
	_record("club-facility-stored", stored)
	var remount: Dictionary = _place(stored, _copies[0], SITES[0])
	_check(
		ClubCareer.same(remount, club) and _apply(remount) and _paid.balance() == balance,
		"same Club copy remounts without charge or replacement identity"
	)
	_record("club-same-copy-remounted", remount)
	var expansion: Dictionary = _paid.commit(
		{
			"id": "practice-land:mogul",
			"rev": _paid.revision(),
			"op": "stadium_land",
			"tier": "mogul",
			"through": 40,
			"progress_through": 40,
			"price_version": StadiumLand.VERSION
		}
	)
	_check(
		(
			expansion.ok
			and _paid.construction().copies.size() == 10
			and ClubCareer.same(_paid.view().stadium_active, club)
		),
		"Mogul expansion retains Club-only placement and grants no facility"
	)
	_record("club-facility-retained-after-mogul-expansion", club)
	balance = _paid.balance()
	var partial: Dictionary = _place(
		StadiumPracticeFacilityItems.store_copy(club, _copies[0]), _copies[0], SITES[1]
	)
	_check(
		_checked(partial).ok and _apply(partial),
		"Store-first transition permits one paid Mogul lane"
	)
	_record("mogul-one-lane-partial", partial)
	_layout = _place(partial, _copies[2], SITES[2])
	_check(
		_checked(_layout).ok and _apply(_layout) and _paid.balance() == balance,
		"two different paid complete parents occupy independent Mogul lanes"
	)
	_record("mogul-mixed-complete-parents", _layout)
	for pair: Array in [[0, 1], [2, 3]]:
		var same_type: Dictionary = _place(
			_place(_empty, _copies[pair[0]], SITES[1]), _copies[pair[1]], SITES[2]
		)
		_check(
			(
				_checked(same_type).ok
				and _apply(same_type)
				and same_type.practice_facilities.size() == 2
				and _paid.balance() == balance
			),
			"two independently paid copies of one type remain distinct " + str(pair)
		)
		_record("mogul-same-type-" + str(pair[0]), same_type)
		var one_left: Dictionary = StadiumPracticeFacilityItems.store_copy(
			same_type, _copies[pair[0]]
		)
		_check(
			(
				_checked(one_left).ok
				and one_left.practice_facilities == [{"copy": _copies[pair[1]], "site": SITES[2]}]
				and _apply(one_left)
			),
			"exact-copy Store retains the other lane " + str(pair)
		)
		_record("mogul-store-first-copy-" + str(pair[0]), one_left)
	_negatives()
	_check(
		(
			_checked(_layout).ok
			and _apply(_layout)
			and _paid.balance() == balance
			and _paid.to_data().version == 39
		),
		"final mixed complete parents apply on ledger39 without any further purchase"
	)
	_record("final-two-independent-complete-parents", _layout)
	_snapshot = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_check(
		(
			StadiumLayoutSnapshot.matches(_old_prefix, _paid)
			and cold != null
			and StadiumLayoutSnapshot.matches(_old_prefix, cold)
		),
		"accepted family30 prefix remains authenticated warm and cold after practice adoption"
	)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshot, SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshot)
			and environment.mode == "day"
			and not _checked(_layout).get("night_qualified", true)
		),
		"frozen practice fixture preserves daylight-only admission"
	)


func _camera_clearance(lab: PitchBatLab, placements: Array) -> void:
	_phase = "bounded-existing-batting-camera-clearance"
	var director: MatchCameraDirector = lab._camera_director
	var old_side: float = director._batter_side
	var old_shot: MatchCameraDirector.Shot = director.shot
	var old_motion: MatchCameraDirector.PresentationMotion = director._presentation_motion
	var old_progress: float = director._presentation_progress
	for left: bool in [false, true]:
		for zoom: bool in [false, true]:
			director.set_batter_handedness(left)
			director.set_shot(MatchCameraDirector.Shot.BATTING)
			director.set_presentation_motion(
				(
					MatchCameraDirector.PresentationMotion.ZOOM_IN
					if zoom
					else MatchCameraDirector.PresentationMotion.STILL
				),
				1.0
			)
			var pose: Transform3D = director._desired_transform(PitchBatLab.MOUND_ORIGIN, 0.0)
			var blocked: Array[String] = []
			for placed: Dictionary in placements:
				var box: AABB = StadiumPracticeFacilityItems.bounds(placed)
				if (
					box.has_point(pose.origin)
					or (
						box.intersects_segment(pose.origin, PitchBatLab.MOUND_ORIGIN + Vector3.UP)
						!= null
					)
				):
					blocked.append(placed.site)
			_operands = {
				"left_handed": left,
				"zoom_in": zoom,
				"eye": _v3(pose.origin),
				"blocked_sites": blocked
			}
			_check(
				blocked.is_empty(),
				(
					"actual existing batting-camera origin and pitcher sightline clear whole "
					+ "practice-facility reservations"
				)
			)
			_camera_cases.append(_operands.duplicate(true))
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress


func _preview_focus() -> void:
	_phase = "actual-owned-copy-workshop-focus"
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(640, 360)
	preview.build(_layout, _paid.construction(), true, "mogul", null, null, _paid.surface_owned())
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		(
			preview.preview_property != null
			and preview.preview_property.props_intact()
			and not preview.preview_property.has_node("MoldedSeatPad")
			and not preview.night_eligible
		),
		(
			"actual Workshop preview builds two paid complete practice parents with no optional "
			+ "pad in daylight"
		)
	)
	var cases: Array[Dictionary] = []
	for copy: String in [_copies[0], _copies[2]]:
		preview.focus_copy(copy)
		await get_tree().process_frame
		var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
		var bounds: AABB = preview.board_bounds.get(copy, AABB())
		var contained: bool = preview.board_bounds.has(copy) and rect.size.x > 0 and rect.size.y > 0
		for index in range(8):
			var point: Vector3 = bounds.get_endpoint(index)
			contained = (
				contained
				and not preview.camera.is_position_behind(point)
				and rect.has_point(preview.camera.unproject_position(point))
			)
		_operands = {
			"copy": copy,
			"bounds": str(bounds),
			"viewport": [rect.size.x, rect.size.y],
			"eye": _v3(preview.camera.position)
		}
		_check(
			contained,
			(
				"actual owned-copy preview focus contains all eight complete facility reservation corners "
				+ copy
			)
		)
		cases.append({"copy": copy, "all_eight_corners_in_frame": contained})
	_ui_cases.merge(
		{"native_preview": true, "focus_cases": cases, "night_eligible": preview.night_eligible}
	)
	preview.queue_free()
	await get_tree().process_frame


func _both_in_frame(camera: Camera3D) -> bool:
	var readable: Rect2 = Rect2(12, 108, 1256, 600)
	for row: Dictionary in _checked(_layout).practice_facility_placements:
		var box: AABB = StadiumPracticeFacilityItems.bounds(row)
		for index in range(8):
			var point: Vector3 = box.get_endpoint(index)
			if (
				camera.is_position_behind(point)
				or not readable.has_point(camera.unproject_position(point))
			):
				_operands = {
					"site": row.site,
					"corner": _v3(point),
					"pixel": str(camera.unproject_position(point)),
					"readable": str(readable)
				}
				return false
	return true


func _views(root: Node3D, property: StadiumPropertyGeometry) -> void:
	_phase = "two-native-complete-parent-originals"
	var focus: Vector3 = Vector3(-37.25, 3.1, 41.75)
	var camera: Camera3D = _studio(root, focus + Vector3(22, 24, -30), focus, 29)
	_label(
		root, "PRACTICE FACILITIES | Two independently paid complete parents", Vector2(22, 18), 23
	)
	_label(
		root,
		"ST-060 chain-link bullpen + ST-061 freestanding net cage | Mogul M1 + M2",
		Vector2(22, 50),
		18
	)
	_label(
		root,
		"Full 4.5 x 10.5 m reservations, 1.5 m lane gap | synthetic funding and progression",
		Vector2(22, 78),
		17
	)
	await get_tree().process_frame
	_check(
		_both_in_frame(camera),
		"overview contains both full installed parent reservations clear of heading and footer"
	)
	await _capture("practice-facility-overview.png")
	for child: Node in root.get_children():
		if child is Label:
			child.queue_free()
	await get_tree().process_frame
	_check(
		(
			is_instance_valid(property.objects.get(_copies[0]))
			and is_instance_valid(property.objects.get(_copies[2]))
		),
		"detail reuses both actual installed paid parent objects"
	)
	camera.position = focus + Vector3(14, 10, -19)
	camera.look_at(focus)
	camera.size = 21
	_label(
		root,
		"COMPLETE PARENTS | Frame, chain-link / net, support and practice markings",
		Vector2(22, 18),
		23
	)
	_label(root, "ST-060 visible 4 x 10 x 3 m | ST-061 visible 4 x 10 x 3.5 m", Vector2(22, 50), 18)
	_label(
		root,
		"Static off-field scenery | no receiver, training, stats, income or new Night qualification",
		Vector2(22, 78),
		17
	)
	await get_tree().process_frame
	_check(
		_both_in_frame(camera),
		"detail contains both full parent reservations without heading or bottom-HUD collision"
	)
	await _capture("practice-facility-details.png")




func _practice_purchase_and_apply_layout(
	paid: ClubAssetLedger, through: int, progress: Array
) -> Dictionary:
	var commands: Array[Dictionary] = [
		{"op": "stadium_land", "tier": "expanded", "price_version": StadiumLand.VERSION},
		{"op": "stadium_land", "tier": "club", "price_version": StadiumLand.VERSION},
		{
			"op": "stadium_buy",
			"item": "ST-038",
			"quantity": 4,
			"price_version": StadiumFloodlightOwnedItems.PRICE_VERSION
		},
		{"op": "stadium_style", "item": "ST-063b", "price_version": StadiumFieldStyles.VERSION},
		{
			"op": "stadium_style",
			"item": "ST-063i",
			"price_version": StadiumGroundStyles.PRICE_VERSION
		}
	]
	for command: Dictionary in commands:
		command.id = "ordinary-floodlight-paid:%d" % paid.revision()
		command.rev = paid.revision()
		command.through = through
		command.progress_through = progress.size()
		var purchased: Dictionary = paid.commit(command)
		if not purchased.ok:
			return {
				"ok": false,
				"stage": "ordinary-purchase",
				"op": command.op,
				"item": command.get("item", command.get("tier", "")),
				"error": purchased.get("error", "")
			}
	var layout: Dictionary = StadiumFloodlightOwnedItems.upgrade(
		paid.view().stadium_active, paid.surface_owned()
	)
	if layout.is_empty():
		return {"ok": false, "stage": "ordinary-layout-upgrade"}
	layout.surface = {"foundation": "grass", "condition": "prepared", "height": "short"}
	layout.styles = {"grass": "ST-063b", "line": ""}
	layout.ground = "ST-063i"
	layout = StadiumFloodlightOwnedItems.select_preset(layout, paid.construction(), "CLUB4-LOW")
	var draft: Dictionary = paid.commit(
		{
			"id": "ordinary-floodlight-draft",
			"rev": paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		return {"ok": false, "stage": "ordinary-draft-layout", "error": draft.get("error", "")}
	var applied: Dictionary = paid.commit(
		{
			"id": "ordinary-floodlight-apply",
			"rev": paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumHomeLayout.geometry("club", layout)
		}
	)
	if not applied.ok or paid.balance() != 60:
		return {"ok": false, "stage": "ordinary-apply-layout", "error": applied.get("error", "")}
	return {}

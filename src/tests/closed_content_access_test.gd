extends Node
## Narrow access contract fixtures. No fabricated earnings or paid F09 claim.
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const Owner = preload("res://src/gameplay/season/dynasty_owner.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func cold(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _ready() -> void:
	var phase: String = "domain"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--access-phase="):
			phase = argument.trim_prefix("--access-phase=")
	var source: SeasonState = SeasonState.create(13002, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "ordinary source career starts through existing route")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "source ordinary draft")
	var origin: Dictionary = SeasonSave.snapshot(source)
	check(
		not origin.is_empty() and SeasonSave._decode(cold(origin)) != null,
		"exact no-earnings source fully decodes"
	)
	var profile: Dictionary = Profile.capture_access_season(
		origin, "access-lineage", "access-owner"
	)
	check(
		not profile.is_empty() and profile.get("version") == 2,
		"explicit source-replayed access profile"
	)
	if not profile.is_empty():
		if phase == "domain":
			_domain(origin, profile)
		elif phase == "store":
			_store(origin, profile)
		else:
			check(false, "recognized phase")
	Store._test_stop_after = ""
	print("Closed access %s checks: %d, failures: %d" % [phase, checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _domain(origin: Dictionary, profile: Dictionary) -> void:
	var access: Dictionary = profile.access
	var club: ClubCareer = SeasonSave._decode(origin).career
	check(
		access.progress.gear_start == club.gear_counts(),
		"gear projection uses existing career counts"
	)
	check(
		access.progress.sponsor_start == club.sponsor_state(),
		"sponsor projection uses existing career state"
	)
	check(
		not access.progress.major_start and access.progress.ability_start == 0,
		"new unearned source cannot unlock F09 or Sky Reader"
	)
	check(
		(
			access.progress.order_start == club.order_access()
			and access.progress.field_start == SeasonFieldSupply.access(club)
		),
		"season-threshold projections unchanged"
	)
	check(
		(
			access.progress.supply_start == club.supply_count()
			and access.progress.batch_start == SeasonSmallBatch.access(club)
		),
		"cumulative supply projections unchanged"
	)
	check(
		access.source.sha256 == ClosedContentAccess.digest(origin), "exact source digest retained"
	)
	for field: String in ["version", "rule", "owner_id", "source", "progress"]:
		var bad: Dictionary = cold(access)
		bad[field] = null
		check(ClosedContentAccess.normalize(bad).is_empty(), "malformed context rejects " + field)
	var bad: Dictionary = cold(access)
	bad.extra = true
	check(ClosedContentAccess.normalize(bad).is_empty(), "unknown context key rejects")
	for field: String in ["supply_start", "ability_start"]:
		for value: Variant in [-1, 4, 0.1, true, null]:
			bad = cold(access)
			bad.progress[field] = value
			check(
				ClosedContentAccess.normalize(bad).is_empty(),
				"wrong integer type/bound rejects " + field
			)
	for value: Variant in [null, 1, [], "wrong"]:
		bad = cold(profile)
		bad.source = value
		check(
			Profile.normalize(bad).is_empty(),
			"malformed v2 profile source rejects without exception"
		)
	bad = cold(profile)
	bad.players[bad.roster[0]].temporary_fielding_slots = 2
	var before_overflow: String = JSON.stringify(bad, "", true, true)
	check(Bridge.create(bad) == null, "first admission temporary slot2 remains rejected")
	check(
		JSON.stringify(bad, "", true, true) == before_overflow,
		"rejected first admission does not decay or mutate source"
	)
	var missing_profile: SeasonState = SeasonState.create_closed_league(
		profile.seed, LeagueRules.capture("dynasty"), true, access
	)
	check(
		(
			missing_profile != null
			and not missing_profile.league_context_consistent()
			and SeasonSave.snapshot(missing_profile).is_empty()
		),
		"access Dynasty without exact profile cannot advertise a valid snapshot"
	)
	var season: SeasonState = Bridge.create(profile)
	check(season != null, "new access Dynasty constructs with ordinary capacity")
	if season == null:
		return
	check(season.career == null and season._closed_access == access, "no public career attached")
	check(
		season.build.cash() == 0 and season.build._bank.view().sponsors.is_empty(),
		"fresh zero Cash and no sponsor ownership"
	)
	check(
		(
			season.build._major.player == ""
			and season.build._abilities.learned.values().all(
				func(rows: Array) -> bool: return rows.is_empty()
			)
		),
		"eligibility grants no nominee or ability"
	)
	for id: String in profile.roster:
		check(
			profile.players[id].temporary_fielding_slots == 1,
			"first admission retains ordinary slot"
		)
	for ai: Dictionary in season.opponents.clubs.values():
		check(ClosedContentAccess.untracked(ai.build), "AI receives no human owner access")
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	check(snapshot.get("version") == 80, "explicit access envelope80")
	var restored: SeasonState = SeasonSave._decode(cold(snapshot))
	check(restored != null, "access Dynasty cold decode")
	check(Owner._decode(cold(snapshot), true) != null, "owner cold numeric Save80 admission")
	check(
		not Lineage.capture_current(Lineage.create(profile), cold(snapshot)).is_empty(),
		"lineage cold numeric Save80 source capture"
	)
	if restored != null:
		check(
			ClubCareer.same(SeasonSave.snapshot(restored), snapshot), "access encode/decode exact"
		)
	check(
		Profile.capture_build(season.build, profile.lineage_id, profile.owner_id).is_empty(),
		"raw Build helper cannot mint access profile"
	)
	check(
		ClosedContentAccess.capture(season.build.to_data(), profile.owner_id).is_empty(),
		"raw Build cannot mint origin"
	)
	bad = cold(snapshot)
	bad.version = 79
	bad.erase("access")
	check(SeasonSave._decode(bad) == null, "profile2 cannot be laundered through old79")
	for field: String in ClosedContentAccess.FIELDS:
		bad = cold(snapshot)
		bad.checkpoint.checkpoint.build[field] = null
		check(SeasonSave._decode(bad) == null, "frozen context/header mismatch rejects " + field)
	bad = cold(snapshot)
	bad.access.source.sha256 = "a".repeat(64)
	check(SeasonSave._decode(bad) == null, "context/profile provenance mismatch rejects")
	bad = cold(snapshot)
	bad.checkpoint.checkpoint.career = origin.career
	check(SeasonSave._decode(bad) == null, "public career mixed with closed access rejects")
	var capture: Dictionary = Profile.capture_season(snapshot, profile.lineage_id, profile.owner_id)
	check(
		not capture.is_empty() and capture.access == access,
		"source replay folds empty current progress exactly once"
	)
	var decayed: Dictionary = Profile.decay(capture)
	check(
		not decayed.is_empty() and decayed.profile.access == access,
		"decay preserves access exactly"
	)
	var standard: SeasonState = SeasonState.create_closed_league(
		13003, LeagueRules.capture("standard"), true, access
	)
	check(standard != null, "new closed Standard shares immutable owner access")
	if standard != null:
		bad = cold(SeasonSave.snapshot(standard))
		bad.dynasty_start = null
		check(
			SeasonSave._decode(bad) == null, "Standard access cannot carry even null Dynasty field"
		)
		for pick in range(4):
			check(standard.choose_player(standard.offers()[0]), "access Standard draft pick")
			var saved: Dictionary = SeasonSave.snapshot(standard)
			check(
				saved.get("version") == 80 and SeasonSave._decode(cold(saved)) != null,
				"access Standard draft/pick4 cold decode"
			)
		check(
			ClosedContentAccess.matches(standard.build, access),
			"pick4 replacement preserves exact baseline"
		)
		bad = cold(access)
		bad.progress.major_start = true
		check(
			not ClosedContentAccess.install(standard.build, bad),
			"different eligibility cannot replace empty-journal installed baseline"
		)
		check(
			not (
				season
				. build
				. preview(
					{
						"id": "still-no-recruit",
						"rev": season.build.revision(),
						"op": "sign",
						"offer": "none",
						"release": profile.roster[0]
					}
				)
				. ok
			),
			(
				"fresh no-shop source admits no sign action; explicit Dynasty gate separately "
				+ "unchanged in source"
			)
		)
	var legacy: Dictionary = Profile.capture_season(origin, "legacy-lineage", "legacy-owner")
	check(
		legacy.get("version") == 1 and not legacy.has("access"), "old capture stays explicit legacy"
	)
	var old_season: SeasonState = Bridge.create(legacy)
	check(
		old_season != null and SeasonSave.snapshot(old_season).get("version") == 79,
		"legacy79 unchanged"
	)
	# Pure fold unit fixture, not source admission or manufactured earned history.
	var raw: SeasonState = SeasonState.create_closed_league(
		13004, LeagueRules.capture("standard"), true, access
	)
	raw.build._paid_rerolls = 2
	raw.build._field_outs = 5
	raw.build._abilities.earned = 2
	raw.build._supply_used = 2
	var fold: Dictionary = ClosedContentAccess._fold_replayed(raw.build, access)
	check(
		not fold.progress.order_start and not fold.progress.field_start,
		"subthreshold seasons do not earn season-threshold flags"
	)
	check(
		fold.progress.ability_start == 2 and fold.progress.supply_start == 2,
		"separate cumulative progress retained"
	)
	var second: SeasonState = SeasonState.create_closed_league(
		13005, LeagueRules.capture("standard"), true, fold
	)
	second.build._paid_rerolls = 2
	second.build._field_outs = 5
	second.build._abilities.earned = 2
	second.build._supply_used = 2
	var folded: Dictionary = ClosedContentAccess._fold_replayed(second.build, fold)
	check(
		not folded.progress.order_start and not folded.progress.field_start,
		"separate 2/5 seasons cannot sum into reroll/Field Supply gate"
	)
	check(
		folded.progress.ability_start == 3 and folded.progress.supply_start == 3,
		"existing cap3 cumulative addition preserved"
	)


func _store(origin: Dictionary, profile: Dictionary) -> void:
	var season: SeasonState = Bridge.create(profile)
	check(season != null, "access owner target constructs")
	if season == null:
		return
	var payload: Dictionary = {
		"lineage": Lineage.create(profile),
		"snapshot": SeasonSave.snapshot(season),
		"session_id": "%s:1" % profile.lineage_id,
		"origin": origin
	}
	var substituted: Dictionary = cold(profile)
	substituted.roster.reverse()
	check(
		(
			not Profile.normalize(substituted).is_empty()
			and not Owner._origin_start_matches(origin, substituted)
		),
		"same-access compact roster substitution cannot bypass exact first source capture"
	)
	substituted = cold(profile)
	substituted.seed += 1
	check(
		(
			Owner._origin_start_matches(origin, substituted)
			and substituted.source.seed == profile.source.seed
		),
		"new target seed is explicit while original source seed and roster evidence stay fixed"
	)
	var absent: Dictionary = payload.duplicate(true)
	absent.erase("origin")
	check(
		(
			Owner
			. project(
				{},
				{
					"op": "create",
					"request_id": "missing-origin",
					"expected_revision": 0,
					"payload": absent
				}
			)
			. is_empty()
		),
		"new access owner cannot admit arbitrary snapshot without origin"
	)
	var path: String = (
		"user://closed-access-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	Store._test_stop_after = "intent.rename"
	var outcome: Dictionary = Store.create(payload, path)
	print(
		"ACCESS_CREATE_DIAGNOSTIC status=",
		outcome.get("status"),
		" reason=",
		outcome.get("reason"),
		" path=",
		path
	)
	if FileAccess.file_exists(path + ".intent"):
		var raw_intent: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(path + ".intent")
		)
		var raw_after: Dictionary = Store._record_valid(raw_intent.after, path)
		print(
			"ACCESS_INTENT_DIAGNOSTIC record=",
			not raw_after.is_empty(),
			" owner=",
			not Owner.normalize(raw_intent.after.owner).is_empty(),
			" transition=",
			Owner.transition_valid({}, raw_intent.after.owner, raw_intent.receipt),
			" origin=",
			Owner.origin_intent_valid(raw_intent.after.owner, raw_intent.origin)
		)
		print(
			"ACCESS_NORMALIZE_DIAGNOSTIC lineage=",
			not Lineage.normalize(raw_intent.after.owner.lineage).is_empty(),
			" slot=",
			Owner._slot_valid(raw_intent.after.owner.dynasty, true),
			" frontier=",
			Owner._frontier_valid(raw_intent.after.owner.dynasty.frontier),
			" numeric_membership=",
			80.0 in [79, 80]
		)
	Store._test_stop_after = ""
	check(
		outcome.status == "not_committed" and Store.inspect(path).status == "pending",
		"exact origin create locks durable source-only intent"
	)
	var intent: Dictionary = Store._read_intent(path)
	check(
		intent.get("version") == 2 and intent.has("origin"),
		"new intent explicitly versions separate origin evidence"
	)
	if intent.is_empty():
		return
	var original_intent: String = FileAccess.get_file_as_string(path + ".intent")
	var reference: Dictionary = intent.origin.reference
	var files: Array[String] = []
	var texts: Array[String] = []
	for replica: String in ["a", "b"]:
		var object_path: String = Store._object_path(path, reference, replica)
		files.append(object_path)
		texts.append(FileAccess.get_file_as_string(object_path))
		check(
			FileAccess.file_exists(object_path), "exact bounded origin replica prepared " + replica
		)
		DirAccess.remove_absolute(object_path)
	outcome = Store.retry_pending(path)
	check(
		outcome.status == "blocked" and not FileAccess.file_exists(path),
		"missing origin blocks cold precommit without primary mutation"
	)
	check(
		FileAccess.get_file_as_string(path + ".intent") == original_intent,
		"blocked origin leaves exact intent unchanged"
	)
	for index in range(files.size()):
		var file: FileAccess = FileAccess.open(files[index], FileAccess.WRITE)
		file.store_string(texts[index])
		file.close()
	var changed: Dictionary = payload.duplicate(true)
	changed.origin.seed += 1
	check(
		Store.create(changed, path).status == "blocked",
		"changed origin cannot replace pending create"
	)
	check(
		(
			(
				Store
				. commit(
					{
						"op": "create",
						"request_id": intent.after.owner.last_action.id,
						"expected_revision": 0,
						"payload": changed
					},
					path
				)
				. status
			)
			== "blocked"
		),
		"same request ID cannot change origin operands"
	)
	outcome = Store.retry_pending(path)
	check(outcome.status == "committed", "exact restored origin cold retry commits")
	var restored: Dictionary = Store.restore(path)
	check(
		restored.status == "committed" and restored.get("qualified_selected_season") is SeasonState,
		"committed selected source fully read-back qualified"
	)
	# Origin is deliberately not required again after proven primary commit.
	for object_path: String in files:
		if FileAccess.file_exists(object_path):
			DirAccess.remove_absolute(object_path)
	check(
		Store.restore(path).status == "committed",
		"unavailable historical origin cannot undo proven target"
	)
	var forged: Dictionary = payload.duplicate(true)
	forged.snapshot.access.progress.major_start = true
	forged.snapshot.dynasty_start.access.progress.major_start = true
	forged.snapshot.checkpoint.checkpoint.build.major_start = true
	forged.snapshot.checkpoint.checkpoint.build.dynasty_start.access.progress.major_start = true
	forged.lineage.start_profile.access.progress.major_start = true
	forged.lineage.current_profile.access.progress.major_start = true
	check(
		(
			Owner
			. project(
				{},
				{
					"op": "create",
					"request_id": "forged-origin",
					"expected_revision": 0,
					"payload": forged
				}
			)
			. is_empty()
		),
		"self-consistent flags and recomputed hashes cannot replace source entitlement"
	)
	if restored.status == "committed":
		_alternate_tamper(path, restored.owner)
		_plain_rollover(path, profile.access)


func _alternate_tamper(path: String, before: Dictionary) -> void:
	var candidate: SeasonState = SeasonState.create_closed_league(
		13010, LeagueRules.capture("standard"), true, before.lineage.current_profile.access
	)
	var request: Dictionary = {
		"op": "switch",
		"request_id": "new-access-standard",
		"expected_revision": before.revision,
		"target": "other",
		"session_id": "standard:13010",
		"snapshot": SeasonSave.snapshot(candidate)
	}
	Store._test_stop_after = "intent.rename"
	var outcome: Dictionary = Store.commit(request, path)
	Store._test_stop_after = ""
	check(
		outcome.status == "not_committed" and Store.inspect(path).status == "pending",
		"new alternate access stops before primary commit"
	)
	var intent: Dictionary = Store._read_intent(path)
	if intent.is_empty():
		return
	var accepted: String = FileAccess.get_file_as_string(path + ".intent")
	var primary: String = FileAccess.get_file_as_string(path)
	var donor: Dictionary = cold(before.lineage.current_profile.access)
	donor.progress.major_start = true
	var forged_season: SeasonState = SeasonState.create_closed_league(
		13010, LeagueRules.capture("standard"), true, donor
	)
	var forged_snapshot: Dictionary = SeasonSave.snapshot(forged_season)
	check(
		SeasonSave._decode(forged_snapshot) != null,
		"controlled context envelope alone is consistency not origin authority"
	)
	var material: Dictionary = Owner._material(forged_snapshot)
	var forged: Dictionary = cold(intent)
	forged.after.owner.other = Owner._slot(
		request.session_id, material.reference, forged_snapshot, forged_season
	)
	var changed: Dictionary = request.duplicate(true)
	changed.snapshot = forged_snapshot
	forged.after.owner.last_action.fingerprint = Owner.fingerprint(changed)
	forged.receipt.fingerprint = Owner.fingerprint(changed)
	forged.receipt.after_hash = Owner.fingerprint(forged.after.owner)
	forged.receipt.new_references = [material.reference]
	check(
		not Owner.normalize(forged.after.owner).is_empty(),
		"forged alternate compact hashes remain internally consistent"
	)
	check(
		not Owner.transition_valid(before, forged.after.owner, forged.receipt),
		"compact new-alternate entitlement identity rejects before file writes"
	)
	check(
		not Owner.request_binding_valid(before, forged.after.owner, forged_snapshot),
		"cold typed request binding independently rejects greater-access alternate"
	)
	check(
		Store._stage_snapshots(path, forged.after.owner, material.snapshots),
		"controlled forged target bytes staged in isolated test only"
	)
	var file: FileAccess = FileAccess.open(path + ".intent", FileAccess.WRITE)
	file.store_string(JSON.stringify(forged, "", true, true))
	file.close()
	check(
		Store.inspect(path).status == "blocked",
		"strict intent admission rejects forged alternate entitlement"
	)
	check(
		(
			Store.retry_pending(path).status == "blocked"
			and FileAccess.get_file_as_string(path) == primary
		),
		(
			"cold forged greater-access alternate cannot bypass source-qualified entitlement by "
			+ "recomputing hashes"
		)
	)
	file = FileAccess.open(path + ".intent", FileAccess.WRITE)
	file.store_string(accepted)
	file.close()
	check(
		Store.inspect(path).status == "pending",
		"restored original alternate intent is still an admissible pending transition"
	)
	check(
		Store.retry_pending(path).status == "committed",
		"untouched exact alternate intent can still commit after restoring its evidence"
	)
	var returned: Dictionary = Store.restore(path)
	check(
		(
			returned.status == "committed"
			and (
				returned.qualified_selected_season._closed_access
				== before.lineage.current_profile.access
			)
		),
		"alternate publication preserves original captured baseline"
	)


func _plain_rollover(path: String, original_access: Dictionary) -> void:
	var owner: Dictionary = Store.inspect(path).owner
	var outcome: Dictionary = Store.commit(
		{
			"op": "switch",
			"request_id": "back-for-access-rollover",
			"expected_revision": owner.revision,
			"target": "dynasty"
		},
		path
	)
	check(outcome.status == "committed", "return preserves exact access-bearing Dynasty")
	if outcome.status != "committed":
		return
	owner = outcome.owner
	outcome = Store.commit(
		{
			"op": "close",
			"request_id": "access-abandon",
			"expected_revision": owner.revision,
			"session_id": owner.dynasty.session_id,
			"reason": "abandon"
		},
		path
	)
	check(outcome.status == "committed", "source-qualified access season closes without decay")
	if outcome.status != "committed":
		return
	owner = outcome.owner
	var request: Dictionary = {
		"op": "begin_next",
		"request_id": "access-next",
		"expected_revision": owner.revision,
		"seed": 13011
	}
	outcome = Store.commit(request, path)
	check(
		outcome.status == "committed" and outcome.owner.lineage.ordinal == 2,
		"ordinary-capacity access next season commits"
	)
	if outcome.status != "committed":
		return
	var season: SeasonState = outcome.get("qualified_selected_season")
	check(
		(
			season != null
			and season._closed_access == original_access
			and season.build.cash() == 0
			and season.build._major.player == ""
			and season.build._bank.view().sponsors.is_empty()
		),
		"access retained but no Cash, sponsor, nominee or extra slot inherited"
	)
	var repeat: Dictionary = Store.commit(request, path)
	check(
		repeat.status == "committed" and repeat.revision == outcome.revision,
		"exact access rollover retry cannot decay twice"
	)
	var changed: Dictionary = request.duplicate(true)
	changed.seed += 1
	check(
		Store.commit(changed, path).status == "blocked",
		"same next request cannot substitute target seed"
	)
	check(Store.restore(path).status == "committed", "access successor cold owner restore")

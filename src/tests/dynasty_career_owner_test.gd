extends Node
## Source-qualified pause/abandon/resume/rollover and transactional retry controls.
## Synthetic compact legacy title prefix permits new enrollment; no physical games.
## No positive completion-credit qualification is claimed.

const UnlockFixture = preload("res://src/tests/league_unlock_fixture.gd")
const Replay = preload("res://src/gameplay/season/dynasty_career_owner_replay.gd")
const V2 = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
const LegacyOwner = preload("res://src/gameplay/season/dynasty_owner.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
var checks: int = 0
var failures: int = 0
var path: String = ""


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var root: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--dynasty-career-test-root="):
			root = argument.trim_prefix("--dynasty-career-test-root=")
	if (
		not root.is_absolute_path()
		or root.length() < 2
		or root != root.simplify_path()
		or DirAccess.dir_exists_absolute(root)
	):
		push_error("Fresh absolute --dynasty-career-test-root= required; no tests ran.")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		get_tree().quit(2)
		return
	path = root.path_join("owner.json")
	_run()
	Store._test_stop_after = ""
	print("Dynasty career owner checks: %d, failures: %d, physical games: 0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _run() -> void:
	_tier_request_units()
	var prepared: Dictionary = {}
	check(
		not V2._add_snapshot(prepared, {"padding": "x".repeat(Store.MAX_SNAPSHOT_BYTES)}),
		"oversized outer-object preparation refuses without missing-field error"
	)
	check(prepared.is_empty(), "oversized object prepares no durable payload")
	var source: SeasonState = SeasonState.create(13002, false, true, true)
	# Use an alternate-league title ladder for this nonphysical source fixture.
	# Standard tier history requires its full public stadium/save context.
	source.career = UnlockFixture.prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1},
		{"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3}
	])
	check(source.career != null, "synthetic legacy tier-3 unlock prefix validates")
	if source.career == null:
		return
	check(source.career.start(source), "origin career starts normally")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin draft pick")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "joint-lineage", "joint-owner")
	var season: SeasonState = Bridge.create(profile)
	if season == null:
		check(false, "qualified Dynasty construction")
		return
	var a_snapshot: Dictionary = Save.wrap_checkpoint(
		SeasonSave.snapshot(season),
		Save.binding_for(season, "joint-owner", "joint-lineage", 0, 1, "joint-lineage:1")
	)
	check(
		Save.core(a_snapshot.checkpoint) == LegacyOwner._core(a_snapshot.checkpoint),
		"Base raw-core extraction remains byte-equivalent"
	)
	check(
		(
			Replay.frontier(a_snapshot.checkpoint, season)
			== LegacyOwner._frontier(a_snapshot.checkpoint, season)
		),
		"Base journal frontier remains exactly historical"
	)
	var payload: Dictionary = {
		"lineage": Lineage.create(profile),
		"snapshot": a_snapshot,
		"session_id": "joint-lineage:1",
		"origin": origin
	}
	var historical: Dictionary = payload.duplicate(true)
	historical.snapshot = a_snapshot.checkpoint.duplicate(true)
	var legacy_request: Dictionary = {
		"op": "create",
		"request_id": "legacy-control",
		"expected_revision": 0,
		"payload": historical
	}
	var legacy: Dictionary = LegacyOwner.project({}, legacy_request)
	var dispatched: Dictionary = Owner.project({}, legacy_request)
	check(not legacy.is_empty() and not dispatched.is_empty(), "v1 source remains admitted")
	for field: String in ["owner", "receipt", "snapshots", "origin"]:
		check(dispatched.get(field) == legacy.get(field), "v1 exact dispatch field: " + field)
	Store._test_stop_after = "intent.rename"
	var interrupted: Dictionary = Store.create(payload, path)
	Store._test_stop_after = ""
	check(interrupted.status == "not_committed", "interrupted create grants no committed owner: " + str(interrupted))
	check(Store.inspect(path).status == "pending", "exact admitted intent survives interruption")
	var altered: Dictionary = payload.duplicate(true)
	altered.snapshot.session.access_sha256 = "0".repeat(64)
	check(Store.create(altered, path).status == "blocked", "changed retry cannot replace intent")
	var created: Dictionary = Store.create(payload, path)
	check(created.status == "committed", "joint owner creation commits: " + str(created))
	if created.status != "committed":
		return
	var initial: Dictionary = created.owner
	for invalid_version: Variant in [83.5, "83", null, true]:
		var invalid: Dictionary = initial.duplicate(true)
		invalid.dynasty.snapshot_version = invalid_version
		check(Owner.normalize(invalid).is_empty(), "malformed snapshot version refused")
	check(not Owner.normalize(JSON.parse_string(JSON.stringify(initial))).is_empty(),
		"owner accepts its own JSON numeric representation")
	check(initial.version == 2 and initial.career.version == 28, "explicit new authorities")
	check(Store.create(payload, path).owner == initial, "creation exact retry is idempotent")
	check(Store.restore(path).status == "committed", "cold wrapper and authority qualification")
	for malformed: Variant in [null, 7]:
		var invalid: Dictionary = initial.duplicate(true)
		invalid.raw_references.other = malformed
		check(Owner.normalize(invalid).is_empty(), "malformed raw reference refuses without error")
	for malformed: Variant in [null, {}, {"origin": {}}, {"snapshot": {}}]:
		var invalid: Dictionary = initial.duplicate(true)
		invalid.operands.payload = malformed
		check(Owner.normalize(invalid).is_empty(), "malformed persisted create operands refused")
		check(
			not Owner.request_binding_valid({}, invalid, a_snapshot, {}, origin),
			"malformed cold request binding refuses without error"
		)
	var malformed_next: Dictionary = initial.duplicate(true)
	malformed_next.last_action.kind = "begin_next"
	malformed_next.pending_next = {"unexpected": true}
	check(
		Owner.normalize(malformed_next).is_empty(),
		"malformed pending request refuses before legacy fingerprint reconstruction"
	)
	_pause_other(initial, a_snapshot)


func _step(op: String, operands: Dictionary) -> Dictionary:
	var owner: Dictionary = Store.inspect(path).get("owner", {})
	if owner.is_empty():
		return {}
	var request: Dictionary = {
		"op": op,
		"request_id": "case:%s:%d" % [op, owner.revision],
		"expected_revision": owner.revision
	}
	request.merge(operands)
	var result: Dictionary = Store.transact(request, path)
	check(result.status == "committed", "joint transition: " + op)
	if result.status == "committed":
		check(Store.transact(request, path).owner == result.owner, "exact retry: " + op)
	return result


func _pause_other(initial: Dictionary, a_snapshot: Dictionary) -> void:
	var other: SeasonState = SeasonState.create_closed_league(
		13003, LeagueRules.capture("standard"), true, Authority.access(initial.career)
	)
	if other == null:
		check(false, "other source construction")
		return
	for pick in range(4):
		check(other.choose_player(other.offers()[0]), "other draft pick")
	var b_snapshot: Dictionary = Save.wrap_checkpoint(
		SeasonSave.snapshot(other),
		Save.binding_for(other, initial.owner_id, initial.lineage.id, 0, 1, "other:1")
	)
	var switched: Dictionary = _step(
		"switch", {"target": "other", "session_id": "other:1", "snapshot": b_snapshot}
	)
	if switched.get("status") != "committed":
		return
	check(switched.owner.lineage.state == "paused", "Dynasty pauses rather than abandons")
	check(switched.owner.dynasty.reference == initial.dynasty.reference, "paused checkpoint exact")
	var closed: Dictionary = _step("close", {"session_id": "other:1", "reason": "abandon"})
	if closed.get("status") != "committed":
		return
	var settled: Dictionary = closed.owner.career.duplicate(true)
	check(settled.settlements.size() == 1, "other close has exactly one history entry")
	var resumed: Dictionary = _step("switch", {"target": "dynasty"})
	if resumed.get("status") != "committed":
		return
	check(resumed.owner.career == settled, "resume cannot rewind shared history or assets")
	var restored: Dictionary = Store.restore(path)
	check(restored.status == "committed", "resumed checkpoint fully qualifies")
	if restored.status != "committed":
		return
	var resumed_snapshot: Dictionary = Save.capture(restored.qualified_selected_season)
	check(Profile.same(resumed_snapshot, a_snapshot), "resume baseline transport-exact")
	check(Save.snapshot_reference(resumed_snapshot) == Save.snapshot_reference(a_snapshot),
		"resume baseline retains exact canonical bytes")
	check(
		resumed.owner.lineage.current_profile.roster == initial.lineage.current_profile.roster,
		"pause and other abandon never discard Dynasty roster"
	)
	_rollover(resumed.owner)


func _rollover(owner: Dictionary) -> void:
	var closed: Dictionary = _step(
		"close", {"session_id": owner.dynasty.session_id, "reason": "abandon"}
	)
	if closed.get("status") != "committed":
		return
	var locked: Dictionary = Store.transact(
		{
			"op": "begin_next",
			"request_id": "locked-tier",
			"expected_revision": closed.owner.revision,
			"seed": 13004,
			"tier": 1
		},
		path
	)
	check(locked.status == "blocked", "Dynasty d1 requires its own completed Base championship")
	check(Store.inspect(path).owner == closed.owner, "locked tier cannot mutate lineage or bank")
	var expected: Dictionary = Profile.decay(closed.owner.lineage.current_profile)
	check(not expected.is_empty(), "unplayed profile has a deterministic decay projection")
	if expected.is_empty():
		return
	var next: Dictionary = _step("begin_next", {"seed": 13004})
	if next.get("status") != "committed":
		return
	check(
		next.owner.lineage.ordinal == 2 and next.owner.lineage.generation == 1,
		"exactly one next generation"
	)
	check(
		next.owner.lineage.start_profile.players == expected.profile.players,
		"unchanged exact decay applied once"
	)
	check(
		next.owner.lineage.start_profile.roster == owner.lineage.current_profile.roster,
		"abandonment permanently retains roster"
	)
	check(next.owner.career.settlements.size() == 2, "rollover does not duplicate settlement")
	check(next.owner.career.assets == owner.career.assets, "abandonments never grant completion CB")
	check(
		next.owner.lineage.start_profile.access == Authority.access(closed.owner.career),
		"fresh access derives from unique shared contributions"
	)
	_choice_operand_units(next.owner)
	var wrong_next: Dictionary = next.owner.duplicate(true)
	wrong_next.operands.seed += 1
	check(Owner.normalize(wrong_next).is_empty(), "next request seed remains fingerprint-bound")
	wrong_next.last_action.fingerprint = LegacyOwner.fingerprint(wrong_next.operands)
	check(
		Owner.normalize(wrong_next).is_empty(),
		"next request seed matches actual lineage transition"
	)
	wrong_next = next.owner.duplicate(true)
	wrong_next.dynasty.snapshot_version = Save.TIER_VERSION
	check(Owner.normalize(wrong_next).is_empty(), "Base session cannot masquerade as Save85")
	var forged: Dictionary = next.owner.duplicate(true)
	forged.lineage.access_rebase.source_access.progress.supply_start = (
		(int(forged.lineage.access_rebase.source_access.progress.supply_start) + 1) % 4
	)
	check(Owner.normalize(forged).is_empty(), "rebase cannot rewrite original decay source access")
	forged = next.owner.duplicate(true)
	forged.lineage.access_rebase.target_sha256 = "0".repeat(64)
	check(Owner.normalize(forged).is_empty(), "effective start access is digest-bound")
	var readback: Dictionary = Store.restore(path)
	check(readback.status == "committed", "next-generation cold source readback")
	if readback.status != "committed":
		return
	var bad: Dictionary = Save.capture(readback.qualified_selected_season)
	bad.session.access_sha256 = "0".repeat(64)
	var refused: Dictionary = Store.transact(
		{
			"op": "checkpoint",
			"request_id": "wrong-access",
			"expected_revision": next.owner.revision,
			"session_id": next.owner.dynasty.session_id,
			"snapshot": bad
		},
		path
	)
	check(refused.status == "blocked", "wrong starting access fails closed")
	check(Store.inspect(path).owner == next.owner, "refused checkpoint preserves authority")


func _tier_request_units() -> void:
	var request: Dictionary = {
		"op": "begin_next", "request_id": "typed-next", "expected_revision": 7, "seed": 13004
	}
	check(V2._request_valid(request), "historical Base next request remains valid")
	for tier in range(5):
		request["tier"] = tier
		check(V2._request_valid(request), "typed next-tier request shape: %d" % tier)
	for invalid: Variant in [-1, 5, 0.5, "1", null, true]:
		request.tier = invalid
		check(not V2._request_valid(request), "invalid tier request refuses")
	check(
		not V2._request_valid(
			{
				"op": "choose_next",
				"request_id": "choice",
				"expected_revision": 7,
				"pending_id": "pending",
				"choices": {},
				"tier": 2
			}
		),
		"overflow continuation cannot replace captured tier"
	)
	var pending: Dictionary = {
		"pending_next": {"id": "shape-only"},
		"pending_tier": 3,
		"pending_rules": LeagueRules.capture_tier("dynasty", 3)
	}
	check(V2._pending_rules_valid(pending), "pending tier/rules metadata agrees")
	pending.pending_rules = LeagueRules.capture_tier("dynasty", 2)
	check(not V2._pending_rules_valid(pending), "pending tier/rules substitution refuses")
	pending.pending_next = null
	check(not V2._pending_rules_valid(pending), "malformed pending container refuses")


func _choice_operand_units(source: Dictionary) -> void:
	# Compact-operand units only, not an admitted owner or an exercised overflow.
	var owner: Dictionary = source.duplicate(true)
	var request: Dictionary = {
		"op": "choose_next",
		"request_id": "shape-choice",
		"expected_revision": owner.last_action.expected_revision,
		"pending_id": owner.lineage.last_transition.request.id,
		"choices": owner.lineage.last_transition.request.overflow_choices.duplicate(true)
	}
	owner.operands = request.duplicate(true)
	owner.last_action.kind = "choose_next"
	owner.last_action.id = request.request_id
	owner.last_action.fingerprint = LegacyOwner.fingerprint(request)
	check(V2._operands_valid(owner), "compact choose operands match represented transition")
	owner.operands.choices = {"unknown": 0}
	owner.last_action.fingerprint = LegacyOwner.fingerprint(owner.operands)
	check(
		not V2._operands_valid(owner),
		"rehashing changed overflow choices cannot replace transition"
	)
	owner.operands = request.duplicate(true)
	owner.operands.pending_id = "wrong"
	owner.last_action.fingerprint = LegacyOwner.fingerprint(owner.operands)
	check(
		not V2._operands_valid(owner),
		"rehashing changed pending identity cannot replace transition"
	)

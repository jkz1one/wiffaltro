extends RefCounted
## Stateless validation with original script constants and Callables supplied by the owner.


static func _request_valid(
	source_ops: Array[String], source_profile: GDScript, source_max_revision: int, request: Variant
) -> bool:
	if (
		not request is Dictionary
		or request.get("op") not in source_ops
		or not source_profile.token(request.get("request_id"))
		or not source_profile.whole(request.get("expected_revision"), 0, source_max_revision - 1)
	):
		return false
	var fields: Array = ["op", "request_id", "expected_revision"]
	match request.op:
		"create":
			fields.append("payload")
			var payload_fields: Array = ["lineage", "snapshot", "session_id"]
			if request.get("payload") is Dictionary and request.payload.has("origin"):
				payload_fields.append("origin")
				if not request.payload.origin is Dictionary:
					return false
			if (
				request.expected_revision != 0
				or not source_profile.keys(request.get("payload"), payload_fields)
				or not request.payload.lineage is Dictionary
				or not request.payload.snapshot is Dictionary
				or not source_profile.token(request.payload.session_id)
			):
				return false
		"checkpoint":
			fields.append_array(["session_id", "snapshot"])
			if (
				not source_profile.token(request.get("session_id"))
				or not request.get("snapshot") is Dictionary
			):
				return false
		"switch":
			fields.append("target")
			if request.get("target") not in ["dynasty", "other"]:
				return false
			if request.has("snapshot") or request.has("session_id"):
				fields.append_array(["snapshot", "session_id"])
				if (
					not request.get("snapshot") is Dictionary
					or not source_profile.token(request.get("session_id"))
				):
					return false
		"close":
			fields.append_array(["session_id", "reason"])
			if (
				not source_profile.token(request.get("session_id"))
				or request.get("reason") not in ["complete", "abandon"]
			):
				return false
		"begin_next":
			fields.append("seed")
			if not source_profile.whole(request.get("seed"), 0, 2147483647):
				return false
		"choose_next":
			fields.append_array(["pending_id", "choices"])
			if (
				not source_profile.token(request.get("pending_id"))
				or not request.get("choices") is Dictionary
			):
				return false
	return source_profile.keys(request, fields)


static func _decode(
	source_profile: GDScript, source_max_snapshot_bytes: int, snapshot: Variant, dynasty: bool
) -> SeasonState:
	if (
		not snapshot is Dictionary
		or not source_profile.whole(snapshot.get("version"), 75, 80)
		or (
			int(snapshot.version) not in [79, 80]
			if dynasty
			else int(snapshot.version) not in [75, 76, 77, 78, 80]
		)
	):
		return null
	if JSON.stringify(snapshot, "", true, true).to_utf8_buffer().size() > source_max_snapshot_bytes:
		return null
	var season: SeasonState = SeasonSave._decode(snapshot)
	if (
		season == null
		or season.build == null
		or season.opponents == null
		or season.league_rules.is_empty()
		or LeagueRules.dynasty(season.league_rules) != dynasty
	):
		return null
	return season


static func _validate_slot(
	source_decode: Callable,
	source_slot: Callable,
	source_profile: GDScript,
	source_current_matches: Callable,
	slot: Dictionary,
	snapshot: Dictionary,
	lineage: Dictionary
) -> SeasonState:
	var season: SeasonState = source_decode.call(snapshot, not lineage.is_empty())
	if season == null:
		return null
	var expected: Dictionary = source_slot.call(slot.session_id, slot.reference, snapshot, season)
	if (
		not source_profile.same(slot, expected)
		or (
			not lineage.is_empty()
			and not source_profile.same(season._dynasty_start, lineage.start_profile)
		)
	):
		return null
	if not lineage.is_empty() and not source_current_matches.call(lineage, season):
		return null
	return season


static func _current_matches(
	source_profile: GDScript, lineage: Dictionary, season: SeasonState
) -> bool:
	# The caller already fully decoded this exact source. Extract, do not replay
	# again, and do not let a compact profile become independently authoritative.
	var current: Dictionary = source_profile._capture(
		season.build, lineage.id, lineage.owner_id, int(lineage.ordinal), "season-replay"
	)
	return not current.is_empty() and source_profile.same(current, lineage.current_profile)


static func _material(source_max_snapshot_bytes: int, snapshot: Dictionary) -> Dictionary:
	var encoded: String = JSON.stringify(snapshot, "", true, true)
	var size: int = encoded.to_utf8_buffer().size()
	if size < 1 or size > source_max_snapshot_bytes:
		return {}
	var digest: String = encoded.sha256_text()
	return {"reference": {"sha256": digest, "bytes": size}, "snapshots": {digest: encoded}}


static func _origin_material(source_material: Callable, snapshot: Dictionary) -> Dictionary:
	# Explicit new origin role alone uses transport-canonical bytes. Legacy
	# session object representation remains byte-for-byte unchanged.
	var raw: Dictionary = source_material.call(snapshot)
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw.snapshots[raw.reference.sha256])
	return source_material.call(parsed) if parsed is Dictionary else {}


static func _slot(
	source_fingerprint: Callable,
	source_frontier: Callable,
	session_id: String,
	reference: Dictionary,
	snapshot: Dictionary,
	season: SeasonState
) -> Dictionary:
	return {
		"session_id": session_id,
		"reference": reference,
		"snapshot_version": int(snapshot.version),
		"profile": LeagueRules.normalized(season.league_rules),
		"seed": season.season_seed,
		"start_hash":
		(
			source_fingerprint.call(season._dynasty_start)
			if LeagueRules.dynasty(season.league_rules)
			else (source_fingerprint.call(season._closed_access) if snapshot.version == 80 else "")
		),
		"checkpoint_revision": season.build.revision(),
		"frontier": source_frontier.call(snapshot, season)
	}


static func _slot_valid(
	source_profile: GDScript,
	source_reference_valid: Callable,
	source_frontier_valid: Callable,
	source_lineage: GDScript,
	slot: Variant,
	dynasty: bool
) -> bool:
	if (
		not source_profile.keys(
			slot,
			[
				"session_id",
				"reference",
				"snapshot_version",
				"profile",
				"seed",
				"start_hash",
				"checkpoint_revision",
				"frontier"
			]
		)
		or not source_profile.token(slot.session_id)
		or not source_reference_valid.call(slot.reference)
		or not source_profile.whole(slot.snapshot_version, 75, 80)
		or (int(slot.snapshot_version) not in [79, 80] if dynasty else slot.snapshot_version == 79)
		or not source_profile.whole(slot.seed, 0, 2147483647)
		or LeagueRules.normalized(slot.profile).is_empty()
		or LeagueRules.dynasty(slot.profile) != dynasty
		or not LeagueRules.season_matches(slot.profile, slot.seed)
		or not source_profile.whole(slot.checkpoint_revision, 0, SeasonBuild.MAX_EVENTS)
		or not source_frontier_valid.call(slot.frontier)
		or slot.checkpoint_revision != slot.frontier.builds["0"].revision
	):
		return false
	return (
		source_lineage._digest(slot.start_hash)
		if dynasty or slot.snapshot_version == 80
		else slot.start_hash == ""
	)


static func _canonical_slot(slot: Dictionary) -> Dictionary:
	slot.snapshot_version = int(slot.snapshot_version)
	slot.seed = int(slot.seed)
	slot.checkpoint_revision = int(slot.checkpoint_revision)
	slot.reference.bytes = int(slot.reference.bytes)
	slot.profile = LeagueRules.normalized(slot.profile)
	for field: String in ["result_count", "report_count", "phase", "champion"]:
		slot.frontier[field] = int(slot.frontier[field])
	for row: Dictionary in slot.frontier.builds.values():
		row.revision = int(row.revision)
		row.decision_count = int(row.decision_count)
	return slot


static func _core(snapshot: Dictionary) -> Dictionary:
	var closed: Dictionary = (
		snapshot.checkpoint if int(snapshot.get("version", 0)) in [78, 79, 80] else snapshot
	)
	return closed.get("checkpoint", {})


static func _frontier(
	source_core: Callable,
	source_lineage: GDScript,
	source_fingerprint: Callable,
	source_exit_ready: Callable,
	snapshot: Dictionary,
	season: SeasonState
) -> Dictionary:
	var core: Dictionary = source_core.call(snapshot)
	var builds: Dictionary = {}
	for index in range(6):
		var key: String = str(index)
		var club: Dictionary = {} if index == 0 else core.opponents.clubs.get(key, {})
		var data: Dictionary = core.build if index == 0 else club.get("build", {})
		var decisions: Array = [] if index == 0 else club.get("decisions", [])
		var count: int = data.get("events", []).size()
		builds[key] = {
			"present": not data.is_empty(),
			"revision": count,
			"header_hash": source_lineage._capture_header(data),
			"prefix_hash":
			(
				source_lineage._capture_prefix(data, count)
				if not data.is_empty()
				else source_fingerprint.call({})
			),
			"decision_count": decisions.size(),
			"decision_hash": source_fingerprint.call(decisions)
		}
	var physical: Dictionary = core.get("physical", {"reports": [], "pending": {}})
	var header: Dictionary = {}
	for key: String in ["version", "seed", "pool", "draws"]:
		header[key] = core[key]
	var opponent_header: Dictionary = core.opponents.duplicate()
	opponent_header.erase("clubs")
	opponent_header.erase("draft_order")
	header["opponents"] = opponent_header
	if snapshot.version == 80:
		header["access"] = snapshot.access
	return {
		"header_hash": source_fingerprint.call(header),
		"builds": builds,
		"draft_picks": core.picks.duplicate(),
		"allocation_hash": source_fingerprint.call(core.opponents.get("draft_order", [])),
		"result_count": core.results.size(),
		"result_hash": source_fingerprint.call(core.results),
		"report_count": physical.reports.size(),
		"report_hash": source_fingerprint.call(physical.reports),
		"pending_hash": source_fingerprint.call(physical.pending),
		"phase": int(season.phase),
		"champion": season.champion,
		"exit_ready": source_exit_ready.call(season)
	}


static func _frontier_valid(
	source_profile: GDScript, source_lineage: GDScript, source_fingerprint: Callable, value: Variant
) -> bool:
	if (
		not source_profile.keys(
			value,
			[
				"header_hash",
				"builds",
				"draft_picks",
				"allocation_hash",
				"result_count",
				"result_hash",
				"report_count",
				"report_hash",
				"pending_hash",
				"phase",
				"champion",
				"exit_ready"
			]
		)
		or not source_profile.keys(value.builds, ["0", "1", "2", "3", "4", "5"])
		or not value.draft_picks is Array
		or value.draft_picks.size() > 4
		or (value.draft_picks.size() < 4) != (value.phase == SeasonState.Phase.DRAFT)
		or not source_profile.whole(value.result_count, 0, 33)
		or not source_profile.whole(value.report_count, 0, 23)
		or not source_profile.whole(
			value.phase, SeasonState.Phase.DRAFT, SeasonState.Phase.COMPLETE
		)
		or not source_profile.whole(value.champion, -1, 5)
		or not value.exit_ready is bool
		or (value.phase == SeasonState.Phase.COMPLETE) != (value.champion >= 0)
	):
		return false
	for field: String in [
		"header_hash", "allocation_hash", "result_hash", "report_hash", "pending_hash"
	]:
		if not source_lineage._digest(value[field]):
			return false
	var seen: Array = []
	for player: Variant in value.draft_picks:
		if (
			not player is String
			or seen.has(player)
			or SeasonPlayerCatalog.profile(player).is_empty()
		):
			return false
		seen.append(player)
	for key: String in value.builds:
		var row: Variant = value.builds[key]
		if (
			not source_profile.keys(
				row,
				[
					"present",
					"revision",
					"header_hash",
					"prefix_hash",
					"decision_count",
					"decision_hash"
				]
			)
			or not row.present is bool
			or not source_profile.whole(row.revision, 0, SeasonBuild.MAX_EVENTS)
			or not source_profile.whole(row.decision_count, 0, SeasonBuild.MAX_EVENTS)
		):
			return false
		for field: String in ["header_hash", "prefix_hash", "decision_hash"]:
			if not source_lineage._digest(row[field]):
				return false
		if row.present != (key == "0" or value.draft_picks.size() == 4):
			return false
		if (
			not row.present
			and (
				row.revision != 0
				or row.decision_count != 0
				or row.header_hash != source_fingerprint.call({})
				or row.prefix_hash != source_fingerprint.call({})
				or row.decision_hash != source_fingerprint.call([])
			)
		):
			return false
	return true


static func _exit_ready(season: SeasonState) -> bool:
	if season.physical != null and not season.physical.pending.is_empty():
		return false
	if season.build == null or season.build.pack_pending():
		return false
	if not season.inventory_rules.is_empty():
		return SeasonInventoryRules.menu_available(season.build)
	# Closed noninventory sources cannot discard an unfulfilled pregame.
	for game: String in season.build._pregames:
		if not season.build._bank.view().rewards.has(game):
			return false
	return true


static func _capture(
	source_profile: GDScript,
	source_core: Callable,
	source_lineage: GDScript,
	lineage: Dictionary,
	season: SeasonState,
	snapshot: Dictionary
) -> Dictionary:
	if (
		lineage.state != "active"
		or not source_profile.same(season._dynasty_start, lineage.start_profile)
	):
		return {}
	var current: Dictionary = source_profile._capture(
		season.build, lineage.id, lineage.owner_id, int(lineage.ordinal), "season-replay"
	)
	if current.is_empty() or current.roster != lineage.start_profile.roster:
		return {}
	var data: Dictionary = source_core.call(snapshot).build
	var header: String = source_lineage._capture_header(data)
	var revision: int = season.build.revision()
	var previous: Dictionary = lineage.get("capture", {})
	if not previous.is_empty():
		if (
			revision < previous.revision
			or header != previous.header_hash
			or source_lineage._capture_prefix(data, int(previous.revision)) != previous.prefix_hash
		):
			return {}
		if revision == previous.revision:
			return lineage if source_profile.same(current, lineage.current_profile) else {}
	var next: Dictionary = lineage.duplicate(true)
	next.version = source_lineage.CAPTURE_VERSION
	next.current_profile = current
	next["capture"] = {
		"version": 1,
		"season_id": "%s:%d" % [lineage.id, int(lineage.ordinal)],
		"revision": revision,
		"header_hash": header,
		"prefix_hash": source_lineage._capture_prefix(data, revision),
		"profile_hash": source_lineage.fingerprint(current),
		"previous_revision": int(previous.get("revision", 0)),
		"previous_prefix": previous.get("prefix_hash", "")
	}
	return source_lineage.normalize(next)


static func _same_session(source_profile: GDScript, before: Dictionary, after: Dictionary) -> bool:
	for key: String in ["session_id", "profile", "seed", "start_hash"]:
		if not source_profile.same(before[key], after[key]):
			return false
	return (
		before.snapshot_version == after.snapshot_version
		or (
			before.frontier.phase == SeasonState.Phase.DRAFT
			and after.frontier.phase != SeasonState.Phase.DRAFT
			and before.snapshot_version in [76, 77]
			and after.snapshot_version == 78
		)
	)


static func _capture_successor(
	source_profile: GDScript, source_lineage: GDScript, before: Dictionary, after: Dictionary
) -> bool:
	return (
		source_profile.same(before, after) or source_lineage.capture_transition_valid(before, after)
	)


static func _frontier_advances(
	source_prefix: Callable, before: Dictionary, after: Dictionary
) -> bool:
	if (
		before.header_hash != after.header_hash
		or not source_prefix.call(before.draft_picks, after.draft_picks)
		or after.result_count < before.result_count
		or after.report_count < before.report_count
	):
		return false
	if before.phase == SeasonState.Phase.DRAFT:
		for row: Dictionary in before.builds.values():
			if row.revision != 0 or row.decision_count != 0:
				return false
		return before.result_count == 0 and before.report_count == 0
	if before.allocation_hash != after.allocation_hash:
		return false
	for key: String in before.builds:
		var old: Dictionary = before.builds[key]
		var next: Dictionary = after.builds[key]
		if (
			old.present != next.present
			or old.header_hash != next.header_hash
			or next.revision < old.revision
			or next.decision_count < old.decision_count
			or (next.revision == old.revision and next.prefix_hash != old.prefix_hash)
			or (
				next.decision_count == old.decision_count
				and next.decision_hash != old.decision_hash
			)
		):
			return false
	return (
		(after.result_count != before.result_count or after.result_hash == before.result_hash)
		and (after.report_count != before.report_count or after.report_hash == before.report_hash)
	)


static func _extends(
	source_core: Callable,
	source_prefix: Callable,
	source_lineage: GDScript,
	source_pending_extends: Callable,
	before: Dictionary,
	after: Dictionary,
	frontier: Dictionary
) -> bool:
	var source: Dictionary = source_core.call(before)
	var next: Dictionary = source_core.call(after)
	if not source_prefix.call(source.picks, next.picks):
		return false
	if source.picks.size() < 4:
		return (
			source.build.events.is_empty()
			and source.opponents.clubs.is_empty()
			and source.results.is_empty()
			and source.get("physical", {}).get("pending", {}).is_empty()
		)
	for index in range(6):
		var key: String = str(index)
		var old_build: Dictionary = (
			source.build if index == 0 else source.opponents.clubs[key].build
		)
		var new_build: Dictionary = next.build if index == 0 else next.opponents.clubs[key].build
		var accepted: Dictionary = frontier.builds[key]
		if (
			new_build.events.size() < accepted.revision
			or old_build.events.size() != accepted.revision
			or source_lineage._capture_header(new_build) != accepted.header_hash
			or (
				source_lineage._capture_prefix(new_build, int(accepted.revision))
				!= accepted.prefix_hash
			)
		):
			return false
		if (
			index > 0
			and not source_prefix.call(
				source.opponents.clubs[key].decisions, next.opponents.clubs[key].decisions
			)
		):
			return false
	if not source_prefix.call(source.results, next.results):
		return false
	var old_physical: Dictionary = source.get("physical", {"reports": [], "pending": {}})
	var new_physical: Dictionary = next.get("physical", {"reports": [], "pending": {}})
	return (
		source_prefix.call(old_physical.reports, new_physical.reports)
		and source_pending_extends.call(source, next)
	)


static func _prefix(source_profile: GDScript, before: Array, after: Array) -> bool:
	return (
		after.size() >= before.size() and source_profile.same(before, after.slice(0, before.size()))
	)


static func _pending_extends(
	source_profile: GDScript,
	source_prefix: Callable,
	source_human_matches: Callable,
	before: Dictionary,
	after: Dictionary
) -> bool:
	var old: Dictionary = before.get("physical", {}).get("pending", {})
	if old.is_empty():
		return true
	var next: Dictionary = after.get("physical", {}).get("pending", {})
	if not next.is_empty():
		return (
			source_profile.same(old.human, next.human)
			and source_prefix.call(old.reports, next.reports)
		)
	# Settling may move accepted pending evidence into permanent archives, but
	# cannot replace its human report or one of its already completed AI games.
	var offset: int = before.physical.reports.size()
	if not source_prefix.call(old.reports, after.physical.reports.slice(offset)):
		return false
	for result: Dictionary in after.results.slice(before.results.size()):
		if result.id == old.human[0]:
			return source_human_matches.call(old.human, result)
	return false


static func _human_matches(source_profile: GDScript, human: Array, result: Dictionary) -> bool:
	if human.size() < 13 or result.away_runs != human[1] or result.home_runs != human[2]:
		return false
	var keys: Array[String] = [
		"performance",
		"used_gear",
		"tactics",
		"batting",
		"stances",
		"fielding",
		"pitching",
		"field_supply",
		"frozen"
	]
	for index in range(keys.size()):
		var expected: Variant = human[index + 3]
		var fallback: Variant = [] if expected is Array else {}
		if not source_profile.same(result.get(keys[index], fallback), expected):
			return false
	var opponent: String = str(int(result.away if result.home == 0 else result.home))
	if not source_profile.same(result.get("ai_tactics", {}).get(opponent, {}), human[12]):
		return false
	if (
		human.size() >= 14
		and human[13] is Array
		and not source_profile.same(result.get("doubleheader_evidence"), human[13])
	):
		return false
	if (
		SeasonRoundSettlement.inventory_result(human)
		and not source_profile.same(result.get("inventory_final"), human[-1])
	):
		return false
	return true


static func _has_reference(
	source_profile: GDScript, owner: Dictionary, reference: Dictionary
) -> bool:
	for name: String in ["dynasty", "other"]:
		if (
			not owner.get(name, {}).is_empty()
			and source_profile.same(owner[name].reference, reference)
		):
			return true
	return false


static func _pending_valid(source_lineage: GDScript, request: Variant, lineage: Dictionary) -> bool:
	return (
		source_lineage._request_valid(request, lineage.id)
		and request.source_generation == lineage.generation
		and request.source_ordinal == lineage.ordinal
	)


static func _has_overflow(profile: Dictionary) -> bool:
	for player: Dictionary in profile.players.values():
		var count: int = 0
		for ability: Dictionary in player.abilities:
			if ability.slot == "Fielding":
				count += 1
		if count > 1:
			return true
	return false

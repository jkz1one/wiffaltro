extends RefCounted
## Single-owner inert lifecycle. No gameplay admission, replacement entitlement,
## bank, recursive season history, or proof of historical authenticity is stored.

const Profile = preload("res://src/gameplay/season/dynasty_profile_contract.gd")
const _CAPTURE_SCRIPT_PATH: String = "res://src/gameplay/season/dynasty_start_profile.gd"
const VERSION: int = 1
const CAPTURE_VERSION: int = 2


static func create(profile: Variant) -> Dictionary:
	var start: Dictionary = Profile.normalize(profile)
	if start.is_empty() or start.season_ordinal != 1:
		return {}
	return normalize(
		{
			"version": VERSION,
			"id": start.lineage_id,
			"owner_id": start.owner_id,
			"generation": 0,
			"state": "active",
			"resume_state": "",
			"closed_reason": "",
			"ordinal": 1,
			"start_profile": start,
			"current_profile": start,
			"last_transition": {},
			"pending_replacement": {}
		}
	)


static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or not Profile.whole(value.get("version"), VERSION, CAPTURE_VERSION):
		return {}
	var fields: Array = [
		"version",
		"id",
		"owner_id",
		"generation",
		"state",
		"resume_state",
		"closed_reason",
		"ordinal",
		"start_profile",
		"current_profile",
		"last_transition",
		"pending_replacement"
	]
	if value.version == CAPTURE_VERSION:
		fields.append("capture")
	if (
		not Profile.keys(value, fields)
		or not Profile.token(value.id)
		or not Profile.token(value.owner_id)
		or not Profile.whole(value.ordinal, 1, Profile.MAX_ORDINAL)
		or not Profile.whole(value.generation, 0, Profile.MAX_ORDINAL - 1)
		or value.generation != value.ordinal - 1
		or not value.state is String
		or value.state not in ["active", "closed", "paused"]
		or not value.resume_state is String
		or not value.closed_reason is String
		or not value.pending_replacement is Dictionary
		or not value.pending_replacement.is_empty()
	):
		return {}
	var phase: String = value.resume_state if value.state == "paused" else value.state
	if (
		phase not in ["active", "closed"]
		or (value.state != "paused" and value.resume_state != "")
		or (phase == "active" and value.closed_reason != "")
		or (phase == "closed" and value.closed_reason not in ["win", "loss", "abandon"])
	):
		return {}
	var start: Dictionary = Profile.normalize(value.start_profile)
	var current: Dictionary = Profile.normalize(value.current_profile)
	if start.is_empty() or current.is_empty() or start.version != current.version:
		return {}
	if start.has("access") and not Profile.access_same_origin(start.access, current.access):
		return {}
	for profile: Dictionary in [start, current]:
		if (
			profile.lineage_id != value.id
			or profile.owner_id != value.owner_id
			or profile.season_ordinal != value.ordinal
		):
			return {}
	# v1 remains inert; v2 requires a source-replayed compact capture record.
	if (
		(value.version == VERSION and not Profile.same(start, current))
		or (value.version == CAPTURE_VERSION and not _capture_valid(value.capture, start, current))
		or not _transition_valid(value.last_transition, start, int(value.generation))
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = int(value.version)
	result.ordinal = int(result.ordinal)
	result.generation = int(result.generation)
	result.start_profile = start
	result.current_profile = current
	if result.version == CAPTURE_VERSION:
		for key: String in ["version", "revision", "previous_revision"]:
			result.capture[key] = int(result.capture[key])
	Profile.freeze(result)
	return result


static func close(value: Variant, outcome: String) -> Dictionary:
	var source: Dictionary = normalize(value)
	if source.is_empty() or outcome not in ["win", "loss", "abandon"]:
		return {}
	if source.state == "closed" and source.closed_reason == outcome:
		return source
	if source.state != "active":
		return {}
	var next: Dictionary = source.duplicate(true)
	next.state = "closed"
	next.closed_reason = outcome
	return normalize(next)


static func pause(value: Variant) -> Dictionary:
	var source: Dictionary = normalize(value)
	if source.is_empty() or source.state == "paused":
		return source
	var next: Dictionary = source.duplicate(true)
	next.resume_state = source.state
	next.state = "paused"
	return normalize(next)


static func resume(value: Variant) -> Dictionary:
	var source: Dictionary = normalize(value)
	if source.is_empty() or source.state != "paused":
		return source
	var next: Dictionary = source.duplicate(true)
	next.state = source.resume_state
	next.resume_state = ""
	return normalize(next)


static func advance(value: Variant, request: Dictionary) -> Dictionary:
	var source: Dictionary = normalize(value)
	if source.is_empty() or not _request_valid(request, source.id):
		return {}
	if not source.last_transition.is_empty() and request.id == source.last_transition.request.id:
		return (
			{"lineage": source, "replayed": true}
			if Profile.same(request, source.last_transition.request)
			else {}
		)
	if (
		source.state != "closed"
		or request.source_generation != source.generation
		or request.source_ordinal != source.ordinal
		or request.target_ordinal != source.ordinal + 1
		or source.ordinal >= Profile.MAX_ORDINAL
	):
		return {}
	var projected: Dictionary = Profile.decay(source.current_profile, request.overflow_choices)
	if projected.is_empty():
		return {}
	var start: Dictionary = projected.profile.duplicate(true)
	start.season_ordinal = int(request.target_ordinal)
	start.seed = int(request.target_seed)
	start = Profile.normalize(start)
	var next: Dictionary = source.duplicate(true)
	next.version = VERSION
	next.erase("capture")
	next.ordinal = int(request.target_ordinal)
	next.generation = int(source.generation) + 1
	next.state = "active"
	next.closed_reason = ""
	next.start_profile = start
	next.current_profile = start
	next.last_transition = {
		"request": request.duplicate(true),
		"source_seed": source.current_profile.seed,
		"source_profile_hash": fingerprint(source.current_profile),
		"changes": projected.changes
	}
	var checked: Dictionary = normalize(next)
	return {} if checked.is_empty() else {"lineage": checked, "replayed": false}


static func request_for(
	value: Dictionary, id: String, next_seed: int, choices: Dictionary = {}
) -> Dictionary:
	return {
		"id": id,
		"source_generation": value.generation,
		"source_ordinal": value.ordinal,
		"target_ordinal": int(value.ordinal) + 1,
		"target_id": "%s:%d" % [value.id, int(value.ordinal) + 1],
		"target_seed": next_seed,
		"overflow_choices": choices.duplicate(true)
	}


static func _request_valid(value: Variant, lineage: String) -> bool:
	return (
		Profile.keys(
			value,
			[
				"id",
				"source_generation",
				"source_ordinal",
				"target_ordinal",
				"target_id",
				"target_seed",
				"overflow_choices"
			]
		)
		and Profile.token(value.id)
		and Profile.whole(value.source_generation, 0, Profile.MAX_ORDINAL - 1)
		and Profile.whole(value.source_ordinal, 1, Profile.MAX_ORDINAL)
		and Profile.whole(value.target_ordinal, 2, Profile.MAX_ORDINAL)
		and value.source_generation == value.source_ordinal - 1
		and value.target_ordinal == value.source_ordinal + 1
		and value.target_id == "%s:%d" % [lineage, int(value.target_ordinal)]
		and Profile.whole(value.target_seed, 0, 2147483647)
		and value.overflow_choices is Dictionary
	)


static func _transition_valid(value: Variant, start: Dictionary, generation: int) -> bool:
	if not value is Dictionary:
		return false
	if generation == 0:
		return value.is_empty()
	if (
		not Profile.keys(value, ["request", "source_seed", "source_profile_hash", "changes"])
		or not _request_valid(value.request, start.lineage_id)
		or value.request.source_generation != generation - 1
		or value.request.target_ordinal != start.season_ordinal
		or value.request.target_seed != start.seed
		or not Profile.whole(value.source_seed, 0, 2147483647)
		or not value.source_profile_hash is String
		or value.source_profile_hash.length() != 64
		or not Profile.keys(value.changes, start.roster)
	):
		return false
	var before: Dictionary = start.duplicate(true)
	before.seed = int(value.source_seed)
	before.season_ordinal = int(value.request.source_ordinal)
	for id: String in start.roster:
		var row: Variant = value.changes[id]
		var player: Dictionary = before.players[id]
		if (
			not Profile.keys(row, ["stats", "mastery", "forgotten", "temporary_slots_before"])
			or not Profile.keys(row.stats, SeasonPlayerCatalog.STATS)
			or not Profile.keys(row.mastery, player.mastery.keys())
			or not row.forgotten is Array
			or row.forgotten.size() > 1
			or not Profile.whole(row.temporary_slots_before, 1, 2)
		):
			return false
		for stat: String in SeasonPlayerCatalog.STATS:
			var change: Variant = row.stats[stat]
			if (
				not _change_valid(change, 2)
				or player.trained[stat] != change.after.paid
				or player.catchup.stats[stat] != change.after.catchup
			):
				return false
			player.trained[stat] = int(change.before.paid)
			player.catchup.stats[stat] = int(change.before.catchup)
			player.stats[stat] = (
				player.authored.stats[stat] + change.before.paid + change.before.catchup
			)
		for recipe: String in player.mastery:
			var change: Variant = row.mastery[recipe]
			if (
				not _change_valid(change, 1)
				or player.earned_mastery[recipe] != change.after.paid
				or player.catchup.mastery[recipe] != change.after.catchup
			):
				return false
			player.earned_mastery[recipe] = int(change.before.paid)
			player.catchup.mastery[recipe] = int(change.before.catchup)
			player.mastery[recipe] = (
				player.authored.mastery.get(recipe, 1) + change.before.paid + change.before.catchup
			)
		for forgotten: Variant in row.forgotten:
			if (
				not Profile.keys(forgotten, ["index", "receipt"])
				or not Profile.whole(forgotten.index, 0, player.abilities.size())
				or not Profile.ability_valid(forgotten.receipt)
				or forgotten.receipt.slot != "Fielding"
			):
				return false
			player.abilities.insert(int(forgotten.index), forgotten.receipt.duplicate(true))
		player.temporary_fielding_slots = int(row.temporary_slots_before)
	before = Profile.normalize(before)
	if before.is_empty() or fingerprint(before) != value.source_profile_hash:
		return false
	var projected: Dictionary = Profile.decay(before, value.request.overflow_choices)
	if projected.is_empty() or not Profile.same(projected.changes, value.changes):
		return false
	var expected: Dictionary = projected.profile.duplicate(true)
	expected.season_ordinal = start.season_ordinal
	expected.seed = start.seed
	return Profile.same(Profile.normalize(expected), start)


static func _change_valid(value: Variant, rate: int) -> bool:
	if (
		not Profile.keys(value, ["before", "after", "removed"])
		or not Profile.keys(value.before, ["paid", "catchup"])
		or not Profile.keys(value.after, ["paid", "catchup"])
		or not Profile.keys(value.removed, ["total", "paid", "catchup"])
	):
		return false
	for pair: Dictionary in [value.before, value.after, value.removed]:
		for amount: Variant in pair.values():
			if not Profile.whole(amount, 0, 9):
				return false
	var drop: int = mini(rate, int(value.before.paid + value.before.catchup))
	var paid: int = mini(drop, int(value.before.paid))
	return (
		value.removed.total == drop
		and value.removed.paid == paid
		and value.removed.catchup == drop - paid
		and value.after.paid == value.before.paid - paid
		and value.after.catchup == value.before.catchup - (drop - paid)
	)


static func fingerprint(value: Dictionary) -> String:
	# An accidental-tamper consistency fingerprint, not authentication.
	return JSON.stringify(value, "", true, true).sha256_text()


# Version2 is an offline compact checkpoint of a source-replayed current season.
# It validates local transition consistency, not omitted historical authenticity.
static func capture_current(value: Variant, snapshot: Variant) -> Dictionary:
	var capture_script: GDScript = load(_CAPTURE_SCRIPT_PATH)
	return {} if capture_script == null else capture_script._capture_lineage_current(value, snapshot)


static func capture_transition_valid(before_value: Variant, after_value: Variant) -> bool:
	var before: Dictionary = normalize(before_value)
	var after: Dictionary = normalize(after_value)
	if (
		before.is_empty()
		or after.is_empty()
		or after.version != CAPTURE_VERSION
		or before.state == "closed"
		or (before.state == "paused" and before.resume_state != "active")
	):
		return false
	for key: String in [
		"id",
		"owner_id",
		"generation",
		"state",
		"resume_state",
		"closed_reason",
		"ordinal",
		"start_profile",
		"last_transition",
		"pending_replacement"
	]:
		if not Profile.same(before[key], after[key]):
			return false
	var previous: Dictionary = before.get("capture", {})
	if (
		after.capture.previous_revision != int(previous.get("revision", 0))
		or after.capture.previous_prefix != previous.get("prefix_hash", "")
	):
		return false
	return (
		previous.is_empty()
		or (
			after.capture.revision > previous.revision
			and after.capture.header_hash == previous.header_hash
		)
	)


static func _capture_valid(value: Variant, start: Dictionary, current: Dictionary) -> bool:
	if (
		not Profile.keys(
			value,
			[
				"version",
				"season_id",
				"revision",
				"header_hash",
				"prefix_hash",
				"profile_hash",
				"previous_revision",
				"previous_prefix"
			]
		)
		or not Profile.whole(value.version, 1, 1)
		or value.season_id != "%s:%d" % [start.lineage_id, int(start.season_ordinal)]
		or current.seed != start.seed
		or current.roster != start.roster
		or current.source.season_key != value.season_id
		or current.source.seed != start.seed
		or not Profile.whole(value.revision, 0, Profile.BUILD_MAX_EVENTS)
		or not Profile.whole(value.previous_revision, 0, int(value.revision))
		or current.source.build_revision != value.revision
		or current.source.authority != "season-replay"
		or not _digest(value.header_hash)
		or not _digest(value.prefix_hash)
		or not _digest(value.profile_hash)
		or value.profile_hash != fingerprint(current)
		or not value.previous_prefix is String
		or (
			value.previous_prefix != ""
			and (not _digest(value.previous_prefix) or value.previous_revision >= value.revision)
		)
		or (value.previous_prefix == "" and value.previous_revision != 0)
	):
		return false
	return true


static func _capture_header(data: Dictionary) -> String:
	var header: Dictionary = data.duplicate()
	header.erase("events")
	# Recruit offer mirrors are derived journal output, not starting authority.
	header.erase("recruits")
	return _json_identity(header)


static func _capture_prefix(data: Dictionary, count: int) -> String:
	return _json_identity({"header": _capture_header(data), "events": data.events.slice(0, count)})


static func _digest(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _json_identity(value: Variant) -> String:
	# Full precision JSON numeric identity: integer spelling alone is not lineage change.
	return (
		JSON
		. stringify(JSON.parse_string(JSON.stringify(value, "", true, true)), "", true, true)
		. sha256_text()
	)

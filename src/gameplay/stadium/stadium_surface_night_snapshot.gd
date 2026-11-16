class_name StadiumSurfaceNightSnapshot
extends RefCounted
## Explicit opt-in family. Historical entry8/fixture9 never infer this mode.

const VERSION: int = 1
const FIXTURE_VERSION: int = 26
const WRAPPED_FIXTURE_VERSION: int = 36
const FAMILY: String = "owned-surface-night-season-v1"
const FIXTURE_FAMILY: String = "owned-surface-night-fixture-v1"
const PUBLIC_READY: bool = true
const TIME_VERSION: int = 2
const TIME_FIXTURE_VERSION: int = 27
const TIME_FAMILY: String = "owned-surface-time-season-v2"
const TIME_FIXTURE_FAMILY: String = "owned-surface-time-fixture-v2"
const CLOCK_RULE: String = "completed-play-half-v1"
const MAX_CLOCK_SECONDS: int = 21600
const ENTRY_KEYS: Array[String] = [
	"version", "tier", "geometry", "revision", "layout", "inventory", "surface_access", "boundary"
]

const Operations1: GDScript = preload(
	"res://src/gameplay/stadium/stadium_surface_night_snapshot_operations_1.gd"
)


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"family": FIXTURE_FAMILY,
				"version": VERSION,
				"candidate": StadiumSurfaceNightLayout.signature(),
				"tier": "expanded",
				"surface": {"foundation": "grass", "condition": "prepared", "height": "short"},
				"grass": "ST-063b",
				"ground": "ST-063i",
				"shadow": [2048, false, 1, 1, 1, 1],
				"light": StadiumLightItems.PROFILE,
				"palette": StadiumSurfaceNightPalette.VERSION,
				"plate_sand_factor": StadiumSurfaceNightPalette.PLATE_SAND_FACTOR
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func ledger(season: SeasonState) -> ClubAssetLedger:
	if season == null:
		return null
	return (
		season._pool_replay_ledger
		if season._pool_replay_ledger != null
		else (ClubPlayers.assets(season.career) if season.career != null else null)
	)


static func run_id(season: SeasonState) -> int:
	return (
		season._npc_replay_run
		if season._npc_replay_run >= 0
		else (season.career.current if season.career != null else -1)
	)


static func capture_policy(season: SeasonState, paid: ClubAssetLedger) -> Dictionary:
	if season == null or paid == null or run_id(season) < 0:
		return {}
	var candidate: Dictionary = StadiumSurfaceNightLayout.capture(paid)
	if (
		candidate.is_empty()
		or not _composition(candidate.entry)
		or not ClubCareer.same(candidate.entry, season.home_property)
	):
		return {}
	var result: Dictionary = {
		"version": VERSION,
		"family": FAMILY,
		"mode": "night",
		"season_seed": season.season_seed,
		"run_id": run_id(season),
		"entry_key": StadiumLayoutSnapshot.key(season.home_property),
		"candidate": candidate
	}
	return normalized_policy(result) if valid_policy(result, season, paid) else {}


static func policy_shape(value: Variant) -> bool:
	if _wrapped_policy_candidate(value):
		return not _wrapped_policy(value).is_empty()
	if value is Dictionary and value.get("version") == TIME_VERSION:
		return _time_policy_shape(value)
	if (
		not value is Dictionary
		or not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._keys(
			value, ["version", "family", "mode", "season_seed", "run_id", "entry_key", "candidate"]
		)
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or value.family != FAMILY
		or value.mode != "night"
		or not SeasonOwnership._whole(value.season_seed, 0, 2147483647)
		or not SeasonOwnership._whole(value.run_id, 0, 1000000)
		or not _digest(value.entry_key)
		or not value.candidate is Dictionary
	):
		return false
	var candidate: Dictionary = value.candidate
	return (
		StadiumSurfaceNightLayout.candidate_shape(candidate)
		and _composition(candidate.entry)
		and value.entry_key == StadiumLayoutSnapshot.key(candidate.entry)
	)


static func normalized_policy(value: Dictionary) -> Dictionary:
	if _wrapped_policy_candidate(value):
		return _wrapped_policy(value).get("policy", {}).duplicate(true)
	if not policy_shape(value):
		return {}
	var result: Dictionary = value.duplicate(true)
	for field: String in ["version", "season_seed", "run_id"]:
		result[field] = int(result[field])
	if result.version == TIME_VERSION:
		result.start_minute = int(result.start_minute)
	result.candidate.candidate_version = int(result.candidate.candidate_version)
	result.candidate.entry = StadiumLayoutSnapshot.normalized(result.candidate.entry)
	return result


static func valid_policy(value: Variant, season: SeasonState, paid: ClubAssetLedger) -> bool:
	if _wrapped_policy_candidate(value):
		var context: Dictionary = _wrapped_policy(value)
		return (
			not context.is_empty()
			and _wrapped_policy_season(context, season)
			and not _wrapped_paid(context, paid).is_empty()
		)
	return (
		season != null
		and policy_shape(value)
		and paid != null
		and value.season_seed == season.season_seed
		and value.run_id == run_id(season)
		and ClubCareer.same(value.candidate.entry, season.home_property)
		and StadiumSurfaceNightLayout.valid(value.candidate, paid)
	)


static func expected(season: SeasonState, scheduled: Dictionary) -> bool:
	return (
		season != null
		and not season.owned_surface_night.is_empty()
		and scheduled.get("home", -1) == 0
		and not scheduled.get("neutral", false)
	)


static func fixture(season: SeasonState, scheduled: Dictionary) -> Dictionary:
	if (
		season != null
		and StadiumLightingKitNightReceiptAdapter.supports_entry(season.home_property)
	):
		var context: Dictionary = _wrapped_policy(season.owned_surface_night)
		if (
			context.is_empty()
			or not _wrapped_policy_season(context, season)
			or _wrapped_paid(context, ledger(season)).is_empty()
		):
			return {}
		return _wrapped_expected(context, season, scheduled)
	if season != null and season.owned_surface_night.get("version") == TIME_VERSION:
		return _time_fixture(season, scheduled)
	if (
		not expected(season, scheduled)
		or not valid_policy(season.owned_surface_night, season, ledger(season))
		or not ClubCareer.same(
			SeasonVenues.fixture_for_id(season, int(scheduled.get("id", -1))), scheduled
		)
	):
		return {}
	var result: Dictionary = season.home_property.duplicate(true)
	result.version = (
		WRAPPED_FIXTURE_VERSION
		if StadiumLightingKitNightReceiptAdapter.supports_entry(season.home_property)
		else FIXTURE_VERSION
	)
	if result.version == WRAPPED_FIXTURE_VERSION:
		result["entry_version"] = int(season.home_property.version)
		result["receipt_adapter"] = StadiumLightingKitNightReceiptAdapter.signature(
			StadiumLightingKitNightCandidate.signature()
		)
	result["family"] = FIXTURE_FAMILY
	result["policy_key"] = _data(normalized_policy(season.owned_surface_night)).sha256_text()
	result["binding"] = {
		"season_seed": season.season_seed,
		"run_id": run_id(season),
		"fixture": int(scheduled.id),
		"match_seed": SeasonPhysicalFixtures.seed_for(season, scheduled),
		"entry_key": StadiumLayoutSnapshot.key(season.home_property)
	}
	result["environment"] = {
		"version": VERSION, "mode": "night", "profile": signature_for(season.home_property)
	}
	return normalized(result)


static func is_family(value: Variant) -> bool:
	if is_time(value) or is_wrapped(value):
		return true
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), FIXTURE_VERSION, FIXTURE_VERSION)
	)


static func valid(value: Variant) -> bool:
	if is_wrapped(value):
		return not _wrapped_snapshot(value).is_empty()
	if is_time(value):
		return _time_valid(value)
	if (
		not is_family(value)
		or not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._keys(value, _fixture_keys(value))
		or value.family != FIXTURE_FAMILY
		or not _digest(value.policy_key)
		or not value.binding is Dictionary
		or not value.environment is Dictionary
		or not SeasonOwnership._keys(
			value.binding, ["season_seed", "run_id", "fixture", "match_seed", "entry_key"]
		)
		or not SeasonOwnership._keys(value.environment, ["version", "mode", "profile"])
	):
		return false
	if (
		is_wrapped(value)
		and (
			not SeasonOwnership._whole(value.get("entry_version"), 32, 34)
			or int(value.entry_version) not in StadiumLightingKitNightReceiptAdapter.ENTRY_VERSIONS
			or (
				value.receipt_adapter
				!= StadiumLightingKitNightReceiptAdapter.signature(
					StadiumLightingKitNightCandidate.signature()
				)
			)
			or not StadiumLightingKitNightReceiptAdapter.supports_entry(_entry(value))
		)
	):
		return false
	var binding: Dictionary = value.binding
	if (
		not SeasonOwnership._whole(binding.season_seed, 0, 2147483647)
		or not SeasonOwnership._whole(binding.run_id, 0, 1000000)
		or not SeasonOwnership._whole(binding.fixture, 0, 32)
		or not SeasonOwnership._whole(binding.match_seed, 0, 2147483647)
		or (
			binding.match_seed
			!= ((int(binding.season_seed) + int(binding.fixture) * 104729) & 0x7fffffff)
		)
		or not _digest(binding.entry_key)
		or not SeasonOwnership._whole(value.environment.version, VERSION, VERSION)
		or value.environment.mode != "night"
		or value.environment.profile != signature_for(_entry(value))
	):
		return false
	var base: Dictionary = _entry(value)
	return _composition(base) and binding.entry_key == StadiumLayoutSnapshot.key(base)


static func entry(value: Dictionary) -> Dictionary:
	if is_wrapped(value):
		return _entry(value) if not _wrapped_snapshot(value).is_empty() else {}
	return _entry(value) if valid(value) else {}


static func _entry(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in (
		StadiumLightingKitNightReceiptAdapter.COMPLETE_KEYS if is_wrapped(value) else ENTRY_KEYS
	):
		result[field] = value[field]
	result = result.duplicate(true)
	result.version = int(value.entry_version) if is_wrapped(value) else 8
	return result


static func normalized(value: Dictionary) -> Dictionary:
	if is_wrapped(value):
		return _wrapped_snapshot(value).get("snapshot", {}).duplicate(true)
	if not valid(value):
		return {}
	var result: Dictionary = StadiumLayoutSnapshot.normalized(_entry(value))
	result.version = (
		TIME_FIXTURE_VERSION
		if is_time(value)
		else WRAPPED_FIXTURE_VERSION if is_wrapped(value) else FIXTURE_VERSION
	)
	for field: String in (
		["family", "policy_key", "environment", "binding", "entry_version", "receipt_adapter"]
		if is_wrapped(value)
		else ["family", "policy_key", "environment", "binding"]
	):
		result[field] = value[field].duplicate(true) if value[field] is Dictionary else value[field]
	if is_wrapped(value):
		result.entry_version = int(result.entry_version)
	result.environment.version = TIME_VERSION if is_time(value) else VERSION
	if is_time(value):
		result.environment.start_minute = int(result.environment.start_minute)
	for field: String in ["season_seed", "run_id", "fixture", "match_seed"]:
		result.binding[field] = int(result.binding[field])
	return result


static func key(value: Dictionary) -> String:
	if is_wrapped(value):
		return _wrapped_snapshot(value).get("snapshot_key", "")
	var result: Dictionary = normalized(value)
	return "" if result.is_empty() else _data(result).sha256_text()


static func matches(value: Dictionary, paid: ClubAssetLedger) -> bool:
	if is_wrapped(value):
		var context: Dictionary = _wrapped_snapshot(value)
		return not context.is_empty() and not _wrapped_paid(context, paid).is_empty()
	return valid(value) and StadiumLayoutSnapshot.matches(_entry(value), paid)


static func matches_fixture(
	value: Dictionary, season: SeasonState, scheduled: Dictionary, paid: ClubAssetLedger
) -> bool:
	if is_wrapped(value):
		return not _wrapped_match(value, season, scheduled, paid).is_empty()
	return (
		matches(value, paid)
		and valid_policy(season.owned_surface_night, season, paid)
		and not key(value).is_empty()
		and key(value) == key(fixture(season, scheduled))
	)


static func proof(value: Dictionary, policy: Dictionary, paid: ClubAssetLedger) -> Dictionary:
	if is_wrapped(value):
		var context: Dictionary = _wrapped_snapshot(value)
		if context.is_empty():
			return {}
		var canonical_policy: Dictionary = _wrapped_policy_for(policy, context)
		var paid_proof: Dictionary = _wrapped_paid(context, paid)
		if (
			canonical_policy.is_empty()
			or paid_proof.is_empty()
			or value.policy_key != _data(canonical_policy).sha256_text()
		):
			return {}
		return _wrapped_proof(context, canonical_policy, paid_proof)
	if (
		not matches(value, paid)
		or not policy_shape(policy)
		or policy.version != (TIME_VERSION if is_time(value) else VERSION)
		or (is_time(value) and value.environment.mode != policy.mode)
		or value.policy_key != _data(normalized_policy(policy)).sha256_text()
		or not ClubCareer.same(_entry(value), policy.candidate.entry)
	):
		return {}
	var prefix: ClubAssetLedger = paid.prefix(int(value.revision))
	if prefix == null:
		return {}
	return {
		"version": TIME_VERSION if is_time(value) else VERSION,
		"profile":
		time_signature_for(_entry(value)) if is_time(value) else signature_for(_entry(value)),
		"policy": normalized_policy(policy),
		"paid_prefix": _data(prefix.to_data()).sha256_text()
	}


static func proof_valid(value: Variant, snapshot: Dictionary) -> bool:
	if is_wrapped(snapshot):
		return _wrapped_proof_valid(value, snapshot)
	if is_time(snapshot):
		return _time_proof_valid(value, snapshot)
	return (
		valid(snapshot)
		and value is Dictionary
		and SeasonOwnership._keys(value, ["version", "profile", "policy", "paid_prefix"])
		and SeasonOwnership._whole(value.version, VERSION, VERSION)
		and value.profile == signature_for(_entry(snapshot))
		and _digest(value.paid_prefix)
		and policy_shape(value.policy)
		and value.policy.version == VERSION
		and snapshot.policy_key == _data(normalized_policy(value.policy)).sha256_text()
		and snapshot.binding.season_seed == value.policy.season_seed
		and snapshot.binding.run_id == value.policy.run_id
		and ClubCareer.same(_entry(snapshot), value.policy.candidate.entry)
	)


static func _composition(value: Dictionary) -> bool:
	if StadiumLightingKitNightCandidate.is_candidate_layout(value.get("layout")):
		return not StadiumLightingKitNightCandidate.admission_profile(value).is_empty()
	if StadiumFloodlightOwnedItems.is_family(value.get("layout")):
		return StadiumSurfaceNightLayout._eligible(value)
	if not StadiumSurfaceNightLayout._eligible(value) or value.tier != "expanded":
		return false
	var layout: Dictionary = value.layout
	return (
		ClubCareer.same(
			layout.surface, {"foundation": "grass", "condition": "prepared", "height": "short"}
		)
		and ClubCareer.same(layout.styles, {"grass": "ST-063b", "line": ""})
		and layout.ground == "ST-063i"
		and layout.receiver == ""
		and layout.target == ""
		and layout.net == ""
		and layout.bases == ""
		and layout.obstacles.is_empty()
		and layout.seating.is_empty()
		and layout.bleachers.is_empty()
		and layout.displays.is_empty()
	)


static func _digest(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)


static func _data(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


# New versions are explicitly opt-in. The old signature and branches stay byte-stable.
static func time_signature() -> String:
	return (
		_data(
			{
				"family": TIME_FIXTURE_FAMILY,
				"version": TIME_VERSION,
				"base": signature(),
				"starts": {"day": 790, "sunset": 970, "night": 1150},
				"rule": CLOCK_RULE,
				"seconds_per_play": 15,
				"seconds_per_half": 120,
				"maximum_seconds": MAX_CLOCK_SECONDS,
				"presentation_revision": 1
			}
		)
		. sha256_text()
	)


static func signature_for(entry_value: Dictionary) -> String:
	if StadiumLightingKitNightReceiptAdapter.supports_entry(entry_value):
		return _wrapped_entry_admission(entry_value).get("signature", "")
	if StadiumLightingKitNightCandidate.is_candidate_layout(entry_value.get("layout")):
		var kit: Dictionary = StadiumLightingKitNightCandidate.admission_profile(entry_value)
		if kit.is_empty():
			return ""
		if StadiumLightingKitNightReceiptAdapter.supports_entry(entry_value):
			return (
				_data(
					{
						"family": FIXTURE_FAMILY,
						"version": VERSION,
						"fixture_version": WRAPPED_FIXTURE_VERSION,
						"candidate": StadiumLightingKitNightCandidate.signature(),
						"receipt_adapter":
						StadiumLightingKitNightCandidate.contract_for(entry_value),
						"entry_version": int(entry_value.version),
						"composition": kit.composition_key,
						"qualification": kit.qualification,
						"presentation": kit.presentation,
						"physical_geometry":
						StadiumLightingKitItems.geometry(
							entry_value.tier,
							StadiumLightingKitNightCandidate.physical_layout(entry_value.layout)
						),
						"runtime": "owned-st111-fixed-night-transaction-v1"
					}
				)
				. sha256_text()
			)
		return (
			_data(
				{
					"family": FIXTURE_FAMILY,
					"version": VERSION,
					"candidate": StadiumLightingKitNightCandidate.signature(),
					"composition": kit.composition_key,
					"qualification": kit.qualification,
					"presentation": kit.presentation,
					"runtime": "owned-st111-fixed-night-transaction-v1"
				}
			)
			. sha256_text()
		)
	if not StadiumFloodlightOwnedItems.is_family(entry_value.get("layout")):
		return signature()
	var profile: Dictionary = StadiumFloodlightOwnedItems.night_profile(entry_value)
	if profile.is_empty():
		return ""
	return (
		_data(
			{
				"family": FIXTURE_FAMILY,
				"version": VERSION,
				"candidate": StadiumSurfaceNightLayout.floodlight_signature(),
				"floodlight_profile": profile.profile,
				"palette": StadiumSurfaceNightPalette.VERSION,
				"plate_sand_factor": StadiumSurfaceNightPalette.PLATE_SAND_FACTOR
			}
		)
		. sha256_text()
	)


static func time_signature_for(entry_value: Dictionary) -> String:
	if StadiumLightingKitNightCandidate.is_candidate_layout(entry_value.get("layout")):
		return ""  # Fixed Night is not calibrated Day/Sunset or clock drift.
	if not StadiumFloodlightOwnedItems.is_family(entry_value.get("layout")):
		return time_signature()
	var base: String = signature_for(entry_value)
	return (
		""
		if base.is_empty()
		else (
			_data(
				{
					"family": TIME_FIXTURE_FAMILY,
					"version": TIME_VERSION,
					"base": base,
					"shared_clock": time_signature()
				}
			)
			. sha256_text()
		)
	)


static func start_minute(profile: String) -> int:
	match profile:
		"day":
			return 790
		"sunset":
			return 970
		"night":
			return 1150
	return -1


static func capture_time_policy(
	season: SeasonState, paid: ClubAssetLedger, profile: String = "day"
) -> Dictionary:
	if start_minute(profile) < 0:
		return {}
	var result: Dictionary = capture_policy(season, paid)
	if (
		result.is_empty()
		or StadiumLightingKitNightCandidate.is_candidate_layout(result.candidate.entry.layout)
	):
		return {}
	result.version = TIME_VERSION
	result.family = TIME_FAMILY
	result.mode = profile
	result["start_minute"] = start_minute(profile)
	result["rule"] = CLOCK_RULE
	return normalized_policy(result) if valid_policy(result, season, paid) else {}


static func _time_policy_shape(value: Dictionary) -> bool:
	if value.get("candidate") is Dictionary and value.candidate.get("candidate_version") == 3:
		return false
	if (
		not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._keys(
			value,
			[
				"version",
				"family",
				"mode",
				"season_seed",
				"run_id",
				"entry_key",
				"candidate",
				"start_minute",
				"rule"
			]
		)
		or not SeasonOwnership._whole(value.version, TIME_VERSION, TIME_VERSION)
		or value.family != TIME_FAMILY
		or not value.mode is String
		or start_minute(value.mode) < 0
		or value.rule != CLOCK_RULE
		or not SeasonOwnership._whole(value.start_minute, 0, 1439)
		or value.start_minute != start_minute(value.mode)
	):
		return false
	var legacy: Dictionary = value.duplicate(true)
	legacy.version = VERSION
	legacy.family = FAMILY
	legacy.mode = "night"
	legacy.erase("start_minute")
	legacy.erase("rule")
	return policy_shape(legacy)


static func is_time(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), TIME_FIXTURE_VERSION, TIME_FIXTURE_VERSION)
	)


static func _time_fixture(season: SeasonState, scheduled: Dictionary) -> Dictionary:
	if (
		not expected(season, scheduled)
		or not valid_policy(season.owned_surface_night, season, ledger(season))
		or not ClubCareer.same(
			SeasonVenues.fixture_for_id(season, int(scheduled.get("id", -1))), scheduled
		)
	):
		return {}
	var policy: Dictionary = normalized_policy(season.owned_surface_night)
	var result: Dictionary = season.home_property.duplicate(true)
	result.version = TIME_FIXTURE_VERSION
	result["family"] = TIME_FIXTURE_FAMILY
	result["policy_key"] = _data(policy).sha256_text()
	result["binding"] = {
		"season_seed": season.season_seed,
		"run_id": run_id(season),
		"fixture": int(scheduled.id),
		"match_seed": SeasonPhysicalFixtures.seed_for(season, scheduled),
		"entry_key": StadiumLayoutSnapshot.key(season.home_property)
	}
	result["environment"] = {
		"version": TIME_VERSION,
		"mode": policy.mode,
		"profile": time_signature_for(season.home_property),
		"start_minute": policy.start_minute,
		"rule": CLOCK_RULE
	}
	return normalized(result)


static func _time_valid(value: Dictionary) -> bool:
	if StadiumLightingKitNightCandidate.is_candidate_layout(value.get("layout")):
		return false
	if (
		not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._keys(
			value, ENTRY_KEYS + ["family", "policy_key", "binding", "environment"]
		)
		or value.family != TIME_FIXTURE_FAMILY
		or not value.environment is Dictionary
		or not SeasonOwnership._keys(
			value.environment, ["version", "mode", "profile", "start_minute", "rule"]
		)
	):
		return false
	var environment: Dictionary = value.environment
	if (
		not SeasonOwnership._whole(environment.version, TIME_VERSION, TIME_VERSION)
		or not environment.mode is String
		or start_minute(environment.mode) < 0
		or environment.profile != time_signature_for(_entry(value))
		or environment.rule != CLOCK_RULE
		or not SeasonOwnership._whole(environment.start_minute, 0, 1439)
		or environment.start_minute != start_minute(environment.mode)
	):
		return false
	var legacy: Dictionary = value.duplicate(true)
	legacy.version = FIXTURE_VERSION
	legacy.family = FIXTURE_FAMILY
	legacy.environment = {
		"version": VERSION, "mode": "night", "profile": signature_for(_entry(value))
	}
	return valid(legacy)


static func _time_proof_valid(value: Variant, snapshot: Dictionary) -> bool:
	return (
		valid(snapshot)
		and value is Dictionary
		and SeasonOwnership._keys(value, ["version", "profile", "policy", "paid_prefix"])
		and SeasonOwnership._whole(value.version, TIME_VERSION, TIME_VERSION)
		and value.profile == time_signature_for(_entry(snapshot))
		and _digest(value.paid_prefix)
		and policy_shape(value.policy)
		and value.policy.version == TIME_VERSION
		and snapshot.environment.mode == value.policy.mode
		and snapshot.policy_key == _data(normalized_policy(value.policy)).sha256_text()
		and snapshot.binding.season_seed == value.policy.season_seed
		and snapshot.binding.run_id == value.policy.run_id
		and ClubCareer.same(_entry(snapshot), value.policy.candidate.entry)
	)


static func clock(profile: String, completed_plays: int, completed_halves: int) -> Dictionary:
	if (
		start_minute(profile) < 0
		or completed_plays < 0
		or completed_plays > 100000
		or completed_halves < 0
		or completed_halves > 10000
	):
		return {}
	return {
		"rule": CLOCK_RULE,
		"start_minute": start_minute(profile),
		"completed_plays": completed_plays,
		"completed_halves": completed_halves,
		"elapsed_seconds": mini(MAX_CLOCK_SECONDS, completed_plays * 15 + completed_halves * 120)
	}


# Terminal callers pass final.half + 1 only for a validated third-out finish.
# PRE_PITCH already names the next half; a walk-off inside a half adds nothing.
static func clock_evidence(snapshot: Dictionary, plays: Array, completed_half: int) -> Dictionary:
	return (
		clock(snapshot.environment.mode, plays.size(), completed_half)
		if is_time(snapshot) and valid(snapshot)
		else {}
	)


static func clock_valid(
	value: Variant, snapshot: Dictionary, plays: Array, completed_half: int
) -> bool:
	if (
		not value is Dictionary
		or not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._keys(
			value,
			["rule", "start_minute", "completed_plays", "completed_halves", "elapsed_seconds"]
		)
	):
		return false
	for field: String in ["start_minute", "completed_plays", "completed_halves", "elapsed_seconds"]:
		if not SeasonOwnership._whole(value[field], 0, 100000):
			return false
	var expected_clock: Dictionary = clock_evidence(snapshot, plays, completed_half)
	return not expected_clock.is_empty() and ClubCareer.same(value, expected_clock)


static func drift(profile: String, progress: Dictionary) -> float:
	# Working authored tuning. Regulation remains subtle; extras darken more gently.
	var ceiling: float = 0.06 if profile == "sunset" else 0.02
	var ordinary: float = minf(1.0, float(progress.elapsed_seconds) / 3600.0) * ceiling
	var extras: float = maxf(0.0, float(progress.completed_halves - 10)) * 0.012
	return minf(0.75 if profile == "sunset" else 0.20, ordinary + extras)


static func is_wrapped(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"), WRAPPED_FIXTURE_VERSION, WRAPPED_FIXTURE_VERSION
		)
	)


static func _fixture_keys(value: Dictionary) -> Array:
	return (
		(
			(
				StadiumLightingKitNightReceiptAdapter.COMPLETE_KEYS
				+ ["entry_version", "receipt_adapter"]
			)
			if is_wrapped(value)
			else ENTRY_KEYS
		)
		+ ["family", "policy_key", "binding", "environment"]
	)


static func is_fixed(value: Variant) -> bool:
	return (
		value is Dictionary
		and (
			SeasonOwnership._whole(value.get("version"), FIXTURE_VERSION, FIXTURE_VERSION)
			or is_wrapped(value)
		)
	)


# Private fixture36 call-local admission. These contexts are created by the cold
# wrappers above, detached and deeply read-only, and never accepted as arguments
# to a public shortcut. No static success cache, await, signal or external callback.
static func _wrapped_freeze(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for field: Variant in value:
			result[field] = _wrapped_freeze(value[field])
		result.make_read_only()
		return result
	if value is Array:
		var result: Array = []
		for child: Variant in value:
			result.append(_wrapped_freeze(child))
		result.make_read_only()
		return result
	return value


static func _wrapped_entry_admission(value: Dictionary) -> Dictionary:
	var context: Dictionary = StadiumLightingKitNightCandidate._wrapped_admission(value)
	if context.is_empty():
		return {}
	context["signature"] = (
		_data(
			{
				"family": FIXTURE_FAMILY,
				"version": VERSION,
				"fixture_version": WRAPPED_FIXTURE_VERSION,
				"candidate": StadiumLightingKitNightCandidate.signature(),
				"receipt_adapter": StadiumLightingKitNightCandidate.contract_for(context.entry),
				"entry_version": int(context.entry.version),
				"composition": context.profile.composition_key,
				"qualification": context.profile.qualification,
				"presentation": context.profile.presentation,
				"physical_geometry": context.physical_geometry,
				"runtime": "owned-st111-fixed-night-transaction-v1"
			}
		)
		. sha256_text()
	)
	return _wrapped_freeze(context)


static func _wrapped_snapshot(value: Variant) -> Dictionary:
	if (
		not is_wrapped(value)
		or not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._keys(value, _fixture_keys(value))
		or value.family != FIXTURE_FAMILY
		or not _digest(value.policy_key)
		or not value.binding is Dictionary
		or not value.environment is Dictionary
		or not SeasonOwnership._keys(
			value.binding, ["season_seed", "run_id", "fixture", "match_seed", "entry_key"]
		)
		or not SeasonOwnership._keys(value.environment, ["version", "mode", "profile"])
		or not SeasonOwnership._whole(value.entry_version, 32, 34)
		or int(value.entry_version) not in StadiumLightingKitNightReceiptAdapter.ENTRY_VERSIONS
		or (
			value.receipt_adapter
			!= StadiumLightingKitNightReceiptAdapter.signature(
				StadiumLightingKitNightCandidate.signature()
			)
		)
	):
		return {}
	var context: Dictionary = _wrapped_entry_admission(_entry(value))
	if context.is_empty():
		return {}
	var binding: Dictionary = value.binding
	if (
		not SeasonOwnership._whole(binding.season_seed, 0, 2147483647)
		or not SeasonOwnership._whole(binding.run_id, 0, 1000000)
		or not SeasonOwnership._whole(binding.fixture, 0, 32)
		or not SeasonOwnership._whole(binding.match_seed, 0, 2147483647)
		or (
			binding.match_seed
			!= ((int(binding.season_seed) + int(binding.fixture) * 104729) & 0x7fffffff)
		)
		or not _digest(binding.entry_key)
		or binding.entry_key != context.entry_key
		or not SeasonOwnership._whole(value.environment.version, VERSION, VERSION)
		or value.environment.mode != "night"
		or value.environment.profile != context.signature
	):
		return {}
	var canonical: Dictionary = context.entry.duplicate(true)
	canonical.version = WRAPPED_FIXTURE_VERSION
	for field: String in [
		"family", "policy_key", "environment", "binding", "entry_version", "receipt_adapter"
	]:
		canonical[field] = (
			value[field].duplicate(true) if value[field] is Dictionary else value[field]
		)
	canonical.entry_version = int(canonical.entry_version)
	canonical.environment.version = VERSION
	for field: String in ["season_seed", "run_id", "fixture", "match_seed"]:
		canonical.binding[field] = int(canonical.binding[field])
	var result: Dictionary = context.duplicate(true)
	result["snapshot"] = canonical
	result["snapshot_key"] = _data(canonical).sha256_text()
	return _wrapped_freeze(result)


static func _wrapped_policy_candidate(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.get("candidate") is Dictionary
		and StadiumLightingKitNightReceiptAdapter.supports_entry(value.candidate.get("entry"))
	)


static func _wrapped_policy(value: Variant) -> Dictionary:
	if not _wrapped_policy_candidate(value) or not StadiumNpcSnapshot._json_types(value):
		return {}
	var context: Dictionary = _wrapped_entry_admission(value.candidate.entry)
	if context.is_empty():
		return {}
	var policy: Dictionary = _wrapped_policy_for(value, context)
	if policy.is_empty():
		return {}
	var result: Dictionary = context.duplicate(true)
	result["policy"] = policy
	return _wrapped_freeze(result)


static func _wrapped_policy_for(value: Variant, context: Dictionary) -> Dictionary:
	return Operations1._wrapped_policy_for(value, context)


static func _wrapped_policy_season(context: Dictionary, season: SeasonState) -> bool:
	return Operations1._wrapped_policy_season(context, season)


static func _wrapped_paid(context: Dictionary, paid: ClubAssetLedger) -> Dictionary:
	return Operations1._wrapped_paid(context, paid)


static func _wrapped_expected(
	context: Dictionary, season: SeasonState, scheduled: Dictionary
) -> Dictionary:
	return Operations1._wrapped_expected(context, season, scheduled)


static func _wrapped_match(
	value: Dictionary, season: SeasonState, scheduled: Dictionary, paid: ClubAssetLedger
) -> Dictionary:
	return Operations1._wrapped_match(value, season, scheduled, paid)


static func _wrapped_proof(
	context: Dictionary, policy: Dictionary, supplied: Dictionary
) -> Dictionary:
	return Operations1._wrapped_proof(context, policy, supplied)


static func _wrapped_proof_valid(value: Variant, snapshot: Dictionary) -> bool:
	return Operations1._wrapped_proof_valid(value, snapshot)


static func _wrapped_runtime_admission(
	value: Dictionary, season: SeasonState, scheduled: Dictionary, paid: ClubAssetLedger
) -> Dictionary:
	return Operations1._wrapped_runtime_admission(value, season, scheduled, paid)


static func _wrapped_acceptance_owner(season: SeasonState) -> bool:
	return Operations1._wrapped_acceptance_owner(season)


static func _wrapped_accepts_human(
	value: Dictionary, night: Variant, season: SeasonState, scheduled: Dictionary
) -> bool:
	return Operations1._wrapped_accepts_human(value, night, season, scheduled)

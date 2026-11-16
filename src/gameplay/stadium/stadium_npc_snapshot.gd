class_name StadiumNpcSnapshot
extends RefCounted

const AC02_PASSIVE_8 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Exact public venue snapshots and separately retained raw qualification declarations.
## Public fixtures bind a saved assignment; raw16/17 never acquire public authority.

const VERSION: int = 16
const FIXTURE_VERSION: int = 17
const PUBLIC_VERSION: int = 18
const PUBLIC_FIXTURE_VERSION: int = 19
const FINAL_FIXTURE_VERSION: int = 20
const GRAND_FINAL_FIXTURE_VERSION: int = 21
const GRAND_II_FINAL_FIXTURE_VERSION: int = 22
const GRAND_III_FINAL_FIXTURE_VERSION: int = 23
const POOL_PARTY_FINAL_FIXTURE_VERSION: int = 24
const HILLSIDE_FINAL_FIXTURE_VERSION: int = 25
const AUTHORITY: String = "npc-authored-v1"
const FIELD: String = "field.npc_venue"
const MAX_BYTES: int = 262144
const ENTRY_KEYS: Array[String] = ["version", "authority", "manifest", "manifest_key"]
const BINDING_KEYS: Array[String] = [
	"season_id",
	"assignment_key",
	"owner_club",
	"venue_id",
	"venue_revision",
	"fixture",
	"away",
	"batting_home",
	"neutral",
	"match_seed",
	"field"
]
const ENVIRONMENT_KEYS: Array[String] = ["version", "seed", "fixture", "mode", "profile"]

const Operations1: GDScript = preload(
	"res://src/gameplay/stadium/stadium_npc_snapshot_operations_1.gd"
)


static func capture(id: String, revision: int) -> Dictionary:
	if not supports(id, revision):
		return {}
	var manifest: Dictionary = StadiumNpcVenues.definition(id, revision)
	return normalized(
		{
			"version": PUBLIC_VERSION,
			"authority": AUTHORITY,
			"manifest": manifest,
			"manifest_key": StadiumNpcVenues.key(manifest)
		}
	)


static func supports(id: String, revision: int) -> bool:
	# Long Yard is admissible only through the distinct neutral-final snapshot20.
	if id in ["LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"]:
		return false
	if id in ["AY-02", "AY-03"] and revision == 1:
		return true
	return (
		StadiumNpcPublicRuntime.supports_definition(id, revision)
		and StadiumNpcPublicReport.supports_definition(id, revision)
	)


static func valid(value: Variant) -> bool:
	return not normalized(value).is_empty()


static func normalized(value: Variant) -> Dictionary:
	var ac02_token: int = AC02_PASSIVE_8.enter("stadium_npc_snapshot.normalized")
	var ac02_result: Dictionary = _ac02_passive_08_normalized(value)
	AC02_PASSIVE_8.leave(ac02_token)
	return ac02_result


static func _ac02_passive_08_normalized(value: Variant) -> Dictionary:
	if (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"), HILLSIDE_FINAL_FIXTURE_VERSION, HILLSIDE_FINAL_FIXTURE_VERSION
		)
	):
		return _normalized_hillside_final(value)
	if (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"), POOL_PARTY_FINAL_FIXTURE_VERSION, POOL_PARTY_FINAL_FIXTURE_VERSION
		)
	):
		return _normalized_pool_party_final(value)
	if (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"), GRAND_III_FINAL_FIXTURE_VERSION, GRAND_III_FINAL_FIXTURE_VERSION
		)
	):
		return _normalized_grand_iii_final(value)
	if (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"), GRAND_II_FINAL_FIXTURE_VERSION, GRAND_II_FINAL_FIXTURE_VERSION
		)
	):
		return _normalized_grand_ii_final(value)
	if (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"), GRAND_FINAL_FIXTURE_VERSION, GRAND_FINAL_FIXTURE_VERSION
		)
	):
		return _normalized_grand_final(value)
	if (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"), FINAL_FIXTURE_VERSION, FINAL_FIXTURE_VERSION
		)
	):
		return _normalized_final(value)
	if not _public_shape(value):
		return {}
	var manifest: Dictionary = StadiumNpcVenues.normalized(value.manifest)
	if (
		manifest.is_empty()
		or JSON.stringify(manifest, "", true, true).sha256_text() != value.manifest_key
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = int(result.version)
	result.manifest = manifest
	if result.version == PUBLIC_FIXTURE_VERSION:
		for field: String in [
			"season_seed",
			"career_run",
			"owner_club",
			"venue_revision",
			"fixture",
			"away",
			"batting_home",
			"match_seed"
		]:
			result.binding[field] = int(result.binding[field])
		if result.binding.has("assignment_version"):
			result.binding.assignment_version = int(result.binding.assignment_version)
			result.binding.environment_seed = int(result.binding.environment_seed)
		for field: String in ["version", "seed", "fixture"]:
			result.environment[field] = int(result.environment[field])
	return result


static func key(value: Variant) -> String:
	var canonical: Dictionary = normalized(value)
	return "" if canonical.is_empty() else JSON.stringify(canonical, "", true, true).sha256_text()


static func fixture(entry: Variant, binding: Variant, environment: Variant) -> Dictionary:
	var result: Dictionary = normalized(entry)
	if result.is_empty() or result.version != PUBLIC_VERSION:
		return {}
	result.version = PUBLIC_FIXTURE_VERSION
	result["binding"] = binding
	result["environment"] = environment
	return normalized(result)


static func matches_fixture(value: Variant, season: SeasonState, scheduled: Dictionary) -> bool:
	var ac02_token: int = AC02_PASSIVE_8.enter("stadium_npc_snapshot.matches_fixture")
	var ac02_result: bool = _ac02_passive_08_matches_fixture(value, season, scheduled)
	AC02_PASSIVE_8.leave(ac02_token)
	return ac02_result


static func _ac02_passive_08_matches_fixture(
	value: Variant, season: SeasonState, scheduled: Dictionary
) -> bool:
	# Only this call's freshly canonical expected data may avoid re-normalization.
	# Null means ineligible, not invalid: unknown inputs retain the original cold path.
	var owned: Variant = SeasonVenues._owned_ac02_fixture(value, season, scheduled)
	if owned != null:
		return (
			not owned.is_empty()
			and key(value) == JSON.stringify(owned, "", true, true).sha256_text()
		)
	var expected: Dictionary = SeasonVenues.for_fixture(season, scheduled)
	return not expected.is_empty() and key(value) == key(expected)


static func is_public(value: Variant) -> bool:
	# Routing discriminator only. Call valid/normalized before reading any payload.
	return (
		value is Dictionary
		and SeasonOwnership._whole(
			value.get("version"), PUBLIC_VERSION, HILLSIDE_FINAL_FIXTURE_VERSION
		)
	)


static func is_fixture(value: Variant) -> bool:
	# Routing only; callers still validate the full frozen payload.
	return (
		is_public(value)
		and (
			value.get("version") == PUBLIC_FIXTURE_VERSION
			or value.get("version") == FINAL_FIXTURE_VERSION
			or value.get("version") == GRAND_FINAL_FIXTURE_VERSION
			or value.get("version") == GRAND_II_FINAL_FIXTURE_VERSION
			or value.get("version") == GRAND_III_FINAL_FIXTURE_VERSION
			or value.get("version") == POOL_PARTY_FINAL_FIXTURE_VERSION
			or value.get("version") == HILLSIDE_FINAL_FIXTURE_VERSION
		)
	)


static func _public_shape(value: Variant) -> bool:
	if (
		not is_public(value)
		or value.version == FINAL_FIXTURE_VERSION
		or value.version == GRAND_FINAL_FIXTURE_VERSION
		or value.version == GRAND_II_FINAL_FIXTURE_VERSION
		or value.version == GRAND_III_FINAL_FIXTURE_VERSION
		or value.version == POOL_PARTY_FINAL_FIXTURE_VERSION
		or value.version == HILLSIDE_FINAL_FIXTURE_VERSION
	):
		return false
	var keys: Array = ENTRY_KEYS.duplicate()
	if value.version == PUBLIC_FIXTURE_VERSION:
		keys.append_array(["binding", "environment"])
	if (
		not _keys(value, keys)
		or not value.authority is String
		or value.authority != AUTHORITY
		or not StadiumNpcManifest._hash(value.manifest_key)
		or not StadiumNpcManifest._shape(value.manifest)
		or not supports(String(value.manifest.id), int(value.manifest.revision))
		or value.manifest.field != FIELD
	):
		return false
	if (
		value.version == PUBLIC_FIXTURE_VERSION
		and (
			not _public_binding(value.binding, value.manifest)
			or not _public_environment(value.environment, value.binding)
		)
	):
		return false
	return (
		_json_types(value)
		and JSON.stringify(value, "", true, true).to_utf8_buffer().size() <= MAX_BYTES
	)


static func _public_binding(value: Variant, manifest: Dictionary) -> bool:
	var keys: Array[String] = [
		"season_seed",
		"career_run",
		"assignment_key",
		"owner_club",
		"venue_id",
		"venue_revision",
		"fixture",
		"away",
		"batting_home",
		"neutral",
		"match_seed",
		"field"
	]
	if value is Dictionary and value.has("assignment_version"):
		keys.append_array(["assignment_version", "environment_seed"])
		if (
			not SeasonOwnership._whole(value.get("assignment_version"), 3, 3)
			or not SeasonOwnership._whole(value.get("environment_seed"), 0, 2147483647)
		):
			return false
	return (
		_keys(value, keys)
		and SeasonOwnership._whole(value.season_seed, 0, 2147483647)
		and SeasonOwnership._whole(value.career_run, 1, ClubCareer.MAX_RUNS)
		and StadiumNpcManifest._hash(value.assignment_key)
		and SeasonOwnership._whole(value.owner_club, 1, 5)
		and value.venue_id is String
		and value.venue_id == manifest.id
		and SeasonOwnership._whole(value.venue_revision, 1, 2)
		and value.venue_revision == manifest.revision
		and SeasonOwnership._whole(value.fixture, 0, 31)
		and SeasonOwnership._whole(value.away, 0, 5)
		and SeasonOwnership._whole(value.batting_home, 1, 5)
		and value.batting_home == value.owner_club
		and value.away != value.batting_home
		and value.neutral is bool
		and not value.neutral
		and SeasonOwnership._whole(value.match_seed, 0, 2147483647)
		and value.field is String
		and value.field == FIELD
		and value.field == manifest.field
	)


static func _public_environment(value: Variant, binding: Dictionary) -> bool:
	return (
		_keys(value, ENVIRONMENT_KEYS)
		and SeasonOwnership._whole(
			value.version, StadiumFixtureEnvironment.VERSION, StadiumFixtureEnvironment.VERSION
		)
		and SeasonOwnership._whole(value.seed, 0, 2147483647)
		and value.seed == binding.get("environment_seed", binding.match_seed)
		and SeasonOwnership._whole(value.fixture, 0, 31)
		and value.fixture == binding.fixture
		and value.mode is String
		and value.mode == "day"
		and value.profile is String
		and value.profile.is_empty()
	)


static func raw_envelope_valid(value: Variant) -> bool:
	return not normalize_raw_envelope(value).is_empty()


static func normalize_raw_envelope(value: Variant) -> Dictionary:
	# Reject raw schema/types/ranges/size before any representation conversion.
	if not _raw_shape(value):
		return {}
	var manifest: Dictionary = StadiumNpcVenues.normalized(value.manifest)
	if manifest.is_empty() or not StadiumNpcDaylightEvidenceV2.matches(manifest):
		return {}
	var manifest_key: String = JSON.stringify(manifest, "", true, true).sha256_text()
	if value.manifest_key != manifest_key:
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = int(result.version)
	result.manifest = manifest
	if result.version == FIXTURE_VERSION:
		for field: String in [
			"owner_club", "venue_revision", "fixture", "away", "batting_home", "match_seed"
		]:
			result.binding[field] = int(result.binding[field])
		for field: String in ["version", "seed", "fixture"]:
			result.environment[field] = int(result.environment[field])
	return result


static func raw_envelope_key(value: Variant) -> String:
	var canonical: Dictionary = normalize_raw_envelope(value)
	return "" if canonical.is_empty() else JSON.stringify(canonical, "", true, true).sha256_text()


static func raw_entry(id: Variant, revision: Variant) -> Dictionary:
	if (
		not id is String
		or id not in ["AY-01", "AE-01", "AC-01"]
		or not SeasonOwnership._whole(revision, 2, 2)
	):
		return {}
	var manifest: Dictionary = StadiumNpcVenues.definition(id, int(revision))
	return normalize_raw_envelope(
		{
			"version": VERSION,
			"authority": AUTHORITY,
			"manifest": manifest,
			"manifest_key": StadiumNpcVenues.key(manifest)
		}
	)


static func raw_fixture(entry: Variant, binding: Variant, environment: Variant) -> Dictionary:
	var result: Dictionary = normalize_raw_envelope(entry)
	if result.is_empty() or result.version != VERSION:
		return {}
	result.version = FIXTURE_VERSION
	result["binding"] = binding
	result["environment"] = environment
	return normalize_raw_envelope(result)


static func _raw_shape(value: Variant) -> bool:
	if (
		not value is Dictionary
		or not SeasonOwnership._whole(value.get("version"), VERSION, FIXTURE_VERSION)
	):
		return false
	var keys: Array = ENTRY_KEYS.duplicate()
	if value.version == FIXTURE_VERSION:
		keys.append_array(["binding", "environment"])
	if (
		not _keys(value, keys)
		or not value.authority is String
		or value.authority != AUTHORITY
		or not StadiumNpcManifest._hash(value.manifest_key)
		or not StadiumNpcManifest._shape(value.manifest)
	):
		return false
	if (
		value.manifest.id not in ["AY-01", "AE-01", "AC-01"]
		or not SeasonOwnership._whole(value.manifest.revision, 2, 2)
		or value.manifest.field != FIELD
	):
		return false
	if (
		value.version == FIXTURE_VERSION
		and (
			not _binding(value.binding, value.manifest)
			or not _environment(value.environment, value.binding)
		)
	):
		return false
	return (
		_json_types(value)
		and JSON.stringify(value, "", true, true).to_utf8_buffer().size() <= MAX_BYTES
	)


static func _binding(value: Variant, manifest: Dictionary) -> bool:
	return (
		_keys(value, BINDING_KEYS)
		and _hex(value.season_id, 32)
		and StadiumNpcManifest._hash(value.assignment_key)
		and SeasonOwnership._whole(value.owner_club, 1, 5)
		and value.venue_id is String
		and value.venue_id == manifest.id
		and SeasonOwnership._whole(value.venue_revision, 2, 2)
		and value.venue_revision == manifest.revision
		and SeasonOwnership._whole(value.fixture, 0, 31)
		and SeasonOwnership._whole(value.away, 0, 5)
		and SeasonOwnership._whole(value.batting_home, 1, 5)
		and value.batting_home == value.owner_club
		and value.away != value.batting_home
		and value.neutral is bool
		and not value.neutral
		and SeasonOwnership._whole(value.match_seed, 0, 2147483647)
		and value.field is String
		and value.field == FIELD
		and value.field == manifest.field
	)


static func _environment(value: Variant, binding: Dictionary) -> bool:
	return (
		_keys(value, ENVIRONMENT_KEYS)
		and SeasonOwnership._whole(
			value.version, StadiumFixtureEnvironment.VERSION, StadiumFixtureEnvironment.VERSION
		)
		and SeasonOwnership._whole(value.seed, 0, 2147483647)
		and SeasonOwnership._whole(value.fixture, 0, 31)
		and value.fixture == binding.fixture
		and value.mode is String
		and value.mode == "day"
		and value.profile is String
		and value.profile.is_empty()
	)


static func _keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, keys):
		return false
	for field: Variant in value:
		if not field is String:
			return false
	return true


static func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _json_types(value: Variant, depth: int = 0) -> bool:
	# Bounded raw JSON only: no object conversion, StringName keys or recursive containers.
	if depth > 16:
		return false
	if value is Dictionary:
		for field: Variant in value:
			if not field is String or not _json_types(value[field], depth + 1):
				return false
		return true
	if value is Array:
		for child: Variant in value:
			if not _json_types(child, depth + 1):
				return false
		return true
	return value is String or value is bool or value is int or (value is float and is_finite(value))


static func _normalized_final(value: Dictionary) -> Dictionary:
	if (
		not _keys(
			value, ["version", "authority", "manifest", "manifest_key", "binding", "environment"]
		)
		or not SeasonOwnership._whole(value.version, FINAL_FIXTURE_VERSION, FINAL_FIXTURE_VERSION)
		or not value.authority is String
		or value.authority != SeasonFinalVenue.AUTHORITY
		or not _json_types(value)
		or JSON.stringify(value, "", true, true).to_utf8_buffer().size() > MAX_BYTES
		or not _keys(
			value.binding,
			[
				"season_seed",
				"career_run",
				"assignment_key",
				"league",
				"selection",
				"venue_owner",
				"venue_id",
				"venue_revision",
				"fixture",
				"away",
				"batting_home",
				"neutral",
				"match_seed",
				"field"
			]
		)
	):
		return {}
	var binding: Dictionary = value.binding
	if (
		not SeasonOwnership._whole(binding.season_seed, 0, 2147483647)
		or not SeasonOwnership._whole(binding.career_run, 1, ClubCareer.MAX_RUNS)
		or not StadiumNpcManifest._hash(binding.assignment_key)
		or not binding.league is String
		or not binding.selection is String
		or not binding.venue_owner is String
		or not binding.venue_id is String
		or not binding.field is String
		or binding.league != SeasonFinalVenue.LEAGUE
		or binding.selection != SeasonFinalVenue.SELECTION
		or binding.venue_owner != SeasonFinalVenue.OWNER
		or binding.venue_id != "LONG-YARD"
		or not SeasonOwnership._whole(binding.venue_revision, 1, 1)
		or not SeasonOwnership._whole(binding.fixture, 32, 32)
		or not SeasonOwnership._whole(binding.away, 0, 5)
		or not SeasonOwnership._whole(binding.batting_home, 0, 5)
		or binding.away == binding.batting_home
		or not binding.neutral is bool
		or not binding.neutral
		or not SeasonOwnership._whole(binding.match_seed, 0, 2147483647)
		or binding.match_seed != SeasonFinalVenue._seed(int(binding.season_seed))
		or binding.field != FIELD
	):
		return {}
	var record: Dictionary = SeasonFinalVenue.normalized(
		{
			"version": SeasonFinalVenue.VERSION,
			"seed": binding.season_seed,
			"career_run": binding.career_run,
			"league": binding.league,
			"selection": binding.selection,
			"fixture": binding.fixture,
			"venue_owner": binding.venue_owner,
			"manifest": value.manifest,
			"manifest_key": value.manifest_key,
			"environment": value.environment
		}
	)
	if (
		record.is_empty()
		or record.manifest.field != FIELD
		or record.manifest.id != "LONG-YARD"
		or record.manifest.revision != 1
		or SeasonFinalVenue.key(record) != binding.assignment_key
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = FINAL_FIXTURE_VERSION
	result.manifest = record.manifest
	result.environment = record.environment
	for field: String in [
		"season_seed",
		"career_run",
		"venue_revision",
		"fixture",
		"away",
		"batting_home",
		"match_seed"
	]:
		result.binding[field] = int(result.binding[field])
	return result


static func _normalized_grand_final(value: Dictionary) -> Dictionary:
	if (
		not _keys(
			value, ["version", "authority", "manifest", "manifest_key", "binding", "environment"]
		)
		or not SeasonOwnership._whole(
			value.version, GRAND_FINAL_FIXTURE_VERSION, GRAND_FINAL_FIXTURE_VERSION
		)
		or not value.authority is String
		or value.authority != SeasonFinalVenue.GRAND_AUTHORITY
		or not _json_types(value)
		or JSON.stringify(value, "", true, true).to_utf8_buffer().size() > MAX_BYTES
		or not _keys(
			value.binding,
			[
				"season_seed",
				"career_run",
				"assignment_key",
				"league",
				"selection",
				"venue_owner",
				"venue_id",
				"venue_revision",
				"fixture",
				"away",
				"batting_home",
				"neutral",
				"match_seed",
				"field"
			]
		)
	):
		return {}
	var binding: Dictionary = value.binding
	if (
		not SeasonOwnership._whole(binding.season_seed, 0, 2147483647)
		or not SeasonOwnership._whole(binding.career_run, 1, ClubCareer.MAX_RUNS)
		or not StadiumNpcManifest._hash(binding.assignment_key)
		or not binding.league is String
		or not binding.selection is String
		or not binding.venue_owner is String
		or not binding.venue_id is String
		or not binding.field is String
		or binding.league != SeasonFinalVenue.GRAND_LEAGUE
		or (
			binding.selection
			not in [
				SeasonFinalVenue.SELECTION,
				SeasonFinalVenue.STANDARD_BASE_SELECTION,
				SeasonFinalVenue.STANDARD_D1_SELECTION
			]
		)
		or binding.venue_owner != SeasonFinalVenue.GRAND_OWNER
		or binding.venue_id != "GRAND-I"
		or not SeasonOwnership._whole(binding.venue_revision, 1, 1)
		or not SeasonOwnership._whole(binding.fixture, 32, 32)
		or not SeasonOwnership._whole(binding.away, 0, 5)
		or not SeasonOwnership._whole(binding.batting_home, 0, 5)
		or binding.away == binding.batting_home
		or not binding.neutral is bool
		or not binding.neutral
		or not SeasonOwnership._whole(binding.match_seed, 0, 2147483647)
		or binding.match_seed != SeasonFinalVenue._seed(int(binding.season_seed))
		or binding.field != FIELD
	):
		return {}
	var record: Dictionary = SeasonFinalVenue.normalized(
		{
			"version": SeasonFinalVenue.GRAND_VERSION,
			"seed": binding.season_seed,
			"career_run": binding.career_run,
			"league": binding.league,
			"selection": binding.selection,
			"fixture": binding.fixture,
			"venue_owner": binding.venue_owner,
			"manifest": value.manifest,
			"manifest_key": value.manifest_key,
			"environment": value.environment
		}
	)
	if (
		record.is_empty()
		or record.manifest.field != FIELD
		or record.manifest.id != "GRAND-I"
		or record.manifest.revision != 1
		or SeasonFinalVenue.key(record) != binding.assignment_key
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = GRAND_FINAL_FIXTURE_VERSION
	result.manifest = record.manifest
	result.environment = record.environment
	for field: String in [
		"season_seed",
		"career_run",
		"venue_revision",
		"fixture",
		"away",
		"batting_home",
		"match_seed"
	]:
		result.binding[field] = int(result.binding[field])
	return result


static func _normalized_grand_ii_final(value: Dictionary) -> Dictionary:
	if (
		not _keys(
			value, ["version", "authority", "manifest", "manifest_key", "binding", "environment"]
		)
		or not SeasonOwnership._whole(
			value.version, GRAND_II_FINAL_FIXTURE_VERSION, GRAND_II_FINAL_FIXTURE_VERSION
		)
		or not value.authority is String
		or value.authority != SeasonFinalVenue.GRAND_II_AUTHORITY
		or not _json_types(value)
		or JSON.stringify(value, "", true, true).to_utf8_buffer().size() > MAX_BYTES
		or not _keys(
			value.binding,
			[
				"season_seed",
				"career_run",
				"assignment_key",
				"league",
				"selection",
				"venue_owner",
				"venue_id",
				"venue_revision",
				"fixture",
				"away",
				"batting_home",
				"neutral",
				"match_seed",
				"field"
			]
		)
	):
		return {}
	var binding: Dictionary = value.binding
	if (
		not SeasonOwnership._whole(binding.season_seed, 0, 2147483647)
		or not SeasonOwnership._whole(binding.career_run, 1, ClubCareer.MAX_RUNS)
		or not StadiumNpcManifest._hash(binding.assignment_key)
		or not binding.league is String
		or not binding.selection is String
		or not binding.venue_owner is String
		or not binding.venue_id is String
		or not binding.field is String
		or binding.league != SeasonFinalVenue.GRAND_LEAGUE
		or (
			binding.selection
			not in [
				SeasonFinalVenue.SELECTION,
				SeasonFinalVenue.STANDARD_D2_SELECTION,
				SeasonFinalVenue.STANDARD_D3_SELECTION
			]
		)
		or binding.venue_owner != SeasonFinalVenue.GRAND_II_OWNER
		or binding.venue_id != "GRAND-II"
		or not SeasonOwnership._whole(binding.venue_revision, 1, 1)
		or not SeasonOwnership._whole(binding.fixture, 32, 32)
		or not SeasonOwnership._whole(binding.away, 0, 5)
		or not SeasonOwnership._whole(binding.batting_home, 0, 5)
		or binding.away == binding.batting_home
		or not binding.neutral is bool
		or not binding.neutral
		or not SeasonOwnership._whole(binding.match_seed, 0, 2147483647)
		or binding.match_seed != SeasonFinalVenue._seed(int(binding.season_seed))
		or binding.field != FIELD
	):
		return {}
	var record: Dictionary = SeasonFinalVenue.normalized(
		{
			"version": SeasonFinalVenue.GRAND_II_VERSION,
			"seed": binding.season_seed,
			"career_run": binding.career_run,
			"league": binding.league,
			"selection": binding.selection,
			"fixture": binding.fixture,
			"venue_owner": binding.venue_owner,
			"manifest": value.manifest,
			"manifest_key": value.manifest_key,
			"environment": value.environment
		}
	)
	if (
		record.is_empty()
		or record.manifest.field != FIELD
		or record.manifest.id != "GRAND-II"
		or record.manifest.revision != 1
		or SeasonFinalVenue.key(record) != binding.assignment_key
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = GRAND_II_FINAL_FIXTURE_VERSION
	result.manifest = record.manifest
	result.environment = record.environment
	for field: String in [
		"season_seed",
		"career_run",
		"venue_revision",
		"fixture",
		"away",
		"batting_home",
		"match_seed"
	]:
		result.binding[field] = int(result.binding[field])
	return result


static func _normalized_grand_iii_final(value: Dictionary) -> Dictionary:
	if (
		not _keys(
			value, ["version", "authority", "manifest", "manifest_key", "binding", "environment"]
		)
		or not SeasonOwnership._whole(
			value.version, GRAND_III_FINAL_FIXTURE_VERSION, GRAND_III_FINAL_FIXTURE_VERSION
		)
		or not value.authority is String
		or value.authority != SeasonFinalVenue.GRAND_III_AUTHORITY
		or not _json_types(value)
		or JSON.stringify(value, "", true, true).to_utf8_buffer().size() > MAX_BYTES
		or not _keys(
			value.binding,
			[
				"season_seed",
				"career_run",
				"assignment_key",
				"league",
				"selection",
				"venue_owner",
				"venue_id",
				"venue_revision",
				"fixture",
				"away",
				"batting_home",
				"neutral",
				"match_seed",
				"field"
			]
		)
	):
		return {}
	var binding: Dictionary = value.binding
	if (
		not SeasonOwnership._whole(binding.season_seed, 0, 2147483647)
		or not SeasonOwnership._whole(binding.career_run, 1, ClubCareer.MAX_RUNS)
		or not StadiumNpcManifest._hash(binding.assignment_key)
		or not binding.league is String
		or not binding.selection is String
		or not binding.venue_owner is String
		or not binding.venue_id is String
		or not binding.field is String
		or binding.league != SeasonFinalVenue.GRAND_LEAGUE
		or (
			binding.selection
			not in [SeasonFinalVenue.SELECTION, SeasonFinalVenue.STANDARD_D4_SELECTION]
		)
		or binding.venue_owner != SeasonFinalVenue.GRAND_III_OWNER
		or binding.venue_id != "GRAND-III"
		or not SeasonOwnership._whole(binding.venue_revision, 1, 1)
		or not SeasonOwnership._whole(binding.fixture, 32, 32)
		or not SeasonOwnership._whole(binding.away, 0, 5)
		or not SeasonOwnership._whole(binding.batting_home, 0, 5)
		or binding.away == binding.batting_home
		or not binding.neutral is bool
		or not binding.neutral
		or not SeasonOwnership._whole(binding.match_seed, 0, 2147483647)
		or binding.match_seed != SeasonFinalVenue._seed(int(binding.season_seed))
		or binding.field != FIELD
	):
		return {}
	var record: Dictionary = SeasonFinalVenue.normalized(
		{
			"version": SeasonFinalVenue.GRAND_III_VERSION,
			"seed": binding.season_seed,
			"career_run": binding.career_run,
			"league": binding.league,
			"selection": binding.selection,
			"fixture": binding.fixture,
			"venue_owner": binding.venue_owner,
			"manifest": value.manifest,
			"manifest_key": value.manifest_key,
			"environment": value.environment
		}
	)
	if (
		record.is_empty()
		or record.manifest.field != FIELD
		or record.manifest.id != "GRAND-III"
		or record.manifest.revision != 1
		or SeasonFinalVenue.key(record) != binding.assignment_key
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = GRAND_III_FINAL_FIXTURE_VERSION
	result.manifest = record.manifest
	result.environment = record.environment
	for field: String in [
		"season_seed",
		"career_run",
		"venue_revision",
		"fixture",
		"away",
		"batting_home",
		"match_seed"
	]:
		result.binding[field] = int(result.binding[field])
	return result


static func _normalized_pool_party_final(value: Dictionary) -> Dictionary:
	return Operations1._normalized_pool_party_final(value)


static func _normalized_hillside_final(value: Dictionary) -> Dictionary:
	return Operations1._normalized_hillside_final(value)

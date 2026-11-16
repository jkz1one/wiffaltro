extends RefCounted
## Stateless operations for the original StadiumNpcSnapshot script.


static func _normalized_pool_party_final(value: Dictionary) -> Dictionary:
	if (
		not StadiumNpcSnapshot._keys(
			value, ["version", "authority", "manifest", "manifest_key", "binding", "environment"]
		)
		or not SeasonOwnership._whole(
			value.version,
			StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION,
			StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION
		)
		or not value.authority is String
		or value.authority != SeasonFinalVenue.POOL_PARTY_AUTHORITY
		or not StadiumNpcSnapshot._json_types(value)
		or (
			JSON.stringify(value, "", true, true).to_utf8_buffer().size()
			> StadiumNpcSnapshot.MAX_BYTES
		)
		or not StadiumNpcSnapshot._keys(
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
		or binding.selection != SeasonFinalVenue.SELECTION
		or binding.venue_owner != SeasonFinalVenue.POOL_PARTY_OWNER
		or binding.venue_id != "POOL-PARTY"
		or not SeasonOwnership._whole(binding.venue_revision, 1, 1)
		or not SeasonOwnership._whole(binding.fixture, 32, 32)
		or not SeasonOwnership._whole(binding.away, 0, 5)
		or not SeasonOwnership._whole(binding.batting_home, 0, 5)
		or binding.away == binding.batting_home
		or not binding.neutral is bool
		or not binding.neutral
		or not SeasonOwnership._whole(binding.match_seed, 0, 2147483647)
		or binding.match_seed != SeasonFinalVenue._seed(int(binding.season_seed))
		or binding.field != StadiumNpcSnapshot.FIELD
	):
		return {}
	var record: Dictionary = SeasonFinalVenue.normalized(
		{
			"version": SeasonFinalVenue.POOL_PARTY_VERSION,
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
		or record.manifest.field != StadiumNpcSnapshot.FIELD
		or record.manifest.id != "POOL-PARTY"
		or record.manifest.revision != 1
		or SeasonFinalVenue.key(record) != binding.assignment_key
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION
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


static func _normalized_hillside_final(value: Dictionary) -> Dictionary:
	if (
		not StadiumNpcSnapshot._keys(
			value, ["version", "authority", "manifest", "manifest_key", "binding", "environment"]
		)
		or not SeasonOwnership._whole(
			value.version,
			StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION,
			StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
		)
		or not value.authority is String
		or value.authority != SeasonFinalVenue.HILLSIDE_AUTHORITY
		or not StadiumNpcSnapshot._json_types(value)
		or (
			JSON.stringify(value, "", true, true).to_utf8_buffer().size()
			> StadiumNpcSnapshot.MAX_BYTES
		)
		or not StadiumNpcSnapshot._keys(
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
		or binding.selection != SeasonFinalVenue.SELECTION
		or binding.venue_owner != SeasonFinalVenue.HILLSIDE_OWNER
		or binding.venue_id != "HILLSIDE"
		or not SeasonOwnership._whole(binding.venue_revision, 1, 1)
		or not SeasonOwnership._whole(binding.fixture, 32, 32)
		or not SeasonOwnership._whole(binding.away, 0, 5)
		or not SeasonOwnership._whole(binding.batting_home, 0, 5)
		or binding.away == binding.batting_home
		or not binding.neutral is bool
		or not binding.neutral
		or not SeasonOwnership._whole(binding.match_seed, 0, 2147483647)
		or binding.match_seed != SeasonFinalVenue._seed(int(binding.season_seed))
		or binding.field != StadiumNpcSnapshot.FIELD
	):
		return {}
	var record: Dictionary = SeasonFinalVenue.normalized(
		{
			"version": SeasonFinalVenue.HILLSIDE_VERSION,
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
		or record.manifest.field != StadiumNpcSnapshot.FIELD
		or record.manifest.id != "HILLSIDE"
		or record.manifest.revision != 1
		or SeasonFinalVenue.key(record) != binding.assignment_key
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
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

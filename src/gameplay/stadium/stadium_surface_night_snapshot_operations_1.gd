extends RefCounted
## Stateless operations for the original StadiumSurfaceNightSnapshot script.


static func _wrapped_policy_for(value: Variant, context: Dictionary) -> Dictionary:
	if (
		not value is Dictionary
		or not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._keys(
			value, ["version", "family", "mode", "season_seed", "run_id", "entry_key", "candidate"]
		)
		or not SeasonOwnership._whole(
			value.version, StadiumSurfaceNightSnapshot.VERSION, StadiumSurfaceNightSnapshot.VERSION
		)
		or value.family != StadiumSurfaceNightSnapshot.FAMILY
		or value.mode != "night"
		or not SeasonOwnership._whole(value.season_seed, 0, 2147483647)
		or not SeasonOwnership._whole(value.run_id, 0, 1000000)
		or not StadiumSurfaceNightSnapshot._digest(value.entry_key)
		or value.entry_key != context.entry_key
		or not value.candidate is Dictionary
	):
		return {}
	var candidate: Dictionary = value.candidate
	if (
		not SeasonOwnership._keys(candidate, ["candidate_version", "family", "contract", "entry"])
		or not SeasonOwnership._whole(candidate.candidate_version, 3, 3)
		or candidate.family != StadiumLightingKitNightCandidate.FAMILY
		or candidate.contract != StadiumLightingKitNightCandidate.contract_for(context.entry)
		or not candidate.entry is Dictionary
		or not ClubCareer.same(candidate.entry, context.entry)
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	for field: String in ["version", "season_seed", "run_id"]:
		result[field] = int(result[field])
	result.candidate.candidate_version = 3
	result.candidate.entry = context.entry.duplicate(true)
	return result


static func _wrapped_policy_season(context: Dictionary, season: SeasonState) -> bool:
	return (
		season != null
		and context.policy.season_seed == season.season_seed
		and context.policy.run_id == StadiumSurfaceNightSnapshot.run_id(season)
		and ClubCareer.same(context.entry, season.home_property)
	)


static func _wrapped_paid(context: Dictionary, paid: ClubAssetLedger) -> Dictionary:
	# Same complete original entry32/34 predicate as their matches(), with the
	# existing cold _validated_ownership already performed in this call.
	if paid == null or context.entry.revision > paid.revision():
		return {}
	var prefix: ClubAssetLedger = paid.prefix(int(context.entry.revision))
	if prefix == null:
		return {}
	var original: Dictionary = context.entry
	if (
		original.tier != prefix.view().land
		or not ClubCareer.same(original.layout, prefix.view().stadium_active)
		or not ClubCareer.same(original.inventory, prefix.construction().to_data())
		or not ClubCareer.same(original.wall_piece_inventory, prefix.wall_pieces().to_data())
		or not ClubCareer.same(original.scoreboard_inventory, prefix.scoreboards().to_data())
		or not ClubCareer.same(original.surface_access, prefix.surface_owned())
	):
		return {}
	return {"paid_prefix": StadiumSurfaceNightSnapshot._data(prefix.to_data()).sha256_text()}


static func _wrapped_expected(
	context: Dictionary, season: SeasonState, scheduled: Dictionary
) -> Dictionary:
	if not SeasonOwnership._whole(scheduled.get("id"), 0, 32):
		return {}
	if (
		not StadiumSurfaceNightSnapshot.expected(season, scheduled)
		or not StadiumSurfaceNightSnapshot._wrapped_policy_season(context, season)
		or not StadiumNpcSnapshot._json_types(season.home_property)
		or not ClubCareer.same(
			SeasonVenues.fixture_for_id(season, int(scheduled.get("id", -1))), scheduled
		)
	):
		return {}
	var seed: int = SeasonPhysicalFixtures.seed_for(season, scheduled)
	if (
		seed < 0
		or seed > 2147483647
		or seed != ((int(season.season_seed) + int(scheduled.id) * 104729) & 0x7fffffff)
	):
		return {}
	var result: Dictionary = context.entry.duplicate(true)
	result.version = StadiumSurfaceNightSnapshot.WRAPPED_FIXTURE_VERSION
	result["entry_version"] = int(context.entry.version)
	result["receipt_adapter"] = StadiumLightingKitNightReceiptAdapter.signature(
		StadiumLightingKitNightCandidate.signature()
	)
	result["family"] = StadiumSurfaceNightSnapshot.FIXTURE_FAMILY
	result["policy_key"] = StadiumSurfaceNightSnapshot._data(context.policy).sha256_text()
	result["binding"] = {
		"season_seed": int(season.season_seed),
		"run_id": int(StadiumSurfaceNightSnapshot.run_id(season)),
		"fixture": int(scheduled.id),
		"match_seed": SeasonPhysicalFixtures.seed_for(season, scheduled),
		"entry_key": context.entry_key
	}
	result["environment"] = {
		"version": StadiumSurfaceNightSnapshot.VERSION,
		"mode": "night",
		"profile": context.signature
	}
	return result


static func _wrapped_match(
	value: Dictionary, season: SeasonState, scheduled: Dictionary, paid: ClubAssetLedger
) -> Dictionary:
	if season == null:
		return {}
	var context: Dictionary = StadiumSurfaceNightSnapshot._wrapped_snapshot(value)
	if context.is_empty():
		return {}
	var policy: Dictionary = StadiumSurfaceNightSnapshot._wrapped_policy_for(
		season.owned_surface_night, context
	)
	if policy.is_empty():
		return {}
	var result: Dictionary = context.duplicate(true)
	result["policy"] = policy
	if not StadiumSurfaceNightSnapshot._wrapped_policy_season(result, season):
		return {}
	var supplied: Dictionary = StadiumSurfaceNightSnapshot._wrapped_paid(result, paid)
	if supplied.is_empty():
		return {}
	# fixture() historically proves the season's own ledger independently. It is
	# not replaced by the caller's paid ledger, even when their values look alike.
	var season_paid: ClubAssetLedger = StadiumSurfaceNightSnapshot.ledger(season)
	if StadiumSurfaceNightSnapshot._wrapped_paid(result, season_paid).is_empty():
		return {}
	var expected_snapshot: Dictionary = StadiumSurfaceNightSnapshot._wrapped_expected(
		result, season, scheduled
	)
	if (
		expected_snapshot.is_empty()
		or result.snapshot_key != StadiumSurfaceNightSnapshot._data(expected_snapshot).sha256_text()
	):
		return {}
	result["proof"] = StadiumSurfaceNightSnapshot._wrapped_proof(result, policy, supplied)
	return StadiumSurfaceNightSnapshot._wrapped_freeze(result)


static func _wrapped_proof(
	context: Dictionary, policy: Dictionary, supplied: Dictionary
) -> Dictionary:
	return {
		"version": StadiumSurfaceNightSnapshot.VERSION,
		"profile": context.signature,
		"policy": policy.duplicate(true),
		"paid_prefix": supplied.paid_prefix
	}


static func _wrapped_proof_valid(value: Variant, snapshot: Dictionary) -> bool:
	var context: Dictionary = StadiumSurfaceNightSnapshot._wrapped_snapshot(snapshot)
	if (
		context.is_empty()
		or not value is Dictionary
		or not SeasonOwnership._keys(value, ["version", "profile", "policy", "paid_prefix"])
		or not SeasonOwnership._whole(
			value.version, StadiumSurfaceNightSnapshot.VERSION, StadiumSurfaceNightSnapshot.VERSION
		)
		or value.profile != context.signature
		or not StadiumSurfaceNightSnapshot._digest(value.paid_prefix)
	):
		return false
	var policy: Dictionary = StadiumSurfaceNightSnapshot._wrapped_policy_for(value.policy, context)
	return (
		not policy.is_empty()
		and snapshot.policy_key == StadiumSurfaceNightSnapshot._data(policy).sha256_text()
		and snapshot.binding.season_seed == policy.season_seed
		and snapshot.binding.run_id == policy.run_id
	)


static func _wrapped_runtime_admission(
	value: Dictionary, season: SeasonState, scheduled: Dictionary, paid: ClubAssetLedger
) -> Dictionary:
	# Fresh raw inputs only; no caller can inject a prior validated context here.
	return StadiumSurfaceNightSnapshot._wrapped_match(value, season, scheduled, paid)


static func _wrapped_acceptance_owner(season: SeasonState) -> bool:
	# Overridden owners retain HumanEvidence.accepts()'s original cold path. This
	# is only eligibility, never a proof of paid ownership or a reusable permission.
	return (
		season != null
		and season.get_script() == SeasonState
		and (season.career == null or season.career.get_script() == ClubCareer)
		and (
			season._pool_replay_ledger == null
			or season._pool_replay_ledger.get_script() == ClubAssetLedger
		)
	)


static func _wrapped_accepts_human(
	value: Dictionary, night: Variant, season: SeasonState, scheduled: Dictionary
) -> bool:
	# Raw inputs only. Resolve this acceptance's own ledger once, before creating
	# the detached admission; never carry _pool_replay_ledger across decode calls.
	if not StadiumSurfaceNightSnapshot._wrapped_acceptance_owner(season):
		return false
	var paid: ClubAssetLedger = StadiumSurfaceNightSnapshot.ledger(season)
	if paid == null or paid.get_script() != ClubAssetLedger:
		return false
	var context: Dictionary = StadiumSurfaceNightSnapshot._wrapped_snapshot(value)
	if context.is_empty():
		return false
	# Exact proof_valid predicates, using only this freshly admitted snapshot.
	if (
		not night is Dictionary
		or not SeasonOwnership._keys(night, ["version", "profile", "policy", "paid_prefix"])
		or not SeasonOwnership._whole(
			night.version, StadiumSurfaceNightSnapshot.VERSION, StadiumSurfaceNightSnapshot.VERSION
		)
		or night.profile != context.signature
		or not StadiumSurfaceNightSnapshot._digest(night.paid_prefix)
	):
		return false
	var proof_policy: Dictionary = StadiumSurfaceNightSnapshot._wrapped_policy_for(
		night.policy, context
	)
	if (
		proof_policy.is_empty()
		or (
			context.snapshot.policy_key
			!= StadiumSurfaceNightSnapshot._data(proof_policy).sha256_text()
		)
		or context.snapshot.binding.season_seed != proof_policy.season_seed
		or context.snapshot.binding.run_id != proof_policy.run_id
	):
		return false
	var policy: Dictionary = StadiumSurfaceNightSnapshot._wrapped_policy_for(
		season.owned_surface_night, context
	)
	if policy.is_empty():
		return false
	var bound: Dictionary = context.duplicate(true)
	bound["policy"] = policy
	bound = StadiumSurfaceNightSnapshot._wrapped_freeze(bound)
	if not StadiumSurfaceNightSnapshot._wrapped_policy_season(bound, season):
		return false
	var expected_snapshot: Dictionary = StadiumSurfaceNightSnapshot._wrapped_expected(
		bound, season, scheduled
	)
	if (
		expected_snapshot.is_empty()
		or bound.snapshot_key != StadiumSurfaceNightSnapshot._data(expected_snapshot).sha256_text()
	):
		return false
	# This path has no independently supplied ledger. The exact ledger prefix is
	# reconstructed once, then serves both the fixture and expected proof checks.
	# Generic matches_fixture() still proves supplied and season ledgers separately.
	var paid_proof: Dictionary = StadiumSurfaceNightSnapshot._wrapped_paid(bound, paid)
	return (
		not paid_proof.is_empty()
		and ClubCareer.same(
			night, StadiumSurfaceNightSnapshot._wrapped_proof(bound, policy, paid_proof)
		)
	)

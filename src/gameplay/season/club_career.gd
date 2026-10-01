class_name ClubCareer
extends RefCounted
# gdlint: disable=max-returns
## One persistent ledger, embedded atomically with its active season. No power carries over.

const MAX_RUNS: int = 1024
var current: int = 0
var runs: Array[Dictionary] = []


func fork() -> ClubCareer:
	var result: ClubCareer = ClubCareer.new()
	result.current = current
	result.runs = runs.duplicate(true)
	return result


func start(season: SeasonState) -> bool:
	if season.phase != SeasonState.Phase.DRAFT or not season.picks.is_empty():
		return false
	if current != 0 or runs.size() >= MAX_RUNS or season.build == null or season.opponents == null:
		return false
	season.build._gear_progress.enabled = true
	season.build._gear_progress.start = gear_counts()
	season.build._sponsor_progress.enabled = true
	season.build._sponsor_progress.start = sponsor_state()
	season.build._order_start = order_access()
	season.build._rain_start = rain_access()
	season.build._transfer_start = transfer_access()
	season.build._supply_start = supply_count()
	season.build._checkout_start = SeasonLateCheckout.access(self)
	season.build._association_start = SeasonAssociation.access(self)
	season.build._freezer_start = SeasonFreezers.access(self)
	season.build._sides_start = SeasonLeftRight.access(self)
	season.build._jump_start = SeasonJumpstart.access(self)
	season.build._sure_start = SeasonSureShot.access(self)
	season.build._abilities.start = SeasonAbilities.access(self)
	season.build._copy.start = SeasonCarbonCopy.access(self)
	season.build._field_start = SeasonFieldSupply.access(self)
	season.build._batch_start = SeasonSmallBatch.access(self)
	current = runs.size() + 1
	runs.append(
		{
			"id": current,
			"seed": season.season_seed,
			"league": "standard",
			"tier": 0,
			"status": "active",
			"proof": ClubSeasonRecord.capture(season),
			"receipt": {},
			"gear": [],
			"sponsors": [],
			"order_rerolls": 0,
			"rain_earned": false,
			"transfer_earned": false,
			"checkout_earned": false,
			"association_earned": false,
			"freezer_earned": false,
			"sides_earned": false,
			"jump_earned": false,
			"sure_earned": false,
			"sky_outs": 0,
			"copy_earned": false,
			"field_outs": 0,
			"batch_used": [],
			"supplies_used": 0
		}
	)
	return true


func sync(season: SeasonState) -> bool:
	if current == 0:
		return season.build == null
	if current != runs.size() or season.season_seed != runs[-1].seed:
		return false
	var run: Dictionary = runs[-1]
	if (
		not gear_matches(season, false)
		or not sponsor_matches(season, false)
		or not order_matches(season, false)
		or not rain_matches(season, false)
		or not transfer_matches(season, false)
		or not supply_matches(season, false)
		or not SeasonLateCheckout.matches(self, season, false)
		or not SeasonAssociation.matches(self, season, false)
		or not SeasonFreezers.matches(self, season, false)
		or not SeasonLeftRight.matches(self, season, false)
		or not SeasonJumpstart.matches(self, season, false)
		or not SeasonSureShot.matches(self, season, false)
		or not SeasonCarbonCopy.matches(self, season, false)
		or not SeasonFieldSupply.matches(self, season, false)
		or not SeasonAbilities.matches(self, season, false)
		or not SeasonSmallBatch.matches(self, season, false)
	):
		return false
	var gear: Variant = (
		season.build._gear_progress.games.duplicate(true) if run.gear != null else null
	)
	var sponsors: Variant = (
		season.build._sponsor_progress.games.duplicate(true) if run.sponsors != null else null
	)
	var orders: Variant = season.build._paid_rerolls if run.order_rerolls != null else null
	var rain: Variant = season.build._rain_earned if run.rain_earned != null else null
	var transfer: Variant = season.build._transfer_earned if run.transfer_earned != null else null
	var supplies: Variant = season.build._supply_used if run.supplies_used != null else null
	var checkout: Variant = season.build._checkout_earned if run.checkout_earned != null else null
	var association: Variant = (
		season.build._association_earned if run.association_earned != null else null
	)
	var freezer: Variant = season.build._freezer_earned if run.freezer_earned != null else null
	var sides: Variant = season.build._sides_earned if run.sides_earned != null else null
	var jump: Variant = season.build._jump_earned if run.jump_earned != null else null
	var sure: Variant = season.build._sure_earned if run.sure_earned != null else null
	var sky: Variant = season.build._abilities.earned if run.sky_outs != null else null
	var copy: Variant = season.build._copy.earned if run.copy_earned != null else null
	var field: Variant = season.build._field_outs if run.field_outs != null else null
	var batch: Variant = season.build._batch_used.duplicate() if run.batch_used != null else null
	var proof: Dictionary = ClubSeasonRecord.capture(season)
	if run.status == "completed":
		return (
			season.phase == SeasonState.Phase.COMPLETE
			and same(run.proof, proof)
			and same(run.gear, gear)
			and same(run.sponsors, sponsors)
			and run.order_rerolls == orders
			and run.rain_earned == rain
			and run.transfer_earned == transfer
			and run.supplies_used == supplies
			and run.checkout_earned == checkout
			and run.association_earned == association
			and run.freezer_earned == freezer
			and run.sides_earned == sides
			and run.jump_earned == jump
			and run.sure_earned == sure
			and run.sky_outs == sky
			and run.copy_earned == copy
			and run.field_outs == field
			and same(run.batch_used, batch)
		)
	if run.status != "active":
		return false
	if season.phase == SeasonState.Phase.COMPLETE:
		var award: Dictionary = ClubSeasonRecord.receipt(proof, not cleared())
		if award.is_empty():
			return false
		run.receipt = award
		run.status = "completed"
	run.proof = proof
	run.gear = gear
	run.sponsors = sponsors
	run.order_rerolls = orders
	run.rain_earned = rain
	run.transfer_earned = transfer
	run.supplies_used = supplies
	run.checkout_earned = checkout
	run.association_earned = association
	run.freezer_earned = freezer
	run.sides_earned = sides
	run.jump_earned = jump
	run.sure_earned = sure
	run.sky_outs = sky
	run.copy_earned = copy
	run.field_outs = field
	run.batch_used = batch
	return true


func close(season: SeasonState) -> bool:
	if not sync(season):
		return false
	if current > 0 and runs[-1].status == "active":
		runs[-1].status = "abandoned"
	current = 0
	return true


func balance() -> int:
	var total: int = 0
	for run: Dictionary in runs:
		total += int(run.receipt.get("total", 0))
	return total


func cleared() -> bool:
	for run: Dictionary in runs:
		if run.receipt.get("finish") == "champion":
			return true
	return false


func to_data() -> Dictionary:
	return {"version": 17, "current": current, "runs": runs.duplicate(true)}


static func same(a: Variant, b: Variant) -> bool:
	return (
		JSON.parse_string(JSON.stringify(a, "", true, true))
		== JSON.parse_string(JSON.stringify(b, "", true, true))
	)


static func from_data(value: Variant) -> ClubCareer:
	if not value is Dictionary or not SeasonOwnership._keys(value, ["version", "current", "runs"]):
		return null
	if (
		not SeasonOwnership._whole(value.version, 1, 17)
		or not value.runs is Array
		or value.runs.size() > MAX_RUNS
	):
		return null
	if not SeasonOwnership._whole(value.current, 0, value.runs.size()):
		return null
	if value.current != 0 and value.current != value.runs.size():
		return null
	var result: ClubCareer = ClubCareer.new()
	result.current = int(value.current)
	for row: Variant in value.runs:
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(
				row,
				(
					["id", "seed", "league", "tier", "status", "proof", "receipt"]
					+ (["gear"] if value.version >= 2 else [])
					+ (["sponsors"] if value.version >= 3 else [])
					+ (["order_rerolls"] if value.version >= 4 else [])
					+ (["rain_earned"] if value.version >= 5 else [])
					+ (["transfer_earned"] if value.version >= 6 else [])
					+ (["supplies_used"] if value.version >= 7 else [])
					+ (["checkout_earned"] if value.version >= 8 else [])
					+ (["association_earned"] if value.version >= 9 else [])
					+ (["freezer_earned"] if value.version >= 10 else [])
					+ (["sides_earned"] if value.version >= 11 else [])
					+ (["jump_earned"] if value.version >= 12 else [])
					+ (["batch_used"] if value.version >= 13 else [])
					+ (["sure_earned"] if value.version >= 14 else [])
					+ (["copy_earned"] if value.version >= 16 else [])
					+ (["sky_outs"] if value.version >= 17 else [])
					+ (["field_outs"] if value.version >= 15 else [])
				)
			)
		):
			return null
		if row.id != result.runs.size() + 1 or not SeasonOwnership._whole(row.seed, 0, 2147483647):
			return null
		if (
			row.league != "standard"
			or row.tier != 0
			or row.status not in ["active", "completed", "abandoned"]
		):
			return null
		if not row.receipt is Dictionary:
			return null
		var record: Dictionary = ClubSeasonRecord.analyze(row.proof)
		if record.is_empty():
			return null
		if row.status == "completed":
			var expected: Dictionary = ClubSeasonRecord.receipt(row.proof, not result.cleared())
			if expected.is_empty() or not same(row.receipt, expected):
				return null
		elif not row.receipt.is_empty() or record.finish != "unfinished":
			return null
		if row.status == "active" and row.id != result.current:
			return null
		if row.status == "abandoned" and row.id == result.current:
			return null
		var migrated: Dictionary = row.duplicate(true)
		if value.version == 1:
			migrated["gear"] = null
		if (
			migrated.gear != null
			and not SeasonGearProgress.valid_games(
				migrated.gear, row.proof.scores, result.gear_counts()
			)
		):
			return null
		if value.version < 3:
			migrated["sponsors"] = null
		if (
			migrated.sponsors != null
			and not SeasonSponsorProgress.valid_games(migrated.sponsors, row.proof.scores)
		):
			return null
		if value.version < 4:
			migrated["order_rerolls"] = null
		if (
			migrated.order_rerolls != null
			and not SeasonOwnership._whole(migrated.order_rerolls, 0, SeasonBuild.MAX_EVENTS)
		):
			return null
		if value.version < 5:
			migrated["rain_earned"] = null
		if migrated.rain_earned != null and not migrated.rain_earned is bool:
			return null
		if value.version < 6:
			migrated["transfer_earned"] = null
		if migrated.transfer_earned != null and not migrated.transfer_earned is bool:
			return null
		if value.version < 7:
			migrated["supplies_used"] = null
		if migrated.supplies_used != null:
			if not SeasonOwnership._whole(migrated.supplies_used, 0, SeasonBuild.MAX_EVENTS):
				return null
		if value.version < 8:
			migrated["checkout_earned"] = null
		if migrated.checkout_earned != null and not migrated.checkout_earned is bool:
			return null
		if value.version < 9:
			migrated["association_earned"] = null
		if migrated.association_earned != null and not migrated.association_earned is bool:
			return null
		if value.version < 10:
			migrated["freezer_earned"] = null
		if migrated.freezer_earned != null and not migrated.freezer_earned is bool:
			return null
		if value.version < 11:
			migrated["sides_earned"] = null
		if migrated.sides_earned != null and not migrated.sides_earned is bool:
			return null
		if value.version < 12:
			migrated["jump_earned"] = null
		if migrated.jump_earned != null and not migrated.jump_earned is bool:
			return null
		if value.version < 17:
			migrated["sky_outs"] = null
		if migrated.sky_outs != null and not SeasonOwnership._whole(migrated.sky_outs, 0, 3):
			return null
		if value.version < 16:
			migrated["copy_earned"] = null
		if migrated.copy_earned != null and not migrated.copy_earned is bool:
			return null
		if value.version < 15:
			migrated["field_outs"] = null
		if (
			migrated.field_outs != null
			and not SeasonOwnership._whole(migrated.field_outs, 0, 329967)
		):
			return null
		if value.version < 14:
			migrated["sure_earned"] = null
		if migrated.sure_earned != null and not migrated.sure_earned is bool:
			return null
		if value.version < 13:
			migrated["batch_used"] = null
		if migrated.batch_used != null and not SeasonSmallBatch.valid(migrated.batch_used):
			return null
		result.runs.append(migrated)
	return result


func matches(season: SeasonState) -> bool:
	if current == 0:
		return season.build == null
	if season.build == null or season.opponents == null or current != runs.size():
		return false
	var run: Dictionary = runs[-1]
	return (
		run.seed == season.season_seed
		and (run.status == "completed") == (season.phase == SeasonState.Phase.COMPLETE)
		and same(run.proof, ClubSeasonRecord.capture(season))
		and gear_matches(season, true)
		and sponsor_matches(season, true)
		and order_matches(season, true)
		and rain_matches(season, true)
		and transfer_matches(season, true)
		and supply_matches(season, true)
		and SeasonLateCheckout.matches(self, season, true)
		and SeasonAssociation.matches(self, season, true)
		and SeasonFreezers.matches(self, season, true)
		and SeasonLeftRight.matches(self, season, true)
		and SeasonJumpstart.matches(self, season, true)
		and SeasonSureShot.matches(self, season, true)
		and SeasonCarbonCopy.matches(self, season, true)
		and SeasonFieldSupply.matches(self, season, true)
		and SeasonAbilities.matches(self, season, true)
		and SeasonSmallBatch.matches(self, season, true)
	)


func gear_counts(before_current: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for run: Dictionary in runs:
		if before_current and run.id == current:
			break
		if run.gear != null:
			result = SeasonGearProgress.add(result, run.gear)
	return result


func gear_matches(season: SeasonState, exact: bool) -> bool:
	if season.build == null:
		return false
	var run: Dictionary = runs[-1]
	var progress: SeasonGearProgress = season.build._gear_progress
	if (run.gear != null) != progress.enabled:
		return false
	if not progress.enabled:
		return true
	return (
		same(progress.start, gear_counts(true))
		and SeasonGearProgress.valid_games(
			progress.games, ClubSeasonRecord.capture(season).scores, progress.start
		)
		and (not exact or same(run.gear, progress.games))
	)


func sponsor_state(before_current: bool = false) -> Dictionary:
	var result: Dictionary = {"hits": [], "encore": false}
	for run: Dictionary in runs:
		if before_current and run.id == current:
			break
		if run.sponsors != null:
			result = SeasonSponsorProgress.add(result, run.sponsors)
	return result


func sponsor_matches(season: SeasonState, exact: bool) -> bool:
	if season.build == null:
		return false
	var run: Dictionary = runs[-1]
	var progress: SeasonSponsorProgress = season.build._sponsor_progress
	if (run.sponsors != null) != progress.enabled:
		return false
	if not progress.enabled:
		return true
	return (
		same(progress.start, sponsor_state(true))
		and SeasonSponsorProgress.valid_games(
			progress.games, ClubSeasonRecord.capture(season).scores
		)
		and (not exact or same(run.sponsors, progress.games))
	)


func order_access(before_current: bool = false) -> bool:
	for run: Dictionary in runs:
		if before_current and run.id == current:
			break
		if run.order_rerolls != null and run.order_rerolls >= 3:
			return true
	return false


func order_matches(season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = runs[-1]
	if (run.order_rerolls != null) != (build._order_start != null):
		return false
	if build._order_start == null:
		return true
	return (
		build._order_start == order_access(true)
		and (not exact or run.order_rerolls == build._paid_rerolls)
	)


func rain_access(before_current: bool = false) -> bool:
	for run: Dictionary in runs:
		if before_current and run.id == current:
			break
		if run.rain_earned == true:
			return true
	return false


func rain_matches(season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = runs[-1]
	if (run.rain_earned != null) != (build._rain_start != null):
		return false
	return (
		build._rain_start == null
		or (
			build._rain_start == rain_access(true)
			and (not exact or run.rain_earned == build._rain_earned)
		)
	)


func transfer_access(before_current: bool = false) -> bool:
	for run: Dictionary in runs:
		if before_current and run.id == current:
			break
		if run.transfer_earned == true:
			return true
	return false


func transfer_matches(season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = runs[-1]
	if (run.transfer_earned != null) != (build._transfer_start != null):
		return false
	return (
		build._transfer_start == null
		or (
			build._transfer_start == transfer_access(true)
			and (not exact or run.transfer_earned == build._transfer_earned)
		)
	)


func supply_count(before_current: bool = false) -> int:
	var count: int = 0
	for run: Dictionary in runs:
		if before_current and run.id == current:
			break
		if run.supplies_used != null:
			count = mini(3, count + int(run.supplies_used))
	return count


func supply_matches(season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = runs[-1]
	if (run.supplies_used != null) != (build._supply_start != null):
		return false
	return (
		build._supply_start == null
		or (
			build._supply_start == supply_count(true)
			and (not exact or run.supplies_used == build._supply_used)
		)
	)

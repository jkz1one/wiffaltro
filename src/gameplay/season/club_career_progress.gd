extends RefCounted
## Private inherited progression queries for the persistent ClubCareer ledger.

var current: int = 0
var runs: Array[Dictionary] = []


static func same(a: Variant, b: Variant) -> bool:
	return (
		JSON.parse_string(JSON.stringify(a, "", true, true))
		== JSON.parse_string(JSON.stringify(b, "", true, true))
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

extends RefCounted
## Session deltas only. Caller owns replay authority, unique identities and replacement order.
const VERSION: int = 3
const TIER_VERSION: int = 4
const FLAGS: Array[String] = [
	"rain", "transfer", "checkout", "association", "freezer", "sides", "jump", "sure",
	"major", "copy"
]
const FIELDS: Array[String] = [
	"version", "proof", "gear", "sponsors", "order_rerolls", "supplies_used", "sky_outs",
	"field_outs", "batch_used", "collection", "player_progress", "pitch_catalog"
]


static func capture(season: SeasonState) -> Dictionary:
	if season == null or season.build == null or not season.build.pitch_catalog_current() or season.career != null \
		or not ClosedContentAccess.matches(season.build, season._closed_access):
		return {}
	var build: SeasonBuild = season.build
	var result: Dictionary = {
		"version": TIER_VERSION if LeagueRules.tiered(season.league_rules) else VERSION,
		"proof": ClubSeasonRecord.capture(season),
		"gear": build._gear_progress.games.duplicate(true),
		"sponsors": build._sponsor_progress.games.duplicate(true),
		"order_rerolls": build._paid_rerolls, "supplies_used": build._supply_used,
		"sky_outs": build._abilities.earned, "field_outs": build._field_outs,
		"batch_used": build._batch_used.duplicate(),
		"collection": ClubCollection.acquired(build),
		"player_progress": WorkingPitchCareerProgress.capture(season),
		"pitch_catalog": WorkingPitchCatalog.signature()
	}
	for flag: String in FLAGS:
		result[flag + "_earned"] = build._major.earned if flag == "major" else (
			build._copy.earned if flag == "copy" else build.get("_" + flag + "_earned"))
	return result if valid(result, season._closed_access) else {}


static func valid(value: Variant, baseline: Dictionary) -> bool:
	var start: Dictionary = ClosedContentAccess.normalize(baseline)
	var fields: Array = FIELDS.duplicate()
	for flag: String in FLAGS:
		fields.append(flag + "_earned")
	if start.is_empty() or not value is Dictionary or not SeasonOwnership._keys(value, fields) \
		or value.pitch_catalog != WorkingPitchCatalog.signature():
		return false
	if not SeasonOwnership._whole(value.version, VERSION, TIER_VERSION) \
		or ClubSeasonRecord.analyze(value.proof).is_empty():
		return false
	var rules: Dictionary = LeagueRules.normalized(value.proof.get("league_rules"))
	if rules.is_empty() or (value.version == TIER_VERSION) != LeagueRules.tiered(rules) \
		or not _metrics_valid(value, start.progress):
		return false
	for flag: String in FLAGS:
		if not value[flag + "_earned"] is bool:
			return false
	return true


static func _metrics_valid(value: Dictionary, baseline: Dictionary) -> bool:
	return (
		SeasonGearProgress.valid_games(value.gear, value.proof.scores, baseline.gear_start)
		and SeasonSponsorProgress.valid_games(value.sponsors, value.proof.scores)
		and SeasonOwnership._whole(value.order_rerolls, 0, SeasonBuild.MAX_EVENTS)
		and SeasonOwnership._whole(value.supplies_used, 0, SeasonBuild.MAX_EVENTS)
		and SeasonOwnership._whole(value.sky_outs, 0, 3)
		and SeasonOwnership._whole(value.field_outs, 0, 329967)
		and SeasonSmallBatch.valid(value.batch_used)
		and ClubCollection.valid(value.collection)
		and WorkingPitchCareerProgress.valid(value.player_progress, value.proof.scores)
	)


static func access(origin: Dictionary, contributions: Array) -> Dictionary:
	var result: Dictionary = ClosedContentAccess.normalize(origin).duplicate(true)
	if result.is_empty():
		return {}
	for entry: Variant in contributions:
		if not entry is Dictionary or not SeasonOwnership._keys(entry, ["baseline", "progress"]):
			return {}
		if not entry.baseline is Dictionary or not valid(entry.progress, entry.baseline) \
			or not ClosedContentAccess.same_origin(origin, entry.baseline):
			return {}
		_fold(result.progress, entry.progress)
	return ClosedContentAccess.normalize(result)


static func _fold(progress: Dictionary, delta: Dictionary) -> void:
	progress.gear_start = SeasonGearProgress.add(progress.gear_start, delta.gear)
	progress.sponsor_start = SeasonSponsorProgress.add(progress.sponsor_start, delta.sponsors)
	progress.order_start = progress.order_start or delta.order_rerolls >= 3
	progress.field_start = progress.field_start or delta.field_outs >= 6
	progress.supply_start = mini(3, int(progress.supply_start) + int(delta.supplies_used))
	progress.ability_start = mini(3, int(progress.ability_start) + int(delta.sky_outs))
	progress.batch_start = SeasonSmallBatch.combine(progress.batch_start, delta.batch_used)
	for flag: String in FLAGS:
		progress[flag + "_start"] = progress[flag + "_start"] or delta[flag + "_earned"]

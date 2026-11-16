class_name ClosedContentAccess
extends RefCounted
## Exact offline source-bound content eligibility, never inventory or admission.
## normalize is consistency only; first owner creation requalifies capture's source.

const VERSION: int = 1
const RULE: String = "closed-owner-content-access-v1"
const FIELDS: Array[String] = [
	"gear_start",
	"sponsor_start",
	"order_start",
	"rain_start",
	"transfer_start",
	"supply_start",
	"checkout_start",
	"association_start",
	"freezer_start",
	"sides_start",
	"jump_start",
	"sure_start",
	"major_start",
	"ability_start",
	"copy_start",
	"field_start",
	"batch_start"
]
const FLAGS: Array[String] = [
	"order",
	"rain",
	"transfer",
	"checkout",
	"association",
	"freezer",
	"sides",
	"jump",
	"sure",
	"major",
	"copy",
	"field"
]


static func capture(source: Variant, owner: String) -> Dictionary:
	var season: SeasonState = SeasonSave._decode(source)
	if season == null or season.career == null or not season.career.matches(season):
		return {}
	return _capture_checked(season.career, source, owner)


static func _capture_checked(club: ClubCareer, source: Dictionary, owner: String) -> Dictionary:
	# Caller owns the successful full decode of this exact career-season source.
	return normalize(
		{
			"version": VERSION,
			"rule": RULE,
			"owner_id": owner,
			"source": {"kind": "career-season", "sha256": digest(source)},
			"progress":
			{
				"gear_start": club.gear_counts(),
				"sponsor_start": club.sponsor_state(),
				"order_start": club.order_access(),
				"rain_start": club.rain_access(),
				"transfer_start": club.transfer_access(),
				"supply_start": club.supply_count(),
				"checkout_start": SeasonLateCheckout.access(club),
				"association_start": SeasonAssociation.access(club),
				"freezer_start": SeasonFreezers.access(club),
				"sides_start": SeasonLeftRight.access(club),
				"jump_start": SeasonJumpstart.access(club),
				"sure_start": SeasonSureShot.access(club),
				"major_start": SeasonDoubleMajor.access(club),
				"ability_start": SeasonAbilities.access(club),
				"copy_start": SeasonCarbonCopy.access(club),
				"field_start": SeasonFieldSupply.access(club),
				"batch_start": SeasonSmallBatch.access(club)
			}
		}
	)


static func normalize(value: Variant) -> Dictionary:
	if (
		not _keys(value, ["version", "rule", "owner_id", "source", "progress"])
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or value.rule != RULE
		or not value.owner_id is String
		or value.owner_id.is_empty()
		or value.owner_id.length() > 160
		or not _keys(value.source, ["kind", "sha256"])
		or value.source.kind != "career-season"
		or not _digest_valid(value.source.sha256)
		or not _keys(value.progress, FIELDS)
	):
		return {}
	var progress: Dictionary = value.progress
	if (
		not SeasonGearProgress.valid_counts(progress.gear_start)
		or not SeasonSponsorProgress.valid_state(progress.sponsor_start)
		or not SeasonOwnership._whole(progress.supply_start, 0, 3)
		or not SeasonOwnership._whole(progress.ability_start, 0, 3)
		or not SeasonSmallBatch.valid(progress.batch_start)
	):
		return {}
	for flag: String in FLAGS:
		if not progress[flag + "_start"] is bool:
			return {}
	var result: Dictionary = value.duplicate(true)
	result.version = VERSION
	result.progress.supply_start = int(progress.supply_start)
	result.progress.ability_start = int(progress.ability_start)
	for id: String in result.progress.gear_start:
		result.progress.gear_start[id] = int(result.progress.gear_start[id])
	_freeze(result)
	return result


static func install(build: SeasonBuild, value: Variant) -> bool:
	var access: Dictionary = normalize(value)
	if (
		access.is_empty()
		or build == null
		or build._market != 0
		or build._league_rules.is_empty()
		or build.revision() != 0
		or build._bank.revision() != 0
		or not build._requests.is_empty()
		or int(build._visit.number) != 0
		or SeasonInventoryResale.enabled(build._bank)
	):
		return false
	# Installing twice with the exact baseline is harmless; a different baseline
	# cannot replace an installed start, even on a still-empty draft journal.
	if not untracked(build):
		return matches(build, access)
	var progress: Dictionary = access.progress
	build._gear_progress.enabled = true
	build._gear_progress.start = progress.gear_start.duplicate(true)
	build._sponsor_progress.enabled = true
	build._sponsor_progress.start = progress.sponsor_start.duplicate(true)
	for field: String in FIELDS:
		if field in ["gear_start", "sponsor_start"]:
			continue
		var entry: Variant = progress[field]
		if field == "major_start":
			build._major.start = entry
		elif field == "ability_start":
			build._abilities.start = entry
		elif field == "copy_start":
			build._copy.start = entry
		else:
			build.set(
				"_" + field,
				entry.duplicate(true) if entry is Array or entry is Dictionary else entry
			)
	return matches(build, access)


static func matches(build: SeasonBuild, value: Variant) -> bool:
	return build != null and matches_data(build.to_data(), value)


static func matches_data(data: Dictionary, value: Variant) -> bool:
	var access: Dictionary = normalize(value)
	if access.is_empty() or data.get("market") != 0:
		return false
	for field: String in FIELDS:
		if not data.has(field) or not ClubCareer.same(data[field], access.progress[field]):
			return false
	return true


static func untracked(build: SeasonBuild) -> bool:
	if build == null:
		return false
	var data: Dictionary = build.to_data()
	for field: String in FIELDS:
		if data.get(field) != null:
			return false
	return true


static func _fold_replayed(build: SeasonBuild, baseline: Variant) -> Dictionary:
	# Private extraction: callers must hold this exact freshly replayed source.
	var access: Dictionary = normalize(baseline)
	if access.is_empty() or not matches(build, access):
		return {}
	var next: Dictionary = access.duplicate(true)
	var progress: Dictionary = next.progress
	progress.gear_start = SeasonGearProgress.add(progress.gear_start, build._gear_progress.games)
	progress.sponsor_start = SeasonSponsorProgress.add(
		progress.sponsor_start, build._sponsor_progress.games
	)
	progress.order_start = progress.order_start or build._paid_rerolls >= 3
	progress.field_start = progress.field_start or build._field_outs >= 6
	progress.supply_start = mini(3, int(progress.supply_start) + build._supply_used)
	progress.ability_start = mini(3, int(progress.ability_start) + build._abilities.earned)
	progress.batch_start = SeasonSmallBatch.combine(progress.batch_start, build._batch_used)
	progress.major_start = progress.major_start or build._major.earned
	progress.copy_start = progress.copy_start or build._copy.earned
	for flag: String in [
		"rain", "transfer", "checkout", "association", "freezer", "sides", "jump", "sure"
	]:
		progress[flag + "_start"] = progress[flag + "_start"] or build.get("_" + flag + "_earned")
	return normalize(next)


static func same_origin(first: Dictionary, second: Dictionary) -> bool:
	return (
		first.get("owner_id") == second.get("owner_id")
		and ClubCareer.same(first.get("source"), second.get("source"))
	)


static func digest(source: Dictionary) -> String:
	# Canonical JSON transport preserves full numeric precision while making
	# runtime integers and their parsed integral-float representation identical.
	return (
		JSON
		. stringify(JSON.parse_string(JSON.stringify(source, "", true, true)), "", true, true)
		. sha256_text()
	)


static func _digest_valid(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values():
			_freeze(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value:
			_freeze(child)
		value.make_read_only()


static func _keys(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size():
		return false
	for field: String in fields:
		if not value.has(field):
			return false
	return true

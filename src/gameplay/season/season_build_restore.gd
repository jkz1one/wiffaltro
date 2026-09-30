class_name SeasonBuildRestore
extends RefCounted
# gdlint: disable=max-returns


static func restore(
	value: Variant,
	seed_value: int,
	roster: Array[String],
	pool: Array[String] = [],
	blocked: Array[String] = []
) -> SeasonBuild:
	if (
		not value is Dictionary
		or not SeasonOwnership._whole(value.get("version"), 1, SeasonBuild.VERSION)
	):
		return null
	var keys: Array = ["version", "seed", "roster", "catalog", "events"]
	if value.version >= 2:
		keys.append_array(["pool", "blocked", "recruit_from", "recruits"])
	if value.version >= 3:
		keys.append("gear_from")
	if value.version >= 4:
		keys.append("misc_from")
	if value.version >= 5:
		keys.append("mapped_gear_from")
	if value.version >= 6:
		keys.append("sponsor_from")
	if value.version >= 7:
		keys.append("gameplay_sponsor_from")
	if value.version >= 8:
		keys.append("sequence_sponsor_from")
	if value.version >= 9:
		keys.append("field_sponsor_from")
	if value.version >= 10:
		keys.append("shop_sponsor_from")
	if value.version >= 11:
		keys.append("school_sponsor_from")
	if value.version >= 12:
		keys.append("anchor_sponsor_from")
	if value.version >= 13:
		keys.append("wholesale_from")
	if value.version >= 14:
		keys.append("tactical_from")
	if value.version >= 15:
		keys.append("expanded_tactical_from")
	if value.version >= 16:
		keys.append("tactical_sponsor_from")
	if value.version >= 17:
		keys.append("budget_from")
	if value.version >= 18:
		keys.append("film_from")
	if value.version >= 19:
		keys.append("market")
	if value.version >= 20:
		keys.append("gear_start")
	if not SeasonOwnership._keys(value, keys):
		return null
	if value.seed != seed_value or value.roster != roster:
		return null
	if (
		value.catalog != SeasonBuild._signature(int(value.version))
		or not value.events is Array
		or value.events.size() > SeasonBuild.MAX_EVENTS
	):
		return null
	var result: SeasonBuild = SeasonBuild.new(seed_value, roster, pool, blocked)
	result._format = int(value.version)
	if value.version >= 2:
		if (
			value.pool != result._pool
			or value.blocked != result._blocked
			or not SeasonOwnership._whole(value.recruit_from, 1, 13)
			or not value.recruits is Array
		):
			return null
		result._recruit_from = int(value.recruit_from)
	if value.version >= 3:
		if not SeasonOwnership._whole(value.gear_from, 1, 13):
			return null
		result._gear_from = int(value.gear_from)
	if value.version >= 4:
		if not SeasonOwnership._whole(value.misc_from, 1, 13):
			return null
		result._misc_from = int(value.misc_from)
	if value.version >= 5:
		if not SeasonOwnership._whole(value.mapped_gear_from, 1, 13):
			return null
		result._mapped_gear_from = int(value.mapped_gear_from)
	if value.version >= 6:
		if not SeasonOwnership._whole(value.sponsor_from, 1, 13):
			return null
		result._sponsor_from = int(value.sponsor_from)
	if value.version >= 7:
		if not SeasonOwnership._whole(value.gameplay_sponsor_from, 1, 13):
			return null
		result._gameplay_sponsor_from = int(value.gameplay_sponsor_from)
	if value.version >= 8:
		if not SeasonOwnership._whole(value.sequence_sponsor_from, 1, 13):
			return null
		result._sequence_sponsor_from = int(value.sequence_sponsor_from)
	if value.version >= 9:
		if not SeasonOwnership._whole(value.field_sponsor_from, 1, 13):
			return null
		result._field_sponsor_from = int(value.field_sponsor_from)
	if value.version >= 10:
		if not SeasonOwnership._whole(value.shop_sponsor_from, 1, 13):
			return null
		result._shop_sponsor_from = int(value.shop_sponsor_from)
	if value.version >= 11:
		if not SeasonOwnership._whole(value.school_sponsor_from, 1, 13):
			return null
		result._school_sponsor_from = int(value.school_sponsor_from)
	if value.version >= 12:
		if not SeasonOwnership._whole(value.anchor_sponsor_from, 1, 13):
			return null
		result._anchor_sponsor_from = int(value.anchor_sponsor_from)
	if value.version >= 13:
		if not SeasonOwnership._whole(value.wholesale_from, 1, 13):
			return null
		result._wholesale_from = int(value.wholesale_from)
	if value.version >= 14:
		if not SeasonOwnership._whole(value.tactical_from, 1, 13):
			return null
		result._tactical_from = int(value.tactical_from)
	if value.version >= 15:
		if not SeasonOwnership._whole(value.expanded_tactical_from, 1, 13):
			return null
		result._expanded_tactical_from = int(value.expanded_tactical_from)
	if value.version >= 16:
		if not SeasonOwnership._whole(value.tactical_sponsor_from, 1, 13):
			return null
		result._tactical_sponsor_from = int(value.tactical_sponsor_from)
	if value.version >= 17:
		if not SeasonOwnership._whole(value.budget_from, 1, 13):
			return null
		result._budget_from = int(value.budget_from)
	if value.version >= 18:
		if not SeasonOwnership._whole(value.film_from, 1, 13):
			return null
		result._film_from = int(value.film_from)
	if value.version >= 19:
		if not SeasonOwnership._whole(value.market, 0, 1):
			return null
		result._market = int(value.market)
	if value.version >= 20 and value.gear_start != null:
		if not SeasonGearProgress.valid_counts(value.gear_start) or result._market != 0:
			return null
		result._gear_progress.enabled = true
		result._gear_progress.start = value.gear_start.duplicate()
	for event: Variant in value.events:
		if not event is Dictionary:
			return null
		var applied: Dictionary = result.commit(event)
		if not applied.ok or applied.replayed:
			return null
	if value.version >= 2:
		# Godot JSON reads every number as float; normalize both quote snapshots
		# before deep comparison without accepting a different value or field.
		var expected: Variant = JSON.parse_string(JSON.stringify(result._recruits))
		var saved: Variant = JSON.parse_string(JSON.stringify(value.recruits))
		if expected != saved:
			return null
	return result

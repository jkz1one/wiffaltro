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
	if value.version >= 21:
		keys.append("sponsor_start")
	if value.version >= 23:
		keys.append("order_start")
	if value.version >= 24:
		keys.append("rain_start")
	if value.version >= 25:
		keys.append("transfer_start")
	if value.version >= 26:
		keys.append("supply_start")
	if value.version >= 27:
		keys.append("checkout_start")
	if value.version >= 28:
		keys.append("association_start")
	if value.version >= 29:
		keys.append("freezer_start")
	if value.version >= 30:
		keys.append("sides_start")
	if value.version >= 31:
		keys.append("jump_start")
	if value.version >= 32:
		keys.append("batch_start")
	if value.version >= 33:
		keys.append("sure_start")
	if value.version >= 34:
		keys.append("field_start")
	if value.version >= 35:
		keys.append("copy_start")
	if value.version >= 36:
		keys.append_array(["ability_from", "ability_start"])
	if value.version >= 37:
		keys.append("major_start")
	if value.version >= 38:
		keys.append("retraining_enabled")
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
	result._retraining_enabled = false
	if value.version >= 38:
		if not value.retraining_enabled is bool:
			return null
		result._retraining_enabled = value.retraining_enabled
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
	if value.version >= 21 and value.sponsor_start != null:
		if not SeasonSponsorProgress.valid_state(value.sponsor_start) or result._market != 0:
			return null
		result._sponsor_progress.enabled = true
		result._sponsor_progress.start = value.sponsor_start.duplicate(true)
	if value.version >= 23:
		if value.order_start != null and not value.order_start is bool:
			return null
		if value.order_start != null and result._market != 0:
			return null
		result._order_start = value.order_start
	if value.version >= 24:
		if value.rain_start != null and (not value.rain_start is bool or result._market != 0):
			return null
		result._rain_start = value.rain_start
	if value.version >= 25:
		if value.transfer_start != null:
			if not value.transfer_start is bool or result._market != 0:
				return null
		result._transfer_start = value.transfer_start
	if value.version >= 26:
		if value.supply_start != null:
			if not SeasonOwnership._whole(value.supply_start, 0, 3) or result._market != 0:
				return null
		result._supply_start = value.supply_start
	if value.version >= 27:
		if value.checkout_start != null:
			if not value.checkout_start is bool or result._market != 0:
				return null
		result._checkout_start = value.checkout_start
	if value.version >= 28:
		if value.association_start != null:
			if not value.association_start is bool or result._market != 0:
				return null
		result._association_start = value.association_start
	if value.version >= 29:
		if value.freezer_start != null:
			if not value.freezer_start is bool or result._market != 0:
				return null
		result._freezer_start = value.freezer_start
	if value.version >= 30:
		if value.sides_start != null:
			if not value.sides_start is bool or result._market != 0:
				return null
		result._sides_start = value.sides_start
	if value.version >= 31:
		if value.jump_start != null:
			if not value.jump_start is bool or result._market != 0:
				return null
		result._jump_start = value.jump_start
	if value.version >= 33:
		if value.sure_start != null:
			if not value.sure_start is bool or result._market != 0:
				return null
		result._sure_start = value.sure_start
	if value.version >= 34:
		if value.field_start != null:
			if not value.field_start is bool or result._market != 0:
				return null
		result._field_start = value.field_start
	if value.version >= 35:
		if value.copy_start != null:
			if not value.copy_start is bool or result._market != 0:
				return null
		result._copy.start = value.copy_start
	if value.version >= 32:
		if value.batch_start != null:
			if not SeasonSmallBatch.valid(value.batch_start) or result._market != 0:
				return null
		result._batch_start = value.batch_start.duplicate() if value.batch_start != null else null
	if value.version >= 36:
		if not SeasonOwnership._whole(value.ability_from, 1, 13):
			return null
		if value.ability_start != null:
			if not SeasonOwnership._whole(value.ability_start, 0, 3) or result._market != 0:
				return null
		result._abilities.from_visit = int(value.ability_from)
		result._abilities.start = value.ability_start
	if value.version >= 37:
		if value.major_start != null and (not value.major_start is bool or result._market != 0):
			return null
		result._major.start = value.major_start
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

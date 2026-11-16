extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_award_plaque(_source_owner: ClubAssetLedger, event: Dictionary) -> \
	Dictionary:
	var id: String = StadiumPlaqueRewards.key(event.earned.player_id)
	if (
		event.id != id
		or not _source_owner._championships.has(id)
		or not ClubCareer.same(_source_owner._championships[id], event.earned)
	):
		return ClubAssetLedger._error(
			"Validated player career history and its exact frozen plaque record are required."
		)
	var quote: Dictionary = _source_owner._stock.plaque_quote(event.earned)
	if not quote.ok or quote.replayed:
		return ClubAssetLedger._error("This player plaque is invalid or has already been issued.")
	return {
		"ok": true,
		"replayed": false,
		"error": "",
		"event": event,
		"price": 0,
		"stock": quote.state,
		"balance_after": _source_owner.balance()
	}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_plaque_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if event is Dictionary and event.get("op") == "stadium_plaque":
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_waterfall_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and SeasonOwnership._whole(
						event.get("price_version"),
						StadiumWaterfallItems.PRICE_VERSION,
						StadiumWaterfallItems.PRICE_VERSION
					)
				)
				or (
					StadiumWaterfallItems.is_family(event.get("layout"))
					or StadiumLightingKitItems.is_family(event.get("layout"))
				)
			)
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_lighting_kit_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and SeasonOwnership._whole(
						event.get("price_version"),
						StadiumLightingKitItems.PRICE_VERSION,
						StadiumLightingKitItems.PRICE_VERSION
					)
				)
				or StadiumLightingKitItems.is_family(event.get("layout"))
			)
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_outfield_plaza_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and (
				(
					event.get("op") == "stadium_buy"
					and SeasonOwnership._whole(
						event.get("price_version"),
						StadiumOutfieldPlazaItems.PRICE_VERSION,
						StadiumOutfieldPlazaItems.PRICE_VERSION
					)
				)
				or StadiumOutfieldPlazaItems.is_family(event.get("layout"))
			)
		):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_live_waterfall_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if event is Dictionary and StadiumWaterfallLiveItems.is_family(event.get("layout")):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_low_wall_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if event is Dictionary and StadiumLowWallLayout.is_family(event.get("layout")):
			return true
	return false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_has_waterfall_animation_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if event is Dictionary and StadiumWaterfallAnimationLayout.is_family(event.get("layout")):
			return true
	return false
# gdlint: enable=max-returns

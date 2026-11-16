extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_prepare(_source_owner: ClubAssetLedger, command: Dictionary) -> \
	Dictionary:
	if not _source_owner._valid:
		return ClubAssetLedger._error("Career income or player-pack seed is invalid.")
	var op: Variant = command.get("op")
	if (
		op
		not in [
			"player_pack_open",
			"player_pack_pick",
			"stadium_draft",
			"stadium_apply",
			"stadium_buy",
			"stadium_land",
			"stadium_style",
			"stadium_surface",
			"stadium_wall_piece",
			"stadium_scoreboard",
			"stadium_pennant",
			"stadium_mastery",
			"stadium_plaque",
			"stadium_salvage_clear"
		]
	):
		return ClubAssetLedger._error("Unknown permanent-asset action.")
	var keys: Array = ["id", "rev", "op"]
	keys.append_array(
		(
			["through", "price_version", "copy"]
			if op == "stadium_salvage_clear"
			else (
				["earned"]
				if op in ["stadium_pennant", "stadium_mastery", "stadium_plaque"]
				else (
					["through", "price_version"]
					if op == "player_pack_open"
					else (
						["through", "price_version", "progress_through", "item", "quantity"]
						if op in ["stadium_wall_piece", "stadium_scoreboard"]
						else (
							["through", "price_version", "item"]
							if op == "stadium_surface"
							else (
								["through", "price_version", "item", "quantity"]
								if op == "stadium_buy"
								else (
									["through", "price_version", "progress_through", "tier"]
									if op == "stadium_land"
									else (
										["through", "price_version", "progress_through", "item"]
										if op == "stadium_style"
										else (
											["layout", "geometry"]
											if op == "stadium_apply"
											else (
												["layout"]
												if op == "stadium_draft"
												else ["pack", "player"]
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	)
	if (
		op == "stadium_buy"
		and (
			SeasonOwnership._whole(
				command.get("price_version"),
				StadiumPurchases.SEATING_VERSION,
				StadiumWallItems.PRICE_VERSION
			)
			or SeasonOwnership._whole(
				command.get("price_version"),
				StadiumPurchases.POOL_VERSION,
				StadiumOutfieldPlazaItems.PRICE_VERSION
			)
		)
	):
		keys.append("progress_through")
	var normalized: Dictionary = ClubAssetLedger.Journal.normalize_request(
		command, keys, ClubAssetLedger.MAX_EVENTS)
	if not normalized.ok:
		return normalized
	var event: Dictionary = normalized.event
	if (
		op
		in [
			"player_pack_open",
			"stadium_buy",
			"stadium_land",
			"stadium_style",
			"stadium_surface",
			"stadium_wall_piece",
			"stadium_scoreboard",
			"stadium_salvage_clear"
		]
	):
		var income_error: Dictionary = ClubAssetLedger.Journal.normalize_income(
			event, _source_owner._credits)
		if not income_error.is_empty():
			return income_error
		if (
			op == "stadium_salvage_clear"
			and (not event.copy is String or event.copy != StadiumStock.SALVAGE_COPY)
		):
			return ClubAssetLedger._error("Invalid starter salvage copy.")
		if op == "stadium_surface" and not event.item is String:
			return ClubAssetLedger._error("Invalid surface upgrade.")
		if op == "stadium_style":
			if (
				not event.item is String
				or not SeasonOwnership._whole(event.progress_through, 1, _source_owner._progress.size())
			):
				return ClubAssetLedger._error("Invalid appearance or closed progress prefix.")
			event.progress_through = int(event.progress_through)
		if op == "stadium_land":
			if (
				not event.tier is String
				or not SeasonOwnership._whole(event.progress_through, 1, _source_owner._progress.size())
			):
				return ClubAssetLedger._error("Invalid land or closed progress prefix.")
			event.progress_through = int(event.progress_through)
		if op in ["stadium_buy", "stadium_wall_piece", "stadium_scoreboard"]:
			if (
				not event.item is String
				or not SeasonOwnership._whole(event.quantity, 1, StadiumStock.MAX_COPIES)
			):
				return ClubAssetLedger._error("Invalid construction item or quantity.")
			event.quantity = int(event.quantity)
			if (
				op in ["stadium_wall_piece", "stadium_scoreboard"]
				or (
					event.price_version
					in [
						StadiumPurchases.SEATING_VERSION,
						StadiumPurchases.DISPLAY_VERSION,
						StadiumPurchases.BLEACHER_VERSION,
						StadiumPurchases.TARGET_VERSION,
						StadiumPurchases.NET_VERSION,
						StadiumPurchases.LIGHT_VERSION,
						StadiumWallItems.PRICE_VERSION,
						StadiumPurchases.POOL_VERSION,
						StadiumFlagItems.PRICE_VERSION,
						StadiumGroundPropsItems.PRICE_VERSION,
						StadiumStraightItems.PRICE_VERSION,
						StadiumRoofItems.PRICE_VERSION,
						StadiumFacilityItems.PRICE_VERSION,
						StadiumBoundaryItems.PRICE_VERSION,
						StadiumReceiverOwnedItems.PRICE_VERSION,
						StadiumFloodlightOwnedItems.PRICE_VERSION,
						StadiumLandscapeOwnedItems.PRICE_VERSION,
						StadiumLiveFurnishingItems.PRICE_VERSION,
						StadiumMoldedSeatItems.PRICE_VERSION,
						StadiumGroundBoxItems.PRICE_VERSION,
						StadiumPracticeFacilityItems.PRICE_VERSION,
						StadiumTreehouseItems.PRICE_VERSION,
						StadiumLandmarkItems.PRICE_VERSION,
						StadiumOutfieldBleacherItems.PRICE_VERSION,
						StadiumRisingAppleItems.PRICE_VERSION,
						StadiumWallTopTerraceItems.PRICE_VERSION,
						StadiumPlayerTunnelItems.PRICE_VERSION,
						StadiumMountedDisplayItems.PRICE_VERSION,
						StadiumStringLightItems.PRICE_VERSION,
						StadiumSalvageCarItems.PRICE_VERSION,
						StadiumWaterfallItems.PRICE_VERSION,
						StadiumLightingKitItems.PRICE_VERSION,
						StadiumOutfieldPlazaItems.PRICE_VERSION
					]
				)
			):
				if not SeasonOwnership._whole(event.progress_through, 1, _source_owner._progress.size()):
					return ClubAssetLedger._error("A closed career progress record is required.")
				event.progress_through = int(event.progress_through)
	elif op in ["stadium_draft", "stadium_apply"]:
		var checked: Dictionary = _source_owner._validate_layout(event.layout)
		if not checked.ok:
			return ClubAssetLedger._error(checked.error)
		if (
			_source_owner._surface_origin == StadiumSurfaceProgression.ROUGH_ORIGIN
			and not SeasonOwnership._whole(
				event.layout.version, 12, StadiumWaterfallAnimationLayout.VERSION
			)
		):
			return ClubAssetLedger._error("This club requires its explicit dirt/grass surface selection.")
		if (
			SeasonOwnership._whole(
				event.layout.version, 12, StadiumWaterfallAnimationLayout.VERSION
			)
			and not StadiumSurfaceLayout.owned(event.layout, _source_owner._surface_owned)
		):
			return ClubAssetLedger._error("The selected surface upgrade is not owned by this club.")
	elif op == "stadium_plaque":
		if not StadiumPlaqueRewards.valid_record(event.earned):
			return ClubAssetLedger._error("Invalid player-plaque record.")
		event.earned = StadiumPlaqueRewards.canonical(event.earned)
	elif op in ["stadium_pennant", "stadium_mastery"]:
		if not (
			StadiumPennantRewards.valid_mastery_record(event.earned)
			if op == "stadium_mastery"
			else StadiumPennantRewards.valid_record(event.earned)
		):
			return ClubAssetLedger._error("Invalid championship pennant record.")
	elif not event.pack is String or not event.player is String:
		return ClubAssetLedger._error("Invalid player selection.")
	var status: Dictionary = ClubAssetLedger.Journal.request_status(
		event, _source_owner._requests, _source_owner.revision, ClubAssetLedger.MAX_EVENTS)
	if not status.ok:
		return status
	if status.replayed:
		return {"ok": true, "replayed": true, "error": "", "view": _source_owner.view()}
	if op == "stadium_salvage_clear":
		return _source_owner._clear_salvage(event)
	if op == "stadium_plaque":
		return _source_owner._award_plaque(event)
	if op in ["stadium_pennant", "stadium_mastery"]:
		return _source_owner._award_pennant(event)
	if op == "player_pack_open":
		return _source_owner._open(event)
	if op == "stadium_buy":
		return _source_owner._buy(event)
	if op == "stadium_wall_piece":
		return _source_owner._buy_wall_piece(event)
	if op == "stadium_scoreboard":
		return _source_owner._buy_scoreboard(event)
	if op == "stadium_land":
		return _source_owner._buy_land(event)
	if op == "stadium_style":
		return _source_owner._buy_style(event)
	if op == "stadium_surface":
		return _source_owner._buy_surface(event)
	if op in ["stadium_draft", "stadium_apply"]:
		if (
			not _source_owner._salvage_origin.is_empty()
			and not _source_owner._salvage_cleared
			and not ClubAssetLedger._fixed_salvage_present(event.layout)
		):
			return ClubAssetLedger._error(
				"Clear the starter junk car once for 190 Club Bucks before moving or storing it."
			)
		if op == "stadium_draft":
			var mastery_transition: Dictionary = StadiumMasteryBannerItems.transition(
				_source_owner._stadium_draft, event.layout
			)
			if not mastery_transition.ok:
				return mastery_transition
			var mounted_transition: Dictionary = StadiumMountedDisplayItems.transition(
				_source_owner._stadium_draft, event.layout
			)
			if not mounted_transition.ok:
				return ClubAssetLedger._error(mounted_transition.error)
			var tunnel_transition: Dictionary = StadiumPlayerTunnelItems.transition(
				_source_owner._stadium_draft, event.layout
			)
			if not tunnel_transition.ok:
				return ClubAssetLedger._error(tunnel_transition.error)
			var transition: Dictionary = StadiumWallTopTerraceItems.transition(
				_source_owner._stadium_draft, event.layout
			)
			if not transition.ok:
				return ClubAssetLedger._error(transition.error)
		if (
			op == "stadium_apply"
			and (
				not event.geometry is String
				or event.geometry != _source_owner._layout_geometry(event.layout)
				or not ClubCareer.same(event.layout, _source_owner._stadium_draft)
			)
		):
			return \
				ClubAssetLedger._error("Apply requires the exact saved draft and current property geometry.")
		return {
			"ok": true,
			"replayed": false,
			"event": event,
			"error": "",
			"cost": 0,
			"balance_after": _source_owner.balance()
		}
	return ClubAssetLedger.PlayerPack.prepare(_source_owner._pack_context(), event)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_validate_layout(_source_owner: ClubAssetLedger, layout: Variant) -> \
	Dictionary:
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 16, 16):
		return StadiumPoolOwnedLayout.validate(layout, _source_owner.construction(), \
			_source_owner.surface_owned(), _source_owner._land)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 15, 15):
		return StadiumMountedScoreboardLayout.validate(
			layout, _source_owner.construction(), _source_owner.wall_pieces(), \
				_source_owner.surface_owned(), _source_owner._land, _source_owner.scoreboards()
		)
	return StadiumOwnedLayout.validate(
		layout, _source_owner.construction(), _source_owner.wall_pieces(), \
			_source_owner.surface_owned(), _source_owner._land, _source_owner.scoreboards()
	)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_layout_geometry(_source_owner: ClubAssetLedger, layout: Dictionary) \
	-> String:
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return StadiumPoolOwnedLayout.geometry(_source_owner._land, layout)
	if SeasonOwnership._whole(layout.get("version"), 15, 15):
		return StadiumMountedScoreboardLayout.geometry(_source_owner._land, layout)
	return StadiumOwnedLayout.geometry(_source_owner._land, layout)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_open(_source_owner: ClubAssetLedger, event: Dictionary) -> Dictionary:
	return ClubAssetLedger.PlayerPack.prepare(_source_owner._pack_context(), event)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_buy(_source_owner: ClubAssetLedger, event: Dictionary) -> Dictionary:
	if (
		(
			_source_owner._stock.capacity_count()
			+ _source_owner._wall_pieces.stock.copies.size()
			+ _source_owner._scoreboards.copies.size()
			+ event.quantity
		)
		> StadiumStock.MAX_COPIES
	):
		return ClubAssetLedger._error("Combined construction inventory is full.")
	if event.through < _source_owner._through or event.through == 0 or \
		_source_owner._credits[event.through - 1] == 0:
		return ClubAssetLedger._error("A completed earning record is required.")
	var progress: Dictionary = {}
	if (
		event.price_version
		in [
			StadiumPurchases.SEATING_VERSION,
			StadiumPurchases.DISPLAY_VERSION,
			StadiumPurchases.BLEACHER_VERSION,
			StadiumPurchases.TARGET_VERSION,
			StadiumPurchases.NET_VERSION,
			StadiumPurchases.LIGHT_VERSION,
			StadiumWallItems.PRICE_VERSION,
			StadiumPurchases.POOL_VERSION,
			StadiumFlagItems.PRICE_VERSION,
			StadiumGroundPropsItems.PRICE_VERSION,
			StadiumStraightItems.PRICE_VERSION,
			StadiumRoofItems.PRICE_VERSION,
			StadiumFacilityItems.PRICE_VERSION,
			StadiumBoundaryItems.PRICE_VERSION,
			StadiumReceiverOwnedItems.PRICE_VERSION,
			StadiumFloodlightOwnedItems.PRICE_VERSION,
			StadiumLandscapeOwnedItems.PRICE_VERSION,
			StadiumLiveFurnishingItems.PRICE_VERSION,
			StadiumMoldedSeatItems.PRICE_VERSION,
			StadiumGroundBoxItems.PRICE_VERSION,
			StadiumPracticeFacilityItems.PRICE_VERSION,
			StadiumTreehouseItems.PRICE_VERSION,
			StadiumLandmarkItems.PRICE_VERSION,
			StadiumOutfieldBleacherItems.PRICE_VERSION,
			StadiumRisingAppleItems.PRICE_VERSION,
			StadiumWallTopTerraceItems.PRICE_VERSION,
			StadiumPlayerTunnelItems.PRICE_VERSION,
			StadiumMountedDisplayItems.PRICE_VERSION,
			StadiumStringLightItems.PRICE_VERSION,
			StadiumSalvageCarItems.PRICE_VERSION,
			StadiumWaterfallItems.PRICE_VERSION,
			StadiumLightingKitItems.PRICE_VERSION,
			StadiumOutfieldPlazaItems.PRICE_VERSION
		]
	):
		if not _source_owner._loading and event.progress_through != _source_owner._progress.size():
			return ClubAssetLedger._error("Career progress changed; reload before purchasing.")
		progress = StadiumCareerProgress.metrics(_source_owner._progress, event.progress_through)
	var quote: Dictionary = StadiumPurchases.quote(
		_source_owner._stock, event.item, event.quantity, event.id, event.price_version, progress
	)
	if not quote.ok:
		return ClubAssetLedger._error(quote.error)
	if _source_owner._income(event.through) - _source_owner._spent < quote.cost:
		return ClubAssetLedger._error("Not enough earned Club Bucks.")
	return {
		"ok": true,
		"replayed": false,
		"error": "",
		"event": event,
		"price": quote.cost,
		"stock": quote.state,
		"balance_after": _source_owner.balance() - quote.cost
	}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_buy_wall_piece(_source_owner: ClubAssetLedger, event: Dictionary) -> \
	Dictionary:
	if event.through < _source_owner._through or event.through == 0 or \
		_source_owner._credits[event.through - 1] == 0:
		return ClubAssetLedger._error("A completed earning record is required.")
	if not _source_owner._loading and event.progress_through != _source_owner._progress.size():
		return ClubAssetLedger._error("Career progress changed; reload before purchasing.")
	var quote: Dictionary = _source_owner._wall_pieces.quote(
		event.item,
		event.quantity,
		event.id,
		StadiumCareerProgress.metrics(_source_owner._progress, event.progress_through),
		_source_owner._stock.capacity_count() + _source_owner._scoreboards.copies.size(),
		event.price_version
	)
	if not quote.ok:
		return ClubAssetLedger._error(quote.error)
	if _source_owner._income(event.through) - _source_owner._spent < quote.cost:
		return ClubAssetLedger._error("Not enough earned Club Bucks.")
	return {
		"ok": true,
		"replayed": false,
		"error": "",
		"event": event,
		"price": quote.cost,
		"wall_pieces": quote.state,
		"balance_after": _source_owner.balance() - quote.cost
	}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_buy_scoreboard(_source_owner: ClubAssetLedger, event: Dictionary) -> \
	Dictionary:
	if event.through < _source_owner._through or event.through == 0 or \
		_source_owner._credits[event.through - 1] == 0:
		return ClubAssetLedger._error("A completed earning record is required.")
	if not _source_owner._loading and event.progress_through != _source_owner._progress.size():
		return ClubAssetLedger._error("Career progress changed; reload before purchasing.")
	var quote: Dictionary = StadiumScoreboardPurchases.quote(
		_source_owner._stock,
		_source_owner._wall_pieces,
		_source_owner._scoreboards,
		event.item,
		event.quantity,
		event.id,
		StadiumCareerProgress.metrics(_source_owner._progress, event.progress_through),
		event.price_version
	)
	if not quote.ok:
		return ClubAssetLedger._error(quote.error)
	if _source_owner._income(event.through) - _source_owner._spent < quote.cost:
		return ClubAssetLedger._error("Not enough earned Club Bucks.")
	return {
		"ok": true,
		"replayed": false,
		"error": "",
		"event": event,
		"price": quote.cost,
		"stock": quote.stock,
		"scoreboards": quote.scoreboards,
		"balance_after": _source_owner.balance() - quote.cost
	}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_buy_land(_source_owner: ClubAssetLedger, event: Dictionary) -> \
	Dictionary:
	if event.through < _source_owner._through or event.through == 0 or \
		_source_owner._credits[event.through - 1] == 0:
		return ClubAssetLedger._error("A completed earning record is required.")
	if not _source_owner._loading and event.progress_through != _source_owner._progress.size():
		return ClubAssetLedger._error("Career progress changed; reload before purchasing.")
	var quote: Dictionary = StadiumLand.quote(
		_source_owner._land,
		event.tier,
		StadiumCareerProgress.metrics(_source_owner._progress, event.progress_through),
		event.price_version
	)
	if not quote.ok:
		return ClubAssetLedger._error(quote.error)
	if _source_owner._income(event.through) - _source_owner._spent < quote.cost:
		return ClubAssetLedger._error("Not enough earned Club Bucks.")
	return {
		"ok": true,
		"replayed": false,
		"error": "",
		"event": event,
		"price": quote.cost,
		"balance_after": _source_owner.balance() - quote.cost
	}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_buy_style(_source_owner: ClubAssetLedger, event: Dictionary) -> \
	Dictionary:
	var gate: String = StadiumSurfaceProgression.style_error(_source_owner._surface_owned, event.item)
	if not gate.is_empty():
		return ClubAssetLedger._error(gate)
	if event.through < _source_owner._through or event.through == 0 or \
		_source_owner._credits[event.through - 1] == 0:
		return ClubAssetLedger._error("A completed earning record is required.")
	if not _source_owner._loading and event.progress_through != _source_owner._progress.size():
		return ClubAssetLedger._error("Career progress changed; reload before purchasing.")
	var quote: Dictionary = StadiumFieldStyles.quote(
		_source_owner._stock,
		event.item,
		event.id,
		StadiumCareerProgress.metrics(_source_owner._progress, event.progress_through),
		event.price_version
	)
	if not quote.ok:
		return ClubAssetLedger._error(quote.error)
	if _source_owner._income(event.through) - _source_owner._spent < quote.cost:
		return ClubAssetLedger._error("Not enough earned Club Bucks.")
	return {
		"ok": true,
		"replayed": false,
		"error": "",
		"event": event,
		"price": quote.cost,
		"stock": quote.state,
		"balance_after": _source_owner.balance() - quote.cost
	}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_buy_surface(_source_owner: ClubAssetLedger, event: Dictionary) -> \
	Dictionary:
	if event.through < _source_owner._through or event.through == 0 or \
		_source_owner._credits[event.through - 1] == 0:
		return ClubAssetLedger._error("A completed earning record is required.")
	var quote: Dictionary = StadiumSurfaceProgression.quote(
		_source_owner._surface_owned, event.item, event.price_version
	)
	if not quote.ok:
		return ClubAssetLedger._error(quote.error)
	if _source_owner._income(event.through) - _source_owner._spent < quote.cost:
		return ClubAssetLedger._error("Not enough earned Club Bucks.")
	return {
		"ok": true,
		"replayed": false,
		"error": "",
		"event": event,
		"price": quote.cost,
		"surface_owned": quote.owned,
		"balance_after": _source_owner.balance() - quote.cost
	}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_prefix(_source_owner: ClubAssetLedger, length: int) -> ClubAssetLedger:
	var ac02_token: int = ClubAssetLedger.AC02_PASSIVE_13.enter("club_asset_ledger.prefix")
	var ac02_result: ClubAssetLedger = _source_owner._ac02_passive_13_prefix(length)
	ClubAssetLedger.AC02_PASSIVE_13.leave(ac02_token)
	return ac02_result
# gdlint: enable=max-returns

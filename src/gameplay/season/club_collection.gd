class_name ClubCollection
extends RefCounted
## Gear/sponsor discovery is evidence of acquisition, never ownership or shop access.


static func catalog() -> Dictionary:
	var result: Dictionary = {}
	for id: String in SeasonSponsorCatalog.ownership_catalog():
		var item: Dictionary = SeasonGearCatalog.item(id)
		var kind: String = "Gear"
		if item.is_empty():
			item = SeasonSponsorCatalog.item(id)
			kind = "Sponsors"
		if not item.is_empty():
			item["category"] = kind
			result[id] = item
	return result


static func acquired(build: SeasonBuild) -> Array[String]:
	var result: Array[String] = []
	if build == null or build._market != 0:
		return result
	# The bank journal is reconstructed by ordinary build replay. Stock/display alone
	# never counts. Sold/replaced copies remain represented by their successful buy.
	var stock: Dictionary = {}
	var supported: Dictionary = catalog()
	for event: Dictionary in build._bank._events:
		if event.op == "stock":
			stock = event.offers
		var offers: Array = []
		if event.op == "buy":
			offers.append(event.offer)
		elif event.op == "sponsor_set":
			for purchase: Dictionary in event.purchases:
				offers.append(purchase.offer)
		for offer: String in offers:
			var id: String = stock.get(offer, "")
			if supported.has(id) and not result.has(id):
				result.append(id)
	result.sort()
	return result


static func valid(value: Variant, allow_frozen: bool = true) -> bool:
	if not value is Array:
		return false
	var supported: Dictionary = catalog()
	var previous: String = ""
	for id: Variant in value:
		if not id is String or not supported.has(id) or id <= previous:
			return false
		if not allow_frozen and id == SeasonFrozenRope.ID:
			return false
		previous = id
	return true


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var saved: Variant = club.runs[-1].collection
	if saved == null:
		return true  # Archived old runs have no recoverable acquisition proof.
	var current: Array[String] = acquired(season.build)
	if exact:
		return ClubCareer.same(saved, current)
	for id: String in saved:
		if not current.has(id):
			return false
	return true


static func discoveries(club: ClubCareer, build: SeasonBuild = null) -> Array[String]:
	var result: Array[String] = acquired(build)
	if club != null:
		for run: Dictionary in club.runs:
			if run.collection == null:
				continue
			for id: String in run.collection:
				if not result.has(id):
					result.append(id)
	result.sort()
	return result


static func owned(build: SeasonBuild) -> Array[String]:
	var result: Array[String] = []
	if build != null:
		var wallet: Dictionary = build.view().wallet
		for receipt: Dictionary in wallet.gear.values() + wallet.sponsors:
			if not receipt.is_empty():
				result.append(receipt.item)
	result.sort()
	return result


static func access(club: ClubCareer) -> Array[String]:
	var result: Array[String] = []
	for id: String in SeasonGearCatalog.catalog():
		result.append(id)
	for id: String in SeasonSponsorCatalog.catalog():
		result.append(id)
	if club == null:
		return result
	result.append_array(SeasonGearProgress.access(club.gear_counts()))
	var progress: SeasonSponsorProgress = SeasonSponsorProgress.new()
	progress.enabled = true
	progress.start = club.sponsor_state()
	result.append_array(progress.eligible())
	var earned: Dictionary = {
		"J01": club.order_access(),
		"G01": club.rain_access(),
		"F07": club.transfer_access(),
		"E04": club.supply_count() >= 3,
		"G03": SeasonLateCheckout.access(club),
		"J05": SeasonAssociation.access(club),
		"E10": SeasonFreezers.access(club),
		"F06": SeasonLeftRight.access(club),
		"J04": SeasonJumpstart.access(club),
		"G02": SeasonSmallBatch.access(club).size() == 3,
		"F08": SeasonSureShot.access(club),
		"B01": SeasonFieldSupply.access(club),
		"E09": SeasonCarbonCopy.access(club),
		"F09": SeasonDoubleMajor.access(club)
	}
	for id: String in earned:
		if earned[id]:
			result.append(id)
	result.sort()
	return result

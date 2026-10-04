class_name SeasonEarnedSponsors
extends RefCounted
## Current Equipment/Sponsors v18 access/effects remain Working candidates.

const ITEMS: Dictionary = {
	"E05":
	{
		"name": "Local Legends",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Each distinct credited Single, Double, Triple or HR in completed games "
			+ "while active stamps this copy. Each stamp adds 1% fair Contact exit speed "
			+ "next game, max 4%. No Power benefit. Selling loses stamps."
		)
	},
	"G05":
	{
		"name": "Encore Energy",
		"price": 20,
		"rarity": "Rare",
		"weight": 0.5,
		"effect":
		(
			"Once per game, confirm a previously removed pitcher's return between "
			+ "batters. Keep their spent stamina, pitch count and used effects. No "
			+ "second return or free recovery."
		)
	}
}
const REQUIREMENTS: Dictionary = {
	"E05":
	(
		"Career: record three distinct credited hit types among Single, Double, "
		+ "Triple and HR in completed games. Wins are not required."
	),
	"G05":
	"Game: win a completed game in which two different club pitchers each earn a credited strikeout."
}


static func eligible(build: SeasonBuild) -> Dictionary:
	if build._market in [6, 7, 8, 9]:
		return SeasonOpponentSponsors.pool(build)
	# Unlock changes future rolls only; existing offers remain immutable.
	var earned: Array[String] = build._sponsor_progress.eligible()
	if build._format >= 37 and build._major.start != null:
		if build._major.start or build._major.earned:
			earned.append("F09")
	if build._format >= 23 and build._order_start != null:
		if build._order_start or build._paid_rerolls >= 3:
			earned.append("J01")
	if build._format >= 24 and build._rain_start != null:
		if build._rain_start or build._rain_earned:
			earned.append("G01")
	if build._format >= 25 and build._transfer_start != null:
		if build._transfer_start or build._transfer_earned:
			earned.append("F07")
	if build._format >= 26 and build._supply_start != null:
		if build._supply_start + build._supply_used >= 3:
			earned.append("E04")
	if build._format >= 27 and build._checkout_start != null:
		if build._checkout_start or build._checkout_earned:
			earned.append("G03")
	if build._format >= 28 and build._association_start != null:
		if build._association_start or build._association_earned:
			earned.append("J05")
	if build._format >= 29 and build._freezer_start != null:
		if build._freezer_start or build._freezer_earned:
			earned.append("E10")
	if build._format >= 30 and build._sides_start != null:
		if build._sides_start or build._sides_earned:
			earned.append("F06")
	if build._format >= 32 and build._batch_start != null:
		if SeasonSmallBatch.combine(build._batch_start, build._batch_used).size() == 3:
			earned.append("G02")
	if build._format >= 35 and build._copy.start != null:
		if build._copy.start or build._copy.earned:
			earned.append("E09")
	if build._format >= 34 and build._field_start != null:
		if build._field_start or build._field_outs >= 6:
			earned.append("B01")
	if build._format >= 33 and build._sure_start != null:
		if build._sure_start or build._sure_earned:
			earned.append("F08")
	if build._format >= 31 and build._jump_start != null:
		if build._jump_start or build._jump_earned:
			earned.append("J04")
	return SeasonSponsorCatalog.eligible(
		build._bank.view().sponsors, build._sponsor_catalog_version(), earned
	)

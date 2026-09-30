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
	return SeasonSponsorCatalog.eligible(
		build._bank.view().sponsors,
		build._sponsor_catalog_version(),
		build._sponsor_progress.eligible()
	)

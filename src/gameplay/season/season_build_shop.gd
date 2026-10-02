class_name SeasonBuildShop
extends RefCounted


static func offers(build: SeasonBuild, rerolls: int) -> Dictionary:
	if build._market == 1:
		return SeasonOpponentMarket.offers(build, rerolls)
	if build._format >= 3 and build._visit.number >= build._gear_from:
		return SeasonGearCatalog.offers(
			build._book,
			build._roster,
			build._bank.view().gear,
			build._rng(rerolls),
			"visit:%d:roll:%d" % [build._visit.number, rerolls],
			(
				3
				if build._format >= 5 and build._visit.number >= build._mapped_gear_from
				else (2 if build._format >= 4 and build._visit.number >= build._misc_from else 1)
			),
			(
				SeasonEarnedSponsors.eligible(build)
				if build._format >= 6 and build._visit.number >= build._sponsor_from
				else {}
			),
			(
				SeasonTacticalCatalog.weights(build._tactical_catalog_version())
				if build._format >= 14 and build._visit.number >= build._tactical_from
				else {}
			),
			build._gear_progress.eligible(build._format >= 41),
			build._abilities.pool(build),
			SeasonRetraining.pool(build)
		)
	return DevelopmentShopCatalog.offers(
		build._book,
		build._roster,
		build._rng(rerolls),
		"visit:%d:roll:%d" % [build._visit.number, rerolls]
	)

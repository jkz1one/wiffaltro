extends "res://src/tests/stadium_mastery_banner_journal_test.gd"
## Synthetic mixed-stock integration only. Reuses the established banner fixture helpers.
## No physical-game, authentic achievement, rendered acceptance or production-save claim.

var plaque: String


func _ready() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5})
	var ordinary: Dictionary = {
		"version": 1,
		"season_id": 5,
		"season_number": 5,
		"league_id": "standard",
		"difficulty_id": "standard.d4",
		"era": StadiumClubIdentity.current()
	}
	mastery = ordinary.duplicate(true)
	mastery["mastery_contract"] = "standard.d4"
	banner = StadiumPennantRewards.mastery_key()
	authority[StadiumPennantRewards.key(5)] = ordinary
	authority[banner] = mastery
	var player: String = SeasonPlayerCatalog.ids()[0]
	plaque = StadiumPlaqueRewards.key(player)
	authority[plaque] = {
		"version": 1,
		"player_id": player,
		"display_name": "Plaque Fixture",
		"uniform_number": null,
		"season_id": 3,
		"award_game": 5,
		"award_completed": true,
		"era": StadiumClubIdentity.current(),
		"stats":
		{
			"hits": 40,
			"strikeouts": 0,
			"clean_outs": 0,
			"completed_seasons": [1, 2, 3],
			"credited_games": {"1": 5, "2": 5, "3": 5},
			"eligible": true,
			"evidence": "prospective-known-minimum"
		}
	}
	check(
		(
			StadiumCareerProgress.valid(progress, credits)
			and StadiumPennantRewards.valid_awards(authority, credits)
		),
		"mixed synthetic authority validates"
	)
	_mixed_case(false)
	_mixed_case(true)
	print(
		(
			"PLAQUE_MASTERY_JOURNAL_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_funding": true,
					"synthetic_progression": true,
					"synthetic_reward_authority": true,
					"physical_games": 0,
					"rendered_acceptance": false,
					"authentic_earned_career": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _mixed_case(with_salvage: bool) -> void:
	var label: String = "salvage mixed50" if with_salvage else "legacy mixed50"
	var ledger: ClubAssetLedger = (
		ClubAssetLedger.new_club(SEED, credits, progress, authority)
		if with_salvage
		else ClubAssetLedger.new(SEED, credits, progress, authority)
	)
	if with_salvage:
		check(
			(
				ledger
				. commit(
					{
						"id": "mixed-clear",
						"rev": ledger.revision(),
						"op": "stadium_salvage_clear",
						"copy": StadiumStock.SALVAGE_COPY,
						"price_version": 1,
						"through": credits.size()
					}
				)
				. ok
			),
			label + " clears starter car"
		)
	for tier: String in ["expanded", "club"]:
		check(
			(
				ledger
				. commit(
					{
						"id": "mixed-land-" + tier,
						"rev": ledger.revision(),
						"op": "stadium_land",
						"tier": tier,
						"through": credits.size(),
						"progress_through": progress.size(),
						"price_version": StadiumLand.VERSION
					}
				)
				. ok
			),
			label + " buys land " + tier
		)
	check(
		(
			ledger
			. commit(
				{
					"id": BUY,
					"rev": ledger.revision(),
					"op": "stadium_buy",
					"item": "ST-029",
					"quantity": 1,
					"price_version": StadiumStraightItems.PRICE_VERSION,
					"through": credits.size(),
					"progress_through": progress.size()
				}
			)
			. ok
		),
		label + " buys paid lower"
	)
	for id: String in [StadiumPennantRewards.key(5), banner]:
		check(
			(
				ledger
				. commit(
					{
						"id": id,
						"rev": ledger.revision(),
						"op": "stadium_mastery" if id == banner else "stadium_pennant",
						"earned": authority[id]
					}
				)
				. ok
			),
			label + " receives title reward"
		)
	var layout: Dictionary = StadiumMasteryBannerItems.upgrade(
		ledger.view().stadium_draft, ledger.surface_owned()
	)
	layout = StadiumStraightItemsUI.select(
		layout, ledger.construction(), LOWER, {"site": "BASE-L1", "lower": "", "concourse": ""}
	)
	layout = StadiumMasteryBannerItems.place(layout, ledger.construction(), banner, LOWER)
	if not _apply(ledger, layout, label + " initial banner mount"):
		return
	var before: Dictionary = ledger.to_data()
	var prior_revision: int = ledger.revision()
	var prior_balance: int = ledger.balance()
	var prior_capacity: int = ledger.construction().capacity_count()
	var event: Dictionary = {
		"id": plaque, "rev": ledger.revision(), "op": "stadium_plaque", "earned": authority[plaque]
	}
	check(ledger.commit(event).ok, label + " grants one stored plaque after mounted banner")
	var data: Dictionary = ledger.to_data()
	var stock: StadiumStock = ledger.construction()
	check(
		(
			data.version == 50
			and stock.to_data().version == 5
			and stock.earned_count() == 3
			and stock.plaque_count() == 1
			and stock.pennant_count() == 1
		),
		label + " exact mixed reward counts"
	)
	check(
		(
			data.plaque_catalog == StadiumPlaqueRewards.signature()
			and data.mastery_catalog == StadiumPennantRewards.mastery_signature()
			and data.mastery_layout_catalog == StadiumMasteryBannerItems.signature()
		),
		label + " all additive signatures retained"
	)
	check(
		stock.capacity_count() == prior_capacity and ledger.balance() == prior_balance,
		label + " plaque consumes neither physical capacity nor money"
	)
	check(
		(
			stock.copies[plaque].earned.uniform_number == null
			and not stock.blueprints.has("ST-066")
			and StadiumHomeLayout.validate(layout, stock, "club").stored.has(plaque)
		),
		label + " unknown-number plaque stays stored without fabricated art or blueprint"
	)
	check(
		(
			ledger.commit(_json(event)).get("replayed", false)
			and ClubCareer.same(ledger.to_data(), data)
		),
		label + " cold duplicate request replays without another copy"
	)
	var prefix: ClubAssetLedger = ledger.prefix(prior_revision)
	check(
		(
			prefix != null
			and ClubCareer.same(prefix.to_data(), before)
			and not prefix.to_data().has("plaque_catalog")
		),
		label + " rollback restores exact mounted49 metadata"
	)
	_cold(ledger, label + " mounted mixed stock")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.valid(_json(snapshot))
			and StadiumLayoutSnapshot.matches(snapshot, ledger)
			and StadiumLayoutSnapshot.key(snapshot) == StadiumLayoutSnapshot.key(_json(snapshot))
		),
		label + " mixed stock5 layout41 snapshot cold-replays exactly"
	)
	if not _apply(
		ledger,
		StadiumMasteryBannerItems.store_copy(layout, banner),
		label + " banner Store with plaque"
	):
		return
	check(
		(
			ClubCareer.same(stock.to_data(), ledger.construction().to_data())
			and StadiumLayoutSnapshot.matches(snapshot, ledger)
		),
		label + " later banner storage preserves plaque and frozen snapshot"
	)
	_cold(ledger, label + " stored mixed stock")
	if with_salvage:
		check(
			stock.copies.has(StadiumStock.SALVAGE_COPY) and ledger.view().salvage_cleared,
			label + " all four earned/salvage source types coexist"
		)

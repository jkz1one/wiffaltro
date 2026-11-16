extends Node
## Deterministic authored score-only structural history, NOT authentic earned seasons.
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	var baseline: Dictionary = StadiumPennantRewardRebuildChecks.run(_check)
	_check(baseline.ok, "existing ordinary pennant lifecycle remains intact")
	_rewards()
	_legacy()
	_non_titles()
	print(
		(
			"MASTERY_REWARD_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"synthetic_history": true,
					"physical_games": 0
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
		push_error("MASTERY_REWARD: " + label)


static func fixture(count: int = 6, legacy: bool = false, with_salvage: bool = false) -> ClubCareer:
	var source: Dictionary = StadiumPennantRewardRebuildChecks.fixture(count)
	if not source.ok:
		return null
	var career: ClubCareer = source.career
	for index in range(career.runs.size()):
		var row: Dictionary = career.runs[index]
		row.tier = mini(index, 4)
		row.receipt = ClubSeasonRecord.receipt(row.proof, index <= 4, row.tier)
	career.current = 0
	if legacy:
		career._pennants.version = StadiumPennantRewards.VERSION
		career._pennants.erase("mastery_from")
		career._pennants.erase("mastery_contract")
	career._assets = {}
	if with_salvage:
		career._assets = (
			ClubAssetLedger
			. new_club(
				51,
				ClubPlayers.income(career),
				StadiumCareerProgress.capture(career),
				StadiumPennantRewards.awards(career)
			)
			. to_data()
		)
	if not StadiumPennantRewards.deliver(career):
		return null
	return ClubCareer.from_data(_json(career.to_data()))


static func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _rewards() -> void:
	var career: ClubCareer = fixture()
	_check(career != null, "authored Standard d0-d4/repeat history cold-validates")
	if career == null:
		return
	var id: String = StadiumPennantRewards.mastery_key()
	var ledger: ClubAssetLedger = ClubPlayers.assets(career)
	var stock: StadiumStock = ledger.construction()
	_check(
		(
			stock.earned_count() == 7
			and stock.copies[id].item == "ST-067"
			and stock.copies[id].paid == 0
		),
		"six ordinary pennants plus exactly one free mastery banner"
	)
	var earned: Dictionary = stock.copies[id].earned
	_check(
		(
			earned.season_id == 5
			and earned.difficulty_id == "standard.d4"
			and earned.mastery_contract == "standard.d4"
		),
		"tier5 uses index4 and freezes first qualifying season and contract"
	)
	_check(
		(
			stock.copies.has(StadiumPennantRewards.key(5))
			and stock.copies.has(StadiumPennantRewards.key(6))
		),
		"qualifying and repeat mastery seasons each retain ordinary pennants"
	)
	_check(
		(
			ledger.revision() == 7
			and ledger.to_data().version == ClubAssetLedger.MASTERY_VERSION
			and stock.to_data().version == StadiumStock.MASTERY_VERSION
		),
		"additive stock4 journal49 carry earned mastery without old-header rewrite"
	)
	_check(
		(
			ledger.view().spent == 0
			and (
				ledger.balance()
				== ClubPlayers.income(career).reduce(func(a: int, b: int) -> int: return a + b, 0)
			)
		),
		"earned banner changes neither income nor spending"
	)
	_check(
		(
			not stock.blueprints.has("ST-067")
			and not stock.quote("ST-067", 1, {"seasons": 999, "wins": 999}, "illegal-banner").ok
		),
		"banner is never a shop blueprint"
	)
	_check(
		not ledger.view().stadium_active.has("mastery_banners"),
		"lack of mount never blocks delivery or fabricates display"
	)
	var before: Dictionary = career.to_data()
	_check(
		StadiumPennantRewards.deliver(career) and ClubCareer.same(before, career.to_data()),
		"repeated delivery is byte-structure idempotent"
	)
	var event: Dictionary = ledger.to_data().events[5]
	_check(
		event.op == "stadium_mastery" and ledger.commit(event).replayed and ledger.revision() == 7,
		"exact mastery journal request replay is idempotent"
	)
	_check(
		(
			ledger.prefix(5) != null
			and ledger.prefix(5).construction().earned_count() == 5
			and not ledger.prefix(5).to_data().has("mastery_catalog")
		),
		"pre-banner prefix retains old header and five pennants"
	)
	_check(
		ledger.prefix(6) != null and ledger.prefix(6).construction().copies.has(id),
		"first banner prefix cold-replays independently"
	)
	_check(
		(
			ClubAssetLedger.from_data(
				ledger.to_data(),
				51,
				ClubPlayers.income(career),
				StadiumCareerProgress.capture(career)
			)
			== null
		),
		"journal alone cannot manufacture mastery authority"
	)
	var frozen: Dictionary = stock.copies[id].duplicate(true)
	stock.copies[id].earned.era.name = "Isolated mutation"
	_check(
		ClubCareer.same(ledger.construction().copies[id], frozen),
		"returned stock cannot repaint frozen identity"
	)
	for change: String in [
		"era", "contract", "league", "season", "ordinary-op", "header", "downgrade"
	]:
		var bad: Dictionary = before.duplicate(true)
		match change:
			"era":
				bad.assets.events[5].earned.era.name = "Repainted"
			"contract":
				bad.assets.events[5].earned.mastery_contract = "standard.d3"
			"league":
				bad.assets.events[5].earned.league_id = "unsupported"
			"season":
				bad.assets.events[5].earned.season_id = 6
				bad.assets.events[5].earned.season_number = 6
			"ordinary-op":
				bad.assets.events[5].op = "stadium_pennant"
			"header":
				bad.assets.erase("mastery_catalog")
			"downgrade":
				bad.assets.version = ClubAssetLedger.PENNANT_VERSION
				bad.assets.erase("mastery_catalog")
		_check(ClubCareer.from_data(bad) == null, "reject changed mastery " + change)
	for change: String in ["paid", "item", "source", "version", "key", "contract"]:
		var bad: Dictionary = ledger.construction().to_data()
		match change:
			"paid":
				bad.copies[id].paid = 1
			"item":
				bad.copies[id].item = "ST-044"
			"source":
				bad.copies[id].source = StadiumPennantRewards.SOURCE
			"version":
				bad.version = StadiumStock.REWARD_VERSION
			"key":
				bad.copies["wrong"] = bad.copies[id]
				bad.copies.erase(id)
			"contract":
				bad.copies[id].earned.mastery_contract = "standard.d5"
		_check(StadiumStock.from_data(bad) == null, "reject malformed banner stock " + change)
	var salvage: ClubCareer = fixture(5, false, true)
	_check(
		(
			salvage != null
			and ClubPlayers.assets(salvage).construction().copies.has(StadiumStock.SALVAGE_COPY)
			and ClubPlayers.assets(salvage).construction().copies.has(id)
		),
		"new stock4 and journal49 preserve mandatory salvage origin plus banner"
	)
	if salvage != null:
		var mixed: ClubAssetLedger = ClubPlayers.assets(salvage)
		_check(
			(
				mixed.prefix(5) != null
				and mixed.prefix(5).to_data().version == ClubAssetLedger.SALVAGE_VERSION
			),
			"salvage48 pre-banner prefix retains mandatory car origin"
		)
	var active_save: SeasonState = _ordinary_next(career)
	var envelope: Dictionary = SeasonSave.snapshot(active_save) if active_save != null else {}
	var cold: SeasonState = SeasonSave._decode(_json(envelope)) if not envelope.is_empty() else null
	_check(
		(
			cold != null
			and ClubCareer.same(ClubPlayers.assets(cold.career).construction().copies[id], frozen)
		),
		(
			"ordinary next-season full SeasonSave envelope preserves frozen earned mastery: "
			+ SeasonSave.last_error
			+ " / started="
			+ str(active_save != null)
			+ " / envelope="
			+ str(not envelope.is_empty())
		)
	)
	var lower: ClubCareer = fixture(4)
	_check(
		lower != null and not ClubPlayers.assets(lower).construction().copies.has(id),
		"lower-tier titles do not grant mastery"
	)


func _legacy() -> void:
	var old: ClubCareer = fixture(5, true)
	_check(
		(
			old != null
			and not ClubPlayers.assets(old).construction().copies.has(
				StadiumPennantRewards.mastery_key()
			)
		),
		"old tier5 completed history loads without silent mastery backfill"
	)
	if old == null:
		return
	var before: Dictionary = old.to_data()
	_check(
		ClubCareer.same(ClubCareer.from_data(_json(before)).to_data(), before),
		"legacy reward history remains exactly version1 on cold load"
	)
	var next: SeasonState = StadiumPennantRewardRebuildChecks._new(old)
	_check(
		next != null and old._pennants.version == 2 and old._pennants.mastery_from == 6,
		"ordinary next-season start prospectively adopts mastery contract"
	)
	if next == null:
		return
	_check(
		StadiumPennantRewardRebuildChecks._finish(next) and old.sync(next),
		"legacy adopted season closes through existing completion path"
	)
	_check(
		not ClubPlayers.assets(old).construction().copies.has(StadiumPennantRewards.mastery_key()),
		"lower-tier title never retroactively backfills old mastery"
	)
	var bad: Dictionary = old.to_data()
	bad.pennants.mastery_contract = "standard.d5"
	_check(
		ClubCareer.from_data(bad) == null,
		"saved mastery contract cannot silently track a future difficulty"
	)

	# Author another new tier5 title after adoption. Only the actual new era is eligible.
	old.current = 0
	old.runs[-1].tier = 4
	old.runs[-1].receipt = ClubSeasonRecord.receipt(old.runs[-1].proof, false, 4)
	old._pennants.eras["6"].name = "New Mastery Era"
	old._assets = {}
	_check(
		StadiumPennantRewards.deliver(old),
		"legacy club can earn first newly qualifying mastery title"
	)
	var restored: ClubCareer = ClubCareer.from_data(_json(old.to_data()))
	_check(
		(
			restored != null
			and (
				(
					ClubPlayers
					. assets(restored)
					. construction()
					. copies[StadiumPennantRewards.mastery_key()]
					. earned
					. season_id
				)
				== 6
			)
			and (
				(
					ClubPlayers
					. assets(restored)
					. construction()
					. copies[StadiumPennantRewards.mastery_key()]
					. earned
					. era
					. name
				)
				== "New Mastery Era"
			)
		),
		(
			"prospective adoption never permanently excludes old mastery winners; new title "
			+ "freezes its actual new era"
		)
	)


func _non_titles() -> void:
	var career: ClubCareer = fixture(4)
	if career == null:
		_check(false, "non-title prefix validates")
		return
	var season: SeasonState = StadiumPennantRewardRebuildChecks._new(career)
	if season == null:
		_check(false, "non-title season starts")
		return
	var active: ClubCareer = career.fork()
	active.runs[-1].tier = 4
	_check(
		not StadiumPennantRewards.awards(active).has(StadiumPennantRewards.mastery_key()),
		"active tier5 cannot issue a banner"
	)
	active.runs[-1].status = "abandoned"
	active.current = 0
	_check(
		not StadiumPennantRewards.awards(active).has(StadiumPennantRewards.mastery_key()),
		"abandoned tier5 cannot issue a banner"
	)
	_check(
		StadiumPennantRewardRebuildChecks._finish(season, false) and career.sync(season),
		"runner-up fixture completes without title"
	)
	career.runs[-1].tier = 4
	career.runs[-1].receipt = ClubSeasonRecord.receipt(career.runs[-1].proof, true, 4)
	career.current = 0
	career._assets = {}
	_check(
		(
			StadiumPennantRewards.deliver(career)
			and ClubCareer.from_data(_json(career.to_data())) != null
			and not ClubPlayers.assets(career).construction().copies.has(
				StadiumPennantRewards.mastery_key()
			)
		),
		"validated completed tier5 runner-up receives no mastery banner"
	)


static func _ordinary_next(career: ClubCareer) -> SeasonState:
	# Same physical/owned-park/venue envelope as the public Standard entry path.
	var season: SeasonState = SeasonState.create(51, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	var club: ClubCareer = career.fork()
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(club)) or not club.start(season, 0):
		return null
	season.career = club
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(club), true)
	season.npc_venues = SeasonVenues.capture_five(51, club.current, 0)
	season.final_venue = SeasonFinalVenue.capture_standard_base(season)
	return season

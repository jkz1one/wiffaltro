extends Node
## Authored structural player histories, never authentic earned seasons or physical games.
var _checks: int = 0
var _failures: Array[String] = []
var _ids: Array[String] = []
var _base: ClubCareer


func _ready() -> void:
	_ids.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	var source: Dictionary = StadiumPennantRewardRebuildChecks.fixture(3)
	_check(source.ok, "reused three-season synthetic score fixture cold-validates")
	if source.ok:
		_base = source.career
		_thresholds()
		_rewards()
		_legacy_and_unknown()
		_later_game_and_rollback()
	print(
		(
			"PLAQUE_REWARD_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"synthetic_history": true,
					"physical_games": 0,
					"authentic_achievements": 0
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
		push_error("PLAQUE_REWARD: " + label)


static func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _line(credited: bool) -> Dictionary:
	return {
		"pa": 1 if credited else 0,
		"pitches": 0,
		"hits": 0,
		"strikeouts": 0,
		"outs": 0,
		"fielded": false,
		"clean_outs": 0
	}


func _author(
	career: ClubCareer, metric: String, amount: int, ids: Array, credited: int = 5
) -> void:
	# Preserve the reusable fixture's schema/score IDs, not its absent details.
	# All individual evidence added here is explicitly synthetic test input.
	for run: Dictionary in career.runs.slice(0, 3):
		run.player_progress.version = ClubPlayerLegend.VERSION
		for index in range(run.player_progress.games.size()):
			var row: Dictionary = run.player_progress.games[index]
			row.stats = {"homers": 0, "hits": 0, "hitters": 0, "strikeouts": 0, "three_k": 0}
			row.end_half = -1
			row.deficit = 0
			row.players = {}
			for player: String in ids:
				row.players[player] = _line(player == ids[0] and index < credited)
	var game: Dictionary = career.runs[2].player_progress.games[mini(credited, 5) - 1]
	var line: Dictionary = game.players[ids[0]]
	line[metric] = amount
	match metric:
		"hits":
			line.pa = maxi(amount, int(line.pa))
			game.stats.hits = amount
			game.stats.hitters = 1 if amount > 0 else 0
		"strikeouts":
			line.pitches = amount * 3
			line.outs = amount
			game.stats.strikeouts = amount
			game.stats.three_k = 1 if amount >= 3 else 0
		"clean_outs":
			line.fielded = amount > 0
			line.outs = amount


func _fixture(metric: String = "hits", amount: int = 40, credited: int = 5) -> ClubCareer:
	var career: ClubCareer = _base.fork()
	_author(career, metric, amount, _ids, credited)
	career._assets = {}
	career._plaques = {"version": StadiumPlaqueRewards.VERSION, "from_season": 1, "records": {}}
	if (
		not StadiumPlaqueRewards.capture(career)
		or not StadiumPennantRewards.deliver(career)
		or not StadiumPlaqueRewards.deliver(career)
	):
		return null
	return ClubCareer.from_data(_json(career.to_data()))


func _thresholds() -> void:
	for pair: Array in [["hits", 40], ["strikeouts", 60], ["clean_outs", 40]]:
		var below: ClubCareer = _fixture(pair[0], pair[1] - 1)
		_check(
			below != null and StadiumPlaqueRewards.awards(below).is_empty(),
			pair[0] + " one below threshold grants no plaque"
		)
		var career: ClubCareer = _fixture(pair[0], pair[1])
		_check(career != null, pair[0] + " independent OR boundary cold-validates")
		if career == null:
			continue
		var awards: Dictionary = StadiumPlaqueRewards.awards(career)
		var id: String = StadiumPlaqueRewards.key(_ids[0])
		_check(
			awards.size() == 1 and awards.has(id) and awards[id].stats[pair[0]] == pair[1],
			pair[0] + " alone earns exactly one stable player reward"
		)
		if not awards.has(id):
			continue
		_check(
			(
				awards[id].stats.completed_seasons == [1, 2, 3]
				and awards[id].stats.credited_games == {"1": 5, "2": 5, "3": 5}
			),
			pair[0] + " requires five credited games in each of three completed seasons"
		)
	var short: ClubCareer = _fixture("hits", 40, 4)
	_check(
		short != null and StadiumPlaqueRewards.awards(short).is_empty(),
		"four credited games per season never become three qualifying seasons"
	)


func _rewards() -> void:
	var career: ClubCareer = _fixture()
	_check(career != null, "synthetic earned plaque career validates")
	if career == null:
		return
	var id: String = StadiumPlaqueRewards.key(_ids[0])
	var ledger: ClubAssetLedger = ClubPlayers.assets(career)
	var stock: StadiumStock = ledger.construction()
	_check(stock.copies.has(id), "earned ST-066 is persistently owned without a display")
	if not stock.copies.has(id):
		return
	var frozen: Dictionary = stock.copies[id].duplicate(true)
	var record: Dictionary = frozen.earned
	_check(
		(
			stock.earned_count() == 4
			and frozen.item == "ST-066"
			and frozen.paid == 0
			and frozen.source == StadiumPlaqueRewards.SOURCE
		),
		"three pennants plus one free plaque"
	)
	_check(
		(
			record.player_id == _ids[0]
			and record.display_name == ContentDB.get_player(StringName(_ids[0])).display_name
			and record.uniform_number == null
		),
		"player identity is frozen while absent authoritative uniform number remains unknown"
	)
	_check(
		(
			record.season_id == 3
			and record.award_completed
			and record.award_game == career.runs[2].player_progress.games.size()
			and ClubCareer.same(record.era, StadiumClubIdentity.current())
		),
		"first qualifying completion freezes era and game-count boundary"
	)
	_check(
		ledger.to_data().version == 50 and stock.to_data().version == 5,
		"plaque adds journal50 and stock5 without relabeling older prefixes"
	)
	_check(
		(
			ledger.view().spent == 0
			and (
				ledger.balance()
				== ClubPlayers.income(career).reduce(
					func(total: int, credit: int) -> int: return total + credit, 0
				)
			)
		),
		"earned ownership changes neither income nor spending"
	)
	_check(
		(
			not stock.blueprints.has("ST-066")
			and not stock.quote("ST-066", 1, {"seasons": 999, "wins": 999}, "illegal-plaque").ok
		),
		"earned plaque is not a purchasable blueprint"
	)
	_check(
		not ledger.view().stadium_active.has("player_plaques"),
		"missing mount or jersey-number presentation never fabricates an active display"
	)
	var before: Dictionary = career.to_data()
	_check(
		(
			StadiumPlaqueRewards.capture(career)
			and StadiumPlaqueRewards.deliver(career)
			and StadiumPlaqueRewards.delivered(career, ClubPlayers.assets(career))
			and ClubCareer.same(before, career.to_data())
		),
		"capture and delivery replay are exact and idempotent"
	)
	var event: Dictionary = ledger.to_data().events[-1]
	_check(
		event.op == "stadium_plaque" and ledger.commit(event).replayed and ledger.revision() == 4,
		"exact plaque journal replay never issues a second copy"
	)
	var prefix: ClubAssetLedger = ledger.prefix(3)
	_check(
		(
			prefix != null
			and prefix.construction().earned_count() == 3
			and not prefix.construction().copies.has(id)
			and not prefix.to_data().has("plaque_catalog")
			and prefix.to_data().version == ClubAssetLedger.PENNANT_VERSION
		),
		"pre-plaque prefix retains three ordinary pennants and old journal header"
	)
	_check(
		ledger.prefix(4) != null and ledger.prefix(4).construction().copies.has(id),
		"first plaque prefix independently cold-replays"
	)
	_check(
		(
			ClubAssetLedger.from_data(
				ledger.to_data(),
				51,
				ClubPlayers.income(career),
				StadiumCareerProgress.capture(career),
				StadiumPennantRewards.awards(career)
			)
			== null
		),
		"pennant authority alone cannot manufacture a plaque"
	)
	var no_authority: ClubAssetLedger = ClubAssetLedger.new(
		51,
		ClubPlayers.income(career),
		StadiumCareerProgress.capture(career),
		StadiumPennantRewards.awards(career)
	)
	var denied: Dictionary = no_authority.commit(
		{"id": id, "rev": 0, "op": "stadium_plaque", "earned": record.duplicate(true)}
	)
	_check(
		not denied.ok and no_authority.revision() == 0,
		"direct plaque request without career plaque authority fails atomically"
	)
	stock.copies[id].earned.era.name = "Mutated returned view"
	stock.copies[id].earned.display_name = "Mutated returned player"
	stock.copies[id].earned.stats.hits = 999
	_check(
		ClubCareer.same(ledger.construction().copies[id], frozen),
		"returned inventory cannot repaint frozen era, name or statistic snapshot"
	)
	var canonical: Dictionary = StadiumPlaqueRewards.canonical(_json(record))
	_check(
		(
			ClubCareer.same(canonical, record)
			and typeof(canonical.stats.hits) == TYPE_INT
			and typeof(canonical.stats.completed_seasons[0]) == TYPE_INT
		),
		"JSON cold record canonicalizes integer statistics and completed seasons"
	)
	var salvage: ClubCareer = career.fork()
	var all_awards: Dictionary = StadiumPennantRewards.awards(salvage)
	all_awards.merge(StadiumPlaqueRewards.awards(salvage))
	salvage._assets = (
		ClubAssetLedger
		. new_club(
			51, ClubPlayers.income(salvage), StadiumCareerProgress.capture(salvage), all_awards
		)
		. to_data()
	)
	_check(
		(
			StadiumPennantRewards.deliver(salvage)
			and StadiumPlaqueRewards.deliver(salvage)
			and ClubCareer.from_data(_json(salvage.to_data())) != null
			and ClubPlayers.assets(salvage).construction().copies.has(StadiumStock.SALVAGE_COPY)
			and ClubPlayers.assets(salvage).construction().copies.has(id)
		),
		"plaque journal preserves mandatory salvage origin and prior ordinary rewards"
	)
	_check(
		(
			ClubPlayers.assets(salvage).prefix(3) != null
			and (
				ClubPlayers.assets(salvage).prefix(3).to_data().version
				== ClubAssetLedger.SALVAGE_VERSION
			)
		),
		"pre-plaque salvage prefix retains its original journal48 header"
	)
	_capacity_and_disclosure(record)
	_malformed(career, id)
	career.current = 0
	var next: SeasonState = StadiumPennantRewardRebuildChecks._new(career)
	_check(next != null, "ordinary next season starts with owned plaque")
	if next == null:
		return
	var save: Dictionary = SeasonSave.snapshot(next)
	var cold: SeasonState = SeasonSave._decode(_json(save)) if not save.is_empty() else null
	_check(
		(
			cold != null
			and ClubCareer.same(ClubPlayers.assets(cold.career).construction().copies[id], frozen)
		),
		"ordinary SeasonSave envelope cold-restores the frozen plaque"
	)
	var definition: PlayerDefinition = ContentDB.get_player(StringName(_ids[0]))
	var previous_name: String = definition.display_name
	definition.display_name = "Later Player Name"
	career._pennants.eras["4"].name = "Later Club Era"
	var unchanged: bool = (
		StadiumPlaqueRewards.capture(career)
		and StadiumPlaqueRewards.deliver(career)
		and ClubCareer.same(ClubPlayers.assets(career).construction().copies[id], frozen)
	)
	definition.display_name = previous_name
	_check(unchanged, "later current name and club era never repaint an earned snapshot")


func _capacity_and_disclosure(record: Dictionary) -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var paid: Dictionary = stock.quote(
		"ST-001",
		StadiumStock.MAX_COPIES - stock.paid_count(),
		{"seasons": 999, "wins": 999},
		"plaque-capacity-boundary"
	)
	_check(paid.ok, "bounded synthetic stock fixture reaches the existing paid-copy capacity")
	if not paid.ok:
		return
	stock = StadiumStock.from_data(paid.state)
	var granted: Dictionary = stock.plaque_quote(record)
	_check(granted.ok and granted.cost == 0, "a full paid inventory never blocks an earned plaque")
	if not granted.ok:
		return
	stock = StadiumStock.from_data(_json(granted.state))
	_check(
		(
			stock != null
			and stock.copies.size() == StadiumStock.MAX_COPIES + 1
			and stock.capacity_count() == StadiumStock.MAX_COPIES
			and stock.paid_count() == StadiumStock.MAX_COPIES
		),
		"stock5 cold-validates a separately bounded plaque without increasing paid capacity"
	)
	if stock == null:
		return
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	var boards: StadiumScoreboardOwnership = StadiumScoreboardOwnership.new()
	_check(
		(
			StadiumWallPieceOwnership.from_data(pieces.to_data(), stock.capacity_count()) != null
			and (
				StadiumScoreboardOwnership.from_data(boards.to_data(), stock.capacity_count())
				!= null
			)
			and StadiumOwnedLayout._complete_ownership(stock, pieces, boards)
		),
		"complete owned-layout wall and scoreboard inventories exclude plaques from shared capacity"
	)
	_check(
		(
			not stock.quote("ST-001", 1, {"seasons": 999, "wins": 999}, "over-capacity").ok
			and stock.plaque_quote(record).replayed
		),
		"full inventory still refuses extra purchases and replays the same earned plaque"
	)
	var description: String = StadiumPlaqueUI.description(record)
	_check(
		(
			description.contains(record.display_name)
			and description.contains(record.era.name)
			and description.contains("40 hits")
			and not description.contains("#")
		),
		"plaque description uses frozen identity and statistics without a guessed jersey number"
	)
	var card: VBoxContainer = VBoxContainer.new()
	StadiumPlaqueUI.card(card, record)
	var text: String = ""
	for child: Node in card.get_children():
		if child is Label:
			text += child.text + "\n"
	_check(
		(
			text.contains("Uniform number was not recorded")
			and text.contains("No number is invented")
			and text.contains("player stays available")
			and text.contains("Safely stored")
		),
		(
			"owned plaque card explicitly discloses unknown number, stored art and continued "
			+ "player availability"
		)
	)
	card.free()


func _malformed(career: ClubCareer, id: String) -> void:
	var record: Dictionary = career._plaques.records[id]
	for field: String in [
		"number",
		"name",
		"version",
		"player",
		"game",
		"completed",
		"stats",
		"tenure",
		"credits",
		"extra",
		"era"
	]:
		var bad: Dictionary = record.duplicate(true)
		match field:
			"number":
				bad.uniform_number = 7
			"name":
				bad.display_name = "\nFake"
			"version":
				bad.version = 2
			"player":
				bad.player_id = "player.unknown"
			"game":
				bad.award_game = 0
			"completed":
				bad.award_completed = 1
			"stats":
				bad.stats.hits = 39
			"tenure":
				bad.stats.completed_seasons = [1, 1, 3]
			"credits":
				bad.stats.credited_games["1"] = 4
			"extra":
				bad.extra = 0
			"era":
				bad.era.crest = "unknown.crest"
		_check(
			not StadiumPlaqueRewards.valid_record(bad), "reject malformed plaque record " + field
		)
	for field: String in ["paid", "item", "source", "version", "key", "number"]:
		var bad: Dictionary = ClubPlayers.assets(career).construction().to_data()
		match field:
			"paid":
				bad.copies[id].paid = 1
			"item":
				bad.copies[id].item = "ST-067"
			"source":
				bad.copies[id].source = StadiumPennantRewards.SOURCE
			"version":
				bad.version = StadiumStock.MASTERY_VERSION
			"key":
				bad.copies["wrong"] = bad.copies[id]
				bad.copies.erase(id)
			"number":
				bad.copies[id].earned.uniform_number = 7
		_check(StadiumStock.from_data(bad) == null, "reject malformed plaque stock " + field)
	for field: String in [
		"stat-snapshot",
		"era-snapshot",
		"name-snapshot",
		"ordinary-op",
		"forged-stat-history",
		"header",
		"downgrade",
		"history",
		"history-from",
		"authority"
	]:
		var bad: Dictionary = career.to_data()
		match field:
			"stat-snapshot":
				bad.assets.events[-1].earned.stats.hits = 41
			"era-snapshot":
				bad.assets.events[-1].earned.era.name = "Repainted"
			"name-snapshot":
				bad.assets.events[-1].earned.display_name = "Repainted"
			"ordinary-op":
				bad.assets.events[-1].op = "stadium_pennant"
			"header":
				bad.assets.erase("plaque_catalog")
			"downgrade":
				bad.assets.version = ClubAssetLedger.MASTERY_VERSION
				bad.assets.erase("plaque_catalog")
			"history":
				bad.plaques.records[id].stats.hits = 41
			"history-from":
				bad.plaques.from_season = 4
			"forged-stat-history":
				bad.plaques.records[id].stats.hits = 41
				bad.assets.events[-1].earned.stats.hits = 41
			"authority":
				bad.erase("plaques")
		_check(ClubCareer.from_data(bad) == null, "reject changed plaque career " + field)


func _legacy_and_unknown() -> void:
	var career: ClubCareer = _base.fork()
	_author(career, "hits", 40, _ids)
	career._assets = {}
	career._plaques = {}
	_check(
		StadiumPennantRewards.deliver(career),
		"legacy individual-history fixture has only ordinary pennants"
	)
	var legacy: Dictionary = career.to_data()
	var old: ClubCareer = ClubCareer.from_data(_json(legacy))
	_check(
		(
			old != null
			and not legacy.has("plaques")
			and StadiumPlaqueRewards.awards(old).is_empty()
			and ClubCareer.same(old.to_data(), legacy)
		),
		"old qualifying v3 history cold-loads exactly without silent plaque backfill"
	)
	if old != null:
		old.current = 0
		var next: SeasonState = StadiumPennantRewardRebuildChecks._new(old)
		_check(
			(
				next != null
				and old._plaques.from_season == 4
				and old._plaques.records.is_empty()
				and not ClubPlayers.assets(old).construction().copies.has(
					StadiumPlaqueRewards.key(_ids[0])
				)
			),
			"ordinary next start adopts prospective provenance without issuing old achievement"
		)
	var unknown: ClubCareer = _base.fork()
	_check(
		(
			StadiumPlaqueRewards.capture(unknown)
			and StadiumPlaqueRewards.deliver(unknown)
			and StadiumPlaqueRewards.awards(unknown).is_empty()
		),
		"score-only seasons never fabricate player details or earn plaques"
	)
	for run: Dictionary in unknown.runs:
		run.player_progress.version = ClubPlayerProgress.HITS_VERSION
		for game: Dictionary in run.player_progress.games:
			game.erase("players")
	unknown._assets = {}
	_check(
		(
			StadiumPennantRewards.deliver(unknown)
			and StadiumPlaqueRewards.capture(unknown)
			and StadiumPlaqueRewards.deliver(unknown)
			and ClubCareer.from_data(_json(unknown.to_data())) != null
			and StadiumPlaqueRewards.awards(unknown).is_empty()
		),
		"legacy aggregate v2 detail remains unknown, not attributed to the present roster"
	)


func _later_game_and_rollback() -> void:
	var career: ClubCareer = _fixture("hits", 39)
	_check(career != null, "three completed seasons just below metric threshold validate")
	if career == null:
		return
	career.current = 0
	var season: SeasonState = StadiumPennantRewardRebuildChecks._new(career)
	_check(season != null, "ordinary fourth season starts before later threshold game")
	if season == null:
		return
	var own: Array = season.teams[0].roster
	# Attribute the authored prior test history to this actual fixture roster.
	_author(career, "hits", 39, own)
	career._assets = {}
	_check(
		StadiumPennantRewards.deliver(career),
		"synthetic history rebuild retains three ordinary pennants"
	)
	var before_game: ClubCareer = career.fork()
	_check(
		_record_hit(season) and career.sync(season),
		"one authored attributed game reaches the ordinary result-settlement path"
	)
	if season.player_results.is_empty():
		return
	var id: String = StadiumPlaqueRewards.key(own[0])
	var awards: Dictionary = StadiumPlaqueRewards.awards(career)
	_check(
		awards.has(id),
		"later active-season statistic can earn after three completed qualifying seasons"
	)
	if not awards.has(id):
		return
	var frozen: Dictionary = awards[id].duplicate(true)
	_check(
		(
			frozen.season_id == 4
			and frozen.award_game == 1
			and not frozen.award_completed
			and frozen.stats.hits == 40
			and frozen.stats.completed_seasons == [1, 2, 3]
			and frozen.stats.credited_games["4"] == 1
		),
		"later award freezes exact active game boundary without crediting an unfinished fourth season"
	)
	var before: Dictionary = career.to_data()
	_check(
		career.sync(season) and career.sync(season) and ClubCareer.same(before, career.to_data()),
		"ordinary active-game sync cannot duplicate or repaint a plaque"
	)
	var saved: Dictionary = SeasonSave.snapshot(season)
	var cold: SeasonState = SeasonSave._decode(_json(saved)) if not saved.is_empty() else null
	_check(
		cold != null and ClubCareer.same(cold.career._plaques.records[id], frozen),
		"active-game award survives full cold-save validation"
	)
	# Fail the asset replay after the new result would make this old prefix eligible.
	var failed: ClubCareer = before_game.fork()
	failed._assets.catalog = "invalid-test-catalog"
	var failed_before: Dictionary = failed.to_data()
	_check(
		not failed.sync(season) and ClubCareer.same(failed.to_data(), failed_before),
		"failed plaque delivery restores prior run, award history and asset journal atomically"
	)
	_check(
		(
			_record_hit(season)
			and career.sync(season)
			and ClubPlayerLegend._evaluate_runs(career.runs)[own[0]].hits == 41
			and ClubCareer.same(career._plaques.records[id], frozen)
		),
		"later individual statistic increases never repaint the first earned snapshot"
	)
	_check(
		(
			career.close(season)
			and career.runs[-1].status == "abandoned"
			and ClubCareer.same(career._plaques.records[id], frozen)
			and ClubCareer.from_data(_json(career.to_data())) != null
		),
		"later abandonment preserves earned statistics and immutable award without extra tenure"
	)


func _record_hit(season: SeasonState) -> bool:
	var row: Dictionary = season.pending_fixture()
	var own: Array = season.teams[0].roster
	var enemy: Array = season.teams[row.away if row.home == 0 else row.home].roster
	var stats: Dictionary = {}
	for player: String in own + enemy:
		stats[player] = MatchPerformance.empty_line()
		stats[player]["fielding_v1"] = false
	stats[own[0]].pa = 1
	stats[own[0]].h = 1
	stats[enemy[0]].p_h = 1
	stats[enemy[0]].pitches = 1
	return (
		SeasonPerformance.valid(stats, stats.keys())
		and season.record_player_result(row.id, 1, 0, stats)
	)

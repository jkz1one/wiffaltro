extends Node
## Bounded closed-bridge tests. Compact fixtures are explicitly trusted semantic
## data; controlled game rewards are not evidence of naturally played seasons.

const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const ALEX: String = "player.alex_finch"
const ARI: String = "player.ari_banks"
const ASH: String = "player.ash_cole"
const ROWAN: String = "player.rowan_chase"
const LINEAGE: String = "development-bridge"
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


static func cold(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


static func semantic_profile() -> Dictionary:
	var roster: Array[String] = [ALEX, ARI, ASH, ROWAN]
	var value: Dictionary = cold(
		Profile.capture_build(SeasonBuild.new(10901, roster), LINEAGE, "human")
	)
	if value.is_empty():
		return {}
	var alex: Dictionary = value.players[ALEX]
	alex.trained.contact = 4
	alex.stats.contact += 4
	alex.ever_earned = true
	var eephus: String = SeasonPlayerCatalog.RECIPES.E
	alex.earned_mastery[eephus] = 3
	alex.mastery[eephus] = 5
	for row: Array in [
		[ALEX, SeasonPlayerCatalog.RECIPES.D, "learn:0", 0, true],
		[ALEX, SeasonPlayerCatalog.RECIPES.R, "remembered:riser", 2, false],
		[ASH, SeasonPlayerCatalog.RECIPES.K, "learn:1", 0, true]
	]:
		var player: Dictionary = value.players[row[0]]
		var recipe: String = row[1]
		player.mastery[recipe] = 1 + row[3]
		player.earned_mastery[recipe] = row[3]
		player.catchup.mastery[recipe] = 0
		player.known_origin[recipe] = {
			"source_season": LINEAGE + ":1", "kind": "learn", "receipt": row[2]
		}
		if row[4]:
			player.active.append(recipe)
			player.active_learning[recipe] = {"source_season": LINEAGE + ":1", "receipt": row[2]}
	for item: String in [SeasonAbilities.COUNT, SeasonAbilities.HANDS]:
		alex.abilities.append(
			{
				"source_season": LINEAGE + ":1",
				"id": "ability:" + item,
				"item": item,
				"slot": SeasonAbilities.ITEMS[item].slot,
				"paid": SeasonAbilities.ITEMS[item].price
			}
		)
	var fresh: Dictionary = RecruitCatalog.fresh(ARI, "middle")
	value.players[ARI].catchup.origin = fresh.catchup
	for stat: String in SeasonPlayerCatalog.STATS:
		value.players[ARI].stats[stat] = fresh.stats[stat]
		value.players[ARI].catchup.stats[stat] = fresh.stats[stat] - fresh.base[stat]
	for recipe: String in fresh.mastery:
		value.players[ARI].mastery[recipe] = fresh.mastery[recipe]
		value.players[ARI].catchup.mastery[recipe] = (
			fresh.mastery[recipe] - value.players[ARI].authored.mastery[recipe]
		)
	return Profile.normalize(value)


static func projected(source: Dictionary, ordinal: int, seed_value: int) -> Dictionary:
	# Explicit test projection: the separate lineage lifecycle owns admission.
	var result: Dictionary = Profile.decay(source)
	if result.is_empty():
		return {}
	var next: Dictionary = result.profile.duplicate(true)
	next.season_ordinal = ordinal
	next.seed = seed_value
	return Profile.normalize(next)


static func operation(
	book: SeasonDevelopment, op: String, player: String, target: String
) -> Dictionary:
	return {
		"id": "current:%d" % book.revision(),
		"rev": book.revision(),
		"op": op,
		"player": player,
		"target": target
	}


func _ready() -> void:
	var source: Dictionary = semantic_profile()
	check(not source.is_empty(), "explicit compact semantic source normalizes")
	if not source.is_empty():
		var start: Dictionary = projected(source, 2, 202)
		check(not start.is_empty(), "first rollover projects bounded existing candidate")
		if not start.is_empty():
			_seeding(start)
			_provenance(start)
			_serialization(start)
			_recapture(start)
	_legacy()
	print("Dynasty development bridge checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _seeding(start: Dictionary) -> void:
	var rules: Dictionary = LeagueRules.capture("dynasty")
	var book: SeasonDevelopment = SeasonDevelopment.new("seeded")
	check(book.enable_dynasty(rules), "empty Dynasty context permits fresh baseline/AI")
	check(
		book.revision() == 0 and book.player(ALEX) == SeasonPlayerCatalog.profile(ALEX),
		"no synthetic events or growth in empty context"
	)
	var input: Dictionary = start.duplicate(true)
	check(book.enable_dynasty(rules, input), "one compact roster injection before events")
	input.players[ALEX].stats.contact = 10
	check(
		book.player(ALEX).stats == start.players[ALEX].stats,
		"caller aliases cannot mutate carried raw profile"
	)
	check(
		(
			book._dynasty_start.is_read_only()
			and book._dynasty_start.players[ALEX].stats.is_read_only()
		),
		"start is recursively immutable"
	)
	check(
		book.revision() == 0 and book._events.is_empty() and book._requests.is_empty(),
		"inheritance creates no purchases or journal requests"
	)
	check(book.enable_dynasty(rules, start), "identical pre-event injection is idempotent")
	check(not book.enable_dynasty(rules), "nonempty start cannot be erased")
	var changed: Dictionary = start.duplicate(true)
	changed.seed += 1
	check(not book.enable_dynasty(rules, changed), "nonempty start cannot be replaced")
	check(
		not book.enable_scramble(LeagueRules.capture("scramble", 0, 202)),
		"carried context cannot become Scramble"
	)
	check(
		(
			book.context_matches(rules)
			and not book.context_matches({})
			and not book.context_matches(LeagueRules.capture("standard"))
		),
		"exact Dynasty rule context bound"
	)
	for id: String in start.roster:
		var raw: Dictionary = book.player(id)
		var authored: Dictionary = SeasonPlayerCatalog.profile(id)
		check(
			(
				raw.stats == start.players[id].stats
				and raw.active == start.players[id].active
				and raw.mastery == start.players[id].mastery
			),
			"raw carried stats and complete recipes: " + id
		)
		check(
			raw.id == id and raw.base == authored.base and raw.capacity == authored.capacity,
			"authored identity/base/capacity unchanged: " + id
		)
	var id: String = "player.bailey_quinn"
	check(book.player(id) == SeasonPlayerCatalog.profile(id), "uncarried players remain authored")
	check(
		book.recruit_profile(id, "late") == RecruitCatalog.fresh(id, "late"),
		"Dynasty uses ordinary recruit catch-up"
	)
	check(
		book.commit(operation(book, "recruit", id, "late")).ok, "uncarried ordinary recruit applies"
	)
	check(
		(
			SeasonRetraining.points(book, id).values() == [0, 0, 0, 0]
			and not book.earned_players([id]).has(id)
		),
		"recruit catch-up creates no paid or earned credit"
	)
	check(not book.enable_dynasty(rules, start), "start cannot be re-enabled after any event")
	var copy: SeasonDevelopment = book.fork()
	check(
		(
			copy.context_matches(rules)
			and Profile.same(copy._dynasty_start, start)
			and copy._dynasty_start.is_read_only()
		),
		"fork preserves immutable context"
	)
	check(
		(
			copy.commit(operation(copy, "stat", ALEX, "power")).ok
			and copy.player(ALEX).stats != book.player(ALEX).stats
		),
		"fork growth cannot mutate original"
	)
	var definition: PlayerDefinition = ProgressionMatchAdapter.player(book, ALEX)
	var original: PlayerDefinition = ContentDB.get_player(StringName(ALEX))
	check(
		(
			definition != null
			and definition.bats == original.bats
			and definition.throws == original.throws
			and definition.switch_hitter == original.switch_hitter
		),
		"adapter retains authored handedness"
	)
	check(
		(
			definition != null
			and definition.natural_delivery == original.natural_delivery
			and definition.pitching_style == original.pitching_style
		),
		"adapter retains natural delivery and pitching style"
	)
	var bad: Dictionary = start.duplicate(true)
	bad.players[ALEX].trained.contact += 1
	var fresh: SeasonDevelopment = SeasonDevelopment.new("bad")
	check(
		not fresh.enable_dynasty(rules, bad) and fresh._league_rules.is_empty(),
		"invalid component balance rejects atomically"
	)
	check(
		not fresh.enable_dynasty(LeagueRules.capture("standard"), start),
		"ordinary rules cannot admit carried profile"
	)
	fresh._players[ALEX].stats.contact += 1
	check(not fresh.enable_dynasty(rules, start), "mutated baseline cache rejects admission")


func _provenance(start: Dictionary) -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("provenance")
	check(book.enable_dynasty(LeagueRules.capture("dynasty"), start), "seed provenance fixture")
	check(
		SeasonRetraining.points(book, ALEX).contact == 2 and SeasonRetraining.count(book) == 2,
		"only surviving paid credits inherit"
	)
	check(
		book.earned_players(start.roster) == [ALEX],
		"inherited ever-earned excludes catch-up and lesson-only players"
	)
	var retrain: Dictionary = {
		"id": "move:0",
		"rev": 0,
		"op": "retrain",
		"player": ALEX,
		"remove": ["contact", "contact"],
		"add": ["power", "power"]
	}
	check(book.commit(retrain).ok, "two surviving earned points may retrain without new credit")
	check(
		(
			SeasonRetraining.points(book, ALEX).contact == 0
			and SeasonRetraining.points(book, ALEX).power == 2
			and SeasonRetraining.count(book) == 2
		),
		"retraining moves inherited paid vector exactly"
	)
	retrain.id = "move:1"
	retrain.rev = book.revision()
	check(not book.commit(retrain).ok, "spent inherited credit cannot be spent twice")
	var drop: String = SeasonPlayerCatalog.RECIPES.D
	var knuckle: String = SeasonPlayerCatalog.RECIPES.K
	var riser: String = SeasonPlayerCatalog.RECIPES.R
	check(
		SeasonPitchExchange.learned(book, ALEX) == start.players[ALEX].active_learning,
		"exact active acquisition map seeds"
	)
	check(
		not SeasonPitchExchange.learned(book, ALEX).has(riser),
		"remembered inactive lesson mints no exchange right"
	)
	check(
		(
			book
			. commit(
				{
					"id": "exchange:0",
					"rev": book.revision(),
					"op": "exchange",
					"player": ALEX,
					"other": ASH,
					"first": drop,
					"second": knuckle
				}
			)
			. ok
		),
		"inherited active recipes exchange"
	)
	check(
		SeasonPitchExchange.learned(book, ASH)[drop] == start.players[ALEX].active_learning[drop],
		"exchange preserves exact original acquisition season and ID"
	)
	check(
		(
			SeasonPitchExchange.learned(book, ALEX)[knuckle]
			== start.players[ASH].active_learning[knuckle]
		),
		"other exchange acquisition retains original provenance"
	)
	check(
		(
			book.player(ALEX).mastery[riser] == start.players[ALEX].mastery[riser]
			and book.player(ALEX).mastery.has(drop)
		),
		"exchange keeps personal inactive mastery memory"
	)
	check(
		(
			book
			. commit(
				{
					"id": "learn:0",
					"rev": book.revision(),
					"op": "learn",
					"player": ALEX,
					"target": riser,
					"replace": knuckle
				}
			)
			. ok
		),
		"new current lesson may reuse old-season local request ID"
	)
	check(
		(
			SeasonPitchExchange.learned(book, ALEX)[riser]
			== {"source_season": LINEAGE + ":2", "receipt": "learn:0"}
		),
		"current source namespace separates same raw receipt ID"
	)
	check(
		(
			not SeasonPitchExchange.learned(book, ALEX).has(knuckle)
			and SeasonPitchExchange.learned(book, ASH)[drop].source_season == LINEAGE + ":1"
		),
		"replacing removes only old active right, not another player's provenance"
	)
	var no_right: Dictionary = start.duplicate(true)
	no_right.players[ALEX].active_learning.clear()
	var none: SeasonDevelopment = SeasonDevelopment.new("no-right")
	check(
		(
			none.enable_dynasty(LeagueRules.capture("dynasty"), no_right)
			and SeasonPitchExchange.learned(none, ALEX).is_empty()
		),
		"nonauthored recipe alone creates no acquisition right"
	)
	var exhausted: Dictionary = start
	for index in range(4):
		exhausted = Profile.decay(exhausted).profile
	var floor_book: SeasonDevelopment = SeasonDevelopment.new("floor")
	check(
		floor_book.enable_dynasty(LeagueRules.capture("dynasty"), exhausted),
		"fully decayed carried profile admits"
	)
	check(
		SeasonRetraining.count(floor_book) == 0 and floor_book.earned_players([ALEX]) == [ALEX],
		"ever-earned survives loss of all paid levels"
	)
	check(
		floor_book.player(ALEX).mastery[SeasonPlayerCatalog.RECIPES.E] == 2,
		"Alex authored Eephus2 floor unchanged"
	)


func _serialization(start: Dictionary) -> void:
	var rules: Dictionary = LeagueRules.capture("dynasty")
	var book: SeasonDevelopment = SeasonDevelopment.new("roundtrip")
	check(book.enable_dynasty(rules, start), "seed standalone roundtrip")
	check(
		book.commit(operation(book, "stat", ALEX, "power")).ok,
		"current growth journal after inherited start"
	)
	var data: Dictionary = cold(book.to_data())
	check(
		(
			data.version == 3
			and Profile.keys(
				data, ["version", "season", "catalog", "events", "league_rules", "dynasty_start"]
			)
		),
		"standalone v3 exact header"
	)
	var restored: SeasonDevelopment = SeasonDevelopment.from_data(data, "roundtrip", rules, start)
	check(
		(
			restored != null
			and restored.player(ALEX) == book.player(ALEX)
			and restored.revision() == 1
		),
		"cold v3 replays one current event without synthetic history"
	)
	check(
		(
			restored != null
			and SeasonRetraining.points(restored, ALEX) == SeasonRetraining.points(book, ALEX)
		),
		"cold restored inherited plus current credit"
	)
	check(
		SeasonDevelopment.from_data(data, "roundtrip") == null,
		"omitted context cannot load Dynasty"
	)
	check(
		SeasonDevelopment.from_data(data, "roundtrip", rules) == null,
		"nonempty start requires exact expected start"
	)
	var wrong: Dictionary = start.duplicate(true)
	wrong.owner_id = "other"
	check(
		SeasonDevelopment.from_data(data, "roundtrip", rules, wrong) == null,
		"foreign expected owner rejects"
	)
	for version in [1, 2, 3]:
		var stripped: Dictionary = data.duplicate(true)
		stripped.version = version
		stripped.erase("dynasty_start")
		if version == 1:
			stripped.erase("league_rules")
		check(
			SeasonDevelopment.from_data(stripped, "roundtrip", rules, start) == null,
			"stripped or downgraded standalone header rejects: " + str(version)
		)
	data.extra = true
	check(
		SeasonDevelopment.from_data(data, "roundtrip", rules, start) == null,
		"extra v3 field rejects"
	)
	var stripped_context: SeasonDevelopment = book.fork()
	stripped_context._league_rules = {}
	check(
		not stripped_context.context_matches({}),
		"stripped rules cannot relabel inherited start as context-free"
	)
	check(
		not stripped_context.context_matches(LeagueRules.capture("standard")),
		"stripped rules cannot relabel inherited start as Standard"
	)
	var injected: SeasonDevelopment = SeasonDevelopment.new("injected")
	injected._dynasty_start = start
	check(
		(
			not injected.context_matches({})
			and not injected.context_matches(LeagueRules.capture("dugout"))
		),
		"injected inherited start invalidates otherwise ordinary context"
	)
	var scramble: SeasonDevelopment = SeasonDevelopment.new("injected-scramble")
	var scramble_rules: Dictionary = LeagueRules.capture("scramble", 0, 505)
	check(scramble.enable_scramble(scramble_rules), "enable clean Scramble negative fixture")
	scramble._dynasty_start = start
	check(
		not scramble.context_matches(scramble_rules),
		"injected inherited start invalidates otherwise matching Scramble context"
	)


func _recapture(start: Dictionary) -> void:
	var current: Dictionary = start
	for ordinal in [2, 3]:
		var roster: Array[String] = []
		roster.assign(current.roster)
		var build: SeasonBuild = SeasonBuild.new(int(current.seed), roster)
		check(
			(
				build.enable_league_rules(LeagueRules.capture("dynasty"))
				and build.enable_dynasty_start(current)
			),
			"Build admits compact projected start: " + str(ordinal)
		)
		check(
			build._book.revision() == 0 and build._book._events.is_empty(),
			"Build inheritance is not synthetic development history"
		)
		var baseline: Dictionary = Profile.capture_build(build, LINEAGE, "human", ordinal)
		check(
			not baseline.is_empty(), "fresh checked Build recaptures initial inherited provenance"
		)
		if baseline.is_empty():
			return
		check(
			baseline.players[ALEX].abilities == current.players[ALEX].abilities,
			"recapture preserves original ability ID/paid/season"
		)
		check(
			(
				baseline.players[ALEX].known_origin == current.players[ALEX].known_origin
				and baseline.players[ALEX].active_learning == current.players[ALEX].active_learning
			),
			"recapture preserves known and acquisition origins"
		)
		check(
			(
				baseline.players[ALEX].earned_mastery == current.players[ALEX].earned_mastery
				and baseline.players[ALEX].trained == current.players[ALEX].trained
			),
			"recapture starts from surviving inherited paid components"
		)
		check(
			(
				Profile.capture_build(build, "foreign", "human", ordinal).is_empty()
				and Profile.capture_build(build, LINEAGE, "other", ordinal).is_empty()
				and Profile.capture_build(build, LINEAGE, "human", ordinal - 1).is_empty()
			),
			"recapture rejects relabeled lineage/owner/ordinal"
		)
		check(
			(
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": 0, "win": true}))
				. ok
			),
			"controlled game funding, not physical game evidence"
		)
		check(
			(
				build.commit(SeasonOpponentPolicy.command(build, "open")).ok
				and build.commit(SeasonOpponentPolicy.command(build, "pack_open")).ok
			),
			"pay actual generated development pack quote"
		)
		var cards: Array = build.view().shop.cards
		check(not cards.is_empty(), "bounded funded pack offers supported development")
		if cards.is_empty():
			return
		var item: String = cards[0]
		var targets: Array[Dictionary] = build.targets(item)
		check(not targets.is_empty(), "paid card has legal target")
		if targets.is_empty():
			return
		var fields: Dictionary = targets[0].duplicate(true)
		fields.item = item
		check(
			build.commit(SeasonOpponentPolicy.command(build, "pack_pick", fields)).ok,
			"apply paid generated development on current journal"
		)
		var captured: Dictionary = Profile.capture_build(build, LINEAGE, "human", ordinal)
		check(not captured.is_empty(), "second-generation growth recaptures only checked Build")
		if captured.is_empty():
			return
		var paid_total: int = 0
		for id: String in current.roster:
			for stat: String in SeasonPlayerCatalog.STATS:
				paid_total += (
					int(captured.players[id].trained[stat]) - int(current.players[id].trained[stat])
				)
			for recipe: String in current.players[id].earned_mastery:
				paid_total += (
					int(captured.players[id].earned_mastery[recipe])
					- int(current.players[id].earned_mastery[recipe])
				)
		check(
			paid_total == 1,
			"capture sums exactly one current paid stat/mastery point onto inherited components"
		)
		check(
			(
				captured.players[ALEX].abilities == current.players[ALEX].abilities
				and captured.players[ALEX].active_learning == current.players[ALEX].active_learning
			),
			"new growth does not re-stamp old ability or lesson origins"
		)
		build._book._players[ALEX].stats.contact = 10
		build._abilities.learned[ALEX].clear()
		check(
			Profile.same(Profile.capture_build(build, LINEAGE, "human", ordinal), captured),
			"caller raw and ability caches cannot override freshly replayed capture"
		)
		if ordinal == 2:
			current = projected(captured, 3, 303)
			check(not current.is_empty(), "second explicit rollover projects fresh checked capture")
			if current.is_empty():
				return


func _legacy() -> void:
	var ordinary: SeasonDevelopment = SeasonDevelopment.new("ordinary")
	check(
		ordinary.to_data().version == 1 and not ordinary.to_data().has("dynasty_start"),
		"historical v1 exact shape unchanged"
	)
	check(
		(
			ordinary
			. commit(
				{
					"id": "legacy:0",
					"rev": 0,
					"op": "learn",
					"player": ALEX,
					"target": SeasonPlayerCatalog.RECIPES.D,
					"replace": ""
				}
			)
			. ok
		),
		"ordinary development still accepts supported lesson"
	)
	check(
		SeasonPitchExchange.learned(ordinary, ALEX)[SeasonPlayerCatalog.RECIPES.D] == "legacy:0",
		"ordinary acquisition values remain String receipt IDs"
	)
	check(
		SeasonDevelopment.from_data(cold(ordinary.to_data()), "ordinary") != null,
		"historical v1 cold replay"
	)
	var scramble: SeasonDevelopment = SeasonDevelopment.new("scramble")
	var rules: Dictionary = LeagueRules.capture("scramble", 0, 404)
	check(
		(
			scramble.enable_scramble(rules)
			and scramble.to_data().version == 2
			and not scramble.to_data().has("dynasty_start")
		),
		"historical Scramble v2 shape unchanged"
	)
	check(
		SeasonDevelopment.from_data(cold(scramble.to_data()), "scramble", rules) != null,
		"historical Scramble cold replay"
	)
	check(
		not scramble.enable_dynasty(LeagueRules.capture("dynasty")),
		"Scramble cannot cross into Dynasty"
	)

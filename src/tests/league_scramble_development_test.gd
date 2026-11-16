extends Node
## Pure mapping and standalone development replay. No production save or activation.

const ALEX: String = "player.alex_finch"
const ROWAN: String = "player.rowan_chase"
const TESS: String = "player.tess_vale"
const SEASON: String = "isolated-scramble-development"

var checks: int = 0
var failures: int = 0


func _ready() -> void:
	_mapping_contract()
	_all_profiles()
	_context_and_isolation()
	_recruit_development()
	_replay_contract()
	print("Scramble development checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _mapping_contract() -> void:
	var rules: Dictionary = LeagueRules.capture("scramble", 0, 0)
	_check(
		(
			SeasonScramble.mapping(ALEX, rules)
			== {
				"contact": "contact",
				"power": "fielding",
				"fielding": "power",
				"pitching": "pitching"
			}
		),
		"seed-zero independent SHA256 golden fixture"
	)
	_check(
		(
			SeasonScramble.mapping(ROWAN, LeagueRules.capture("scramble", 0, 117))
			== {
				"contact": "power",
				"power": "pitching",
				"fielding": "fielding",
				"pitching": "contact"
			}
		),
		"seed117 independent SHA256 golden fixture"
	)
	_check(
		(
			SeasonScramble.mapping(TESS, LeagueRules.capture("scramble", 0, 2147483647))
			== {
				"contact": "pitching",
				"power": "contact",
				"fielding": "fielding",
				"pitching": "power"
			}
		),
		"maximum root seed independent SHA256 golden fixture"
	)
	_check(
		(
			SeasonScramble.profile(ALEX, rules).stats
			== {"contact": 2, "power": 2, "fielding": 1, "pitching": 5}
		),
		"seed-zero independent exact Alex vector"
	)
	_check(
		(
			SeasonScramble.mapping(ROWAN, LeagueRules.capture("scramble", 0, 24680))
			== {
				"contact": "fielding",
				"power": "contact",
				"fielding": "power",
				"pitching": "pitching"
			}
		),
		"reviewer independent seed24680 golden mapping"
	)
	_check(
		(
			SeasonScramble.profile(ROWAN, LeagueRules.capture("scramble", 0, 24680)).stats
			== {"contact": 1, "power": 1, "fielding": 5, "pitching": 1}
		),
		"reviewer independent seed24680 exact Rowan vector"
	)
	var dakota: String = "player.dakota_wells"
	_check(
		(
			SeasonScramble.mapping(dakota, LeagueRules.capture("scramble", 0, 2147483647))
			== {
				"contact": "pitching",
				"power": "power",
				"fielding": "fielding",
				"pitching": "contact"
			}
		),
		"reviewer independent maximum seed golden mapping"
	)
	_check(
		(
			SeasonScramble.profile(dakota, LeagueRules.capture("scramble", 0, 2147483647)).stats
			== {"contact": 3, "power": 2, "fielding": 2, "pitching": 2}
		),
		"reviewer independent maximum seed exact Dakota vector"
	)
	for invalid: Variant in [{}, null, [], LeagueRules.capture("standard")]:
		_check(
			SeasonScramble.mapping(ALEX, invalid).is_empty(),
			"invalid or non-Scramble mapping closed"
		)
		_check(SeasonScramble.profile(ALEX, invalid).is_empty(), "invalid profile context closed")
		_check(
			SeasonScramble.fresh(ALEX, "early", invalid).is_empty(),
			"invalid recruit context closed"
		)
	for invalid: String in ["", "alex_finch", "player.debug_pitcher", "player.unknown"]:
		_check(SeasonScramble.mapping(invalid, rules).is_empty(), "only canonical known identities")
		_check(SeasonScramble.profile(invalid, rules).is_empty(), "unknown profile closed")
		_check(SeasonScramble.fresh(invalid, "early", rules).is_empty(), "unknown recruit closed")
	_check(SeasonScramble.fresh(ALEX, "unknown", rules).is_empty(), "unknown recruit stage closed")
	for field: String in ["version", "league", "tier", "profile", "season_seed"]:
		var malformed: Dictionary = rules.duplicate(true)
		malformed.erase(field)
		_check(
			SeasonScramble.profile(ALEX, malformed).is_empty(), "missing immutable rule " + field
		)
	for bad_seed: Variant in [-1, 2147483648, 0.5, true, "0", null]:
		var malformed: Dictionary = rules.duplicate(true)
		malformed.season_seed = bad_seed
		_check(SeasonScramble.mapping(ALEX, malformed).is_empty(), "strict root seed validation")
	var extra: Dictionary = rules.duplicate(true)
	extra.shop_seed = 99
	_check(SeasonScramble.mapping(ALEX, extra).is_empty(), "no shop seed in transform context")
	var malformed_profile: Dictionary = SeasonPlayerCatalog.profile(ALEX)
	malformed_profile.stats.contact = 0.5
	_check(
		SeasonScramble.transform(malformed_profile, rules).is_empty(), "fractional stats rejected"
	)
	malformed_profile = SeasonPlayerCatalog.profile(ALEX)
	malformed_profile.base.erase("power")
	_check(
		SeasonScramble.transform(malformed_profile, rules).is_empty(),
		"incomplete authored base rejected"
	)
	# Seed only this standalone test's RNG. Helper calls must not advance it.
	seed(44017)
	var expected_next: int = randi()
	seed(44017)
	var first: Dictionary = SeasonScramble.profile(ALEX, rules)
	SeasonScramble.fresh(ROWAN, "late", rules)
	_check(randi() == expected_next, "transforms never consume global RNG")
	seed(99011)
	for index in range(32):
		randi()
	_check(
		SeasonScramble.profile(ALEX, rules) == first, "mapping independent of unrelated RNG draws"
	)


func _all_profiles() -> void:
	var catalog_signature: String = SeasonPlayerCatalog.signature()
	var recruit_signature: String = RecruitCatalog.signature()
	var ids: Array[String] = SeasonPlayerCatalog.ids()
	_check(ids.size() == 48, "all48 authored players present")
	var differing_players: int = 0
	for season_seed: int in [0, 117, 2147483647]:
		var rules: Dictionary = LeagueRules.capture("scramble", 0, season_seed)
		var book: SeasonDevelopment = _book(rules)
		_check(
			book.revision() == 0 and book.to_data().events.is_empty(), "permutation is not training"
		)
		for player_id: String in ids:
			var source: Dictionary = SeasonPlayerCatalog.profile(player_id)
			var source_before: Dictionary = source.duplicate(true)
			var permutation: Dictionary = SeasonScramble.mapping(player_id, rules)
			var destinations: Array = permutation.keys()
			var sources: Array = permutation.values()
			destinations.sort()
			sources.sort()
			var names: Array[String] = SeasonPlayerCatalog.STATS.duplicate()
			names.sort()
			_check(destinations == names and sources == names, "four-stat bijection " + player_id)
			var transformed: Dictionary = SeasonScramble.transform(source, rules)
			_profile_equal_except_vectors(source, transformed, permutation, player_id)
			_check(transformed == book.player(player_id), "all initial players transformed once")
			_check(transformed.base == transformed.stats, "initial transformed authored baseline")
			_check(source == source_before, "transform is pure for caller profile")
			if (
				season_seed == 117
				and (
					permutation
					!= SeasonScramble.mapping(player_id, LeagueRules.capture("scramble", 0, 0))
				)
			):
				differing_players += 1
			for stage: String in RecruitCatalog.STAGES:
				var recruit: Dictionary = RecruitCatalog.fresh(player_id, stage)
				var changed: Dictionary = SeasonScramble.fresh(player_id, stage, rules)
				_profile_equal_except_vectors(
					recruit, changed, permutation, player_id + ":" + stage
				)
				_check(changed.base == transformed.base, "recruit retains permuted authored base")
				_check(
					changed.catchup == recruit.catchup, "catchup stage and price remain unchanged"
				)
				_check(
					book.recruit_profile(player_id, stage) == changed, "book fresh lookup agrees"
				)
			transformed.stats.contact = 999
			transformed.base.power = 999
			transformed.active.clear()
			transformed.mastery.clear()
			_check(SeasonPlayerCatalog.profile(player_id) == source_before, "no catalog alias")
			_check(book.player(player_id) != transformed, "no ledger profile alias")
		_check(
			book.earned_players(ids).is_empty(),
			"innate permutation has no earned-player provenance"
		)
		_check(SeasonRetraining.count(book) == 0, "innate permutation is not retrainable growth")
	_check(differing_players > 0, "root seed actually changes mappings")
	_check(SeasonPlayerCatalog.signature() == catalog_signature, "global player catalog unchanged")
	_check(RecruitCatalog.signature() == recruit_signature, "global recruits and prices unchanged")


func _profile_equal_except_vectors(
	source: Dictionary, changed: Dictionary, permutation: Dictionary, label: String
) -> void:
	_check(source.keys() == changed.keys(), "profile fields preserved: " + label)
	for key: String in source:
		if key not in ["stats", "base"]:
			_check(
				source[key] == changed[key],
				"identity/repertoire/mastery/capacity/provenance: " + label
			)
	for field: String in ["stats", "base"]:
		var original_values: Array = source[field].values()
		var changed_values: Array = changed[field].values()
		original_values.sort()
		changed_values.sort()
		_check(original_values == changed_values, "stat multiset preserved: " + label + ":" + field)
		var old_total: int = 0
		var new_total: int = 0
		for stat: String in SeasonPlayerCatalog.STATS:
			old_total += int(source[field][stat])
			new_total += int(changed[field][stat])
			_check(
				changed[field][stat] == source[field][permutation[stat]], "same mapping: " + label
			)
		_check(old_total == new_total, "exact vector total preserved: " + label + ":" + field)


func _context_and_isolation() -> void:
	var rules: Dictionary = LeagueRules.capture("scramble", 0, 117)
	var original_rules: Dictionary = rules.duplicate(true)
	var book: SeasonDevelopment = _book(rules)
	_check(book.enable_scramble(rules), "identical pre-event enable is idempotent")
	_check(not book.enable_scramble(LeagueRules.capture("scramble", 0, 118)), "immutable root seed")
	_check(not book.enable_scramble(LeagueRules.capture("standard")), "immutable league")
	_check(not book.context_matches({}), "Scramble cannot masquerade as empty context")
	_check(
		not book.context_matches(LeagueRules.capture("standard")),
		"Scramble rejects standard context"
	)
	_check(not book.context_matches(null), "invalid expected context rejected")
	rules.season_seed = 999
	_check(book.context_matches(original_rules), "enable copies caller rules")
	var snapshot: Dictionary = book.to_data()
	snapshot.league_rules.season_seed = 987
	snapshot.events.append({"op": "stat"})
	_check(
		book.context_matches(original_rules) and book.revision() == 0,
		"serialized data cannot mutate book"
	)
	var forked: SeasonDevelopment = book.fork()
	_check(forked.to_data() == book.to_data(), "fork preserves exact profile context")
	var initial: Dictionary = book.player(ALEX)
	_check(forked.commit(_command(forked, ALEX, "stat", "contact")).ok, "train isolated fork")
	_check(book.player(ALEX) == initial and book.revision() == 0, "fork player/event isolation")
	_check(not forked.enable_scramble(original_rules), "cannot re-enable after events")
	forked._league_rules.season_seed = 333
	_check(book.context_matches(original_rules), "fork context has no alias")
	var ordinary: SeasonDevelopment = SeasonDevelopment.new(SEASON)
	_check(ordinary.context_matches({}), "legacy empty context")
	for league: String in ["standard", "dugout", "academy", "equipment", "earnings", "sponsorship"]:
		_check(
			ordinary.context_matches(LeagueRules.capture(league)),
			"non-Scramble requires empty context"
		)
	_check(not ordinary.context_matches(original_rules), "legacy cannot satisfy Scramble context")
	_check(
		ordinary.recruit_profile(ALEX, "early") == RecruitCatalog.fresh(ALEX, "early"),
		"ordinary fresh recruits unchanged"
	)
	_check(ordinary.commit(_command(ordinary, ALEX, "stat", "contact")).ok, "ordinary training")
	var before: Dictionary = ordinary.to_data()
	_check(
		not ordinary.enable_scramble(original_rules) and ordinary.to_data() == before,
		"no enabling after ordinary training"
	)
	_check(not SeasonDevelopment.new().enable_scramble(original_rules), "no context without season")


func _recruit_development() -> void:
	var rules: Dictionary = LeagueRules.capture("scramble", 0, 117)
	for stage: String in RecruitCatalog.STAGES:
		var book: SeasonDevelopment = _book(rules)
		for player_id: String in SeasonPlayerCatalog.ids():
			var command: Dictionary = _command(book, player_id, "recruit", stage)
			var before: Dictionary = book.player(player_id)
			var preview: Dictionary = book.preview(command)
			var expected: Dictionary = SeasonScramble.fresh(player_id, stage, rules)
			_check(preview.ok and preview.after == expected, "all48 stage recruit previews")
			_check(book.player(player_id) == before, "recruit preview is inert")
			_check(
				book.commit(command).ok and book.player(player_id) == expected,
				"all48 stage recruit applications"
			)
			var after: Dictionary = book.to_data()
			_check(
				book.commit(command).replayed and book.to_data() == after,
				"retry never double-permutes"
			)
			_reject(
				book,
				_command(book, player_id, "recruit", stage),
				"new recruit reapplication rejected"
			)
			_reject(
				book,
				_command(book, player_id, "recruit", "late"),
				"later catchup cannot replace recruit"
			)
		_check(
			book.earned_players(SeasonPlayerCatalog.ids()).is_empty(),
			"catchup is not earned training"
		)
		_check(SeasonRetraining.count(book) == 0, "catchup cannot fund Retraining Camp")
		var restored: SeasonDevelopment = SeasonDevelopment.from_data(
			JSON.parse_string(JSON.stringify(book.to_data())), SEASON, rules
		)
		_check(restored != null, "all48 stage recruit journal replays")
		if restored != null:
			for player_id: String in SeasonPlayerCatalog.ids():
				_check(
					restored.player(player_id) == book.player(player_id),
					"replay preserves recruit vector"
				)
	var trained: SeasonDevelopment = _book(rules)
	_check(
		trained.commit(_command(trained, ROWAN, "stat", "contact")).ok,
		"pre-recruit player training"
	)
	_reject(
		trained,
		_command(trained, ROWAN, "recruit", "early"),
		"trained initial cannot receive catchup"
	)
	var returning: SeasonDevelopment = _book(rules)
	_check(
		returning.commit(_command(returning, ALEX, "recruit", "middle")).ok,
		"returning fixture recruit"
	)
	var baseline: Dictionary = returning.player(ALEX).base.duplicate(true)
	_check(
		returning.commit(_command(returning, ALEX, "stat", "power")).ok,
		"returning fixture training"
	)
	_check(
		returning.player(ALEX).base == baseline, "training never changes transformed authored base"
	)
	_check(
		returning.earned_players([ALEX]) == [ALEX] and SeasonRetraining.count(returning) == 1,
		"only paid stat event produces earned growth"
	)
	var preserved: Dictionary = returning.player(ALEX)
	_reject(
		returning,
		_command(returning, ALEX, "recruit", "late"),
		"trained returning recruit not rerandomized"
	)
	_check(
		returning.fork().player(ALEX) == preserved, "returning fork preserves exact trained profile"
	)
	var restored: SeasonDevelopment = SeasonDevelopment.from_data(
		returning.to_data(), SEASON, rules
	)
	_check(
		restored != null and restored.player(ALEX) == preserved,
		"returning replay preserves exact trained profile"
	)
	_reject(returning, _command(returning, ROWAN, "recruit", "unknown"), "invalid stage is atomic")


func _replay_contract() -> void:
	var rules: Dictionary = LeagueRules.capture("scramble", 0, 117)
	var book: SeasonDevelopment = _book(rules)
	_check(book.commit(_command(book, ALEX, "recruit", "late")).ok, "replay recruit fixture")
	_check(book.commit(_command(book, ALEX, "stat", "power")).ok, "replay training fixture")
	var data: Dictionary = JSON.parse_string(JSON.stringify(book.to_data()))
	_check(
		(
			data.version == 2
			and data.size() == 5
			and data.league_rules.size() == 5
			and LeagueRules.normalized(data.league_rules) == rules
		),
		"strict version2 standalone header"
	)
	var restored: SeasonDevelopment = SeasonDevelopment.from_data(data, SEASON, rules)
	_check(
		restored != null and restored.to_data() == book.to_data(),
		"JSON replay retains frozen context"
	)
	if restored != null:
		data.events[0].target = "early"
		data.league_rules.season_seed = 991
		_check(restored.to_data() == book.to_data(), "JSON input cannot alias replayed book")
	data = book.to_data()
	_check(SeasonDevelopment.from_data(data, SEASON) == null, "Scramble requires expected context")
	_check(
		SeasonDevelopment.from_data(data, SEASON, {}) == null,
		"empty expected context rejects Scramble"
	)
	_check(
		SeasonDevelopment.from_data(data, SEASON, LeagueRules.capture("standard")) == null,
		"wrong expected league rejects Scramble"
	)
	_check(
		SeasonDevelopment.from_data(data, SEASON, LeagueRules.capture("scramble", 0, 118)) == null,
		"wrong expected root seed rejected"
	)
	_check(
		SeasonDevelopment.from_data(data, "another-season", rules) == null,
		"cross-season replay rejected"
	)
	var malformed: Dictionary = data.duplicate(true)
	malformed.erase("league_rules")
	_check(
		SeasonDevelopment.from_data(malformed, SEASON, rules) == null,
		"stripped version2 context rejected"
	)
	malformed.version = 1
	_check(
		SeasonDevelopment.from_data(malformed, SEASON, rules) == null,
		"downgraded stripped header rejected"
	)
	malformed = data.duplicate(true)
	malformed.version = 1
	_check(
		SeasonDevelopment.from_data(malformed, SEASON, rules) == null,
		"version1 with Scramble header rejected"
	)
	for value: Variant in [0, 3, 1.5, true, "2", null]:
		malformed = data.duplicate(true)
		malformed.version = value
		_check(
			SeasonDevelopment.from_data(malformed, SEASON, rules) == null,
			"invalid save version rejected"
		)
	for field: String in ["players", "shop_seed", "baseline"]:
		malformed = data.duplicate(true)
		malformed[field] = {}
		_check(
			SeasonDevelopment.from_data(malformed, SEASON, rules) == null,
			"no authoritative side blob " + field
		)
	for bad_rules: Variant in [{}, null, [], LeagueRules.capture("standard")]:
		malformed = data.duplicate(true)
		malformed.league_rules = bad_rules
		_check(
			SeasonDevelopment.from_data(malformed, SEASON, rules) == null,
			"invalid embedded context rejected"
		)
	malformed = data.duplicate(true)
	malformed.events.append(malformed.events[0].duplicate(true))
	_check(
		SeasonDevelopment.from_data(malformed, SEASON, rules) == null,
		"duplicate saved request rejected"
	)
	malformed = data.duplicate(true)
	var repeated: Dictionary = malformed.events[0].duplicate(true)
	repeated.id = "new-recruit-attempt"
	repeated.rev = malformed.events.size()
	malformed.events.append(repeated)
	_check(
		SeasonDevelopment.from_data(malformed, SEASON, rules) == null,
		"saved recruit reapplication rejected"
	)
	malformed = data.duplicate(true)
	malformed.events[0].rev = 0.5
	_check(
		SeasonDevelopment.from_data(malformed, SEASON, rules) == null,
		"fractional event revision rejected"
	)
	malformed = data.duplicate(true)
	malformed.catalog = "changed"
	_check(
		SeasonDevelopment.from_data(malformed, SEASON, rules) == null,
		"authored catalog signature enforced"
	)
	var ordinary: SeasonDevelopment = SeasonDevelopment.new(SEASON)
	_check(ordinary.commit(_command(ordinary, ALEX, "stat", "contact")).ok, "legacy replay fixture")
	var legacy: Dictionary = ordinary.to_data()
	_check(
		legacy.version == 1 and legacy.size() == 4 and not legacy.has("league_rules"),
		"legacy version1 shape unchanged"
	)
	var old: SeasonDevelopment = SeasonDevelopment.from_data(
		JSON.parse_string(JSON.stringify(legacy)), SEASON
	)
	_check(old != null and old.player(ALEX) == ordinary.player(ALEX), "legacy replay unchanged")
	_check(
		SeasonDevelopment.from_data(legacy, SEASON, rules) == null,
		"legacy cannot import into Scramble"
	)
	_check(
		SeasonDevelopment.from_data(legacy, SEASON, LeagueRules.capture("standard")) != null,
		"legacy accepts matching empty non-Scramble context"
	)
	_check(
		SeasonDevelopment.from_data(legacy, SEASON, null) == null, "null expected context invalid"
	)


func _book(rules: Dictionary) -> SeasonDevelopment:
	var book: SeasonDevelopment = SeasonDevelopment.new(SEASON)
	_check(book.enable_scramble(rules), "enable immutable Scramble before events")
	return book


func _command(book: SeasonDevelopment, player_id: String, op: String, target: String) -> Dictionary:
	return {
		"id": "scramble:%d" % book.revision(),
		"rev": book.revision(),
		"player": player_id,
		"op": op,
		"target": target
	}


func _reject(book: SeasonDevelopment, command: Dictionary, message: String) -> void:
	var before: Dictionary = book.to_data()
	var before_player: Dictionary = book.player(command.player)
	_check(
		(
			not book.commit(command).ok
			and book.to_data() == before
			and book.player(command.player) == before_player
		),
		message
	)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

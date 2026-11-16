extends Node
## Actual whole production contract/lineage with explicit authored semantic fixtures.
## No Build capture, earned provenance, access-v2, Owner/save or physical gameplay claim.

const Profile = preload("res://src/gameplay/season/dynasty_profile_contract.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const ALEX: String = "player.alex_finch"
const ASH: String = "player.ash_cole"
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


static func cold(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


static func base_profile() -> Dictionary:
	# The required source enum is schema data only, never asserted to prove a real replay.
	var roster: Array[String] = [ALEX, "player.ari_banks", ASH, "player.rowan_chase"]
	var players: Dictionary = {}
	for id: String in roster:
		var authored: Dictionary = SeasonPlayerCatalog.profile(id)
		var zeros: Dictionary = {}
		for stat: String in SeasonPlayerCatalog.STATS:
			zeros[stat] = 0
		var mastery_zeros: Dictionary = {}
		var known: Dictionary = {}
		for recipe: String in authored.mastery:
			mastery_zeros[recipe] = 0
			known[recipe] = {"source_season": "authored", "kind": "authored", "receipt": recipe}
		players[id] = {
			"authored": {"stats": authored.stats.duplicate(),
				"mastery": authored.mastery.duplicate(), "capacity": authored.capacity},
			"stats": authored.stats.duplicate(), "active": authored.active.duplicate(),
			"mastery": authored.mastery.duplicate(), "trained": zeros.duplicate(),
			"catchup": {"origin": {}, "stats": zeros.duplicate(),
				"mastery": mastery_zeros.duplicate()},
			"earned_mastery": mastery_zeros.duplicate(), "known_origin": known,
			"active_learning": {}, "abilities": [], "temporary_fielding_slots": 1,
			"ever_earned": false}
	return Profile.normalize({"version": 1, "lineage_id": "dynasty-fixture", "owner_id": "human",
		"season_ordinal": 1, "seed": 10901, "rule": Profile.rule(),
		"source": {"season_key": "dynasty-fixture:1", "seed": 10901,
			"build_revision": 0, "catalog": SeasonPlayerCatalog.signature(),
			"authority": "build-replay"}, "roster": roster, "players": players})


static func semantic_profile() -> Dictionary:
	# Explicit semantic-offline checkpoint fixture, not a replayed paid source.
	var value: Dictionary = cold(base_profile())
	if value.is_empty():
		return {}
	var alex: Dictionary = value.players[ALEX]
	alex.catchup.origin = RecruitCatalog.fresh(ALEX, "late").catchup
	for row: Array in [["contact", 3, 0], ["power", 1, 0], ["fielding", 1, 1], ["pitching", 2, 3]]:
		alex.trained[row[0]] = row[1]
		alex.catchup.stats[row[0]] = row[2]
		alex.stats[row[0]] = alex.authored.stats[row[0]] + row[1] + row[2]
	alex.ever_earned = true
	var eephus: String = SeasonPlayerCatalog.RECIPES.E
	alex.earned_mastery[eephus] = 2
	alex.catchup.mastery[eephus] = 1
	alex.mastery[eephus] = 5
	for row: Array in [[SeasonPlayerCatalog.RECIPES.R, 3], [SeasonPlayerCatalog.RECIPES.D, 0]]:
		var recipe: String = row[0]
		alex.mastery[recipe] = 1 + row[1]
		alex.earned_mastery[recipe] = row[1]
		alex.catchup.mastery[recipe] = 0
		alex.known_origin[recipe] = {
			"source_season": "dynasty-fixture:1", "kind": "learn", "receipt": "lesson:" + recipe
		}
	alex.active.append(SeasonPlayerCatalog.RECIPES.D)
	alex.active_learning[SeasonPlayerCatalog.RECIPES.D] = {
		"source_season": "dynasty-fixture:1", "receipt": "lesson:" + SeasonPlayerCatalog.RECIPES.D
	}
	for item: String in [Profile.ABILITY_HANDS, Profile.ABILITY_COUNT, Profile.ABILITY_SKY]:
		alex.abilities.append(
			{
				"source_season": "dynasty-fixture:1",
				"id": "ability:" + item,
				"item": item,
				"slot": Profile.ABILITY_ITEMS[item].slot,
				"paid": Profile.ABILITY_ITEMS[item].price
			}
		)
	alex.temporary_fielding_slots = 2
	var ash: Dictionary = value.players[ASH]
	ash.catchup.origin = RecruitCatalog.fresh(ASH, "middle").catchup
	ash.catchup.stats.pitching = 2
	ash.stats.pitching += 2
	return Profile.normalize(value)


static func overflow_choice(item: String = Profile.ABILITY_HANDS) -> Dictionary:
	return {ALEX: {"player": "", "forget": "ability:" + item}}


func _ready() -> void:
	var profile: Dictionary = semantic_profile()
	check(not profile.is_empty(), "explicit bounded semantic fixture validates")
	if not profile.is_empty():
		_decay(profile)
		_lifecycle(profile)
		_negatives(profile)
		_cold_transactions(profile)
	print("Dynasty contract lifecycle checks: %d, failures: %d, synthetic=true, Owner=false"
		% [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _decay(profile: Dictionary) -> void:
	check(
		Profile.decay(profile).is_empty(), "F09 overflow fails closed without explicit forgetting"
	)
	for forgotten: String in [Profile.ABILITY_HANDS, Profile.ABILITY_SKY]:
		var projected: Dictionary = Profile.decay(profile, overflow_choice(forgotten))
		check(not projected.is_empty(), "either exact existing Fielding receipt may be forgotten")
		if projected.is_empty():
			continue
		var alex: Dictionary = projected.profile.players[ALEX]
		check(
			alex.trained.pitching == 0 and alex.catchup.stats.pitching == 3,
			"mixed growth loses paid first"
		)
		check(
			alex.trained.fielding == 0 and alex.catchup.stats.fielding == 0,
			"remaining drop consumes catch-up after paid"
		)
		check(
			alex.trained.contact == 1 and alex.stats.power == alex.authored.stats.power,
			"two per stat, not two total; near-floor clips"
		)
		check(
			(
				projected.profile.players[ASH].stats.pitching
				== profile.players[ASH].authored.stats.pitching
			),
			"catch-up-only stat also decays"
		)
		check(
			(
				alex.mastery[SeasonPlayerCatalog.RECIPES.E] == 4
				and alex.mastery[SeasonPlayerCatalog.RECIPES.R] == 3
			),
			"active and inactive upgraded mastery decay once"
		)
		check(
			(
				alex.mastery[SeasonPlayerCatalog.RECIPES.D] == 1
				and alex.active == profile.players[ALEX].active
			),
			"learned floor and ordered repertoire persist"
		)
		check(
			(
				alex.active_learning == profile.players[ALEX].active_learning
				and not alex.active_learning.has(SeasonPlayerCatalog.RECIPES.R)
			),
			"inactive remembered recipe receives no active exchange right"
		)
		check(
			alex.abilities.size() == 2 and alex.temporary_fielding_slots == 1,
			"explicit forgetting grants no free extra slot or reserve"
		)
		check(
			projected.changes[ALEX].forgotten[0].receipt.id == "ability:" + forgotten,
			"original ability identity/price provenance retained"
		)
		var current: Dictionary = projected.profile
		for index in range(5):
			current = Profile.decay(current).profile
		check(
			current.players[ALEX].mastery[SeasonPlayerCatalog.RECIPES.E] == 2,
			"Alex authored E2 floor survives repeated seasons"
		)
		check(
			current.players[ALEX].mastery[SeasonPlayerCatalog.RECIPES.R] == 1,
			"inactive learned recipe remains known at floor1"
		)


func _lifecycle(profile: Dictionary) -> void:
	var initial: Dictionary = Lineage.create(profile)
	check(not initial.is_empty(), "single owner lineage initialized")
	var common: Dictionary = {}
	for outcome: String in ["win", "loss", "abandon"]:
		var closed: Dictionary = Lineage.close(initial, outcome)
		check(
			closed.current_profile == profile and closed.pending_replacement.is_empty(),
			"close retains roster, no decay or replacement credit: " + outcome
		)
		var paused: Dictionary = Lineage.pause(closed)
		check(Profile.same(Lineage.resume(paused), closed), "pause/resume exact closed lineage")
		for forgotten: String in [Profile.ABILITY_HANDS, Profile.ABILITY_SKY]:
			var request: Dictionary = Lineage.request_for(
				closed, "rollover:1", 200, overflow_choice(forgotten)
			)
			var result: Dictionary = Lineage.advance(closed, request)
			check(
				not result.is_empty() and not result.replayed,
				"committed next season: " + outcome + "/" + forgotten
			)
			if result.is_empty():
				continue
			check(
				not Lineage.normalize(cold(result.lineage)).is_empty(),
				"cold rollover validates original ability order"
			)
			var repeated: Dictionary = Lineage.advance(Lineage.pause(result.lineage), request)
			check(
				(
					not repeated.is_empty()
					and repeated.replayed
					and repeated.lineage.state == "paused"
				),
				"rollover retry remains inert across pause"
			)
			var altered: Dictionary = request.duplicate(true)
			altered.target_seed += 1
			check(
				Lineage.advance(result.lineage, altered).is_empty(),
				"same rollover ID with changed seed rejects"
			)
			altered = request.duplicate(true)
			altered.id = "another-roll"
			check(
				Lineage.advance(Lineage.close(result.lineage, "abandon"), altered).is_empty(),
				"old source generation cannot roll again under new ID"
			)
			if forgotten == Profile.ABILITY_HANDS:
				if common.is_empty():
					common = result.lineage.current_profile
				check(
					Profile.same(result.lineage.current_profile, common),
					"same formula for all outcome labels"
				)
	check(
		Profile.same(Lineage.resume(Lineage.pause(initial)), initial),
		"leaving and returning preserves active same lineage"
	)


func _negatives(profile: Dictionary) -> void:
	var bad: Dictionary = cold(profile)
	bad.players[ALEX].trained.contact += 1
	check(Profile.normalize(bad).is_empty(), "unbalanced surviving training rejects")
	bad = cold(profile)
	bad.players[ALEX].abilities[0].paid = 0
	check(Profile.normalize(bad).is_empty(), "altered paid ability provenance rejects")
	bad = cold(profile)
	bad.players[ALEX].active_learning[SeasonPlayerCatalog.RECIPES.R] = {
		"source_season": "dynasty-fixture:1", "receipt": "inactive"
	}
	check(Profile.normalize(bad).is_empty(), "inactive exchange entitlement rejects")
	bad = cold(profile)
	bad.players[ALEX].stats.contact += 0.00001
	check(Profile.normalize(bad).is_empty(), "fractional stats reject before canonicalization")
	bad = cold(profile)
	bad.rule.allocation = "catchup-first"
	check(Profile.normalize(bad).is_empty(), "alternate allocation cannot relabel frozen candidate")
	bad = cold(profile)
	bad.roster[1] = bad.roster[0]
	check(Profile.normalize(bad).is_empty(), "duplicate owner identity rejects")
	bad = cold(profile)
	bad.players["player.gray_west"] = bad.players[ALEX]
	check(Profile.normalize(bad).is_empty(), "non-rostered archive rejects")
	bad = cold(profile)
	bad.players[ALEX].active_learning.clear()
	check(
		not Profile.normalize(bad).is_empty(),
		"nonauthored active recipe does not automatically imply exchange acquisition"
	)
	check(
		Profile.decay(profile, {ALEX: {"player": "", "forget": "absent"}}).is_empty(),
		"wrong ability receipt rejects"
	)
	for origin_key: String in ["foreign:1", "dynasty-fixture:2", "authored"]:
		bad = cold(profile)
		bad.players[ALEX].abilities[0].source_season = origin_key
		check(
			Profile.normalize(bad).is_empty(),
			"foreign/future ability origin rejects: " + origin_key
		)
		bad = cold(profile)
		bad.players[ALEX].active_learning[SeasonPlayerCatalog.RECIPES.D].source_season = origin_key
		check(
			Profile.normalize(bad).is_empty(),
			"foreign/future active learning origin rejects: " + origin_key
		)
		bad = cold(profile)
		bad.players[ALEX].known_origin[SeasonPlayerCatalog.RECIPES.R].source_season = origin_key
		check(
			Profile.normalize(bad).is_empty(),
			"foreign/future remembered recipe origin rejects: " + origin_key
		)
	for malformed: Variant in [42, {}, false, null]:
		for field: String in ["state", "resume_state", "closed_reason"]:
			bad = cold(Lineage.pause(Lineage.create(profile)))
			bad[field] = malformed
			check(Lineage.normalize(bad).is_empty(), "wrong lifecycle type rejects: " + field)
	bad = cold(profile)
	bad.players[ALEX].active = [SeasonPlayerCatalog.RECIPES.OF]
	bad.players[ALEX].active_learning.clear()
	check(Profile.normalize(bad).is_empty(), "repertoire cannot shrink below authored count")
	bad = cold(profile)
	bad.players["player.ari_banks"].abilities.append(bad.players[ALEX].abilities[0].duplicate(true))
	check(
		Profile.normalize(bad).is_empty(),
		"one paid ability acquisition cannot be cloned across players"
	)
	bad = cold(profile)
	var drop: String = SeasonPlayerCatalog.RECIPES.D
	bad.players[ASH].active.append(drop)
	bad.players[ASH].mastery[drop] = 1
	bad.players[ASH].earned_mastery[drop] = 0
	bad.players[ASH].catchup.mastery[drop] = 0
	bad.players[ASH].known_origin[drop] = bad.players[ALEX].known_origin[drop].duplicate(true)
	bad.players[ASH].active_learning[drop] = bad.players[ALEX].active_learning[drop].duplicate(true)
	check(
		Profile.normalize(bad).is_empty(),
		"active learned acquisition cannot be cloned across players"
	)



func _cold_transactions(profile: Dictionary) -> void:
	check(Profile.same(Profile.normalize(cold(profile)), profile), "cold semantic profile exact")
	check(profile.is_read_only() and profile.players.is_read_only()
		and profile.players[ALEX].stats.is_read_only(), "normalized contract recursively frozen")
	var initial: Dictionary = Lineage.create(profile)
	var paused: Dictionary = cold(Lineage.pause(initial))
	check(Profile.same(Lineage.resume(paused), initial), "cold paused active resume exact")
	var closed: Dictionary = cold(Lineage.close(initial, "win"))
	check(Profile.same(Lineage.close(closed, "win"), closed), "same close is idempotent")
	var request: Dictionary = Lineage.request_for(closed, "cold-next", 271, overflow_choice())
	var result: Dictionary = Lineage.advance(closed, cold(request))
	check(not result.is_empty(), "JSON request advances actual lineage")
	if result.is_empty():
		return
	var saved: Dictionary = cold(result.lineage)
	var retry: Dictionary = Lineage.advance(saved, cold(request))
	check(not retry.is_empty() and retry.replayed
		and Profile.same(retry.lineage, saved), "cold exact retry applies no second decay")
	check(saved.generation == 1 and saved.ordinal == 2 and saved.current_profile.seed == 271
		and saved.current_profile.roster == profile.roster, "next generation retains roster and seed")
	var forged: Dictionary = cold(saved)
	forged.last_transition.changes[ALEX].stats.contact.after.paid += 1
	check(Lineage.normalize(forged).is_empty(), "cold changed decay receipt refuses")
	forged = cold(request)
	forged.overflow_choices = overflow_choice(Profile.ABILITY_SKY)
	check(Lineage.advance(saved, forged).is_empty(), "same request ID cannot change forgotten receipt")
	check(Lineage.advance(Lineage.pause(closed), request).is_empty(),
		"paused closed lineage cannot start new generation")

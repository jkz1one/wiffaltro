class_name LeagueRules
extends RefCounted
## Closed staging profiles. Registry presence never grants career admission.

const ValueContract = preload("res://src/gameplay/season/club_value_contract.gd")
const JournalContract = preload("res://src/gameplay/season/club_asset_journal.gd")
const VERSION: int = 1
const SCRAMBLE_VERSION: int = 2
const TIER_VERSION: int = 3
const DYNASTY_TIER_VERSION: int = 4
const TIER_PROFILE: String = "league-cumulative-standard-v1"
const SCRAMBLE_PROFILE: String = "league-scramble-stat-permutation-v1"
const IDS: Array[String] = [
	"standard",
	"dynasty",
	"sponsorship",
	"dugout",
	"academy",
	"doubleheader",
	"equipment",
	"earnings",
	"scramble"
]
const PROFILE: String = "league-base-capacity-v1"
# Adjustable playtest candidate. Any future rate change requires a new profile ID.
const EQUIPMENT_PROFILE: String = "league-equipment-spare-candidate-carry1-v1"
const ACADEMY_PROFILE: String = "league-academy-two-pick-candidate-12-v1"
const EARNINGS_PROFILE: String = "league-earnings-margin-candidate-15-10-24-v1"
const SPONSORSHIP_PROFILE: String = "league-sponsorship-candidate-16-10-v1"
const DYNASTY_PROFILE: String = "league-dynasty-compact-start-paid-first-v1"
const DOUBLEHEADER_PROFILE: String = "league-doubleheader-candidate-sweep6-v1"


static func capture(league: String, tier: int = 0, season_seed: Variant = null) -> Dictionary:
	if tier != 0:
		return {}
	if league == "scramble":
		if not _seed_valid(season_seed):
			return {}
		return {
			"version": SCRAMBLE_VERSION,
			"league": league,
			"tier": 0,
			"profile": SCRAMBLE_PROFILE,
			"season_seed": int(season_seed)
		}
	if (
		(
			league
			not in [
				"standard",
				"dugout",
				"sponsorship",
				"earnings",
				"academy",
				"equipment",
				"doubleheader",
				"dynasty"
			]
		)
		or season_seed != null
	):
		return {}
	var profile: String = (
		{
			"equipment": EQUIPMENT_PROFILE,
			"academy": ACADEMY_PROFILE,
			"earnings": EARNINGS_PROFILE,
			"sponsorship": SPONSORSHIP_PROFILE,
			"doubleheader": DOUBLEHEADER_PROFILE,
			"dynasty": DYNASTY_PROFILE
		}
		. get(league, PROFILE)
	)
	return {"version": VERSION, "league": league, "tier": tier, "profile": profile}


static func normalized(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("league") is String:
		return {}
	# JSON parses integral numbers as floats; Array.has/in is type-sensitive.
	if _integer(value.get("version"), TIER_VERSION) \
		or _integer(value.get("version"), DYNASTY_TIER_VERSION):
		return _normalized_tier(value)
	var is_scramble: bool = value.league == "scramble"
	var fields: Array[String] = ["version", "league", "tier", "profile"]
	if is_scramble:
		fields.append("season_seed")
	if value.size() != fields.size():
		return {}
	for key: String in fields:
		if not value.has(key):
			return {}
	if (
		not _integer(value.version, SCRAMBLE_VERSION if is_scramble else VERSION)
		or not _integer(value.tier, 0)
		or not value.profile is String
	):
		return {}
	var expected: Dictionary = capture(value.league, 0, value.get("season_seed"))
	return expected if not expected.is_empty() and value.profile == expected.profile else {}


static func capture_tier(league: String, tier: int, season_seed: Variant = null) -> Dictionary:
	if tier == 0:
		return capture(league, 0, season_seed)
	if tier not in [1, 2, 3, 4] or league == "standard":
		return {}
	var result: Dictionary = capture(league, 0, season_seed)
	if result.is_empty():
		return {}
	result.version = DYNASTY_TIER_VERSION if league == "dynasty" else TIER_VERSION
	result.tier = tier
	result["difficulty_profile"] = TIER_PROFILE
	return result


static func _normalized_tier(value: Dictionary) -> Dictionary:
	if not ValueContract.whole(value.get("tier"), 1, 4):
		return {}
	var expected: Dictionary = capture_tier(
		value.league, int(value.tier), value.get("season_seed")
	)
	if expected.is_empty() or not JournalContract.keys(value, expected.keys()):
		return {}
	return expected if JournalContract.same(value, expected) else {}


static func tiered(value: Variant) -> bool:
	var rules: Dictionary = normalized(value)
	return not rules.is_empty() and rules.version in [TIER_VERSION, DYNASTY_TIER_VERSION]


static func scramble(value: Variant) -> bool:
	var rules: Dictionary = normalized(value)
	return not rules.is_empty() and rules.league == "scramble"


static func season_matches(value: Variant, seed_value: Variant) -> bool:
	var rules: Dictionary = normalized(value)
	return (
		not rules.is_empty()
		and (
			rules.league != "scramble"
			or (_seed_valid(seed_value) and int(seed_value) == rules.season_seed)
		)
	)


static func _seed_valid(value: Variant) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and value >= 0
		and value <= 2147483647
	)


static func capacities(value: Variant) -> Dictionary:
	var rules: Dictionary = normalized(value)
	if rules.is_empty():
		return {}
	return {
		"held": 1 if rules.league == "equipment" else (3 if rules.league == "dugout" else 2),
		"sponsors": 6 if rules.league == "sponsorship" else 5
	}


static func sponsorship(value: Variant) -> bool:
	var rules: Dictionary = normalized(value)
	return not rules.is_empty() and rules.league == "sponsorship"


static func equipment(value: Variant) -> bool:
	var rules: Dictionary = normalized(value)
	return not rules.is_empty() and rules.league == "equipment"


static func academy(value: Variant) -> bool:
	var rules: Dictionary = normalized(value)
	return not rules.is_empty() and rules.league == "academy"


static func doubleheader(value: Variant) -> bool:
	var rules: Dictionary = normalized(value)
	return not rules.is_empty() and rules.league == "doubleheader"


static func earnings(value: Variant) -> bool:
	var rules: Dictionary = normalized(value)
	return not rules.is_empty() and rules.league == "earnings"


static func final_scores_valid(own: Variant, opponent: Variant, win: Variant) -> bool:
	if not win is bool:
		return false
	for score: Variant in [own, opponent]:
		if (
			not (score is int or score is float)
			or not is_finite(float(score))
			or float(score) != floor(float(score))
			or score < 0
			or score > 9999
		):
			return false
	return own != opponent and win == (own > opponent)


static func game_income(
	value: Variant, win: bool, own: Variant = null, opponent: Variant = null
) -> int:
	var rules: Dictionary = normalized(value)
	if rules.is_empty():
		return -1
	if rules.league == "earnings":
		return (
			clampi(15 + int(own) - int(opponent), 10, 24)
			if final_scores_valid(own, opponent, win)
			else -1
		)
	return (16 if win else 10) if rules.league == "sponsorship" else (18 if win else 12)


static func public_activation_enabled(_league: String) -> bool:
	# Existing Standard admission remains exclusively owned by ClubCareer.
	# No profile in this staging registry may activate a new public route.
	return false


static func _integer(value: Variant, expected: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) == float(expected)
	)


static func dynasty(value: Variant) -> bool:
	var rules: Dictionary = normalized(value)
	return not rules.is_empty() and rules.league == "dynasty"

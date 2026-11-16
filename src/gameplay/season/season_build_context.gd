extends RefCounted
## Private inherited state and immutable league/pricing context for SeasonBuild.

const _WRAP_V6_SOURCE_PINS: Dictionary = {
	"src/gameplay/season/expanded_season_progression.gd":
	"e4ed317f366f714691c47d991f052078c114aa9c308aa8cf49f1d1fd83a0e01d",
	"src/gameplay/pitching/expanded_season_catalog.gd":
	"cb1ff9e70025ce4166ce38edcc1aa4d2790767ad13c505a36800280fd6cd2fb0",
	"src/gameplay/pitching/working_pitch_catalog_v6.gd":
	"0e709f6bda6fa95a8fa7cc666ad31354cc223633c8c0782254adeb8d16820dff",
	"src/gameplay/pitching/working_pitch_catalog.gd":
	"6285ae5b772796bedbf50a56cc7d47142bd7a2e656aef85efef1c215ff67c33c",
}

const _CONTEXT_DYNASTY_PROFILE_SCRIPT_PATH: String = (
	"res://src/gameplay/season/dynasty_start_profile.gd"
)

const _CONTEXT_VERSION: int = 41
const _CONTEXT_D1_VERSION: int = 42
const _CONTEXT_D3_VERSION: int = 43
const _CONTEXT_D4_VERSION: int = 44
const _CONTEXT_LEAGUE_VERSION: int = 45
const _CONTEXT_LEAGUE_TIER_VERSION: int = 46
const _LEAGUE_TIER_ECONOMY = preload("res://src/gameplay/season/league_tier_economy.gd")
const _CONTEXT_D1_PRICE_RULE: String = "standard-d1-reroll-v1"
const _DYNASTY_CONTRACT = preload("res://src/gameplay/season/dynasty_profile_contract.gd")
const _CONTEXT_MAX_EVENTS: int = _DYNASTY_CONTRACT.BUILD_MAX_EVENTS
const _CONTEXT_SHOP_OPS: Array[String] = [
	"open",
	"leave_shop",
	"lesson_pair",
	"wholesale",
	"tactical_buy",
	"ability_buy",
	"retrain_buy",
	"major_assign",
	"tactical_exchange",
	"buy",
	"use",
	"discard",
	"reroll",
	"focused_reroll",
	"transfer_pitch",
	"reserve_offer",
	"release_reservation",
	"pack_open",
	"pack_pick",
	"pack_skip",
	"sign",
	"equip",
	"sell_gear",
	"spare_buy",
	"spare_swap",
	"sponsor_buy",
	"sponsor_sell"
]

var last_error: String = ""
var _seed: int
var _roster: Array[String] = []
var _initial_roster: Array[String] = []
var _pool: Array[String] = []
var _blocked: Array[String] = []
var _contracts: Dictionary = {}
var _recruits: Array[Dictionary] = []
var _game_rosters: Dictionary = {}
var _appeared: bool = false
var _format: int = _CONTEXT_VERSION
# Exact historical display-name provenance for Build41+ replay, not a saved grant.
var _legacy_gap_name: bool = false
var _market: int = 0
var _league_rules: Dictionary = {}
var _dynasty_start: Dictionary = {}
var _pricing_rule: String = ""
var _sponsor_rule: String = ""
var _retraining_enabled: bool = true
var _gear_progress: SeasonGearProgress = SeasonGearProgress.new()
var _sponsor_progress: SeasonSponsorProgress = SeasonSponsorProgress.new()
var _legends: Dictionary = {}
var _order_start: Variant = null
var _paid_rerolls: int = 0
var _rain_start: Variant = null
var _rain_earned: bool = false
var _transfer_start: Variant = null
var _transfer_earned: bool = false
var _checkout_start: Variant = null
var _checkout_earned: bool = false
var _association_start: Variant = null
var _freezer_start: Variant = null
var _sides_start: Variant = null
var _major: SeasonDoubleMajor = SeasonDoubleMajor.new()
var _abilities: SeasonAbilities = SeasonAbilities.new()
var _copy: SeasonCarbonCopy = SeasonCarbonCopy.new()
var _field_start: Variant = null
var _field_outs: int = 0
var _sure_start: Variant = null
var _sure_earned: bool = false
var _jump_start: Variant = null
var _batch_start: Variant = null
var _batch_used: Array = []
var _association_earned: bool = false
var _freezer_earned: bool = false
var _sides_earned: bool = false
var _jump_earned: bool = false
var _supply_start: Variant = null
var _supply_used: int = 0
var _insurance: Dictionary = {}
var _reservation: Dictionary = {}
var _recruit_from: int = 1
var _gear_from: int = 1
var _misc_from: int = 1
var _mapped_gear_from: int = 1
var _sponsor_from: int = 1
var _gameplay_sponsor_from: int = 1
var _sequence_sponsor_from: int = 1
var _field_sponsor_from: int = 1
var _shop_sponsor_from: int = 1
var _school_sponsor_from: int = 1
var _anchor_sponsor_from: int = 1
var _wholesale_from: int = 1
var _tactical_from: int = 1
var _expanded_tactical_from: int = 1
var _tactical_sponsor_from: int = 1
var _budget_from: int = 1
var _film_from: int = 1
var _scouts: Dictionary = {}
var _pregames: Dictionary = {}
var _match_inventory: Dictionary = {}
var _scholarships: Dictionary = {}
var _used_gear: Dictionary = {}
var _income_by_game: Dictionary = {}
var _bank: SeasonOwnership
var _book: SeasonDevelopment
var _visit: Dictionary = {"number": 0, "open": false}
var _events: Array[Dictionary] = []
var _requests: Dictionary = {}



func enable_league_rules(value: Variant) -> bool:
	if _book != null and _book._pitch_catalog_version == ExpandedSeasonCatalog.VERSION:
		return false
	var rules: Dictionary = LeagueRules.normalized(value)
	if (
		rules.is_empty()
		or not _events.is_empty()
		or not _requests.is_empty()
		or int(_visit.number) != 0
		or _market not in [0, 12]
	):
		return false
	if _format in [_CONTEXT_LEAGUE_VERSION, _CONTEXT_LEAGUE_TIER_VERSION]:
		return league_context_valid() and _league_rules == rules
	if _format != _CONTEXT_VERSION or not pricing_context_valid():
		return false
	var next_book: SeasonDevelopment = _book.fork()
	if (
		(LeagueRules.scramble(rules) and not next_book.enable_scramble(rules))
		or (LeagueRules.dynasty(rules) and not next_book.enable_dynasty(rules))
		or not next_book.context_matches(rules)
	):
		return false
	var tiered: bool = _LEAGUE_TIER_ECONOMY.tier(rules) > 0
	var next_bank: SeasonOwnership = _bank.fork() if tiered else _bank
	var bank_ready: bool = (
		next_bank.enable_league_tier(rules, _seed) if tiered
		else (int(rules.tier) == 0 and next_bank.enable_league_rules(rules))
	)
	if not bank_ready:
		return false
	_book = next_book
	_bank = next_bank
	_format = _CONTEXT_LEAGUE_TIER_VERSION if tiered else _CONTEXT_LEAGUE_VERSION
	_pricing_rule = _CONTEXT_D1_PRICE_RULE if tiered else ""
	_sponsor_rule = _LEAGUE_TIER_ECONOMY.sponsor_rule(rules) if tiered else ""
	_league_rules = rules.duplicate(true)
	return true


func league_context_valid() -> bool:
	var rules: Dictionary = LeagueRules.normalized(_league_rules)
	var base: bool = _format == _CONTEXT_LEAGUE_VERSION and not rules.is_empty() \
		and int(rules.tier) == 0 and _pricing_rule.is_empty() and _sponsor_rule.is_empty() \
		and _bank._format == SeasonOwnership.LEAGUE_VERSION
	var composed: bool = _format == _CONTEXT_LEAGUE_TIER_VERSION \
		and _pricing_rule == _CONTEXT_D1_PRICE_RULE \
		and _LEAGUE_TIER_ECONOMY.valid(rules, _sponsor_rule, _seed) \
		and _bank._format == SeasonOwnership.LEAGUE_TIER_VERSION \
		and _bank._sponsor_rule == _sponsor_rule and _bank._term_seed == _seed
	return (
		(base or composed)
		and _market in [0, 12]
		and _bank.league_rules_valid()
		and _bank._league_rules == _league_rules
		and _book != null
		and _book.context_matches(_league_rules)
		and dynasty_context_valid()
	)


func dynasty_context_valid() -> bool:
	if not LeagueRules.dynasty(_league_rules):
		return _dynasty_start.is_empty() and _book._dynasty_start.is_empty()
	if not ClubCareer.same(_dynasty_start, _book._dynasty_start):
		return false
	if _dynasty_start.is_empty():
		return true
	var profile: Dictionary = (
		preload(_CONTEXT_DYNASTY_PROFILE_SCRIPT_PATH).normalize(_dynasty_start)
	)
	return (
		not profile.is_empty()
		and String(profile.lineage_id).length() <= 152
		and _market == 0
		and profile.seed == _seed
		and profile.roster == _initial_roster
	)


func enable_dynasty_start(value: Variant) -> bool:
	if (
		not LeagueRules.dynasty(_league_rules)
		or _market != 0
		or revision() != 0
		or not _requests.is_empty()
		or _bank.revision() != 0
		or not _dynasty_start.is_empty()
	):
		return false
	var profile: Dictionary = (
		preload(_CONTEXT_DYNASTY_PROFILE_SCRIPT_PATH).normalize(value)
	)
	if (
		profile.is_empty()
		or String(profile.lineage_id).length() > 152
		or profile.seed != _seed
		or profile.roster != _initial_roster
	):
		return false
	for id: String in profile.roster:
		if profile.players[id].temporary_fielding_slots != 1:
			return false
	var book: SeasonDevelopment = _book.fork()
	if not book.enable_dynasty(_league_rules, profile):
		return false
	var abilities: SeasonAbilities = _abilities.fork()
	for id: String in profile.roster:
		abilities.learned[id] = []
		for row: Dictionary in profile.players[id].abilities:
			var receipt: Dictionary = row.duplicate(true)
			receipt.erase("source_season")
			abilities.learned[id].append(receipt)
	_book = book
	_abilities = abilities
	_dynasty_start = profile
	return dynasty_context_valid()


# Working d1 pricing is an immutable journal header, never a mid-run toggle.
func enable_d1_pricing() -> bool:
	if _book != null and _book._pitch_catalog_version == ExpandedSeasonCatalog.VERSION:
		return false
	if not _events.is_empty() or not _requests.is_empty() or int(_visit.number) != 0:
		return false
	if d1_pricing_valid():
		return true
	if _format != _CONTEXT_VERSION or not pricing_context_valid() or _market not in [0, 12]:
		return false
	_format = _CONTEXT_D1_VERSION
	_pricing_rule = _CONTEXT_D1_PRICE_RULE
	return true


func enable_d3_sponsors() -> bool:
	if _book != null and _book._pitch_catalog_version == ExpandedSeasonCatalog.VERSION:
		return false
	if (
		not _events.is_empty()
		or not _requests.is_empty()
		or int(_visit.number) != 0
		or _bank.revision() != 0
	):
		return false
	if d3_sponsors_valid():
		return true
	if (
		_format not in [_CONTEXT_VERSION, _CONTEXT_D1_VERSION]
		or not pricing_context_valid()
		or _market not in [0, 12]
		or not SeasonOwnership._whole(_seed, 0, 2147483647)
	):
		return false
	# Prepare all inherited context on a detached bank. Failure changes nothing.
	var bank: SeasonOwnership = _bank.fork()
	if not bank.enable_sponsor_terms(SeasonSponsorCatalog.D3_RULE, _seed):
		return false
	_format = _CONTEXT_D3_VERSION
	_pricing_rule = _CONTEXT_D1_PRICE_RULE
	_sponsor_rule = SeasonSponsorCatalog.D3_RULE
	_bank = bank
	return true


func enable_d4_sponsors() -> bool:
	if _book != null and _book._pitch_catalog_version == ExpandedSeasonCatalog.VERSION:
		return false
	if (
		not _events.is_empty()
		or not _requests.is_empty()
		or int(_visit.number) != 0
		or _bank.revision() != 0
	):
		return false
	if d4_sponsors_valid():
		return true
	if (
		_format not in [_CONTEXT_VERSION, _CONTEXT_D1_VERSION]
		or not pricing_context_valid()
		or _market not in [0, 12]
		or not SeasonOwnership._whole(_seed, 0, 2147483647)
	):
		return false
	var bank: SeasonOwnership = _bank.fork()
	if not bank.enable_sponsor_terms(SeasonSponsorCatalog.D4_RULE, _seed):
		return false
	_format = _CONTEXT_D4_VERSION
	_pricing_rule = _CONTEXT_D1_PRICE_RULE
	_sponsor_rule = SeasonSponsorCatalog.D4_RULE
	_bank = bank
	return true


func d4_sponsors_valid() -> bool:
	if _format == _CONTEXT_LEAGUE_TIER_VERSION:
		return league_context_valid() and _bank.d4_sponsors_valid()
	return (
		_format == _CONTEXT_D4_VERSION
		and _pricing_rule == _CONTEXT_D1_PRICE_RULE
		and _sponsor_rule == SeasonSponsorCatalog.D4_RULE
		and _market in [0, 12]
		and SeasonOwnership._whole(_seed, 0, 2147483647)
		and _bank.d4_sponsors_valid()
		and _bank._sponsor_rule == _sponsor_rule
		and _bank._term_seed == _seed
	)


func d3_sponsors_valid() -> bool:
	if _format == _CONTEXT_LEAGUE_TIER_VERSION:
		return league_context_valid() and _bank.sponsor_terms_valid()
	return (
		_format == _CONTEXT_D3_VERSION
		and _pricing_rule == _CONTEXT_D1_PRICE_RULE
		and _sponsor_rule == SeasonSponsorCatalog.D3_RULE
		and _market in [0, 12]
		and SeasonOwnership._whole(_seed, 0, 2147483647)
		and _bank.sponsor_terms_valid()
		and _bank._sponsor_rule == _sponsor_rule
		and _bank._term_seed == _seed
	)


func d1_pricing_valid() -> bool:
	if _format == _CONTEXT_LEAGUE_TIER_VERSION:
		return league_context_valid()
	return (
		d4_sponsors_valid()
		or d3_sponsors_valid()
		or (
			_format == _CONTEXT_D1_VERSION
			and _pricing_rule == _CONTEXT_D1_PRICE_RULE
			and _market in [0, 12]
			and _sponsor_rule.is_empty()
			and _bank._format == SeasonOwnership.VERSION
			and _bank.context_valid()
		)
	)


func pricing_context_valid() -> bool:
	if _format in [_CONTEXT_LEAGUE_VERSION, _CONTEXT_LEAGUE_TIER_VERSION]:
		return league_context_valid()
	if (
		not _league_rules.is_empty()
		or not _dynasty_start.is_empty()
		or _book == null
		or not _book.context_matches({})
	):
		return false
	return (
		d1_pricing_valid()
		or (
			_format >= 1
			and _format <= _CONTEXT_VERSION
			and _pricing_rule.is_empty()
			and _sponsor_rule.is_empty()
			and _bank._format == SeasonOwnership.VERSION
			and _bank.context_valid()
		)
	)


func reroll_price() -> int:
	if not pricing_context_valid():
		return -1
	var payable: int = SeasonReclamation.price(_visit)
	return payable + 1 if d1_pricing_valid() and payable > 0 else payable


func revision() -> int:
	return _events.size()


static func _wrap_v6_supported(data: Dictionary) -> bool:
	if typeof(data.get("version")) != TYPE_INT or data.version != 41 \
		or typeof(data.get("market")) != TYPE_INT or data.market not in [0, 12] \
		or data.has("league_rules") or data.has("dynasty_start") \
		or not data.get("catalog") is String:
		return false
	for path: String in _WRAP_V6_SOURCE_PINS:
		if FileAccess.get_sha256("res://" + path) != _WRAP_V6_SOURCE_PINS[path]:
			return false
	return true

static func _wrap_v6(data: Dictionary) -> Dictionary:
	if not _wrap_v6_supported(data):
		return ExpandedSeasonProgression.wrap_build(data)
	var result: Dictionary = data.duplicate(true)
	result["exotic_start"] = []
	result["base_version"] = data.version
	result.version = ExpandedSeasonProgression.BUILD_VERSION
	var catalog_signature: String = ExpandedSeasonCatalog.signature()
	if catalog_signature.is_empty():
		return ExpandedSeasonProgression.wrap_build(data)
	result["pitch_catalog"] = catalog_signature
	result["catalog_context"] = {"version": ExpandedSeasonCatalog.VERSION,
		"signature": catalog_signature, "purpose": ExpandedSeasonCatalog.PURPOSE}
	result.catalog = (
		"expanded-season-progression-v6:" + data.catalog + ":" + catalog_signature
	).sha256_text()
	return result


static func _wrap_v6_owner(owner: Variant, data: Dictionary) -> Dictionary:
	if owner.get_script() != load("res://src/gameplay/season/season_build.gd"):
		return ExpandedSeasonProgression.wrap_build(data)
	var book: Variant = owner._book
	if book == null or book.get_script() != load("res://src/gameplay/season/season_development.gd"):
		return ExpandedSeasonProgression.wrap_build(data)
	if owner._format != 41 or owner._market not in [0, 12] \
		or not owner._league_rules.is_empty() or not owner._dynasty_start.is_empty() \
		or not book._dynasty_start.is_empty() or not book._exotic_start.is_empty():
		return ExpandedSeasonProgression.wrap_build(data)
	return _wrap_v6(data)

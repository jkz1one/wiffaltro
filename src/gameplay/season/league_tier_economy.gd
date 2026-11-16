extends RefCounted
## Immutable composition of authored League rules and the approved cumulative tier economy.

const PROFILE: String = "league-tier-economy-v1"
const PRICING_RULE: String = "standard-d1-reroll-v1"


static func tier(value: Variant) -> int:
	var rules: Dictionary = LeagueRules.normalized(value)
	if rules.is_empty() or rules.league == "standard":
		return -1
	return int(rules.tier) if SeasonOwnership._whole(rules.tier, 1, 4) else -1


static func sponsor_rule(value: Variant) -> String:
	var level: int = tier(value)
	if level == 4:
		return SeasonSponsorCatalog.D4_RULE
	return SeasonSponsorCatalog.D3_RULE if level == 3 else ""


static func valid(value: Variant, rule: String, seed_value: Variant) -> bool:
	return tier(value) > 0 and SeasonOwnership._whole(seed_value, 0, 2147483647) \
		and rule == sponsor_rule(value)

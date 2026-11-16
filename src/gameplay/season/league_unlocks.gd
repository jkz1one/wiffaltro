extends RefCounted
## Public entry policy, derived from validated settled championship history.
## Never used to reinterpret an existing save, immutable rules, or paused session.

const IDS: Array[String] = ["standard", "dugout", "sponsorship", "academy",
	"equipment", "earnings", "doubleheader", "scramble", "dynasty"]
const LEAGUE_WINS: Dictionary = {"sponsorship": "standard", "academy": "sponsorship",
	"equipment": "dugout", "earnings": "equipment"}
const TIER_WINS: Dictionary = {"doubleheader": 1, "scramble": 2, "dynasty": 3}


static func from_titles(titles: Dictionary) -> Array[String]:
	# Callers first validate their complete career/owner history. These keys are
	# the existing title namespace, not user-provided claims or unlocked flags.
	var result: Array[String] = []
	for league: String in IDS:
		if league in ["standard", "dugout"]:
			result.append(league)
		elif LEAGUE_WINS.has(league) and _won_league(titles, LEAGUE_WINS[league]):
			result.append(league)
		elif TIER_WINS.has(league) and _won_tier(titles, int(TIER_WINS[league])):
			result.append(league)
	return result


static func _won_league(titles: Dictionary, league: String) -> bool:
	for tier in range(5):
		if titles.get(_key(league, tier), false) == true:
			return true
	return false


static func _won_tier(titles: Dictionary, tier: int) -> bool:
	for league: String in IDS:
		if titles.get(_key(league, tier), false) == true:
			return true
	return false


static func _key(league: String, tier: int) -> String:
	return str(tier) if league == "standard" else "%s:%d" % [league, tier]


static func requirement(league: String) -> String:
	if league in ["standard", "dugout"]:
		return "Available from the start."
	if LEAGUE_WINS.has(league):
		return "Win a championship in %s." % String(LEAGUE_WINS[league]).capitalize()
	if TIER_WINS.has(league):
		return "Win a tier %d championship in any League." % int(TIER_WINS[league])
	return "Unknown League."

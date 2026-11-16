extends RefCounted
## Candidate League career admission. Public availability is a separate decision.
## Dynasty keeps its existing persistent owner/lineage and is never reset here.

const VERSION: int = 27
const IDS: Array[String] = [
	"dugout", "sponsorship", "academy", "doubleheader", "equipment", "earnings", "scramble"
]


static func rules_valid(value: Variant, seed_value: Variant) -> bool:
	var rules: Dictionary = LeagueRules.normalized(value)
	return (
		not rules.is_empty()
		and rules.league in IDS
		and LeagueRules.season_matches(rules, seed_value)
	)


static func title_key(league: String, tier: int) -> String:
	return str(tier) if league == "standard" else "%s:%d" % [league, tier]


static func row_valid(row: Dictionary) -> bool:
	if not row.get("proof") is Dictionary:
		return false
	if row.get("league") == "dynasty":
		# Only owner-coordinated closed history uses this extra binding. Career27's
		# strict row keys still reject it; it cannot enter ordinary fresh-start saves.
		var context: Dictionary = preload("res://src/gameplay/season/dynasty_career_save.gd").binding(
			row.get("dynasty_session"))
		return not context.is_empty() and context.league == "dynasty" \
			and context.seed == row.get("seed") and row.get("tier") == context.tier \
			and row.get("league_rules", {}).get("tier") == context.tier \
			and LeagueRules.dynasty(row.get("league_rules")) \
			and ClubCareer.same(row.proof.get("league_rules"), row.league_rules)
	if row.get("league") == "standard":
		return not row.has("league_rules") and not row.proof.has("league_rules")
	return (
		rules_valid(row.get("league_rules"), row.get("seed"))
		and SeasonOwnership._whole(row.get("tier"), 0, 4)
		and row.tier == row.league_rules.tier
		and row.league == row.league_rules.league
		and ClubCareer.same(row.proof.get("league_rules"), row.league_rules)
	)


static func admitted(season: SeasonState) -> bool:
	if season == null or not season.league_career or season.career == null:
		return false
	return context_matches(season, season.career)


static func context_matches(season: SeasonState, club: ClubCareer) -> bool:
	if (
		season == null or club == null
		or club.current <= 0 or club.current != club.runs.size()
		or not row_valid(club.runs[-1])
		or club.runs[-1].seed != season.season_seed
		or club.runs[-1].status not in ["active", "completed"]
	):
		return false
	if club.runs[-1].league == "standard":
		return not season.league_career and season.league_rules.is_empty()
	return (
		season.league_career
		and rules_valid(season.league_rules, season.season_seed)
		and ClubCareer.same(club.runs[-1].league_rules, season.league_rules)
		and season._closed_access.is_empty()
		and season._dynasty_owner_binding.is_empty()
	)

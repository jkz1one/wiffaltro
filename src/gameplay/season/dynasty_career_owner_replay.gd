extends RefCounted
## Exact owner-v2 raw-family dispatch after full Save83/85 qualification.
## Raw snapshot bytes and versions are never rewritten for legacy admission.

const Legacy = preload("res://src/gameplay/season/dynasty_owner.gd")
const Ops = preload("res://src/gameplay/season/dynasty_owner_operations_1.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")


static func slot(
	session_id: String, reference: Dictionary, snapshot: Dictionary, season: SeasonState
) -> Dictionary:
	var result: Dictionary = Ops._slot(
		Legacy.fingerprint, frontier, session_id, reference, snapshot, season
	)
	if not LeagueRules.dynasty(season.league_rules):
		result.start_hash = Legacy.fingerprint(season._closed_access)
	return result


static func frontier(snapshot: Dictionary, season: SeasonState) -> Dictionary:
	var result: Dictionary = Ops._frontier(
		Save.core, Lineage, Legacy.fingerprint, Legacy._exit_ready, snapshot, season
	)
	var owned: bool = snapshot.version == Save.Owned.VERSION
	var raw: Dictionary = Save.Owned.unpack(snapshot).checkpoint if owned else snapshot
	if raw.version != Save.RAW_TIER_VERSION and not owned:
		return result
	# The old helper includes access for raw80 only. Bind the new raw84 access
	# and exact captured tier rules explicitly, alongside unchanged journal keys.
	var core: Dictionary = Save.core(snapshot)
	var header: Dictionary = {}
	for key: String in ["version", "seed", "pool", "draws"]:
		header[key] = core[key]
	var opponents: Dictionary = core.opponents.duplicate()
	opponents.erase("clubs")
	opponents.erase("draft_order")
	header["opponents"] = opponents
	header["access"] = raw.access
	if raw.version == Save.RAW_TIER_VERSION:
		header["raw_version"] = Save.RAW_TIER_VERSION
		header["tier_rules"] = season.league_rules
	if owned:
		header["owned_wrapper"] = Save.Owned.VERSION
		header["player_access"] = season.player_access
		header["owned_draft"] = raw.checkpoint.owned_draft
	result.header_hash = Legacy.fingerprint(header)
	return result


static func extends_checkpoint(
	before: Dictionary, after: Dictionary, prior_frontier: Dictionary
) -> bool:
	return Ops._extends(
		Save.core, Legacy._prefix, Lineage, Legacy._pending_extends, before, after, prior_frontier
	)

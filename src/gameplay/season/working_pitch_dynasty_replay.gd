extends RefCounted
## Exact owner-v2 raw-family dispatch after full Save83/85 qualification.
## Raw snapshot bytes and versions are never rewritten for legacy admission.

const Legacy = preload("res://src/gameplay/season/dynasty_owner.gd")
const Ops = preload("res://src/gameplay/season/dynasty_owner_operations_1.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Save = preload("res://src/gameplay/season/working_pitch_dynasty_save.gd")


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
	# Current raw header commits its complete catalog/profile/access context.
	var unpacked: Dictionary = Save.parts(snapshot)
	if unpacked.is_empty():
		return {}
	var core: Dictionary = unpacked.data
	var header: Dictionary = {}
	for key: String in ["version", "seed", "pool", "draws"]:
		header[key] = core[key]
	var opponents: Dictionary = core.opponents.duplicate()
	opponents.erase("clubs")
	opponents.erase("draft_order")
	header["opponents"] = opponents
	header["access"] = unpacked.raw.access
	header["pitch_catalog"] = snapshot.pitch_catalog
	header["raw_version"] = Save.VERSION
	header["tier_rules"] = season.league_rules
	header["start_profile"] = unpacked.start
	result.header_hash = Legacy.fingerprint(header)
	return result


static func extends_checkpoint(
	before: Dictionary, after: Dictionary, prior_frontier: Dictionary
) -> bool:
	return Ops._extends(
		Save.core, Legacy._prefix, Lineage, Legacy._pending_extends, before, after, prior_frontier
	)

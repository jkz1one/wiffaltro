extends RefCounted
## Save81 adds mixed League history without reinterpreting any closed checkpoint.
## The contained season retains its existing replay format and exact rules.

const ClubLeagueCareer = preload("res://src/gameplay/season/club_league_career.gd")

const Owned = preload("res://src/gameplay/season/league_owned_draft_save.gd")

const VERSION: int = 81
const TIER_CHECKPOINT_VERSION: int = 82


static func wrap(value: Dictionary) -> Dictionary:
	if value.is_empty():
		return {}
	var payload: Dictionary = value
	while payload.get("checkpoint") is Dictionary:
		payload = payload.checkpoint
	var career: Variant = payload.get("career")
	if not career is Dictionary or career.get("version") != ClubLeagueCareer.VERSION:
		return value
	# Snapshot owns this newly constructed dictionary, never an accepted save.
	payload.erase("career")
	return {"version": VERSION, "career": career, "checkpoint": value}


static func contains_mixed_career(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var payload: Dictionary = value
	for depth in range(4):
		if payload.get("career") is Dictionary and \
			payload.career.get("version") == ClubLeagueCareer.VERSION:
			return true
		if not payload.get("checkpoint") is Dictionary:
			break
		payload = payload.checkpoint
	return false


static func decode(value: Dictionary, player_access: Array = []) -> SeasonState:
	if (
		not SeasonOwnership._keys(value, ["version", "career", "checkpoint"])
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or not value.career is Dictionary
		or value.career.get("version") != ClubLeagueCareer.VERSION
		or not value.checkpoint is Dictionary
		or not SeasonOwnership._whole(value.checkpoint.get("version"), 4, TIER_CHECKPOINT_VERSION)
		or contains_mixed_career(value.checkpoint)
	):
		return null
	var career: ClubCareer = ClubCareer.from_data(value.career)
	if career == null:
		return null
	var checkpoint: Dictionary = value.checkpoint.duplicate(true)
	if int(checkpoint.version) <= 74:
		if checkpoint.has("career") or not player_access.is_empty():
			return null
		checkpoint["career"] = value.career.duplicate(true)
		# Only this new envelope admits Career27 to the retained Standard replay.
		return SeasonSave._ac02_passive_15_private_decode(checkpoint)
	if career.current <= 0 or career.current != career.runs.size():
		return null
	var inventory: Dictionary = {}
	if checkpoint.version == 78:
		if (
			not SeasonOwnership._keys(checkpoint, ["version", "inventory_rules", "checkpoint"])
			or not SeasonInventoryRules.valid(checkpoint.inventory_rules)
			or not checkpoint.checkpoint is Dictionary
		):
			return null
		inventory = checkpoint.inventory_rules
		checkpoint = checkpoint.checkpoint
	if not Owned.version_in(checkpoint.get("version"), [76, 77, TIER_CHECKPOINT_VERSION]):
		return null
	# Career authority is supplied only by this validated new envelope. Replay
	# attaches it at the normal career-validation join, before earned-access checks.
	return SeasonSave._decode_closed_league(checkpoint, inventory, null, {}, career, player_access)

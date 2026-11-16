extends RefCounted
## Exact admission-time eligibility witness, independent of sequential history.
## A witness is NEVER authority by itself. Every use requires the caller's
## qualified admission-time authority (current owner for admission; replayed
## historical owner for restore). Do not normalize a supplied witness as a grant.
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const VERSION: int = 2
const OWNER_HISTORY_VERSION: int = 3
const FIELDS: Array[String] = ["version", "owner_id", "authority_reference",
	"history_reference", "assets_reference", "access", "player_access", "history"]


static func capture(qualified_authority: Dictionary) -> Dictionary:
	var authority: Dictionary = Authority.normalize(qualified_authority)
	if authority.is_empty():
		return {}
	var players: Dictionary = Authority.player_view(authority)
	var access: Dictionary = Authority.access(authority)
	if players.is_empty() or access.is_empty():
		return {}
	var club: ClubCareer = Authority._history(authority)
	var history: Dictionary = history_data(club)
	var result: Dictionary = {"version": OWNER_HISTORY_VERSION if history.version == 28 else VERSION, "owner_id": authority.owner_id,
		"authority_reference": Save.snapshot_reference(authority),
		"history_reference": Save.snapshot_reference(history), "history": history,
		"assets_reference": Save.snapshot_reference(authority.assets),
		"access": access.duplicate(true), "player_access": players.owned.duplicate()}
	for field: String in ["authority_reference", "history_reference", "assets_reference"]:
		if not Authority._reference_valid(result[field]):
			return {}
	return result


static func qualify(witness: Variant, qualified_authority: Dictionary) -> Dictionary:
	if not Profile.keys(witness, FIELDS) or not Profile.whole(witness.version, VERSION, OWNER_HISTORY_VERSION) \
		or not Profile.token(witness.owner_id) or not ClubPlayerCatalog.valid_ids(witness.player_access) \
		or ClosedContentAccess.normalize(witness.access).is_empty():
		return {}
	for field: String in ["authority_reference", "history_reference", "assets_reference"]:
		if not Authority._reference_valid(witness[field]):
			return {}
	var expected: Dictionary = capture(qualified_authority)
	if expected.is_empty() or _claim(witness).is_empty() or not ClubCareer.same(witness, expected):
		return {}
	# Return only newly derived values, never caller-controlled aliases.
	Profile.freeze(expected)
	return expected


static func _claim(witness: Variant) -> Dictionary:
	# Consistency only. Caller must obtain this exact value from replay-qualified
	# owner state; never use a file-supplied claim as authorization.
	if not Profile.keys(witness, FIELDS) or not Profile.whole(witness.version, VERSION, OWNER_HISTORY_VERSION) \
		or not Profile.token(witness.owner_id) or not ClubPlayerCatalog.valid_ids(witness.player_access):
		return {}
	if not witness.history is Dictionary:
		return {}
	var access: Dictionary = ClosedContentAccess.normalize(witness.access)
	var history: ClubCareer = history_club(witness.history)
	if (witness.version == OWNER_HISTORY_VERSION) != (witness.history.get("version") == 28) \
		or access.is_empty() or history == null or history.current != 0 \
		or access.owner_id != witness.owner_id:
		return {}
	for row: Dictionary in history.runs:
		if row.has("dynasty_session") and row.dynasty_session.owner_id != witness.owner_id:
			return {}
	for field: String in ["authority_reference", "history_reference", "assets_reference"]:
		if not Authority._reference_valid(witness[field]):
			return {}
	if not ClubCareer.same(witness.history_reference, Save.snapshot_reference(history_data(history))) \
		or not ClubCareer.same(witness.assets_reference, Save.snapshot_reference(history._assets)):
		return {}
	var result: Dictionary = witness.duplicate(true)
	result.history = history_data(history)
	result.access = access
	Profile.freeze(result)
	return result


static func matches_start(
	season: SeasonState, witness: Variant, qualified_authority: Dictionary
) -> bool:
	var grant: Dictionary = qualify(witness, qualified_authority)
	return not grant.is_empty() and season != null and season.league_rules.is_empty() \
		and ClosedContentAccess.matches(season.build, grant.access) \
		and ClubCareer.same(season.player_access, grant.player_access) \
		and ClubPlayerDraft.frozen_matches(season)


static func history_data(club: ClubCareer) -> Dictionary:
	var result: Dictionary = club.to_data()
	for row: Dictionary in club.runs:
		if row.has("dynasty_session"):
			result.version = 28
			break
	return result


static func history_club(value: Variant) -> ClubCareer:
	if value is Dictionary and value.get("version") == 28:
		return ClubCareer.from_owner_history(value)
	return ClubCareer.from_data(value)

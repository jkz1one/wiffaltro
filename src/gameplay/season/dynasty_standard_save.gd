extends RefCounted
## Explicit Standard session envelope, separately qualified against its admission
## authority or a fixed committed owner witness. Public dispatch requires a bound
## owner; UI activation and pending physical rounds remain gated.
const VERSION: int = 88
const LIVE_VERSION: int = 89
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Delta = preload("res://src/gameplay/season/dynasty_standard_progress.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const FIELDS: Array[String] = ["owner_id", "lineage_id", "generation", "ordinal",
	"session_id", "seed", "tier", "league", "grant_sha256"]


static func binding(value: Variant) -> Dictionary:
	var fields: Array = FIELDS.duplicate()
	if value is Dictionary and value.has("format"):
		fields.append("format")
		if not Profile.whole(value.format, LIVE_VERSION, LIVE_VERSION):
			return {}
	if value is Dictionary and value.has("starting_profile"):
		fields.append("starting_profile")
		if not value.has("format") or not value.starting_profile is String \
			or value.starting_profile not in ["day", "sunset", "night"]:
			return {}
	if not Profile.keys(value, fields):
		return {}
	for field: String in ["owner_id", "lineage_id", "session_id"]:
		if not Profile.token(value[field]):
			return {}
	if not value.league is String or value.league != "standard" or not Profile.whole(value.generation, 0, Profile.MAX_ORDINAL - 1) \
		or not Profile.whole(value.ordinal, 1, Profile.MAX_ORDINAL) \
		or value.generation != value.ordinal - 1 \
		or not Profile.whole(value.seed, 0, 2147483647) \
		or not Profile.whole(value.tier, 0, 4) \
		or not ClosedContentAccess._digest_valid(value.grant_sha256):
		return {}
	var result: Dictionary = value.duplicate(true)
	for field: String in ["generation", "ordinal", "seed", "tier"]:
		result[field] = int(result[field])
	return result


static func binding_for(
	season: SeasonState, grant: Dictionary, owner_id: String, lineage_id: String,
	generation: int, ordinal: int, session_id: String
) -> Dictionary:
	if season == null or season.career == null or not season.league_rules.is_empty():
		return {}
	return binding({"owner_id": owner_id, "lineage_id": lineage_id,
		"generation": generation, "ordinal": ordinal, "session_id": session_id,
		"seed": season.season_seed, "tier": season.career.active_tier(),
		"league": "standard", "grant_sha256": Save.snapshot_reference(grant).sha256})


static func wrap_checkpoint(
	checkpoint: Dictionary, context: Dictionary, witness: Dictionary, admission: Dictionary
) -> Dictionary:
	var value: Dictionary = {"version": context.get("format", VERSION), "session": context.duplicate(true),
		"grant": witness.duplicate(true), "checkpoint": checkpoint.duplicate(true)}
	return value if not qualify(value, admission).is_empty() else {}


static func qualify(value: Variant, qualified_admission: Dictionary) -> Dictionary:
	var grant: Dictionary = Grant.qualify(value.get("grant") if value is Dictionary else null,
		qualified_admission)
	if grant.is_empty():
		return {}
	return _qualify_bound(value, binding(value.get("session")), grant)


static func _qualify_bound(
	value: Variant, expected_session: Dictionary, expected_grant: Dictionary
) -> Dictionary:
	# expected operands must come from replay-qualified owner state, never the
	# untrusted envelope itself. Public admission uses qualify above.
	if not Profile.keys(value, ["version", "session", "grant", "checkpoint"]) \
		or not Profile.whole(value.version, VERSION, LIVE_VERSION) \
		or not value.checkpoint is Dictionary \
		or Save.snapshot_reference(value).bytes > 8 * 1024 * 1024:
		return {}
	var context: Dictionary = binding(value.session)
	var grant: Dictionary = Grant._claim(expected_grant)
	if context.is_empty() or int(value.version) != int(context.get("format", VERSION)) or grant.is_empty() or context.owner_id != grant.owner_id \
		or context.grant_sha256 != Save.snapshot_reference(grant).sha256 \
		or not ClubCareer.same(value.grant, grant) \
		or not ClubCareer.same(context, binding(expected_session)):
		return {}

	# Never recursively dispatch our own envelope or a closed-league bound save.
	var raw_version: Variant = value.checkpoint.get("version")
	if SeasonOwnership._whole(raw_version, 81, 81):
		if not value.checkpoint.get("checkpoint") is Dictionary \
			or not SeasonOwnership._whole(value.checkpoint.checkpoint.get("version"), 59, 74):
			return {}
	elif not SeasonOwnership._whole(raw_version, 59, 74):
		return {}
	var season: SeasonState = _live().decode(value.checkpoint, grant, context) if int(value.version) == LIVE_VERSION \
		else SeasonSave._decode(value.checkpoint)
	if season == null or not season.league_rules.is_empty() or season.season_seed != context.seed:
		return {}
	if int(value.version) == VERSION and (season.career == null or season.career.active_tier() != context.tier):
		return {}
	var delta: Dictionary = Delta._capture_bound(season, grant)
	if delta.is_empty():
		return {}
	# Shared-asset mutations need their own owner transaction. A valid embedded
	# ordinary ledger cannot expand the admission-time owned field here.
	var prefix: ClubCareer = preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(grant.history)
	if not StadiumLayoutSnapshot.matches(season.home_property, ClubPlayers.assets(prefix)):
		return {}
	season._dynasty_career_session = context.duplicate(true)
	season._standard_bound_grant = grant.duplicate(true)
	return {"session": context, "grant": grant, "season": season, "inner": value.checkpoint,
		"contribution": delta, "reference": Save.snapshot_reference(value),
		"raw_reference": Save.snapshot_reference(value.checkpoint)}


static func capture(
	season: SeasonState, context: Dictionary, grant: Dictionary, admission: Dictionary
) -> Dictionary:
	return wrap_checkpoint(_raw(season, context), context, grant, admission)


static func _live() -> GDScript:
	return load("res://src/gameplay/season/dynasty_standard_live.gd")


static func _raw(season: SeasonState, context: Dictionary) -> Dictionary:
	if season == null:
		return {}
	if Profile.whole(context.get("format"), LIVE_VERSION, LIVE_VERSION):
		return _live().capture_raw(season)
	var detached: SeasonState = SeasonState.new()
	for property: Dictionary in season.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			detached.set(property.name, season.get(property.name))
	detached._dynasty_career_session = {}
	detached._dynasty_owner_binding = {}
	detached._standard_bound_grant = {}
	return SeasonSave.snapshot(detached)


static func _capture_bound(season: SeasonState) -> Dictionary:
	var context: Dictionary = binding(season._dynasty_career_session)
	var grant: Dictionary = Grant._claim(season._standard_bound_grant)
	if context.is_empty() or grant.is_empty():
		return {}
	var value: Dictionary = {"version": context.get("format", VERSION), "session": context,
		"grant": grant, "checkpoint": _raw(season, context)}
	return value if not _qualify_bound(value, context, grant).is_empty() else {}


static func decode_current(value: Dictionary) -> SeasonState:
	if not SeasonSave.dynasty_owner_bound():
		return null
	var found: Dictionary = SeasonSave.DYNASTY_OWNER_STORE.inspect(SeasonSave._dynasty_owner_path)
	var owner: Dictionary = found.get("owner", {})
	if found.get("status") not in ["ready", "recoverable"] or owner.get("version") != 2:
		return null
	var slot: Dictionary = owner.get(str(owner.get("selected", "")), {})
	if slot.is_empty() or not owner.get("career", {}).get("sessions", {}).has(slot.session_id):
		return null
	var entry: Dictionary = owner.career.sessions[slot.session_id]
	if not entry.has("standard_grant"):
		return null
	var checked: Dictionary = _qualify_bound(
		value, entry.session, entry.standard_grant)
	return checked.get("season")

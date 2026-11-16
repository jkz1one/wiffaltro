extends RefCounted
## Test-only95/96 authority and two-round frontier. Never grants or records progress.
const TimeHome = preload("res://src/gameplay/season/dynasty_shared_time.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const AUTHORITY_KEYS: Array[String] = ["version", "format", "source_profile", "input_sha256",
	"authored_prerequisites", "original_sha256", "admission_sha256", "header", "owner_id",
	"lineage_id", "origin", "assets", "settlements"]
const BOUNDARY_KEYS: Array[String] = ["version", "kind", "format", "source_profile", "authority_key",
	"save_sha256", "owner_sha256", "mirror_sha256", "owner_key", "owner_revision", "snapshot_key",
	"seed", "home", "policy", "results", "reports", "pending_reports", "pending"]

static func key(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

static func digest(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)

static func authority_shape(value: Variant) -> bool:
	if not SeasonOwnership._keys(value, AUTHORITY_KEYS) or not SeasonOwnership._whole(value.version, 1, 1) \
		or not Save.Owned.version_in(value.format, [95, 96]) or not value.authored_prerequisites is bool or value.authored_prerequisites != true \
		or not TimeHome.header_valid(value.header) or value.header.version != value.format \
		or value.header.starting_profile != "night" or value.header.owned_surface_night.version != 2 \
		or value.owner_id != value.header.session.owner_id or value.lineage_id != value.header.session.lineage_id:
		return false
	for field: String in ["source_profile", "input_sha256", "original_sha256", "admission_sha256", "origin", "assets", "settlements"]:
		if not digest(value[field]): return false
	return true

static func authority(season: SeasonState, owner: Dictionary, profile: String,
	input_sha: String, original_sha: String, admission_sha: String) -> Dictionary:
	if not TimeHome.matches(season): return {}
	var value: Dictionary = {"version": 1, "format": season._league_home_context.format,
		"source_profile": profile, "input_sha256": input_sha, "authored_prerequisites": true,
		"original_sha256": original_sha, "admission_sha256": admission_sha,
		"header": season._league_home_context.header.duplicate(true), "owner_id": owner.owner_id,
		"lineage_id": owner.lineage.id, "origin": key(owner.career.origin),
		"assets": key(owner.career.assets), "settlements": key(owner.career.settlements)}
	return value if authority_shape(value) else {}

static func binding_matches(binding: Dictionary, owner_path: String, revision: int, session_id: String) -> bool:
	return owner_path.is_absolute_path() and owner_path == owner_path.simplify_path() \
		and binding.get("path") == owner_path and binding.get("revision") == revision \
		and binding.get("session_id") == session_id

static func paused_matches(before: Dictionary, after: Dictionary, format: int) -> bool:
	if format not in [95, 96]: return false
	var paused: String = "other" if format == 96 else "dynasty"
	var prior: Dictionary = before.get(paused, {})
	var current: Dictionary = after.get(paused, {})
	if prior.is_empty() or not ClubCareer.same(prior, current): return false
	var id: String = prior.get("session_id", "")
	var prior_entry: Dictionary = before.get("career", {}).get("sessions", {}).get(id, {})
	var current_entry: Dictionary = after.get("career", {}).get("sessions", {}).get(id, {})
	return not prior_entry.is_empty() and ClubCareer.same(prior_entry, current_entry)

static func matches(value: Variant, season: SeasonState, owner: Dictionary, profile: String, owner_path: String) -> bool:
	if not authority_shape(value) or not TimeHome.matches(season) or owner.is_empty() \
		or value.source_profile != profile or value.owner_id != owner.get("owner_id") \
		or value.lineage_id != owner.get("lineage", {}).get("id") \
		or not ClubCareer.same(value.header, season._league_home_context.header): return false
	var selected: String = "dynasty" if value.format == 96 else "other"
	var id: String = value.header.session.session_id
	var entry: Dictionary = owner.career.sessions.get(id, {})
	return owner.selected == selected and owner[selected].session_id == id \
		and owner[selected].snapshot_version == value.format and entry.get("settled") == 0 \
		and ClubCareer.same(entry.get("time_home"), value.header) \
		and ClubCareer.same(entry.get("session"), value.header.session) \
		and ClubCareer.same(owner[selected].reference, Save.snapshot_reference(SeasonSave.snapshot(season))) \
		and binding_matches(season._dynasty_owner_binding, owner_path, int(owner.revision), id) \
		and season.career == null and not season.league_career and season.league_rules.tier == 0 \
		and season.league_rules.league == ("dynasty" if value.format == 96 else "dugout") \
		and value.origin == key(owner.career.origin) and value.assets == key(owner.career.assets) \
		and value.settlements == key(owner.career.settlements)

static func boundary_shape(value: Variant) -> bool:
	if not SeasonOwnership._keys(value, BOUNDARY_KEYS) or not SeasonOwnership._whole(value.version, 1, 1) \
		or not Save.Owned.version_in(value.format, [95, 96]) or not value.pending is bool \
		or not SeasonOwnership._whole(value.owner_revision, 1, 2147483647) \
		or not SeasonOwnership._whole(value.seed, 0, 2147483647): return false
	for field: String in ["source_profile", "authority_key", "save_sha256", "owner_sha256", "mirror_sha256", "owner_key", "snapshot_key", "home", "policy"]:
		if not digest(value[field]): return false
	if not SeasonOwnership._whole(value.results, 0, 2) or not SeasonOwnership._whole(value.reports, 0, 4) \
		or not SeasonOwnership._whole(value.pending_reports, 0, 2) or value.reports != value.results * 2: return false
	match value.kind:
		"enroll96", "resume96": return value.format == 96 and value.results == 0 and not value.pending and value.pending_reports == 0
		"alternate95": return value.format == 95 and value.results == 0 and not value.pending and value.pending_reports == 0
		"human": return value.results < 2 and value.pending and value.pending_reports == 0
		"ai": return value.results < 2 and value.pending and value.pending_reports in [1, 2]
		"publish": return value.results in [1, 2] and not value.pending and value.pending_reports == 0
	return false

static func frontier(kind: String, results: int, pending: bool, reports: int) -> bool:
	if results not in [0, 1] or reports not in [0, 1, 2]: return false
	match kind:
		"human": return not pending and reports == 0
		"ai": return pending and reports < 2
		"publish": return pending and reports == 2
	return false

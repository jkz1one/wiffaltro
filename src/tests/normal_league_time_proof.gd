extends RefCounted
## Harness-only94 authority/receipt schema. No gameplay, persistence or grants.
const TimeHome = preload("res://src/gameplay/season/normal_league_time_candidate.gd")
const FUNDING_SHA: String = "8bf9acd070679060c26065ae8045c70016c1e460ff920f1692a036e6c5da5fe1"
const AUTHORITY_KEYS: Array[String] = ["version", "format", "source_profile", "funding_sha256",
	"seed", "career_run", "prior_history_key", "header", "prepared_sha256"]
const BOUNDARY_KEYS: Array[String] = ["version", "kind", "source_profile", "authority_key",
	"save_sha256", "seed", "home", "policy", "results", "reports", "pending_reports", "pending"]

static func key(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

static func digest(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)

static func authority_shape(value: Variant) -> bool:
	return SeasonOwnership._keys(value, AUTHORITY_KEYS) and SeasonOwnership._whole(value.version, 1, 1) and SeasonOwnership._whole(value.format, 94, 94) \
		and digest(value.source_profile) and value.funding_sha256 == FUNDING_SHA \
		and SeasonOwnership._whole(value.seed, 0, 2147483647) \
		and SeasonOwnership._whole(value.career_run, 2, ClubCareer.MAX_RUNS) \
		and digest(value.prior_history_key) and digest(value.prepared_sha256) \
		and TimeHome._header_valid(value.header) and value.header.starting_profile == "night" \
		and value.header.owned_surface_night.version == 2 \
		and value.header.owned_surface_night.run_id == value.career_run \
		and value.header.owned_surface_night.season_seed == value.seed

static func authority(season: SeasonState, source_profile: String, prepared_sha: String) -> Dictionary:
	if not TimeHome.matches(season) or season.career == null:
		return {}
	var value: Dictionary = {"version": 1, "format": 94, "source_profile": source_profile,
		"funding_sha256": FUNDING_SHA, "seed": season.season_seed,
		"career_run": season.career.current, "prior_history_key": key(season.career.runs.slice(0, -1)),
		"header": season._league_home_context.header.duplicate(true), "prepared_sha256": prepared_sha}
	return value if authority_shape(value) else {}

static func matches(value: Variant, season: SeasonState, source_profile: String) -> bool:
	return authority_shape(value) and season != null and TimeHome.matches(season) \
		and season.career != null and season.career.current == value.career_run \
		and season.career.runs.size() == value.career_run and season.season_seed == value.seed \
		and season.league_rules.get("league") == "dugout" and season.league_rules.get("tier") == 0 \
		and value.source_profile == source_profile and season._dynasty_career_session.is_empty() \
		and season._dynasty_owner_binding.is_empty() \
		and ClubCareer.same(value.header, season._league_home_context.header) \
		and value.prior_history_key == key(season.career.runs.slice(0, -1))

static func boundary_shape(value: Variant) -> bool:
	if not SeasonOwnership._keys(value, BOUNDARY_KEYS) or not SeasonOwnership._whole(value.version, 1, 1) \
		or value.kind not in ["start", "human", "ai", "publish"] \
		or not value.pending is bool or not SeasonOwnership._whole(value.seed, 0, 2147483647):
		return false
	for field: String in ["source_profile", "authority_key", "save_sha256", "home", "policy"]:
		if not digest(value[field]): return false
	if not SeasonOwnership._whole(value.results, 0, 2) \
		or not SeasonOwnership._whole(value.reports, 0, 4) \
		or not SeasonOwnership._whole(value.pending_reports, 0, 2) \
		or value.reports != value.results * 2:
		return false
	match value.kind:
		"start": return value.results == 0 and not value.pending and value.pending_reports == 0
		"human": return value.results < 2 and value.pending and value.pending_reports == 0
		"ai": return value.results < 2 and value.pending and value.pending_reports in [1, 2]
		"publish": return value.results in [1, 2] and not value.pending and value.pending_reports == 0
	return false

static func frontier(kind: String, results: int, pending: bool, reports: int) -> bool:
	# Every invocation does at most one game or zero-game publication.
	if results not in [0, 1] or reports not in [0, 1, 2]: return false
	match kind:
		"human": return not pending and reports == 0
		"ai": return pending and reports < 2
		"publish": return pending and reports == 2
	return false

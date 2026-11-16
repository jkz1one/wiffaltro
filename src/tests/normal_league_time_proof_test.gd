extends "res://src/tests/normal_league_time_test.gd"
## Focused synthetic harness controls, not physical evidence or new earned history.
const Proof = preload("res://src/tests/normal_league_time_proof.gd")
const Journal = preload("res://src/tests/normal_league_proof_journal.gd")

func _ready() -> void:
	if OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") != "1" or not StadiumNpcPublicRuntime.source_qualified():
		get_tree().quit(2)
		return
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--time94-proof-root="): root = arg.trim_prefix("--time94-proof-root=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root) or FileAccess.file_exists(root):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	var source: SeasonState = _retained_funding()
	_check(source != null, "retained authored prerequisites decode for harness controls")
	if source != null:
		var ordinary: SeasonState = _ordinary(source)
		var season: SeasonState = NormalTime.admit(ordinary, "night") if ordinary != null else null
		_check(season != null, "real94 header prepared without playing a game")
		if season != null:
			var profile: String = FileAccess.get_sha256("res://src/presentation/stadium/stadium_npc_current_source_profile.gd")
			var authority: Dictionary = Proof.authority(season, profile, "a".repeat(64))
			_check(Proof.matches(authority, season, profile), "exact94 full header/policy/history authority")
			for field: String in Proof.AUTHORITY_KEYS:
				var missing: Dictionary = authority.duplicate(true)
				missing.erase(field)
				_check(not Proof.matches(missing, season, profile), "missing authority field " + field)
			for field: Variant in ["extra", 7]:
				var extra: Dictionary = authority.duplicate(true)
				extra[field] = true
				_check(not Proof.matches(extra, season, profile), "unknown authority key refuses")
			for change: String in ["version", "format", "run", "history", "funding", "policy", "home", "profile"]:
				var bad: Dictionary = authority.duplicate(true)
				match change:
					"version": bad.version = true
					"format": bad.format = 93
					"run": bad.career_run += 1
					"history": bad.prior_history_key = "b".repeat(64)
					"funding": bad.funding_sha256 = "b".repeat(64)
					"policy": bad.header.owned_surface_night.run_id += 1
					"home": bad.header.home_property.revision += 1
					"profile": bad.source_profile = "b".repeat(64)
				_check(not Proof.matches(bad, season, profile), "changed94 authority refuses " + change)
	_boundary_controls()
	_frontier_controls()
	_journal_controls(root.path_join("journal-control"))
	print("NORMAL94_PROOF_RESULT checks=%d failures=%d synthetic_controls=true games=0" % [_checks, _failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

func _boundary_controls() -> void:
	var receipt: Dictionary = {"version": 1, "kind": "human", "source_profile": "a".repeat(64),
		"authority_key": "b".repeat(64), "save_sha256": "c".repeat(64), "seed": 1,
		"home": "d".repeat(64), "policy": "e".repeat(64), "results": 0,
		"reports": 0, "pending_reports": 0, "pending": true}
	_check(Proof.boundary_shape(receipt), "synthetic human boundary shape")
	for field: String in Proof.BOUNDARY_KEYS:
		var missing: Dictionary = receipt.duplicate(true)
		missing.erase(field)
		_check(not Proof.boundary_shape(missing), "missing boundary field " + field)
	for change: String in ["version", "kind", "policy", "count", "pending", "extra"]:
		var bad: Dictionary = receipt.duplicate(true)
		match change:
			"version": bad.version = true
			"kind": bad.kind = "publish"
			"policy": bad.policy = ""
			"count": bad.results = 2
			"pending": bad.pending = false
			"extra": bad[1] = true
		_check(not Proof.boundary_shape(bad), "malformed boundary refuses " + change)

func _frontier_controls() -> void:
	for results: int in [0, 1, 2]:
		for pending: bool in [false, true]:
			for reports: int in [0, 1, 2]:
				for kind: String in ["human", "ai", "publish"]:
					var expected: bool = results < 2 and ((kind == "human" and not pending and reports == 0)
						or (kind == "ai" and pending and reports < 2)
						or (kind == "publish" and pending and reports == 2))
					_check(Proof.frontier(kind, results, pending, reports) == expected,
						"one-step frontier excludes duplicates or synthetic jumps")

func _journal_controls(root: String) -> void:
	DirAccess.make_dir_recursive_absolute(root)
	_check(Journal.write_new(root.path_join("season.json"), {"synthetic": "save"}), "isolated synthetic journal input")
	var intent: String = Journal.begin(root, "human-0", {"synthetic_control": true, "format": 94})
	_check(not intent.is_empty(), "immutable intent before synthetic action")
	_check(Journal.write_new(root.path_join("human-0.json"), {"synthetic_control": true}), "synthetic raw saved independently")
	_check(not Journal.ready(root, true) and Journal.begin(root, "human-retry", {}).is_empty(), "uncertain raw outcome prohibits another game")
	_check(not Journal.write_new(root.path_join("human-0.json"), {"replacement": true}), "retained raw cannot be overwritten")
	var receipt: Dictionary = {"save_sha256": FileAccess.get_sha256(root.path_join("season.json"))}
	_check(Journal.write_new(root.path_join("boundary.json"), receipt)
		and Journal.write_new(root.path_join("resume-boundary.json"), receipt)
		and Journal.complete(root, intent, "boundary.json"), "original protocol completes only matching durable receipt")
	_check(Journal.ready(root, true) and Journal.begin(root, "human-0", {}).is_empty(), "completed action identity still cannot replay")

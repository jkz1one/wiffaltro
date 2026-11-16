extends Node
## Read-only audit of an already committed retained round. No save/restore/repair/game.
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("STANDARD_AUDIT_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	var root: String = ""
	var evidence: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-owner-root="):
			root = arg.trim_prefix("--audit-owner-root=")
		if arg.begins_with("--audit-evidence-root="):
			evidence = arg.trim_prefix("--audit-evidence-root=")
	if not check(root.is_absolute_path() and evidence.is_absolute_path()
		and DirAccess.dir_exists_absolute(root) and DirAccess.dir_exists_absolute(evidence), "existing absolute retained roots"):
		get_tree().quit(2)
		return
	var owner_hashes: Dictionary = _hash_tree(root)
	var evidence_hashes: Dictionary = _hash_tree(evidence)
	_run(root, evidence)
	SeasonSave._dynasty_owner_path = ""
	check(ClubCareer.same(owner_hashes, _hash_tree(root)), "entire owner tree bytes unchanged")
	check(ClubCareer.same(evidence_hashes, _hash_tree(evidence)), "entire evidence/archive tree bytes unchanged")
	print("STANDARD_SETTLEMENT_AUDIT checks=%d failures=%d new_physical_games=0 writes=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _run(root: String, evidence: String) -> void:
	var before: Dictionary = _read(evidence.path_join("retained/owner.json")).get("owner", {})
	var final: Dictionary = _read(evidence.path_join("final89.json"))
	var path: String = root.path_join("owner.json")
	var found: Dictionary = Store.inspect(path)
	if not check(found.get("status") == "ready" and not before.is_empty() and not final.is_empty(), "ready owner and retained before/final evidence"):
		return
	var owner: Dictionary = found.owner
	if not check(owner.selected == "other" and owner.revision > before.revision
		and owner.other.session_id == before.other.session_id, "final checkpoint of same selected session follows retained pending"):
		return
	if not check(SeasonSave.bind_dynasty_owner(path), "read-only owner binding"):
		return
	var season: SeasonState = SeasonSave._decode(final)
	if not check(season != null, "committed final89 decodes against current owner"):
		return
	check(ClubCareer.same(SeasonSave.snapshot(season), final), "cold decoded full envelope exact")
	check(ClubCareer.same(owner.other.reference, SeasonSave.DynastyCareerSave.snapshot_reference(final)), "manifest binds exact retained final")
	var entry: Dictionary = owner.career.sessions[owner.other.session_id]
	check(entry.settled == 0, "season remains active, not completion-settled")
	check(season.player_results.size() == 1 and season.results.size() == 3
		and season.round_index == 1 and season.physical.pending.is_empty()
		and season.physical.reports.size() == 2, "one human plus two AI games form one complete round")
	check(entry.contribution.proof.scores.size() == 3, "session proof records all three league fixtures")
	check(ClubCareer.same(entry.contribution.proof, ClubSeasonRecord.capture(season)), "persisted contribution equals exact runtime capture")
	check(ClubCareer.same(entry.standard_grant,
		before.career.sessions[before.other.session_id].standard_grant), "frozen admission grant unchanged")
	check(owner.career.sessions.size() == before.career.sessions.size()
		and ClubCareer.same(owner.career.settlements, before.career.settlements)
		and Authority.view(owner.career).balance == Authority.view(before.career).balance
		and ClubCareer.same(owner.dynasty.reference, before.dynasty.reference), "no new session, completion payout or Dynasty mutation")
	check(SeasonRoundSettlement._receipts(season), "one reward receipt per completed club fixture")
func _read(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}
func _hash_tree(root: String, relative: String = "") -> Dictionary:
	var result: Dictionary = {}
	var folder: String = root.path_join(relative)
	for name: String in DirAccess.get_files_at(folder):
		var key: String = relative.path_join(name) if not relative.is_empty() else name
		result[key] = FileAccess.get_sha256(root.path_join(key))
	for name: String in DirAccess.get_directories_at(folder):
		result.merge(_hash_tree(root, relative.path_join(name) if not relative.is_empty() else name))
	return result

extends Node
const Live = preload("res://src/gameplay/season/dynasty_standard_live.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("STANDARD_HISTORY ", ok, " ", label)
	return ok
func _ready() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--owner-history-file="): path = arg.trim_prefix("--owner-history-file=")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		get_tree().quit(2)
		return
	_run(value.owner)
	print("STANDARD_HISTORY_RESULT %d checks, %d failures" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run(owner: Dictionary) -> void:
	var grant: Dictionary = Grant.capture(owner.career)
	if not check(grant.get("version") == 3, "settled Dynasty uses grant3"): return
	for tier in [0, 1]:
		_tier(owner, grant, tier)

func _tier(owner: Dictionary, grant: Dictionary, tier: int) -> void:
	var session: Dictionary = Bound.binding({"owner_id": owner.owner_id, "lineage_id": owner.lineage.id,
		"generation": owner.lineage.generation, "ordinal": owner.lineage.ordinal,
		"session_id": "standard-history-probe", "seed": 91700 + tier, "tier": tier, "league": "standard",
		"format": 89, "grant_sha256": Save.snapshot_reference(grant).sha256})
	var prepared: Dictionary = Live.prepare(grant, session)
	if not check(not prepared.is_empty(), "qualified transient Standard projection prepares"): return
	check(prepared.template.career.version == 29, "explicit transient grammar29")
	check(ClubCareer.from_data(prepared.template.career) == null, "ordinary decoder refuses projection29")
	var season: SeasonState = Live.create(grant, session)
	if not check(season != null, "Standard creates after Dynasty settlement"): return
	var snapshot: Dictionary = Bound.capture(season, session, grant, owner.career)
	if not check(not snapshot.is_empty(), "qualified Standard89 snapshot captures"): return
	var cold: Dictionary = JSON.parse_string(JSON.stringify(snapshot, "", true, true))
	check(not Bound.qualify(cold, owner.career).is_empty(), "cold owner-qualified replay")
	check(SeasonSave._decode(cold.checkpoint) == null, "raw ordinary decode refuses29")
	var bad: Dictionary = cold.checkpoint.duplicate(true)
	bad.career.version = 27
	check(Live.decode(bad, grant, session) == null, "no mislabeled27 fallback")
	bad = cold.checkpoint.duplicate(true)
	bad.career.runs[0].seed += 1
	check(Live.decode(bad, grant, session) == null, "prefix tamper rejected")
	check(SeasonSave.Operations1._ac02_passive_15_private_decode_payload_terrain(
		cold.checkpoint, {}, false, {}, false, {}, null, {}, null, [],
		{"grant": grant, "session": session, "template": prepared.template}) == null,
		"grant3 replay requires separately derived projection")

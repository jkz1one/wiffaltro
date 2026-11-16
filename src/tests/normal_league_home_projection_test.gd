extends Node
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
var failures: int = 0
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("NORMAL93_PROJECTION ", ok, " ", label)
func _ready() -> void:
	var source: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--projection-source="): source = arg.trim_prefix("--projection-source=")
	if not source.is_absolute_path() or not FileAccess.file_exists(source):
		get_tree().quit(2)
		return
	var bytes: String = FileAccess.get_file_as_string(source)
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(bytes))
	check(season != null and Normal.matches(season), "retained genuine pre-result93 validates read-only")
	if season != null:
		var original: Dictionary = SeasonSave.snapshot(season)
		var fork: SeasonState = SeasonRoundSettlement._fork_replayed_state(season)
		check(fork != null and Normal.matches(fork), "decoder projection retains ordinary Career27 authority")
		if fork != null:
			check(fork.career != season.career and ClubCareer.same(fork.career.to_data(), season.career.to_data()), "career deeply detached with exact current history and assets")
			var kept: ClubCareer = fork.career
			fork.career = null
			check(not Normal.matches(fork), "old null-career projection reproduces93 context failure")
			fork.career = kept
			check(ClubCareer.same(SeasonSave.snapshot(fork), original), "projection checkpoint exactly equals validated empty-pending source")
			fork.career.runs[-1].seed += 1
			check(not Normal.matches(fork), "mutated projected career cannot pass context")
			check(ClubCareer.same(SeasonSave.snapshot(season), original), "projection mutation cannot alter original career")
		var bad: SeasonState = Normal.detached(season)
		bad._league_home_context = season._league_home_context.duplicate(true)
		bad.home_property = season.home_property.duplicate(true)
		bad.career = null
		check(SeasonRoundSettlement._fork_replayed_state(bad) == null, "93 missing career refuses projection")
	check(FileAccess.get_file_as_string(source) == bytes, "retained input byte-identical")
	print("NORMAL93_PROJECTION_RESULT %d checks, %d failures; no games or save writes" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)

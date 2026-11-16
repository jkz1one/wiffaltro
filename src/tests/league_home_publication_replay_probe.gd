extends Node
## Read-only replay of real retained evidence; never writes or reruns a game.
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print("HOME_PUBLICATION ", ok, " ", label)
	if not ok: failures += 1
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--league-home-resume-root="): root = arg.trim_prefix("--league-home-resume-root=")
	if not root.is_absolute_path():
		get_tree().quit(2)
		return
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = root.path_join("season.json.dynasty-owner")
	var owner: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("season.json.dynasty-owner"))).owner
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(
		"season.json.dynasty-owner.objects/" + owner.other.reference.sha256 + ".a.json")))
	var before: Dictionary = Authority._qualify_session(owner.career, owner.other.session_id, snapshot)
	check(not before.is_empty(), "retained snapshot qualifies")
	if before.is_empty():
		get_tree().quit(1)
		return
	var pending: Dictionary = before.season.physical.pending.duplicate(true)
	var detached: Dictionary = snapshot.duplicate(true)
	SeasonRoundSettlement._physical_payload(detached).physical.pending = {}
	var replay: Dictionary = Authority._qualify_session(owner.career, owner.other.session_id, detached)
	var projected: Dictionary = SeasonRoundSettlement._project_candidate(replay.season, pending)
	check(projected.has("candidate") and not projected.has("fixture") and not projected.has("error"), "all real reports project complete round")
	if projected.has("candidate") and not projected.has("fixture"):
		var saved: Dictionary = Live.capture(projected.candidate)
		var after: Dictionary = Authority._qualify_session(owner.career, owner.other.session_id, saved)
		check(not after.is_empty(), "completed replay snapshot qualifies")
		if not after.is_empty():
			check(Owner._extends(before, after, owner.other.frontier), "exact accepted round continuation")
			after.season._league_home_context.erase("format")
			check(not Owner._extends(before, after, owner.other.frontier), "mixed90/91 transition refused")
			after.season._league_home_context["format"] = 91
			var result: Dictionary = after.season.player_results.back()
			check(Live._human_matches(pending.human, result), "exact human identity")
			var changed: Dictionary = result.duplicate(true)
			changed.property = "foreign-property"
			check(not Live._human_matches(pending.human, changed), "changed property refused")
			changed = result.duplicate(true)
			changed.doubleheader_evidence = []
			check(not Live._human_matches(pending.human, changed), "false Doubleheader refused")
			changed = result.duplicate(true)
			changed.inventory_final = {"forged": true}
			check(not Live._human_matches(pending.human, changed), "extra inventory refused")
			changed = result.duplicate(true)
			changed.away_runs += 1
			check(not Live._human_matches(pending.human, changed), "changed score refused")
	get_tree().quit(0 if failures == 0 else 1)

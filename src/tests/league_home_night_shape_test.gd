extends Node
## Pure composition/identity controls using retained genuine Night evidence.
## Added inventory/workload rows are SHAPE ONLY, never a94 game or reward.
const Night = preload("res://src/gameplay/season/league_home_night_result.gd")
var checks: int = 0
var failures: int = 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("LEAGUE_NIGHT_SHAPE ", value, " ", label)


func _ready() -> void:
	if OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") != "1" or not StadiumNpcPublicRuntime.source_qualified():
		print("LEAGUE_NIGHT_SHAPE_REFUSED: exact reviewed source and serialized launcher are required")
		get_tree().quit(2)
		return
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--night-input="):
			path = argument.trim_prefix("--night-input=")
	if not path.is_absolute_path() or not FileAccess.file_exists(path):
		get_tree().quit(2)
		return
	var input: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not input is Dictionary or not input.get("human") is Array or not input.get("result") is Dictionary:
		get_tree().quit(2)
		return
	var human: Array = input.human
	var result: Dictionary = input.result
	if not SeasonRoundSettlement._night_shape({"human": human, "reports": []}) \
		or not ClubCareer.same(human[17], result.get("night_evidence")):
		get_tree().quit(2)
		return
	var fixture: Dictionary = {"id": result.id, "round": result.round, "away": result.away, "home": result.home}
	check(Night.result_keys_valid(result, fixture, false, false, true), "retained genuine Night result keeps original strict field grammar")
	var foreign: Dictionary = result.duplicate(true)
	foreign["unrecognized_result_field"] = "must not disappear"
	check(not Night.result_keys_valid(foreign, fixture, false, false, true), "unknown result field cannot be silently dropped by94 replay")
	foreign = result.duplicate(true)
	foreign[73] = true
	check(not Night.result_keys_valid(foreign, fixture, false, false, true), "non-String result key refuses94 replay")
	var away: Dictionary = result.duplicate(true)
	away.erase("night_evidence")
	check(Night.result_keys_valid(away, fixture, false, false, false)
		and not Night.result_keys_valid(result, fixture, false, false, false), "away grammar excludes unscheduled Night evidence")
	for doubleheader: bool in [false, true]:
		for inventory: bool in [false, true]:
			var composed: Array = human.slice(0, 13)
			var row: Dictionary = result.duplicate(true)
			if doubleheader:
				composed.append([{"shape_only": 1}, {"shape_only": 2}])
				row["doubleheader_evidence"] = composed[-1].duplicate(true)
			if inventory:
				composed.append({"shape_only": true})
				row["inventory_final"] = composed[-1].duplicate(true)
			composed.append_array(human.slice(13))
			var string_keys: bool = true
			for key: Variant in row: string_keys = string_keys and key is String
			check(string_keys, "composed result uses exact String key grammar")
			if doubleheader or inventory:
				var string_name_row: Dictionary = row.duplicate(true)
				var tail_key: String = "doubleheader_evidence" if doubleheader else "inventory_final"
				var tail: Variant = string_name_row[tail_key]
				string_name_row.erase(tail_key)
				string_name_row[StringName(tail_key)] = tail
				check(not Night.result_keys_valid(string_name_row, fixture, doubleheader, inventory, true),
					"same spelling StringName tail stays rejected by strict result grammar")
			check(Night.result_keys_valid(row, fixture, doubleheader, inventory, true), "context-enabled workload and inventory result keys retained")
			if doubleheader:
				check(not Night.result_keys_valid(row, fixture, false, inventory, true), "workload result key requires Doubleheader context")
			if inventory:
				check(not Night.result_keys_valid(row, fixture, doubleheader, false, true), "inventory result key requires inventory context")
			check(Night.shape(composed, [], doubleheader), "complete Night/workload/inventory shape")
			check(Night.human_matches(composed, row), "exact comparison preserves all tail operands")
			check(not LeagueHomeResult.shape(composed, [], doubleheader), "historical League home tail stays strict")
			if doubleheader or inventory:
				check(not SeasonRoundSettlement._night_shape({"human": composed, "reports": []}), "historical Night18 stays strict")
			check(not Night.shape(composed, [{}], doubleheader), "invalid AI report rejected")
			check(not Night.shape(composed, [], not doubleheader), "wrong workload offset rejected")
			for index: int in [composed.size() - 5, composed.size() - 4, composed.size() - 3, composed.size() - 2, composed.size() - 1]:
				var bad: Array = composed.duplicate(true)
				bad[index] = "changed" if index == composed.size() - 4 else {}
				check(not Night.human_matches(bad, row), "changed reserved/property/evidence tail rejects")
			for field: String in ["pool_evidence", "yard_evidence"]:
				var bad: Dictionary = row.duplicate(true)
				bad[field] = {}
				check(not Night.human_matches(composed, bad), "mixed " + field + " rejects")
				check(not Night.result_keys_valid(bad, fixture, doubleheader, inventory, true), "strict94 replay rejects mixed " + field)
			var missing: Dictionary = row.duplicate(true)
			missing.erase("night_evidence")
			check(not Night.human_matches(composed, missing), "missing Night rejects")
			if inventory:
				missing = row.duplicate(true)
				missing.inventory_final = {"shape_only": false}
				check(not Night.human_matches(composed, missing), "inventory identity retained")
			if doubleheader:
				missing = row.duplicate(true)
				missing.doubleheader_evidence[1].shape_only = 3
				check(not Night.human_matches(composed, missing), "second-leg workload identity retained")
	check(not Night.pending_valid(null, []), "no pending authority from shape alone")
	check(Night.record_operands(null, human).is_empty(), "no recording authority from shape alone")
	print("LEAGUE_NIGHT_SHAPE_RESULT checks=%d failures=%d physical_games=0 added_workload_inventory=shape_only" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

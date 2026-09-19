class_name BaseState
extends RefCounted

var first: StringName = &""
var second: StringName = &""
var third: StringName = &""

func clear() -> void:
	first = &""
	second = &""
	third = &""

func set_debug_preset(index: int) -> void:
	clear()
	match posmod(index, 3):
		1:
			third = &"runner.third"
		2:
			first = &"runner.first"
			second = &"runner.second"
			third = &"runner.third"

func advance_for_hit(
	result: BallPlayOutcome.Result,
	batter: StringName
) -> int:
	var runs_scored: int = 0
	match result:
		BallPlayOutcome.Result.SINGLE:
			if not third.is_empty():
				runs_scored += 1
			third = second
			second = first
			first = batter
		BallPlayOutcome.Result.DOUBLE:
			if not third.is_empty():
				runs_scored += 1
			if not second.is_empty():
				runs_scored += 1
			third = first
			second = batter
			first = &""
		BallPlayOutcome.Result.TRIPLE:
			runs_scored += occupied_count()
			first = &""
			second = &""
			third = batter
		BallPlayOutcome.Result.HOME_RUN:
			runs_scored += occupied_count() + 1
			clear()
	return runs_scored

func occupied_count() -> int:
	var count: int = 0
	if not first.is_empty():
		count += 1
	if not second.is_empty():
		count += 1
	if not third.is_empty():
		count += 1
	return count

func display_string() -> String:
	return "1B %s   2B %s   3B %s" % [
		"●" if not first.is_empty() else "○",
		"●" if not second.is_empty() else "○",
		"●" if not third.is_empty() else "○",
	]

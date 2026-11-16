extends Node
## Read-only cold qualification probe; never creates games or result evidence.


func _ready() -> void:
	var expected: bool = not OS.get_cmdline_user_args().has("--expect-rejected")
	var start: int = Time.get_ticks_usec()
	var original: bool = StadiumNpcSourceQualification.matches_original(
		StadiumNpcPublicRuntime.SOURCE_PINS
	)
	var original_us: int = Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var current: bool = StadiumNpcSourceQualification.matches_current(
		StadiumNpcPublicRuntime.SOURCE_PINS
	)
	var current_us: int = Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var accepted: bool = StadiumNpcPublicRuntime.source_qualified()
	var combined_us: int = Time.get_ticks_usec() - start
	# Hash every baseline path once, irrespective of stale pins, for fair size/cost comparison.
	start = Time.get_ticks_usec()
	for path: String in StadiumNpcPublicRuntime.SOURCE_PINS:
		FileAccess.get_sha256(path)
	var full_baseline_us: int = Time.get_ticks_usec() - start
	print(
		"NPC_SOURCE_PROFILE ",
		JSON.stringify(
			{
				"original": original,
				"current": current,
				"accepted": accepted,
				"expected": expected,
				"original_us": original_us,
				"current_us": current_us,
				"combined_us": combined_us,
				"full_baseline_hash_us": full_baseline_us
			}
		)
	)
	get_tree().quit(0 if accepted == expected and not original else 1)

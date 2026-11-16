extends Node
## Fresh-process read-only audit of six actual public-save outputs.
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _ready() -> void:
	var manifest_path: String = OS.get_environment("QA_SAVED_MANIFEST")
	var output: String = OS.get_environment("QA_SAVE_OUTPUT")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	check(StadiumNpcPublicRuntime.source_qualified(), "exact reviewed combined source admitted")
	check(
		manifest.failures.is_empty() and manifest.saves.size() == 6,
		"six successful real public-save outputs"
	)
	for row: Dictionary in manifest.saves:
		var before: String = FileAccess.get_sha256(row.saved_path)
		check(before == row.saved_sha256, "saved bytes exactly bound before cold decode")
		SeasonSave.path = row.saved_path
		var season: SeasonState = SeasonSave.restore()
		var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(row.path))
		check(
			season != null and ClubCareer.same(original, SeasonSave.snapshot(season)),
			"cold actual legacy/current saved state preserves complete original semantics"
		)
		check(
			(
				FileAccess.get_sha256(row.saved_path) == before
				and FileAccess.get_sha256(row.path) == row.input_sha256
			),
			"cold read leaves saved and frozen original bytes unchanged"
		)
	var file: FileAccess = FileAccess.open(
		output.path_join("cold-saved-summary.json"), FileAccess.WRITE
	)
	file.store_string(
		JSON.stringify(
			{
				"checks": checks,
				"failures": failures,
				"new_games": 0,
				"manifest_sha256": FileAccess.get_sha256(manifest_path)
			}
		)
	)
	file.close()
	print("QUALIFIED_SAVED_COLD checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

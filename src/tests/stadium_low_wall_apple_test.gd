extends "res://src/tests/stadium_low_wall_plaza_capture_test.gd"


## Existing actual-contact HR probe exercised with complete low ownership and paid plaza apple.
func _views(_layout_value: Dictionary, _recipe: String) -> void:
	pass


func _runtime() -> void:
	for profile: String in StadiumLowWallRecipes.PROFILES:
		var low: Dictionary = StadiumLowWallLayout.upgrade(_layout, _paid.surface_owned())
		var suggested: Dictionary = StadiumLowWallManifest.suggest(
			profile, "ST-024", _paid.construction(), _paid.wall_pieces().stock
		)
		check(suggested.ok, "paid apple low profile suggestion")
		if not suggested.ok:
			continue
		low.low_wall = suggested.manifest
		if not _low_apply(low):
			continue
		_snapshot = StadiumLayoutSnapshot.capture(_paid, true)
		check(_snapshot.version == 32, "apple uses actual complete low snapshot")
		await super._runtime()

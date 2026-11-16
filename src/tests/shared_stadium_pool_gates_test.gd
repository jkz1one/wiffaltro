extends Node
const Pool = preload("res://src/gameplay/season/dynasty_stadium_pool.gd")
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _ready() -> void:
	for version in range(1, 70):
		var layout: Dictionary = {"version": version, "family": StadiumPoolOwnedLayout.FAMILY if version == 16 else StadiumSurfaceLayout.FAMILY}
		check(Pool.supported(layout) == (version in [12, 16] and StadiumPoolWorkshopUI.WORKSHOP_ENABLED), "exact Pool family " + str(version))
		for op: String in ["stadium_draft", "stadium_apply"]:
			var request: Dictionary = {"op": op, "layout": layout}
			if version not in [12, 16]:
				check(not Pool.allowed(SeasonState.new(), request), "other family denied")
				continue
			for phase in range(5):
				for variant in range(5):
					var season: SeasonState = SeasonState.new()
					season.phase = phase
					if variant > 0:
						season.physical = SeasonPhysicalFixtures.new()
					if variant == 2:
						season.physical.pending = {"test": true}
					if variant == 3:
						season.owned_surface_night = {"test": true}
					if variant == 4:
						season.home_property = {"boundary": {}}
					var expected: Dictionary = ClubConstruction.draft_admission(season, layout, true) if op == "stadium_draft" else ClubConstruction.apply_admission(season, layout, true)
					check(Pool.allowed(season, request) == expected.ok, "pure admission parity")
					check(Assets.allowed(season, request) == expected.ok, "owner command admission parity")
	check(not Pool.supported({"version": 16, "family": "wrong"}), "wrong family")
	print("SHARED_POOL_GATES checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

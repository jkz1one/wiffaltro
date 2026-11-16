extends "res://src/tests/stadium_waterfall_animation_public_test.gd"
## Exact same public replay, but with publicly purchased46 and empty47 opt-in.
const VariantSetup = preload("res://src/tests/stadium_low_wall_public_variant.gd")


func _prepare(input: Dictionary) -> Dictionary:
	var branch: Dictionary = VariantSetup.prepare(input, "low_flanks")
	if not branch.ok:
		return branch
	var previous: SeasonState = branch.completed_season
	var paid: ClubAssetLedger = ClubPlayers.assets(previous.career)
	var layout: Dictionary = StadiumWaterfallAnimationLayout.upgrade(
		paid.view().stadium_active, paid.surface_owned()
	)
	var saved: Dictionary = ClubConstruction.save_draft(previous, layout, paid.revision())
	if not saved.ok:
		return saved
	var applied: Dictionary = ClubConstruction.apply_draft(
		previous, layout, ClubPlayers.assets(previous.career).revision()
	)
	if not applied.ok:
		return applied
	return {"ok": true, "error": "", "completed_season": previous}


func _motion_control(lab: PitchBatLab) -> void:
	var property: StadiumWaterfallAnimationProperty = (
		StadiumWaterfallAnimationRuntime.property_claim(lab) as StadiumWaterfallAnimationProperty
	)
	check(
		(
			property != null
			and property.animation_layout.animation_base == 46
			and property.animation_layout.waterfall_motion.is_empty()
		),
		"real public home retains exact empty47/base46 receipt"
	)
	check(
		(
			StadiumWaterfallAnimationRuntime.current(lab) == null
			and lab._match_state.stadium.is_read_only()
			and property._issued_live
			and property.issued_props_intact(lab)
		),
		"public empty47 admits issued owner context without inventing animation"
	)
	var boundary: StadiumWaterfallAnimationLowBoundary = property.get_node("BoundaryGraph")
	check(
		(
			boundary.deep_intact()
			and StadiumWaterfallAnimationInstall.installed_bound(lab, lab._match_state.stadium)
		),
		"real public47/base46 deep report context intact"
	)


func _profile_label() -> String:
	return "empty47-base46-low-flanks"

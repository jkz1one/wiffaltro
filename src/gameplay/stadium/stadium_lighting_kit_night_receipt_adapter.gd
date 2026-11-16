class_name StadiumLightingKitNightReceiptAdapter
extends RefCounted
## Additive authority adapter only. Never creates a projected ownership receipt.
## Original entry32/34 must validate and match its complete paid journal prefix.
const VERSION: int = 1
const FIXTURE_VERSION: int = 36
const FAMILY: String = "owned-st111-empty-successor-receipt-v1"
const ENTRY_VERSIONS: Array[int] = [32, 34]
const COMPLETE_KEYS: Array[String] = [
	"version",
	"tier",
	"geometry",
	"revision",
	"layout",
	"inventory",
	"wall_piece_inventory",
	"scoreboard_inventory",
	"surface_access",
	"boundary"
]


static func signature(core_contract: String) -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"family": FAMILY,
				"fixture": FIXTURE_VERSION,
				"candidate": core_contract,
				"entries": ENTRY_VERSIONS,
				"layouts": [46, 47],
				"retained_animation_bases": [45, 46],
				"low_wall": StadiumLowWallLayout.signature(),
				"animation": StadiumWaterfallAnimationLayout.signature(),
				"projection": "exact-empty-lossless-retained-base-to-physical43-v1",
				"authority":
				"original-complete-inventories-layout-geometry-paid-prefix-never-projected-receipt-v1",
				"physical": "separately-bound43-layout-geometry-and-exact-boundary-v1",
				"installed_successor_features": false
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func supports_entry(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.get("layout") is Dictionary
		and (
			(
				SeasonOwnership._whole(value.get("version"), 32, 32)
				and StadiumLowWallLayout.is_family(value.layout)
			)
			or (
				SeasonOwnership._whole(value.get("version"), 34, 34)
				and StadiumWaterfallAnimationLayout.is_family(value.layout)
			)
		)
	)


static func valid_entry(value: Variant) -> bool:
	return (
		supports_entry(value)
		and StadiumLayoutSnapshot.valid(value)
		and not retained_empty_base(value.layout).is_empty()
	)


static func retained_empty_base(layout: Dictionary) -> Dictionary:
	# This is a physical projection, never an entry/prefix/ownership substitution.
	var result: Dictionary = layout.duplicate(true)
	if StadiumWaterfallAnimationLayout.is_family(result):
		if (
			result.get("family") != StadiumWaterfallAnimationLayout.FAMILY
			or not result.get("waterfall_motion") is Array
			or not result.waterfall_motion.is_empty()
		):
			return {}
		var retained: Dictionary = StadiumWaterfallAnimationLayout.base(result)
		if (
			retained.is_empty()
			or not ClubCareer.same(
				StadiumWaterfallAnimationLayout.with_base(result, retained), result
			)
		):
			return {}
		result = retained
	if StadiumLowWallLayout.is_family(result):
		if (
			result.get("family") != StadiumLowWallLayout.FAMILY
			or not ClubCareer.same(result.get("low_wall"), StadiumLowWallManifest.empty())
		):
			return {}
		var retained: Dictionary = StadiumLowWallLayout.base(result)
		if (
			retained.is_empty()
			or not ClubCareer.same(StadiumLowWallLayout.with_base(result, retained), result)
		):
			return {}
		result = retained
	return result if StadiumWaterfallLiveItems.is_family(result) else {}

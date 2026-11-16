class_name StadiumSurfaceNightLayout
extends RefCounted
## Candidate-only owned surface binding. Structural eligibility is not optical qualification.

const CANDIDATE_VERSION: int = 1
const FAMILY: String = "owned-surface-night-candidate-v1"
const FLOODLIGHT_CANDIDATE_VERSION: int = 2
const FLOODLIGHT_FAMILY: String = "owned-floodlight-night-candidate-v2"
const RUNTIME_READY: bool = false
const PUBLIC_READY: bool = false


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"candidate_version": CANDIDATE_VERSION,
				"family": FAMILY,
				"entry_version": 8,
				"layout_version": StadiumSurfaceLayout.VERSION,
				"tiers": ["backyard", "expanded"],
				"walls": StadiumWallLayout.empty(),
				"boundary": StadiumBoundaryGraph.signature(),
				"surface": StadiumSurfaceLayout.signature(),
				"lights": StadiumLightItems.signature(),
				"light_sites_version": StadiumYardLightSites.VERSION,
				"palette_version": StadiumSurfaceNightPalette.VERSION,
				"plate_sand_factor": StadiumSurfaceNightPalette.PLATE_SAND_FACTOR
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func capture(ledger: ClubAssetLedger) -> Dictionary:
	if ledger == null:
		return {}
	var entry: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	if StadiumLightingKitNightCandidate.is_candidate_layout(entry.get("layout")):
		return StadiumLightingKitNightCandidate.capture(ledger)
	if not _eligible(entry):
		return {}
	var floodlight: bool = StadiumFloodlightOwnedItems.is_family(entry.layout)
	var candidate: Dictionary = {
		"candidate_version": FLOODLIGHT_CANDIDATE_VERSION if floodlight else CANDIDATE_VERSION,
		"family": FLOODLIGHT_FAMILY if floodlight else FAMILY,
		"contract": floodlight_signature() if floodlight else signature(),
		"entry": entry.duplicate(true)
	}
	return candidate if valid(candidate, ledger) else {}


static func valid(candidate: Variant, ledger: ClubAssetLedger) -> bool:
	if candidate is Dictionary and candidate.get("candidate_version") == 3:
		return StadiumLightingKitNightCandidate.valid(candidate, ledger)
	if ledger == null or not candidate_shape(candidate):
		return false
	# matches() binds the complete declaration to its authentic paid journal prefix,
	# including older retained entries. Later ownership cannot repair an earlier entry.
	return _eligible(candidate.entry) and StadiumLayoutSnapshot.matches(candidate.entry, ledger)


static func floodlight_signature() -> String:
	# Separate candidate contract; candidate1 and its ST-037 hashes stay unchanged.
	return (
		JSON
		. stringify(
			{
				"candidate_version": FLOODLIGHT_CANDIDATE_VERSION,
				"family": FLOODLIGHT_FAMILY,
				"entry_version": 8,
				"owned_floodlights": StadiumFloodlightOwnedItems.signature(),
				"profiles": ["CLUB4-LOW", "MOGUL6-STANDARD", "MOGUL4-PREMIUM"],
				"palette_version": StadiumSurfaceNightPalette.VERSION,
				"plate_sand_factor": StadiumSurfaceNightPalette.PLATE_SAND_FACTOR
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func candidate_shape(candidate: Variant) -> bool:
	if candidate is Dictionary and candidate.get("candidate_version") == 3:
		return StadiumLightingKitNightCandidate.candidate_shape(candidate)
	if (
		not candidate is Dictionary
		or not SeasonOwnership._keys(
			candidate, ["candidate_version", "family", "contract", "entry"]
		)
		or not candidate.entry is Dictionary
	):
		return false
	if SeasonOwnership._whole(
		candidate.candidate_version, FLOODLIGHT_CANDIDATE_VERSION, FLOODLIGHT_CANDIDATE_VERSION
	):
		return (
			candidate.family == FLOODLIGHT_FAMILY
			and candidate.contract == floodlight_signature()
			and StadiumFloodlightOwnedItems.is_family(candidate.entry.get("layout"))
			and _eligible(candidate.entry)
		)
	return (
		SeasonOwnership._whole(candidate.candidate_version, CANDIDATE_VERSION, CANDIDATE_VERSION)
		and candidate.family == FAMILY
		and candidate.contract == signature()
		and not StadiumFloodlightOwnedItems.is_family(candidate.entry.get("layout"))
		and _eligible(candidate.entry)
	)


static func _eligible(entry: Dictionary) -> bool:
	if StadiumFloodlightOwnedItems.is_family(entry.get("layout")):
		return (
			StadiumLayoutSnapshot.valid(entry)
			and SeasonOwnership._whole(entry.get("version"), 8, 8)
			and not StadiumFloodlightOwnedItems.night_profile(entry).is_empty()
		)
	if (
		not StadiumLayoutSnapshot.valid(entry)
		or not SeasonOwnership._whole(entry.get("version"), 8, 8)
		or entry.tier not in ["backyard", "expanded"]
		or not SeasonOwnership._whole(entry.layout.get("version"), 12, 12)
	):
		return false
	var layout: Dictionary = entry.layout
	if (
		not ClubCareer.same(layout.walls, StadiumWallLayout.empty())
		or entry.boundary != StadiumBoundaryGraph.signature()
	):
		return false
	var stock: StadiumStock = StadiumLayoutSnapshot.ownership(entry)
	var checked: Dictionary = StadiumSurfaceLayout.validate(layout, stock, entry.tier)
	if (
		not checked.ok
		or not StadiumSurfaceLayout.owned(layout, StadiumLayoutSnapshot.surface_access(entry))
	):
		return false
	var lights: Dictionary = StadiumYardLightSites.validate(layout.lights, stock, entry.tier)
	if not lights.ok or not lights.complete:
		return false
	for row: Dictionary in checked.placements:
		if not StadiumLightItems.COMPATIBLE_ITEMS.has(row.item):
			return false
	# Do not promote the unchanged v12 result's night_qualified=false.
	return true

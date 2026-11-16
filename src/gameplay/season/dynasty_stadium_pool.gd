extends RefCounted
## Exact public Pool and its lossless v12 storage base. Never grants ownership.

static func supported(layout: Variant) -> bool:
	if not StadiumPoolWorkshopUI.WORKSHOP_ENABLED or not layout is Dictionary:
		return false
	return (SeasonOwnership._whole(layout.get("version"), 16, 16)
		and layout.get("family") == StadiumPoolOwnedLayout.FAMILY) or (
		SeasonOwnership._whole(layout.get("version"), 12, 12)
		and layout.get("family") == StadiumSurfaceLayout.FAMILY)


static func allowed(season: SeasonState, request: Dictionary) -> bool:
	if not supported(request.get("layout")):
		return false
	if request.get("op") == "stadium_draft":
		return ClubConstruction.draft_admission(season, request.layout, true).ok
	if request.get("op") == "stadium_apply":
		return ClubConstruction.apply_admission(season, request.layout, true).ok
	return false

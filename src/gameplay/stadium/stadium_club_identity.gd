class_name StadiumClubIdentity
extends RefCounted
## The current shipped Yard Club identity, independent of historical reward snapshots.

const VERSION: int = 1
const CREST: String = "club.yard_mark.v1"


static func current() -> Dictionary:
	# These are the existing ST-043 cloth and lettering colors, in sRGB hex.
	return {"version": VERSION, "name": SeasonState.TEAM_NAMES[0], "crest": CREST,
		"palette": ["66917a", "e1dcc8"]}


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["version", "name", "crest", "palette"]):
		return false
	if not SeasonOwnership._whole(value.version, VERSION, VERSION) \
		or not value.name is String or value.name.strip_edges().is_empty() \
		or value.name.length() > 64 or value.crest != CREST \
		or not value.palette is Array or value.palette.size() != 2:
		return false
	for index in range(value.name.length()):
		if value.name.unicode_at(index) < 32 or value.name.unicode_at(index) == 127:
			return false
	for color: Variant in value.palette:
		if not color is String or color.length() != 6:
			return false
		for character: String in color:
			if not "0123456789abcdef".contains(character):
				return false
	return true

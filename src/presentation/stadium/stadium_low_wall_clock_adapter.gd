class_name StadiumLowWallClockAdapter
extends RefCounted
## Additive exact family46 admission; historical clock/property checks stay strict.
const VERSION: int = 1


static func required(lab: PitchBatLab) -> bool:
	if (
		not is_instance_valid(lab)
		or lab._match_state == null
		or lab._stadium_ledger == null
		or not StadiumLowWallSnapshot.is_family(lab._match_state.stadium)
	):
		return false
	for row: Dictionary in lab._match_state.stadium.layout.get("mounted_displays", []):
		if lab._stadium_ledger._stock.copies.get(row.copy, {}).get("item", "") == "ST-069":
			return true
	return false


static func property_valid(property: StadiumPropertyGeometry, snapshot: Dictionary) -> bool:
	return (
		is_instance_valid(property)
		and property.get_script() == StadiumLowWallProperty
		and StadiumLowWallSnapshot.is_family(snapshot)
		and property.low_context_intact()
		and property.low_layout == snapshot.layout
	)

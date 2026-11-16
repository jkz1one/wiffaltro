class_name StadiumGrandIIPublicVisibility
extends StadiumGrandIPublicVisibility
## Exact28 groups: all I groups plus2 lower bowls,3 concourses,3 upper bowls,2 transitions.
## Same member-level clearance includes every added support and occupied crowd mesh.


func _venue_id() -> String:
	return "GRAND-II"


func _mesh_counts() -> Dictionary:
	var counts: Dictionary = MESH_COUNTS.duplicate()
	counts.merge({"ST-083": 15, "ST-082": 126, "ST-085": 117, "ST-088": 117})
	return counts


func _copy_counts() -> Dictionary:
	return StadiumGrandIIPublicConstruction.COUNTS


func _group_count() -> int:
	return 28

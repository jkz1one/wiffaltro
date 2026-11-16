class_name StadiumBoundaryLab
extends RefCounted
## Explicit isolated-lab adapter. No managed fixture, automation, save or editor activation.


static func install(lab: PitchBatLab) -> bool:
	if not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
		or not lab.get_meta("stadium_boundary_lab_only", false) or lab._managed_match \
		or lab._automation != null or lab._field_id != PitchBatLab.FIELD_ID \
		or is_instance_valid(lab._batted_ball) or not lab.has_meta("stadium_property"):
		return false
	return StadiumBoundaryRuntime._install(lab)

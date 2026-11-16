class_name StadiumGrandIIPublicCamera
extends StadiumGrandIPublicCamera
## Preserve Club camera framing and bind refreshed visibility to the exact II owner.


func _refresh(camera: Camera3D) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if property == null or property.venue_id != "GRAND-II" or camera != lab._camera \
		or lab._camera_director != self:
		return
	property.refresh_actor_presentation(lab)

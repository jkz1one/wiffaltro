class_name StadiumPoolPartyPublicCamera
extends StadiumClubCameraDirector
## Original Grand I inherits Club entry/live framing; current public owner replaces private gate.

var lab_ref: WeakRef


func update(camera: Camera3D, delta_seconds: float,
	ball_live: bool, ball_position: Vector3) -> void:
	super.update(camera, delta_seconds, ball_live, ball_position)
	_refresh(camera)


func snap(camera: Camera3D, ball_position: Vector3 = Vector3.ZERO) -> void:
	super.snap(camera, ball_position)
	_refresh(camera)


func _refresh(camera: Camera3D) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if property == null or property.venue_id != "POOL-PARTY" or camera != lab._camera \
		or lab._camera_director != self:
		return
	property.refresh_actor_presentation(lab)

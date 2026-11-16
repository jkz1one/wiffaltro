class_name StadiumClubReceiverVisibility
extends RefCounted
## Per-member bounds respect the corrected net's empty cup; never change physical geometry.


static func apply(net: Node3D, hidden: bool, camera: Camera3D, ball: Node3D = null) -> void:
	var alpha: float = 1
	if not hidden and is_instance_valid(camera) and is_instance_valid(ball):
		for mesh: MeshInstance3D in net.get_node("Visual").get_children():
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			if mesh.get_aabb().intersects_segment(inverse * camera.global_position,
				inverse * ball.global_position) != null:
				alpha = StadiumReceiverVisibility.FADED_ALPHA
				break
	StadiumReceiverVisibility._style(net, hidden, alpha)


static func refresh(lab: PitchBatLab, receiver: StadiumClubPitchReceiver,
	force_visible: bool = false) -> void:
	StadiumPropertyRuntime.refresh_receiver_visibility(lab, force_visible)
	var hidden: bool = not force_visible and not is_instance_valid(lab._batted_ball) \
		and lab._camera_director.shot == MatchCameraDirector.Shot.BATTING
	apply(receiver.net, hidden, lab._camera, lab._batted_ball)

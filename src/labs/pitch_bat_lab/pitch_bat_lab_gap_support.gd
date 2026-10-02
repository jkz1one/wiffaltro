class_name PitchBatLabGapSupport
extends RefCounted
## Sample actual defense/static colliders once, before launch reapplies assignment.


static func resolve(lab: PitchBatLab, contact: ContactResult) -> void:
	if (
		not lab._match_mode
		or not lab._swing_tracker.profile.gear_gap_bias
		or not contact.frozen_launch.is_empty()
		or contact.outcome not in [ContactResult.Outcome.CONTACT, ContactResult.Outcome.PERFECT]
	):
		return
	var data: Dictionary = capture(lab, contact.contact_position)
	var launch: Dictionary = SeasonGapCommit.make(
		data, contact, lab._swing_tracker.intent.handedness_left
	)
	if not SeasonGapCommit.apply(contact, launch):
		return
	var state: MatchState = lab._match_state
	state.frozen_contacts.append(
		{
			"pitch": lab._throw_number,
			"pa": state.plate_appearance_number,
			"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
			"player": String(state.batter().definition.id),
			"launch": launch.duplicate(true)
		}
	)


static func capture(lab: PitchBatLab, origin: Vector3) -> Dictionary:
	var defenders: Array[Vector3] = []
	if is_instance_valid(lab._pitcher_marker):
		defenders.append(lab._pitcher_marker.global_position)
	if is_instance_valid(lab._primary_fielder):
		defenders.append(lab._primary_fielder.global_position)
	var setup: BallSetupDefinition = ContentDB.get_ball_setup(lab.BALL_SETUP_ID)
	var info: Dictionary = {"known": setup != null and setup.aero_profile != null, "boxes": []}
	var radius: float = setup.aero_profile.radius_m if info.known else 0.0
	_collect(lab, radius, info)
	var boxes: Array[Rect2] = []
	boxes.assign(info.boxes)
	return SeasonGapLane.snapshot(lab._field_definition, origin, defenders, boxes, info.known)


static func _collect(node: Node, radius: float, info: Dictionary) -> void:
	if node is StaticBody3D and node.collision_layer != 0:
		var surface: StringName = node.get_meta(&"ball_surface", &"")
		if surface not in [&"ground", &"back_wall"]:
			var shapes: int = 0
			for child: Node in node.get_children():
				if not child is CollisionShape3D or child.disabled:
					continue
				shapes += 1
				if not child.shape is BoxShape3D:
					info.known = false
					continue
				var lower: Vector2 = Vector2.INF
				var upper: Vector2 = -Vector2.INF
				for x: float in [-0.5, 0.5]:
					for y: float in [-0.5, 0.5]:
						for z: float in [-0.5, 0.5]:
							var point: Vector3 = (
								child.global_transform * (child.shape.size * Vector3(x, y, z))
							)
							var planar: Vector2 = Vector2(point.x, point.z)
							lower = lower.min(planar)
							upper = upper.max(planar)
				info.boxes.append(Rect2(lower, upper - lower).grow(radius))
			if shapes == 0:
				info.known = false
	for child: Node in node.get_children():
		_collect(child, radius, info)

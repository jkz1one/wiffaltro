class_name BatSwingRegressionTest
extends RefCounted

static func run(host: Node, check: Callable) -> void:
	_test_batter_motion(host, check)
	_test_staged_mirrored_bat_path(check)
	_test_attack_plane(check)
	PlayabilityRegressionTest.run(check)

static func _test_batter_motion(host: Node, check: Callable) -> void:
	var profile: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	var batter: PlayerAvatar = PlayerAvatar.new()
	host.add_child(batter)
	batter.configure(
		PlayerAvatar.Role.BATTER,
		false,
		false,
		Color.WHITE
	)
	var ready_hand_z: float = batter._throw_hand.position.z
	batter.play_batting_swing(profile)
	batter._process(profile.sweet_spot_seconds)
	check.call(
		batter._throw_hand.position.z > ready_hand_z
		and batter._body_root.rotation.y > 0.0,
		"Batter hands and torso should drive with the independent bat actor"
	)
	batter.queue_free()


static func _test_staged_mirrored_bat_path(check: Callable) -> void:
	var profile: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	var slot_time: float = profile.sweet_spot_seconds * 0.45
	var extension_time: float = lerpf(
		profile.sweet_spot_seconds, profile.swing_duration_seconds, 0.35
	)
	var ready: Vector3 = BatActor.pivot_position_at_elapsed(
		false, 0.0, profile.sweet_spot_seconds, profile.swing_duration_seconds
	)
	var slot: Vector3 = BatActor.pivot_position_at_elapsed(
		false, slot_time, profile.sweet_spot_seconds, profile.swing_duration_seconds
	)
	var contact: Vector3 = BatActor.pivot_position_at_elapsed(
		false,
		profile.sweet_spot_seconds,
		profile.sweet_spot_seconds,
		profile.swing_duration_seconds
	)
	var extension: Vector3 = BatActor.pivot_position_at_elapsed(
		false, extension_time, profile.sweet_spot_seconds, profile.swing_duration_seconds
	)
	var finish: Vector3 = BatActor.pivot_position_at_elapsed(
		false,
		profile.swing_duration_seconds,
		profile.sweet_spot_seconds,
		profile.swing_duration_seconds
	)
	check.call(
		ready.z < slot.z
		and slot.z < contact.z
		and contact.z < extension.z
		and finish.z < extension.z
		and finish.y > contact.y,
		"the visible swing should slot, drive, extend through contact, then finish high"
	)
	var left_contact: Vector3 = BatActor.pivot_position_at_elapsed(
		true,
		profile.sweet_spot_seconds,
		profile.sweet_spot_seconds,
		profile.swing_duration_seconds
	)
	var right_yaw: float = BatActor.yaw_degrees_at_elapsed(
		false, extension_time, profile.sweet_spot_seconds, profile.swing_duration_seconds
	)
	var left_yaw: float = BatActor.yaw_degrees_at_elapsed(
		true, extension_time, profile.sweet_spot_seconds, profile.swing_duration_seconds
	)
	check.call(
		is_equal_approx(contact.x, -left_contact.x)
		and is_equal_approx(right_yaw, -left_yaw),
		"left- and right-handed swings should mirror the same back-to-front path"
	)
	var contact_phases: Vector2 = BatActor.phase_progress_at_elapsed(
		profile.sweet_spot_seconds,
		profile.sweet_spot_seconds,
		profile.swing_duration_seconds
	)
	check.call(
		BatActor.aim_influence_at_phases(contact_phases) >= 0.60,
		"subtle batting aim posture should remain visible through contact"
	)

static func _test_attack_plane(check: Callable) -> void:
	var profile: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	var intent: SwingIntent = SwingIntent.new()
	intent.aim_point = Vector2(0.0, 1.05)
	var early: Vector3 = ContactResolver.swing_center_position(
		profile.contact_window_start_seconds,
		intent,
		profile
	)
	var sweet: Vector3 = ContactResolver.swing_center_position(
		profile.sweet_spot_seconds,
		intent,
		profile
	)
	var late: Vector3 = ContactResolver.swing_center_position(
		profile.contact_window_end_seconds,
		intent,
		profile
	)
	check.call(
		early.y < intent.aim_point.y
		and is_equal_approx(sweet.y, intent.aim_point.y)
		and late.y > intent.aim_point.y
		and early.z < sweet.z
		and sweet.z < late.z,
		"the virtual barrel should travel upward through the aimed contact point"
	)

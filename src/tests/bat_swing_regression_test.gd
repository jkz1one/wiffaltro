class_name BatSwingRegressionTest
extends RefCounted

static func run(host: Node, check: Callable) -> void:
	_test_batter_motion(host, check)
	_test_attack_plane(check)

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

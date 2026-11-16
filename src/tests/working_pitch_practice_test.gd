extends Node
## Native interaction/pose assertions; visual batting feel remains separate.

const Practice = preload("res://src/labs/pitch_bat_lab/working_pitch_lab.gd")
const InputChecks = preload("res://src/tests/working_pitch_practice_input_checks.gd")
var _failures: Array[String] = []


func _ready() -> void:
	var lab = Practice.new()
	add_child(lab)
	await get_tree().process_frame
	_check(lab._working_picker.item_count == 41, "all 41 actual recipes are selectable")
	await InputChecks.new().run(lab, _check)
	await _test_reset_during_preparation(lab)
	for index: int in range(41):
		lab._choose_working_pitch(index)
		_check(lab._selected_pitch().id == WorkingPitchCatalog.recipes()[index].id,
			"selection retains exact recipe identity")
		lab._throw_pitch()
		_check(lab._pitch_actor.running
			and lab._pitch_actor.parameters.pitch_id == lab._selected_pitch().id,
			"selection launches the actual ordinary flight actor")
	var running: PitchLaunchParameters = lab._pitch_actor.parameters
	lab._choose_working_pitch(40)
	_check(lab._pitch_actor.parameters == running, "repeated selection does not interrupt a pitch")
	lab._choose_working_pitch(1000)
	_check(lab._selected_pitch_index == 40, "out-of-range selection has no effect")
	lab._cycle_working_pitch(1)
	_check(lab._selected_pitch_index == 0 and not lab._pitch_actor.running,
		"Next wraps all 41 and cancels only unfinished practice")
	lab._cycle_working_pitch(-1)
	_check(lab._selected_pitch_index == 40, "Previous wraps all 41")
	lab._toggle_match_mode()
	_check(not lab._match_mode, "private practice cannot activate a paid season")
	for label: String in WorkingPitchCatalog.SOURCE_STYLES:
		var id: String = WorkingPitchCatalog.SOURCE_STYLES[label].recipe
		lab._choose_working_pitch(WorkingPitchCatalog.ids().find(id))
		_check(lab._working_picker.tooltip_text.contains(label), "source style remains discoverable")
		_check(lab._working_picker.get_item_text(lab._selected_pitch_index).contains(label),
			"reviewed named style is visible in the selector")
	for old_id: String in WorkingPitchCatalog.RETIRED_ALIASES:
		_check(lab._choose_working_recipe(old_id), "retired selection has an explicit alias")
		_check(String(lab._selected_pitch().id) == WorkingPitchCatalog.canonical_id(old_id),
			"selection alone resolves to the unique named design")
	_check(not lab._choose_working_recipe("pitch.unknown"), "unknown selection fails closed")
	get_tree().root.size = Vector2i(700, 400)
	await get_tree().process_frame
	lab._layout_working_controls()
	var viewport_size: Vector2 = lab.get_viewport().get_visible_rect().size
	var rect: Rect2 = lab._working_panel.get_global_rect()
	_check(rect.position.x >= 0 and rect.end.x <= viewport_size.x, "compact selector remains onscreen")
	_check(lab._working_picker.get_popup().max_size.y <= maxi(150, int(viewport_size.y - 100)),
		"41-item popup is height bounded")
	_test_four_slots()
	lab.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("Working practice checks passed: 41 selections, "
			+ "viewport input/focus, interrupted/repeated flow, four slot poses.")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_reset_during_preparation(lab) -> void:
	# A synchronous control-flow fixture, separate from real-input/visual acceptance.
	lab._reset_lab()
	lab._throw_pitch()
	var actor: PitchFlightActor = lab._pitch_actor
	var active: bool = actor != null and actor.running and actor.visible
	_check(active, "reset fixture starts with a visible actual flight")
	if not active:
		lab._reset_lab()
		return
	var prior_throw: int = lab._throw_number
	var reset_calls: Array[int] = [0]
	var reset_on_hide: Callable = func() -> void:
		if not actor.visible:
			reset_calls[0] += 1
			lab._reset_lab()
	actor.visibility_changed.connect(reset_on_hide, CONNECT_ONE_SHOT)
	lab._request_lab_pitch()
	# If the signal did not fire, disconnect the fixture before any later cleanup.
	if actor.visibility_changed.is_connected(reset_on_hide):
		actor.visibility_changed.disconnect(reset_on_hide)
	var canceled: bool = (
		reset_calls[0] == 1 and lab._pitch_actor == actor
		and lab._at_bat_cadence.state == AtBatCadenceController.State.IDLE
		and not actor.running and lab._throw_number == prior_throw
		and lab._working_preparing_generation == -1
	)
	_check(canceled, "synchronous reset cancels the older request and releases its own latch")
	if not canceled:
		lab._reset_lab()
		return
	# Observe real frames beyond the maximum authored 3.53-second delivery.
	var quiet_deadline: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < quiet_deadline:
		await get_tree().process_frame
		if (lab._at_bat_cadence.state != AtBatCadenceController.State.IDLE
			or actor.running or lab._throw_number != prior_throw):
			canceled = false
			break
	_check(canceled, "reset leaves no delayed stale cadence or throw")
	if not canceled:
		lab._reset_lab()
		return
	var recipe: StringName = lab._selected_pitch().id
	lab._request_lab_pitch()
	var pending: bool = (
		lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY
		and not actor.running and lab._throw_number == prior_throw
		and lab._working_preparing_generation == -1
	)
	_check(pending, "a later fresh request starts its own windup after reset")
	if not pending:
		lab._reset_lab()
		return
	var started: int = Time.get_ticks_msec()
	while not actor.running and Time.get_ticks_msec() - started < 6000:
		if lab._at_bat_cadence.state != AtBatCadenceController.State.DELIVERY:
			break
		await get_tree().process_frame
	var elapsed_ms: int = Time.get_ticks_msec() - started
	_check(actor.running and elapsed_ms <= 6000 and actor.parameters != null
		and actor.parameters.pitch_id == recipe and lab._throw_number == prior_throw + 1,
		"fresh request releases exactly one actual selected-recipe flight within 6000 ms (%d ms)"
		% elapsed_ms)
	lab._reset_lab()


func _test_four_slots() -> void:
	for left: bool in [false, true]:
		var positions: Array[Vector3] = []
		for id: String in ["pitch.overhand_four_seam", "pitch.three_quarter_four_seam",
			"pitch.riser", "pitch.submarine_riser"]:
			var pitch: PitchDefinition = WorkingPitchCatalog.get_recipe(id)
			var avatar: PlayerAvatar = PlayerAvatar.new()
			add_child(avatar)
			avatar.configure(PlayerAvatar.Role.PITCHER, false, left, Color.WHITE)
			avatar.position = PitchBatLab.MOUND_ORIGIN
			var slot: int = pitch.delivery_profile.delivery
			var release: Vector3 = pitch.delivery_profile.release_offset_pitcher_frame_m
			var world: Vector3 = PitchBatLab.MOUND_ORIGIN + CoordinateFrame.pitcher_frame_vector(
				release.x, release.y, release.z, left)
			for progress: float in [0.0, 0.55, 1.0]:
				if slot == DeliveryProfileDefinition.Delivery.OVERHAND \
					or slot == DeliveryProfileDefinition.Delivery.SIDEARM:
					avatar.set_pitch_delivery_progress(
						progress, slot == DeliveryProfileDefinition.Delivery.SIDEARM)
				else:
					avatar.set_pitch_profile_progress(progress, pitch.delivery_profile, world)
				_check(avatar._throw_hand.global_position.is_finite(), "every pose is finite")
			if slot == DeliveryProfileDefinition.Delivery.THREE_QUARTER \
				or slot == DeliveryProfileDefinition.Delivery.SUBMARINE:
				_check(avatar._throw_hand.global_position.distance_to(world) < 0.00001,
					"new slot release hand meets exact authored launch")
			for prior: Vector3 in positions:
				_check(prior.distance_to(avatar._throw_hand.global_position) > 0.1,
					"all four delivery poses are distinct")
			positions.append(avatar._throw_hand.global_position)
			avatar.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

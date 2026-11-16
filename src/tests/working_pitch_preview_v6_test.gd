extends Node
## Native test for the additive private preview and its exact source registration.
## Observes real frames/input/flight. Does not qualify visuals, saves or paid access.

const Preview = preload("res://src/labs/pitch_bat_lab/working_pitch_preview_v6.gd")
const PreviewScene = preload("res://src/labs/pitch_bat_lab/working_pitch_preview_v6.tscn")
const Registry = preload("res://src/gameplay/pitching/working_pitch_catalog_registry.gd")
const InputChecks = preload("res://src/tests/working_pitch_practice_input_checks.gd")
var _failures: Array[String] = []

class RefusedPreview:
	extends "res://src/labs/pitch_bat_lab/working_pitch_preview_v6.gd"
	func _preview_requested_context() -> Dictionary:
		return {}  # Fault fixture, never a production fallback.


class PreparationChecks:
	extends "res://src/tests/working_pitch_practice_test.gd"
	func _ready() -> void:
		pass  # Reuse only the original synchronous preparation-reset fixture.


func _ready() -> void:
	var lab = PreviewScene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	_check(lab._preview_ready and not lab._preview_failed, "exact v6 host initializes")
	if not lab._preview_ready or lab._preview_failed:
		lab.queue_free()
		_finish()
		return
	_test_contexts(lab)
	var expected: Array[String] = WorkingPitchCatalog.ids()
	expected.append_array(Preview.EXTRA_IDS)
	_check(lab._working_picker.item_count == 43 and lab._working_options.size() == 43,
		"picker and detached options contain exactly 43 entries")
	for index: int in range(43):
		lab._choose_working_pitch(index)
		_check(String(lab._selected_pitch().id) == expected[index]
			and lab._working_picker.selected == index
			and lab._working_picker.get_item_text(index) == lab._working_label(lab._selected_pitch()),
			"picker row %d preserves the exact catalog order and visible identity" % index)
	_check(lab._working_note.text.contains("VERSION 6 PRIVATE PREVIEW"),
		"private preview is explicitly labeled")
	_check(lab._working_quit == null, "embedded host has no application-wide Quit button")
	lab._quit_working_practice()
	await get_tree().process_frame
	_check(is_instance_valid(lab) and lab.is_inside_tree(), "embedded Quit callback is a no-op")

	# Reuse the existing actual viewport/focus, popup, Space/echo, pause and F2 suite.
	var input = InputChecks.new()
	await input.run(lab, _check)
	_check(lab._preview_ready and not lab._preview_failed,
		"ordinary popup, paused and repeated-input refusal does not reject valid v6")
	for index: int in [41, 42]:
		await input._click(lab._working_picker)
		if not await input._choose_popup(index):
			continue
		var pitch: PitchDefinition = lab._selected_pitch()
		_check(String(pitch.id) == Preview.EXTRA_IDS[index - 41]
			and pitch.delivery_profile.delivery == DeliveryProfileDefinition.Delivery.SUBMARINE
			and is_equal_approx(pitch.delivery_profile.release_offset_pitcher_frame_m.y, 0.72),
			"new recipe uses its genuine authored Submarine delivery")
		await input._throw_from_focus("v6 recipe %d" % index)
		var launch: PitchLaunchParameters = lab._pitch_actor.parameters
		var release: Vector3 = pitch.delivery_profile.release_offset_pitcher_frame_m
		var expected_release: Vector3 = PitchBatLab.MOUND_ORIGIN + CoordinateFrame.pitcher_frame_vector(
			release.x, release.y, release.z, false)
		_check(launch != null and launch.pitch_id == pitch.id
			and launch.position.distance_to(expected_release) < 0.00001,
			"actual bounded windup launches selected v6 identity from authored Submarine release")
		lab._reset_lab()
	await _test_cancellation(lab)
	var preparation = PreparationChecks.new()
	add_child(preparation)
	await preparation._test_reset_during_preparation(lab)
	for failure: String in preparation._failures:
		_check(false, "inherited preparation regression: " + failure)
	preparation.queue_free()
	await get_tree().process_frame
	lab._toggle_match_mode()
	_check(not lab._match_mode and not lab._managed_match
		and lab._status_label.text.contains("Private practice only"), "match entry stays private-only")
	await _test_cross_context_release(lab)
	lab.queue_free()
	await get_tree().process_frame
	await _test_empty_options()
	await _test_initial_refusal()
	await _test_failure_boundaries()
	_finish()


func _test_contexts(lab) -> void:
	var context: Dictionary = lab._preview_context
	_check(Registry.valid_context(context) and context.version == 6
		and context.signature == Preview.PREVIEW_SIGNATURE,
		"native registry identity equals the current isolation-fix pin")
	_check(Registry.default_preview_context().version == 5 and WorkingPitchCatalog.ids().size() == 41,
		"default context and original catalog remain v5/41")
	_check(not lab._preview_context_valid(Registry.default_preview_context()),
		"otherwise valid v5 preview context is not v6")
	for value: Variant in [{}, null, {"version": 6.0, "signature": context.signature,
		"purpose": "isolated_preview"}, {"version": 6, "signature": "foreign",
		"purpose": "isolated_preview"}, {"version": 6, "signature": context.signature,
		"purpose": "career"}]:
		_check(not lab._preview_context_valid(value), "malformed, foreign or persistent context refuses")
	var detached: PitchDefinition = Registry.get_recipe(context, Preview.EXTRA_IDS[0])
	var selected: PitchDefinition = lab._working_options[41]
	_check(detached != selected and detached.delivery_profile != selected.delivery_profile,
		"consumer and registry reads do not alias recipe or nested delivery resources")


func _test_cancellation(lab) -> void:
	for mode: String in ["reset", "selection"]:
		lab._choose_working_pitch(41)
		lab._reset_lab()
		var before: int = lab._throw_number
		lab._request_lab_pitch()
		_check(lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY,
			mode + ": ordinary request enters windup")
		var generation: int = lab._working_request_generation
		lab._request_lab_pitch()
		_check(lab._working_request_generation == generation and lab._throw_number == before,
			mode + ": repeated request neither restarts nor queues windup")
		if mode == "reset":
			lab._reset_lab()
		else:
			lab._choose_working_pitch(42)
		var canceled: bool = true
		var deadline: int = Time.get_ticks_msec() + 4000
		while Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			if lab._pitch_actor.running or lab._throw_number != before \
				or lab._at_bat_cadence.state != AtBatCadenceController.State.IDLE:
				canceled = false
				break
		_check(canceled, mode + ": cancellation has no delayed flight beyond the authored windup")


func _test_cross_context_release(lab) -> void:
	lab._reset_lab()
	lab._choose_working_pitch(42)
	var before: int = lab._throw_number
	lab._request_lab_pitch()
	_check(lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY,
		"cross-context fixture begins a genuine ordinary windup")
	lab._preview_context = Registry.default_preview_context()
	var deadline: int = Time.get_ticks_msec() + 6000
	while not lab._preview_failed and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(lab._preview_failed and not lab._preview_ready and not lab._pitch_actor.running
		and lab._throw_number == before and lab.process_mode == Node.PROCESS_MODE_DISABLED
		and lab._pitch_actor.process_mode == Node.PROCESS_MODE_DISABLED,
		"context swapped during windup refuses at final release without v5 fallback")
	_check(lab._working_picker.disabled and lab._working_quit == null,
		"failed embedded preview disables selection and never acquires application Quit")


func _test_empty_options() -> void:
	var lab = PreviewScene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	_check(lab._preview_ready, "empty-options fixture first initializes normally")
	if lab._preview_ready:
		lab._working_options.clear()
		lab._refresh_config()
		_check(lab._preview_failed and not lab._working_delivery_admitted()
			and lab._working_picker.disabled, "empty options fail closed before selected-pitch dereference")
	lab.queue_free()
	await get_tree().process_frame


func _test_initial_refusal() -> void:
	var lab = RefusedPreview.new()
	add_child(lab)
	await get_tree().process_frame
	_check(lab._preview_failed and not lab._preview_base_started and lab._working_options.is_empty()
		and lab._working_picker.disabled and lab._working_quit == null,
		"invalid initial context shows a closed error state without starting v5 or exposing embedded Quit")
	lab._quit_working_practice()
	lab.queue_free()
	await get_tree().process_frame


func _test_failure_boundaries() -> void:
	var sibling: Node = Node.new()
	sibling.name = "UnrelatedHostSentinel"
	sibling.process_mode = Node.PROCESS_MODE_ALWAYS
	sibling.set_meta("sentinel", "unchanged")
	add_child(sibling)
	var external: Dictionary = {"parent_mode": process_mode, "tree_paused": get_tree().paused,
		"sibling_mode": sibling.process_mode, "sibling_parent": sibling.get_parent()}
	await _test_early_release_noop(sibling, external)
	await _test_startup_rejection(sibling, external)
	await _test_refresh_rejection(sibling, external)
	for fault: String in ["context", "options"]:
		await _test_space_admission_rejection(fault, sibling, external)
	sibling.queue_free()
	await get_tree().process_frame


func _test_early_release_noop(sibling: Node, external: Dictionary) -> void:
	var lab = PreviewScene.instantiate()
	var fired: Array[bool] = [false]
	var early_release: Callable = func(child: Node) -> void:
		if child.name == "PitchFlightActor" and not fired[0]:
			fired[0] = true
			lab._throw_pitch()
			lab._request_lab_pitch()
	lab.child_entered_tree.connect(early_release)
	add_child(lab)
	lab.child_entered_tree.disconnect(early_release)
	await get_tree().process_frame
	_check(fired[0] and lab._preview_ready and not lab._preview_failed
		and not lab._preview_initializing and lab._throw_number == 0
		and not lab._pitch_actor.running and lab._working_picker.item_count == 43,
		"actual startup release/request callbacks are non-admitting no-ops, not catalog failures")
	_assert_external_unchanged(sibling, external)
	lab.queue_free()
	await get_tree().process_frame


func _test_startup_rejection(sibling: Node, external: Dictionary) -> void:
	var lab = PreviewScene.instantiate()
	var fired: Array[bool] = [false]
	var reject_during_startup: Callable = func(child: Node) -> void:
		if child.name == "PitchFlightActor" and not fired[0]:
			fired[0] = true
			lab._preview_reject("first startup rejection")
			lab._preview_reject("later startup rejection must not replace the first")
	lab.child_entered_tree.connect(reject_during_startup)
	add_child(lab)
	lab.child_entered_tree.disconnect(reject_during_startup)
	await get_tree().process_frame
	_check(fired[0] and is_instance_valid(lab._primary_fielder)
		and is_instance_valid(lab._batter_avatar) and is_instance_valid(lab._bat_actor),
		"real inherited startup continued far enough to create late PAUSABLE children")
	_assert_terminal_failure(lab, "first startup rejection", 0, sibling, external)
	# An additional owned child proves repeatable finalization, without changing the first reason.
	var late: Node = Node.new()
	late.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab.add_child(late)
	lab._preview_reject("repeat finalization must preserve original evidence")
	_assert_terminal_failure(lab, "first startup rejection", 0, sibling, external)
	lab.queue_free()
	await get_tree().process_frame


func _test_refresh_rejection(sibling: Node, external: Dictionary) -> void:
	var lab = PreviewScene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	if not lab._preview_ready:
		_check(false, "refresh rejection fixture requires a committed preview")
		lab.queue_free()
		await get_tree().process_frame
		return
	var before: int = lab._throw_number
	var fired: Array[bool] = [false]
	lab._controls_label.hide()
	var reject_during_refresh: Callable = func() -> void:
		fired[0] = true
		lab._preview_reject("first inherited refresh rejection")
	lab._controls_label.visibility_changed.connect(reject_during_refresh, CONNECT_ONE_SHOT)
	lab._refresh_config()  # The genuine presentation refresh makes this label visible.
	await get_tree().process_frame
	_check(fired[0], "the inherited refresh actually emitted its synchronous visibility callback")
	_assert_terminal_failure(lab, "first inherited refresh rejection", before, sibling, external)
	lab.queue_free()
	await get_tree().process_frame


func _test_space_admission_rejection(fault: String, sibling: Node, external: Dictionary) -> void:
	var lab = PreviewScene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	if not lab._preview_ready:
		_check(false, fault + ": Space rejection fixture requires a committed preview")
		lab.queue_free()
		await get_tree().process_frame
		return
	lab._working_picker.grab_focus()
	await get_tree().process_frame
	var before: int = lab._throw_number
	var input = InputChecks.new()
	input._lab = lab
	input._tree = get_tree()
	input._check = _check
	if not await input._prepare_admission(fault + " admission setup"):
		lab.queue_free()
		await get_tree().process_frame
		return
	_check(lab._preview_ready and not lab._preview_failed,
		fault + ": healthy preview survives actual intro dismissal")
	if not lab._preview_ready or lab._preview_failed:
		lab.queue_free()
		await get_tree().process_frame
		return
	lab._working_picker.grab_focus()
	if fault == "context":
		lab._preview_context = Registry.default_preview_context()
	else:
		lab._working_options.clear()
	# No intervening refresh or direct request/reject: use actual focused Space input.
	await input._key(KEY_SPACE)
	await get_tree().process_frame
	_assert_terminal_failure(lab, "Version 6 preview validation failed before pitch admission.",
		before, sibling, external)
	lab.queue_free()
	await get_tree().process_frame


func _assert_terminal_failure(lab, reason: String, before: int,
	sibling: Node, external: Dictionary) -> void:
	_check(lab._preview_failed and not lab._preview_ready and not lab._preview_initializing
		and not lab._preview_finalizing and lab._preview_failure_reason == reason,
		"terminal failure remains sticky and internally consistent")
	_check(lab._throw_number == before and not lab._pitch_actor.running
		and lab._at_bat_cadence.state == AtBatCadenceController.State.IDLE,
		"terminal failure cancels cadence without flight or throw-count change")
	_check(lab._working_note.text == "VERSION 6 PRIVATE PREVIEW UNAVAILABLE\n" + reason
		and lab._working_picker.disabled and lab._working_quit == null
		and lab._working_panel.can_process() and lab._working_note.is_visible_in_tree(),
		"only the owned correct error UI remains active, with no embedded application Quit")
	var private_layer: CanvasLayer = lab._working_panel.get_parent() as CanvasLayer
	_check(_owned_gameplay_quiescent(lab, private_layer),
		"all owned gameplay descendants, including late explicit modes, are disabled")
	_check(not lab._working_delivery_admitted() and lab._preview_failure_reason == reason,
		"already-failed admission is a no-op preserving the first failure")
	_assert_external_unchanged(sibling, external)


func _owned_gameplay_quiescent(node: Node, private_layer: CanvasLayer) -> bool:
	if node == private_layer:
		return private_layer.process_mode == Node.PROCESS_MODE_ALWAYS and private_layer.visible
	if node.process_mode != Node.PROCESS_MODE_DISABLED:
		return false
	if node is CanvasLayer and node.visible:
		return false
	for child: Node in node.get_children():
		if not _owned_gameplay_quiescent(child, private_layer):
			return false
	return true


func _assert_external_unchanged(sibling: Node, external: Dictionary) -> void:
	_check(process_mode == external.parent_mode and get_tree().paused == external.tree_paused
		and is_instance_valid(sibling) and sibling.get_parent() == external.sibling_parent
		and sibling.process_mode == external.sibling_mode and sibling.get_meta("sentinel") == "unchanged",
		"failure changes no parent, sibling or external pause sentinel")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V6 private preview native checks passed; human visual acceptance remains separate.")
	get_tree().quit(0 if _failures.is_empty() else 1)

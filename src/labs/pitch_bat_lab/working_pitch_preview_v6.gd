extends "res://src/labs/pitch_bat_lab/working_pitch_lab.gd"
## Additive private consumer. No default selection, save, ownership or career hook.
## Native input tests and human visual acceptance are separate requirements.

const Registry = preload("res://src/gameplay/pitching/working_pitch_catalog_registry.gd")
# Strict source pin for the reviewed delivery-isolation revision.
const PREVIEW_SIGNATURE: String = "26d158816be97ced53ce52fb86a4f3def7b44ed6a95271e6c1043ef9216ac926"
const EXTRA_IDS: Array[String] = ["pitch.submarine_two_seam", "pitch.submarine_curveball"]
const PREVIEW_NOTE: String = "VERSION 6 PRIVATE PREVIEW • 43 recipes\nSPACE windup + throw • Tab/Enter choose\nNo paid season, ownership or mastery is granted."
var _preview_context: Dictionary = {}
var _preview_initializing: bool = false
var _preview_base_started: bool = false
var _preview_base_ready: bool = false
var _preview_ready: bool = false
var _preview_failed: bool = false
var _preview_failure_reason: String = ""
var _preview_finalizing: bool = false
var _preview_refresh_depth: int = 0
var _preview_lifetime: int = 0
var _preview_startup: Dictionary = {}


func _ready() -> void:
	if _preview_failed or _preview_base_started:
		_preview_reject("The private preview cannot restart an earlier lifetime.")
		return
	_preview_lifetime += 1
	_preview_startup = _preview_lifetime_snapshot()
	_match_mode = false
	if _managed_match or _automation != null or _configured_match != null:
		_preview_reject("This entry accepts isolated private practice only.")
		return
	_preview_context = _preview_requested_context()
	_preview_startup.context = _preview_context
	if not _preview_lifetime_current(_preview_startup):
		_preview_reject("The exact version 6 preview context is unavailable.")
		return
	var options: Array[PitchDefinition] = Registry.recipes(_preview_context)
	if not _preview_options_valid(options) or not _preview_lifetime_current(_preview_startup):
		_preview_reject("The complete 43-recipe preview is unavailable.")
		return
	_preview_initializing = true
	_preview_base_started = true
	super._ready()
	if not is_instance_valid(self):
		return
	# Rejection during base callbacks is sticky. Finalize only after the base has
	# finished creating its late children and its actual private controls.
	_preview_base_ready = _preview_host_complete()
	if not _preview_lifetime_current(_preview_startup) or not _preview_base_ready:
		_preview_abort_startup("The private practice host did not complete the same initialization.")
		return
	_working_options = options
	_selected_pitch_index = 0
	var publication: Dictionary = _preview_publication_snapshot()
	_working_picker.clear()
	if not _preview_publication_current(publication):
		_preview_abort_startup("The preview changed while rebuilding its picker.")
		return
	for pitch: PitchDefinition in options:
		_working_picker.add_item(_working_label(pitch))
		if not _preview_publication_current(publication):
			_preview_abort_startup("The preview changed while adding a picker row.")
			return
	_refresh_config()  # Required inherited refresh, still non-admitting.
	if not _preview_publication_current(publication) or _working_picker.item_count != 43:
		_preview_abort_startup("The preview changed during its final initialization refresh.")
		return
	_working_note.text = PREVIEW_NOTE
	if not _preview_publication_current(publication) or _working_picker.item_count != 43:
		_preview_abort_startup("The preview changed while publishing its controls.")
		return
	_preview_startup = {}
	_preview_initializing = false
	_preview_ready = true  # Last publication, with no callback-bearing work after it.


func _preview_abort_startup(reason: String) -> void:
	_preview_initializing = false
	_preview_reject(reason)


func _preview_lifetime_snapshot() -> Dictionary:
	return {"generation": _preview_lifetime, "tree": get_tree(), "parent": get_parent(),
		"context": _preview_context}


func _preview_lifetime_current(snapshot: Dictionary) -> bool:
	return (is_instance_valid(self) and is_inside_tree() and not is_queued_for_deletion()
		and not _preview_failed and snapshot.has("generation")
		and _preview_lifetime == snapshot.generation and get_tree() == snapshot.tree
		and get_parent() == snapshot.parent and is_same(_preview_context, snapshot.context)
		and _preview_context_valid(_preview_context))


func _preview_controls_owned() -> bool:
	return (is_instance_valid(_working_panel) and is_instance_valid(_working_picker)
		and is_instance_valid(_working_note) and is_ancestor_of(_working_panel)
		and _working_panel.get_parent() is CanvasLayer
		and _working_panel.get_parent().get_parent() == self
		and _working_picker.get_parent() == _working_panel
		and _working_note.get_parent() == _working_panel)


func _preview_host_complete() -> bool:
	return (is_inside_tree() and not is_queued_for_deletion() and _preview_controls_owned()
		and _match_state != null and _at_bat_cadence != null and _home_run != null
		and is_instance_valid(_pitch_actor) and is_ancestor_of(_pitch_actor)
		and is_instance_valid(_primary_fielder) and is_ancestor_of(_primary_fielder)
		and _field_definition != null and is_instance_valid(_status_label)
		and is_ancestor_of(_status_label))


func _preview_publication_snapshot() -> Dictionary:
	var snapshot: Dictionary = _preview_lifetime_snapshot()
	snapshot.merge({"picker": _working_picker, "panel": _working_panel, "note": _working_note,
		"options": _working_options, "actor": _pitch_actor, "state": _match_state,
		"cadence": _at_bat_cadence, "home": _home_run})
	return snapshot


func _preview_publication_current(snapshot: Dictionary) -> bool:
	return (_preview_lifetime_current(snapshot) and _preview_host_complete()
		and _working_picker == snapshot.picker and _working_panel == snapshot.panel
		and _working_note == snapshot.note and is_same(_working_options, snapshot.options)
		and _pitch_actor == snapshot.actor and _match_state == snapshot.state
		and _at_bat_cadence == snapshot.cadence and _home_run == snapshot.home
		and _preview_options_valid(_working_options))


func _preview_requested_context() -> Dictionary:
	return Registry.context_for_use(6, "isolated_preview")


func _preview_context_valid(value: Variant) -> bool:
	return (Registry.valid_context(value) and value.version == 6
		and value.signature == PREVIEW_SIGNATURE)


func _preview_options_valid(options: Array[PitchDefinition]) -> bool:
	var expected: Array[String] = WorkingPitchCatalog.ids()
	if expected.size() != 41:
		return false
	expected.append_array(EXTRA_IDS)
	if options.size() != expected.size():
		return false
	for index: int in range(options.size()):
		var pitch: PitchDefinition = options[index]
		if pitch == null or String(pitch.id) != expected[index] or pitch.delivery_profile == null:
			return false
		if index >= 41 and (pitch.delivery_profile.delivery != DeliveryProfileDefinition.Delivery.SUBMARINE
			or not is_equal_approx(pitch.delivery_profile.release_offset_pitcher_frame_m.y, 0.72)):
			return false
	return true


func _preview_usable() -> bool:
	return (_preview_ready and not _preview_failed and not _preview_initializing
		and _preview_context_valid(_preview_context) and _preview_options_valid(_working_options))


func _working_delivery_admitted() -> bool:
	# Initialization/already-failed state is a no-op, not another catalog error.
	if _preview_initializing or _preview_failed or not _preview_ready:
		return false
	if not _preview_usable():
		_preview_reject("Version 6 preview validation failed before pitch admission.")
		return false
	return super._working_delivery_admitted()  # Ordinary pause/popup guards do not reject the catalog.


func _throw_pitch() -> void:
	if _preview_initializing or _preview_failed or not _preview_ready:
		return
	# Recheck at actual release and preserve every original private/flight guard.
	if not _preview_usable():
		_preview_reject("Version 6 preview validation failed. No pitch was launched.")
		return
	if not super._working_delivery_admitted():
		return
	super._throw_pitch()


func _refresh_config() -> void:
	if _preview_failed:
		return
	if _preview_initializing:
		if not _preview_lifetime_current(_preview_startup):
			_preview_reject("The preview initialization lifetime changed during refresh.")
			return
		if _match_state != null and _config_label != null and not _working_options.is_empty():
			_preview_refresh_depth += 1
			super._refresh_config()
			_preview_refresh_depth -= 1
			if not _preview_lifetime_current(_preview_startup):
				_preview_reject("The preview initialization changed during inherited refresh.")
		return
	if not _preview_ready:
		return
	if not _preview_usable():
		_preview_reject("Version 6 preview validation failed. Reload the isolated preview.")
		return
	var publication: Dictionary = _preview_publication_snapshot()
	_preview_refresh_depth += 1
	super._refresh_config()
	_preview_refresh_depth -= 1
	if not _preview_publication_current(publication):
		_preview_reject("The preview changed during inherited refresh.")
		return
	_working_note.text = PREVIEW_NOTE
	if not _preview_publication_current(publication):
		_preview_reject("The preview changed while refreshing its controls.")


func _preview_reject(reason: String) -> void:
	if not _preview_failed:
		_preview_failure_reason = reason  # Preserve the first failure, including nested callbacks.
	_preview_failed = true
	_preview_ready = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if _preview_initializing or _preview_refresh_depth > 0 or _preview_finalizing:
		return  # The owning continuation finalizes after its synchronous callbacks unwind.
	_preview_finalize_failure()


func _preview_finalize_failure() -> void:
	if _preview_finalizing:
		return
	_preview_finalizing = true
	if _preview_base_ready and _preview_host_complete():
		_reset_lab()  # Reuse generation invalidation and ordinary cancellation.
	_preview_set_process_branch(self, Node.PROCESS_MODE_DISABLED)
	if not is_inside_tree() or is_queued_for_deletion():
		_preview_finalizing = false
		return
	if not _preview_controls_owned():
		# Never re-enable a replaced/foreign panel outside this preview's subtree.
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 8
		add_child(layer)
		_working_panel = VBoxContainer.new()
		layer.add_child(_working_panel)
		_working_note = Label.new()
		_working_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_working_panel.add_child(_working_note)
		_working_picker = OptionButton.new()
		_working_panel.add_child(_working_picker)
		_working_quit = null
		if not get_viewport().size_changed.is_connected(_layout_working_controls):
			get_viewport().size_changed.connect(_layout_working_controls)
	var private_layer: CanvasLayer = _working_panel.get_parent() as CanvasLayer
	_preview_set_process_branch(private_layer, Node.PROCESS_MODE_INHERIT)
	private_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	private_layer.show()
	_working_note.text = "VERSION 6 PRIVATE PREVIEW UNAVAILABLE\n" + _preview_failure_reason
	_working_picker.disabled = true
	_working_picker.get_popup().hide()
	for child: Node in _working_panel.get_children():
		if child is HBoxContainer:
			for button: Node in child.get_children():
				if button is BaseButton:
					button.disabled = true
	_layout_working_controls()
	_install_working_quit.call_deferred()
	_preview_finalizing = false  # A later finalization may rescan newly added owned children.


func _preview_set_process_branch(node: Node, mode: Node.ProcessMode) -> void:
	# Explicit PAUSABLE/ALWAYS child modes do not inherit a disabled root.
	node.process_mode = mode
	if mode == Node.PROCESS_MODE_DISABLED and node is CanvasLayer:
		node.hide()
	for child: Node in node.get_children():
		_preview_set_process_branch(child, mode)


func _install_working_quit() -> void:
	if is_instance_valid(_working_quit):
		return
	super._install_working_quit()  # Retains standalone-only, never embedded, exit.


func _exit_tree() -> void:
	_preview_lifetime += 1
	_preview_ready = false
	if _preview_base_started:
		super._exit_tree()

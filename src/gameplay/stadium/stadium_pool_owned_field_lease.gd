class_name StadiumPoolOwnedFieldLease
extends RefCounted
## Exact owned, supported-writer contract. NOT arbitrary native-write observation.
## Original full gameplay/Guard seals remain the launch/outcome/capture authority.
# gdlint: disable=max-returns

const POLICY: String = "PAID_POOL_OWNED_STATIC_FIELD_LEASE_v80"
const ANCESTOR_SCRIPTS: Array[String] = [
	"res://src/labs/pitch_bat_lab/pitch_bat_lab.gd",
	"res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd",
	"res://src/presentation/season/season_app.gd",
	"res://src/gameplay/simulation/physical_match_runner.gd",
	"res://src/gameplay/simulation/physical_round_worker.gd"
]
# Exact authored callback nodes inside the lab. Custom/test scripts never qualify.
const NATIVE_NODES: Array[String] = [
	"Node", "Node3D", "MeshInstance3D", "MultiMeshInstance3D", "CollisionShape3D",
	"CharacterBody3D", "RigidBody3D", "Camera3D", "WorldEnvironment",
	"DirectionalLight3D", "CanvasLayer", "Control", "Label", "Button", "Panel",
	"PanelContainer", "VBoxContainer", "HBoxContainer", "GridContainer",
	"MarginContainer", "ScrollContainer", "HSeparator", "VSeparator", "ColorRect",
	"TextureRect", "ProgressBar", "OptionButton", "TabBar", "PopupMenu",
	"ConfirmationDialog", "AcceptDialog", "Window", "AudioStreamPlayer"
]
const NODE_SCRIPTS: Array[String] = [
	"res://src/labs/pitch_bat_lab/pitch_bat_lab.gd",
	"res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd",
	"res://src/presentation/ball/pitch_flight_actor.gd",
	"res://src/presentation/ball/batted_ball_body.gd",
	"res://src/presentation/ball/ball_visibility.gd",
	"res://src/presentation/fielding/fielder_controller.gd",
	"res://src/presentation/players/player_avatar.gd",
	"res://src/presentation/equipment/bat_actor.gd",
	"res://src/tools/debug/trajectory_debug_draw.gd",
	"res://src/presentation/ui/match_scorebug.gd",
	"res://src/presentation/ui/pitch_feedback.gd",
	"res://src/presentation/ui/pitch_picker.gd",
	"res://src/presentation/ui/clubhouse_menu_stack.gd",
	"res://src/presentation/ui/pitch_bat_lab_pause_menu.gd",
	"res://src/presentation/ui/match_stats_panel.gd",
	"res://src/presentation/ui/match_roster_controls.gd",
	"res://src/presentation/ui/match_sponsor_controls.gd",
	"res://src/presentation/ui/match_jumpstart_controls.gd",
	"res://src/presentation/ui/match_sure_shot_controls.gd",
	"res://src/presentation/ui/match_tactical_controls.gd",
	"res://src/presentation/ui/play_sounds.gd"
]

var generation: int = 1
var phase: String = "INSTALLED"
var play_generation: int = 0
var decline: String = ""
var _property: WeakRef
var _lab: WeakRef
var _controller: WeakRef
var _token: WeakRef
var _match: WeakRef
var _ledger: WeakRef
var _field: WeakRef
var _runtime_field: WeakRef
var _policy: WeakRef
var _field_helper: WeakRef
var _prepared: WeakRef
var _model: WeakRef
var _carrier: WeakRef
var _model_pose: Transform3D
var _carrier_pose: Transform3D
var _water_bytes: PackedByteArray
var _source: String
var _tree: SceneTree
var _sealed: Dictionary = {}
var _bodies: Dictionary = {}
var _ancestors: Array[Dictionary] = []
var _play_nodes: Dictionary = {}
var _external_nodes: Dictionary = {}
var _active_nodes: Dictionary = {}
var _required_nodes: Dictionary = {}
var _retiring_nodes: Dictionary = {}
var _node_scripts: Array[Script] = []
var _guard: WeakRef
var _ball: WeakRef
var _resolver: WeakRef
var _state: WeakRef
var _armed: bool = false
var _issued: bool = false


static func capture(property: StadiumPoolOwnedProperty, lab: PitchBatLab,
	controller: StadiumPoolControllerActive) -> StadiumPoolOwnedFieldLease:
	if not _exact(property, "res://src/presentation/stadium/stadium_pool_owned_property.gd") \
		or not _exact(controller, "res://src/gameplay/stadium/stadium_pool_controller_active.gd") \
		or property._field_installation_retired or not property.full_capture_valid(lab) \
		or not StadiumPoolOwnedIntegrity.owner_scene_admitted(property.integrity_policy2) \
		or controller._bound_profile != property or lab.pool_controller_active != controller \
		or not _exact(controller._prepared,
			"res://src/gameplay/stadium/stadium_pool_model_preparation.gd") \
		or controller._prepared.context == null \
		or controller._prepared.context._owner_model_plan.is_empty() \
		or StadiumPoolOwnedIntegrity.owner_model_route(
			controller._prepared.context._owner_model_plan, controller._prepared.context) != 1 \
		or not _exact(lab._match_state, "res://src/gameplay/match/match_state.gd"):
		return null
	var result: StadiumPoolOwnedFieldLease = StadiumPoolOwnedFieldLease.new()
	result._property = weakref(property)
	result._lab = weakref(lab)
	result._controller = weakref(controller)
	result._token = weakref(property.entitlement)
	result._match = weakref(lab._match_state)
	result._ledger = weakref(lab._stadium_ledger)
	result._field = weakref(property.field)
	result._runtime_field = weakref(lab._field_definition)
	result._policy = weakref(property.integrity_policy2)
	result._field_helper = weakref(property._field_integrity_v68)
	result._prepared = weakref(controller._prepared)
	result._model = weakref(property.pool_model)
	var carrier: Node3D = property.pool_model.get_node_or_null(StadiumPoolInteriorV2.VOLUME_ID)
	if carrier == null or carrier.get_script() != null or carrier.get_class() != "Node3D":
		return null
	result._carrier = weakref(carrier)
	result._model_pose = property.pool_model.global_transform
	result._carrier_pose = carrier.global_transform
	result._water_bytes = var_to_bytes(carrier.get_meta("descriptor", {}))
	result._source = controller._source
	result._tree = lab.get_tree()
	for path: String in NODE_SCRIPTS:
		var script: GDScript = load(path) as GDScript
		if script == null or script.get_class() != "GDScript" or script.get_script() != null \
			or not script.has_source_code() \
			or script.source_code.sha256_text() != FileAccess.get_sha256(path):
			return null
		result._node_scripts.append(script)
	for record: Dictionary in property.integrity_policy2._owner_scene_nodes:
		var node: Node = record.ref.get_ref() as Node
		result._sealed[record.id] = result._membership_record(node)
	for body: StaticBody3D in lab.find_children("*", "StaticBody3D", true, false):
		result._bodies[body.get_instance_id()] = {"ref": weakref(body),
			"parent": weakref(body.get_parent()), "rid": body.get_rid(),
			"pose": body.global_transform, "world": body.get_world_3d(),
			"space": body.get_world_3d().space}
	var ancestor: Node = property.get_parent()
	while ancestor != null:
		var script: Script = ancestor.get_script()
		if script != null and (script.resource_path not in ANCESTOR_SCRIPTS \
			or script != load(script.resource_path)):
			return null
		result._ancestors.append(result._node_record(ancestor))
		result._required_nodes[ancestor.get_instance_id()] = true
		ancestor = ancestor.get_parent()
	# Cold classification includes internal children: no unregistered parent can hide
	# a later entrant. Unknown native internals deliberately keep the full route.
	for node: Node in result._subtree_nodes(lab):
		var id: int = node.get_instance_id()
		if not result._sealed.has(id):
			if not result._node_admitted(node):
				return null
			result._external_nodes[id] = result._membership_record(node)
			if node.get_script() != null or result._actor_member(node):
				result._active_nodes[id] = result._node_record(node)
				result._required_nodes[id] = true
	result._issued = true
	return result


func arm() -> bool:
	if _armed or phase != "INSTALLED" or _tree == null:
		return false
	if _tree.node_added.connect(_node_added) != OK \
		or _tree.node_removed.connect(_node_removed) != OK:
		revoke("STRUCTURAL_BINDING")
		return false
	for record: Dictionary in _sealed.values():
		var node: Node = record.ref.get_ref() as Node
		if node == null or node.child_order_changed.connect(_sealed_changed) != OK \
			or node.script_changed.connect(_sealed_changed) != OK \
			or node.tree_exiting.connect(_sealed_changed) != OK:
			revoke("SEALED_BINDING")
			return false
	for record: Dictionary in _external_nodes.values():
		var node: Node = record.ref.get_ref() as Node
		if node == null or not _watch_external(node):
			revoke("EXTERNAL_SCRIPT_BINDING")
			return false
	_armed = true
	return true


func revoke(reason: String) -> void:
	if phase == "REVOKED":
		return
	# Publish retirement before disconnecting anything or invoking other code.
	phase = "REVOKED"
	var property: StadiumPoolOwnedProperty = (
		_property.get_ref() as StadiumPoolOwnedProperty if _property != null else null)
	if _issued and _exact(property, "res://src/presentation/stadium/stadium_pool_owned_property.gd") \
		and property._owned_field_lease == self:
		property._field_installation_retired = true
	generation += 1
	decline = reason
	play_generation = 0
	_guard = null
	_ball = null
	_resolver = null
	_state = null
	_play_nodes.clear()
	if is_instance_valid(_tree):
		if _tree.node_added.is_connected(_node_added):
			_tree.node_added.disconnect(_node_added)
		if _tree.node_removed.is_connected(_node_removed):
			_tree.node_removed.disconnect(_node_removed)
	for record: Dictionary in _sealed.values():
		var node: Node = record.ref.get_ref() as Node
		if node != null:
			if node.child_order_changed.is_connected(_sealed_changed):
				node.child_order_changed.disconnect(_sealed_changed)
			if node.script_changed.is_connected(_sealed_changed):
				node.script_changed.disconnect(_sealed_changed)
			if node.tree_exiting.is_connected(_sealed_changed):
				node.tree_exiting.disconnect(_sealed_changed)
	for record: Dictionary in _external_nodes.values():
		var node: Node = record.ref.get_ref() as Node
		if node != null:
			_unwatch_external(node)
	_armed = false


func issued_for(property: StadiumPoolOwnedProperty, lab: PitchBatLab) -> bool:
	# Wrong/forged callers cannot retire somebody else's installation.
	return _issued and _property != null and _lab != null \
		and _property.get_ref() == property and _lab.get_ref() == lab \
		and _exact(self, "res://src/gameplay/stadium/stadium_pool_owned_field_lease.gd")


func valid_installation(property: StadiumPoolOwnedProperty, lab: PitchBatLab) -> bool:
	if not issued_for(property, lab) or phase != "INSTALLED":
		return false
	if generation != 1 or not _armed \
		or not _exact(property, "res://src/presentation/stadium/stadium_pool_owned_property.gd") \
		or property._owned_field_lease != self or not _alive(lab) \
		or not _exact(lab, "res://src/labs/pitch_bat_lab/pitch_bat_lab.gd"):
		revoke("INSTALLATION_BINDING_CHANGED")
		return false
	var controller: StadiumPoolControllerActive = _controller.get_ref()
	var valid: bool = (
		_alive(property) and not property._field_installation_retired
		and _exact(controller, "res://src/gameplay/stadium/stadium_pool_controller_active.gd")
		and controller._owned_field_lease == self and lab.pool_controller_active == controller
		and controller._bound_profile == property and controller._lab == lab
		and property.entitlement == _token.get_ref() and lab._match_state == _match.get_ref()
		and lab._stadium_ledger == _ledger.get_ref() and property.field == _field.get_ref()
		and lab._field_definition == _runtime_field.get_ref()
		and property.integrity_policy2 == _policy.get_ref()
		and property._field_integrity_v68 == _field_helper.get_ref()
		and controller._prepared == _prepared.get_ref() and controller._source == _source
		and _exact(controller._prepared, "res://src/gameplay/stadium/stadium_pool_model_preparation.gd")
		and _exact(controller._prepared.context, "res://src/gameplay/stadium/stadium_pool_interior_v2.gd")
		and _exact(property.entitlement, "res://src/gameplay/stadium/stadium_pool_owned_authority.gd")
		and _exact(lab._stadium_ledger, "res://src/gameplay/season/club_asset_ledger.gd")
		and _exact(property.field, "res://src/content/definitions/field_definition.gd")
		and _exact(lab._field_definition, "res://src/content/definitions/field_definition.gd")
		and _exact(property.integrity_policy2,
			"res://src/gameplay/stadium/stadium_pool_owned_integrity.gd")
		and _exact(property._field_integrity_v68,
			"res://src/gameplay/stadium/stadium_pool_owned_field_integrity.gd")
		and _exact(lab._match_state, "res://src/gameplay/match/match_state.gd")
		and _exact(lab._ball_play_resolver, "res://src/gameplay/ball_in_play/ball_play_resolver.gd")
		and _tree == lab.get_tree() and _tree.node_added.is_connected(_node_added)
		and _tree.node_removed.is_connected(_node_removed)
	)
	if not valid:
		revoke("INSTALLATION_BINDING_CHANGED")
		return false
	var previous: Node = property
	for record: Dictionary in _ancestors:
		var node: Node = record.ref.get_ref() as Node
		if not _record_valid(record) or previous.get_parent() != node:
			valid = false
		previous = node
		if not is_instance_valid(previous):
			break
	if is_instance_valid(previous) and previous.get_parent() != null:
		valid = false
	# Cheap script identity remains live even on native sealed descendants. Source
	# text/shape/topology collection is leased, never custom callback execution.
	for record: Dictionary in _sealed.values():
		if not _membership_valid(record):
			revoke("SEALED_MEMBERSHIP_OR_SCRIPT_CHANGED")
			return false
	for record: Dictionary in _external_nodes.values():
		var node: Node = record.ref.get_ref() as Node
		if not _membership_valid(record, _retiring_nodes.has(node.get_instance_id())
			if is_instance_valid(node) else false):
			revoke("EXTERNAL_MEMBERSHIP_OR_SCRIPT_CHANGED")
			return false
	for record: Dictionary in _active_nodes.values():
		if not _record_valid(record):
			revoke("ACTIVE_PROCESS_OR_PARENT_CHANGED")
			return false
	for record: Dictionary in _bodies.values():
		var body: StaticBody3D = record.ref.get_ref() as StaticBody3D
		if not _alive(body) or body.get_parent() != record.parent.get_ref() \
			or body.get_rid() != record.rid or body.global_transform != record.pose \
			or not _body_world_valid(body, record):
			valid = false
	if not valid:
		revoke("INSTALLATION_BINDING_CHANGED")
	return valid


func bind_play(controller: StadiumPoolControllerActive, guard: StadiumPoolWaterGuard) -> bool:
	if not _issued or _controller == null or controller != _controller.get_ref() \
		or _guard != null or not _exact(controller,
			"res://src/gameplay/stadium/stadium_pool_controller_active.gd") \
		or controller._guard != guard:
		return false
	var property: StadiumPoolOwnedProperty = _property.get_ref()
	var lab: PitchBatLab = _lab.get_ref()
	if not valid_installation(property, lab) \
		or not _exact(guard, "res://src/gameplay/stadium/stadium_pool_water_guard.gd") \
		or guard.generation != 0 or guard._active_awards or controller._guard != guard \
		or guard._context != controller._prepared.context \
		or guard._guard_body_plan.is_empty() \
		or StadiumPoolOwnedIntegrity.guard_body_request(guard._guard_body_plan, guard).is_empty() \
		or not _ball_resources_plain(guard) \
		or not property.valid_owner_full_ledger(lab) or not guard.valid() \
		or not _exact(guard._resolver, "res://src/gameplay/ball_in_play/ball_play_resolver.gd") \
		or not _exact(guard._state, "res://src/gameplay/ball_in_play/ball_play_state.gd"):
		revoke("FULL_LAUNCH_OR_DOMAIN_FAILED")
		return false
	_play_nodes.clear()
	for row: Array in controller._tree:
		var node: Node = instance_from_id(row[0]) as Node
		if not _sealed.has(row[0]):
			if not _node_admitted(node):
				revoke("CUSTOM_PLAY_DOMAIN")
				return false
			_play_nodes[row[0]] = _node_record(node)
			_play_nodes[row[0]]["required"] = _actor_member(node)
	_guard = weakref(guard)
	_ball = weakref(guard._ball)
	_resolver = weakref(guard._resolver)
	_state = weakref(guard._state)
	play_generation = controller.generation
	guard._owned_field_lease = self
	return true


func retire_play(controller: StadiumPoolControllerActive, guard: StadiumPoolWaterGuard) -> void:
	if not _issued or _controller == null:
		return
	if controller == _controller.get_ref() and _guard != null and _guard.get_ref() == guard:
		# Keep primitive membership/script watches until actual removal. The lab may
		# create its next ball before queue_free removes the retiring ball this frame.
		var ball: Node = _ball.get_ref() as Node if _ball != null else null
		for id: int in _external_nodes:
			var node: Node = _external_nodes[id].ref.get_ref() as Node
			if node != null and ball != null and (node == ball or ball.is_ancestor_of(node)):
				_retiring_nodes[id] = true
		_guard = null
		_ball = null
		_resolver = null
		_state = null
		play_generation = 0
		_play_nodes.clear()


func valid_play(controller: StadiumPoolControllerActive, guard: StadiumPoolWaterGuard) -> bool:
	# A retired launch cannot revive, and merely asking about it cannot poison the
	# still-installed field needed by the next ordinary ball.
	if not _issued or _guard == null or _controller == null \
		or _guard.get_ref() != guard or controller != _controller.get_ref():
		return false
	if not _exact(guard, "res://src/gameplay/stadium/stadium_pool_water_guard.gd") \
		or not _exact(controller, "res://src/gameplay/stadium/stadium_pool_controller_active.gd"):
		revoke("PLAY_SCRIPT_CHANGED")
		return false
	if not valid_installation(_property.get_ref(), _lab.get_ref()):
		return false
	var valid: bool = (
		controller == _controller.get_ref() and _guard != null and _guard.get_ref() == guard
		and _exact(guard, "res://src/gameplay/stadium/stadium_pool_water_guard.gd")
		and guard._owned_field_lease == self and controller._guard == guard
		and play_generation > 0 and controller.generation == play_generation
		and guard.generation == 1 and not guard._generation_invalid
		and _ball != null and guard._ball == _ball.get_ref() and controller._ball == _ball.get_ref()
		and _exact(guard._ball, "res://src/presentation/ball/batted_ball_body.gd")
		and _ball_resources_plain(guard)
		and _resolver != null and guard._resolver == _resolver.get_ref()
		and _state != null and guard._state == _state.get_ref() and controller._state == _state.get_ref()
		and guard._resolver == controller._lab._ball_play_resolver
		and _exact(guard._resolver, "res://src/gameplay/ball_in_play/ball_play_resolver.gd")
		and _exact(guard._state, "res://src/gameplay/ball_in_play/ball_play_state.gd")
		and guard._context == controller._prepared.context and guard._model == _model.get_ref()
		and guard._source == _source and guard._downstream == controller._sample
		and not guard._active_awards and guard._bodies.size() == _bodies.size()
	)
	if not valid:
		revoke("PLAY_BINDING_CHANGED")
		return false
	for record: Dictionary in _play_nodes.values():
		if not _record_valid(record):
			valid = false
	for id: int in _bodies:
		var entry: Dictionary = guard._bodies.get(id, {})
		var record: Dictionary = _bodies[id]
		if entry.is_empty() or entry.get("body") != record.ref.get_ref() \
			or entry.get("rid") != record.rid or entry.get("parent") != record.parent.get_ref() \
			or entry.get("pose") != record.pose:
			valid = false
	if not valid:
		revoke("PLAY_BINDING_CHANGED")
	return valid


func water_valid(interior: StadiumPoolInteriorV2, model: Node3D, source: String) -> bool:
	if not _issued or _property == null or _controller == null or _carrier == null:
		return false
	var property: StadiumPoolOwnedProperty = _property.get_ref()
	var controller: StadiumPoolControllerActive = _controller.get_ref()
	var carrier: Node3D = _carrier.get_ref()
	return (
		phase == "INSTALLED" and _exact(interior,
			"res://src/gameplay/stadium/stadium_pool_interior_v2.gd")
		and _exact(controller, "res://src/gameplay/stadium/stadium_pool_controller_active.gd")
		and _exact(controller._prepared, "res://src/gameplay/stadium/stadium_pool_model_preparation.gd")
		and interior == controller._prepared.context
		and not interior._invalidated and source == _source and interior._source == _source
		and _exact(property, "res://src/presentation/stadium/stadium_pool_owned_property.gd")
		and _alive(model) and model.get_script() == null \
		and model == _model.get_ref() and property.pool_model == model
		and model.get_parent() == property and model.global_transform == _model_pose
		and interior._model.get_ref() == model and interior._pose == _model_pose
		and _alive(carrier) and carrier.get_script() == null and carrier.get_parent() == model
		and model.get_node_or_null(StadiumPoolInteriorV2.VOLUME_ID) == carrier
		and interior._carrier.get_ref() == carrier and carrier.global_transform == _carrier_pose
		and var_to_bytes(carrier.get_meta("descriptor", {})) == _water_bytes
	)


func descriptor() -> Dictionary:
	# Only value data; no Node, Resource, WeakRef or writable internal container aliases.
	var ids: Array[int] = []
	for id: int in _bodies:
		ids.append(id)
	return {"policy": POLICY, "generation": generation, "phase": phase,
		"play_generation": play_generation, "static_body_ids": ids,
		"model_pose": _model_pose, "carrier_pose": _carrier_pose}


func _external_script_changed() -> void:
	revoke("EXTERNAL_SCRIPT_CHANGED")


func _sealed_changed() -> void:
	revoke("SEALED_TOPOLOGY_OR_SCRIPT_CHANGED")


func _node_added(node: Node) -> void:
	if phase != "INSTALLED":
		return
	var lab: Node = _lab.get_ref()
	var property: Node = _property.get_ref()
	if lab == null or not lab.is_ancestor_of(node):
		return
	# _enter_tree precedes this signal. Hot checks compare the OLD parent's count,
	# so reentry rejects before notification. Never refresh that parent here.
	# Classify the complete incoming subtree before accepting even its native root;
	# descendants have not necessarily entered the tree or run their callbacks yet.
	for incoming: Node in _subtree_nodes(node):
		if property.is_ancestor_of(incoming) or incoming is StaticBody3D:
			revoke("STATIC_MEMBERSHIP_ADDED")
			return
		if not _node_admitted(incoming, not incoming.is_inside_tree()):
			revoke("CUSTOM_NODE_ADDED")
			return
		if _guard != null and _actor_member(incoming):
			revoke("ACTIVE_ACTOR_TOPOLOGY_CHANGED")
			return
	var id: int = node.get_instance_id()
	if _external_nodes.has(id):
		revoke("MEMBERSHIP_REENTERED")
		return
	_external_nodes[id] = _membership_record(node)
	if not _watch_external(node):
		revoke("EXTERNAL_BINDING")
	elif _guard != null:
		_play_nodes[id] = _node_record(node)


func _node_removed(node: Node) -> void:
	if phase != "INSTALLED":
		return
	var id: int = node.get_instance_id()
	if _sealed.has(id) or _required_nodes.has(id) \
		or (_guard != null and _play_nodes.has(id) and _play_nodes[id].get("required", false)):
		revoke("STATIC_MEMBERSHIP_REMOVED")
	elif _external_nodes.has(id):
		_unwatch_external(node)
		_external_nodes.erase(id)
		_play_nodes.erase(id)
		_retiring_nodes.erase(id)
	# The native parent still contains this child here. Its later child_order_changed
	# event is the sole permitted refresh, after actual erasure/reparent completion.


func _external_children_changed(node: Node) -> void:
	if phase != "INSTALLED" or not _external_nodes.has(node.get_instance_id()):
		return
	# Event-driven finite membership accounting, never an authority/descriptor reseal.
	# Every child must have passed complete incoming-subtree admission first.
	for child: Node in node.get_children(true):
		var id: int = child.get_instance_id()
		var record: Dictionary = _sealed.get(id, _external_nodes.get(id, {}))
		if record.is_empty() or record.ref.get_ref() != child \
			or record.parent != node.get_instance_id() or child.get_script() != record.script:
			revoke("UNCLASSIFIED_CHILD_ORDER_CHANGED")
			return
	_external_nodes[node.get_instance_id()].children = node.get_child_count(true)


func _external_exiting(node: Node) -> void:
	var id: int = node.get_instance_id()
	if _required_nodes.has(id) or (_guard != null and _play_nodes.has(id) \
		and _play_nodes[id].get("required", false)):
		revoke("REQUIRED_NODE_EXITING")


func _watch_external(node: Node) -> bool:
	return node.script_changed.connect(_external_script_changed) == OK \
		and node.child_order_changed.connect(_external_children_changed.bind(node)) == OK \
		and node.tree_exiting.connect(_external_exiting.bind(node)) == OK


func _unwatch_external(node: Node) -> void:
	if node.script_changed.is_connected(_external_script_changed):
		node.script_changed.disconnect(_external_script_changed)
	if node.child_order_changed.is_connected(_external_children_changed.bind(node)):
		node.child_order_changed.disconnect(_external_children_changed.bind(node))
	if node.tree_exiting.is_connected(_external_exiting.bind(node)):
		node.tree_exiting.disconnect(_external_exiting.bind(node))


func _subtree_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	var index: int = 0
	while index < result.size():
		result.append_array(result[index].get_children(true))
		index += 1
	return result


func _membership_record(node: Node) -> Dictionary:
	return {"ref": weakref(node), "script": node.get_script(),
		"parent": node.get_parent().get_instance_id() if node.get_parent() != null else 0,
		"children": node.get_child_count(true),
		"process": [node.process_mode, node.process_priority,
			node.process_physics_priority, node.process_thread_group],
		"ui_timeout": node.get_signal_connection_list(&"timeout").duplicate(true)
			if node.get_class() == "Timer" else []}


func _membership_valid(record: Dictionary, retiring: bool = false) -> bool:
	var node: Node = record.ref.get_ref() as Node
	return is_instance_valid(node) and node.is_inside_tree() \
		and (retiring or not node.is_queued_for_deletion()) \
		and node.get_script() == record.script \
		and (node.get_parent().get_instance_id() if node.get_parent() != null else 0) == record.parent \
		and node.get_child_count(true) == record.children \
		and [node.process_mode, node.process_priority,
			node.process_physics_priority, node.process_thread_group] == record.process \
		and (node.get_class() != "Timer" \
			or (node.get_signal_connection_list(&"timeout") == record.ui_timeout \
				and (node.get_parent().get_class() != "TabBar" or _native_ui_internal(node))))


func _actor_member(node: Node) -> bool:
	var lab: PitchBatLab = _lab.get_ref()
	if not is_instance_valid(lab):
		return false
	for root: Node in [lab._pitch_actor, lab._primary_fielder, lab._pitcher_marker,
		lab._batted_ball]:
		if is_instance_valid(root) and (root == node or root.is_ancestor_of(node)):
			return true
	return false


func _body_world_valid(body: StaticBody3D, record: Dictionary) -> bool:
	var world: World3D = body.get_world_3d()
	return world != null and world == record.world and world.get_class() == "World3D" \
		and world.get_script() == null and world.space == record.space


func _node_admitted(node: Node, before_enter: bool = false) -> bool:
	if not is_instance_valid(node) \
		or (node.get_class() not in NATIVE_NODES and not _native_ui_internal(node)) \
		or (node.get_script() != null and node.get_script() not in _node_scripts) \
		or (not before_enter and not StadiumPoolOwnedIntegrity._owner_scene_plain_world(node)):
		return false
	var lab: PitchBatLab = _lab.get_ref()
	if node is RigidBody3D:
		return node == lab._batted_ball and _exact(node,
			"res://src/presentation/ball/batted_ball_body.gd")
	if node is CharacterBody3D:
		return node == lab._primary_fielder and _exact(node,
			"res://src/presentation/fielding/fielder_controller.gd")
	if node is CollisionShape3D and not _actor_member(node):
		return false
	return true


func _native_ui_internal(node: Node) -> bool:
	# Finite native children actually constructed by authored ScrollContainer /
	# OptionButton / TabBar UI. Native callbacks can reach trusted authored UI
	# refresh handlers. Unknown Timer/Area/animation domains stay rejected.
	if node.get_script() != null:
		return false
	var parent: Node = node.get_parent()
	if parent == null or parent.get_script() != null or parent.get_children().has(node):
		return false
	if node.get_class() in ["HScrollBar", "VScrollBar"]:
		return parent.get_class() == "ScrollContainer"
	if node.get_class() == "Timer":
		if parent.get_class() not in ["PopupMenu", "TabBar"]:
			return false
		var connections: Array[Dictionary] = node.get_signal_connection_list(&"timeout")
		if connections.size() != 1:
			return false
		var callback: Callable = connections[0].callable
		# callable_mp is custom even on a scriptless native parent. Do not require
		# a debug-only reflected method name; retain the exact captured inventory.
		if parent.get_class() == "TabBar" and (not (node as Timer).one_shot \
			or not callback.is_custom() or callback.get_unbound_arguments_count() != 0 \
			or callback.get_argument_count() != 0 or connections[0].flags != 0):
			return false
		return callback.is_valid() and callback.get_object() == parent \
			and callback.get_bound_arguments_count() == 0
	if node.get_class() not in ["LineEdit", "PopupMenuItems"]:
		return false
	while parent != null:
		if parent.get_script() != null:
			return false
		if parent.get_class() == "PopupMenu":
			return true
		if parent.get_class() not in ["VBoxContainer", "PanelContainer", "ScrollContainer"]:
			return false
		var grandparent: Node = parent.get_parent()
		if grandparent == null or grandparent.get_children().has(parent):
			return false
		parent = grandparent
	return false


func _ball_resources_plain(guard: StadiumPoolWaterGuard) -> bool:
	return is_instance_valid(guard._ball) and is_instance_valid(guard._ball_shape) \
		and guard._ball_shape.get_script() == null and guard._ball_resource != null \
		and guard._ball_resource.get_script() == null \
		and guard._ball.physics_material_override != null \
		and guard._ball.physics_material_override.get_class() == "PhysicsMaterial" \
		and guard._ball.physics_material_override.get_script() == null


func _node_record(node: Node) -> Dictionary:
	return {"ref": weakref(node), "parent": node.get_parent().get_instance_id()
		if node.get_parent() != null else 0, "script": node.get_script(),
		"process": [node.process_mode, node.process_priority,
			node.process_physics_priority, node.process_thread_group]}


func _record_valid(record: Dictionary) -> bool:
	var node: Node = record.ref.get_ref() as Node
	return _alive(node) and node.get_script() == record.script \
		and (node.get_parent().get_instance_id() if node.get_parent() != null else 0) == record.parent \
		and [node.process_mode, node.process_priority,
			node.process_physics_priority, node.process_thread_group] == record.process


static func _alive(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()


static func _exact(value: Object, path: String) -> bool:
	if not is_instance_valid(value):
		return false
	var script: Script = value.get_script()
	return script != null and script == load(path) and script.get_class() == "GDScript" \
		and script.get_script() == null

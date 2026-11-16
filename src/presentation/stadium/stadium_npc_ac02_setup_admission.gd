class_name StadiumNpcAc02SetupAdmission
extends RefCounted
## One setup call's monotone callback-closure witness, never an integrity/value cache.
## Every original cold read still runs. Unknown objects/edges only disable body admission.

const ENGINE_HASH: String = "7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3"
const NATIVE_NODES: Array[String] = [
	"Node3D", "StaticBody3D", "CollisionShape3D", "MeshInstance3D", "Label3D"
]
const MESHES: Array[String] = ["BoxMesh", "CylinderMesh", "CapsuleMesh", "SphereMesh", "ArrayMesh"]
const SHAPES: Array[String] = [
	"BoxShape3D", "ConvexPolygonShape3D", "CylinderShape3D", "CapsuleShape3D"
]
var closed: bool = true
var reason: String = "closed"
var _roots: Array[StadiumNpcPublicProperty] = []


func reject(why: String) -> void:
	if closed:
		closed = false
		reason = why


func begin(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	if Engine.is_editor_hint() or Engine.get_version_info().get("hash", "") != ENGINE_HASH:
		reject("unreviewed-engine")
		return
	if (
		not no_live_owners(lab, property)
		or not _exact(StadiumNpcAc02PublicConstruction.FIELD, FieldDefinition)
		or not plain_metadata(StadiumNpcAc02PublicConstruction.FIELD)
	):
		reject("setup-owners-or-live-state")
		return
	# Context validation precedes geometry. Never let its container serialization invoke
	# foreign scripts before the unchanged audit has begun recording read eligibility.
	for value: Variant in [
		lab._match_state.stadium,
		property.public_snapshot,
		property.public_assignments,
		property.public_final_assignment,
		property.public_fixture,
		lab._npc_season.npc_venues,
		lab._npc_season.final_venue,
		lab._npc_season.schedule,
		lab._npc_season.semifinals,
		lab._npc_season.final_fixture
	]:
		plain(value)
	add_root(property)


func add_root(property: StadiumNpcPublicProperty) -> void:
	if not closed:
		return
	if not _root_support(property):
		reject("unreviewed-property-support")
		return
	_roots.append(property)
	# Only native node identity/script/metadata reads here. Resource reflection and lazy
	# queries remain in the original traversal, where observe runs before each read.
	_tree(property)


func _tree(node: Node) -> void:
	if not closed:
		return
	observe(node)
	if not closed:
		return
	for key: StringName in node.get_meta_list():
		plain(node.get_meta(key))
	for child: Node in node.get_children():
		_tree(child)


func plain(value: Variant) -> void:
	if closed and not plain_data(value):
		reject("opaque-container-value")


static func plain_data(value: Variant, depth: int = 0) -> bool:
	if depth > 24 or value is Object or value is Callable or value is Signal or value is RID:
		return false
	if value is Array:
		for item: Variant in value:
			if not plain_data(item, depth + 1):
				return false
	elif value is Dictionary:
		for key: Variant in value:
			if not plain_data(key, depth + 1) or not plain_data(value[key], depth + 1):
				return false
	return true


static func plain_metadata(value: Variant) -> bool:
	if not value is Object or not is_instance_valid(value):
		return false
	for key: StringName in value.get_meta_list():
		if not plain_data(value.get_meta(key)):
			return false
	return true


func observe(value: Object) -> void:
	if not closed or value == null:
		return
	if not is_instance_valid(value):
		reject("invalid-object")
		return
	if value is Node:
		if not _node_slot(value as Node):
			reject("unreviewed-node-slot-or-script")
		return
	_observe_remaining_checks(value)


func _observe_remaining_checks(value: Object) -> void:
	if value.get_script() != null:
		reject("scripted-resource")
		return
	var native: String = value.get_class()
	if native not in MESHES and native not in SHAPES and native != "StandardMaterial3D":
		reject("unreviewed-native-resource")
		return
	for signal_info: Dictionary in value.get_signal_list():
		var edges: Array = value.get_signal_connection_list(signal_info.name)
		if edges.is_empty():
			continue
		var signal_name: String = String(signal_info.name)
		var expected_count: int = 2 if native in SHAPES else 1
		if edges.size() != expected_count:
			reject("resource-edge-count")
			return
		var methods: Array[String] = []
		for edge: Dictionary in edges:
			var callback: Callable = edge.callable
			var owner: Object = callback.get_object()
			if (
				int(edge.flags) != 0
				or not callback.is_valid()
				or not callback.is_custom()
				or not callback.get_bound_arguments().is_empty()
				or callback.get_unbound_arguments_count() != 0
				or not _leaf_owner(owner)
			):
				reject("resource-edge-callable-or-owner")
				return
			var method: String = String(callback.get_method())
			if native in MESHES:
				if (
					signal_name != "changed"
					or method != "MeshInstance3D::_mesh_changed"
					or owner.get_class() != "MeshInstance3D"
					or (owner as MeshInstance3D).mesh != value
				):
					reject("mesh-edge-slot")
			elif native == "StandardMaterial3D":
				if (
					signal_name != "property_list_changed"
					or method != "Object::notify_property_list_changed"
					or owner.get_class() != "MeshInstance3D"
					or (owner as MeshInstance3D).material_override != value
				):
					reject("material-edge-slot")
			else:
				if (
					signal_name != "changed"
					or owner.get_class() != "CollisionShape3D"
					or (owner as CollisionShape3D).shape != value
					or method not in ["Node3D::update_gizmos", "CollisionShape3D::_shape_changed"]
					or methods.has(method)
				):
					reject("shape-edge-slot")
			methods.append(method)


func _leaf_owner(value: Object) -> bool:
	if (
		not is_instance_valid(value)
		or not value is Node
		or value.get_script() != null
		or (value as Node).get_child_count() != 0
		or not _belongs(value as Node)
	):
		return false
	# The admitted native callbacks cannot forward to an arbitrary listener. In particular
	# notify_property_list_changed emits this owner's property_list_changed signal.
	for signal_info: Dictionary in value.get_signal_list():
		if not value.get_signal_connection_list(signal_info.name).is_empty():
			return false
	return true


func _belongs(node: Node) -> bool:
	for root: StadiumNpcPublicProperty in _roots:
		if is_instance_valid(root) and (node == root or root.is_ancestor_of(node)):
			return true
	return false


func _node_slot(node: Node) -> bool:
	if not _belongs(node):
		return false
	if node.get_script() == null:
		return node.get_class() in NATIVE_NODES
	return _node_slot_remaining_checks(node)


func _node_slot_remaining_checks(node: Node) -> bool:
	for root: StadiumNpcPublicProperty in _roots:
		if not is_instance_valid(root):
			continue
		var expected: Script = null
		if node == root:
			expected = StadiumNpcPublicProperty
		elif node == root.construction and node.get_parent() == root:
			expected = StadiumNpcAc02PublicConstruction
		elif node == root.boundary and node.get_parent() == root:
			expected = StadiumNpcAc02PublicBoundary
		elif node == root.receiver and node.get_parent() == root:
			expected = StadiumNpcAc02PublicReceiver
		if expected != null:
			return _exact(node, expected)
		if (
			node == root.construction.get_node_or_null("ClubBoundary")
			and node.get_parent() == root.construction
			and node == root.boundary.source
		):
			return _exact(node, StadiumNpcAc02PublicBoundarySource)
		var board: Variant = root.objects.get("npc:AC-02:r1:SCORE-SMALL")
		if (
			board is Node
			and is_instance_valid(board)
			and node == root.display
			and node == (board as Node).get_node_or_null("Visual/ScoreDisplay")
		):
			return _exact(node, StadiumNpcClubDisplayV1)
	return false


static func _exact(value: Variant, script: Script) -> bool:
	return value is Object and is_instance_valid(value) and value.get_script() == script


static func _reference(value: WeakRef, owner: Object) -> bool:
	return value != null and value.get_script() == null and value.get_ref() == owner


static func _root_support(property: StadiumNpcPublicProperty) -> bool:
	# Check every scripted target before accessing its fields or invoking its helpers.
	if (
		not _exact(property, StadiumNpcPublicProperty)
		or property.venue_id != "AC-02"
		or not _exact(property.construction, StadiumNpcAc02PublicConstruction)
		or not _exact(property.boundary, StadiumNpcAc02PublicBoundary)
		or not _exact(property.receiver, StadiumNpcAc02PublicReceiver)
		or not _exact(property.display, StadiumNpcClubDisplayV1)
		or not _exact(property.field, FieldDefinition)
		or not _exact(property.actor_cutaway, StadiumNpcRetainedActorCutaway)
		or not _exact(property.ball_readability, StadiumNpcRetainedBallReadability)
	):
		return false
	return (
		_exact(property.boundary.source, StadiumNpcAc02PublicBoundarySource)
		and _exact(property.boundary.graph, StadiumNpcAc02PublicGraph)
		and property.boundary.source.graph == property.boundary.graph
		and property.construction.field == property.field
		and property.receiver.flex_surface.is_empty()
	)


static func no_live_owners(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	if (
		not _exact(lab, PitchBatLab)
		or not _root_support(property)
		or not plain_metadata(property.field)
		or property.issued
		or property.suspended
		or property._checking
		or property._cleaning
		or not _reference(property.lab_ref, lab)
		or not lab.has_meta("stadium_property")
		or lab.get_meta("stadium_property") != property
		or lab.get_node_or_null("StarterFieldGeometry/HomeProperty") != property
		or not lab.is_inside_tree()
		or lab.get_tree().paused
		or lab._debug_paused
		or lab.get_tree().debug_collisions_hint
		or lab.get_tree().debug_navigation_hint
		or not _exact(lab._match_state, MatchState)
		or property.bound_state != lab._match_state
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or lab._batted_ball != null
		or not property.bound_balls.is_empty()
		or property.display._match != property.bound_state
		or not _exact(lab._npc_season, SeasonState)
		or property.public_season != lab._npc_season
		or (lab._npc_season.career != null and not _exact(lab._npc_season.career, ClubCareer))
		or (lab._automation != null and not _exact(lab._automation, MatchAutomation))
		or not _exact(lab.get_node_or_null("StarterFieldGeometry"), StarterFieldLabGeometry)
		or not _exact(lab._camera_director, StadiumNpcAc02PublicCamera)
		or property.presentation_director != lab._camera_director
		or not _reference(property.presentation_camera, lab._camera)
		or not _reference(lab._camera_director.lab_ref, lab)
		or not is_instance_valid(lab._camera)
		or lab._camera.get_class() != "Camera3D"
		or lab._camera.get_script() != null
		or lab.get_node_or_null("LabCamera") != lab._camera
		or lab._camera_director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY
		or not _exact(lab._camera_director.tracking_visibility, StadiumNpcAc02PublicVisibility)
	):
		return false
	var view: StadiumNpcAc02PublicVisibility = lab._camera_director.tracking_visibility
	if (
		view.property != property
		or not _exact(view._recipe, StadiumNpcAc02PublicGraph)
		or not _exact(view._wall_prisms, StadiumWallViewPrisms)
		or not _exact(property.ac02_guides, StadiumNpcAc02PublicGuides)
		or property.ac02_guides != property._ac02_guides_pin
	):
		return false
	var guides: StadiumNpcAc02PublicGuides = property.ac02_guides
	if (
		guides._retired
		or guides._suppressed
		or guides._guides.size() != 5
		or not _reference(guides._lab_ref, lab)
		or not _reference(guides._property_ref, property)
		or not _reference(guides._camera_ref, lab._camera)
		or not _reference(guides._host_ref, property.get_parent())
		or not _reference(guides._director_ref, lab._camera_director)
	):
		return false
	for row: Dictionary in guides._guides:
		if (
			not row.has_all(["node", "name", "bar", "mesh", "material", "pose"])
			or not row.node is WeakRef
			or row.node.get_script() != null
			or typeof(row.name) not in [TYPE_STRING, TYPE_STRING_NAME]
			or typeof(row.bar) != TYPE_BOOL
			or not row.mesh is Mesh
			or not row.material is StandardMaterial3D
			or not row.pose is Transform3D
		):
			return false
	if not guides.owners_intact():
		return false
	var readability: StadiumNpcRetainedBallReadability = property.ball_readability
	var cutaway: StadiumNpcRetainedActorCutaway = property.actor_cutaway
	if (
		cutaway.frozen
		or not cutaway.entries.is_empty()
		or not cutaway.last_hits.is_empty()
		or not plain_data(readability._details)
		or readability._ball != null
		or readability._camera != null
		or readability._visual != null
		or readability._source_mesh != null
		or readability._original != Transform3D.IDENTITY
		or readability._radius != StadiumNpcRetainedBallReadability.DEFAULT_RADIUS_M
	):
		return false
	# presentation_actors evaluates these arguments even with live=false.
	return (
		_exact(lab._batter_avatar, PlayerAvatar)
		and _exact(lab._pitcher_avatar, PlayerAvatar)
		and _exact(lab._bat_actor, BatActor)
		and _exact(lab._primary_fielder, FielderController)
		and _exact(lab._primary_fielder._avatar, PlayerAvatar)
		and _exact(lab._pitch_actor, PitchFlightActor)
		and _exact(lab._ball_play_resolver, BallPlayResolver)
	)


static func refresh_receiver(lab: PitchBatLab, force_visible: bool = false) -> Dictionary:
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if (
		property == null
		or property.get_script() != StadiumNpcPublicProperty
		or property.venue_id != "AC-02"
	):
		StadiumPropertyRuntime.refresh_receiver_visibility(lab, force_visible)
		return {"admitted": false, "reason": "ordinary-route"}
	# Preserve the original bridge's prefix before the first receiver audit.
	StadiumBaseMarkerVisibility.update(property, lab._camera, lab._batted_ball)
	return property.refresh_ac02_setup_receiver(lab, force_visible)

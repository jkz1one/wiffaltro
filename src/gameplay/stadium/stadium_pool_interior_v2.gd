class_name StadiumPoolInteriorV2
extends RefCounted
## Exact authored polygon-prism geometry. No sensor, motion query, or entry-time inference.

const VERSION: int = 2
const ID: String = "ST006-POLYGON-INTERIOR-v2"
const MODEL_ID: String = "ST006-ANNULAR-POOL-DB2-v2"
const VOLUME_ID: String = "ST006_WATER_VOLUME_v2"
const VOLUME_ROLE: String = "WATER_ANALYTIC_POLYGON_PRISM_V2"
const EPSILON_M: float = 0.00001
const SOURCE_PATHS: Array[String] = [
	"res://src/gameplay/stadium/stadium_pool_contract.gd",
	"res://src/gameplay/stadium/stadium_pool_party_asset_integrity.gd",
	"res://src/presentation/stadium/stadium_pool_models.gd",
	"res://src/gameplay/stadium/stadium_pool_interior_v2.gd",
	"res://src/presentation/stadium/stadium_pool_models_v2.gd"
]

var _model: WeakRef
var _carrier: WeakRef
var _parent_id: int = 0
var _source: String = ""
var _pose: Transform3D
var _snapshot: PackedByteArray
var _identities: PackedInt64Array
var _source_inputs: Dictionary = {}
var _invalidated: bool = false
var _owned_profile: WeakRef
var _owned_lab: WeakRef
# Cold eligibility/source plan, never a cached observation or successful result.
var _owner_model_plan: Dictionary = {}


static func vertices() -> PackedVector2Array:
	var result: PackedVector2Array = []
	for index: int in range(StadiumPoolContract.SEGMENTS):
		var point: Vector3 = StadiumPoolContract.point(StadiumPoolContract.INNER_RADIUS, 0, index)
		result.append(Vector2(point.x, point.z))
	return result


static func descriptor(source: String = "") -> Dictionary:
	return {
		"id": ID,
		"version": VERSION,
		"volume_id": VOLUME_ID,
		"kind": VOLUME_ROLE,
		"source_sha256": source,
		"vertices_xz": vertices(),
		"height_m": StadiumPoolContract.WATER_HEIGHT,
		"circumradius_m": StadiumPoolContract.INNER_RADIUS,
		"segments": StadiumPoolContract.SEGMENTS,
		"boundary_epsilon_m": EPSILON_M,
		"authoritative_geometry": "AUTHORED_POLYGON_TIMES_CLOSED_HEIGHT_INTERVAL",
		"physics_qualified": false
	}


static func capture(model: Node3D, expected_source: String) -> StadiumPoolInteriorV2:
	if (
		not is_instance_valid(model)
		or not model.is_inside_tree()
		or model.is_queued_for_deletion()
		or model.get_parent() == null
		or expected_source.length() != 64
		or expected_source != StadiumPoolPartyAssetIntegrity.source_sha256()
		or model.global_transform != StadiumPoolContract.placement()
	):
		return null
	var reference: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	if reference == null:
		return null
	reference.transform = StadiumPoolContract.placement()
	var matches: bool = StadiumPoolPartyAssetIntegrity.same_tree(model, reference)
	reference.free()
	if not matches:
		return null
	var carrier: Node3D = model.get_node_or_null(VOLUME_ID) as Node3D
	if carrier == null or carrier is CollisionObject3D:
		return null
	var context: StadiumPoolInteriorV2 = StadiumPoolInteriorV2.new()
	context._model = weakref(model)
	context._carrier = weakref(carrier)
	context._parent_id = model.get_parent().get_instance_id()
	context._source = expected_source
	context._pose = model.global_transform
	context._snapshot = var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(model))
	context._identities = _node_identities(model)
	for path: String in SOURCE_PATHS:
		context._source_inputs[path] = FileAccess.get_sha256(path)
	return context


static func capture_owned(
	model: Node3D, expected_source: String, property: StadiumPoolOwnedProperty, lab: PitchBatLab
) -> StadiumPoolInteriorV2:
	if (
		not is_instance_valid(property)
		or not property.full_capture_valid(lab)
		or property.pool_model != model
		or not is_instance_valid(model)
		or not model.is_inside_tree()
		or model.is_queued_for_deletion()
		or model.get_parent() == null
		or expected_source.length() != 64
		or expected_source != StadiumPoolPartyAssetIntegrity.source_sha256()
		or model.global_transform != property.admitted_pose()
	):
		return null
	var reference: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	if reference == null:
		return null
	reference.transform = property.admitted_pose()
	var matches: bool = StadiumPoolPartyAssetIntegrity.same_tree(model, reference)
	reference.free()
	if not matches:
		return null
	var carrier: Node3D = model.get_node_or_null(VOLUME_ID) as Node3D
	if carrier == null or carrier is CollisionObject3D:
		return null
	var context: StadiumPoolInteriorV2 = StadiumPoolInteriorV2.new()
	context._owned_profile = weakref(property)
	context._owned_lab = weakref(lab)
	context._model = weakref(model)
	context._carrier = weakref(carrier)
	context._parent_id = model.get_parent().get_instance_id()
	context._source = expected_source
	context._pose = model.global_transform
	context._snapshot = var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(model))
	context._identities = _node_identities(model)
	for path: String in SOURCE_PATHS:
		context._source_inputs[path] = FileAccess.get_sha256(path)
	context._owner_model_plan = StadiumPoolOwnedIntegrity.capture_owner_model_plan(
		context, property, lab)
	return context


func valid(model: Node3D, expected_source: String) -> bool:
	if _invalidated:
		return false
	var model_request: Dictionary = {}
	if not _owner_model_plan.is_empty():
		var route: int = StadiumPoolOwnedIntegrity.owner_model_route(_owner_model_plan, self)
		if route < 0:
			_invalidated = true
			return false
		if route == 1:
			model_request = {"plan": _owner_model_plan, "interior": self,
				"model": model, "combined": false}
	var bound: bool = (
		is_instance_valid(model)
		and _model != null
		and _carrier != null
		and _model.get_ref() == model
		and model.is_inside_tree()
		and not model.is_queued_for_deletion()
		and model.get_parent() != null
		and model.get_parent().get_instance_id() == _parent_id
		and expected_source == _source
		and model.global_transform == _pose
		and (_pose_authorized() if model_request.is_empty()
			else _pose_authorized_model(model_request))
		and model.get_node_or_null(VOLUME_ID) == _carrier.get_ref()
	)
	if bound and not model_request.get("combined", false):
		bound = (
			_node_identities(model) == _identities
			and _model_snapshot_valid(model)
		)
	if not bound:
		_invalidated = true
	return bound


func valid_guard_body(model: Node3D, expected_source: String,
	guard_request: Dictionary) -> bool:
	# Exact-only entry. Keep ordinary valid() byte-exact for custom subclasses.
	guard_request["observed"] = false
	guard_request["complete"] = false
	if guard_request.get("interior") != self or guard_request.get("model") != model \
		or guard_request.get("source") != expected_source:
		return valid(model, expected_source)
	if _invalidated:
		return false
	var model_request: Dictionary = {}
	if not _owner_model_plan.is_empty():
		var route: int = StadiumPoolOwnedIntegrity.owner_model_route(_owner_model_plan, self)
		if route < 0:
			_invalidated = true
			return false
		if route == 1:
			model_request = {"plan": _owner_model_plan, "interior": self,
				"model": model, "combined": false, "guard_request": guard_request}
	var bound: bool = (
		is_instance_valid(model)
		and _model != null
		and _carrier != null
		and _model.get_ref() == model
		and model.is_inside_tree()
		and not model.is_queued_for_deletion()
		and model.get_parent() != null
		and model.get_parent().get_instance_id() == _parent_id
		and expected_source == _source
		and model.global_transform == _pose
		and (_pose_authorized() if model_request.is_empty()
			else _pose_authorized_model(model_request))
		and model.get_node_or_null(VOLUME_ID) == _carrier.get_ref()
	)
	if bound and not model_request.get("combined", false):
		bound = (
			_node_identities(model) == _identities
			and _model_snapshot_valid(model)
		)
	if not guard_request.is_empty() and not StadiumPoolOwnedIntegrity._guard_body_source_current(
		guard_request.plan):
		guard_request.source_breach = true
	if not bound:
		_invalidated = true
	elif not guard_request.is_empty() and guard_request.get("observed", false) \
		and not guard_request.get("source_breach", false):
		# Only the successful combined observation plus the complete tail is a receipt.
		guard_request.complete = true
	return bound


func _pose_authorized() -> bool:
	if _owned_profile == null:
		return _pose == StadiumPoolContract.placement()
	var property: StadiumPoolOwnedProperty = _owned_profile.get_ref() as StadiumPoolOwnedProperty
	var lab: PitchBatLab = _owned_lab.get_ref() as PitchBatLab if _owned_lab != null else null
	return (
		is_instance_valid(property)
		and property.valid_owner(lab)
		and property.pool_model == _model.get_ref()
		and _pose == property.admitted_pose()
	)


func _pose_authorized_model(model_request: Dictionary) -> bool:
	# The preceding model binding reads retain their original position. If they
	# changed the domain, choose the old route before accessing owned context fields.
	var route: int = StadiumPoolOwnedIntegrity.owner_model_route(model_request.plan, self)
	if route < 0:
		return false
	if route == 0:
		return _pose_authorized()
	var property: StadiumPoolOwnedProperty = _owned_profile.get_ref() as StadiumPoolOwnedProperty
	var lab: PitchBatLab = _owned_lab.get_ref() as PitchBatLab if _owned_lab != null else null
	return (
		is_instance_valid(property)
		and property.valid_owner_model(lab, model_request)
		and property.pool_model == _model.get_ref()
		and _pose == property.admitted_pose()
	)


func sample(world_center: Vector3, radius: float) -> Dictionary:
	var model: Node3D = _model.get_ref() as Node3D if _model != null else null
	if not valid(model, _source) or not world_center.is_finite():
		return _invalid_sample("STALE_BINDING_OR_NONFINITE_CENTER")
	var result: Dictionary = sample_local(_pose.affine_inverse() * world_center, radius)
	result["model_instance"] = model.get_instance_id()
	result["volume_instance"] = _carrier.get_ref().get_instance_id()
	result["source_sha256"] = _source
	return result


func valid_owned_lease(model: Node3D, expected_source: String,
	lease: StadiumPoolOwnedFieldLease) -> bool:
	if get_script() != load("res://src/gameplay/stadium/stadium_pool_interior_v2.gd"):
		return false
	if _invalidated or lease == null \
		or lease.get_script() != load("res://src/gameplay/stadium/stadium_pool_owned_field_lease.gd"):
		return false
	var property: StadiumPoolOwnedProperty = _owned_profile.get_ref() \
		if _owned_profile != null else null
	var lab: PitchBatLab = _owned_lab.get_ref() if _owned_lab != null else null
	if not lease.issued_for(property, lab):
		return false
	var bound: bool = is_instance_valid(property) \
		and property.valid_owner_leased(lab, lease) \
		and lease.water_valid(self, model, expected_source)
	if not bound:
		_invalidated = true
		lease.revoke("LEASED_INTERIOR_CHANGED")
	return bound


func sample_owned_lease(world_center: Vector3, radius: float,
	lease: StadiumPoolOwnedFieldLease) -> Dictionary:
	var model: Node3D = _model.get_ref() as Node3D if _model != null else null
	if not valid_owned_lease(model, _source, lease) or not world_center.is_finite():
		return _invalid_sample("STALE_BINDING_OR_NONFINITE_CENTER")
	var result: Dictionary = sample_local(_pose.affine_inverse() * world_center, radius)
	result["model_instance"] = model.get_instance_id()
	result["volume_instance"] = _carrier.get_ref().get_instance_id()
	result["source_sha256"] = _source
	return result


func binding_receipt() -> Dictionary:
	return {
		"source_sha256": _source,
		"source_inputs": _source_inputs.duplicate(true),
		"volume_id": VOLUME_ID,
		"pose": _pose,
		"node_instances": _identities.duplicate(),
		"snapshot_sha256": _snapshot.hex_encode().sha256_text(),
		"snapshot_hash_encoding": "SHA256_OF_LOWERCASE_HEX_SNAPSHOT_BYTES",
		"invalidated": _invalidated
	}


static func sample_local(center: Vector3, radius: float) -> Dictionary:
	if not center.is_finite() or not is_finite(radius) or radius <= 0:
		return _invalid_sample("NONFINITE_CENTER_OR_INVALID_RADIUS")
	var polygon: PackedVector2Array = vertices()
	var point: Vector2 = Vector2(center.x, center.z)
	var inside: bool = true
	var horizontal_squared: float = INF
	for index: int in range(polygon.size()):
		var start: Vector2 = polygon[index]
		var edge: Vector2 = polygon[(index + 1) % polygon.size()] - start
		var offset: Vector2 = point - start
		if edge.cross(offset) < 0:
			inside = false
		var fraction: float = clampf(offset.dot(edge) / edge.length_squared(), 0, 1)
		var closest: Vector2 = start + edge * fraction
		horizontal_squared = minf(horizontal_squared, point.distance_squared_to(closest))
	if inside:
		horizontal_squared = 0
	var vertical: float = maxf(maxf(-center.y, center.y - StadiumPoolContract.WATER_HEIGHT), 0)
	var distance_squared: float = horizontal_squared + vertical * vertical
	var separation: float = sqrt(distance_squared) - radius
	if not is_finite(distance_squared) or not is_finite(separation):
		return _invalid_sample("DISTANCE_OVERFLOW")
	return {
		"valid": true,
		"volume_id": VOLUME_ID,
		"local_center": center,
		"radius_m": radius,
		"horizontal_distance_squared_m2": horizontal_squared,
		"vertical_distance_m": vertical,
		"distance_squared_m2": distance_squared,
		"separation_m": separation,
		"strict_overlap": separation < 0,
		"positive_overlap": separation < -EPSILON_M,
		"tangent_or_uncertain": absf(separation) <= EPSILON_M,
		"dry": separation > EPSILON_M,
		"entry_time_known": false,
		"interpretation": "CURRENT_SPHERE_VS_AUTHORED_POLYGON_PRISM_ONLY"
	}


static func _node_identities(node: Node) -> PackedInt64Array:
	var result: PackedInt64Array = [node.get_instance_id()]
	for child: Node in node.get_children(true):
		result.append_array(_node_identities(child))
	return result


static func _invalid_sample(reason: String) -> Dictionary:
	return {
		"valid": false,
		"positive_overlap": false,
		"strict_overlap": false,
		"tangent_or_uncertain": false,
		"dry": false,
		"volume_id": VOLUME_ID,
		"reason": reason,
		"entry_time_known": false
	}


func _model_snapshot_valid(model: Node3D) -> bool:
	if _owned_profile == null:
		return var_to_bytes(
			StadiumPoolPartyAssetIntegrity.snapshot(model)
		) == _snapshot
	var property: StadiumPoolOwnedProperty = _owned_profile.get_ref() as StadiumPoolOwnedProperty
	return (
		is_instance_valid(property) and property.integrity_policy2 != null
		and property.integrity_policy2.valid_model(model)
	)


func owned_integrity_policy() -> StadiumPoolOwnedIntegrity:
	var property: StadiumPoolOwnedProperty = (
		_owned_profile.get_ref() as StadiumPoolOwnedProperty if _owned_profile != null else null
	)
	return property.integrity_policy2 if is_instance_valid(property) else null

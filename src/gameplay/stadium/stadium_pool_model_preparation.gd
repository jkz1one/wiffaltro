class_name StadiumPoolModelPreparation
extends RefCounted
## Symmetric preflight for fresh-process controls. Live callbacks allocate no reference Nodes.

var context: StadiumPoolInteriorV2
var _model: Node3D
var _parent: Node
var _role: String
var _source: String
var _snapshot: PackedByteArray
var _identities: PackedInt64Array
var _owned_profile: WeakRef
var _owned_lab: WeakRef


static func capture(model: Node3D, role: String, source: String) -> StadiumPoolModelPreparation:
	if source != StadiumPoolPartyAssetIntegrity.source_sha256():
		return null
	var result: StadiumPoolModelPreparation = StadiumPoolModelPreparation.new()
	if role == StadiumPoolContract.LIVE:
		result.context = StadiumPoolInteriorV2.capture(model, source)
		if result.context == null:
			return null
	elif role == StadiumPoolContract.SCENERY:
		if not StadiumPoolContract.valid_binding(
			model, role, StadiumPoolContract.placement(), StadiumPoolContract.geometry(role)
		):
			return null
	elif role != "NO_POOL" or model != null:
		return null
	result._model = model
	result._parent = model.get_parent() if model != null else null
	result._role = role
	result._source = source
	if model != null:
		result._snapshot = var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(model))
		result._identities = StadiumPoolInteriorV2._node_identities(model)
	return result


static func capture_owned(
	property: StadiumPoolOwnedProperty, lab: PitchBatLab, source: String
) -> StadiumPoolModelPreparation:
	if not is_instance_valid(property) or not property.valid_owner(lab):
		return null
	var result: StadiumPoolModelPreparation = StadiumPoolModelPreparation.new()
	result.context = StadiumPoolInteriorV2.capture_owned(property.pool_model, source, property, lab)
	if result.context == null:
		return null
	result._owned_profile = weakref(property)
	result._owned_lab = weakref(lab)
	result._model = property.pool_model
	result._parent = property.pool_model.get_parent()
	result._role = StadiumPoolContract.LIVE
	result._source = source
	result._snapshot = var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(property.pool_model))
	result._identities = StadiumPoolInteriorV2._node_identities(property.pool_model)
	return result


func valid(model: Node3D, role: String, source: String) -> bool:
	if model != _model or role != _role or source != _source:
		return false
	if model == null:
		return role == "NO_POOL"
	if not is_instance_valid(model) or not model.is_inside_tree() or model.is_queued_for_deletion():
		return false
	if model.get_parent() != _parent or not _pose_valid(model):
		return false
	if role == StadiumPoolContract.LIVE and (context == null or not context.valid(model, source)):
		return false
	return (
		StadiumPoolInteriorV2._node_identities(model) == _identities
		and _model_snapshot_valid(model)
	)


func _pose_valid(model: Node3D) -> bool:
	if _owned_profile == null:
		return model.global_transform == StadiumPoolContract.placement()
	var property: StadiumPoolOwnedProperty = _owned_profile.get_ref() as StadiumPoolOwnedProperty
	var lab: PitchBatLab = _owned_lab.get_ref() as PitchBatLab if _owned_lab != null else null
	return (
		is_instance_valid(property)
		and property.valid_owner(lab)
		and property.pool_model == model
		and model.global_transform == property.admitted_pose()
	)


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

class_name StadiumPoolOwnedProperty
extends StadiumPoolBoundProperty
## Paid public Pool property. Ordinary receiver, surfaces and baseball remain authoritative.
# gdlint: disable=max-returns

const FIELD_LEASE_SCRIPT_PATH: String = (
	"res://src/gameplay/stadium/stadium_pool_owned_field_lease.gd"
)
const SELF_SCRIPT_PATH: String = (
	"res://src/presentation/stadium/stadium_pool_owned_property.gd"
)

var integrity_policy2: StadiumPoolOwnedIntegrity
var _field_integrity_v68: StadiumPoolOwnedFieldIntegrity
# One property-owned installed generation; null means initial full-route admission fallback.
var _owned_field_lease: StadiumPoolOwnedFieldLease
var _field_installation_sealed: bool = false
var _field_installation_retired: bool = false
var _field_lease_attempted: bool = false


func build_owned(lab: PitchBatLab, token: StadiumPoolOwnedAuthority) -> bool:
	if not StadiumPropertyGeometry.construction_target_allowed(self):
		return false
	if (
		token == null
		or lab == null
		or lab._match_state == null
		or not token.valid_for(lab, lab._match_state.stadium, "CONFIGURED")
	):
		return false
	entitlement = token
	_descriptor = token.descriptor()
	frozen_snapshot = lab._match_state.stadium.duplicate(true)
	_snapshot_bytes = var_to_bytes(frozen_snapshot)
	if not super.build(
		"backyard",
		StadiumPoolOwnedLayout.base(frozen_snapshot.layout),
		StadiumLayoutSnapshot.ownership(frozen_snapshot)
	):
		return false
	set_meta("property_signature", frozen_snapshot.geometry)
	pool_model = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	if pool_model == null:
		return false
	pool_model.transform = admitted_pose()
	add_child(pool_model)
	# Ownership is deliberately outside the immutable exact Pool model tree.
	objects[_descriptor.copy] = pool_model
	var template_wall: Node = get_node("TemplateBackWall")
	boundary = StadiumBoundaryRuntime.assemble(self) as StadiumBoundaryPrototype
	if is_instance_valid(template_wall) and template_wall.get_parent() == null:
		template_wall.free()  # Prospective off-tree removals cannot leak until a later frame.
	if boundary == null:
		return false
	receiver = StadiumPitchReceiver.new()
	receiver.name = "PitchReceiverPresentation"
	add_child(receiver)
	if not receiver.configure(objects[frozen_snapshot.layout.receiver], lab._sounds):
		return false
	ground_body = get_node_or_null("PropertyGround") as StaticBody3D
	if ground_body == null or not _ground_shape_exact():
		return false
	var reference: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	if reference == null:
		return false
	reference.transform = admitted_pose()
	var exact: bool = StadiumPoolPartyAssetIntegrity.same_tree(pool_model, reference)
	reference.free()
	if not exact:
		return false
	footprint = _owned_footprint(lab)
	if footprint.is_empty():
		return false
	_ground_bytes = var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(ground_body))
	_ground_ids = StadiumPoolInteriorV2._node_identities(ground_body)
	_boundary_bytes = _boundary_geometry()
	_boundary_ids = StadiumPoolInteriorV2._node_identities(boundary)
	_field_bytes = var_to_bytes(StadiumPoolPartyAssetIntegrity._value(field))
	_field_integrity_v68 = StadiumPoolOwnedFieldIntegrity.capture(field)
	_runtime_field = lab._field_definition
	_pool_ids = StadiumPoolInteriorV2._node_identities(pool_model)
	_receiver_id = receiver.get_instance_id()
	_chair_id = receiver.chair.get_instance_id()
	return true


func bind_owner(lab: PitchBatLab, host: StarterFieldLabGeometry) -> bool:
	if not super.bind_owner(lab, host):
		return false
	integrity_policy2 = StadiumPoolOwnedIntegrity.capture(
		lab, self, pool_model, boundary, ground_body, receiver.chair
	)
	if get_script() == load(SELF_SCRIPT_PATH):
		_field_installation_sealed = integrity_policy2 != null
	return integrity_policy2 != null


func install_owned_field_lease(lab: PitchBatLab, controller: StadiumPoolControllerActive) -> bool:
	if _field_lease_attempted or _field_installation_retired:
		return false
	_field_lease_attempted = true
	_owned_field_lease = StadiumPoolOwnedFieldLease.capture(self, lab, controller)
	if _owned_field_lease != null:
		controller._owned_field_lease = _owned_field_lease
		if not _owned_field_lease.arm():
			_owned_field_lease.revoke("INSTALL_BINDING_FAILED")
	return _owned_field_lease != null and _owned_field_lease.phase == "INSTALLED"


func revoke_owned_field(reason: String) -> void:
	_field_installation_retired = true
	if (
		_owned_field_lease != null
		and (
			_owned_field_lease.get_script()
			== load(FIELD_LEASE_SCRIPT_PATH)
		)
	):
		_owned_field_lease.revoke(reason)


func owned_field_boundary_valid(lab: PitchBatLab) -> bool:
	# Full callers still run their original gameplay/ledger oracle separately.
	return (
		not _field_installation_retired
		and (
			_owned_field_lease == null
			or (
				(
					_owned_field_lease.get_script()
					== load(FIELD_LEASE_SCRIPT_PATH)
				)
				and _owned_field_lease.valid_installation(self, lab)
			)
		)
	)


func valid_owner_leased(lab: PitchBatLab, lease: StadiumPoolOwnedFieldLease) -> bool:
	if (
		lease == null
		or (
			lease.get_script()
			!= load(FIELD_LEASE_SCRIPT_PATH)
		)
		or not lease.issued_for(self, lab)
	):
		return false
	var valid: bool = (
		lease.valid_installation(self, lab)
		and _policy_valid_owner(lab, false, false, {}, lease)
		and lease.water_valid(lease._prepared.get_ref().context, pool_model, lease._source)
	)
	if not valid:
		lease.revoke("LEASED_OWNER_CHANGED")
	return valid


func full_capture_valid(lab: PitchBatLab) -> bool:
	# Original full oracle against ORIGINAL installation bytes. Never refresh them.
	return (
		_policy_valid_owner(lab, true)
		and ledger_boundary_valid(lab)
		and integrity_policy2 != null
		and integrity_policy2.valid_inventory(lab)
	)


func ground_matches(body: StaticBody3D) -> bool:
	return _policy_ground_valid(body, false)


func _policy_ground_valid(body: StaticBody3D, full_capture: bool) -> bool:
	if full_capture:
		return super.ground_matches(body)
	return (
		is_instance_valid(body)
		and body == ground_body
		and body.get_parent() == self
		and body.is_inside_tree()
		and not body.is_queued_for_deletion()
		and StadiumPoolInteriorV2._node_identities(body) == _ground_ids
		and integrity_policy2 != null
		and integrity_policy2.valid_ground(body)
	)


func _policy_boundary_valid(full_capture: bool) -> bool:
	if full_capture:
		return _boundary_geometry() == _boundary_bytes
	return integrity_policy2 != null and integrity_policy2.valid_boundary(boundary)


func _policy_inventory_valid(lab: PitchBatLab, full_capture: bool) -> bool:
	if full_capture:
		return _static_inventory(lab) == _static_bytes
	return integrity_policy2 != null and integrity_policy2.valid_inventory(lab)


func _policy_scene_valid(
	lab: PitchBatLab, full_capture: bool, model_request: Dictionary = {}
) -> bool:
	if not model_request.is_empty():
		# Early owner guards may call custom code. Recheck the domain immediately
		# before the observation; a fallback must keep the later full model walk.
		var guard_request: Dictionary = model_request.get("guard_request", {})
		if not guard_request.is_empty():
			var guard_route: int = StadiumPoolOwnedIntegrity.guard_body_route(guard_request)
			if guard_route < 0:
				guard_request.source_breach = true
			if guard_route != 1:
				# Keep V74 context validation; only guard coverage is withdrawn.
				guard_request = {}
		var route: int = StadiumPoolOwnedIntegrity.owner_model_route(
			model_request.plan, model_request.interior
		)
		if route < 0:
			return false
		if route == 1:
			model_request.combined = true
			return StadiumPoolOwnedIntegrity.owner_scene_matches(
				integrity_policy2,
				lab,
				self,
				boundary,
				ground_body,
				_boundary_ids,
				_ground_ids,
				true,
				model_request.model,
				model_request.interior._identities,
				guard_request
			)
	if not full_capture and StadiumPoolOwnedIntegrity.owner_scene_admitted(integrity_policy2):
		return StadiumPoolOwnedIntegrity.owner_scene_matches(
			integrity_policy2, lab, self, boundary, ground_body, _boundary_ids, _ground_ids
		)
	# Original standalone/custom-helper dispatch and cold seals remain the fallback.
	return (
		StadiumPoolInteriorV2._node_identities(boundary) == _boundary_ids
		and _policy_boundary_valid(full_capture)
		and _policy_ground_valid(ground_body, full_capture)
		and _policy_inventory_valid(lab, full_capture)
	)


func valid_owner(lab: PitchBatLab) -> bool:
	return _policy_valid_owner(lab)


func valid_owner_model(lab: PitchBatLab, model_request: Dictionary) -> bool:
	# Explicit request-local entry; standalone, cold and full-ledger paths are unchanged.
	return _policy_valid_owner(lab, false, false, model_request)


func ledger_boundary_valid(lab: PitchBatLab) -> bool:
	return (
		entitlement is StadiumPoolOwnedAuthority
		and ((entitlement as StadiumPoolOwnedAuthority).full_valid_for(
			lab, frozen_snapshot, "INSTALLED"
		))
	)


func valid_owner_full_ledger(lab: PitchBatLab) -> bool:
	return _policy_valid_owner(lab, false, true) and ledger_boundary_valid(lab)


func valid_owner_full_fields(lab: PitchBatLab) -> bool:
	return _policy_valid_owner(lab, false, true)


func _policy_field_valid(value: FieldDefinition, full: bool) -> bool:
	# Cold validation retains its direct original oracle, never virtual helper dispatch.
	if full:
		if (
			_field_integrity_v68 != null
			and _field_integrity_v68.get_script() == StadiumPoolOwnedFieldIntegrity
			and not StadiumPoolOwnedFieldIntegrity.sources_current(_field_integrity_v68, value)
		):
			return false
		return var_to_bytes(StadiumPoolPartyAssetIntegrity._value(value)) == _field_bytes
	if (
		_field_integrity_v68 == null
		or _field_integrity_v68.get_script() != StadiumPoolOwnedFieldIntegrity
	):
		return var_to_bytes(StadiumPoolPartyAssetIntegrity._value(value)) == _field_bytes
	return _field_integrity_v68.matches(value, _field_bytes)


func _policy_valid_owner(
	lab: PitchBatLab,
	full_capture: bool = false,
	full_fields: bool = false,
	model_request: Dictionary = {},
	owned_lease: StadiumPoolOwnedFieldLease = null
) -> bool:
	if owned_lease != null and (owned_lease != _owned_field_lease or full_capture or full_fields):
		return false
	if (
		lab == null
		or lab.is_queued_for_deletion()
		or lab.get_script() != load("res://src/labs/pitch_bat_lab/pitch_bat_lab.gd")
		or get_script() != load(SELF_SCRIPT_PATH)
		or _lab_ref == null
		or _lab_ref.get_ref() != lab
		or _lab_parent == null
		or _lab_parent.get_ref() != lab.get_parent()
		or lab.get_parent() == null
		or lab.get_parent().process_thread_group != Node.PROCESS_THREAD_GROUP_INHERIT
		or _match_ref == null
		or _match_ref.get_ref() != lab._match_state
		or not lab._match_mode
		or lab._field_id != PitchBatLab.FIELD_ID
		or not is_inside_tree()
		or is_queued_for_deletion()
		or lab.global_transform != Transform3D.IDENTITY
		or global_transform != Transform3D.IDENTITY
		or not is_instance_valid(_host)
		or _host.is_queued_for_deletion()
		or _host.get_script() != load("res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd")
		or _host.get_parent() != lab
		or _host.global_transform != Transform3D.IDENTITY
		or get_parent() != _host
		or not lab.has_meta("stadium_property")
		or lab.get_meta("stadium_property") != self
		or not lab.has_meta("stadium_pool_owned_property")
		or lab.get_meta("stadium_pool_owned_property") != self
		or lab._match_state == null
		or not entitlement is StadiumPoolOwnedAuthority
		or not is_instance_valid(lab._pitch_actor)
		or not is_instance_valid(lab._pitcher_marker)
		or not is_instance_valid(lab._primary_fielder)
		or not is_instance_valid(lab._ball_play_resolver)
	):
		return false
	if (
		_actors(lab) != _actor_ids
		or _scripts(lab) != _actor_scripts
		or lab._primary_fielder.get_parent() != lab
		or lab._pitcher_marker.get_parent() != lab
		or lab._pitch_actor.get_parent() != lab
		or var_to_bytes(frozen_snapshot) != _snapshot_bytes
		or var_to_bytes(lab._match_state.stadium) != _snapshot_bytes
		or var_to_bytes(lab.get_meta("stadium_snapshot", {})) != _snapshot_bytes
		or entitlement.descriptor() != _descriptor
		or not entitlement.owns(lab, frozen_snapshot, self)
		or get_meta("property_signature", "") != frozen_snapshot.geometry
		or lab.get_meta("boundary_signature", "") != frozen_snapshot.boundary
	):
		return false
	if (
		not is_instance_valid(pool_model)
		or pool_model.get_parent() != self
		or (owned_lease == null and StadiumPoolInteriorV2._node_identities(pool_model) != _pool_ids)
		or pool_model.global_transform != admitted_pose()
		or objects.size() != 2
		or objects.get(_descriptor.copy) != pool_model
		or not is_instance_valid(receiver)
		or receiver.get_parent() != self
		or receiver.get_instance_id() != _receiver_id
		or (
			receiver.get_script()
			!= preload("res://src/presentation/stadium/stadium_pitch_receiver.gd")
		)
		or not is_instance_valid(receiver.chair)
		or receiver.chair.get_parent() != self
		or receiver.chair.get_instance_id() != _chair_id
		or receiver.chair != objects.get(frozen_snapshot.layout.receiver)
		or receiver.chair.transform != Transform3D(Basis.IDENTITY, StadiumStarterLayout.RECEIVER)
		or lab._pitch_actor.receiver_router != receiver.route
	):
		return false
	if (
		not is_instance_valid(boundary)
		or boundary.get_parent() != self
		or (
			boundary.get_script()
			!= preload("res://src/presentation/stadium/stadium_boundary_prototype.gd")
		)
		or boundary.transform != Transform3D.IDENTITY
	):
		return false
	return (
		(owned_lease != null or _policy_scene_valid(lab, full_capture, model_request))
		and field != null
		and lab._field_definition != null
		and lab._field_definition == _runtime_field
		and (owned_lease != null or _policy_field_valid(field, full_capture or full_fields))
		and (
			owned_lease != null
			or _policy_field_valid(lab._field_definition, full_capture or full_fields)
		)
		and lab._ball_play_resolver.segment_observer == StadiumBoundaryObserver.observe
		and lab._primary_fielder.stadium_boundary_clip == StadiumBoundaryGraph.clip
		and lab._primary_fielder.stadium_obstacles == route_obstacles()
	)


func route_obstacles() -> Array[Dictionary]:
	if _descriptor.is_empty():
		return []
	return [
		{
			"center": StadiumStarterLayout.RECEIVER,
			"radius": Vector2(0.30, 0.43).length() + StadiumDefenderRoutes.BODY_RADIUS,
			"copy": frozen_snapshot.layout.receiver
		},
		{
			"center": admitted_pose().origin,
			"radius": StadiumPoolBoundFootprint.ROUTE_RADIUS,
			"owned_pool": true,
			"copy": _descriptor.copy
		}
	]


func _owned_footprint(lab: PitchBatLab) -> Dictionary:
	if is_inside_tree() or transform != Transform3D.IDENTITY or field == null:
		return {}
	if (
		StadiumPoolPartyAssetIntegrity._value(field)
		!= StadiumPoolPartyAssetIntegrity._value(lab._field_definition)
	):
		return {}
	var checked: Dictionary = StadiumPoolOwnedFootprint.validate(admitted_pose(), tier, field)
	if checked.is_empty():
		return {}
	var center: Vector3 = admitted_pose().origin
	var reserved: AABB = StadiumPoolOwnedFootprint.reservation(admitted_pose())
	var obstacle: Array[Dictionary] = [
		{"center": center, "radius": StadiumPoolBoundFootprint.ROUTE_RADIUS}
	]
	if not is_instance_valid(lab._primary_fielder) or not is_instance_valid(lab._pitcher_marker):
		return {}
	for spawn: Vector3 in [
		lab._primary_fielder.global_position,
		lab._primary_fielder.anchor_position,
		lab._pitcher_marker.global_position
	]:
		if (
			not StadiumPoolBoundFootprint._defender_inside(spawn)
			or not StadiumDefenderRoutes.clear(spawn, spawn, obstacle)
		):
			return {}
	for id: String in ["Plate", "Mound"]:
		var marker: Node3D = get_node_or_null(NodePath(id))
		if (
			marker == null
			or marker is CollisionObject3D
			or marker.get_child_count() != 1
			or not marker.get_child(0) is MeshInstance3D
		):
			return {}
		var mesh: MeshInstance3D = marker.get_child(0)
		if (
			not mesh.mesh is BoxMesh
			or reserved.intersects(marker.transform * AABB(-mesh.mesh.size / 2, mesh.mesh.size))
		):
			return {}
	var painted_overlaps: Array[String] = []
	for id: String in ["Safe", "Deep", "FoulLine-1", "FoulLine1"]:
		var guide: Node3D = get_node_or_null(NodePath(id))
		if (
			guide == null
			or guide is CollisionObject3D
			or guide.get_child_count() != 1
			or not guide.get_child(0) is MeshInstance3D
		):
			return {}
		var mesh: MeshInstance3D = guide.get_child(0)
		if (
			not mesh.mesh is BoxMesh
			or guide.position.y > 0.025
			or mesh.mesh.size.y != Vector3(0, 0.025, 0).y
		):
			return {}
		var half: Vector3 = Vector3(mesh.mesh.size.x / 2, 0, 0)
		var width: float = mesh.mesh.size.z / 2
		if id.begins_with("FoulLine"):
			half = Vector3(0, 0, mesh.mesh.size.z / 2)
			width = mesh.mesh.size.x / 2
		if (
			DefenderSpacing.segment_distance_xz(
				center, guide.transform * -half, guide.transform * half
			)
			<= StadiumPoolContract.RESERVATION_RADIUS + width
		):
			painted_overlaps.append(id)
	checked["painted_guide_overlaps"] = painted_overlaps
	checked["painted_guide_policy"] = "RETAIN_NONCOLLIDING_ORDINARY_PAINT_BELOW_PROP"
	return checked


func admitted_pose() -> Transform3D:
	return StadiumPoolOwnedLayout.pose(frozen_snapshot.get("layout", {}))


func _exit_tree() -> void:
	if not restoring:
		StadiumPoolOwnedExtension.property_exiting(self)

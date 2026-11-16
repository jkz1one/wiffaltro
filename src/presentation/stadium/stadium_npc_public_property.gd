# gdlint: disable=max-returns,max-public-methods,max-file-lines
class_name StadiumNpcPublicProperty
extends StadiumNpcRetainedProperty

const AC02_PASSIVE_2 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Public-only authority and lifecycle around unchanged retained presentation/contact mechanics.
## Issued ordinary play trusts static installation until a supported writer retires it.
## Cold diagnostics keep full source/geometry audits; dynamic owners remain fresh.

var bound_state: MatchState
var public_bound: bool = true
var public_snapshot: Dictionary = {}
var public_season: SeasonState
var public_assignments: Dictionary = {}
var public_final_assignment: Dictionary = {}
var environment_lease: Dictionary = {}
var public_fixture: Dictionary = {}
var public_automation: MatchAutomation
var public_managed: bool = false
var old_receiver: Callable
var suspended: bool = false
var issued: bool = false
var retirement_reason: String = ""
var hillside_support: StadiumHillsidePublicSupport
var ae02_actors: StadiumNpcAe02PublicActors
var ac02_guides: StadiumNpcAc02PublicGuides

var _hillside_support_pin: StadiumHillsidePublicSupport
var _hillside_scorebug: MatchScorebug
# Runtime-only issuance state; never persisted or used by any historical family.
var _ac02_issue: StadiumNpcAc02IssuedStateV1
var _ac02_issue_pin: StadiumNpcAc02IssuedStateV1
var _ac02_issued_once: bool = false
var _ac02_generation: int = 0
var _ac02_preparing: bool = false
var _ac02_preparation_failed: bool = false
var _ac02_factory_origin: Array = []
var _ac02_factory_origin_pin: Array = []
var _checking: bool = false
var _cleaning: bool = false
var _host: Node3D
var _actor: PitchFlightActor
var _resolver: BallPlayResolver
var _fielder: FielderController
var _camera: Camera3D
var _sounds: PlaySounds
var _release: PitchReleaseController
var _cadence: AtBatCadenceController
var _support: Array = []
var _members: Dictionary = {}
var _field_values: Dictionary = {}
var _nodes: Array[Dictionary] = []
var _issued_nodes: Array[Dictionary] = []
var _receiver_meshes: Dictionary = {}
var _bodies: Dictionary = {}
var _resources: Array[Resource] = []
var _gardens_time_resources: Array[Resource] = []
# Pool-only native shape setters for these fields do not emit Resource.changed.
# Freeze the captured handles/values once; callbacks always read actual current values.
var _pool_shape_parameters: Array[Dictionary] = []
var _pool_shape_parameters_pin: Array[Dictionary] = []
var _visibility_pin: Array = []
var _host_count: int = -1
var _contact_dispatch: bool = false
var _boundary_pin: Array = []
var _route_pin: Array[Dictionary] = []
var _ae02_actors_pin: StadiumNpcAe02PublicActors
var _ac02_guides_pin: StadiumNpcAc02PublicGuides
var _ae02_cone_study_pin: RefCounted
var _ae02_cone_script: Script


var _ac02_startup_attempt: RefCounted
var _ac02_startup_enrolled: bool = false
var _ac02_startup_committed: bool = false

func route_obstacles() -> Array[Dictionary]:
	return construction.route_obstacles() \
		if venue_id in ["AE-02", "AC-02", "AM-01", "AM-02", "LONG-YARD", "GRAND-I",
			"GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"] else (
		super.route_obstacles())


func view_graph() -> StadiumRecipeBoundary:
	if venue_id == "HILLSIDE":
		return construction.boundary.graph
	if venue_id == "POOL-PARTY":
		return StadiumTimberDugoutBoundary.candidate("straight")
	if venue_id == "GRAND-III":
		return StadiumDugoutBoundary.candidate("straight")
	if venue_id == "GRAND-II":
		return StadiumDugoutBoundary.candidate("straight")
	if venue_id == "GRAND-I":
		return StadiumDugoutBoundary.candidate("straight")
	if venue_id == "LONG-YARD":
		return StadiumDugoutBoundary.candidate("deeper_center")
	if venue_id == "AC-02":
		return StadiumNpcAc02PublicGraph.new()
	if venue_id == "AM-02":
		return StadiumNpcMogulTwoV1.TemplateView.new()
	return StadiumNpcMogulOneV1.TemplateView.new() if venue_id == "AM-01" else super.view_graph()


func pin_lab(lab: PitchBatLab) -> void:
	lab_ref = weakref(lab)
	_host = lab.get_node("StarterFieldGeometry")
	if venue_id == "HILLSIDE":
		_hillside_support_pin = hillside_support
		_hillside_scorebug = lab._scorebug
	_actor = lab._pitch_actor
	_resolver = lab._ball_play_resolver
	_fielder = lab._primary_fielder
	_camera = lab._camera
	_sounds = lab._sounds
	_release = lab._release_controller
	_cadence = lab._at_bat_cadence
	_support = [construction, boundary, field, receiver, display, actor_cutaway, ball_readability,
		presentation_director, presentation_director.tracking_visibility]
	if venue_id == "AC-02":
		_ac02_guides_pin = ac02_guides
	if venue_id == "AE-02":
		_ae02_actors_pin = ae02_actors
		_ae02_cone_study_pin = ae02_actors.cone_study
		_ae02_cone_script = ae02_actors.cone_study.get_script()
	_members = objects.duplicate()
	_boundary_pin = _boundary_data()
	for key: String in StadiumNpcYardV1.FIELD:
		_field_values[key] = field.get(key)


func support_intact(strict: bool = true) -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property.support_intact")
	var ac02_result: bool = _ac02_passive_02_support_intact(strict)
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_support_intact(strict: bool = true) -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if not is_instance_valid(lab) or not is_instance_valid(presentation_director) \
		or not is_instance_valid(actor_cutaway) or not is_instance_valid(ball_readability) \
		or not is_instance_valid(construction) or not is_instance_valid(boundary) \
		or _support != [construction, boundary, field, receiver,
		display, actor_cutaway, ball_readability, presentation_director,
		presentation_director.tracking_visibility] or not StadiumNpcPublicRuntime._references(self) \
		or not is_instance_valid(field) or field.get_script() != FieldDefinition \
		or field != construction.field \
		or (strict and (objects != _members or construction.objects != _members)) \
		or tier != {"AY-01": "backyard", "AE-01": "expanded", "AE-02": "expanded",
			"AC-01": "club", "AC-02": "club",
			"AM-01": "mogul", "AM-02": "mogul", "LONG-YARD": "club",
				"GRAND-I": "mogul", "GRAND-II": "mogul", "GRAND-III": "mogul",
					"POOL-PARTY": "expanded", "HILLSIDE": "expanded"}.get(venue_id) \
		or construction.tier != tier \
		or _actor != lab._pitch_actor or _resolver != lab._ball_play_resolver \
		or _fielder != lab._primary_fielder or _camera != lab._camera or _sounds != lab._sounds \
		or _release != lab._release_controller or _cadence != lab._at_bat_cadence \
		or actor_cutaway.get_script() != StadiumNpcRetainedActorCutaway \
		or ball_readability.get_script() != StadiumNpcRetainedBallReadability \
		or not _boundary_intact(strict) or not _ae02_support_intact() or not _ac02_support_intact() \
		or not _environment_intact(lab) or not _hillside_support_intact():
		return false
	for key: String in _field_values:
		if typeof(field.get(key)) != typeof(_field_values[key]) or field.get(key) != _field_values[key]:
			return false
	if venue_id == "AY-01":
		return receiver == null and display == null and lab._camera_director == old_camera
	var prefix: String = StadiumNpcPublicRuntime.identity_prefix(venue_id)
	return is_instance_valid(receiver) and receiver.get_parent() == self \
		and receiver.chair == objects.get(prefix + "RECEIVER-PRIMARY") \
		and receiver.net == objects.get(prefix + "RECEIVER-CATCH") \
		and receiver.sounds == lab._sounds and score_display_intact(true) \
		and lab._camera_director.camera_mask == 80 \
		and ((venue_id == "HILLSIDE" \
			and lab._camera_director.get_script() == StadiumExpandedCameraDirector \
			and receiver.camera_protection == _receiver_camera_protection) \
		or (venue_id == "POOL-PARTY" \
			and lab._camera_director.get_script() == StadiumPoolPartyPublicCamera \
			and lab._camera_director.lab_ref != null \
			and lab._camera_director.lab_ref.get_ref() == lab \
			and receiver.camera_protection == _receiver_camera_protection) \
		or (venue_id == "GRAND-III" \
			and lab._camera_director.get_script() == StadiumGrandIIIPublicCamera \
			and lab._camera_director.lab_ref != null \
			and lab._camera_director.lab_ref.get_ref() == lab \
			and receiver.camera_protection == _receiver_camera_protection) \
		or (venue_id == "GRAND-II" \
			and lab._camera_director.get_script() == StadiumGrandIIPublicCamera \
			and lab._camera_director.lab_ref != null \
			and lab._camera_director.lab_ref.get_ref() == lab \
			and receiver.camera_protection == _receiver_camera_protection) \
		or (venue_id == "GRAND-I" \
			and lab._camera_director.get_script() == StadiumGrandIPublicCamera \
			and lab._camera_director.lab_ref != null \
			and lab._camera_director.lab_ref.get_ref() == lab \
			and receiver.camera_protection == _receiver_camera_protection) \
		or (venue_id == "LONG-YARD" \
			and lab._camera_director.get_script() == StadiumLongYardPublicCamera \
			and lab._camera_director.lab_ref != null \
			and lab._camera_director.lab_ref.get_ref() == lab \
			and receiver.camera_protection == _receiver_camera_protection) \
		or (venue_id == "AE-01" \
			and lab._camera_director.get_script() == StadiumExpandedCameraDirector) \
			or (venue_id == "AE-02" \
				and lab._camera_director.get_script() == StadiumNpcAe02PublicCamera \
				and lab._camera_director.lab_ref != null \
				and lab._camera_director.lab_ref.get_ref() == lab) \
			or (venue_id == "AC-02" \
				and lab._camera_director.get_script() == StadiumNpcAc02PublicCamera \
				and lab._camera_director.lab_ref != null \
				and lab._camera_director.lab_ref.get_ref() == lab \
				and receiver.camera_protection == _receiver_camera_protection) \
			or (venue_id == "AC-01" \
				and lab._camera_director.get_script() == StadiumClubCameraDirector \
				and receiver.camera_protection == _receiver_camera_protection) \
			or (venue_id == "AM-01" \
				and lab._camera_director.get_script() == StadiumNpcAm01PublicCamera \
				and lab._camera_director.lab_ref != null \
				and lab._camera_director.lab_ref.get_ref() == lab \
				and receiver.camera_protection == _receiver_camera_protection)
			or (venue_id == "AM-02" \
				and lab._camera_director.get_script() == StadiumNpcAm02PublicCamera \
				and lab._camera_director.lab_ref != null \
				and lab._camera_director.lab_ref.get_ref() == lab \
				and receiver.camera_protection == _receiver_camera_protection))


func score_display_intact(check_match: bool = false) -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property.score_display_intact")
	var ac02_result: bool = _ac02_passive_02_score_display_intact(check_match)
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_score_display_intact(check_match: bool = false) -> bool:
	# Presentation prerequisite only. _references and public admission remain separate.
	if venue_id == "HILLSIDE":
		if display != null or not is_instance_valid(construction) \
			or construction.get_script() != StadiumHillsidePublicConstruction \
			or objects != construction.objects or objects.size() != 8:
			return false
		for site: String in ["DUGOUT-L", "DUGOUT-R", "FOUL-POLE-L", "FOUL-POLE-R",
			"RECEIVER-CATCH", "RECEIVER-PRIMARY", "SIDE-SEAT-L", "SIDE-SEAT-R"]:
			var model: Variant = objects.get("npc:HILLSIDE:r1:" + site)
			if typeof(model) != TYPE_OBJECT or not is_instance_valid(model) \
				or not model is Node3D or not construction.is_ancestor_of(model):
				return false
		if check_match:
			var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
			return is_instance_valid(lab) and lab._match_state == bound_state \
				and is_instance_valid(_hillside_scorebug) and lab._scorebug == _hillside_scorebug \
				and _hillside_scorebug.get_script() == MatchScorebug and _hillside_scorebug._built \
				and _hillside_scorebug.is_inside_tree()
		return true
	var board: Node3D = objects.get(StadiumNpcPublicRuntime.identity_prefix(venue_id)
		+ StadiumNpcPublicRuntime.board_site(venue_id))
	return is_instance_valid(board) and is_instance_valid(display) \
		and display == board.get_node_or_null("Visual/ScoreDisplay") \
		and (not check_match or display._match == bound_state)


func _environment_intact(lab: PitchBatLab) -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property._environment_intact")
	var ac02_result: bool = _ac02_passive_02_private_environment_intact(lab)
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_private_environment_intact(lab: PitchBatLab) -> bool:
	if venue_id == "HILLSIDE":
		return StadiumHillsideEnvironmentV1.installed(lab, environment_lease)
	if venue_id == "POOL-PARTY":
		return StadiumPoolPartyEnvironmentV1.installed(lab, environment_lease)
	if venue_id == "GRAND-III":
		return StadiumGrandIIIEnvironmentV1.installed(lab, environment_lease)
	if venue_id == "GRAND-II":
		return StadiumGrandIIEnvironmentV1.installed(lab, environment_lease)
	if venue_id == "GRAND-I":
		return StadiumGrandIEnvironmentV1.installed(lab, environment_lease)
	return StadiumLongYardEnvironmentV1.installed(lab, environment_lease) \
		if venue_id == "LONG-YARD" else environment_lease.is_empty()


func _ac02_support_intact() -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property._ac02_support_intact")
	var ac02_result: bool = _ac02_passive_02_private_ac02_support_intact()
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_private_ac02_support_intact() -> bool:
	if venue_id != "AC-02":
		return ac02_guides == null and _ac02_guides_pin == null
	return is_instance_valid(ac02_guides) and ac02_guides == _ac02_guides_pin \
		and ac02_guides.get_script() == StadiumNpcAc02PublicGuides and ac02_guides.owners_intact()


func _ae02_support_intact() -> bool:
	if venue_id != "AE-02":
		return ae02_actors == null and _ae02_actors_pin == null
	return is_instance_valid(ae02_actors) and ae02_actors == _ae02_actors_pin \
		and ae02_actors.get_script() == StadiumNpcAe02PublicActors \
		and is_instance_valid(ae02_actors.cone_study) \
		and ae02_actors.cone_study == _ae02_cone_study_pin \
		and ae02_actors.cone_study.get_script() == _ae02_cone_script and ae02_actors.owners_intact()


func issue_installation() -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property.issue_installation")
	var ac02_result: bool = _ac02_passive_02_issue_installation()
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_issue_installation() -> bool:
	if suspended or issued:
		return false
	# Unknown deployment retains the literal historical call, without added Resource
	# observations. Only the exact qualified no-extension executable admits the observer.
	var deployment_qualified: bool = venue_id == "AC-02" \
		and StadiumNpcAc02IssuedQualificationV1.eligible()
	var native_admission: StadiumNpcAc02IssuedNativeAdmissionV1 = \
		StadiumNpcAc02IssuedNativeAdmissionV1.new() if deployment_qualified else null
	var historical_valid: bool = StadiumNpcPublicRuntime.installed(lab_ref.get_ref(), \
		native_admission) \
		if deployment_qualified else StadiumNpcPublicRuntime.installed(lab_ref.get_ref())
	if native_admission != null:
		native_admission.complete(historical_valid)
	if not historical_valid:
		return false
	_host_count = _host.get_child_count(true)
	_visibility_pin = _visibility_data()
	_route_pin = route_obstacles().duplicate(true)
	_pin_resource(field)
	if venue_id in ["LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"]:
		for key: String in ["applied_environment", "applied_sky", "applied_material"]:
			_pin_resource(environment_lease[key])
		for key: String in ["sun", "world"]:
			for signal_name: StringName in [&"tree_exiting", &"script_changed"]:
				environment_lease[key].connect(signal_name, _installation_changed)
		get_tree().node_added.connect(_environment_node_added)
	_capture_node(self)
	for node: Node in find_children("*", "", true, false):
		_capture_node(node)
	if venue_id == "POOL-PARTY":
		_pool_shape_parameters.make_read_only()
		_pool_shape_parameters_pin = _pool_shape_parameters
	if receiver != null:
		for model: Node3D in [receiver.chair, receiver.net]:
			_receiver_meshes[model] = model.get_node("Visual").find_children(
				"*", "MeshInstance3D", true, false)
	issued = true
	# Preserve the exact original successful final callback before the new route exists.
	if not callback_intact():
		return false
	if venue_id != "AC-02":
		return true
	_ac02_preparing = true
	var prepared: Dictionary = StadiumNpcAc02IssuedStateV1.try_issue(
		lab_ref.get_ref(), self, native_admission, deployment_qualified)
	_ac02_preparing = false
	if _ac02_preparation_failed or prepared.status == StadiumNpcAc02IssuedStateV1.Outcome.INVALIDATED:
		pause_invalid()
		return false
	if prepared.status == StadiumNpcAc02IssuedStateV1.Outcome.INELIGIBLE:
		return true # Unchanged historical dispatch, not a new cold-every-call promise.
	_ac02_issue = prepared.issuer
	_ac02_issue_pin = _ac02_issue
	_ac02_generation = _ac02_issue.generation
	_ac02_issued_once = true
	lab_ref.get_ref()._ac02_issued_owner = _ac02_issue
	lab_ref.get_ref()._ac02_issued_history = true
	receiver.mark_issued(self)
	ac02_guides.mark_issued()
	return true


func callback_intact() -> bool:
	if ac02_startup_pending():
		return false
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property.callback_intact")
	var ac02_result: bool = _ac02_passive_02_callback_intact()
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_callback_intact() -> bool:
	if has_ac02_issue():
		if _checking or _cleaning:
			return false
		var issued_lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
		_checking = true
		var intact: bool = _ac02_issue != null and _ac02_issue == _ac02_issue_pin \
			and _ac02_issue.hot_intact(issued_lab, self, _ac02_generation)
		_checking = false
		if not intact:
			ac02_revoke("issued callback refused")
			pause_invalid() # New branch is owner-safe; never falls through to historical success.
		return intact
	if suspended or _checking or _cleaning \
		or (venue_id == "HILLSIDE" and (hillside_support == null or hillside_support.pending)):
		return false
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	_checking = true
	var valid: bool = false
	if issued and ordinary_callbacks():
		valid = StadiumNpcPublicRuntime.callback_bound(lab, self)
	else:
		# Direct/custom diagnostic callers retain the strict actual-geometry boundary.
		valid = StadiumNpcPublicRuntime.installed(lab)
	_checking = false
	if not valid:
		pause_invalid()
	return valid


func ordinary_callbacks() -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property.ordinary_callbacks")
	var ac02_result: bool = _ac02_passive_02_ordinary_callbacks()
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_ordinary_callbacks() -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab == null or not is_instance_valid(_actor) or not is_instance_valid(_resolver) \
		or _actor.get_script() != PitchFlightActor or _resolver.get_script() != BallPlayResolver \
		or (_resolver.state != null and _resolver.state.get_script() != BallPlayState) \
		or (_actor.state != null and _actor.state.get_script() != PitchState) \
		or (_actor.parameters != null and _actor.parameters.get_script() != PitchLaunchParameters):
		return false
	for row: Array in [[_actor.plate_crossed, lab._on_plate_crossed],
		[_actor.trace_sampled, lab._on_trace_sampled],
		[_resolver.play_resolved, lab._on_ball_play_resolved]]:
		var connections: Array = row[0].get_connections()
		if connections.size() != 1 or connections[0].callable != row[1] or connections[0].flags != 0:
			return false
	return true


func routing_intact() -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property.routing_intact")
	var ac02_result: bool = _ac02_passive_02_routing_intact()
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_routing_intact() -> bool:
	if _resolver.segment_observer != observe or _fielder.stadium_boundary_clip != clip \
		or _fielder.stadium_obstacles != _route_pin \
		or not _resolver.play_resolved.is_connected(lab_ref.get_ref()._on_ball_play_resolved) \
		or _actor.receiver_router != (Callable() if receiver == null else receiver_route):
		return false
	var ids: Dictionary = {}
	for reference: WeakRef in bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		if ids.has(ball.get_instance_id()) or ball.get_parent() != lab_ref.get_ref() \
			or ball.get_script() != BattedBallBody \
			or not StadiumNpcPublicRuntime._ball_wiring(self, ball, _resolver):
			return false
		ids[ball.get_instance_id()] = true
	if venue_id in ["AC-01", "AC-02", "AM-01", "AM-02", "LONG-YARD", "GRAND-I",
		"GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"]:
		for values: Dictionary in [boundary._bound_balls, boundary._resolver_ids, boundary._previous]:
			if values.size() != ids.size():
				return false
			for identity: int in values:
				if not ids.has(identity):
					return false
	return true


func _capture_node(node: Node) -> void:
	var row: Dictionary = {"node": node, "parent": node.get_parent(), "script": node.get_script(),
		"count": node.get_child_count(true), "process": node.process_mode, "meta": {}}
	for key: String in StadiumNpcRetainedGeometry.META:
		if node.has_meta(key):
			row.meta[key] = node.get_meta(key)
	row.meta = row.meta.duplicate(true)
	if venue_id == "POOL-PARTY" and StadiumPoolPartyRuntime.owns_node(self, node):
		row["pool_meta"] = {}
		for key: StringName in node.get_meta_list():
			row.pool_meta[String(key)] = node.get_meta(key)
		row.pool_meta = row.pool_meta.duplicate(true)
	if node is Node3D:
		row["pose"] = node.transform
		row["top_level"] = node.top_level
		row["visible"] = node.visible
	if node is CollisionObject3D:
		row["layers"] = [node.collision_layer, node.collision_mask, node.collision_priority,
			node.disable_mode]
	if node is StaticBody3D:
		row["physics_material"] = node.physics_material_override
		row["velocity"] = [node.constant_linear_velocity, node.constant_angular_velocity]
		_bodies[node] = row
		_pin_resource(node.physics_material_override)
	if node is CollisionShape3D:
		row["shape"] = node.shape
		row["disabled"] = node.disabled
		_pin_resource(node.shape)
		if venue_id == "POOL-PARTY":
			var parameters: Dictionary = {"node": node, "shape": node.shape,
				"margin": node.shape.margin if node.shape != null else NAN,
				"bias": node.shape.custom_solver_bias if node.shape != null else NAN}
			parameters.make_read_only()
			_pool_shape_parameters.append(parameters)
	if node is MeshInstance3D:
		row["mesh"] = node.mesh
		row["material"] = node.material_override
		row["overlay"] = node.material_overlay
		row["receiver_visual"] = StadiumNpcRetainedGeometry._receiver_visual(node)
		row["cone_visual"] = venue_id == "AE-02" \
			and StadiumNpcAe02PublicActors.owns_mesh(self, node)
		if row.receiver_visual and node.material_override is StandardMaterial3D:
			row["receiver_material"] = _receiver_material(node.material_override)
		if not row.receiver_visual:
			_pin_resource(node.mesh)
			_pin_resource(node.material_override)
			_pin_resource(node.material_overlay)
	_nodes.append(row)
	# Bounded live owners, receiver flex/fade and six cone visuals. Collision stays cold.
	if node in [self, construction, boundary, receiver] \
		or (venue_id == "POOL-PARTY" and (node == objects.get(StadiumPoolPartyRuntime.COPY) \
			or node.name == StringName(StadiumPoolInteriorV2.VOLUME_ID))) \
		or (receiver != null and (
		node in [receiver.chair, receiver.net] or StadiumNpcRetainedGeometry._receiver_visual(node))) \
		or (node is MeshInstance3D and row.get("cone_visual", false)):
		_issued_nodes.append(row)
	for signal_name: StringName in [&"tree_exiting", &"child_order_changed", &"script_changed"]:
		if not node.is_connected(signal_name, _installation_changed):
			node.connect(signal_name, _installation_changed)


func _pin_resource(resource: Resource) -> void:
	if resource == null or _resources.has(resource):
		return
	_resources.append(resource)
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if venue_id == "GRAND-III" and StadiumGrandIIIEnvironmentV1.owns_dynamic_resource(lab, \
		environment_lease, resource):
		_gardens_time_resources.append(resource)
		resource.changed.connect(_gardens_time_resource_changed.bind(resource))
		return
	if not resource.changed.is_connected(_installation_changed):
		resource.changed.connect(_installation_changed)


func _gardens_time_resource_changed(resource: Resource) -> void:
	if not issued or _cleaning:
		return
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if StadiumGrandIIIEnvironmentV1.dynamic_resource_change(lab, environment_lease, resource):
		return
	# A replaced lab/state supplies no authority for writes to its new gameplay owner.
	if not is_instance_valid(lab) or StadiumNpcPublicRuntime._property(lab) != self or \
		lab._match_state != bound_state:
		suspended = true
		issued = false
		return
	retire_installation("unplanned Gardens time resource change")


func _disconnect_environment() -> void:
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	if tree != null and tree.node_added.is_connected(_environment_node_added):
		tree.node_added.disconnect(_environment_node_added)
	for key: String in ["sun", "world"]:
		var node: Node = environment_lease.get(key) as Node
		if not is_instance_valid(node):
			continue
		for signal_name: StringName in [&"tree_exiting", &"script_changed"]:
			if node.is_connected(signal_name, _installation_changed):
				node.disconnect(signal_name, _installation_changed)


func _environment_node_added(node: Node) -> void:
	# Event-only ownership guard; no per-frame scene scan.
	if not issued or _cleaning or lab_ref == null:
		return
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab
	if not is_instance_valid(lab) or not lab.is_ancestor_of(node):
		return
	if venue_id == "POOL-PARTY" and node is CollisionObject3D:
		boundary.include_collider(node)
	if node is Light3D:
		retire_installation("unleased light added")


func retire_installation(reason: String = "supported static edit") -> void:
	if ac02_startup_pending():
		_abort_startup(reason)
		return
	if _ac02_preparing:
		_ac02_preparation_failed = true
	ac02_revoke(reason)
	# Every supported static writer must call this BEFORE changing source/geometry,
	# resources, collision data, metadata, or boundary/visibility recipe contents.
	# Retirement is sticky: restoring values cannot renew this installation.
	if not _cleaning and not suspended:
		retirement_reason = reason
		pause_invalid()


func _installation_changed() -> void:
	if ac02_startup_pending():
		_abort_startup("captured installation changed")
		return
	if issued and not _cleaning:
		retire_installation("static membership, script or resource changed")


func issued_intact() -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property.issued_intact")
	var ac02_result: bool = _ac02_passive_02_issued_intact()
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_issued_intact() -> bool:
	# This is a lifecycle contract, not equivalence to arbitrary native mutate/restore.
	# Unsupported direct static edits retain the next installed() cold audit.
	# Pool native silent shape scalars additionally receive an immediate live check.
	return _node_records_intact(_issued_nodes, false) and _pool_shape_parameters_intact() \
		and (receiver == null or (
		_receiver_style_intact(receiver.chair) and _receiver_style_intact(receiver.net)))


func _pool_shape_parameters_intact() -> bool:
	if venue_id != "POOL-PARTY":
		return true
	if not is_same(_pool_shape_parameters, _pool_shape_parameters_pin) \
		or not _pool_shape_parameters.is_read_only() or _pool_shape_parameters.is_empty():
		return false
	for row: Dictionary in _pool_shape_parameters:
		if not row.is_read_only() or not is_instance_valid(row.node) \
			or not is_instance_valid(row.shape) or row.node.shape != row.shape \
			or row.shape.get_script() != null or not is_finite(row.shape.margin) \
			or not is_finite(row.shape.custom_solver_bias) \
			or row.shape.margin != row.margin or row.shape.custom_solver_bias != row.bias:
			return false
	return true


func physical_intact() -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property.physical_intact")
	var ac02_result: bool = _ac02_passive_02_physical_intact()
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_physical_intact() -> bool:
	# Explicit diagnostic keeps the original all-node/resource comparison.
	if not _node_records_intact(_nodes):
		return false
	for resource: Resource in _resources:
		var handler: Callable = _gardens_time_resource_changed.bind(resource) \
			if _gardens_time_resources.has(resource) else _installation_changed
		if not is_instance_valid(resource) or not resource.changed.is_connected(handler):
			return false
	return receiver == null or (_receiver_style_intact(receiver.chair) \
		and _receiver_style_intact(receiver.net))


func _node_records_intact(records: Array[Dictionary], strict: bool = true) -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property._node_records_intact")
	var ac02_result: bool = _ac02_passive_02_private_node_records_intact(records, strict)
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_private_node_records_intact(records: Array[Dictionary], strict: bool = \
	true) -> bool:
	if not issued or records.is_empty() or _host.get_child_count(true) != _host_count:
		return false
	for row: Dictionary in records:
		var node: Node = row.node
		if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion() \
			or node.get_parent() != row.parent or node.get_script() != row.script \
			or node.get_child_count(true) != row.count or node.process_mode != row.process \
			or (not StadiumMountedScoreboardContract._clean(node)
				and not (venue_id == "POOL-PARTY" and StadiumPoolPartyRuntime.owns_node(self, node))):
			return false
		if row.has("pool_meta"):
			var metadata: Dictionary = {}
			for key: StringName in node.get_meta_list():
				metadata[String(key)] = node.get_meta(key)
			if metadata != row.pool_meta:
				return false
		if node is Node3D:
			var pose: Transform3D = node.transform
			if node.name == &"ST026_PANEL" and StadiumNpcRetainedGeometry._receiver_visual(node):
				if not is_finite(pose.origin.z) or pose.origin.z < -0.042501 \
					or pose.origin.z > -0.012499:
					return false
				pose.origin.z = row.pose.origin.z
			var receiver_container: bool = node.name == &"Visual" \
				and StadiumNpcRetainedGeometry._receiver_visual(node)
			if pose != row.pose or node.top_level != row.top_level \
				or (not receiver_container and node.visible != row.visible):
				return false
		for key: String in StadiumNpcRetainedGeometry.META:
			if node.has_meta(key) != row.meta.has(key) \
				or (row.meta.has(key) and node.get_meta(key) != row.meta[key]):
				return false
		if node is CollisionObject3D and [node.collision_layer, node.collision_mask,
			node.collision_priority, node.disable_mode] != row.layers:
			return false
		if node is StaticBody3D and (node.physics_material_override != row.physics_material \
			or [node.constant_linear_velocity, node.constant_angular_velocity] != row.velocity):
			return false
		if node is CollisionShape3D and (node.shape != row.shape or node.shape == null \
			or node.shape.get_script() != null or node.disabled != row.disabled):
			return false
		if node is MeshInstance3D:
			if row.get("cone_visual", false):
				if not StadiumNpcAe02PublicActors.mesh_intact(self, node, row.material, row.overlay):
					return false
			elif node.material_override != row.material or node.material_overlay != row.overlay:
				return false
			if strict and row.has("receiver_material") \
				and _receiver_material(node.material_override) != row.receiver_material:
				return false
			var club_panel: bool = venue_id in ["AC-01", "AC-02", "AM-01", "AM-02", "LONG-YARD",
				"GRAND-I", "GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"] \
				and row.receiver_visual \
				and StadiumNpcClubNetV1.PANELS.has(String(node.name))
			if not club_panel and node.mesh != row.mesh:
				return false
			if club_panel and (node.mesh == null or node.mesh.get_script() != null \
				or not is_finite(receiver.flex_elapsed) or receiver.flex_elapsed < 0 \
				or receiver.flex_elapsed > StadiumNpcClubNetV1.SETTLE \
				or not receiver.flex_impact.is_finite()):
				return false
	return true


func _visibility_data() -> Array:
	if presentation_director == null:
		return []
	var view: StadiumNpcRetainedVisibility = presentation_director.tracking_visibility \
		as StadiumNpcRetainedVisibility
	if view == null or view._recipe == null or view._wall_prisms == null:
		return []
	if venue_id == "HILLSIDE" and not view is StadiumHillsidePublicVisibility:
		return []
	if venue_id == "POOL-PARTY" and not view is StadiumPoolPartyPublicVisibility:
		return []
	if venue_id == "GRAND-III" and not view is StadiumGrandIIIPublicVisibility:
		return []
	if venue_id == "GRAND-II" and not view is StadiumGrandIIPublicVisibility:
		return []
	if venue_id == "GRAND-I" and not view is StadiumGrandIPublicVisibility:
		return []
	if venue_id == "LONG-YARD" and not view is StadiumLongYardPublicVisibility:
		return []
	if venue_id == "AC-02" and not view is StadiumNpcAc02PublicVisibility:
		return []
	if venue_id == "AE-02" and not view is StadiumNpcAe02PublicVisibility:
		return []
	var result: Array = [view, view.get_script(), view.property,
		view._recipe, view._recipe.get_script(),
		view._recipe.polygon(), view._recipe.segments(), view._wall_prisms,
		view._wall_prisms.get_script(), view._wall_prisms.walls.duplicate(true),
		view._obstacles.duplicate(true), view._uprights.duplicate(true),
		view._wall_bounds.duplicate(true), view.field_wall_z, view._groups.duplicate(true),
		view._rails.duplicate(true)]
	if venue_id == "HILLSIDE":
		result.append((view as StadiumHillsidePublicVisibility)._wall_slices.duplicate(true))
	if venue_id == "AE-02":
		result.append((view as StadiumNpcAe02PublicVisibility).side_state())
	return result


func visibility_intact(strict: bool = true) -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property.visibility_intact")
	var ac02_result: bool = _ac02_passive_02_visibility_intact(strict)
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_visibility_intact(strict: bool = true) -> bool:
	if _visibility_pin.is_empty():
		return false
	if strict:
		return _visibility_pin == _visibility_data()
	# Recipes are static after issue. Only their actual owners are dynamic here.
	var view: StadiumNpcRetainedVisibility = presentation_director.tracking_visibility \
		as StadiumNpcRetainedVisibility
	return is_instance_valid(view) and view == _visibility_pin[0] \
		and view.get_script() == _visibility_pin[1] and view.property == self \
		and is_instance_valid(view._recipe) and view._recipe == _visibility_pin[3] \
		and view._recipe.get_script() == _visibility_pin[4] \
		and is_instance_valid(view._wall_prisms) and view._wall_prisms == _visibility_pin[7] \
		and view._wall_prisms.get_script() == _visibility_pin[8] \
		and (venue_id != "AE-02" or (view is StadiumNpcAe02PublicVisibility \
			and (view as StadiumNpcAe02PublicVisibility).owners_intact()))


func clip(from: Vector3, to: Vector3) -> Vector3:
	return super.clip(from, to) if callback_intact() else from


func observe(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> Dictionary:
	if not callback_intact() or resolver != _resolver or resolver.state == null \
		or resolver.state.dead or resolver.field != field:
		return {}
	if venue_id in ["POOL-PARTY", "HILLSIDE"]:
		var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab
		if not is_instance_valid(lab._batted_ball) or previous != lab._previous_batted_position \
			or current != lab._batted_ball.global_position:
			return {}
	_contact_dispatch = true
	var result: Dictionary
	if venue_id == "HILLSIDE":
		result = boundary.observe(resolver, previous, current)
	elif venue_id == "POOL-PARTY":
		result = StadiumPoolPartyPublicSweep.observe(boundary, resolver, previous, current)
	elif venue_id == "GRAND-III":
		result = StadiumGrandIPublicSweep.observe(boundary, resolver, previous, current)
	elif venue_id == "GRAND-II":
		result = StadiumGrandIPublicSweep.observe(boundary, resolver, previous, current)
	elif venue_id == "GRAND-I":
		result = StadiumGrandIPublicSweep.observe(boundary, resolver, previous, current)
	elif venue_id == "LONG-YARD":
		result = StadiumLongYardPublicSweep.observe(boundary, resolver, previous, current)
	elif venue_id == "AC-02":
		result = StadiumNpcAc02PublicSweep.observe(boundary, resolver, previous, current)
	elif venue_id == "AE-02":
		result = boundary.graph.observe(resolver, previous, current)
	elif venue_id == "AM-02":
		result = StadiumNpcAm02PublicSweep.observe(boundary, resolver, previous, current)
	elif venue_id == "AM-01":
		result = StadiumNpcAm01PublicSweep.observe(boundary, resolver, previous, current)
	else:
		result = super.observe(resolver, previous, current)
	_contact_dispatch = false
	return result


func receiver_route(actor: PitchFlightActor, start: Vector3, velocity: Vector3) -> bool:
	return callback_intact() and actor == _actor and receiver != null \
		and receiver.route(actor, start, velocity)


func _receiver_camera_protection() -> bool:
	return callback_intact() and super._receiver_camera_protection()


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if not StadiumNpcPublicRuntime.bind_ball(lab, ball, resolver):
		pause_invalid()


func bind_contacts(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	for reference: WeakRef in bound_balls:
		if reference.get_ref() == ball:
			return
	bound_balls.assign(bound_balls.filter(func(reference: WeakRef) -> bool:
		return is_instance_valid(reference.get_ref())))
	if venue_id in ["AC-02", "AM-01", "AM-02", "LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III",
		"POOL-PARTY", "HILLSIDE"]:
		boundary.bind_ball(ball, resolver)
		bound_balls.append(weakref(ball))
	else:
		super.bind_ball(ball, resolver)
	ball.physics_contact_router = _boundary_contact_batch.bind(resolver)
	if venue_id == "HILLSIDE" and not hillside_support.ground.bind_public_ball(ball, resolver):
		retire_installation("The captured Hillside ball lost its physical ground binding")


func _ball_owned(ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	if not callback_intact() or not is_instance_valid(ball) or resolver != _resolver \
		or resolver.state == null or resolver.field != field \
		or ball.get_script() != BattedBallBody or ball.get_parent() != lab_ref.get_ref() \
		or lab_ref.get_ref()._batted_ball != ball \
		or not StadiumNpcPublicRuntime._ball_wiring(self, ball, resolver):
		return false
	for reference: WeakRef in bound_balls:
		if reference.get_ref() == ball:
			return true
	return false


func _boundary_contact_batch(ball: BattedBallBody, batch: Array[Dictionary],
	resolver: BallPlayResolver) -> void:
	if not _ball_owned(ball, resolver) or resolver.state.dead:
		return
	# Compare with the native manifold being processed, not the previous monitor-frame list.
	# A direct call cannot invent contacts by borrowing a valid owned body identity.
	var native: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(ball.get_rid())
	if native == null:
		return
	var actual: Array[Dictionary] = []
	for index in range(native.get_contact_count()):
		var body: Object = native.get_contact_collider_object(index)
		if body is Node:
			actual.append({"body": body, "position": native.get_contact_collider_position(index)})
	if batch != actual:
		return
	for contact: Dictionary in batch:
		if not contact.get("body") is StaticBody3D or not _bodies.has(contact.body) \
			or not contact.get("position") is Vector3 or not contact.position.is_finite():
			return
	var state: BallPlayState = resolver.state
	if venue_id == "HILLSIDE":
		if not hillside_support.ground.public_ground_first(ball, batch, state) \
			or resolver.state != state or not _ball_owned(ball, resolver) or state.dead:
			return
	_contact_dispatch = true
	boundary._contact_batch(ball, batch, resolver)
	_contact_dispatch = false


func _ball_contact(body: Node, ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	if not _ball_owned(ball, resolver) or resolver.state.dead or not _bodies.has(body) \
		or not ball.get_colliding_bodies().has(body):
		return
	super._ball_contact(body, ball, resolver)


func _club_contact(event: Dictionary, resolver: BallPlayResolver) -> void:
	if not _contact_dispatch or not callback_intact() or resolver != _resolver \
		or resolver.state == null or resolver.state.dead:
		return
	super._club_contact(event, resolver)


func rebind(state: MatchState) -> void:
	# Explicit install may bind the original state; generic presentation cannot adopt another.
	if state != bound_state:
		pause_invalid()
		return
	if not suspended:
		super.rebind(state)


func refresh_receiver_presentation(lab: PitchBatLab, force_visible: bool = false) -> void:
	var ac02_token: int = \
		AC02_PASSIVE_2.enter("stadium_npc_public_property.refresh_receiver_presentation")
	_ac02_passive_02_refresh_receiver_presentation(lab, force_visible)
	AC02_PASSIVE_2.leave(ac02_token)


func _ac02_passive_02_refresh_receiver_presentation(lab: PitchBatLab, force_visible: bool = \
	false) -> void:
	if lab_ref == null or lab_ref.get_ref() != lab or not callback_intact():
		restore_presentations()
		return
	super.refresh_receiver_presentation(lab, force_visible)


func refresh_ac02_setup_receiver(lab: PitchBatLab, force_visible: bool = false) -> Dictionary:
	# The original first receiver guard is retained. Only its valid, unissued AC02
	# remainder may use a call-local proof; public callback_intact is unchanged.
	if get_script() != StadiumNpcPublicProperty or venue_id != "AC-02" or issued \
		or lab_ref == null or lab_ref.get_ref() != lab or suspended or _checking or _cleaning:
		refresh_receiver_presentation(lab, force_visible)
		return {"admitted": false, "reason": "ordinary-guard"}
	var admission: StadiumNpcAc02SetupAdmission = StadiumNpcAc02SetupAdmission.new()
	admission.begin(lab, self)
	_checking = true
	var valid: bool = StadiumNpcPublicRuntime.installed(lab, admission)
	_checking = false
	if not valid:
		pause_invalid()
		restore_presentations()
		return {"admitted": false, "reason": "first-guard-failed"}
	if not admission.closed or not StadiumNpcAc02SetupAdmission.no_live_owners(lab, self):
		var reason: String = admission.reason if not admission.closed else "post-audit-owners"
		# Do not repeat the first guard. Original retained remainder performs every
		# nested public actor/camera guard, including paused restoration semantics.
		admission = null
		super.refresh_receiver_presentation(lab, force_visible)
		return {"admitted": false, "reason": reason}
	# Retire authority before any presentation write. The exact no-live actor body
	# still allocates/reset diagnostics and clears cutaway state, as before.
	admission = null
	rebind(lab._match_state)
	super.refresh_actor_presentation(lab)
	_refresh_receiver_visuals(lab, force_visible)
	return {"admitted": true, "reason": "closed-no-live", "nested_guards_omitted": 2}


func _process(_delta: float) -> void:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property._process")
	_ac02_passive_02_private_process(_delta)
	AC02_PASSIVE_2.leave(ac02_token)


func _ac02_passive_02_private_process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab != null:
		refresh_receiver_presentation(lab)


func _physics_process(_delta: float) -> void:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property._physics_process")
	_ac02_passive_02_private_physics_process(_delta)
	AC02_PASSIVE_2.leave(ac02_token)


func _ac02_passive_02_private_physics_process(_delta: float) -> void:
	if lab_ref != null:
		callback_intact()


func pause_invalid() -> void:
	if ac02_startup_pending():
		_abort_startup("preparation paused")
		return
	if _ac02_preparing:
		_ac02_preparation_failed = true
	if has_ac02_issue():
		ac02_revoke("pause invalid")
		if _ac02_issue_pin != null:
			var issued_lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
			_ac02_issue_pin.pause_owned(issued_lab, self)
		else:
			suspended = true
			issued = false
		return
	if suspended:
		return
	if venue_id == "HILLSIDE":
		_pause_hillside()
		return
	suspended = true
	issued = false
	if venue_id == "HILLSIDE" and hillside_support != null:
		hillside_support.retire()
	restore_presentations()
	if is_instance_valid(display):
		display.bind_match(null)
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if not is_instance_valid(lab):
		return
	lab.set_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND, true)
	lab.set_meta("stadium_npc_runtime_interrupted", true)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	var paused_ball: BattedBallBody = lab._batted_ball
	if venue_id == "HILLSIDE":
		paused_ball = bound_balls[0].get_ref() as BattedBallBody if not bound_balls.is_empty() else null
	if is_instance_valid(paused_ball):
		paused_ball.freeze = true
		paused_ball.process_mode = Node.PROCESS_MODE_DISABLED
		paused_ball.set_process(false)
		paused_ball.set_physics_process(false)
		if paused_ball.surface_contact.is_connected(lab._on_batted_surface_contact):
			paused_ball.surface_contact.disconnect(lab._on_batted_surface_contact)
	disconnect_balls()
	if venue_id == "HILLSIDE" and not environment_lease.is_empty():
		_disconnect_environment()
		StadiumHillsideEnvironmentV1.restore(lab, environment_lease)
	if is_instance_valid(_resolver):
		if _resolver.play_resolved.is_connected(lab._on_ball_play_resolved):
			_resolver.play_resolved.disconnect(lab._on_ball_play_resolved)
		_resolver.segment_observer = Callable()
	if is_instance_valid(receiver):
		if receiver._rock != null and receiver._rock.is_valid():
			receiver._rock.kill()
		if receiver._pocket != null and receiver._pocket.is_valid():
			receiver._pocket.kill()
		if receiver is StadiumNpcRetainedClubReceiver:
			receiver._cancel_active()
	if is_instance_valid(_actor):
		_actor.receiver_router = Callable()
		_actor.reset_pitch()
	if is_instance_valid(_release):
		_release.cancel()
	if is_instance_valid(_cadence):
		_cadence.stop()
	lab._automation = null
	# No result, fixture settlement, raw/private admission or automatic resumption.


func disconnect_balls() -> void:
	for reference: WeakRef in bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		if ball.physics_contact_router.get_object() == self:
			ball.physics_contact_router = Callable()
		if boundary is StadiumNpcRetainedClubBoundary or boundary is StadiumNpcAm01PublicBoundary \
			or boundary is StadiumNpcAm02PublicBoundary or boundary is StadiumNpcAc02PublicBoundary \
			or boundary is StadiumLongYardPublicBoundary or boundary is StadiumGrandIPublicBoundary \
			or boundary is StadiumPoolPartyPublicBoundary or boundary is StadiumHillsidePublicContactAdapter:
			boundary._disconnect_ball(ball)
			boundary._forget(ball.get_instance_id(), boundary._resolver_ids.get(
				ball.get_instance_id(), -1))
		elif is_instance_valid(boundary):
			boundary._forget(ball.get_instance_id())
	super.disconnect_balls()
	if boundary is StadiumNpcRetainedClubBoundary or boundary is StadiumNpcAm01PublicBoundary \
			or boundary is StadiumNpcAm02PublicBoundary or boundary is StadiumNpcAc02PublicBoundary \
			or boundary is StadiumLongYardPublicBoundary or boundary is StadiumGrandIPublicBoundary \
			or boundary is StadiumPoolPartyPublicBoundary or boundary is StadiumHillsidePublicContactAdapter:
		boundary._bound_balls.clear()
		boundary._previous.clear()
		boundary._resolver_ids.clear()
		boundary.last_live.clear()
	elif is_instance_valid(boundary):
		boundary._touching.clear()


func _exit_tree() -> void:
	if ac02_startup_pending():
		_abort_startup("preparation property exit")
		return
	if has_ac02_issue():
		ac02_revoke("tree exit")
		_cleaning = true
		var issued_lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
		if is_instance_valid(issued_lab):
			StadiumNpcPublicRuntime.unexpected_exit(issued_lab, self)
		ac02_cleanup_local()
		if _ac02_issue_pin != null:
			_ac02_issue_pin.release_abandoned_originals()
		old_nodes.clear()
		bound_state = null
		return
	_cleaning = true
	_disconnect_environment()
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if is_instance_valid(lab):
		StadiumNpcPublicRuntime.unexpected_exit(lab, self)
	disconnect_balls()
	if is_instance_valid(display):
		display.bind_match(null)
	bound_state = null
	for node: Node in old_nodes:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	old_nodes.clear()


func _boundary_intact(strict: bool) -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property._boundary_intact")
	var ac02_result: bool = _ac02_passive_02_private_boundary_intact(strict)
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_private_boundary_intact(strict: bool) -> bool:
	if strict:
		return StadiumNpcPublicRuntime._boundary_complete(self) \
			and _boundary_pin == _boundary_data()
	if _boundary_pin.is_empty() or boundary != _boundary_pin[0] \
		or boundary.get_script() != _boundary_pin[1]:
		return false
	if venue_id == "AY-01":
		return boundary == construction.get_node_or_null("BoundaryGraph")
	if not is_instance_valid(boundary.graph) or boundary.graph != _boundary_pin[2] \
		or boundary.graph.get_script() != _boundary_pin[3]:
		return false
	if venue_id in ["AE-01", "AE-02"]:
		return boundary == construction.get_node_or_null("BoundaryGraph")
	if venue_id == "POOL-PARTY" and (_boundary_pin.size() != 12 \
		or not is_instance_valid(boundary.pool_model) or boundary.pool_model != _boundary_pin[10] \
		or boundary.pool_model != objects.get(StadiumPoolPartyRuntime.COPY) \
		or boundary.pool_model != construction.pool_model \
		or boundary.pool_bodies != _boundary_pin[11]):
		return false
	return is_instance_valid(boundary.source) and boundary.source == _boundary_pin[6] \
		and boundary.source.get_script() == _boundary_pin[7] \
		and boundary.source == construction.get_node_or_null(
			"HillsideBoundary" if venue_id == "HILLSIDE" else "ClubBoundary") \
		and boundary.graph == boundary.source.graph \
		and boundary.contact_applied.is_connected(_club_contact) \
		and boundary.contact_applied.get_connections().size() == 1


func _boundary_data() -> Array:
	if not is_instance_valid(boundary):
		return []
	if venue_id == "AY-01":
		return [boundary, boundary.get_script()]
	if boundary.graph == null:
		return []
	var result: Array = [boundary, boundary.get_script(), boundary.graph,
		boundary.graph.get_script(), boundary.graph.polygon(), boundary.graph.segments()]
	if venue_id in ["AC-01", "AC-02", "AM-01", "AM-02", "LONG-YARD", "GRAND-I",
		"GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"]:
		if not is_instance_valid(boundary.source):
			return []
		result.append_array([boundary.source, boundary.source.get_script(),
			boundary.bodies.duplicate(), boundary.items.duplicate()])
	if venue_id == "POOL-PARTY":
		result.append_array([boundary.pool_model, boundary.pool_bodies.duplicate()])
	return result


func _receiver_style_intact(model: Node3D) -> bool:
	var ac02_token: int = AC02_PASSIVE_2.enter("stadium_npc_public_property._receiver_style_intact")
	var ac02_result: bool = _ac02_passive_02_private_receiver_style_intact(model)
	AC02_PASSIVE_2.leave(ac02_token)
	return ac02_result


func _ac02_passive_02_private_receiver_style_intact(model: Node3D) -> bool:
	if not is_instance_valid(model) or not model.has_node("Visual"):
		return false
	var visual: Node3D = model.get_node("Visual")
	var state: String = model.get_meta("receiver_render_state", "visible")
	if state not in ["hidden", "faded", "visible"] or visual.visible != (state != "hidden"):
		return false
	var alpha: float = StadiumReceiverVisibility.FADED_ALPHA if state == "faded" else 1.0
	var blend: int = BaseMaterial3D.TRANSPARENCY_ALPHA if state == "faded" else (
		BaseMaterial3D.TRANSPARENCY_DISABLED)
	var shadow: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if state == "visible" else (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var meshes: Array = _receiver_meshes.get(model, []) if issued else visual.find_children(
		"*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return false
	for mesh: MeshInstance3D in meshes:
		if not is_instance_valid(mesh):
			return false
		var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		if material == null or not mesh.visible or not is_equal_approx(material.albedo_color.a, alpha) \
			or material.transparency != blend or mesh.cast_shadow != shadow:
			return false
	return true


func _receiver_material(material: StandardMaterial3D) -> Dictionary:
	# Only fade alpha/transparency are dynamic; the retained material's other stored channels
	# remain exact. This bounded two-model check is separate from cold 72-object geometry.
	var values: Dictionary = StadiumNpcRetainedGeometry._stored(material)
	var color: Color = values.albedo_color
	color.a = 1.0
	values.albedo_color = color
	values.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return values


func restore_presentations() -> void:
	if has_ac02_issue() and not ac02_owns_cleanup():
		ac02_revoke("presentation owner replaced")
		return
	if venue_id == "HILLSIDE" and (hillside_support == null or not hillside_support.cleanup_owned()):
		return
	# Restore only the originally admitted presentation owners, even after a substituted field.
	var cutaway: Variant = _support[5] if _support.size() == 9 else actor_cutaway
	var readability: Variant = _support[6] if _support.size() == 9 else ball_readability
	if is_instance_valid(cutaway) and cutaway.get_script() == StadiumNpcRetainedActorCutaway:
		cutaway.restore_all()
	if has_ac02_issue() and not ac02_owns_cleanup():
		ac02_revoke("presentation callback replaced owner")
		return
	if is_instance_valid(readability) \
		and readability.get_script() == StadiumNpcRetainedBallReadability:
		readability.restore_all()
	if has_ac02_issue() and not ac02_owns_cleanup():
		ac02_revoke("readability callback replaced owner")
		return
	var cones: StadiumNpcAe02PublicActors = _ae02_actors_pin \
		if is_instance_valid(_ae02_actors_pin) else ae02_actors
	if is_instance_valid(cones) and cones.get_script() == StadiumNpcAe02PublicActors:
		cones.restore_all()
	var guides: StadiumNpcAc02PublicGuides = _ac02_guides_pin \
		if is_instance_valid(_ac02_guides_pin) else ac02_guides
	if is_instance_valid(guides) and guides.get_script() == StadiumNpcAc02PublicGuides:
		guides.restore_all()


func refresh_actor_presentation(lab: PitchBatLab) -> void:
	var ac02_token: int = \
		AC02_PASSIVE_2.enter("stadium_npc_public_property.refresh_actor_presentation")
	_ac02_passive_02_refresh_actor_presentation(lab)
	AC02_PASSIVE_2.leave(ac02_token)


func _ac02_passive_02_refresh_actor_presentation(lab: PitchBatLab) -> void:
	if lab_ref == null or lab_ref.get_ref() != lab or not callback_intact():
		restore_presentations()
		return
	if venue_id in ["AE-02", "AC-02", "LONG-YARD", "GRAND-I",
		"GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"] and lab.get_tree().paused:
		restore_presentations()
		return
	super.refresh_actor_presentation(lab)
	if venue_id == "AE-02":
		ae02_actors.refresh(lab, self)
	elif venue_id == "AC-02":
		ac02_guides.refresh()


func hillside_owner_intact() -> bool:
	return venue_id == "HILLSIDE" and hillside_support != null \
		and hillside_support == _hillside_support_pin \
		and hillside_support.get_script() == StadiumHillsidePublicSupport \
		and hillside_support.owner_context_intact()


func _hillside_support_intact() -> bool:
	if venue_id != "HILLSIDE":
		return hillside_support == null and _hillside_support_pin == null
	return hillside_owner_intact() and hillside_support.bound_intact() \
		and boundary.dynamic_intact()


func hillside_tracking_valid(lab: PitchBatLab, motion: StadiumHillsideDefenderMotion) -> bool:
	return issued and not suspended and lab_ref != null and lab_ref.get_ref() == lab \
		and _hillside_support_intact() and motion != null \
		and motion in [hillside_support.primary_motion, hillside_support.pitcher_motion]


func hillside_launch_binding_valid(ball: BattedBallBody, state: BallPlayState) -> bool:
	return venue_id == "HILLSIDE" and callback_intact() and state != null and not state.dead \
		and _resolver.state == state and is_instance_valid(ball) and not ball.is_queued_for_deletion() \
		and ball.is_inside_tree() and lab_ref.get_ref()._batted_ball == ball \
		and ball.get_parent() == lab_ref.get_ref() \
		and StadiumNpcPublicRuntime._ball_wiring(self, ball, _resolver)


func clear_hillside_ball(ball: BattedBallBody) -> void:
	if venue_id != "HILLSIDE":
		return
	if hillside_support != null:
		hillside_support.clear_ball(ball)
	if is_instance_valid(ball):
		if is_instance_valid(boundary):
			boundary._disconnect_ball(ball)
			boundary._forget(ball.get_instance_id(), boundary._resolver_ids.get(ball.get_instance_id(), -1))
		if ball.physics_contact_router.get_object() == self:
			ball.physics_contact_router = Callable()
	bound_balls.assign(bound_balls.filter(func(reference: WeakRef) -> bool:
		return is_instance_valid(reference.get_ref()) and reference.get_ref() != ball))


func _pause_hillside() -> void:
	suspended = true
	issued = false
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if hillside_support != null:
		hillside_support.retire()
	# These are the exact captured ball delegates. Never select lab._batted_ball here.
	for reference: WeakRef in bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if is_instance_valid(ball):
			ball.freeze = true
			ball.process_mode = Node.PROCESS_MODE_DISABLED
			if is_instance_valid(lab) and ball.surface_contact.is_connected(lab._on_batted_surface_contact):
				ball.surface_contact.disconnect(lab._on_batted_surface_contact)
	disconnect_balls()
	_disconnect_environment()
	if not environment_lease.is_empty():
		if hillside_support != null and hillside_support.cleanup_owned():
			StadiumHillsideEnvironmentV1.restore(lab, environment_lease)
		else:
			StadiumHillsideEnvironmentV1.abandon(lab, environment_lease)
	if hillside_support == null or not hillside_support.cleanup_owned():
		return
	restore_presentations()
	if not hillside_support.cleanup_owned():
		return
	lab.set_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND, true)
	lab.set_meta("stadium_npc_runtime_interrupted", true)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab._automation = null
	if is_instance_valid(_resolver):
		if _resolver.play_resolved.is_connected(lab._on_ball_play_resolved):
			_resolver.play_resolved.disconnect(lab._on_ball_play_resolved)
		if _resolver.segment_observer == Callable(self, "observe"):
			_resolver.segment_observer = Callable()
	if is_instance_valid(receiver):
		if receiver._rock != null and receiver._rock.is_valid():
			receiver._rock.kill()
		if receiver._pocket != null and receiver._pocket.is_valid():
			receiver._pocket.kill()
		if receiver is StadiumNpcRetainedClubReceiver:
			receiver._cancel_active()
	if not hillside_support.cleanup_owned():
		return
	if is_instance_valid(_actor):
		_actor.receiver_router = Callable()
		_actor.reset_pitch()
	if not hillside_support.cleanup_owned():
		return
	if is_instance_valid(_release):
		_release.cancel()
	if not hillside_support.cleanup_owned():
		return
	if is_instance_valid(_cadence):
		_cadence.stop()


func has_ac02_issue() -> bool:
	return _ac02_issued_once or _ac02_issue_pin != null


func ac02_revoke(reason: String) -> void:
	if ac02_startup_pending():
		_abort_startup(reason)
		return
	if _ac02_preparing:
		_ac02_preparation_failed = true
	if _ac02_issue_pin != null:
		_ac02_issue_pin.revoke(reason)


func ac02_owns_cleanup() -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	return _ac02_issue_pin != null and _ac02_issue_pin.owns_cleanup(lab, self)


func ac02_cleanup_local() -> void:
	ac02_revoke("old-owned local cleanup")
	if _ac02_issue_pin != null:
		_ac02_issue_pin.cleanup_local(self)
	suspended = true
	issued = false


func ac02_startup_pending() -> bool:
	return _ac02_startup_enrolled and not _ac02_startup_committed




func _ac02_startup_capture() -> void:
	# Same historical captures, before VALIDATING. No public issue/installed dispatch.
	_host_count = _host.get_child_count(true)
	_visibility_pin = _visibility_data()
	_route_pin = route_obstacles().duplicate(true)
	_pin_resource(field)
	_capture_node(self)
	for node: Node in find_children("*", "", true, false):
		_capture_node(node)
	for model: Node3D in [receiver.chair, receiver.net]:
		_receiver_meshes[model] = model.get_node("Visual").find_children("*", "MeshInstance3D", true, \
			false)


func _ac02_startup_actor(attempt: RefCounted) -> bool:
	if attempt != _ac02_startup_attempt or not attempt.setup_owners(self):
		return false
	super.refresh_actor_presentation(attempt.lab)
	# No-live guide body restores its captured guide presentation, never asks public
	# camera/callback admission to become true while the attempt is pending.
	ac02_guides.restore_all()
	return attempt.setup_owners(self)


func _ac02_startup_receiver(attempt: RefCounted, force_visible: bool = false) -> bool:
	if attempt != _ac02_startup_attempt or not attempt.setup_owners(self):
		return false
	StadiumBaseMarkerVisibility.update(self, attempt.lab._camera, null)
	rebind(attempt.lab._match_state)
	if not _ac02_startup_actor(attempt):
		return false
	_refresh_receiver_visuals(attempt.lab, force_visible)
	return attempt.setup_owners(self)


func _abort_startup(why: String) -> void:
	if _ac02_startup_attempt != null:
		_ac02_startup_attempt.abort(why)
	else:
		# A lost attempt can deny but cannot select a replacement cleanup owner.
		suspended = true
		issued = false

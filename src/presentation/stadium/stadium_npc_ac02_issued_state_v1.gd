class_name StadiumNpcAc02IssuedStateV1
extends RefCounted
enum Outcome { INELIGIBLE, INVALIDATED, ACTIVE }
enum Lifetime { PREPARING, INACTIVE, ACTIVE, REVOKED }

## AC02-only private authority receipt plus a separate fixed-role live owner table.
## Never serializes, replaces, freezes or adopts a caller's source containers.
# gdlint: disable=max-returns,max-file-lines,max-public-methods
const VERSION: int = 1
const FAMILY: String = "ac02-issued-state-v1"
const MUTATION_CONTRACT: String = "detached-primitive-records-supported-writers-deep-boundaries-v1"
const COMPLETION_CONTRACT: String = "automated-in-memory-completion-no-export-v1"
const MAX_DEPTH: int = 24
const MAX_ENTRIES: int = 262144
const MAX_STRING_BYTES: int = 16777216
const RECORD_KEYS: Array[String] = [
	"family", "version", "venue", "revision", "issue_generation", "receipt", "context"
]
const CONTEXT_KEYS: Array[String] = [
	"season_seed",
	"career_run",
	"season_phase",
	"round_index",
	"fixture_id",
	"fixture_row",
	"managed",
	"player_home",
	"automation_seed"
]
const ROLES: Array[String] = [
	"lab",
	"property",
	"host",
	"match",
	"season",
	"career",
	"automation",
	"actor",
	"resolver",
	"fielder",
	"camera",
	"director",
	"sounds",
	"release",
	"cadence",
	"construction",
	"field",
	"receiver",
	"boundary",
	"source",
	"graph",
	"display",
	"visibility",
	"recipe",
	"prisms",
	"guides",
	"cutaway",
	"readability",
	"batter",
	"pitcher",
	"bat",
	"fielder_avatar",
	"chair",
	"net",
	"chair_visual",
	"net_visual"
]
const NATIVE_NODE_CLASSES: Array[String] = [
	"Node3D", "MeshInstance3D", "StaticBody3D", "CollisionShape3D", "Label3D"
]
const NATIVE_RESOURCE_CLASSES: Array[String] = [
	"ArrayMesh",
	"BoxMesh",
	"CylinderMesh",
	"CapsuleMesh",
	"SphereMesh",
	"StandardMaterial3D",
	"BoxShape3D",
	"ConvexPolygonShape3D",
	"CylinderShape3D",
	"CapsuleShape3D",
	"SphereShape3D",
	"PhysicsMaterial"
]

var state: Lifetime = Lifetime.PREPARING
var generation: int = 1
var reason: String = ""
var _record: Dictionary = {}
var _record_pin: Dictionary = {}
var _bindings: Dictionary = {}
var _bindings_pin: Dictionary = {}
var _sources: Dictionary = {}
var _sources_pin: Dictionary = {}
var _receiver_handles: Array = []
var _receiver_handles_pin: Array = []
var _owned_originals: Array[Node] = []
var _owned_originals_pin: Array[Node] = []
var _original_order: Array[Node] = []
var _original_order_pin: Array[Node] = []
var _original_restore_pending: bool = false
var _releasing_originals: bool = false
var _fixture_slot: int = -1
var _fixture_regular: bool = true
var _ball: BattedBallBody
var _ball_binding: bool = false
var _ball_state: BallPlayState
var _cleanup_automation: MatchAutomation
var _cleanup_career: ClubCareer
var _settlement_saving: bool = false
var _settlement_save_lost: bool = false
var _deep_checking: bool = false
var _pausing: bool = false
var _paused: bool = false
var _local_released: bool = false
var _restoring: bool = false
var _restored: bool = false
var _settlement_report: Dictionary = {}
# Diagnostic scheduling only: these fields never prove export or settlement authority.
# A crash can lose all QC since the last successful explicit/final/leave/reset flush.
var _manual_qc_opted_out: bool = false
var _manual_qc_started: bool = false
var _manual_qc_exporter: PlayRecordExport
var _manual_qc_records: Array[PlayRecord] = []
var _manual_qc_count: int = 0
var _manual_qc_dirty_revision: int = 0
var _manual_qc_saved_revision: int = 0
var _manual_qc_flushing: bool = false
var _manual_qc_terminal_attempted: bool = false
var _manual_qc_terminal_count: int = 0
var _manual_qc_terminal_revision: int = 0


static func try_issue(
	lab: PitchBatLab,
	property: StadiumNpcPublicProperty,
	native_admission: StadiumNpcAc02IssuedNativeAdmissionV1,
	deployment_qualified: bool = false
) -> Dictionary:
	# Original issue_installation already completed installed() AND final callback_intact().
	# Only the synchronous issue_installation continuation may prepare a new issuer.
	if (
		not is_instance_valid(property)
		or property.has_ac02_issue()
		or not property.issued
		or property.suspended
		or property._cleaning
		or not property._ac02_preparing
	):
		return {"status": Outcome.INVALIDATED}
	if (
		property.venue_id != "AC-02"
		or not deployment_qualified
		or native_admission == null
		or not native_admission.admitted()
	):
		return {"status": Outcome.INELIGIBLE}
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.new()
	if not issue._prepare(lab, property):
		return (
			{"status": Outcome.INELIGIBLE}
			if issue.state == Lifetime.INACTIVE
			else {"status": Outcome.INVALIDATED}
		)
	# No token is visible while the original historical dispatch runs.
	if (
		not property.callback_intact()
		or not issue._owners(lab, property)
		or not issue._context(lab, property)
		or not issue._structure()
		or not issue._canonical_matches(lab, property)
	):
		issue.revoke("preparation invalidated")
		return {"status": Outcome.INVALIDATED}
	issue.state = Lifetime.ACTIVE
	return {"status": Outcome.ACTIVE, "issuer": issue}


func _prepare(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	if property._nodes.is_empty() or property._resources.is_empty():
		revoke("required historical captures missing")
		return false
	for row: Dictionary in property._nodes:
		if (
			not row.has_all(["node", "parent", "script", "count", "process", "meta"])
			or not row.node is Node
			or not is_instance_valid(row.node)
			or row.node.is_queued_for_deletion()
		):
			revoke("required historical capture damaged")
			return false
	if (
		not _exact_participants(lab, property)
		or not property.ordinary_callbacks()
		or not _native_capture_eligible(property)
		or not is_same(property._ac02_factory_origin, property._ac02_factory_origin_pin)
		or property._ac02_factory_origin.size() != 5
		or (
			property._ac02_factory_origin
			!= [
				property,
				property.construction,
				property.boundary,
				property.receiver,
				property.field
			]
		)
	):
		state = Lifetime.INACTIVE
		return false
	_bindings = _participants(lab, property)
	_bindings.make_read_only()
	_bindings_pin = _bindings
	_cleanup_career = _bindings.career
	_owned_originals = property.old_nodes.duplicate()
	_owned_originals.make_read_only()
	_owned_originals_pin = _owned_originals
	_original_order = property.host_children.duplicate()
	_original_order.make_read_only()
	_original_order_pin = _original_order
	_receiver_handles = []
	for model: Node3D in [property.receiver.chair, property.receiver.net]:
		var meshes: Array = property._receiver_meshes.get(model, [])
		if meshes.is_empty() or meshes.size() > 64:
			state = Lifetime.INACTIVE
			return false
		for mesh: MeshInstance3D in meshes:
			if (
				not _native(mesh, "MeshInstance3D", null)
				or not _native(mesh.material_override, "StandardMaterial3D", null)
			):
				state = Lifetime.INACTIVE
				return false
			var handle: Array = [
				mesh,
				mesh.get_parent(),
				mesh.material_override,
				mesh.material_overlay,
				mesh.mesh,
				StadiumNpcClubNetV1.PANELS.has(String(mesh.name))
			]
			handle.make_read_only()
			_receiver_handles.append(handle)
	_receiver_handles.make_read_only()
	_receiver_handles_pin = _receiver_handles
	_cleanup_automation = lab._automation
	_ball = lab._batted_ball
	# The new issue begins only at the reviewed factory's idle installation boundary.
	if _ball != null or not property.bound_balls.is_empty():
		state = Lifetime.INACTIVE
		return false
	var canonical: Dictionary = StadiumNpcSnapshot.normalized(lab._match_state.stadium)
	if canonical.is_empty() or canonical.manifest.id != "AC-02" or canonical.manifest.revision != 1:
		revoke("canonical prerequisite failed")
		return false
	# Canonical receipt may accept historical numeric representations that this narrower
	# scalar hot proof does not. That is eligibility only, not a new historical rejection.
	if typeof(lab._match_state.stadium.manifest.get("revision")) != TYPE_INT:
		state = Lifetime.INACTIVE
		return false
	for key: String in canonical.binding:
		if typeof(lab._match_state.stadium.binding.get(key)) != typeof(canonical.binding[key]):
			state = Lifetime.INACTIVE
			return false
	var fixture_id: int = canonical.binding.fixture
	_fixture_regular = fixture_id < 30
	var rows: Array[Dictionary] = (
		lab._npc_season.schedule if _fixture_regular else lab._npc_season.semifinals
	)
	if rows.size() > (30 if _fixture_regular else 2):
		state = Lifetime.INACTIVE
		return false
	for index in range(rows.size()):
		if rows[index].get("id") == fixture_id:
			_fixture_slot = index
			break
	if _fixture_slot < 0:
		revoke("selected fixture disappeared")
		return false
	var fixture: Dictionary = _selected_fixture(rows[_fixture_slot])
	if fixture.is_empty():
		state = Lifetime.INACTIVE
		return false
	# Capture canonical output only, never walk raw caller dictionaries with a new copier.
	# This unchanged validator also establishes the selected fixture's original authority.
	if not StadiumNpcSnapshot.matches_fixture(canonical, lab._npc_season, fixture):
		revoke("canonical fixture prerequisite failed")
		return false
	_sources = {
		"receipt": lab._match_state.stadium,
		"public_snapshot": property.public_snapshot,
		"lab_snapshot": lab.get_meta("stadium_snapshot", {}),
		"assignments": lab._npc_season.npc_venues,
		"public_assignments": property.public_assignments,
		"public_fixture": property.public_fixture,
		"schedule": lab._npc_season.schedule,
		"semifinals": lab._npc_season.semifinals,
		"fixture": rows[_fixture_slot],
		"binding": lab._match_state.stadium.binding,
		"manifest": lab._match_state.stadium.manifest,
		"environment": lab._match_state.stadium.environment
	}
	_sources.make_read_only()
	_sources_pin = _sources
	var context: Dictionary = {
		"season_seed": lab._npc_season.season_seed,
		"career_run": SeasonVenues.run_for(lab._npc_season),
		"season_phase": lab._npc_season.phase,
		"round_index": lab._npc_season.round_index,
		"fixture_id": fixture_id,
		"fixture_row": fixture,
		"managed": lab._managed_match,
		"player_home": lab._player_home,
		"automation_seed": null if lab._automation == null else lab._automation.seed
	}
	var owned: Dictionary = {
		"family": FAMILY,
		"version": VERSION,
		"venue": "AC-02",
		"revision": 1,
		"issue_generation": generation,
		"receipt": canonical,
		"context": context
	}
	var budget: Array[int] = [MAX_ENTRIES, MAX_STRING_BYTES]
	var frozen: Variant = _copy_canonical(owned, budget)
	if not frozen is Dictionary:
		state = Lifetime.INACTIVE
		return false
	_record = frozen
	_record_pin = _record
	return true


static func _selected_fixture(row: Dictionary) -> Dictionary:
	# Selected scalar shape only. No history, arbitrary keys or nested raw data.
	var keys: Array = ["id", "round", "away", "home"]
	if row.has("neutral"):
		keys.append("neutral")
	if not StadiumNpcSnapshot._keys(row, keys):
		return {}
	for key: String in ["id", "round", "away", "home"]:
		if typeof(row[key]) != TYPE_INT:
			return {}
	if row.has("neutral") and typeof(row.neutral) != TYPE_BOOL:
		return {}
	var result: Dictionary = {"id": row.id, "round": row.round, "away": row.away, "home": row.home}
	if row.has("neutral"):
		result["neutral"] = row.neutral
	return result


static func _copy_canonical(value: Variant, budget: Array[int], depth: int = 0) -> Variant:
	# Private primitive copy; also used for the one synchronous settlement-save witness.
	# null is legitimate canonical context; an exhausted budget is the error sentinel.
	budget[0] -= 1
	if depth > MAX_DEPTH or budget[0] < 0:
		budget[0] = -1
		return null
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			budget[0] -= 1
			if budget[0] < 0 or typeof(key) != TYPE_STRING:
				budget[0] = -1
				return null
			budget[1] -= key.to_utf8_buffer().size()
			result[key] = _copy_canonical(value[key], budget, depth + 1)
			if budget[0] < 0 or budget[1] < 0:
				return null
		result.make_read_only()
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_copy_canonical(item, budget, depth + 1))
			if budget[0] < 0 or budget[1] < 0:
				return null
		result.make_read_only()
		return result
	if typeof(value) == TYPE_STRING:
		budget[1] -= value.to_utf8_buffer().size()
		return value
	if (
		typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT]
		or (typeof(value) == TYPE_FLOAT and is_finite(value))
	):
		return value
	budget[0] = -1
	return null


func revoke(why: String) -> void:
	if state == Lifetime.REVOKED:
		return
	state = Lifetime.REVOKED
	generation = 2
	reason = why
	var receiver: StadiumNpcAc02PublicReceiver = (
		_bindings.get("receiver") as StadiumNpcAc02PublicReceiver
	)
	if is_instance_valid(receiver):
		receiver.cleanup_issued_local()


func hot_intact(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, expected_generation: int
) -> bool:
	if (
		state != Lifetime.ACTIVE
		or generation != expected_generation
		or expected_generation != 1
		or not is_instance_valid(property)
		or property._ac02_issue != self
		or property._ac02_issue_pin != self
		or not property._ac02_issued_once
		or not property.issued
		or property.suspended
		or property._cleaning
		or not is_instance_valid(lab)
		or lab._ac02_issued_owner != self
		or not _owners(lab, property)
		or not _context(lab, property)
		or not _dynamic(lab, property)
	):
		revoke("active owner, context or dynamic proof lost")
		return false
	return true


func _owners(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	if (
		not is_same(_bindings, _bindings_pin)
		or _bindings.size() != ROLES.size()
		or not _exact_participants(lab, property)
	):
		return false
	var current: Dictionary = _participants(lab, property)
	for role: String in ROLES:
		if not _bindings.has(role) or current[role] != _bindings[role]:
			return false
	return (
		StadiumNpcPublicRuntime._property(lab) == property
		and property.bound_state == lab._match_state
		and property.public_season == lab._npc_season
		and property.public_automation == lab._automation
		and property.lab_ref != null
		and property.lab_ref.get_ref() == lab
	)


func _context(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	if (
		not is_same(_record, _record_pin)
		or not _record.has("context")
		or not is_same(_sources, _sources_pin)
		or _sources.size() != 12
	):
		return false
	var context: Dictionary = _record.context
	var season: SeasonState = lab._npc_season
	if (
		not is_same(lab._match_state.stadium, _sources.receipt)
		or not is_same(property.public_snapshot, _sources.public_snapshot)
		or not is_same(lab.get_meta("stadium_snapshot", {}), _sources.lab_snapshot)
		or not is_same(season.npc_venues, _sources.assignments)
		or not is_same(property.public_assignments, _sources.public_assignments)
		or not is_same(property.public_fixture, _sources.public_fixture)
		or not is_same(season.schedule, _sources.schedule)
		or not is_same(season.semifinals, _sources.semifinals)
		or not is_same(lab._match_state.stadium.get("binding"), _sources.binding)
		or not is_same(lab._match_state.stadium.get("manifest"), _sources.manifest)
		or not is_same(lab._match_state.stadium.get("environment"), _sources.environment)
		or season.season_seed != context.season_seed
		or SeasonVenues.run_for(season) != context.career_run
		or season.phase != context.season_phase
		or season.round_index != context.round_index
		or lab._managed_match != context.managed
		or property.public_managed != context.managed
		or lab._player_home != context.player_home
		or (null if lab._automation == null else lab._automation.seed) != context.automation_seed
	):
		return false
	var rows: Array[Dictionary] = season.schedule if _fixture_regular else season.semifinals
	if (
		_fixture_slot < 0
		or _fixture_slot >= rows.size()
		or not is_same(rows[_fixture_slot], _sources.fixture)
	):
		return false
	var row: Dictionary = rows[_fixture_slot]
	if row.size() != context.fixture_row.size():
		return false
	for key: String in context.fixture_row:
		if (
			not row.has(key)
			or typeof(row[key]) != typeof(context.fixture_row[key])
			or row[key] != context.fixture_row[key]
		):
			return false
	# Bounded selected authority only. Identity is NOT a nested-content validation claim.
	var binding: Dictionary = _sources.binding
	for key: String in _record.receipt.binding:
		if (
			not binding.has(key)
			or typeof(binding[key]) != typeof(_record.receipt.binding[key])
			or binding[key] != _record.receipt.binding[key]
		):
			return false
	return (
		_sources.manifest.get("id") == "AC-02"
		and typeof(_sources.manifest.get("revision")) == TYPE_INT
		and _sources.manifest.revision == 1
		and _sources.receipt.get("version") == _record.receipt.version
		and _sources.receipt.get("authority") == _record.receipt.authority
		and _public_mode(lab, property)
	)


static func _public_mode(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	if (
		not lab._match_mode
		or lab._configured_match != null
		or lab._stadium_ledger != null
		or lab.pool_active_receipt != null
		or lab.pool_controller_active != null
		or lab.hillside_private_runtime != null
		or lab._hillside_private_owner_identity != null
		or lab.has_node("HillsidePrivateRuntime")
		or StadiumPoolBoundExtension.requested(lab)
		or StadiumPoolOwnedExtension.requested(lab)
		or not property.public_bound
		or not lab.has_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND)
		or typeof(lab.get_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND, false)) != TYPE_BOOL
		or lab.get_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND, false) != true
	):
		return false
	for marker: StringName in (
		StadiumScoreboardRuntime.AUTHORING
		+ [
			&"stadium_npc_retained_lab_only",
			&"stadium_npc_ay02_installed_lab_only",
			&"stadium_npc_ay03_installed_lab_only",
			&"stadium_candidate_only",
			&"stadium_npc_runtime_interrupted",
			&"stadium_npc_runtime_restoring"
		]
	):
		if lab.has_meta(marker):
			return false
	return property.venue_id == "AC-02" and (lab._managed_match or lab._automation != null)


func _dynamic(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	var host: Node3D = _bindings.host
	if (
		property.get_parent() != host
		or host.get_parent() != lab
		or lab.get_node_or_null("StarterFieldGeometry") != host
		or host.get_node_or_null("HomeProperty") != property
		or host.global_transform != Transform3D.IDENTITY
		or property.transform != Transform3D.IDENTITY
		or property.top_level
		or host.get_child_count(true) != property._host_count
		or property.process_mode != Node.PROCESS_MODE_INHERIT
		or not property.is_processing()
		or not property.is_physics_processing()
		or property.process_priority != -100
		or property.process_physics_priority != -100
		or lab._field_definition != _bindings.field
		or lab._field_id != property.field.id
		or property.construction.field != property.field
		or property.construction.get_parent() != property
		or property.boundary.get_parent() != property
		or property.boundary.source != _bindings.source
		or property.boundary.graph != _bindings.graph
		or property.boundary.source.graph != _bindings.graph
		or property.receiver.get_parent() != property
		or property.receiver.sounds != _bindings.sounds
		or property.receiver.camera_protection != property._receiver_camera_protection
		or property.display._match != _bindings.match
		or property.presentation_camera == null
		or property.presentation_camera.get_ref() != _bindings.camera
		or not lab._camera_director.presentation_override.is_null()
		or lab._camera.cull_mask != property.old_camera_mask
		or lab._camera_director.camera_mask != 80
		or lab._camera_director.lab_ref == null
		or lab._camera_director.lab_ref.get_ref() != lab
		or property.presentation_director.tracking_visibility.property != property
		or property.presentation_director.tracking_visibility._recipe != _bindings.recipe
		or property.presentation_director.tracking_visibility._wall_prisms != _bindings.prisms
		or not property.ordinary_callbacks()
		or not property.routing_intact()
		or not property.ac02_guides.owners_intact()
		or not property._receiver_style_intact(property.receiver.chair)
		or not property._receiver_style_intact(property.receiver.net)
		or not is_finite(property.receiver.flex_elapsed)
		or property.receiver.flex_elapsed < 0
		or property.receiver.flex_elapsed > StadiumNpcClubNetV1.SETTLE
		or not property.receiver.flex_impact.is_finite()
	):
		return false
	if not is_same(_receiver_handles, _receiver_handles_pin) or _receiver_handles.is_empty():
		return false
	for value: Variant in _receiver_handles:
		if not _receiver_handle_shape(value):
			return false
		var handle: Array = value
		if (
			not _native(handle[0], "MeshInstance3D", null)
			or handle[0].get_parent() != handle[1]
			or not _native(handle[2], "StandardMaterial3D", null)
			or handle[0].material_override != handle[2]
			or handle[0].material_overlay != handle[3]
			or handle[0].mesh == null
			or handle[0].mesh.get_script() != null
			or (not handle[5] and handle[0].mesh != handle[4])
			or (handle[5] and handle[0].mesh.get_class() != "ArrayMesh")
		):
			return false
		if (
			handle[0].name == &"ST026_PANEL"
			and (
				not is_finite(handle[0].position.z)
				or handle[0].position.z < -0.042501
				or handle[0].position.z > -0.012499
			)
		):
			return false
	if (
		not _native(property.receiver.chair, "Node3D", null)
		or not _native(property.receiver.net, "Node3D", null)
		or property.receiver.chair != _bindings.chair
		or property.receiver.net != _bindings.net
		or property.receiver.chair.get_node_or_null("Visual") != _bindings.chair_visual
		or property.receiver.net.get_node_or_null("Visual") != _bindings.net_visual
	):
		return false
	if lab._batted_ball != _ball:
		return false
	if (
		_ball != null
		and (
			not _native(_ball, "RigidBody3D", BattedBallBody)
			or (_ball.get_parent() != lab and not _ball_binding)
			or lab._ball_play_resolver.state != _ball_state
			or lab._ball_play_resolver.field != _bindings.field
		)
	):
		return false
	return true


func deep_intact(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	if (
		_deep_checking
		or not _structure()
		or not hot_intact(lab, property, property._ac02_generation)
	):
		revoke("deep entry structure or owner failed")
		return false
	_deep_checking = true
	var native_admission: StadiumNpcAc02IssuedNativeAdmissionV1 = (
		StadiumNpcAc02IssuedNativeAdmissionV1.new()
	)
	# Original installed_bound predicates, with observation threaded through the same
	# unchanged installed() body. No second geometry traversal or relaxed predicate.
	var valid: bool = (
		_structure()
		and _native_capture_eligible(property)
		and _canonical_matches(lab, property)
		and StadiumNpcPublicRuntime._property(lab) == property
		and property.public_snapshot == _sources.public_snapshot
		and StadiumNpcPublicRuntime.installed(lab, native_admission)
	)
	native_admission.complete(valid)
	valid = valid and native_admission.admitted()
	_deep_checking = false
	if not valid or not hot_intact(lab, property, property._ac02_generation):
		revoke("deep receipt, role or historical proof failed")
		return false
	return true


func _structure() -> bool:
	if (
		not is_same(_record, _record_pin)
		or not StadiumNpcSnapshot._keys(_record, RECORD_KEYS)
		or not StadiumNpcSnapshot._keys(_record.get("context"), CONTEXT_KEYS)
		or _record.family != FAMILY
		or typeof(_record.family) != TYPE_STRING
		or typeof(_record.version) != TYPE_INT
		or _record.version != VERSION
		or typeof(_record.venue) != TYPE_STRING
		or _record.venue != "AC-02"
		or typeof(_record.revision) != TYPE_INT
		or _record.revision != 1
		or typeof(_record.issue_generation) != TYPE_INT
		or _record.issue_generation != 1
		or not is_same(_bindings, _bindings_pin)
		or not _bindings.is_read_only()
		or not StadiumNpcSnapshot._keys(_bindings, ROLES)
		or not is_same(_sources, _sources_pin)
		or not _sources.is_read_only()
		or not StadiumNpcSnapshot._keys(
			_sources,
			[
				"receipt",
				"public_snapshot",
				"lab_snapshot",
				"assignments",
				"public_assignments",
				"public_fixture",
				"schedule",
				"semifinals",
				"fixture",
				"binding",
				"manifest",
				"environment"
			]
		)
		or not _record.receipt is Dictionary
		or not is_same(_owned_originals, _owned_originals_pin)
		or not _owned_originals.is_read_only()
		or not is_same(_original_order, _original_order_pin)
		or not _original_order.is_read_only()
		or not is_same(_receiver_handles, _receiver_handles_pin)
		or not _receiver_handles.is_read_only()
	):
		return false
	var context: Dictionary = _record.context
	if not context.fixture_row is Dictionary:
		return false
	for value: Variant in _receiver_handles:
		if not _receiver_handle_shape(value):
			return false
	for key: String in ["season_seed", "career_run", "season_phase", "round_index", "fixture_id"]:
		if typeof(context[key]) != TYPE_INT:
			return false
	return (
		typeof(context.managed) == TYPE_BOOL
		and typeof(context.player_home) == TYPE_BOOL
		and typeof(context.automation_seed) in [TYPE_NIL, TYPE_INT]
		and not _selected_fixture(context.fixture_row).is_empty()
		and _readonly_json(_record, [MAX_ENTRIES, MAX_STRING_BYTES])
	)


static func _receiver_handle_shape(value: Variant) -> bool:
	if not value is Array or value.size() != 6 or not value.is_read_only():
		return false
	return (
		value[0] is MeshInstance3D
		and is_instance_valid(value[0])
		and value[1] is Node
		and is_instance_valid(value[1])
		and value[2] is StandardMaterial3D
		and is_instance_valid(value[2])
		and (value[3] == null or (value[3] is Material and is_instance_valid(value[3])))
		and value[4] is Mesh
		and is_instance_valid(value[4])
		and typeof(value[5]) == TYPE_BOOL
	)


static func _readonly_json(value: Variant, budget: Array[int], depth: int = 0) -> bool:
	budget[0] -= 1
	if depth > MAX_DEPTH or budget[0] < 0:
		return false
	if value is Dictionary:
		if not value.is_read_only():
			return false
		for key: Variant in value:
			if typeof(key) != TYPE_STRING:
				return false
			budget[1] -= key.to_utf8_buffer().size()
			if not _readonly_json(value[key], budget, depth + 1):
				return false
		return budget[1] >= 0
	if value is Array:
		if not value.is_read_only():
			return false
		for item: Variant in value:
			if not _readonly_json(item, budget, depth + 1):
				return false
		return budget[1] >= 0
	if typeof(value) == TYPE_STRING:
		budget[1] -= value.to_utf8_buffer().size()
		return budget[1] >= 0
	return (
		typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT]
		or (typeof(value) == TYPE_FLOAT and is_finite(value))
	)


func _canonical_matches(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	var current: Dictionary = StadiumNpcSnapshot.normalized(lab._match_state.stadium)
	return (
		not current.is_empty()
		and _same_plain(current, _record.receipt)
		and _same_plain(StadiumNpcSnapshot.normalized(property.public_snapshot), _record.receipt)
		and _same_plain(
			StadiumNpcSnapshot.normalized(lab.get_meta("stadium_snapshot", {})), _record.receipt
		)
		and _same_plain(_selected_fixture(_sources.fixture), _record.context.fixture_row)
		and StadiumNpcSnapshot.matches_fixture(
			current, lab._npc_season, _record.context.fixture_row
		)
	)


static func _same_plain(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		if left.size() != right.size():
			return false
		for key: String in left:
			if not right.has(key) or not _same_plain(left[key], right[key]):
				return false
		return true
	if left is Array:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _same_plain(left[index], right[index]):
				return false
		return true
	return left == right


static func _participants(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> Dictionary:
	var view: StadiumNpcAc02PublicVisibility = property.presentation_director.tracking_visibility
	return {
		"lab": lab,
		"property": property,
		"host": property.get_parent(),
		"match": lab._match_state,
		"season": lab._npc_season,
		"career": lab._npc_season.career,
		"automation": lab._automation,
		"actor": lab._pitch_actor,
		"resolver": lab._ball_play_resolver,
		"fielder": lab._primary_fielder,
		"camera": lab._camera,
		"director": lab._camera_director,
		"sounds": lab._sounds,
		"release": lab._release_controller,
		"cadence": lab._at_bat_cadence,
		"construction": property.construction,
		"field": property.field,
		"receiver": property.receiver,
		"boundary": property.boundary,
		"source": property.boundary.source,
		"graph": property.boundary.graph,
		"display": property.display,
		"visibility": view,
		"recipe": view._recipe,
		"prisms": view._wall_prisms,
		"guides": property.ac02_guides,
		"cutaway": property.actor_cutaway,
		"readability": property.ball_readability,
		"batter": lab._batter_avatar,
		"pitcher": lab._pitcher_avatar,
		"bat": lab._bat_actor,
		"fielder_avatar": lab._primary_fielder._avatar,
		"chair": property.receiver.chair,
		"net": property.receiver.net,
		"chair_visual": property.receiver.chair.get_node_or_null("Visual"),
		"net_visual": property.receiver.net.get_node_or_null("Visual")
	}


static func _native(value: Variant, native_class: String, script: Variant) -> bool:
	if (
		not value is Object
		or not is_instance_valid(value)
		or value.get_class() != native_class
		or value.get_script() != script
	):
		return false
	return not value is Node or (not value.is_queued_for_deletion() and value.is_inside_tree())


static func _exact_participants(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	# Exact native base classes plus exact scripts under the qualified no-extension engine.
	# Check a scripted target BEFORE reading its fields. Null script alone is never eligibility.
	if (
		not _native(lab, "Node3D", PitchBatLab)
		or not _native(property, "Node3D", StadiumNpcPublicProperty)
		or not _native(lab._match_state, "RefCounted", MatchState)
		or not _native(lab._npc_season, "RefCounted", SeasonState)
		or (
			lab._npc_season.career != null
			and not _native(lab._npc_season.career, "RefCounted", ClubCareer)
		)
		or (lab._automation != null and not _native(lab._automation, "RefCounted", MatchAutomation))
		or not _native(property.get_parent(), "Node3D", StarterFieldLabGeometry)
		or not _native(property.construction, "Node3D", StadiumNpcAc02PublicConstruction)
		or not _native(property.boundary, "Node3D", StadiumNpcAc02PublicBoundary)
		or not _native(property.receiver, "Node3D", StadiumNpcAc02PublicReceiver)
		or not _native(property.field, "Resource", FieldDefinition)
		or not _native(property.display, "Node3D", StadiumNpcClubDisplayV1)
		or not _native(lab._camera_director, "RefCounted", StadiumNpcAc02PublicCamera)
		or property.presentation_director != lab._camera_director
	):
		return false
	if (
		not _native(property.boundary.source, "Node3D", StadiumNpcAc02PublicBoundarySource)
		or not _native(property.boundary.graph, "RefCounted", StadiumNpcAc02PublicGraph)
		or not _native(
			property.presentation_director.tracking_visibility,
			"RefCounted",
			StadiumNpcAc02PublicVisibility
		)
	):
		return false
	var view: StadiumNpcAc02PublicVisibility = property.presentation_director.tracking_visibility
	return (
		_native(view._recipe, "RefCounted", StadiumNpcAc02PublicGraph)
		and _native(view._wall_prisms, "RefCounted", StadiumWallViewPrisms)
		and _native(property.ac02_guides, "RefCounted", StadiumNpcAc02PublicGuides)
		and _native(property.actor_cutaway, "RefCounted", StadiumNpcRetainedActorCutaway)
		and _native(property.ball_readability, "RefCounted", StadiumNpcRetainedBallReadability)
		and _native(lab._camera, "Camera3D", null)
		and _native(lab._pitch_actor, "Node3D", PitchFlightActor)
		and _native(lab._ball_play_resolver, "RefCounted", BallPlayResolver)
		and _native(lab._primary_fielder, "CharacterBody3D", FielderController)
		and _native(lab._sounds, "Node", PlaySounds)
		and _native(lab._release_controller, "RefCounted", PitchReleaseController)
		and _native(lab._at_bat_cadence, "RefCounted", AtBatCadenceController)
		and _native(lab._batter_avatar, "Node3D", PlayerAvatar)
		and _native(lab._pitcher_avatar, "Node3D", PlayerAvatar)
		and _native(lab._bat_actor, "Node3D", BatActor)
		and _native(lab._primary_fielder._avatar, "Node3D", PlayerAvatar)
	)


func owns_cleanup(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	return _owns_cleanup_career(lab, property, _cleanup_career)


func _owns_cleanup_career(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, career: ClubCareer
) -> bool:
	# The replacement-aware form is private to the synchronous save transaction.
	# Ordinary cleanup uses only the last explicitly accepted cleanup identity.
	if (
		not is_same(_bindings, _bindings_pin)
		or not _bindings.has_all(ROLES)
		or not is_instance_valid(lab)
		or not is_instance_valid(property)
		or lab != _bindings.lab
		or property != _bindings.property
		or lab.get_script() != PitchBatLab
		or property.get_script() != StadiumNpcPublicProperty
		or StadiumNpcPublicRuntime._property(lab) != property
		or lab._match_state != _bindings.match
		or lab._npc_season != _bindings.season
		or not is_instance_valid(lab._npc_season)
		or lab._npc_season.career != career
		or lab._automation != _cleanup_automation
		or lab._batted_ball != _ball
		or not is_instance_valid(lab._ball_play_resolver)
		or lab._ball_play_resolver != _bindings.resolver
		or (_ball != null and lab._ball_play_resolver.state != _ball_state)
	):
		return false
	return (
		lab._pitch_actor == _bindings.actor
		and lab._ball_play_resolver == _bindings.resolver
		and lab._primary_fielder == _bindings.fielder
		and lab._camera == _bindings.camera
		and lab._camera_director == _bindings.director
		and lab._sounds == _bindings.sounds
		and lab._release_controller == _bindings.release
		and lab._at_bat_cadence == _bindings.cadence
		and lab._field_definition == _bindings.field
		and lab._batter_avatar == _bindings.batter
		and lab._pitcher_avatar == _bindings.pitcher
		and lab._bat_actor == _bindings.bat
		and lab.get_node_or_null("StarterFieldGeometry") == _bindings.host
		and property.construction == _bindings.construction
		and property.receiver == _bindings.receiver
		and property.boundary == _bindings.boundary
		and property.display == _bindings.display
	)


func save_settlement(app: Variant) -> bool:
	# No receipt or replacement is accepted from a caller. This invocation owns both.
	if _settlement_saving:
		_settlement_save_lost = true
		SeasonSave.last_error = "The AC-02 settlement save was reentered. Ownership was not transferred."
		return false
	var before: Dictionary = _settlement_save_context(app, _cleanup_career)
	if before.is_empty():
		SeasonSave.last_error = \
			("The completed AC-02 game lost its settlement owner. The save was not " + "attempted.")
		return false
	_settlement_saving = true
	_settlement_save_lost = false
	var writes: Array = []
	var saved: bool = SeasonSave.save(before.season, writes)
	var accepted: bool = false
	if (
		saved
		and not _settlement_save_lost
		and writes.size() == 1
		and _cleanup_career == before.career
		and _native(before.season, "RefCounted", SeasonState)
	):
		var write: Array = writes[0]
		if (
			write.size() == 4
			and write[0] == before.season
			and write[1] == before.career
			and write[2] != before.career
			and write[2] == before.season.career
			and _same_plain(write[3], before.career_values)
		):
			var after: Dictionary = _settlement_save_context(app, write[2])
			accepted = (
				not after.is_empty()
				and _same_settlement_context(before, after)
				and _same_plain(before.career_values, after.career_values)
				and _same_plain(before.career_values, _settlement_career_values(before.career))
			)
			if accepted:
				# Neither immutable gameplay bindings nor REVOKED generation/reason change.
				_cleanup_career = write[2]
	_settlement_saving = false
	if saved and not accepted:
		SeasonSave.last_error = ("The season was saved, but AC-02 settlement ownership was lost. " + \
			"Restore the durable pending round to continue.")
	return saved and accepted


func _settlement_save_context(app: Variant, career: Variant) -> Dictionary:
	# Exact scripts precede fields. Unknown/opaque state is not equality authority.
	if (
		state != Lifetime.REVOKED
		or generation != 2
		or reason != "settlement begins"
		or not _native(app, "Node", SeasonApp)
		or not _native(career, "RefCounted", ClubCareer)
		or not career.get_meta_list().is_empty()
	):
		return {}
	var lab: PitchBatLab = app.lab
	var season: SeasonState = app.season
	var ticket: Dictionary = app._ac02_settlement_ticket
	var property: Variant = ticket.get("property")
	if (
		not _native(lab, "Node3D", PitchBatLab)
		or not _native(season, "RefCounted", SeasonState)
		or not _native(property, "Node3D", StadiumNpcPublicProperty)
		or not _native(lab._match_state, "RefCounted", MatchState)
		or not _native(season.physical, "RefCounted", SeasonPhysicalFixtures)
		or not _native(season.ownership, "RefCounted", SeasonOwnership)
		or not _native(season.build, "RefCounted", SeasonBuild)
		or not _native(season.opponents, "RefCounted", SeasonOpponents)
		or not _structure()
		or not _owns_cleanup_career(lab, property, career)
	):
		return {}
	if (
		not app._result_recorded
		or ticket.get("lab") != lab
		or ticket.get("season") != season
		or ticket.get("state") != lab._match_state
		or ticket.get("issue") != self
		or ticket.get("physical") != season.physical
		or typeof(ticket.get("fixture_id")) != TYPE_INT
		or app._fixture_id != ticket.fixture_id
		or lab._match_state.phase != MatchState.Phase.GAME_END
		or not property.has_ac02_issue()
		or property._ac02_issue != self
		or property._ac02_issue_pin != self
		or property._ac02_generation != _record.issue_generation
		or lab._ac02_issued_owner != self
		or not lab._ac02_issued_history
		or not ticket.get("fixture") is Dictionary
		or not ticket.get("human") is Array
		or not is_same(season.physical.pending, ticket.get("pending"))
		or not season.physical.pending.get("human") is Array
	):
		return {}
	var rows: Array[Dictionary] = season.schedule if _fixture_regular else season.semifinals
	if (
		_fixture_slot < 0
		or _fixture_slot >= rows.size()
		or not is_same(rows[_fixture_slot], _sources.fixture)
	):
		return {}
	var budget: Array[int] = [MAX_ENTRIES, MAX_STRING_BYTES]
	var values: Variant = _copy_canonical(
		[
			ticket.fixture,
			ticket.human,
			season.physical.pending,
			season.physical.reports,
			season.physical.cursor,
			season.physical.needed,
			season.physical.error,
			season.physical.projecting,
			season.season_seed,
			season.phase,
			season.round_index,
			season.schedule,
			season.semifinals,
			season.npc_venues,
			season.home_property,
			season.owned_surface_night,
			season.final_venue,
			season.picks,
			season.teams,
			season.results,
			season.player_results,
			season.playoff_seeds,
			season.final_fixture,
			season.champion,
			season.starter_index,
			season.fielder_index,
			season.difficulty,
			_fixture_slot,
			_fixture_regular
		],
		budget
	)
	var career_values: Variant = _copy_canonical(
		[career.current, career.runs, career._assets, career._pennants, career._plaques], budget
	)
	if (
		budget[0] < 0
		or budget[1] < 0
		or not values is Array
		or not career_values is Array
		or not _same_plain(season.physical.pending.human, ticket.human)
		or not _same_plain(_selected_fixture(rows[_fixture_slot]), ticket.fixture)
		or ticket.fixture.get("id") != ticket.fixture_id
	):
		return {}
	return {
		"app": app,
		"lab": lab,
		"season": season,
		"state": lab._match_state,
		"property": property,
		"ticket": ticket,
		"physical": season.physical,
		"pending": season.physical.pending,
		"human": ticket.human,
		"fixture": ticket.fixture,
		"schedule": season.schedule,
		"semifinals": season.semifinals,
		"assignments": season.npc_venues,
		"ownership": season.ownership,
		"build": season.build,
		"opponents": season.opponents,
		"career": career,
		"career_values": career_values,
		"values": values,
		"path": SeasonSave.path,
		"property_generation": property._ac02_generation,
		"binding": _bindings,
		"sources": _sources,
		"record": _record
	}


static func _settlement_career_values(career: Variant) -> Variant:
	if not _native(career, "RefCounted", ClubCareer) or not career.get_meta_list().is_empty():
		return null
	var budget: Array[int] = [MAX_ENTRIES, MAX_STRING_BYTES]
	var result: Variant = _copy_canonical(
		[career.current, career.runs, career._assets, career._pennants, career._plaques], budget
	)
	return result if budget[0] >= 0 and budget[1] >= 0 else null


static func _same_settlement_context(before: Dictionary, after: Dictionary) -> bool:
	for key: String in [
		"app",
		"lab",
		"season",
		"state",
		"property",
		"ticket",
		"physical",
		"pending",
		"human",
		"fixture",
		"schedule",
		"semifinals",
		"assignments",
		"ownership",
		"build",
		"opponents",
		"binding",
		"sources",
		"record"
	]:
		if not is_same(before[key], after[key]):
			return false
	return (
		before.path == after.path
		and before.property_generation == after.property_generation
		and _same_plain(before.values, after.values)
	)


func pause_owned(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	revoke("issued installation paused")
	if _pausing or _paused:
		return
	_pausing = true
	_pause_owned_body(lab, property)
	_paused = true
	_pausing = false


func _pause_owned_body(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	property.suspended = true
	property.issued = false
	if not owns_cleanup(lab, property):
		cleanup_local(property)
		return
	property.restore_presentations()
	if not owns_cleanup(lab, property):
		cleanup_local(property)
		return
	if is_instance_valid(_bindings.display):
		_bindings.display.bind_match(null)
	if not owns_cleanup(lab, property):
		cleanup_local(property)
		return
	lab.set_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND, true)
	lab.set_meta("stadium_npc_runtime_interrupted", true)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_ball):
		_ball.freeze = true
		_ball.process_mode = Node.PROCESS_MODE_DISABLED
		_ball.set_process(false)
		_ball.set_physics_process(false)
		if _ball.surface_contact.is_connected(lab._on_batted_surface_contact):
			_ball.surface_contact.disconnect(lab._on_batted_surface_contact)
	cleanup_local(property)
	if not owns_cleanup(lab, property):
		return
	var resolver: BallPlayResolver = _bindings.resolver
	if is_instance_valid(resolver):
		if resolver.play_resolved.is_connected(lab._on_ball_play_resolved):
			resolver.play_resolved.disconnect(lab._on_ball_play_resolved)
		if resolver.segment_observer == property.observe:
			resolver.segment_observer = Callable()
	if not owns_cleanup(lab, property):
		return
	var receiver: StadiumNpcAc02PublicReceiver = _bindings.receiver
	if is_instance_valid(receiver):
		receiver._cancel_active()
	if not owns_cleanup(lab, property):
		return
	if is_instance_valid(_bindings.actor):
		if _bindings.actor.receiver_router == property.receiver_route:
			_bindings.actor.receiver_router = Callable()
		_bindings.actor.reset_pitch()
	if not owns_cleanup(lab, property):
		return
	if is_instance_valid(_bindings.release):
		_bindings.release.cancel()
	if not owns_cleanup(lab, property):
		return
	if is_instance_valid(_bindings.cadence):
		_bindings.cadence.stop()
	if owns_cleanup(lab, property):
		lab._automation = null
		_cleanup_automation = null


func cleanup_local(property: StadiumNpcPublicProperty) -> void:
	# Old callbacks only. In particular, never call the inherited presentation restore,
	# which can write actors, ball meshes and host guides borrowed by another owner.
	revoke("local release")
	if _local_released:
		return
	_local_released = true
	property.suspended = true
	property.issued = false
	var old_boundary: Node = _bindings.get("boundary") as Node
	var old_resolver: RefCounted = _bindings.get("resolver") as RefCounted
	for reference: WeakRef in property.bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		if ball.physics_contact_router == property._boundary_contact_batch.bind(old_resolver):
			ball.physics_contact_router = Callable()
		if is_instance_valid(old_boundary):
			var seed: Callable = old_boundary._seed.bind(ball.get_instance_id())
			var forget: Callable = (
				old_boundary._forget.bind(ball.get_instance_id(), old_resolver.get_instance_id())
				if is_instance_valid(old_resolver)
				else Callable()
			)
			if ball.launch_started.is_connected(seed):
				ball.launch_started.disconnect(seed)
			if forget.is_valid() and ball.tree_exited.is_connected(forget):
				ball.tree_exited.disconnect(forget)
	property.bound_balls.clear()
	for row: Dictionary in property._nodes:
		var node: Node = row.get("node") as Node
		if not is_instance_valid(node):
			continue
		for signal_name: StringName in [&"tree_exiting", &"child_order_changed", &"script_changed"]:
			if node.is_connected(signal_name, property._installation_changed):
				node.disconnect(signal_name, property._installation_changed)
	for resource: Resource in property._resources:
		if (
			is_instance_valid(resource)
			and resource.changed.is_connected(property._installation_changed)
		):
			resource.changed.disconnect(property._installation_changed)
	var receiver: StadiumNpcAc02PublicReceiver = (
		_bindings.get("receiver") as StadiumNpcAc02PublicReceiver
	)
	if is_instance_valid(receiver):
		receiver.cleanup_issued_local()
	var guides: StadiumNpcAc02PublicGuides = _bindings.get("guides") as StadiumNpcAc02PublicGuides
	if is_instance_valid(guides):
		guides.cleanup_local()


static func current(lab: PitchBatLab) -> StadiumNpcAc02IssuedStateV1:
	return lab._ac02_issued_owner if is_instance_valid(lab) else null


func continue_action(lab: PitchBatLab) -> bool:
	var property: StadiumNpcPublicProperty = _bindings.get("property") as StadiumNpcPublicProperty
	if not is_instance_valid(property) or not hot_intact(lab, property, 1):
		if is_instance_valid(property):
			pause_owned(lab, property)
		return false
	return true


static func complete_automated_record(
	lab: PitchBatLab, result: StringName, runs_scored: int = 0
) -> bool:
	if lab.ac02_startup_pending():
		return true
	# True means consumed (completed OR refused), never permission to fall back.
	# False retains the literal historical/manual finish_record -> deep-save path.
	# Never-issued labs return before any new object-valued metadata/owner observation.
	# This primitive history is not authority; even a forged true value must prove owners.
	if not lab._ac02_issued_history:
		return false
	# Existing interruption presence is a sticky denial, never marker-value authority.
	if lab.has_meta("stadium_npc_runtime_interrupted"):
		return true
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	var issue: StadiumNpcAc02IssuedStateV1 = current(lab)
	if (
		issue == null
		or property == null
		or property._ac02_issue != issue
		or property._ac02_issue_pin != issue
		or not property.has_ac02_issue()
	):
		_mark_completion_refused(lab)
		if issue != null:
			issue._refuse_record_completion(lab)
		if (
			property != null
			and property._ac02_issue_pin != null
			and property._ac02_issue_pin != issue
		):
			property._ac02_issue_pin._refuse_record_completion(lab)
		return true
	# Minimal sticky classification also refuses corrupted NEW manual ownership.
	# Never infer an originally manual issue from a removed live automation pointer.
	if (
		issue.state != Lifetime.ACTIVE
		or issue.generation != 1
		or property._ac02_generation != 1
		or not is_same(issue._bindings, issue._bindings_pin)
		or not issue._bindings.is_read_only()
		or not issue._bindings.has_all(["lab", "property", "match", "automation"])
		or issue._bindings.lab != lab
		or issue._bindings.property != property
		or issue._bindings.match != lab._match_state
		or issue._bindings.automation != lab._automation
	):
		_mark_completion_refused(lab)
		issue._refuse_record_completion(lab)
		return true
	if issue._bindings.automation == null:
		return false
	var record: PlayRecord = lab._active_play_record
	var records: Array[PlayRecord] = lab._play_records
	# Private primitive/captured-table integrity, then fresh existing gameplay proof.
	# No whole-park reflection, canonicalization, I/O or arbitrary outcome/phase rule.
	if (
		not issue._structure()
		or not issue.hot_intact(lab, property, 1)
		or not _native(record, "RefCounted", PlayRecord)
		or lab._active_play_record != record
		or not is_same(lab._play_records, records)
		or records.is_read_only()
		or lab._automation == null
		or lab._automation != issue._bindings.automation
	):
		_mark_completion_refused(lab)
		issue._refuse_record_completion(lab)
		return true
	# Exact PlayRecord has no custom setters; these four original writes cannot reenter.
	record.result = result
	record.runs_scored = runs_scored
	records.append(record)
	lab._active_play_record = null
	return true


static func complete_manual_record(
	lab: PitchBatLab, result: StringName, runs_scored: int = 0
) -> bool:
	if lab.ac02_startup_pending():
		return true
	# Separate from automated completion. True consumes completion OR a refusal.
	# Custom/historical fallback is allowed only after real issued ownership is proved.
	if not lab._ac02_issued_history:
		return false
	if lab.has_meta("stadium_npc_runtime_interrupted"):
		return true
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	var issue: StadiumNpcAc02IssuedStateV1 = current(lab)
	if (
		issue == null
		or property == null
		or property._ac02_issue != issue
		or property._ac02_issue_pin != issue
		or not property.has_ac02_issue()
	):
		_mark_completion_refused(lab)
		if issue != null:
			issue._refuse_record_completion(lab)
		if (
			property != null
			and property._ac02_issue_pin != null
			and property._ac02_issue_pin != issue
		):
			property._ac02_issue_pin._refuse_record_completion(lab)
		return true
	if (
		issue.state != Lifetime.ACTIVE
		or issue.generation != 1
		or property._ac02_generation != 1
		or not is_same(issue._bindings, issue._bindings_pin)
		or not issue._bindings.is_read_only()
		or not issue._bindings.has_all(["lab", "property", "match", "automation"])
		or issue._bindings.lab != lab
		or issue._bindings.property != property
		or issue._bindings.match != lab._match_state
		or issue._bindings.automation != lab._automation
	):
		_mark_completion_refused(lab)
		issue._refuse_record_completion(lab)
		return true
	if issue._bindings.automation != null:
		return false
	if not issue._structure() or not issue.hot_intact(lab, property, 1):
		_mark_completion_refused(lab)
		issue._refuse_record_completion(lab)
		return true
	var record: PlayRecord = lab._active_play_record
	var records: Array[PlayRecord] = lab._play_records
	if (
		records.is_read_only()
		or not is_same(lab._play_records, records)
		or lab._active_play_record != record
	):
		_mark_completion_refused(lab)
		issue._refuse_record_completion(lab)
		return true
	if issue._manual_qc_opted_out:
		return false
	if (
		not _native(record, "RefCounted", PlayRecord)
		or not _native(lab._record_export, "RefCounted", PlayRecordExport)
	):
		issue._manual_qc_opted_out = true
		return false
	if not issue._manual_qc_started:
		# No earlier custom record can hide in this cumulative session. Never scan it.
		if not records.is_empty():
			issue._manual_qc_opted_out = true
			return false
		issue._manual_qc_started = true
		issue._manual_qc_exporter = lab._record_export
		issue._manual_qc_records = records
	elif (
		lab._record_export != issue._manual_qc_exporter
		or not is_same(records, issue._manual_qc_records)
		or records.size() != issue._manual_qc_count
	):
		# Replacement/custom opt-out lasts for this issue, including deliberate resets.
		issue._manual_qc_opted_out = true
		return false
	# Exact native record has no custom setters: preserve the four completion writes.
	record.result = result
	record.runs_scored = runs_scored
	records.append(record)
	lab._active_play_record = null
	issue._manual_qc_count += 1
	issue._manual_qc_dirty_revision += 1
	return true


func manual_qc_pending() -> bool:
	return _manual_qc_dirty_revision > _manual_qc_saved_revision


func manual_qc_owner(lab: PitchBatLab) -> bool:
	# Fresh owner checks only. Dirty revisions and successful earlier saves are not proof.
	if (
		not is_instance_valid(lab)
		or not lab._ac02_issued_history
		or lab.has_meta("stadium_npc_runtime_interrupted")
		or current(lab) != self
		or state != Lifetime.ACTIVE
		or generation != 1
		or not is_same(_bindings, _bindings_pin)
		or not _bindings.is_read_only()
		or not _bindings.has_all(["lab", "property", "match", "automation"])
		or _bindings.lab != lab
		or _bindings.match != lab._match_state
		or _bindings.automation != null
		or lab._automation != null
	):
		return false
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	return (
		property != null
		and property == _bindings.property
		and property._ac02_issue == self
		and property._ac02_issue_pin == self
		and property._ac02_generation == 1
		and property.has_ac02_issue()
		and _structure()
		and hot_intact(lab, property, 1)
	)


func manual_qc_reset_session() -> void:
	# Called only after the captured ACTIVE manual session was deliberately cleared.
	# Do not reset custom opt-out or any lifetime/generation/authority state.
	_manual_qc_started = false
	_manual_qc_exporter = null
	_manual_qc_records = []
	_manual_qc_count = 0
	_manual_qc_dirty_revision = 0
	_manual_qc_saved_revision = 0
	_manual_qc_terminal_attempted = false
	_manual_qc_terminal_count = 0
	_manual_qc_terminal_revision = 0


static func _mark_completion_refused(lab: PitchBatLab) -> void:
	# Never overwrite/read an opaque pre-existing marker value. Supported paths do not
	# clear interruption; restoring owner/pins therefore cannot revive this old lifetime.
	if not lab.has_meta("stadium_npc_runtime_interrupted"):
		lab.set_meta("stadium_npc_runtime_interrupted", true)


func _refuse_record_completion(lab: PitchBatLab) -> void:
	# A foreign issuer borrowed from another lab is not ours to retire or clean.
	if _bindings_pin.get("lab") != lab:
		return
	revoke("issued record completion refused")
	# Only the captured old property may be paused/released. Never borrow a replacement.
	if not is_same(_bindings, _bindings_pin) or _bindings.get("lab") != lab:
		return
	var property: StadiumNpcPublicProperty = _bindings.get("property") as StadiumNpcPublicProperty
	if is_instance_valid(property):
		pause_owned(lab, property)


func created_ball(lab: PitchBatLab, candidate: BattedBallBody) -> bool:
	var property: StadiumNpcPublicProperty = _bindings.get("property") as StadiumNpcPublicProperty
	# Called at the exact BattedBallBody.new site, before assigning the new current ball.
	if (
		not continue_action(lab)
		or _ball != null
		or candidate == null
		or candidate.get_script() != BattedBallBody
		or candidate.get_class() != "RigidBody3D"
		or candidate.get_parent() != null
	):
		revoke("ball creation ownership lost")
		return false
	_ball = candidate
	_ball_state = lab._ball_play_resolver.state
	_ball_binding = true
	return property != null


func bound_ball(lab: PitchBatLab, candidate: BattedBallBody) -> bool:
	if candidate != _ball or not _ball_binding or not continue_action(lab):
		return false
	_ball_binding = false
	return true


func clear_ball(lab: PitchBatLab, candidate: Variant) -> bool:
	# Sanctioned null transition only, immediately before queue_free + current-ball null.
	var property: StadiumNpcPublicProperty = _bindings.get("property") as StadiumNpcPublicProperty
	if not owns_cleanup(lab, property) or candidate != _ball:
		revoke("ball cleanup ownership lost")
		return false
	_ball = null
	_ball_state = null
	_ball_binding = false
	return true


static func before_settlement(lab: PitchBatLab) -> bool:
	if is_instance_valid(lab) and lab.ac02_startup_pending():
		return false
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	var issue: StadiumNpcAc02IssuedStateV1 = current(lab)
	if issue == null:
		return property == null or not property.has_ac02_issue()
	if property == null or property._ac02_issue_pin != issue:
		issue.revoke("settlement owner lost")
		return false
	if (
		issue == null
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.GAME_END
		or not issue.deep_intact(lab, property)
	):
		return false
	if lab._automation != null:
		issue._settlement_report = StadiumNpcPublicReport.capture(lab)
		if issue._settlement_report.is_empty() or not issue.deep_intact(lab, property):
			return false
	# Human evidence was captured by SeasonApp; automated report17 above is unchanged.
	# Revocation does not pause, write reward state, or change the caller's report/snapshot.
	issue.revoke("settlement begins")
	return true


func restore_owned(lab: PitchBatLab, property: StadiumNpcPublicProperty, deferred: bool) -> void:
	revoke("runtime teardown")
	if _restoring or _restored or _pausing:
		return
	_restoring = true
	_restore_owned_body(lab, property, deferred)
	_restored = true
	_restoring = false


func _restore_owned_body(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, deferred: bool
) -> void:
	if not owns_cleanup(lab, property):
		cleanup_local(property)
		release_abandoned_originals()
		return
	pause_owned(lab, property)
	if not owns_cleanup(lab, property):
		cleanup_local(property)
		release_abandoned_originals()
		return
	# Capture the one permitted post-restore tuple before any borrowed owner is changed.
	var restore: Dictionary = {
		"lab": lab,
		"host": _bindings.host,
		"match": _bindings.match,
		"season": _bindings.season,
		"career": _cleanup_career,
		"actor": _bindings.actor,
		"resolver": _bindings.resolver,
		"fielder": _bindings.fielder,
		"camera": _bindings.camera,
		"release": _bindings.release,
		"cadence": _bindings.cadence,
		"ball": _ball,
		"old_field": property.old_field,
		"old_field_id": property.old_field_id,
		"old_camera": property.old_camera,
		"old_visibility": property.old_visibility,
		"old_observer": property.old_observer,
		"old_clip": property.old_clip,
		"old_obstacles": property.old_obstacles,
		"old_receiver": property.old_receiver,
		"old_mask": property.old_camera_mask
	}
	var originals: Array[Node] = _owned_originals.duplicate()
	var order: Array[Node] = _original_order.duplicate()
	property.old_nodes.clear()
	if is_instance_valid(_bindings.actor) and not _bindings.actor.receiver_router.is_valid():
		_bindings.actor.receiver_router = property.old_receiver
	if is_instance_valid(_bindings.resolver) and not _bindings.resolver.segment_observer.is_valid():
		_bindings.resolver.segment_observer = property.old_observer
	if (
		is_instance_valid(_bindings.fielder)
		and _bindings.fielder.stadium_boundary_clip == property.clip
	):
		_bindings.fielder.stadium_boundary_clip = property.old_clip
		_bindings.fielder.stadium_obstacles = property.old_obstacles
	if not owns_cleanup(lab, property):
		release_abandoned_originals()
		return
	# Plain field assignments have no user code under this contract's exact scripts.
	lab._field_id = property.old_field_id
	lab._field_definition = property.old_field
	lab._camera.cull_mask = property.old_camera_mask
	lab._camera_director = property.old_camera
	if is_instance_valid(property.old_camera):
		property.old_camera.tracking_visibility = property.old_visibility
	lab.remove_meta("stadium_property")
	lab.remove_meta("stadium_snapshot")
	lab.set_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND, true)
	lab.set_meta("stadium_npc_runtime_interrupted", true)
	lab.set_meta("stadium_npc_runtime_restoring", true)
	property.lab_ref = null
	# This deferred closure owns the exact old tuple, not whatever later occupies lab.
	if deferred or property.public_bound:
		_original_restore_pending = true
		_restore_original_nodes_kept.call_deferred(self, restore, originals, order)
	else:
		_restore_original_nodes(restore, originals, order)


static func _restore_original_nodes_kept(
	issue: StadiumNpcAc02IssuedStateV1,
	restore: Dictionary,
	originals: Array[Node],
	order: Array[Node]
) -> void:
	# An instance Callable keeps only ObjectID. The queued argument owns this exact
	# RefCounted issuer until the one deferred restore/release transaction completes.
	issue._restore_original_nodes(restore, originals, order)


static func _restore_tuple(restore: Dictionary) -> bool:
	if not is_instance_valid(restore.lab):
		return false
	var lab: PitchBatLab = restore.lab
	return (
		is_instance_valid(lab)
		and not lab.is_queued_for_deletion()
		and lab.is_inside_tree()
		and lab.get_script() == PitchBatLab
		and not lab.has_meta("stadium_property")
		and lab._match_state == restore.match
		and lab._npc_season == restore.season
		and is_instance_valid(lab._npc_season)
		and lab._npc_season.career == restore.career
		and lab._automation == null
		and lab._batted_ball == restore.ball
		and lab._pitch_actor == restore.actor
		and lab._ball_play_resolver == restore.resolver
		and lab._primary_fielder == restore.fielder
		and lab._camera == restore.camera
		and lab._camera_director == restore.old_camera
		and lab._field_definition == restore.old_field
		and lab._field_id == restore.old_field_id
		and lab._release_controller == restore.release
		and lab._at_bat_cadence == restore.cadence
		and is_instance_valid(restore.host)
		and not restore.host.is_queued_for_deletion()
		and lab.get_node_or_null("StarterFieldGeometry") == restore.host
	)


func _restore_original_nodes(
	restore: Dictionary, originals: Array[Node], order: Array[Node]
) -> void:
	_original_restore_pending = false
	# Never feed a stale deferred cleanup through the historical replacement-blind tail.
	if not _restore_tuple(restore):
		release_abandoned_originals()
		return
	for node: Node in originals:
		if not _restore_tuple(restore):
			release_abandoned_originals()
			return
		if is_instance_valid(node) and node.get_parent() == null:
			restore.host.add_child(node)
	for index in range(order.size()):
		if not _restore_tuple(restore):
			release_abandoned_originals()
			return
		if is_instance_valid(order[index]) and order[index].get_parent() == restore.host:
			restore.host.move_child(order[index], mini(index, restore.host.get_child_count() - 1))
	if _restore_tuple(restore):
		restore.lab.remove_meta("stadium_npc_runtime_restoring")


func release_abandoned_originals() -> void:
	# Detached original Nodes remain this lifetime's resources. Never touch an
	# adopted/reparented node, and never compete with the pending deferred restore.
	if (
		_original_restore_pending
		or _releasing_originals
		or not is_same(_owned_originals, _owned_originals_pin)
		or not _owned_originals.is_read_only()
	):
		return
	_releasing_originals = true
	for node: Node in _owned_originals:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	_releasing_originals = false


static func _native_capture_eligible(property: StadiumNpcPublicProperty) -> bool:
	# Piggyback the historical capture's already-built node/resource lists. No second
	# geometry traversal, resource property reflection, or callback-graph classifier.
	if (
		property._nodes.is_empty()
		or property._nodes.size() > 8192
		or property._resources.size() > 16384
	):
		return false
	for row: Dictionary in property._nodes:
		var node: Node = row.get("node") as Node
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			return false
		if node.get_script() == null:
			if node.get_class() not in NATIVE_NODE_CLASSES:
				return false
		elif (
			node
			not in [
				property,
				property.construction,
				property.boundary,
				property.receiver,
				property.boundary.source,
				property.display
			]
		):
			return false
	for resource: Resource in property._resources:
		if not is_instance_valid(resource):
			return false
		if resource == property.field:
			if resource.get_script() != FieldDefinition or resource.get_class() != "Resource":
				return false
		elif resource.get_script() != null or resource.get_class() not in NATIVE_RESOURCE_CLASSES:
			return false
	return true

extends RefCounted
enum State { PREPARING, VALIDATING, COMMITTED, ABORTED }

## Preload-only, one-use manual cold-start continuation. Never a public authority.
const CONTRACT: String = "ac02-native-manual-startup-preparing-v2"
const INPUT_ROOTS: Array[String] = [
	"stadium",
	"npc_venues",
	"schedule",
	"semifinals",
	"final_fixture",
	"final_venue",
	"pending",
	"selected"
]
var state: State = State.PREPARING
var reason: String = ""
var executing: bool = false
var setup_complete: bool = false
var app: SeasonApp
var lab: PitchBatLab
var property: StadiumNpcPublicProperty
var match_state: MatchState
var season: SeasonState
var career: ClubCareer
var fixture: Dictionary = {}
var snapshot: Dictionary = {}
var player_home: bool
var issue: StadiumNpcAc02IssuedStateV1
var originals: Array[Node] = []
var wall_viewport: WeakRef
var _enrolled: bool = false
var _witness: Dictionary = {}
var _witness_pin: Dictionary = {}
var _sources: Dictionary = {}
var _sources_pin: Dictionary = {}
var _snapshot_pin: Dictionary = {}


func enroll(owner: SeasonApp, candidate: PitchBatLab) -> bool:
	# Ineligible input has no enrollment side effect and retains literal old dispatch.
	if (
		app != null
		or _enrolled
		or state != State.PREPARING
		or not _enrollment_owners(owner, candidate)
	):
		return false
	var source_match: MatchState = candidate._configured_match
	var source_season: SeasonState = owner.season
	var source_career: ClubCareer = source_season.career
	# pending_fixture and fixture_for_id dereference row fields. Refuse unknown shapes
	# before either lookup, then bound/copy the complete primitive roots before normalization.
	if (
		not _fixture_rows(source_season.schedule)
		or not _fixture_rows(source_season.semifinals)
		or (
			not source_season.final_fixture.is_empty()
			and not _fixture_row(source_season.final_fixture)
		)
	):
		return false
	var pending: Dictionary = source_season.pending_fixture()
	if pending.is_empty():
		return false
	var selected: Dictionary = _selected_source(source_season, pending.id)
	if selected.is_empty():
		return false
	return _enroll_remaining_checks(
		owner, candidate, source_match, source_season, source_career, pending, selected
	)


func _enroll_remaining_checks(
	owner: SeasonApp,
	candidate: PitchBatLab,
	source_match: MatchState,
	source_season: SeasonState,
	source_career: ClubCareer,
	pending: Dictionary,
	selected: Dictionary
) -> bool:
	var raw: Dictionary = source_match.stadium
	var sources: Dictionary = {
		"app": owner,
		"lab": candidate,
		"match": source_match,
		"season": source_season,
		"career": source_career,
		"stadium": raw,
		"npc_venues": source_season.npc_venues,
		"schedule": source_season.schedule,
		"semifinals": source_season.semifinals,
		"final_fixture": source_season.final_fixture,
		"final_venue": source_season.final_venue,
		"pending": pending,
		"selected": selected
	}
	var inputs: Dictionary = {
		"season_seed": source_season.season_seed,
		"phase": source_season.phase,
		"round_index": source_season.round_index,
		"run": source_career.current if source_career != null else source_season._npc_replay_run
	}
	for key: String in INPUT_ROOTS:
		inputs[key] = sources[key]
	var budget: Array[int] = [
		StadiumNpcAc02IssuedStateV1.MAX_ENTRIES, StadiumNpcAc02IssuedStateV1.MAX_STRING_BYTES
	]
	var frozen: Variant = StadiumNpcAc02IssuedStateV1._copy_canonical(inputs, budget)
	if budget[0] < 0 or budget[1] < 0 or not frozen is Dictionary:
		return false
	var canonical: Dictionary = StadiumNpcSnapshot.normalized(raw)
	if (
		canonical.is_empty()
		or canonical.manifest.id != "AC-02"
		or canonical.version != StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION
		or not StadiumNpcSnapshot.matches_fixture(raw, source_season, frozen.pending)
		or not StadiumNpcAc02IssuedQualificationV1.eligible()
		or not StadiumNpcPublicRuntime.source_qualified()
		or not _tree_edges(owner, owner)
		or not _tree_edges(candidate)
		or not owner.get_tree().node_added.get_connections().is_empty()
		or not owner.get_tree().node_removed.get_connections().is_empty()
	):
		return false
	var canonical_budget: Array[int] = [
		StadiumNpcAc02IssuedStateV1.MAX_ENTRIES, StadiumNpcAc02IssuedStateV1.MAX_STRING_BYTES
	]
	var frozen_canonical: Variant = StadiumNpcAc02IssuedStateV1._copy_canonical(
		canonical, canonical_budget
	)
	if canonical_budget[0] < 0 or canonical_budget[1] < 0 or not frozen_canonical is Dictionary:
		return false
	# Recheck the captured sources after the initial full relation, before enrollment.
	if (
		not _enrollment_owners(owner, candidate)
		or candidate._configured_match != source_match
		or owner.season != source_season
		or not _inputs_match(source_match, source_season, sources, frozen)
	):
		return false
	sources.make_read_only()
	app = owner
	lab = candidate
	match_state = source_match
	season = source_season
	career = source_career
	fixture = frozen.pending
	snapshot = frozen_canonical
	_snapshot_pin = snapshot
	player_home = lab._player_home
	_witness = frozen
	_witness_pin = _witness
	_sources = sources
	_sources_pin = _sources
	lab._ac02_startup_enrolled = true
	lab._ac02_startup_attempt = self
	_enrolled = true
	return true


func committed() -> bool:
	return state == State.COMMITTED


func context() -> bool:
	if not _enrolled or state not in [State.PREPARING, State.VALIDATING]:
		return false
	# Exact scripts precede all scripted fields. Pins preserve the finite expected tree
	# and the original identity table; no live caller container is ever frozen.
	if (
		not is_same(_witness, _witness_pin)
		or not _witness.is_read_only()
		or _witness.size() != 12
		or not is_same(_sources, _sources_pin)
		or not _sources.is_read_only()
		or _sources.size() != 13
		or not is_same(snapshot, _snapshot_pin)
		or not snapshot.is_read_only()
		or not is_instance_valid(app)
		or app.get_script() != SeasonApp
		or not is_instance_valid(lab)
		or lab.get_script() != PitchBatLab
		or not is_instance_valid(match_state)
		or match_state.get_script() != MatchState
		or not is_instance_valid(season)
		or season.get_script() != SeasonState
		or (career != null and (not is_instance_valid(career) or career.get_script() != ClubCareer))
	):
		abort("startup context changed")
		return false
	var current: bool = (
		app == _sources.app
		and lab == _sources.lab
		and match_state == _sources.match
		and season == _sources.season
		and career == _sources.career
		and is_same(fixture, _witness.pending)
		and app.lab == lab
		and lab._ac02_startup_attempt == self
		and lab._ac02_startup_enrolled
		and not lab._ac02_startup_committed
		and not lab.is_queued_for_deletion()
		and (lab.get_parent() == null or lab.get_parent() == app)
		and app.season == season
		and lab._npc_season == season
		and season.career == career
		and app._season_game
		and app._fixture_id == fixture.get("id")
		and lab._managed_match
		and lab._player_home == player_home
		and lab._automation == null
		and (lab._configured_match == match_state or lab._match_state == match_state)
		and lab._batted_ball == null
		and lab._active_play_record == null
		and lab._play_records.is_empty()
		and lab._throw_number == 0
		and not lab._swing_consumed
		and not lab.has_meta("stadium_npc_runtime_interrupted")
		and _inputs_match(match_state, season, _sources, _witness)
	)
	if not current:
		# Some native guard callers discard false. Observation itself must retire the attempt.
		abort("startup context changed")
	return current


static func _enrollment_owners(owner: SeasonApp, candidate: PitchBatLab) -> bool:
	if (
		not is_instance_valid(owner)
		or owner.get_script() != SeasonApp
		or not is_instance_valid(candidate)
		or candidate.get_script() != PitchBatLab
	):
		return false
	return (
		candidate.get_parent() == null
		and owner.lab == candidate
		and owner._season_game
		and candidate._automation == null
		and candidate._managed_match
		and candidate._match_state == null
		and is_instance_valid(owner.season)
		and owner.season.get_script() == SeasonState
		and is_instance_valid(candidate._configured_match)
		and candidate._configured_match.get_script() == MatchState
		and candidate._npc_season == owner.season
		and (
			owner.season.career == null
			or (
				is_instance_valid(owner.season.career)
				and owner.season.career.get_script() == ClubCareer
			)
		)
		and candidate._stadium_ledger == null
		and not candidate._ac02_startup_enrolled
	)


static func _fixture_rows(rows: Array[Dictionary]) -> bool:
	if rows.size() > StadiumNpcAc02IssuedStateV1.MAX_ENTRIES:
		return false
	for row: Dictionary in rows:
		if not _fixture_row(row):
			return false
	return true


static func _fixture_row(row: Dictionary) -> bool:
	for key: String in ["id", "round", "home", "away"]:
		if typeof(row.get(key)) != TYPE_INT:
			return false
	return (
		row.id >= 0
		and row.id <= 32
		and (not row.has("neutral") or typeof(row.neutral) == TYPE_BOOL)
	)


static func _selected_source(current_season: SeasonState, id: int) -> Dictionary:
	# The original lookup returns a copy. Retain its actual first-match row as well.
	if id < 30:
		for row: Dictionary in current_season.schedule:
			if row.id == id:
				return row
	elif id < 32:
		for row: Dictionary in current_season.semifinals:
			if row.id == id:
				return row
	elif current_season.final_fixture.get("id", -1) == id:
		return current_season.final_fixture
	return {}


static func _inputs_match(
	current_match: MatchState, current_season: SeasonState, sources: Dictionary, witness: Dictionary
) -> bool:
	# Pure continuity predicate. Call lookups only after the complete input tree matches.
	if (
		not is_instance_valid(current_match)
		or current_match.get_script() != MatchState
		or not is_instance_valid(current_season)
		or current_season.get_script() != SeasonState
	):
		return false
	var current_career: ClubCareer = current_season.career
	if (
		current_match != sources.match
		or current_season != sources.season
		or current_career != sources.career
		or (
			current_career != null
			and (not is_instance_valid(current_career) or current_career.get_script() != ClubCareer)
		)
	):
		return false
	if (
		not is_same(current_match.stadium, sources.stadium)
		or not is_same(current_season.npc_venues, sources.npc_venues)
		or not is_same(current_season.schedule, sources.schedule)
		or not is_same(current_season.semifinals, sources.semifinals)
		or not is_same(current_season.final_fixture, sources.final_fixture)
		or not is_same(current_season.final_venue, sources.final_venue)
		or not _same_input(current_season.season_seed, witness.season_seed)
		or not _same_input(current_season.phase, witness.phase)
		or not _same_input(current_season.round_index, witness.round_index)
		or not _same_input(
			current_career.current if current_career != null else current_season._npc_replay_run,
			witness.run
		)
	):
		return false
	for key: String in INPUT_ROOTS:
		if not _same_input(sources[key], witness[key]):
			return false
	return (
		is_same(current_season.pending_fixture(), sources.pending)
		and is_same(_selected_source(current_season, witness.pending.id), sources.selected)
	)


static func _same_input(actual: Variant, expected: Variant) -> bool:
	# Expected is the detached, deeply readonly finite copier result. Recurse only
	# through its shape, never through a newly introduced object/cycle/opaque branch.
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		if not expected.is_read_only() or actual.size() != expected.size():
			return false
		for key: Variant in actual:
			if typeof(key) != TYPE_STRING:
				return false
		for key: String in expected:
			if not actual.has(key) or not _same_input(actual[key], expected[key]):
				return false
		return true
	if expected is Array:
		if not expected.is_read_only() or actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_input(actual[index], expected[index]):
				return false
		return true
	if typeof(expected) == TYPE_FLOAT:
		return is_finite(actual) and actual == expected
	match typeof(expected):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return actual == expected
	return false


func owns(value: StadiumNpcPublicProperty) -> bool:
	return (
		context()
		and is_instance_valid(property)
		and value == property
		and property._ac02_startup_attempt == self
		and property.get_script() == StadiumNpcPublicProperty
		and not property.suspended
		and not property._cleaning
	)


func setup_owners(value: StadiumNpcPublicProperty) -> bool:
	return (
		state == State.PREPARING
		and owns(value)
		and StadiumNpcAc02SetupAdmission.no_live_owners(lab, property)
		and not lab._pitch_actor.running
		and not lab._release_controller.active
		and lab._at_bat_cadence.state == AtBatCadenceController.State.IDLE
	)


func install() -> bool:
	if executing or setup_complete or property != null or not context():
		abort("startup reentered or context changed")
		return false
	executing = true
	property = StadiumNpcPublicRuntime._stage_startup(self)
	if property != null:
		property._ac02_startup_attempt = self
		property._ac02_startup_enrolled = true
	var ok: bool = property != null and StadiumNpcPublicRuntime._commit_startup(self, property)
	executing = false
	if not ok:
		abort("startup staging refused")
	return ok


func markers() -> bool:
	if not setup_owners(property):
		abort("marker setup owner lost")
		return false
	if (
		not PitchBatLabPresentation._refresh_markers_prefix(lab)
		or not property._ac02_startup_receiver(self)
	):
		abort("marker setup refused")
		return false
	PitchBatLabPresentation._refresh_markers_suffix(lab)
	return setup_owners(property)


func finish_setup() -> bool:
	if executing or setup_complete or not setup_owners(property):
		abort("startup presentation reentered")
		return false
	executing = true
	SeasonOpponentChoices.prepare(lab)
	if not setup_owners(property):
		abort("opponent setup owner lost")
		return false
	lab._camera_mode = 0 if lab._player_is_batting() else 1
	lab._camera_director.set_shot(
		(
			MatchCameraDirector.Shot.BATTING
			if lab._camera_mode == 0
			else MatchCameraDirector.Shot.PITCHING
		)
	)
	if not property._ac02_startup_receiver(self):
		abort("role camera owner lost")
		return false
	return _finish_setup_remaining_checks()


func _finish_setup_remaining_checks() -> bool:
	lab._status_label.text = (
		"TOP 1 • %s\nGame presentation starting"
		% ("Player batting" if lab._player_is_batting() else "Player pitching")
	)
	lab._live_label.text = ""
	if not markers():
		return false
	lab._refresh_config()
	if not setup_owners(property):
		abort("configuration owner lost")
		return false
	# Actual manual intro body, with only the nested camera guard bridged.
	if lab._match_presentation_director == null:
		lab._match_presentation_director = MatchPresentationDirector.new()
	lab._at_bat_cadence.stop()
	lab._status_label.text = ""
	PitchBatLabPresentation.refresh_event(lab)
	lab._match_presentation_director.begin_intro(int(Time.get_ticks_usec() & 0x7fffffff))
	lab._camera_director.set_shot(lab._match_presentation_director.current_shot())
	PitchBatLabFeelSupport._sync_presentation_camera(lab)
	if not lab._camera_director._snap_startup(self, lab._camera):
		abort("intro camera owner lost")
		return false
	PitchBatLabPresentation.show_match_intro(lab)
	executing = false
	return setup_owners(property)


func ready_complete() -> void:
	# Called after the original _ready tail's marker/config writes, synchronously.
	if not setup_owners(property) or executing or setup_complete:
		abort("ready tail owner lost")
		return
	setup_complete = true


func validate_and_publish() -> bool:
	if (
		executing
		or not setup_complete
		or not setup_owners(property)
		or lab.get_parent() != app
		or lab._match_state != match_state
	):
		abort("final startup context refused")
		return false
	executing = true
	if not preflight(property):
		abort("final native preflight refused")
		return false
	property._ac02_startup_capture()
	issue = StadiumNpcAc02IssuedStateV1.new()
	if not context() or not issue._prepare(lab, property):
		abort("canonical preparation refused")
		return false
	# Bind candidate receipt while pending-first dispatch still denies all public access.
	property._ac02_issue = issue
	property._ac02_issue_pin = issue
	property._ac02_generation = 1
	property._ac02_issued_once = true
	lab._ac02_issued_owner = issue
	lab._ac02_issued_history = true
	property.receiver.mark_issued(property)
	property.ac02_guides.mark_issued()
	property.issued = true  # Historical captures are published only behind pending denial.
	state = State.VALIDATING
	# Full unchanged installed body owns the only fresh expected park/comparison.
	if (
		not StadiumNpcPublicRuntime._ac02_passive_01_installed(lab)
		or not context()
		or not issue._owners(lab, property)
		or not issue._context(lab, property)
		or not issue._structure()
		or not issue._canonical_matches(lab, property)
		or not property.ordinary_callbacks()
		or not StadiumNpcPublicRuntime._ac02_passive_01_callback_bound(lab, property)
		or not issue._owners(lab, property)
		or not issue._context(lab, property)
		or not context()
		or state != State.VALIDATING
		or issue.state != StadiumNpcAc02IssuedStateV1.Lifetime.PREPARING
	):
		abort("final actual proof refused")
		return false
	# Publication tail: assignments only. No calls, wiring, allocation, or setter effects.
	property.issued = true
	property._ac02_startup_committed = true
	lab._ac02_startup_committed = true
	executing = false
	state = State.COMMITTED
	issue.state = StadiumNpcAc02IssuedStateV1.Lifetime.ACTIVE
	return true


func abort(why: String) -> void:
	if state == State.COMMITTED or state == State.ABORTED:
		return
	state = State.ABORTED
	reason = why
	# Denial precedes all cleanup. No current replacement field/routes are restored.
	if is_instance_valid(property) and property._ac02_startup_attempt == self:
		property.suspended = true
		property.issued = false
	if issue != null:
		issue.revoke(why)


func dispose() -> void:
	abort("startup discarded")
	if state != State.ABORTED:
		return
	var lab_owned: bool = (
		is_instance_valid(lab)
		and (lab.get_parent() == null or (is_instance_valid(app) and lab.get_parent() == app))
	)
	if wall_viewport != null and is_instance_valid(property):
		StadiumWallRenderQuality._release(wall_viewport, property.get_instance_id())
		wall_viewport = null
	for node: Node in originals:
		if is_instance_valid(node) and node.get_parent() == null:
			node.queue_free()
	if (
		is_instance_valid(property)
		and (property.get_parent() == null or (lab_owned and lab.is_ancestor_of(property)))
	):
		if is_instance_valid(property.ac02_guides):
			property.ac02_guides.cleanup_local()
		if is_instance_valid(property.receiver):
			property.receiver.cleanup_issued_local()
		# A foreign adopter is never detached, freed or restored by this attempt.
		if property.get_parent() == null:
			property.queue_free()
	if lab_owned:
		# Captured original identity survives token loss; never select a replacement.
		if is_instance_valid(app) and app.lab == lab:
			app.lab = null
		lab.queue_free()


static func _tree_edges(node: Node, app_owner: SeasonApp = null) -> bool:
	for signal_name: StringName in [
		&"tree_entered",
		&"tree_exiting",
		&"tree_exited",
		&"child_entered_tree",
		&"child_exiting_tree",
		&"child_order_changed",
		&"ready"
	]:
		for edge: Dictionary in node.get_signal_connection_list(signal_name):
			if not _app_canvas_edge(node, app_owner, signal_name, edge):
				return false
	return true


static func _app_canvas_edge(
	node: Node, app_owner: SeasonApp, signal_name: StringName, edge: Dictionary
) -> bool:
	# Exact observed native app/root-viewport canvas ordering contract only.
	# Every other emitter/edge retains refusal; detached lab admission is unchanged.
	if (
		app_owner == null
		or node != app_owner
		or app_owner.get_script() != SeasonApp
		or not app_owner.is_inside_tree()
		or signal_name != &"child_order_changed"
		or int(edge.flags) != CONNECT_REFERENCE_COUNTED
	):
		return false
	var root: Window = app_owner.get_tree().root
	var callback: Callable = edge.callable
	if (
		app_owner.get_parent() != root
		or app_owner.get_viewport() != root
		or root.get_class() != "Window"
		or root.get_script() != null
		or callback.get_object() != root
		or not callback.is_valid()
		or not callback.is_custom()
		or callback.get_method() != &"Viewport::canvas_parent_mark_dirty"
		or callback.get_unbound_arguments_count() != 0
	):
		return false
	var arguments: Array = callback.get_bound_arguments()
	return arguments.size() == 1 and is_same(arguments[0], app_owner)


func preflight(root: StadiumNpcPublicProperty) -> bool:
	# Bounded native identity/edge check only: no expected park, profiles or byte comparison.
	# A scripted resource is rejected before get_property_list/get/lazy mesh queries.
	if not owns(root) or not StadiumNpcAc02SetupAdmission._root_support(root):
		return false
	var admission: StadiumNpcAc02SetupAdmission = StadiumNpcAc02SetupAdmission.new()
	admission.add_root(root)
	if not admission.closed:
		return false
	return _preflight_scene_nodes(root, admission)


func _preflight_scene_nodes(
	root: StadiumNpcPublicProperty,
	admission: StadiumNpcAc02SetupAdmission
) -> bool:
	var seen: Dictionary = {}
	for node: Node in [root] + root.find_children("*", "", true, false):
		if not _preflight_node(node, admission, seen):
			return false
	var host: Node = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or host.get_script() != StarterFieldLabGeometry:
		return false
	for name: String in StadiumNpcAc02PublicGuides.NAMES + ["PitchTarget"]:
		var node: MeshInstance3D = host.get_node_or_null(NodePath(name)) as MeshInstance3D
		if (
			node == null
			or node.get_script() != null
			or node.get_class() != "MeshInstance3D"
			or node.get_child_count() != 0
			or not _emitter_edges(node)
			or not _resource_preflight(node.mesh, seen)
			or not _resource_preflight(node.material_override, seen)
			or node.material_overlay != null
		):
			return false
	return context()






func _preflight_node(node: Node, admission: StadiumNpcAc02SetupAdmission, seen: Dictionary) -> bool:
	if not admission._node_slot(node) or not _emitter_edges(node):
		return false
	if not _preflight_mesh_resources(node, seen):
		return false
	if node is Label3D:
		# Same exact stored slots reached by the retained final Label3D traversal.
		# Node class/script admission above precedes reflection; no value comparison.
		for row: Dictionary in node.get_property_list():
			var key: String = row.name
			if (
				int(row.usage) & PROPERTY_USAGE_STORAGE == 0
				or StadiumNpcRetainedGeometry.SKIP_PROPERTIES.has(key)
				or key.begins_with("metadata/")
			):
				continue
			if not _resource_value(node.get(key), seen, 0):
				return false
	if node is CollisionShape3D and not _resource_preflight(node.shape, seen):
		return false
	if node is StaticBody3D and not _resource_preflight(node.physics_material_override, seen):
		return false
	return true


func _preflight_mesh_resources(node: Node, seen: Dictionary) -> bool:
	if node is GeometryInstance3D:
		for resource: Resource in [node.material_override, node.material_overlay]:
			if not _resource_preflight(resource, seen):
				return false
	if node is MeshInstance3D:
		if not _resource_preflight(node.mesh, seen):
			return false
		if node.mesh != null:
			for index in range(node.mesh.get_surface_count()):
				if not _resource_preflight(node.get_surface_override_material(index), seen):
					return false
	return true


func _emitter_edges(node: Node) -> bool:
	# Geometry writes can emit these exact native signals. Gameplay signals are not
	# traversed here; original ordinary_callbacks checks their actual three edges.
	for name: StringName in [
		&"tree_entered",
		&"tree_exiting",
		&"tree_exited",
		&"child_entered_tree",
		&"child_exiting_tree",
		&"child_order_changed",
		&"script_changed",
		&"property_list_changed",
		&"visibility_changed"
	]:
		if not node.has_signal(name):
			continue
		for edge: Dictionary in node.get_signal_connection_list(name):
			var callback: Callable = edge.callable
			if (
				callback == property._installation_changed
				and int(edge.flags) == 0
				and name in [&"tree_exiting", &"child_order_changed", &"script_changed"]
			):
				continue
			if (
				node == property
				and name == &"tree_exiting"
				and int(edge.flags) == CONNECT_ONE_SHOT
				and callback.get_object() == StadiumWallRenderQuality
				and callback.get_method() == &"_release"
			):
				var args: Array = callback.get_bound_arguments()
				if (
					args.size() == 2
					and args[0] is WeakRef
					and args[0].get_script() == null
					and args[0].get_ref() == property.get_viewport()
					and args[1] == property.get_instance_id()
				):
					continue
			return false
	return true


func _resource_preflight(value: Resource, seen: Dictionary, depth: int = 0) -> bool:
	if value == null:
		return true
	if (
		depth > 24
		or seen.size() > 16384
		or value.get_script() != null
		or value.get_class() not in StadiumNpcAc02IssuedStateV1.NATIVE_RESOURCE_CLASSES
	):
		return false
	if seen.has(value):
		return true
	return _preflight_resource_links(value, seen, depth)


func _preflight_resource_links(value: Resource, seen: Dictionary, depth: int) -> bool:
	seen[value] = true
	for name: StringName in [&"changed", &"property_list_changed"]:
		for edge: Dictionary in value.get_signal_connection_list(name):
			var callback: Callable = edge.callable
			if (
				name == &"changed"
				and callback == property._installation_changed
				and int(edge.flags) == 0
			):
				continue
			if _guide_edge(value, name, callback, int(edge.flags)):
				continue
			var owner: Object = callback.get_object()
			if (
				not is_instance_valid(owner)
				or not owner is Node
				or owner.get_script() != null
				or not callback.is_custom()
				or int(edge.flags) != 0
				or not callback.get_bound_arguments().is_empty()
				or callback.get_unbound_arguments_count() != 0
				or not _native_leaf(owner as Node)
				or not _emitter_edges(owner as Node)
			):
				return false
			if owner is GeometryInstance3D:
				if not (
					(
						owner is MeshInstance3D
						and name == &"changed"
						and callback.get_method() == &"MeshInstance3D::_mesh_changed"
						and owner.mesh == value
					)
					or (
						name == &"property_list_changed"
						and callback.get_method() == &"Object::notify_property_list_changed"
						and _material_slot(owner, value)
					)
				):
					return false
			elif owner is CollisionShape3D:
				if (
					name != &"changed"
					or owner.shape != value
					or (
						callback.get_method()
						not in [&"Node3D::update_gizmos", &"CollisionShape3D::_shape_changed"]
					)
				):
					return false
			else:
				return false
	# Realize only exact native meshes before capture retirement is connected. No compare.
	if value is Mesh:
		value.get_aabb()
		for index in range(value.get_surface_count()):
			value.surface_get_arrays(index)
			if not _resource_preflight(value.surface_get_material(index), seen, depth + 1):
				return false
	return _preflight_resource_properties(value, seen, depth)


func _preflight_resource_properties(
	value: Resource,
	seen: Dictionary,
	depth: int
) -> bool:
	for row: Dictionary in value.get_property_list():
		var key: String = row.name
		if (
			int(row.usage) & PROPERTY_USAGE_STORAGE == 0
			or StadiumNpcRetainedGeometry.SKIP_PROPERTIES.has(key)
			or key.begins_with("metadata/")
		):
			continue
		if not _resource_value(value.get(key), seen, depth + 1):
			return false
	return (
		state == State.PREPARING
		and is_instance_valid(lab)
		and lab._ac02_startup_attempt == self
		and is_instance_valid(app)
		and app.lab == lab
	)


func _resource_value(value: Variant, seen: Dictionary, depth: int) -> bool:
	if depth > 24:
		return false
	if value is Resource:
		return _resource_preflight(value, seen, depth)
	if value is Object or value is Callable or value is Signal or value is RID:
		return false
	if value is Array:
		for item: Variant in value:
			if not _resource_value(item, seen, depth + 1):
				return false
	elif value is Dictionary:
		for key: Variant in value:
			if (
				not StadiumNpcAc02SetupAdmission.plain_data(key)
				or not _resource_value(value[key], seen, depth + 1)
			):
				return false
	return true


func _guide_edge(resource: Resource, name: StringName, callback: Callable, flags: int) -> bool:
	if name != &"changed" or flags != 0 or not is_instance_valid(property.ac02_guides):
		return false
	var guides: StadiumNpcAc02PublicGuides = property.ac02_guides
	for index in range(guides._guides.size()):
		var row: Dictionary = guides._guides[index]
		if (
			(resource == row.mesh and callback == guides._resource_changed.bind(index, false))
			or (resource == row.material and callback == guides._resource_changed.bind(index, true))
		):
			return true
	return false


func _native_leaf(node: Node) -> bool:
	if node.get_child_count() != 0:
		return false
	if property.is_ancestor_of(node):
		return true
	var host: Node = lab.get_node_or_null("StarterFieldGeometry")
	return (
		host != null
		and node.get_parent() == host
		and String(node.name) in StadiumNpcAc02PublicGuides.NAMES + ["PitchTarget"]
	)


func _material_slot(node: GeometryInstance3D, value: Resource) -> bool:
	if node.material_override == value or node.material_overlay == value:
		return true
	if node is MeshInstance3D:
		# Native node slot count, not a reflected or lazy query on an unadmitted mesh.
		for index in range(node.get_surface_override_material_count()):
			if node.get_surface_override_material(index) == value:
				return true
	return false

extends Node3D
## Split cold installed checks on the exact Expanded neutral pool recipe.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const F = preload("res://src/tests/pool_party_public_fixture.gd")
var _checks: int = 0
var _failures: int = 0
var _case: String = "lifecycle-away"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-party-runtime-case="):
			_case = argument.trim_prefix("--pool-party-runtime-case=")
	_run.call_deferred()


func _run() -> void:
	_check(_case in ["lifecycle-away", "lifecycle-home", "pool-shape", "pool-meta",
		"timber-shape", "pool-body-owner", "pool-body-list"],
		"one exact split cold case selected")
	_check(R.source_qualified() and F.ready(), "composed sources and neutral fixture current")
	var original: SeasonState = F.season()
	var before: Dictionary = SeasonSave.snapshot(original) if original != null else {}
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(
		JSON.stringify(before, "", true, true)))
	_check(season != null, "full precision save66 restores final5 snapshot24")
	if season == null or _failures > 0:
		_finish()
		return
	var home: bool = _case == "lifecycle-home"
	var fixture: Dictionary = F.fixture(season, home)
	before = SeasonSave.snapshot(season)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = SeasonPhysicalFixtures.match_for(season, fixture)
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	lab._player_home = home
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var property: StadiumNpcPublicProperty = R._property(lab)
	_check(not lab.yard_bound_startup_failed and property != null and property.issued,
		"genuine startup issued the saved Pool Party owner")
	if property == null or lab.yard_bound_startup_failed:
		lab.free()
		_finish()
		return
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._at_bat_cadence.stop()
	var pool: Node3D = property.objects[StadiumPoolPartyRuntime.COPY]
	if _case.begins_with("lifecycle-"):
		_origin_probes(lab, property, pool)
	_check(property.venue_id == "POOL-PARTY" and property.tier == "expanded"
		and property.objects.size() == 65 and lab._stadium_ledger == null
		and typeof(property.field.id) == TYPE_STRING_NAME,
		"exact65 Expanded neutral copies and typed field without paid stock")
	_check(lab._match_state.stadium.version == 24 and lab._match_state.stadium.environment.version == 6
		and lab._match_state.stadium.environment.time == "13:10"
		and lab._match_state.stadium.environment.weather == "clear",
		"saved daytime clear environment exact")
	_check(property.boundary.graph.get_script() == StadiumTimberDugoutBoundary
		and property.presentation_director.get_script() == StadiumPoolPartyPublicCamera
		and property.presentation_director.tracking_visibility._groups.size() == 8,
		"timber graph and exact eight visibility groups installed")
	_check(not pool.has_meta("owned_copy") and not pool.has_meta("npc_instance")
		and pool.transform == StadiumPoolContract.placement()
		and StadiumPoolPartyPublicConstruction._pool_intact(pool),
		"original Pool model remains immutable and externally neutral-owned")
	var pool_routes: Array[Dictionary] = property.route_obstacles().filter(
		func(row: Dictionary) -> bool:
		return row.copy == StadiumPoolPartyRuntime.COPY)
	_check(pool_routes.size() == 1 and pool_routes[0].center == Vector3(12, 0, 18)
		and is_equal_approx(pool_routes[0].radius, 2.82),
		"complete2.5 envelope plus actual0.32 actor clearance uses ordinary routes")
	_check(not StadiumDefenderRoutes.clear(Vector3(8, 0, 18), Vector3(16, 0, 18), pool_routes)
		and StadiumDefenderRoutes.clear(Vector3(8, 0, 14), Vector3(16, 0, 14), pool_routes),
		"through-pool route refused while genuine adjacent route remains open")
	_check(property.receiver.get_script() == StadiumPoolPartyPublicReceiver
		and property.receiver.net.get_meta("stadium_item") == "ST-025"
		and property.receiver.chair.get_meta("stadium_item") == "ST-026",
		"original target/portable-net pair preserved")
	_check(StadiumPoolPartyEnvironmentV1.installed(lab, property.environment_lease)
		and lab.find_children("*", "SpotLight3D", true, false).is_empty(),
		"exact 13:10 lease with no night lighting")
	for row: Dictionary in lab._match_state.stadium.manifest.instances:
		var model: Node3D = property.objects[row.instance]
		_check(ClubCareer.same(StadiumPoolPartyPublicConstruction.components(model.transform),
			Array(PackedFloat32Array(row.transform))), "exact parsed/native transform " + row.site)
	_check(R.installed(lab) and property.callback_intact(), "full cold and issued checks agree")
	if _case == "pool-shape":
		var shape: CollisionShape3D = pool.get_node("Collision/POOL_LADDER/Shape")
		shape.shape.margin = 0.02
	elif _case == "pool-meta":
		pool.set_meta("water_award_active", true)
	elif _case == "timber-shape":
		var timber: Node3D = property.objects["npc:POOL-PARTY:r1:DUGOUT-L"]
		var shape: CollisionShape3D = timber.get_node("Collision/FrontBarrier-1/Shape")
		shape.shape.margin = 0.02
	elif _case == "pool-body-owner":
		property.boundary.pool_model = null
	elif _case == "pool-body-list":
		property.boundary.pool_bodies.clear()
	if not _case.begins_with("lifecycle"):
		_check(not R.installed(lab) and not property.callback_intact(),
			"cold and issued audits reject exact model/shape/reference mutation")
		property.retire_installation("explicit integrity mutation probe")
		_check(property.suspended and not property.issued and not property.callback_intact(),
			"revoked authority cannot silently resume")
	_check(ClubCareer.same(before, SeasonSave.snapshot(season)) and lab._play_records.is_empty()
		and PhysicalMatchReport.capture(lab).is_empty(), "probe does not fabricate a game or settlement")
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	var lease: Dictionary = property.environment_lease
	var prior: Dictionary = lease.duplicate(false)
	var world: WorldEnvironment = lab._world_environment
	_check(R.teardown(lab), "idle teardown accepts owned lease")
	_check(lease.is_empty() and world.environment == prior.before_environment,
		"teardown restores same-origin environment and clears lease")
	lab.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	_finish()


func _check(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error("POOL_PARTY_RUNTIME: " + label)


func _finish() -> void:
	print("POOL_PARTY_PUBLIC_RUNTIME case=%s checks=%d failures=%d" % [_case, _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _origin_probes(lab: PitchBatLab, property: StadiumNpcPublicProperty, pool: Node3D) -> void:
	# Synchronous cold probes restore each original before any ordinary frame/callback.
	_check(StadiumPoolPartyRuntime.origin_clean(lab, property), "exact Pool root origin admitted")
	pool.set_meta("stadium_lab_only", true)
	_check(not R._binding_mode(lab, property, true), "unexpected Pool root marker refused")
	pool.remove_meta("stadium_lab_only")
	pool.set_meta("stadium_candidate_only", false)
	_check(not R._binding_mode(lab, property, true), "wrong factory marker value refused")
	pool.set_meta("stadium_candidate_only", true)
	var child: Node = pool.get_node("Collision")
	child.set_meta("stadium_lab_only", true)
	_check(not R._binding_mode(lab, property, true), "Pool descendant marker refused")
	child.remove_meta("stadium_lab_only")
	property.set_meta("stadium_lab_only", true)
	_check(not R._binding_mode(lab, property, true), "non-Pool owner marker refused")
	property.remove_meta("stadium_lab_only")
	lab.set_meta("stadium_lab_only", true)
	_check(not R._binding_mode(lab, property, true), "lab ancestor marker refused")
	lab.remove_meta("stadium_lab_only")
	_check(R.installed(lab), "strict cold installation intact after restored marker probes")

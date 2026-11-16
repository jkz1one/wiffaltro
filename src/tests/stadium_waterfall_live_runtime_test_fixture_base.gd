extends Node3D
## Real paid-copy integration plus native, unforced rigid-body drops. No ordinary-game,
## authentic-earned progression, visual, Mobile or Night qualification is claimed here.
const Runtime = preload("res://src/presentation/stadium/stadium_waterfall_live_runtime.gd")
const Geometry = preload("res://src/presentation/stadium/stadium_waterfall_live_models.gd")
const Witness = preload("res://src/presentation/stadium/stadium_waterfall_trap_witness.gd")
const COPY: String = "purchase:runtime-waterfall:0"
const RADIUS: float = 0.0365
const REST: Vector3 = Vector3(0, 0.2365, -1.075)
const EPSILON: float = 0.00001

var _checks: int = 0
var _failures: Array[String] = []
var _property: StadiumPropertyGeometry
var _boundary: StadiumBoundaryOwnedRuntime
var _model: Node3D
var _snapshot: Dictionary = {}
var _outcomes: Array[BallPlayOutcome] = []
var _ordinary: Dictionary = {}
var _native_drops_count: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
		push_error("WATERFALL_LIVE_RUNTIME_FAILURE " + label)


func _context(local: Vector3, foul: bool = false, gravity: bool = false) -> Dictionary:
	_outcomes.clear()
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
	resolver.segment_observer = _boundary.observe
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 1 if gravity else 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	ball.global_position = _model.to_global(local)
	_property.bind_ball(ball, resolver)
	_boundary.bind_ball(ball, resolver)
	# This focused observer runs once after each actual physics step. No alternate
	# contact data is supplied; helper queries the native world itself.
	ball.physics_contact_router = Callable()
	ball._started = true
	return {"ball": ball, "resolver": resolver}


func _sample(
	context: Dictionary,
	previous: Vector3,
	current: Vector3,
	apply: bool = true,
	delta: float = -1.0
) -> Dictionary:
	context.resolver.advance_time(1.0 / Engine.physics_ticks_per_second if delta < 0 else delta)
	var selected: Dictionary = _boundary.event(
		previous, current, StadiumTimberDugoutBoundary.ball_radius(context.ball), context.resolver
	)
	if apply and not selected.is_empty():
		_boundary.apply_event(context.resolver, selected)
	return selected


func _admission_controls() -> void:
	for mode: String in [
		"initial-overlap",
		"hovering",
		"sub-epsilon-floor-overlap",
		"unobserved-gap",
		"frozen",
		"rebound-exit"
	]:
		var start: Vector3 = REST if mode == "initial-overlap" else Vector3(0, 0.8, -1.075)
		var context: Dictionary = _context(start)
		var previous: Vector3 = context.ball.global_position
		if mode != "initial-overlap":
			context.ball.global_position = _model.to_global(Vector3(0, 0.5, -1.075))
			_sample(context, previous, context.ball.global_position)
			previous = context.ball.global_position
			_check(not context.resolver.state.dead, "top admission alone never awards " + mode)
		if mode == "rebound-exit":
			await get_tree().physics_frame
			context.ball.global_position = _model.to_global(Vector3(0, 0.8, -1.075))
			_sample(context, previous, context.ball.global_position)
			previous = context.ball.global_position
		for frame in range(30):
			await get_tree().physics_frame
			context.ball.global_position = _model.to_global(
				(
					REST
					+ (
						Vector3.UP
						* (
							0.003
							if mode == "hovering"
							else (-0.000005 if mode == "sub-epsilon-floor-overlap" else 0)
						)
					)
				)
			)
			context.ball.linear_velocity = Vector3.ZERO
			if mode == "frozen":
				context.ball.freeze = true
			_sample(
				context,
				previous,
				context.ball.global_position,
				true,
				Witness.MAX_GAP + 0.01 if mode == "unobserved-gap" and frame == 0 else -1.0
			)
			previous = context.ball.global_position
		_check(
			not context.resolver.state.dead,
			"native authority refuses " + mode + " without generic settled timeout"
		)
		context.ball.free()


func _build() -> bool:
	var credits: Array = []
	var progress: Array = []
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(208, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		var land: Dictionary = ledger.commit(
			{
				"id": "wf-runtime-land-" + tier,
				"rev": ledger.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(land.ok, "paid Mogul path " + tier)
		if not land.ok:
			return false
	var bought: Dictionary = ledger.commit(
		{
			"id": "runtime-waterfall",
			"rev": ledger.revision(),
			"op": "stadium_buy",
			"item": "ST-046",
			"quantity": 1,
			"price_version": 32,
			"through": 40,
			"progress_through": 40
		}
	)
	_check(
		bought.ok and ledger.construction().copies.has(COPY),
		"unchanged paid ST046 stock supplies exact live copy"
	)
	if not bought.ok:
		return false
	var layout: Dictionary = StadiumWaterfallLiveItems.place(
		ledger.view().stadium_draft,
		ledger.construction(),
		COPY,
		StadiumWaterfallLiveSites.SITE,
		0,
		ledger.surface_owned()
	)
	var drafted: Dictionary = ledger.commit(
		{
			"id": "wf-runtime-draft",
			"rev": ledger.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	_check(drafted.ok, "family45 real owned draft succeeds")
	if not drafted.ok:
		return false
	var applied: Dictionary = ledger.commit(
		{
			"id": "wf-runtime-apply",
			"rev": ledger.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumWaterfallLiveItems.geometry("mogul", layout)
		}
	)
	_check(applied.ok, "family45 explicit paid-copy Apply succeeds")
	if not applied.ok:
		return false
	_snapshot = StadiumLayoutSnapshot.capture(ledger, true)
	_property = StadiumPropertyGeometry.new()
	add_child(_property)
	_check(
		_property.build("mogul", ledger.view().stadium_active, ledger.construction()),
		"full exact owned property builds"
	)
	_boundary = StadiumBoundaryRuntime.assemble(_property) as StadiumBoundaryOwnedRuntime
	_check(
		_boundary != null and _property.props_intact(),
		"ordinary owned boundary seals and routes live waterfall"
	)
	_model = _property.objects.get(COPY)
	return _boundary != null and _model != null and _property.props_intact()


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _codec_controls() -> void:
	var witness: StadiumWaterfallTrapWitness = Witness.new()
	var proof: Dictionary = {}
	var previous: Vector3 = Vector3(0, 0.8, -1.075)
	for frame in range(1, 25):
		var current: Vector3 = (
			Vector3(0, 0.5, -1.075)
			if frame == 1
			else Vector3(REST.x, Runtime._native_support_ceiling(RADIUS), REST.z)
		)
		proof = witness.observe(
			{
				"copy": COPY,
				"serial": 1,
				"frame": frame,
				"time": frame * 0.05,
				"previous": previous,
				"position": current,
				"velocity": Vector3.ZERO,
				"radius": RADIUS,
				"active": true,
				"contact": "none" if frame == 1 else "support"
			}
		)
		previous = current
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var floors: Dictionary = {
		"version": 1,
		"serial": 1,
		"events":
		[
			{
				"frame": 1,
				"time": 0.01,
				"previous": [-10.2, 1.1, 10.0],
				"position": [-10.2, 1.1, 12.0],
				"grounded": false,
				"touched": false,
				"foul": false,
				"before": 0,
				"after": 1
			},
			{
				"frame": 2,
				"time": 0.02,
				"previous": [-10.2, 1.1, 12.0],
				"position": [-10.2, 1.1, 18.325],
				"grounded": false,
				"touched": false,
				"foul": false,
				"before": 1,
				"after": 2
			}
		]
	}
	_check(
		Runtime.floor_evidence_valid(floors, proof, 2, field),
		"ordered real safe/deep crossings replay prior earned Double from NONE"
	)
	_check(
		not Runtime.floor_evidence_valid(
			{"version": 1, "serial": 1, "events": []}, proof, 2, field
		),
		"empty floor chronology cannot be paired with a fabricated higher result"
	)
	for mode: String in [
		"serial",
		"same-frame",
		"same-time",
		"future",
		"negative-time",
		"no-crossing",
		"foul",
		"grounded",
		"touched",
		"preseed",
		"fake-triple"
	]:
		var bad_floors: Dictionary = floors.duplicate(true)
		match mode:
			"serial":
				bad_floors.serial = 9
			"same-frame":
				bad_floors.events[1].frame = 1
			"same-time":
				bad_floors.events[1].time = 0.01
			"future":
				bad_floors.events[1].time = proof.observed_at + 0.01
			"negative-time":
				bad_floors.events[0].time = -0.5
			"no-crossing":
				bad_floors.events[1].previous[2] = 18.0
			"foul":
				bad_floors.events[1].foul = true
			"grounded":
				bad_floors.events[1].grounded = true
			"touched":
				bad_floors.events[1].touched = true
			"preseed":
				bad_floors.events[0].before = 1
			"fake-triple":
				bad_floors.events[1].after = 3
		_check(
			not Runtime.floor_evidence_valid(bad_floors, proof, 2, field),
			"earned-floor chronology rejects " + mode
		)
	var encoded: Dictionary = Runtime.proof_to_data(proof)
	var cold: Variant = JSON.parse_string(JSON.stringify(encoded, "", true, true))
	var recovered: Dictionary = Runtime.proof_from_data(cold)
	_check(
		(
			not recovered.is_empty()
			and Witness.replay(recovered)
			and (
				JSON.stringify(Runtime.proof_to_data(recovered), "", true, true)
				== JSON.stringify(encoded, "", true, true)
			)
		),
		"JSON-safe full precision evidence roundtrips canonical typed witness"
	)
	for mode: String in [
		"bad-vector",
		"bad-frame",
		"extra-field",
		"no-entry",
		"missing-contact",
		"missing-encoding",
		"bad-scalar",
		"nonfinite-scalar"
	]:
		var bad: Dictionary = encoded.duplicate(true)
		match mode:
			"bad-vector":
				bad.samples[-1].position = [0, "bad", 0]
			"bad-frame":
				bad.samples[-1].frame = 0.5
			"extra-field":
				bad["caller_support"] = true
			"no-entry":
				bad.samples[0].previous = _vector(REST)
			"missing-contact":
				bad.samples[-1].erase("contact")
			"missing-encoding":
				bad.erase("float_encoding")
			"bad-scalar":
				bad.samples[-1].time = "caller-says-still"
			"nonfinite-scalar":
				bad.samples[-1].time = Runtime._float_data(INF)
		_check(
			Runtime.proof_from_data(bad).is_empty(),
			"malformed serialized evidence rejected " + mode
		)


func _finish() -> void:
	print(
		(
			"WATERFALL_LIVE_RUNTIME_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"native_drops": _native_drops_count,
					"physical_games": 0,
					"synthetic_funding": true,
					"synthetic_progression": true,
					"visual_qualified": false
				}
			)
		)
	)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _geometry() -> void:
	_check(
		_model.position == StadiumWaterfallLiveSites.CENTER and _model.basis == Basis.IDENTITY,
		"exact full-scale paid placement, no automatic relocation"
	)
	var body: StaticBody3D = _model.get_node("Collision/" + Geometry.SURFACE)
	_check(
		body.get_child_count() == 13 and _model.get_node("Visual").get_child_count() == 21,
		"same frozen 21 visible meshes and 13 genuine native stone boxes"
	)
	var hit: Dictionary = _boundary.event(
		_model.to_global(Vector3(0, 0.4, -3)), _model.to_global(Vector3(0, 0.4, -1)), RADIUS
	)
	_check(
		(
			hit.get("kind") == "waterfall_solid"
			and hit.get("role") == "LIVE_RICOCHET"
			and hit.get("body_id") == body.get_instance_id()
		),
		"real basin rim sweep yields owned live ricochet"
	)
	var open: Dictionary = _boundary.event(
		_model.to_global(Vector3(0, 1.1, -1.075)), _model.to_global(Vector3(0, 0.4, -1.075)), RADIUS
	)
	_check(open.is_empty(), "open-top path and visible water have no manufactured collision")
	var decorative: Node3D = StadiumWaterfallModels.create()
	decorative.set_meta("owned_copy", "decorative-control")
	decorative.set_meta("site", "LANDMARK-A")
	add_child(decorative)
	_check(
		(
			not Runtime._live(decorative)
			and decorative.find_children("*", "CollisionObject3D", true, false).is_empty()
		),
		"frozen LANDMARK-A decoration cannot become live authority"
	)
	decorative.free()
	var forged: StaticBody3D = StaticBody3D.new()
	for key: String in ["owned_copy", "stadium_item", "surface_id", "surface_role"]:
		forged.set_meta(key, body.get_meta(key))
	add_child(forged)
	_check(
		Runtime.native_event(_property, forged, _model.global_position).is_empty(),
		"copied contact metadata without exact issued native body is rejected"
	)
	forged.free()


func _untrusted_geometry_wire(proof: Dictionary) -> Dictionary:
	# Test-only encoding of deliberately untrusted geometric evidence. The native
	# writer must refuse it; this separately exercises the reader against raw bytes.
	var data: Dictionary = proof.duplicate(true)
	data["float_encoding"] = Runtime.FLOAT_ENCODING
	for key: String in ["quiet_since", "observed_at", "radius"]:
		data[key] = Runtime._float_data(float(data[key]))
	data.entry.fraction = Runtime._float_data(float(data.entry.fraction))
	data.position = Runtime._vector_data(proof.position)
	data.entry.position = Runtime._vector_data(proof.entry.position)
	for row: Dictionary in data.samples:
		for key: String in ["time", "radius"]:
			row[key] = Runtime._float_data(float(row[key]))
		for key: String in ["previous", "position", "velocity"]:
			row[key] = Runtime._vector_data(row[key])
	return data
func _cold_support_negatives(rows: Array, plays: Array, snapshot: Dictionary) -> void:
	var typed: Dictionary = Runtime.proof_from_data(rows[0].events[-1].waterfall_proof)
	for all_samples: bool in [true, false]:
		var bad: Array = rows.duplicate(true)
		var changed: bool = false
		for sample: Dictionary in bad[0].events[-1].waterfall_proof.samples:
			if (
				sample.contact == "support"
				and (all_samples or sample.frame == bad[0].events[-1].waterfall_proof.frame)
			):
				sample.contact = "none"
				changed = true
		_check(
			(
				changed
				and not PhysicalStadiumContacts.valid(
					JSON.parse_string(JSON.stringify(bad, "", true, true)), plays, snapshot
				)
			),
			"cold native proof rejects omitted support labels: " + str(all_samples)
		)
	for offset: float in [0.003, 0.000005, -0.000005]:
		var witness: StadiumWaterfallTrapWitness = Witness.new()
		var previous: Vector3 = typed.samples[0].previous
		var rebuilt: Dictionary = {}
		var last: Dictionary = {}
		for original: Dictionary in typed.samples:
			var sample: Dictionary = original.duplicate(true)
			sample.previous = previous
			if sample.time >= typed.quiet_since - 0.20:
				sample.position.y += offset
			rebuilt = witness.observe(sample)
			previous = sample.position
			last = sample
		for index in range(24):
			last = last.duplicate(true)
			last.previous = last.position
			last.frame += 1
			last.time += 1.0 / 60.0
			last.velocity = Vector3.ZERO
			last.contact = "support"
			rebuilt = witness.observe(last)
		_check(
			not rebuilt.is_empty() and Witness.replay(rebuilt),
			"geometry-only forged height control is internally consistent: " + str(offset)
		)
		if rebuilt.is_empty():
			continue
		_check(
			Runtime.proof_to_data(rebuilt).is_empty(),
			"native writer rejects unsupported geometry-only height: " + str(offset)
		)
		var bad: Array = rows.duplicate(true)
		bad[0].events[-1].waterfall_proof = _untrusted_geometry_wire(rebuilt)
		bad[0].events[-1].time = rebuilt.observed_at
		bad[0].events[-1].position = Runtime._vector_data(
			rebuilt.position + StadiumWaterfallLiveSites.CENTER
		)
		_check(
			not PhysicalStadiumContacts.valid(
				JSON.parse_string(JSON.stringify(bad, "", true, true)), plays, snapshot
			),
			"cold native reader rejects unsupported geometry-only height: " + str(offset)
		)

	for delta: float in [0.000005, -0.000005]:
		var radius: float = typed.radius + delta
		var witness: StadiumWaterfallTrapWitness = Witness.new()
		var previous: Vector3 = typed.samples[0].previous + Vector3.UP * delta
		var rebuilt: Dictionary = {}
		for original: Dictionary in typed.samples:
			var sample: Dictionary = original.duplicate(true)
			sample.radius = radius
			sample.previous = previous
			sample.position.y += delta
			if sample.time >= typed.quiet_since:
				sample.position.y = Runtime._native_support_ceiling(radius)
			rebuilt = witness.observe(sample)
			previous = sample.position
		_check(
			not rebuilt.is_empty() and Runtime.native_proof_valid(rebuilt),
			"substituted-radius control has consistent native-height evidence: " + str(delta)
		)
		if rebuilt.is_empty():
			continue
		var bad: Array = rows.duplicate(true)
		bad[0].events[-1].waterfall_proof = _untrusted_geometry_wire(rebuilt)
		bad[0].events[-1].time = rebuilt.observed_at
		bad[0].events[-1].position = Runtime._vector_data(
			rebuilt.position + StadiumWaterfallLiveSites.CENTER
		)
		_check(
			not PhysicalStadiumContacts.valid(
				JSON.parse_string(JSON.stringify(bad, "", true, true)), plays, snapshot
			),
			"cold report rejects micrometre-scale radius substitution: " + str(delta)
		)


func _validate_record(
	context: Dictionary, expected: int, label: String, valid_floor: bool = true
) -> void:
	var names: Array[String] = ["out", "foul", "single", "double", "triple", "home_run"]
	var plays: Array = [
		{
			"result": names[expected],
			"contact":
			(
				ContactResult.Outcome.FOUL
				if context.resolver.state.is_foul_play
				else ContactResult.Outcome.CONTACT
			),
			"exit_speed": 7.0
		}
	]
	var rows: Array = [
		{
			"play": 0,
			"reason": String(_outcomes[0].reason) if not _outcomes.is_empty() else "",
			"events": context.resolver.state.stadium_contacts.duplicate(true)
		}
	]
	_check(
		PhysicalStadiumContacts.valid(rows, plays, _snapshot) == valid_floor,
		"native record requires exact owned snapshot and evidenced prior floor: " + label
	)
	var cold_rows: Variant = JSON.parse_string(JSON.stringify(rows, "", true, true))
	var cold_snapshot: Dictionary = JSON.parse_string(JSON.stringify(_snapshot, "", true, true))
	_check(
		PhysicalStadiumContacts.valid(cold_rows, plays, cold_snapshot) == valid_floor,
		"complete cold JSON report replays owned native evidence and earned floor: " + label
	)
	if valid_floor and not PhysicalStadiumContacts.valid(cold_rows, plays, cold_snapshot):
		var last: Dictionary = cold_rows[0].events[-1]
		var proof: Dictionary = Runtime.proof_from_data(last.waterfall_proof)
		print(
			(
				"WATERFALL_COLD_DIAGNOSTIC "
				+ JSON.stringify(
					{
						"label": label,
						"snapshot_valid": StadiumLayoutSnapshot.valid(cold_snapshot),
						"proof_valid": not proof.is_empty(),
						"floor_valid":
						Runtime.floor_evidence_valid(
							last.waterfall_floor_evidence,
							proof,
							int(last.earned_floor),
							ContentDB.get_field(PitchBatLab.FIELD_ID)
						),
						"raw_layout_hash_matches":
						(
							last.waterfall_layout_hash
							== JSON.stringify(cold_snapshot.layout, "", true, true).sha256_text()
						),
						"normalized_layout_hash_matches":
						(
							last.waterfall_layout_hash
							== (
								JSON
								. stringify(
									StadiumLayoutSnapshot.normalized(cold_snapshot).layout,
									"",
									true,
									true
								)
								. sha256_text()
							)
						)
					}
				)
			)
		)
	if rows[0].events.is_empty() or not rows[0].events[-1].has("waterfall_proof"):
		_check(false, "terminal report carries native entry/dwell proof: " + label)
		return
	if label == "minimum-single":
		_cold_support_negatives(rows, plays, cold_snapshot)
	for field: String in [
		"id",
		"surface",
		"waterfall_layout_hash",
		"earned_floor",
		"waterfall_proof",
		"floor-result-pair"
	]:
		var bad: Array = rows.duplicate(true)
		match field:
			"id":
				bad[0].events[-1][field] = "stored-or-foreign-copy"
			"surface":
				bad[0].events[-1][field] = Geometry.SURFACE
			"waterfall_layout_hash":
				bad[0].events[-1][field] = "forged"
			"earned_floor":
				bad[0].events[-1][field] = -1
			"waterfall_proof":
				bad[0].events[-1][field].samples[0].previous = [0.0, 0.3, -1.075]
			"floor-result-pair":
				bad[0].events[-1].earned_floor = BallPlayState.ResultFloor.TRIPLE
		var changed_plays: Array = plays.duplicate(true)
		if field == "floor-result-pair":
			changed_plays[0].result = "triple"
		_check(
			not PhysicalStadiumContacts.valid(bad, changed_plays, _snapshot),
			"persisted report rejects forged " + field + ": " + label
		)


func _native_drop(
	foul: bool, floor_value: int, label: String, apply: bool = true, approach: bool = false
) -> Dictionary:
	_native_drops_count += 1
	var context: Dictionary = _context(
		Vector3(0, 1.1, -9.4) if approach else Vector3(0, 1.1, -1.075), foul, true
	)
	context.resolver.state.raise_result_floor(floor_value)
	if approach:
		# Explicit synthetic preflight geometry exercises the actual ordinary band
		# observer, not a pre-seeded floor. After this setup the drop is unforced.
		var from: Vector3 = context.ball.global_position
		context.ball.global_position = _model.to_global(Vector3(0, 1.1, -1.075))
		_boundary.observe(context.resolver, from, context.ball.global_position)
		_check(
			context.resolver.state.result_floor == BallPlayState.ResultFloor.DOUBLE,
			"real safe/deep-plane observer, rather than scalar preseed, establishes prior Double"
		)
	var previous: Vector3 = context.ball.global_position
	var selected: Dictionary = {}
	var entry_seen: bool = false
	var floor_seen: bool = false
	var rebound_seen: bool = false
	var impacts: int = 0
	for frame in range(240):
		await get_tree().physics_frame
		var current: Vector3 = context.ball.global_position
		var local: Vector3 = _model.to_local(current)
		if not Geometry.trap_entry_local(_model.to_local(previous), local, RADIUS).is_empty():
			entry_seen = true
		if local.y < 0.25:
			floor_seen = true
		if floor_seen and context.ball.linear_velocity.y > 0.1:
			rebound_seen = true
		selected = _sample(context, previous, current, apply)
		if selected.get("kind") == "waterfall_solid":
			impacts += 1
		previous = current
		if selected.get("kind") == "waterfall_trap" or context.resolver.state.dead:
			break
	_check(
		entry_seen and floor_seen and rebound_seen and impacts > 0,
		"unforced native descent observes genuine top entry, floor contact and rebound: " + label
	)
	_check(
		(
			selected.get("kind") == "waterfall_trap"
			and Witness.replay(selected.get("waterfall_proof", {}))
		),
		"current bound native drop yields independently replayable sustained proof: " + label
	)
	if selected.get("kind") != "waterfall_trap":
		var actual_y: float = _model.to_local(context.ball.global_position).y
		var support_y: float = (
			Vector3(
				0,
				(
					Geometry.basin_volume().position.y
					+ StadiumTimberDugoutBoundary.ball_radius(context.ball)
				),
				0
			)
			. y
		)
		print(
			(
				"WATERFALL_SUPPORT_DIAGNOSTIC "
				+ label
				+ " actual_y="
				+ String.num(actual_y, 17)
				+ " representable_support_y="
				+ String.num(support_y, 17)
			)
		)
	if not apply:
		context["selected"] = selected
		return context
	var expected: int = (
		BallPlayOutcome.Result.FOUL
		if foul
		else (
			BallPlayOutcome.Result.DOUBLE
			if approach
			else (
				BallPlayOutcome.Result.TRIPLE
				if floor_value == BallPlayState.ResultFloor.TRIPLE
				else BallPlayOutcome.Result.SINGLE
			)
		)
	)
	_check(
		context.resolver.state.dead and _outcomes.size() == 1 and _outcomes[0].result == expected,
		"foul-first minimum Single preserving higher earned floor: " + label
	)
	_check(
		not _boundary.apply_event(context.resolver, selected),
		"issued terminal event is single-use: " + label
	)
	if not selected.get("waterfall_proof", {}).is_empty():
		var proof: Dictionary = selected.waterfall_proof
		_check(
			proof.observed_at - proof.quiet_since + EPSILON >= Witness.DWELL,
			"at least 0.30 seconds quiet, never total elapsed play: " + label
		)
		print(
			(
				"WATERFALL_OWNED_NATIVE_TRACE "
				+ JSON.stringify(
					{
						"label": label,
						"samples": proof.samples.size(),
						"at": proof.observed_at,
						"quiet_since": proof.quiet_since,
						"copy": proof.copy,
						"serial": proof.serial,
						"rebound": rebound_seen,
						"proof_hash":
						JSON.stringify(Runtime.proof_to_data(proof), "", true, true).sha256_text()
					}
				)
			)
		)
	_validate_record(context, expected, label, floor_value <= BallPlayState.ResultFloor.DOUBLE)
	context.ball.free()
	return {}




func _issued_controls() -> void:
	var context: Dictionary = await _native_drop(
		false, BallPlayState.ResultFloor.NONE, "issued-controls", false
	)
	var selected: Dictionary = context.selected
	if selected.get("kind") != "waterfall_trap":
		context.ball.free()
		return
	var forged: Dictionary = selected.duplicate(true)
	forged.waterfall_proof.samples[-1].velocity.x = 99
	_check(
		not _boundary.apply_event(context.resolver, forged),
		"forged typed proof cannot match boundary-issued event"
	)
	var original: Vector3 = context.ball.global_position
	context.ball.global_position += Vector3.UP * 0.02
	_check(
		not Runtime.apply(
			_property,
			context.resolver,
			selected,
			_boundary._flights[context.resolver.get_instance_id()]
		),
		"current ball movement rejects otherwise issued proof"
	)
	context.ball.global_position = original
	context.ball.freeze = true
	_check(
		not Runtime.apply(
			_property,
			context.resolver,
			selected,
			_boundary._flights[context.resolver.get_instance_id()]
		),
		"freeze rejects stale award authority"
	)
	context.ball.freeze = false
	var bound: Dictionary = _boundary._flights[context.resolver.get_instance_id()]
	var old_radius: float = context.ball.radius_m
	context.ball.radius_m += 0.01
	_check(
		not Runtime.apply(_property, context.resolver, selected, bound),
		"changed aero/native sphere agreement rejects radius substitution"
	)
	context.ball.radius_m = old_radius
	var original_state: BallPlayState = context.resolver.state
	context.resolver.state = BallPlayState.new()
	_check(
		not Runtime.apply(_property, context.resolver, selected, bound),
		"replacement play state cannot inherit a prior admitted flight"
	)
	context.resolver.state = original_state
	original_state.dead = true
	_check(
		not Runtime.apply(_property, context.resolver, selected, bound),
		"already-dead play cannot receive a second terminal award"
	)
	original_state.dead = false
	var old_world: Transform3D = _model.transform
	_model.position.x += 0.01
	_check(
		not Runtime.apply(_property, context.resolver, selected, bound),
		"changed current owned model pose rejects issued proof"
	)
	_model.transform = old_world
	var foreign_copy: Dictionary = selected.duplicate(true)
	foreign_copy.owned_copy = "foreign-paid-copy"
	_check(
		not Runtime.apply(_property, context.resolver, foreign_copy, bound),
		"substituted paid copy cannot reuse another model's evidence"
	)
	var frame_event: Dictionary = selected.duplicate(true)
	frame_event.frame -= 1
	_check(
		not Runtime.apply(
			_property,
			context.resolver,
			frame_event,
			_boundary._flights[context.resolver.get_instance_id()]
		),
		"sameframe requirement rejects prior frame"
	)
	context.resolver.advance_time(0.001)
	_check(
		not _boundary.apply_event(context.resolver, selected),
		"time advance invalidates current issued proof"
	)
	var parent: Node = context.ball.get_parent()
	var foreign_parent: Node3D = Node3D.new()
	add_child(foreign_parent)
	context.ball.reparent(foreign_parent)
	_check(
		not Runtime.apply(_property, context.resolver, selected, bound),
		"reparented current ball cannot consume original flight authority"
	)
	context.ball.reparent(parent)
	foreign_parent.free()
	_boundary.bind_ball(context.ball, context.resolver)
	_check(
		not _boundary.apply_event(context.resolver, selected),
		"rebind serial cannot inherit admission or old event"
	)
	context.ball.free()

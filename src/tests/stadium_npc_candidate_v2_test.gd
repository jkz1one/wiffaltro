extends Node
## Candidate data, exact physical correspondence and identity attacks. Never certification.

var _failures: int = 0


func _ready() -> void:
	for id: String in ["AY-01", "AE-01", "AC-01"]:
		_data(id)
		_construction(id)
	_check(
		ContentDB.get_field(&"field.npc_venue") == null,
		"private NPC field cannot enter ContentDB human field choices"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro candidate NPC r2 data passed: exact literals, field, identity and geometry."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _data(id: String) -> void:
	var old: Dictionary = StadiumNpcVenues.definition(id, 1)
	var candidate: Dictionary = StadiumNpcCandidatesV2.definition(id)
	var bytes: String = JSON.stringify(candidate, "", true, true)
	_check(
		(
			not candidate.is_empty()
			and candidate.revision == 2
			and candidate.field == "field.npc_venue"
			and candidate.environment_certificates.is_empty()
		),
		"explicit unqualified r2 candidate " + id
	)
	_check(
		(
			not StadiumNpcVenues.definition(id, 2).is_empty()
			and not StadiumNpcVenues.valid_manifest(candidate)
		),
		"public r2 exists separately; empty-certificate candidate has no public authority"
	)
	var public_value: Dictionary = StadiumNpcVenues.definition(id, 2)
	_check(not StadiumNpcCandidatesV2.valid_manifest(public_value), "public is not a candidate")
	public_value.environment_certificates = []
	_check(JSON.stringify(public_value, "", true, true) == bytes,
		"public empty-certificate bytes exactly equal frozen candidate")
	_check(StadiumNpcCandidatesV2.decode(bytes) == candidate, "exact JSON canonical roundtrip")
	_check(
		(
			StadiumNpcCandidatesV2.key(candidate).length() == 64
			and StadiumNpcCandidatesV2.payload_key(candidate).length() == 64
			and (
				StadiumNpcCandidatesV2.key(candidate)
				!= StadiumNpcCandidatesV2.payload_key(candidate)
			)
		),
		"full manifest and certificate-excluded payload have separate nonrecursive domains"
	)
	var expected_count: int = {"AY-01": 4, "AE-01": 27, "AC-01": 72}[id]
	_check(candidate.instances.size() == expected_count, "exact bounded instance count")
	for index in range(old.instances.size()):
		var before: Dictionary = old.instances[index]
		var after: Dictionary = candidate.instances[index]
		_check(
			(
				after.instance == "npc:%s:r2:%s" % [id, before.site]
				and before.item == after.item
				and before.site == after.site
				and var_to_bytes(before.transform) == var_to_bytes(after.transform)
			),
			"independent per-site transform/type/item correspondence"
		)
		var host: String = "field"
		if before.host != "field":
			for old_host: Dictionary in old.instances:
				if old_host.instance == before.host:
					host = "npc:%s:r2:%s" % [id, old_host.site]
		_check(after.host == host, "explicit host resolves to same physical site")
	for key: String in old:
		if key not in ["revision", "assembly", "field", "instances"]:
			_check(
				var_to_bytes(old[key]) == var_to_bytes(candidate[key]),
				"unchanged sport/model/presentation/valuation literal " + key
			)
	for field: String in ["field.starter_backyard", "field.commons_park", "field.unknown"]:
		var wrong: Dictionary = candidate.duplicate(true)
		wrong.field = field
		_check(not StadiumNpcCandidatesV2.valid_manifest(wrong), "wrong field rejected " + field)
	for mutation: String in ["mixed", "dangling", "pose", "type", "certificate", "assembly"]:
		var wrong: Dictionary = candidate.duplicate(true)
		match mutation:
			"mixed":
				wrong.instances[0].instance = old.instances[0].instance
			"dangling":
				wrong.instances[0].host = "npc:%s:r2:ABSENT" % id
			"pose":
				wrong.instances[0].transform[9] += 0.125
			"type":
				wrong.instances[0].transform[9] = str(wrong.instances[0].transform[9])
			"certificate":
				wrong.environment_certificates = [
					{
						"mode": "day",
						"profile": "",
						"version": 1,
						"assembly_sha256": StadiumNpcCandidatesV2.payload_key(candidate)
					}
				]
			"assembly":
				wrong.assembly = old.assembly
		_check(
			(
				not StadiumNpcCandidatesV2.valid_manifest(wrong)
				and StadiumNpcCandidatesV2.key(wrong).is_empty()
			),
			"forged candidate fails " + mutation
		)
	candidate.instances[0].transform[9] += 1.0
	_check(
		JSON.stringify(StadiumNpcCandidatesV2.definition(id), "", true, true) == bytes,
		"nested candidate returns cannot mutate literal registry"
	)


func _construction(id: String) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.set_meta("stadium_npc_retained_lab_only", true)
	var old: StadiumNpcRetainedProperty = StadiumNpcRetainedRuntime._stage(lab, id, 1)
	var candidate: StadiumNpcRetainedProperty = StadiumNpcCandidateRuntimeV2._stage(lab, id, 2)
	_check(old != null and candidate != null, "both independent public construction seams stage")
	if old == null or candidate == null:
		if old != null:
			old.free()
		if candidate != null:
			candidate.free()
		lab.free()
		return
	_check(
		StadiumNpcCandidateConstructionV2.valid(candidate), "all installed r2 hosts and field exact"
	)
	_check(
		(
			StadiumNpcRetainedRuntime._construct(lab, id, 2) == null
			and not StadiumNpcRetainedRuntime._complete(lab, candidate)
			and not StadiumNpcRetainedRuntime._commit(lab, candidate)
		),
		"r1 wrappers never admit r2"
	)
	var actual: Dictionary = StadiumNpcRetainedGeometry._geometry(candidate)
	var expected: Dictionary = StadiumNpcRetainedGeometry._geometry(old)
	_normalize_identity(actual, id)
	_add_hosts(expected, old, StadiumNpcVenues.definition(id, 1), old.objects)
	if var_to_bytes(_ordered(actual)) != var_to_bytes(_ordered(expected)):
		_difference(actual, expected, id)
	_check(
		var_to_bytes(_ordered(actual)) == var_to_bytes(_ordered(expected)),
		"all actual meshes/materials/colliders/transforms/scripts match retained r1 exactly"
	)
	_check(
		(
			var_to_bytes(_r1_routes(candidate.route_obstacles(), id))
			== var_to_bytes(old.route_obstacles())
		),
		"actual route bounds unchanged byte-for-byte"
	)
	if id != "AY-01":
		var identity: String = "npc:%s:r2:RECEIVER-PRIMARY" % id
		var target: Node3D = candidate.objects[identity]
		candidate.objects.erase(identity)
		_check(
			candidate.route_obstacles().is_empty(),
			"missing receiver key fails without script error"
		)
		candidate.objects[identity] = target
		_check(not candidate.route_obstacles().is_empty(), "exact receiver route restores")
	for key: String in StadiumNpcYardV1.FIELD:
		if key not in ["id", "display_name"]:
			_check(
				(
					typeof(candidate.field.get(key)) == typeof(old.field.get(key))
					and candidate.field.get(key) == old.field.get(key)
				),
				"exact sport field " + key
			)
	for index in range(9):
		_check(
			(
				candidate.field.fielder_anchor(index) == old.field.fielder_anchor(index)
				and (
					candidate.field.is_fielder_anchor_available(index)
					== old.field.is_fielder_anchor_available(index)
				)
			),
			"all anchor methods correspond"
		)
	var original_field: FieldDefinition = candidate.field
	var forged: FieldDefinition = (
		preload("res://src/tests/stadium_npc_candidate_v2_forged_field.gd").new()
	)
	for key: String in StadiumNpcYardV1.FIELD:
		forged.set(key, original_field.get(key))
	candidate.field = forged
	candidate.construction.field = forged
	_check(
		not StadiumNpcCandidateRuntimeV2._complete(lab, candidate),
		"equal field exports cannot conceal a substituted sport-method script"
	)
	candidate.field = original_field
	candidate.construction.field = original_field
	var original_id: StringName = candidate.field.id
	candidate.field.id = &"field.starter_backyard"
	_check(not StadiumNpcCandidateRuntimeV2._complete(lab, candidate), "forged field rejected")
	candidate.field.id = original_id
	var model: Node3D = candidate.objects.values()[0]
	var host: String = model.get_meta("npc_host")
	model.set_meta("npc_host", "npc:%s:r1:ABSENT" % id)
	_check(
		not StadiumNpcCandidateRuntimeV2._complete(lab, candidate), "mixed installed host rejected"
	)
	model.set_meta("npc_host", host)
	_check(
		StadiumNpcCandidateRuntimeV2._complete(lab, candidate), "exact restoration qualifies again"
	)
	old.free()
	candidate.free()
	lab.free()


func _normalize_identity(node: Dictionary, id: String) -> void:
	# Independent site-derived inverse, not the construction remap table.
	for key: String in ["npc_instance", "owned_copy", "npc_host"]:
		if not node.has(key) or node[key] == "field":
			continue
		var matched: bool = false
		for row: Dictionary in StadiumNpcVenues.definition(id, 1).instances:
			if node[key] == "npc:%s:r2:%s" % [id, row.site]:
				node[key] = row.instance
				matched = true
				break
		_check(matched, "every identity-bearing actual node belongs to finite known r2 site")
	for child: Dictionary in node.children:
		_normalize_identity(child, id)


func _add_hosts(
	snapshot: Dictionary, node: Node, definition: Dictionary, objects: Dictionary
) -> void:
	# r1 Yard/Expanded omit host metadata. Add only the independently literal-defined host.
	for row: Dictionary in definition.instances:
		if objects.get(row.instance) == node:
			snapshot["npc_host"] = row.host
	for index in range(node.get_child_count()):
		_add_hosts(snapshot.children[index], node.get_child(index), definition, objects)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _ordered(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort()
		for key: Variant in keys:
			result[key] = _ordered(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_ordered(item))
		return result
	return value


func _r1_routes(rows: Array[Dictionary], id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = rows.duplicate(true)
	for row: Dictionary in result:
		if not row.has("copy"):
			continue
		var matched: bool = false
		for instance: Dictionary in StadiumNpcVenues.definition(id, 1).instances:
			if row.copy == "npc:%s:r2:%s" % [id, instance.site]:
				row.copy = instance.instance
				matched = true
				break
		_check(matched, "route copy belongs to explicit r2 instance before inverse comparison")
	return result


# gdlint: disable=max-returns
func _difference(actual: Variant, expected: Variant, path: String) -> bool:
	if typeof(actual) != typeof(expected):
		print("NPC_R2_GEOMETRY_DIFF type ", path, " ", typeof(actual), " != ", typeof(expected))
		return true
	if actual is Dictionary:
		for key: Variant in actual:
			if not expected.has(key):
				print("NPC_R2_GEOMETRY_DIFF extra ", path, ".", key)
				return true
			if _difference(actual[key], expected[key], path + "." + str(key)):
				return true
		for key: Variant in expected:
			if not actual.has(key):
				print("NPC_R2_GEOMETRY_DIFF missing ", path, ".", key)
				return true
	elif actual is Array:
		if actual.size() != expected.size():
			print("NPC_R2_GEOMETRY_DIFF length ", path, " ", actual.size(), " != ", expected.size())
			return true
		for index in range(actual.size()):
			if _difference(actual[index], expected[index], path + "[" + str(index) + "]"):
				return true
	elif var_to_bytes(actual) != var_to_bytes(expected):
		print("NPC_R2_GEOMETRY_DIFF value ", path, " actual=", actual, " expected=", expected)
		return true
	return false

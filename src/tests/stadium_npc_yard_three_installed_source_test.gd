extends Node3D
## Independent original-authoring correspondence and immutable baseline source checks.

const MAP: String = "res://src/tests/fixtures/npc_yard_three_installed_baseline.json"
var _failures: int = 0


func _ready() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	for path: String in manifest.files:
		_check(FileAccess.file_exists("res://" + path)
			and FileAccess.get_sha256("res://" + path) == manifest.files[path],
			"unchanged complete baseline source " + path)
	_check(StadiumNpcYardThreeCandidateV1.key(StadiumNpcYardThreeCandidateV1.definition())
		== "4ce7a2b451994bd64a0173c80bb30dc001f4229b6f6d1e5383b253012415e652",
		"immutable candidate C is unchanged")
	_check(StadiumNpcManifest.payload_key(StadiumNpcYardThreeCandidateV1.definition())
		== "1ba39621a6b93ce887360cf04cd38ecbfd19a36cba06e754f94e9fb459d423d7",
		"immutable subject S is unchanged and has no new certificate")
	var property: StadiumNpcYardThreePropertyV1 = StadiumNpcYardThreeRuntimeV1._construct(
		null, "AY-03", 1)
	var source: StadiumPropertyGeometry = StadiumYardThreeStudy.build()
	_check(property != null and source != null, "independent original and installed stages build")
	if property != null and source != null:
		_check(StadiumNpcYardThreeCorrespondence._policies(property.construction, source, true),
			"actual retained node/resource/script/execution policies match original authoring")
		_check(var_to_bytes(_without_contact_alias(StadiumNpcYardThreeCorrespondence._snapshot(
			property.construction, true))) == var_to_bytes(_without_contact_alias(
			StadiumNpcYardThreeCorrespondence._snapshot(source, true))),
			"installed retained geometry equals independent original eight-copy authoring")
		for row: Dictionary in StadiumNpcYardThreeCandidateV1.definition().instances:
			var model: Node3D = property.objects[row.instance]
			_check(model.get_meta("npc_instance") == row.instance
				and model.get_meta("owned_copy") == row.instance
				and model.get_meta("npc_site") == row.site
				and model.get_meta("npc_host") == row.host,
				"compatibility alias preserves exact NPC identity without human stock")
			for body: StaticBody3D in model.get_node("Collision").get_children():
				_check(body.get_meta("owned_copy") == row.instance
					and body.get_meta("npc_instance") == row.instance,
					"actual contact body alias is exact")
		for key: String in StadiumNpcYardV1.FIELD:
			_check(typeof(property.field.get(key)) == typeof(source.field.get(key))
				and property.field.get(key) == source.field.get(key), "exact field semantics " + key)
		_check(property.view_graph().get_script() == StadiumNpcYardV1.TemplateView
			and property.route_obstacles().is_empty() and property.receiver == null,
			"private adapter explicitly selects Yard graph and empty receiver/routes")
		for start: Vector3 in [Vector3(0, 0, 10), Vector3(-15, 0, 12), Vector3(15, 0, 12)]:
			for end: Vector3 in [Vector3(-100, 0, 20), Vector3(100, 0, 20),
				Vector3(0, 0, 100), Vector3(0, 0, -100)]:
				_check(property.clip(start, end) == StadiumBoundaryGraph.clip(start, end),
					"installed private clipping equals original independently authored Yard")
		_resource_controls(property)
		property.free()
		source.free()
	else:
		if property != null:
			property.free()
		if source != null:
			source.free()
	await get_tree().process_frame
	if _failures == 0:
		print("Wiffaltro AY03 installed source passed: original correspondence and closed baseline.")
	get_tree().quit(0 if _failures == 0 else 1)


func _without_contact_alias(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.erase("owned_copy")
	var children: Array = []
	for child: Dictionary in result.children:
		children.append(_without_contact_alias(child))
	result.children = children
	return result


func _resource_controls(actual: StadiumNpcYardThreePropertyV1) -> void:
	var reference: StadiumNpcYardThreePropertyV1 = StadiumNpcYardThreeRuntimeV1._construct(
		null, "AY-03", 1)
	_check(StadiumNpcYardThreeInstalledGeometryV1.same(actual, reference),
		"fresh strict installed-geometry positive control")
	var mesh: MeshInstance3D = actual.objects["npc:AY-03:r1:YLIGHT-FL"].get_node("Visual/Footing")
	var script: GDScript = GDScript.new()
	script.source_code = "extends BoxMesh\n"
	_check(script.reload() == OK, "same-valued resource script negative control compiles")
	mesh.mesh.set_script(script)
	_check(not StadiumNpcYardThreeInstalledGeometryV1.same(actual, reference),
		"same-valued scripted resource cannot bypass stored-geometry comparison")
	mesh.mesh.set_script(null)
	_check(StadiumNpcYardThreeInstalledGeometryV1.same(actual, reference),
		"exact resource restoration passes strict geometry")
	reference.free()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

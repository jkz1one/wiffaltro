extends Node3D
## Fresh reconstruction. No old lost implementation or engine receipt is represented here.

const Proof = preload("res://src/tests/stadium_npc_yard_two_installed_proof.gd")
const PREFIX: String = "npc:AY-02:r1:"
var _seen: Dictionary = {}
var _failures: int = 0


func _ready() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Proof.MAP))
	# R10 permits one authenticated original-file overlay; the original map stays immutable.
	var overlay: Dictionary = manifest.material_schema_epoch_scope.original_overlay
	var retained_path: String = "src/presentation/stadium/stadium_npc_retained_geometry.gd"
	var files_ok: bool = overlay.size() == 1 and overlay.has(retained_path)
	var uid_count: int = 0
	for path: String in manifest.files:
		var expected: Dictionary = manifest.files[path]
		if path == retained_path and overlay.has(path):
			var delta: Dictionary = overlay[path]
			files_ok = files_ok and delta.before == expected \
				and delta.after.mode == expected.mode \
				and FileAccess.get_file_as_bytes("res://" + path).size() == delta.after.bytes
			expected = delta.after
		files_ok = (
			files_ok and FileAccess.get_sha256("res://" + path) == expected.sha256
		)
		uid_count += int(path.ends_with(".uid"))
	_assert(
		"SRC-01/original_files",
		files_ok and manifest.files.size() == 2255,
		"All authenticated original file bytes remain unchanged"
	)
	_assert(
		"SRC-01/original_uids",
		files_ok and uid_count == 98,
		"All 98 original UIDs retained; Python guard rejects additions"
	)
	var definition: Dictionary = StadiumNpcYardTwoCandidateV1.definition()
	_assert(
		"SRC-02/candidate",
		(
			StadiumNpcYardTwoCandidateV1.key(definition)
			== "fb15cd5c23ab70e3498e0888aea409e9f03b4dedbac59e8c507fc70014327041"
		),
		"Exact C"
	)
	_assert(
		"SRC-02/subject",
		(
			StadiumNpcManifest.payload_key(definition)
			== "d5f2d743639135f4feb51447905a2c17040b6594edadaa83702e25864d2e8dd9"
		),
		"Exact S"
	)
	_assert(
		"SRC-02/raw",
		(
			FileAccess.get_sha256("res://src/tests/fixtures/npc_yard_two_r1_authoring_source.json")
			== "08695950bfe72b92dd09532ee9d031c7dc63975f6f4ff87162b3fea4b43bef2e"
		),
		"Raw unchanged"
	)
	_assert(
		"SRC-02/certificates", definition.environment_certificates.is_empty(), "No certificates"
	)
	var actual: StadiumNpcYardTwoV1 = StadiumNpcYardTwoV1.build()
	var oracle: StadiumYardTwoProperty = StadiumYardTwoStudy.build()
	_assert(
		"SRC-03/original_correspondence",
		(
			actual != null
			and oracle != null
			and StadiumNpcYardTwoCorrespondence.matches(actual, oracle)
		),
		"Independent old factory oracle"
	)
	if actual != null and oracle != null:
		var field_ok: bool = true
		for key: String in StadiumNpcYardV1.FIELD:
			field_ok = field_ok and typeof(actual.field.get(key)) == typeof(oracle.field.get(key))
			field_ok = field_ok and actual.field.get(key) == oracle.field.get(key)
		_assert("SRC-03/typed_field", field_ok, "Exact original field values/types")
		_assert(
			"SRC-03/boundary",
			actual.get_node("BoundaryGraph").get_child_count() == 6,
			"Six genuine retained joined slabs"
		)
		var identities: bool = actual.objects.size() == 4
		for row: Dictionary in definition.instances:
			var model: Node3D = actual.objects[row.instance]
			identities = identities and model.get_meta("npc_instance", "") == row.instance
			identities = identities and model.get_meta("npc_site", "") == row.site
			identities = identities and model.get_meta("npc_host", "") == row.host
			identities = identities and not model.has_meta("owned_copy")
		_assert("SRC-04/four_namespaces", identities, "Four exact NPC copies, no human inventory")
		_assert(
			"SRC-04/no_entitlements",
			ClubAssetLedger.from_data(definition, 0, []) == null,
			"NPC compatibility grants no human stock"
		)
		_configured(oracle)
	if actual != null:
		actual.free()
	if oracle != null:
		oracle.free()
	var authority_ok: bool = true
	for path: String in manifest.runtime_files:
		var source: String = FileAccess.get_file_as_string("res://" + path)
		for forbidden: String in [
			"StadiumYardTwoStudy",
			"StadiumStarterModels",
			"StadiumSeatingModels",
			"StadiumCatalog",
			"FileAccess."
		]:
			authority_ok = authority_ok and not source.contains(forbidden)
	_assert("SRC-06/closed_authority", authority_ok, "New runtime has no mutable authoring oracle")
	_assert(
		"SRC-07/public_closed", Proof.public_closed(), "Unchanged registry/save/report selectors"
	)
	Proof.finish(self, "source")


func _configured(oracle: StadiumYardTwoProperty) -> void:
	var property: StadiumNpcYardTwoPropertyV1 = StadiumNpcYardTwoRuntimeV1._construct(null)
	var bound: bool = (
		property != null and StadiumNpcYardTwoRuntimeV1._bind_components(null, property)
	)
	var receiver: StadiumPitchReceiver = StadiumPitchReceiver.new()
	var original: Node3D = oracle.objects[StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY"]
	var configured: bool = receiver.configure(original)
	_assert(
		"SRC-05/independent_configure",
		bound and configured,
		"Actual new and original receiver bind operations both succeed"
	)
	if bound and configured:
		var chair: Node3D = property.objects[PREFIX + "RECEIVER-PRIMARY"]
		var policy: bool = chair.process_mode == Node.PROCESS_MODE_PAUSABLE
		policy = policy and chair.get_node("Collision").get_child_count() == 10
		for body: StaticBody3D in chair.get_node("Collision").get_children():
			policy = policy and body.collision_layer == 17 and body.collision_mask == 0
			policy = policy and body.get_meta("owned_copy", "") == PREFIX + "RECEIVER-PRIMARY"
		_assert("SRC-05/physical_policy", policy, "Ten original PAUSABLE solids/layer17/mask0")
		_assert(
			"SRC-05/configured_correspondence",
			(
				StadiumNpcYardTwoCorrespondence._policies(property.construction, oracle, true)
				and (
					var_to_bytes(
						StadiumNpcYardTwoCorrespondence.snapshot(property.construction, true)
					)
					== var_to_bytes(StadiumNpcYardTwoCorrespondence.snapshot(oracle, true))
				)
			),
			"Configured state is compared rather than skipped"
		)
	receiver.free()
	if property != null:
		property.free()


func _assert(id: String, ok: bool, detail: String) -> void:
	Proof.record(self, id, ok, detail)

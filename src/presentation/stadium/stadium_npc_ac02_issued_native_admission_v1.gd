class_name StadiumNpcAc02IssuedNativeAdmissionV1
extends RefCounted
## Call-local eligibility observation inside the unchanged recursive geometry comparison.
## It never reflects, copies geometry, stores Resource aliases, or skips an original read.
const MAX_VISITS: int = 65536
const NATIVE_RESOURCES: Array[String] = ["ArrayMesh", "BoxMesh", "CylinderMesh", "CapsuleMesh",
	"SphereMesh", "StandardMaterial3D", "BoxShape3D", "ConvexPolygonShape3D",
	"CylinderShape3D", "CapsuleShape3D", "SphereShape3D", "PhysicsMaterial"]
var eligible: bool = true
var reason: String = ""
var visits: int = 0
var resource_visits: int = 0
var expected_roots: int = 0
var historical_complete: bool = false


func add_root(_property: StadiumNpcPublicProperty) -> void:
	expected_roots += 1
	if expected_roots != 1:
		reject("unexpected-reference-count")


func observe(value: Object) -> void:
	visits += 1
	if visits > MAX_VISITS:
		reject("native-observation-budget")
		return
	if value == null:
		return
	if not is_instance_valid(value):
		reject("invalid-observed-handle")
		return
	if value is Resource:
		resource_visits += 1
		if value.get_script() != null or value.get_class() not in NATIVE_RESOURCES:
			reject("unknown-or-scripted-resource")


func plain(value: Variant) -> void:
	# Original _content already walks containers and observes every Resource value.
	# This hook sees dictionary keys only, not a new generic raw-container walk.
	if value is Object or value is Callable or value is Signal or value is RID:
		reject("opaque-geometry-key")


func reject(why: String) -> void:
	if eligible:
		eligible = false
		reason = why


func complete(original_result: bool) -> void:
	historical_complete = original_result and expected_roots == 1 and resource_visits > 0


func admitted() -> bool:
	return historical_complete and eligible and visits <= MAX_VISITS

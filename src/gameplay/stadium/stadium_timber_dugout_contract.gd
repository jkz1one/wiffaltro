class_name StadiumTimberDugoutContract
extends RefCounted
## Exact CI timber geometry. The narrow Pool Party adapter uses real sphere sweeps.

const VERSION: int = 1
const ID: String = "ST032-ROOFLESS-TIMBER-CI-v1"
const RUNTIME_ADAPTER: String = "ST032_SPHERE_SWEEP_v1"
const ENVELOPE: AABB = AABB(Vector3(-3, 0, 0), Vector3(6, 1.30, 2.65))
const INTERIOR: AABB = AABB(Vector3(-3, 0, 0), Vector3(6, 1.30, 2.40))
const OPENING: AABB = AABB(Vector3(-1, 0, 0), Vector3(2, 1.30, 0))
const FRONT_HEIGHT: float = 1.20
const ENTRY_HEIGHT: float = 1.30
const EPS: float = StadiumRecipeBoundary.EPS


static func placement(left: bool) -> Transform3D:
	return StadiumDugoutRecipe.placement(left)


static func panels(left: bool) -> Array[Dictionary]:
	return StadiumDugoutRecipe.panels(left)


static func interface(left: bool) -> Dictionary:
	var site: String = "DUGOUT-L" if left else "DUGOUT-R"
	return {
		"id": ID,
		"version": VERSION,
		"item": "ST-032",
		"site": site,
		"placement": placement(left),
		"envelope": ENVELOPE,
		"interior": INTERIOR,
		"opening": OPENING,
		"interior_navigable": false,
		"roof": false,
		"tunnel_host": false,
		"rail_interval": Vector2(10, 16),
		"opening_interval": Vector2(12, 14),
		"seam_owner": site,
		"front_height": FRONT_HEIGHT,
		"front_surfaces": front_surfaces(left),
		"entry_height": ENTRY_HEIGHT,
		"entry_role": "DUGOUT_OPENING_DEAD",
		"above_entry_role": "DUGOUT_EXTERIOR_DEAD",
		"front_role": "DUGOUT_FACE_LIVE",
		"above_front_role": "SIDE_EXIT_DEAD",
		"same_time_priority": ["solid", "entry"],
		"remaining_side_panels": 16,
		"displaced_panels_stored": 3,
		"runtime_adapter": RUNTIME_ADAPTER,
		"authority": "CI_WORKING_AUTHORED_CANDIDATE",
		"source_sha256": StadiumPoolPartyAssetIntegrity.source_sha256()
	}


static func front_region(s: float, height: float) -> String:
	# Descriptive point-region classifier only; runtime uses StadiumTimberDugoutBoundary.event.
	# The sphere sweep, not this helper, owns physical jamb and closed-seam precedence.
	if not is_finite(s) or not is_finite(height) or height < 0 or s < 10 or s > 16:
		return ""
	if s <= 12 or s >= 14:
		return "DUGOUT_FACE_LIVE" if height <= FRONT_HEIGHT else "SIDE_EXIT_DEAD"
	return "DUGOUT_OPENING_DEAD" if height <= ENTRY_HEIGHT else "DUGOUT_EXTERIOR_DEAD"


static func valid_binding(root: Node3D, left: bool, record: Variant) -> bool:
	if (
		root == null
		or not record is Dictionary
		or record != interface(left)
		or String(record.get("source_sha256", "")).length() != 64
	):
		return false
	var reference: Node3D = StadiumTimberDugoutModels.create()
	reference.transform = placement(left)
	var valid: bool = StadiumPoolPartyAssetIntegrity.same_tree(root, reference)
	reference.free()
	return valid


static func front_surfaces(left: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for side: int in [-1, 1]:
		var near_home: bool = left == (side == -1)
		result.append(
			{
				"surface_id": "FrontBarrier%d" % side,
				"role": "DUGOUT_FACE_LIVE",
				"rail_interval": Vector2(10, 12) if near_home else Vector2(14, 16),
				"local_bounds": AABB(Vector3(side * 2 - 1, 0, 0), Vector3(2, 1.20, 0.18))
			}
		)
	return result

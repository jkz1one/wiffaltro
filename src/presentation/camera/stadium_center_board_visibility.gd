class_name StadiumCenterBoardVisibility
extends StadiumHeightCameraVisibility
## Candidate-specific exact box proxies. Existing property-board handling is unchanged.

const POLICY: String = "raised-center-obb-render-ball-same-side-defense-v4"
# BattedBallBody's unchanged normal mesh is larger than its 0.0365 m physics sphere.
# Keep the whole 0.075 m rendered sphere clear, plus 5 mm numerical/edge tolerance.
const BALL_RENDER_RADIUS: float = 0.075
const BALL_EDGE_TOLERANCE: float = 0.005
const LOS_MARGIN: float = BALL_RENDER_RADIUS + BALL_EDGE_TOLERANCE
var _candidate_meshes: Array[Dictionary] = []


func configure(geometry: Node) -> void:
	_candidate_meshes.clear()
	super.configure(geometry)
	var property: StadiumCenterBoardProperty = geometry.get_node_or_null("HomeProperty") \
		as StadiumCenterBoardProperty
	if property == null or not is_instance_valid(property.candidate):
		return
	# Each authored box retains its real orientation, including diagonal braces.
	# World AABBs fill the empty triangles beside those braces with false solids.
	_collect_candidate(property.candidate.get_node("Visual"), property.candidate)


func _collect_candidate(node: Node, root: Node3D) -> void:
	if node is MeshInstance3D and node.mesh != null and node.visible:
		_candidate_meshes.append({"path": String(root.get_path_to(node)),
			"bounds": node.get_aabb(), "pose": node.global_transform,
			"inverse": node.global_transform.affine_inverse()})
	for child: Node in node.get_children():
		_collect_candidate(child, root)


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	return super._blocked(camera, ball) or not candidate_blocker(camera, ball).is_empty()


func candidate_blocker(camera: Vector3, ball: Vector3, margin: float = LOS_MARGIN) -> Dictionary:
	for proxy: Dictionary in _candidate_meshes:
		if proxy_intersects(proxy, camera, ball, margin):
			return proxy
	return {}


static func proxy_intersects(proxy: Dictionary, camera: Vector3, ball: Vector3,
	margin: float = LOS_MARGIN) -> bool:
	var bounds: AABB = proxy.bounds
	var local_ball: Vector3 = proxy.inverse * ball
	var local_camera: Vector3 = proxy.inverse * camera
	# These candidate transforms are rigid, so local padding remains in meters.
	# Do not shrink below the ball silhouette near a support; real visual overlap
	# must remain a blocked ray even though the support is not a gameplay body.
	var padded: AABB = bounds.grow(margin)
	return padded.intersects_segment(local_camera, local_ball) != null

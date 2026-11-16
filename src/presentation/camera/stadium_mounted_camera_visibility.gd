class_name StadiumMountedCameraVisibility
extends StadiumHeightCameraVisibility
## Exact catalog1 center policy; all other collections retain legacy camera behavior.

const POLICY: String = "raised-center-obb-render-ball-same-side-defense-v4"
const BALL_RENDER_RADIUS: float = 0.075
const BALL_EDGE_TOLERANCE: float = 0.005
const LOS_MARGIN: float = BALL_RENDER_RADIUS + BALL_EDGE_TOLERANCE
var _mounted_meshes: Array[Dictionary] = []


func configure(geometry: Node) -> void:
	_mounted_meshes.clear()
	super.configure(geometry)


func _collect(node: Node, allow_upright: bool = true) -> void:
	if node.name == &"Visual" and StadiumScoreboardAssembly.is_center_root(node.get_parent()):
		_collect_mount(node, node.get_parent())
		return
	super._collect(node, allow_upright)


func _collect_mount(node: Node, root: Node3D) -> void:
	if node is MeshInstance3D and node.mesh is BoxMesh and node.visible:
		_mounted_meshes.append({"root": root.get_instance_id(), "node": node.get_instance_id(),
			"parent": node.get_parent().get_instance_id(), "mesh": node.mesh.get_instance_id(),
			"path": String(root.get_path_to(node)), "bounds": node.get_aabb(),
			"pose": node.global_transform, "inverse": node.global_transform.affine_inverse()})
	for child: Node in node.get_children():
		_collect_mount(child, root)


func _blocked(camera: Vector3, ball: Vector3) -> bool:
	return super._blocked(camera, ball) or not mounted_blocker(camera, ball).is_empty()


func mounted_blocker(camera: Vector3, ball: Vector3) -> Dictionary:
	for proxy: Dictionary in _mounted_meshes:
		if proxy_intersects(proxy, camera, ball):
			return proxy
	return {}


static func proxy_intersects(proxy: Dictionary, camera: Vector3, ball: Vector3) -> bool:
	# Rigid local boxes retain diagonal-brace gaps; the full rendered sphere margin never shrinks.
	var bounds: AABB = proxy.bounds
	return bounds.grow(LOS_MARGIN).intersects_segment(
		proxy.inverse * camera, proxy.inverse * ball) != null

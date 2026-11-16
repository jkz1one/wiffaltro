class_name StadiumWallRenderQuality
extends RefCounted
## Viewport-lifetime antialiasing for fine wall detail, never a persistent graphics setting.

const META: StringName = &"wiffaltro_wall_msaa"


static func attach(owner: Node3D) -> bool:
	if owner == null or not owner.is_inside_tree() or DisplayServer.get_name() == "headless":
		return false
	var viewport: Viewport = owner.get_viewport()
	var state: Dictionary = viewport.get_meta(META, {})
	var id: int = owner.get_instance_id()
	if state.is_empty():
		state = {"original": int(viewport.msaa_3d), "owners": {},
			"changed": viewport.msaa_3d < Viewport.MSAA_4X}
		if state.changed:
			viewport.msaa_3d = Viewport.MSAA_4X
	if state.owners.has(id):
		return false
	state.owners[id] = true
	viewport.set_meta(META, state)
	owner.tree_exiting.connect(_release.bind(weakref(viewport), id), CONNECT_ONE_SHOT)
	return true


static func _release(reference: WeakRef, id: int) -> void:
	var viewport: Viewport = reference.get_ref()
	if viewport == null or not viewport.has_meta(META):
		return
	var state: Dictionary = viewport.get_meta(META)
	if not state.owners.has(id):
		return
	state.owners.erase(id)
	if not state.owners.is_empty():
		viewport.set_meta(META, state)
		return
	if state.changed and viewport.msaa_3d == Viewport.MSAA_4X:
		viewport.set("msaa_3d", state.original)
	viewport.remove_meta(META)

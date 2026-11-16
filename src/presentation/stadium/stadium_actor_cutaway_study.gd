class_name StadiumActorCutawayStudy
extends RefCounted
## Reusable Working presentation-only study. Grand I is its sole opt-in caller.
## Triangle caches support rigid actors with immutable Mesh resources only. A replaced
## Mesh reference rebuilds automatically; in-place edits/skinning/deformation require
## explicit cache invalidation/rebuild before broader reuse. No skeletal support is claimed.

const VERSION: int = 1
var frozen: bool = false
var entries: Dictionary = {}
var last_hits: Array[Dictionary] = []


func apply(batter: PlayerAvatar, bat: BatActor, camera: Camera3D, ball: Node3D, live: bool) -> void:
	# Paired contrast readback may toggle ball visibility. It must never toggle this policy.
	if frozen:
		return
	last_hits.clear()
	if (
		not live
		or not is_instance_valid(camera)
		or not is_instance_valid(ball)
		or not is_instance_valid(batter)
		or batter.role != PlayerAvatar.Role.BATTER
	):
		restore_all()
		return
	var actors: Array[Node3D] = [batter]
	if is_instance_valid(bat):
		actors.append(bat)
	var active: Dictionary = {}
	for actor: Node3D in actors:
		var meshes: Array[Node] = actor.find_children("*", "MeshInstance3D", true, false)
		var obstructs: bool = false
		for member: Node in meshes:
			var mesh: MeshInstance3D = member as MeshInstance3D
			if not mesh.is_visible_in_tree() or mesh.mesh == null:
				continue
			var id: int = mesh.get_instance_id()
			active[id] = true
			_sync(mesh)
			if not entries.has(id):
				continue
			var hit: Dictionary = intersection(mesh, camera.global_position, ball.global_position)
			if not hit.is_empty():
				obstructs = true
				last_hits.append(
					{
						"actor": actor.get_instance_id(),
						"mesh": id,
						"path": String(mesh.get_path()),
						"position": hit.position,
						"face_index": hit.face_index
					}
				)
		for member: Node in meshes:
			var mesh: MeshInstance3D = member as MeshInstance3D
			var id: int = mesh.get_instance_id()
			if not active.has(id) or not entries.has(id):
				continue
			if obstructs:
				mesh.material_override = entries[id].fade_material
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				entries[id].faded = true
			else:
				_restore(entries[id])
	# Remove references to replaced, hidden, or removed actors and restore surviving originals.
	for id: int in entries.keys():
		if not active.has(id):
			_restore(entries[id])
			entries.erase(id)


func _sync(mesh: MeshInstance3D) -> void:
	var id: int = mesh.get_instance_id()
	if entries.has(id):
		var entry: Dictionary = entries[id]
		var expected: Material = entry.fade_material if entry.faded else entry.original_material
		if mesh.material_override == expected and mesh.mesh == entry.source_mesh:
			# External settings while unfaded become the next restore baseline. While faded,
			# preserve an explicit replacement shadow mode rather than remembering stale state.
			if not entry.faded or mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				entry.shadow = mesh.cast_shadow
			entry.transparency = mesh.transparency
			return
		# Reconfiguration supplied another material/mesh; never restore a stale material over it.
		_restore(entry)
		entries.erase(id)
	var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
	if material == null and mesh.mesh.get_surface_count() == 1:
		material = mesh.get_active_material(0) as StandardMaterial3D
	if material == null:
		return
	var faded: StandardMaterial3D = material.duplicate() as StandardMaterial3D
	var color: Color = faded.albedo_color
	color.a = minf(color.a, StadiumReceiverVisibility.FADED_ALPHA)
	faded.albedo_color = color
	faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	entries[id] = {
		"mesh": weakref(mesh),
		"source_mesh": mesh.mesh,
		"triangles": mesh.mesh.generate_triangle_mesh(),
		"original_material": mesh.material_override,
		"shadow": mesh.cast_shadow,
		"transparency": mesh.transparency,
		"fade_material": faded,
		"faded": false
	}


func intersection(mesh: MeshInstance3D, from: Vector3, to: Vector3) -> Dictionary:
	var id: int = mesh.get_instance_id()
	if not entries.has(id) or not mesh.is_visible_in_tree():
		return {}
	var inverse: Transform3D = mesh.global_transform.affine_inverse()
	var local_from: Vector3 = inverse * from
	var local_to: Vector3 = inverse * to
	if mesh.get_aabb().intersects_segment(local_from, local_to) == null:
		return {}
	var triangles: TriangleMesh = entries[id].triangles
	if triangles == null:
		return {}
	var hit: Dictionary = triangles.intersect_segment(local_from, local_to)
	if not hit.is_empty():
		hit.position = mesh.global_transform * hit.position
	return hit


func restore_all() -> void:
	for entry: Dictionary in entries.values():
		_restore(entry)
	entries.clear()
	last_hits.clear()


func _restore(entry: Dictionary) -> void:
	var mesh: MeshInstance3D = entry.mesh.get_ref() as MeshInstance3D
	if mesh == null or not entry.faded:
		return
	if mesh.material_override == entry.fade_material:
		mesh.material_override = entry.original_material
	# Only revert the state still owned by this helper. Never overwrite external replacements.
	if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		mesh.cast_shadow = entry.shadow
	entry.faded = false

class_name StadiumPoolModelsV2
extends RefCounted
## Private v2 water descriptor wrapper. Original visual and solid subtrees are untouched.


static func create(role: String = StadiumPoolContract.SCENERY) -> Node3D:
	var root: Node3D = StadiumPoolModels.create(role)
	if root == null or role == StadiumPoolContract.SCENERY:
		return root
	var legacy: Node = root.get_node_or_null(StadiumPoolContract.WATER_VOLUME_ID)
	if legacy == null:
		root.free()
		return null
	root.remove_child(legacy)
	legacy.free()
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	if source.length() != 64:
		root.free()
		return null
	root.set_meta("geometry_version", StadiumPoolInteriorV2.VERSION)
	root.set_meta("model_id", StadiumPoolInteriorV2.MODEL_ID)
	root.set_meta("water_geometry_id", StadiumPoolInteriorV2.ID)
	root.set_meta("water_source_sha256", source)
	var volume: Node3D = Node3D.new()
	volume.name = StadiumPoolInteriorV2.VOLUME_ID
	volume.set_meta("volume_id", StadiumPoolInteriorV2.VOLUME_ID)
	volume.set_meta("volume_role", StadiumPoolInteriorV2.VOLUME_ROLE)
	volume.set_meta("water_award_active", false)
	volume.set_meta("runtime_adapter", "PRIVATE_GUARD_REQUIRES_SEPARATE_BINDING")
	volume.set_meta("descriptor", StadiumPoolInteriorV2.descriptor(source))
	root.add_child(volume)
	return root

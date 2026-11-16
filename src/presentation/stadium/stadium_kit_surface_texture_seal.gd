class_name StadiumKitSurfaceTextureSeal
extends RefCounted
## Candidate3-only deep seal for the exact deterministic factory texture.
## ImageTexture.get_image() returns a copy, not stable Resource identity. Keep the
## actual texture/backing identities and compare exact native descriptors/full bytes.
## No readback is added to the issued hot-action contract or historical candidates.

var _owner: WeakRef
var _property: WeakRef
var _texture: ImageTexture
var _source: Image
var _image: Dictionary = {}


static func issue(
	owner: StadiumSurfaceNightRuntime, property: StadiumPropertyGeometry
) -> StadiumKitSurfaceTextureSeal:
	if (
		not is_instance_valid(owner)
		or owner.get_script() != StadiumSurfaceNightRuntime
		or not is_instance_valid(property)
		or property.get_script() != StadiumPropertyGeometry
		or not owner._kit_texture_issuance_allowed(property)
	):
		return null
	# Access the existing factory object without invoking texture(), which could
	# create a new value and accidentally adopt pre-admission replacement state.
	var state: Dictionary = StadiumSurfaceTexture.issued_texture_state(
		StadiumSurfaceTexture._texture
	)
	if state.is_empty():
		return null
	var result: StadiumKitSurfaceTextureSeal = StadiumKitSurfaceTextureSeal.new()
	result._owner = weakref(owner)
	result._property = weakref(property)
	result._texture = state.texture
	result._source = state.source
	result._image = state.image.duplicate(true)
	result._image.make_read_only()
	return result if result._content_intact() else null


func matches(property: StadiumPropertyGeometry) -> bool:
	var owner: StadiumSurfaceNightRuntime = _owner.get_ref() if _owner != null else null
	return (
		get_script() == StadiumKitSurfaceTextureSeal
		and is_instance_valid(owner)
		and owner.get_script() == StadiumSurfaceNightRuntime
		and is_instance_valid(property)
		and _property != null
		and is_same(_property.get_ref(), property)
		and is_same(owner._property, property)
		and is_same(owner._kit_texture_seal, self)
	)


func capture_allowed(property: StadiumPropertyGeometry) -> bool:
	if not matches(property):
		return false
	var owner: StadiumSurfaceNightRuntime = _owner.get_ref()
	return (
		owner._phase == StadiumSurfaceNightRuntime.Phase.CONFIGURED
		and not owner._restoring
		and not owner._kit_issue_ever
		and property.get_parent() == null
	)


func intact(property: StadiumPropertyGeometry) -> bool:
	# Data checks remain available during authorized restoration. Ownership/phase
	# authority is checked by the existing enclosing lifecycle, not recursively here.
	return matches(property) and _content_intact()


func _content_intact() -> bool:
	if not is_instance_valid(_texture) or not is_instance_valid(_source) or _image.is_empty():
		return false
	var issued: Dictionary = StadiumSurfaceTexture.issued_texture_state(_texture)
	if (
		issued.is_empty()
		or not is_same(issued.source, _source)
		or issued.image != _image
		or _texture.get_meta_list() != [&"source_image"]
		or not _texture.has_meta(&"source_image")
		or not is_same(_texture.get_meta(&"source_image"), _source)
		or StadiumSurfaceTexture.image_content(_source) != _image
		or _texture.get_width() != _image.width
		or _texture.get_height() != _image.height
		or _texture.get_format() != _image.format
	):
		return false
	# Missing native readback fails closed; backing metadata is not a GPU proof.
	var current: Image = _texture.get_image()
	return is_instance_valid(current) and StadiumSurfaceTexture.image_content(current) == _image


func capture_resource(
	resource: Resource,
	rows: Array[Dictionary],
	seen: Dictionary,
	depth: int = 0,
	complete_source_materials: bool = true
) -> bool:
	var property: StadiumPropertyGeometry = _property.get_ref() if _property != null else null
	if not capture_allowed(property) or not is_instance_valid(resource):
		return false
	if seen.has(resource.get_instance_id()):
		return true
	if depth > 8:
		return false
	seen[resource.get_instance_id()] = true
	if complete_source_materials and resource is StandardMaterial3D:
		var state: Dictionary = StadiumFloodlightOwnedModels._source_material_state(resource)
		for value: Variant in state.values:
			if (
				value is Resource
				and not capture_resource(value, rows, seen, depth + 1, complete_source_materials)
			):
				return false
		rows.append(
			{
				"resource": resource,
				"keys": state.keys,
				"values": state.values,
				"metadata": state.metadata
			}
		)
		return true
	return _capture_resource_properties(resource, rows, seen, depth, complete_source_materials)


func _capture_resource_properties(
	resource: Resource, rows: Array[Dictionary], seen: Dictionary,
	depth: int, complete_source_materials: bool
) -> bool:
	var known: bool = is_same(resource, _texture)
	if known and not _content_intact():
		return false
	var keys: Array[StringName] = []
	var values: Array = []
	for description: Dictionary in resource.get_property_list():
		if (
			(int(description.usage) & PROPERTY_USAGE_STORAGE) == 0
			or description.name in ["resource_name", "resource_path", "resource_local_to_scene"]
		):
			continue
		if known and description.name == &"image":
			continue  # Only this issued texture's ephemeral getter wrapper is replaced.
		var value: Variant = resource.get(description.name)
		keys.append(StringName(description.name))
		values.append(value.duplicate(true) if value is Array or value is Dictionary else value)
		if (
			value is Resource
			and not capture_resource(value, rows, seen, depth + 1, complete_source_materials)
		):
			return false
	var row: Dictionary = {"resource": resource, "keys": keys, "values": values}
	if known:
		row["kit_surface_texture"] = self
	rows.append(row)
	return true

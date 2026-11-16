class_name StadiumWaterfallMotionOwner
extends Node
## Owned CPU phase, not shader TIME or machine time. Integration must supply the pitch gate.
## Only the eight explicit phase uniforms may change; foreign state is never overwritten.
const CYCLES_PER_SECOND: float = 0.15
const NODE_FIELDS: Array[String] = [
	"transform",
	"visible",
	"top_level",
	"process_mode",
	"layers",
	"transparency",
	"material_overlay",
	"cast_shadow",
	"extra_cull_margin",
	"ignore_occlusion_culling",
	"lod_bias",
	"gi_mode",
	"visibility_range_begin",
	"visibility_range_begin_margin",
	"visibility_range_end",
	"visibility_range_end_margin",
	"visibility_range_fade_mode",
	"sorting_offset",
	"sorting_use_aabb_center",
	"custom_aabb"
]

var retired: bool = false
var phase: float = 0.0
var _model: Node3D
var _parent: Node
var _pose: Transform3D
var _copy: String
var _rows: Array[Dictionary] = []
var _meta: Dictionary = {}


static func install(parent: Node, model: Node3D) -> StadiumWaterfallMotionOwner:
	if (
		parent == null
		or model == null
		or model.get_parent() != parent
		or not StadiumWaterfallMotionModels.valid(model, 0.0)
	):
		return null
	var owner: StadiumWaterfallMotionOwner = StadiumWaterfallMotionOwner.new()
	owner._model = model
	owner._parent = parent
	owner._pose = model.transform
	owner._copy = model.get_meta("owned_copy", "")
	for key: String in [
		"stadium_item",
		"working_geometry_only",
		"geometry_version",
		"obstacle_units",
		"night_qualified",
		"water_motion_version"
	]:
		owner._meta[key] = model.get_meta(key)
	for id: String in StadiumWaterfallModels.PARTS:
		var part: MeshInstance3D = model.get_node(id)
		var water: bool = id in StadiumWaterfallMotionModels.WATER
		var shader: Shader = (part.material_override as ShaderMaterial).shader if water else null
		var fields: Dictionary = {}
		for field: String in NODE_FIELDS:
			fields[field] = part.get(field)
		owner._rows.append(
			{
				"id": id,
				"part": part,
				"mesh": part.mesh,
				"material": part.material_override,
				"shader": shader,
				"water": water,
				"fields": fields,
				"mesh_fields": _resource_fields(part.mesh),
				"material_fields": _resource_fields(part.material_override, water),
				"shader_fields": _resource_fields(shader) if water else {}
			}
		)
	parent.add_child(owner)
	return owner


func intact() -> bool:
	if (
		retired
		or not is_instance_valid(_model)
		or not is_instance_valid(_parent)
		or get_parent() != _parent
		or _model.get_parent() != _parent
		or _model.is_queued_for_deletion()
		or _model.transform != _pose
		or _model.get_meta("owned_copy", "") != _copy
		or not StadiumWaterfallModels._clean(_model)
		or _model.get_child_count() != _rows.size()
		or not is_finite(phase)
		or phase < 0
		or phase >= 1
	):
		return false
	for key: String in _meta:
		if (
			typeof(_model.get_meta(key, null)) != typeof(_meta[key])
			or _model.get_meta(key, null) != _meta[key]
		):
			return false
	for row: Dictionary in _rows:
		var part: MeshInstance3D = row.part
		if (
			not is_instance_valid(part)
			or part.get_parent() != _model
			or _model.get_node_or_null(row.id) != part
			or not StadiumWaterfallModels._clean(part)
			or part.get_child_count() != 0
			or part.mesh != row.mesh
			or part.material_override != row.material
			or part.get_surface_override_material(0) != null
			or not _fields_equal(part, row.fields)
			or not _fields_equal(row.mesh, row.mesh_fields)
			or not _fields_equal(row.material, row.material_fields)
		):
			return false
		if (
			row.water
			and (
				row.material.shader != row.shader
				or not _fields_equal(row.shader, row.shader_fields)
				or row.material.get_shader_parameter("phase") != phase
			)
		):
			return false
	return true


static func _resource_fields(resource: Resource, moving_water: bool = false) -> Dictionary:
	# Capture canonical persisted settings once AFTER strict factory validation.
	# Avoid allocating 13 materials and 21 nodes twice per visual frame.
	var result: Dictionary = {"script": resource.get_script()}
	for property: Dictionary in resource.get_property_list():
		if (
			not (int(property.usage) & PROPERTY_USAGE_STORAGE)
			or property.name in ["resource_name", "resource_local_to_scene"]
			or (moving_water and property.name == "shader_parameter/phase")
		):
			continue
		result[property.name] = resource.get(property.name)
	return result


static func _fields_equal(object: Object, fields: Dictionary) -> bool:
	if not is_instance_valid(object):
		return false
	for key: String in fields:
		var value: Variant = object.get(key)
		if typeof(value) != typeof(fields[key]) or value != fields[key]:
			return false
	return true


func advance(delta: float, actionable_pitch_or_flight: bool, paused: bool) -> bool:
	if not intact() or not is_finite(delta) or delta < 0:
		retire()
		return false
	if (
		delta > 0.25
		or paused
		or actionable_pitch_or_flight
		or (is_inside_tree() and get_tree().paused)
	):
		return true
	return _write(fposmod(phase + delta * CYCLES_PER_SECOND, 1.0))


func reset() -> bool:
	if not intact():
		retire()
		return false
	return _write(0.0)


func _write(value: float) -> bool:
	phase = value
	for row: Dictionary in _rows:
		if row.water:
			row.material.set_shader_parameter("phase", phase)
	if not intact():
		retire()
		return false
	return true


func retire() -> void:
	retired = true
	set_process(false)

class_name StadiumPropertyGeometry
extends Node3D
## Shared full-scale property/asset assembly for preview and isolated runtime validation.
## Production activation still requires a bound season/physical-replay layout snapshot.

const SOURCE_OPERATIONS_1: GDScript = preload(
	"res://src/presentation/stadium/stadium_property_geometry_operations_1.gd"
)

const SOURCE_OPERATIONS_2: GDScript = preload(
	"res://src/presentation/stadium/stadium_property_geometry_operations_2.gd"
)

const SOURCE_OPERATIONS_3: GDScript = preload(
	"res://src/presentation/stadium/stadium_property_geometry_operations_3.gd"
)

var objects: Dictionary = {}
var field: FieldDefinition
var tier: String
var _ground_props_family: bool = false
var _props_live: bool = true
var _issued_props: Dictionary = {}
var _issued_contacts: Dictionary = {}
var _props_ball: WeakRef
var _props_play: BallPlayState
var _props_resolver: BallPlayResolver
var _props_world: Transform3D
var _props_ball_parent: Node
var _props_lab: WeakRef
var _props_state: MatchState
var _props_paid: ClubAssetLedger
var _props_generation: int = -1
var _furnishing_water: Dictionary = {}
var _junk_car_traps: Dictionary = {}
var _waterfall_traps: Dictionary = {}
# Fixed property infrastructure is sealed separately; it never creates a paid copy.
var _infrastructure: Array[Dictionary] = []
var _outer_ground: Array[Node3D] = []
var _waterfall_animation_copies: Array[String] = []
var _waterfall_animation: StadiumWaterfallAnimationLease
var _lighting_preview: StadiumLightingKitPreviewRuntime
var _lighting_fixture_sealed: bool = false


func issued_feature_absent(feature: StringName) -> bool:
	# Historical/unissued properties retain the complete existing handlers. A
	# boolean metadata flag or borrowed authoring preview never grants absence.
	if (
		feature not in [&"live_furnishings", &"salvage_car"]
		or get_script() != StadiumPropertyGeometry
		or not _lighting_fixture_sealed
		or not is_instance_valid(_lighting_preview)
		or _lighting_preview.get_script() != StadiumLightingKitPreviewRuntime
		or _lighting_preview._fixture_owner == null
	):
		return false
	var owner: Variant = _lighting_preview._fixture_owner.get_ref()
	return (
		owner is StadiumSurfaceNightRuntime
		and is_instance_valid(owner)
		and owner.get_script() == StadiumSurfaceNightRuntime
		and owner._kit_lease == _lighting_preview
		and owner._kit_feature_absent(self, feature)
	)


static func construction_target_allowed(target: Node) -> bool:
	return SOURCE_OPERATIONS_1._source_public_construction_target_allowed(target)


func build(property_tier: String, layout: Dictionary, stock: StadiumStock) -> bool:
	return SOURCE_OPERATIONS_1._source_public_build(self, property_tier, layout, stock)


func _build_property_families(
	property_tier: String,
	layout: Dictionary,
	stock: StadiumStock,
	terrain: bool,
	checked: Dictionary
) -> bool:
	return SOURCE_OPERATIONS_1._source_private_build_property_families(self, property_tier, layout, \
		stock, terrain, checked)


func _build_property_models(layout: Dictionary, stock: StadiumStock) -> bool:
	return SOURCE_OPERATIONS_2._source_private_build_property_models(self, layout, stock)


func _appearance(layout: Dictionary, stock: StadiumStock) -> bool:
	return SOURCE_OPERATIONS_2._source_private_appearance(self, layout, stock)


func _apply_family_appearance(layout: Dictionary, stock: StadiumStock) -> bool:
	return SOURCE_OPERATIONS_2._source_private_apply_family_appearance(self, layout, stock)


func _apply_style_appearance(layout: Dictionary, stock: StadiumStock) -> bool:
	return SOURCE_OPERATIONS_2._source_private_apply_style_appearance(self, layout, stock)


func _box(
	id: String, center: Vector3, size: Vector3, color: Color, surface: StringName = &""
) -> Node3D:
	return SOURCE_OPERATIONS_2._source_private_box(self, id, center, size, color, surface)


static func outer_ground_boxes(property_tier: String) -> Array[AABB]:
	return SOURCE_OPERATIONS_2._source_public_outer_ground_boxes(property_tier)


func restore_outer_ground() -> bool:
	return SOURCE_OPERATIONS_2._source_public_restore_outer_ground(self)


func _capture_infrastructure(
	root: Node3D, texture_seal: StadiumKitSurfaceTextureSeal = null
) -> bool:
	# Reuse the existing finite resource-state capture, including unsignaled material values.
	# This extends this property's current-copy guard, without inventing inventory for the pad/ground.
	if (
		root == null
		or root.get_parent() != self
		or (texture_seal != null and not texture_seal.capture_allowed(self))
	):
		return false
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	var rows: Array[Dictionary] = []
	var resources: Array[Dictionary] = []
	var seen: Dictionary = {}
	for node: Node in nodes:
		if not node is Node3D or node.get_script() != null:
			return false
		var fields: Array[StringName] = [&"transform", &"top_level", &"visible", &"process_mode"]
		if node is MeshInstance3D:
			fields.append_array(
				[
					&"mesh",
					&"material_override",
					&"material_overlay",
					&"cast_shadow",
					&"layers",
					&"transparency"
				]
			)
		elif node is StaticBody3D:
			fields.append_array(
				[
					&"collision_layer",
					&"collision_mask",
					&"disable_mode",
					&"physics_material_override",
					&"constant_linear_velocity",
					&"constant_angular_velocity"
				]
			)
		elif node is CollisionShape3D:
			fields.append_array([&"shape", &"disabled"])
		if node is Light3D:
			# Seal every serialized emitter field, including inactive source parameters.
			for property: Dictionary in node.get_property_list():
				var field: StringName = property.name
				if (
					int(property.usage) & PROPERTY_USAGE_STORAGE
					and (
						String(field).begins_with("light_")
						or String(field).begins_with("spot_")
						or String(field).begins_with("shadow_")
						or String(field).begins_with("distance_fade_")
						or field == &"editor_only"
					)
				):
					if not fields.has(field):
						fields.append(field)
		var values: Array = []
		for field_name: StringName in fields:
			var value: Variant = node.get(field_name)
			values.append(value.duplicate(true) if value is Array or value is Dictionary else value)
			if value is Resource:
				if texture_seal != null:
					if not texture_seal.capture_resource(value, resources, seen, 0, true):
						return false
				elif not StadiumFloodlightOwnedModels._capture_resource(
					value, resources, seen, 0, true
				):
					return false
		var metadata: Dictionary = {}
		for key: StringName in node.get_meta_list():
			var value: Variant = node.get_meta(key)
			metadata[key] = (
				value.duplicate(true) if value is Array or value is Dictionary else value
			)
		rows.append(
			{
				"node": node,
				"parent": node.get_parent(),
				"name": node.name,
				"children": node.get_children(),
				"fields": fields,
				"values": values,
				"metadata": metadata
			}
		)
	_infrastructure.append({"root": root, "rows": rows, "resources": resources})
	return true


func _infrastructure_intact() -> bool:
	return SOURCE_OPERATIONS_2._source_private_infrastructure_intact(self)


func _infrastructure_seals_intact() -> bool:
	return SOURCE_OPERATIONS_2._source_private_infrastructure_seals_intact(self)




func _infrastructure_resources_intact(seal: Dictionary) -> bool:
	return SOURCE_OPERATIONS_2._source_private_infrastructure_resources_intact(self, seal)


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	SOURCE_OPERATIONS_2._source_public_bind_ball(self, ball, resolver)


func _ball_contact(body: Node, ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	SOURCE_OPERATIONS_2._source_private_ball_contact(self, body, ball, resolver)


func _receiver_native_contact(
	body: Node, ball: BattedBallBody, resolver: BallPlayResolver, physical_position: Vector3
) -> void:
	SOURCE_OPERATIONS_2._source_private_receiver_native_contact(self, body, ball, resolver, \
		physical_position)


func _apply_ball_contact(
	body: Node, ball: BattedBallBody, resolver: BallPlayResolver, physical_position: Vector3
) -> void:
	SOURCE_OPERATIONS_2._source_private_apply_ball_contact(self, body, ball, resolver, \
		physical_position)


func route_obstacles() -> Array[Dictionary]:
	return SOURCE_OPERATIONS_2._source_public_route_obstacles(self)


func _route_obstacles(models: Dictionary) -> Array[Dictionary]:
	return SOURCE_OPERATIONS_2._source_private_route_obstacles(self, models)


func _prop_bodies(model: Node3D) -> Array:
	return SOURCE_OPERATIONS_2._source_private_prop_bodies(self, model)


func _capture_prop(model: Node3D, placement: Dictionary) -> void:
	SOURCE_OPERATIONS_3._source_private_capture_prop(self, model, placement)


func _retire_props() -> void:
	SOURCE_OPERATIONS_3._source_private_retire_props(self)


func props_intact() -> bool:
	return SOURCE_OPERATIONS_3._source_public_props_intact(self)


func _props_context_intact() -> bool:
	return SOURCE_OPERATIONS_3._source_private_props_context_intact(self)


func _props_inventory_intact(
	ordinary_count: int,
	boundary: StadiumBoundaryOwnedRuntime
) -> bool:
	return SOURCE_OPERATIONS_3._source_private_props_inventory_intact(self, ordinary_count, boundary)


func _issued_props_intact() -> bool:
	return SOURCE_OPERATIONS_3._source_private_issued_props_intact(self)




func _issued_prop_intact(copy: String) -> bool:
	return SOURCE_OPERATIONS_3._source_private_issued_prop_intact(self, copy)




func _issued_prop_collision_intact(copy: String, row: Dictionary) -> bool:
	return SOURCE_OPERATIONS_3._source_private_issued_prop_collision_intact(self, copy, row)




func _issued_prop_bodies_intact(copy: String, row: Dictionary) -> bool:
	return SOURCE_OPERATIONS_3._source_private_issued_prop_bodies_intact(self, copy, row)


func bind_props_context(lab: PitchBatLab) -> bool:
	return SOURCE_OPERATIONS_3._source_public_bind_props_context(self, lab)


func attach_lighting_preview(
	lease: StadiumLightingKitPreviewRuntime, kit: Node3D, poles: Array[Node3D]
) -> bool:
	return SOURCE_OPERATIONS_3._source_public_attach_lighting_preview(self, lease, kit, poles)


func detach_lighting_preview(lease: StadiumLightingKitPreviewRuntime) -> bool:
	return SOURCE_OPERATIONS_3._source_public_detach_lighting_preview(self, lease)


func has_live_waterfall() -> bool:
	return SOURCE_OPERATIONS_3._source_public_has_live_waterfall(self)


func waterfall_step(from: Vector3, target: Vector3, travel: float, actors: Array = []) -> Vector3:
	return SOURCE_OPERATIONS_3._source_public_waterfall_step(self, from, target, travel, actors)


func waterfall_clip(from: Vector3, to: Vector3) -> Vector3:
	return SOURCE_OPERATIONS_3._source_public_waterfall_clip(self, from, to)

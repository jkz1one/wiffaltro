class_name StadiumYardThreeStudy
extends RefCounted
## AY-03 authoring only: exact AY-01 physical baseline plus four dormant ST-037 v2 poles.

const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")
const LIGHT_SITES: Array[String] = ["YLIGHT-FL", "YLIGHT-FR", "YLIGHT-RL", "YLIGHT-RR"]
const PREFIX: String = "npc-candidate:AY-03:"
const SOURCES: Dictionary = {
	"yard_baseline": "res://src/presentation/stadium/stadium_yard_venue_study.gd",
	"baseline_field": "res://src/content/fields/starter_field.tres",
	"yard_light": "res://src/presentation/stadium/stadium_yard_light_models.gd",
	"light_parts": "res://src/presentation/stadium/stadium_starter_models.gd",
	"field": "res://src/content/fields/npc_venue_field.tres",
	"field_semantics": "res://src/content/definitions/field_definition.gd",
	"assembly": "res://src/presentation/stadium/stadium_yard_three_study.gd",
	"lab": "res://src/presentation/stadium/stadium_yard_three_lab.gd"
}


static func canonical() -> Dictionary:
	var result: Dictionary = StadiumYardVenueStudy.canonical().duplicate(true)
	result.id = "AY-03"
	result["field"] = {"id": "field.npc_venue", "values": {}}
	for key: String in StadiumNpcYardV1.FIELD:
		result.field.values[key] = FIELD.get(key)
	result.surface.id = "AY-03-default-backyard-v1"
	for row: Dictionary in result.items:
		row.instance = PREFIX + row.site
		row["host"] = "field"
	for site: String in LIGHT_SITES:
		var model: Node3D = StadiumYardLightModels.create()
		StadiumYardLightModels.place(model, site)
		var beam: SpotLight3D = model.get_node("FieldLight")
		result.items.append({"instance": PREFIX + site, "item": "ST-037", "site": site,
			"host": "field", "model": "yard-light-v2",
			"transform": StadiumYardVenueStudy.components(model.transform),
			"role": "DECORATIVE_AFTER_TERMINAL",
			"beam_transform": StadiumYardVenueStudy.components(beam.transform)})
		model.free()
	for key: String in SOURCES:
		result.model_sources[key] = FileAccess.get_sha256(SOURCES[key])
	result.blueprint_entitlements = ["ST-037", "ST-080"]
	result["lighting"] = {"version": 1, "presentation": "dormant-daylight",
		"complete_fixed_sites": LIGHT_SITES.duplicate(), "beam_visible": false,
		"lens_emission": false, "future_profile": "requires-separate-whole-layout-qualification"}
	var light: Dictionary = StadiumCatalog.item("ST-037")
	result.endowment.blueprint_value += int(light.blueprint_price)
	result.endowment.copy_value += int(light.copy_price) * 4
	result.endowment.total_value = result.endowment.blueprint_value + result.endowment.copy_value
	return result


static func build() -> StadiumPropertyGeometry:
	# This is a construction seam only. No AY-01 lab, definition, registry or runtime is installed.
	var property: StadiumPropertyGeometry = StadiumYardVenueStudy.build()
	if property == null:
		return null
	property.name = "AY03Candidate"
	property.field = FIELD.duplicate(true) as FieldDefinition
	var objects: Dictionary = {}
	for site: String in StadiumYardVenueStudy.SITES:
		var model: Node3D = property.objects["npc-candidate:AY-01:" + site]
		_bind(model, site)
		objects[PREFIX + site] = model
	for site: String in LIGHT_SITES:
		var model: Node3D = StadiumYardLightModels.create()
		model.name = site
		if not StadiumYardLightModels.place(model, site):
			model.free()
			property.free()
			return null
		_bind(model, site)
		property.add_child(model)
		objects[PREFIX + site] = model
	property.objects = objects
	property.set_meta("candidate_venue", canonical())
	return property


static func _bind(model: Node3D, site: String) -> void:
	model.set_meta("candidate_instance", PREFIX + site)
	model.set_meta("candidate_site", site)
	model.set_meta("candidate_host", "field")
	for body: StaticBody3D in model.get_node("Collision").get_children():
		body.set_meta("candidate_instance", PREFIX + site)

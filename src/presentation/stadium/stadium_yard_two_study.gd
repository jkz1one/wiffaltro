class_name StadiumYardTwoStudy
extends RefCounted
## DE AY-02 authoring only: exact chair receiver, two small bleachers and one live cone.

const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")
const PREFIX: String = "npc-candidate:AY-02:"
const SITES: Array[String] = ["RECEIVER-PRIMARY", "SIDE-SEAT-L", "SIDE-SEAT-R", "O-R1"]
const ITEMS: Array[String] = ["ST-079", "ST-027", "ST-027", "ST-001"]
const SOURCES: Dictionary = {
	"starter_models": "res://src/presentation/stadium/stadium_starter_models.gd",
	"seating_models": "res://src/presentation/stadium/stadium_seating_models.gd",
	"field": "res://src/content/fields/npc_venue_field.tres",
	"field_semantics": "res://src/content/definitions/field_definition.gd",
	"assembly": "res://src/presentation/stadium/stadium_yard_two_study.gd",
	"property": "res://src/presentation/stadium/stadium_yard_two_property.gd",
	"receiver_adapter": "res://src/presentation/stadium/stadium_yard_two_receiver.gd",
	"receiver_algorithm": "res://src/presentation/stadium/stadium_pitch_receiver.gd",
	"lab": "res://src/presentation/stadium/stadium_yard_two_lab.gd",
	"camera": "res://src/presentation/stadium/stadium_yard_two_camera_director.gd",
	"coverage": "res://src/presentation/stadium/stadium_yard_two_camera_motion.gd",
	"target_visibility": "res://src/presentation/stadium/stadium_yard_two_tracking_visibility.gd",
	"actor_presentation": "res://src/presentation/stadium/stadium_yard_two_actor_presentation.gd",
	"retained_actor_algorithm":
	"res://src/presentation/stadium/stadium_npc_retained_actor_cutaway.gd",
	"shared_motion": "res://src/presentation/camera/ball_in_play_camera.gd",
	"render_quality": "res://src/presentation/stadium/stadium_wall_render_quality.gd"
}


static func pose(site: String) -> Transform3D:
	match site:
		"RECEIVER-PRIMARY":
			return Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.05))
		"SIDE-SEAT-L":
			return Transform3D(
				Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT), Vector3(-24, 0, 12.5)
			)
		"SIDE-SEAT-R":
			return Transform3D(
				Basis(Vector3(0, 0, 1), Vector3.UP, Vector3.LEFT), Vector3(24, 0, 12.5)
			)
		"O-R1":
			return Transform3D(Basis.IDENTITY, Vector3(8, 0, 14))
	return Transform3D.IDENTITY


static func canonical() -> Dictionary:
	var result: Dictionary = StadiumYardVenueStudy.canonical().duplicate(true)
	result.id = "AY-02"
	result["camera_profile"] = {
		"id": StadiumYardTwoCameraDirector.PROFILE,
		"batting_entry": [0.18, 2.10, -6.5],
		"handed_x": true,
		"focus": [0.0, 1.10, 7.1],
		"fov": "unchanged-shared",
		"live_motion": "unchanged-shared",
		"entry_phase": "PRE_PITCH-only",
		"side_target_policy": "authenticated-side-corridor-offense-half-planes-v1",
		"side_target_clearance_m": BallTrackingVisibility.WALL_CAMERA_CLEARANCE,
		"side_target_stage": "desired-before-shared-avoidance-and-integration"
	}
	result["render_profile"] = {
		"id": "AY02-WALL-MSAA4X-VIEWPORT-LEASE-v1",
		"minimum": "MSAA_4X",
		"scope": "actual-installed-candidate-viewport",
		"owner": "authentic-BoundaryGraph",
		"restore": "unchanged-shared-owner-lease",
		"ball_geometry": "unchanged",
		"ball_material": "unchanged"
	}
	result["field"] = {"id": "field.npc_venue", "values": {}}
	for key: String in StadiumNpcYardV1.FIELD:
		result.field.values[key] = FIELD.get(key)
	result.items.clear()
	for index in range(SITES.size()):
		var item: String = ITEMS[index]
		result.items.append(
			{
				"instance": PREFIX + SITES[index],
				"item": item,
				"site": SITES[index],
				"host": "field",
				"model": "wooden-bleachers-v1" if item == "ST-027" else "starter-models-v1:" + item,
				"transform": StadiumYardVenueStudy.components(pose(SITES[index])),
				"role":
				(
					"DECORATIVE_AFTER_TERMINAL"
					if item == "ST-027"
					else ("LIVE_RICOCHET" if item == "ST-001" else "RECEIVER_CONTAINMENT_FOUL")
				)
			}
		)
	for key: String in SOURCES:
		result.model_sources[key] = FileAccess.get_sha256(SOURCES[key])
	result.blueprint_entitlements = ["ST-001", "ST-027", "ST-079"]
	result.live_units = 1
	result.receiver = {
		"id": "RX-CHAIR-079-00-v1",
		"configuration": "RX-CHAIR-079-00-v1",
		"site": "RECEIVER-PRIMARY",
		"catalog_item": "ST-079",
		"catching_layer": "",
		"transform": StadiumYardVenueStudy.components(pose("RECEIVER-PRIMARY")),
		"pitch_surfaces": StadiumStarterModels.surfaces("ST-079"),
		"batted_surfaces": StadiumStarterModels.surfaces("ST-079"),
		"cleanup_z": StadiumPitchReceiver.CLEANUP_Z,
		"timeout": StadiumPitchReceiver.TIMEOUT,
		"sweep_step": StadiumPitchReceiver.STEP,
		"visual_settle": 0.28,
		"collider_motion": "rest-only",
		"max_pitch_contacts": 1
	}
	result.surface.id = "AY-02-default-backyard-v1"
	result.routing.live_obstacles = [
		{
			"instance": PREFIX + "O-R1",
			"item": "ST-001",
			"site": "O-R1",
			"units": 1,
			"role": "LIVE_RICOCHET"
		}
	]
	result.endowment.blueprint_value = 0
	result.endowment.copy_value = 0
	for item: String in result.blueprint_entitlements:
		result.endowment.blueprint_value += int(StadiumCatalog.item(item).blueprint_price)
	for item: String in ITEMS:
		result.endowment.copy_value += int(StadiumCatalog.item(item).copy_price)
	result.endowment.total_value = result.endowment.blueprint_value + result.endowment.copy_value
	return result


static func build() -> StadiumYardTwoProperty:
	var property: StadiumYardTwoProperty = StadiumYardTwoProperty.new()
	property.name = "AY02Candidate"
	# Empty grammar creates free infrastructure only. Never a starter grant or paid purchase.
	if not property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new()):
		property.free()
		return null
	property.field = FIELD.duplicate(true) as FieldDefinition
	if StadiumBoundaryRuntime.assemble(property) == null:
		property.free()
		return null
	for index in range(SITES.size()):
		var model: Node3D = (
			StadiumSeatingModels.create(ITEMS[index])
			if ITEMS[index] == "ST-027"
			else StadiumStarterModels.create(ITEMS[index])
		)
		model.name = SITES[index]
		model.transform = pose(SITES[index])
		var identity: String = PREFIX + SITES[index]
		model.set_meta("candidate_instance", identity)
		model.set_meta("candidate_site", SITES[index])
		model.set_meta("candidate_host", "field")
		property.add_child(model)
		property.objects[identity] = model
		property.bind_model(identity, model)
	property.set_meta("candidate_venue", canonical())
	return property

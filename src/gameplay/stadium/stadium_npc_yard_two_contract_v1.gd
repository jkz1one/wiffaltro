class_name StadiumNpcYardTwoContractV1
extends RefCounted
## Complete historical venue data, with finite scene-vector reconstruction only.
## sweep_step repeats the independently pinned original float64 expression 1.0 / 240.0;
## Godot's decimal parser loses eight float64 ULPs for its historical JSON token.
## Camera/receiver scalar semantics are exact float64 values and confer no runtime authority.
# gdlint: disable=max-file-lines,max-line-length


static func payload() -> Dictionary:
	return {
		"blueprint_entitlements": [
			"ST-001",
			"ST-027",
			"ST-079"
		],
		"boundary": {
			"id": "PERIM-BACKYARD-STRAIGHT-BX1-v1",
			"segments": [
				{
					"a": [
						-8.0,
						-6.0
					],
					"b": [
						8.0,
						-6.0
					],
					"height": 1.2,
					"id": "REAR-DEAD-01",
					"priority": 300,
					"role": "REAR_PERIMETER_DEAD"
				},
				{
					"a": [
						8.0,
						-6.0
					],
					"b": [
						24.0,
						23.399999618530273
					],
					"height": 1.2,
					"id": "SIDE-R-01",
					"priority": 50,
					"role": "SIDE_RETURN_LIVE"
				},
				{
					"a": [
						24.0,
						23.399999618530273
					],
					"b": [
						21.519454956054688,
						23.399999618530273
					],
					"height": 1.2,
					"id": "RETURN-R-01",
					"priority": 100,
					"role": "SIDE_RETURN_LIVE"
				},
				{
					"a": [
						21.519454956054688,
						23.399999618530273
					],
					"b": [
						-21.519454956054688,
						23.399999618530273
					],
					"height": 3.25,
					"id": "BACK-TERMINAL-01",
					"priority": 200,
					"role": "BACK_WALL_TERMINAL"
				},
				{
					"a": [
						-21.519454956054688,
						23.399999618530273
					],
					"b": [
						-24.0,
						23.399999618530273
					],
					"height": 1.2,
					"id": "RETURN-L-01",
					"priority": 100,
					"role": "SIDE_RETURN_LIVE"
				},
				{
					"a": [
						-24.0,
						23.399999618530273
					],
					"b": [
						-8.0,
						-6.0
					],
					"height": 1.2,
					"id": "SIDE-L-01",
					"priority": 50,
					"role": "SIDE_RETURN_LIVE"
				}
			],
			"signature": "93859ee6fb839243e6ac471b45027547e4a47e09e7e57bc957f19c7410b542e9",
			"thickness": 0.2
		},
		"camera_profile": {
			"batting_entry": [
				0.18,
				2.1,
				-6.5
			],
			"entry_phase": "PRE_PITCH-only",
			"focus": [
				0.0,
				1.1,
				7.1
			],
			"fov": "unchanged-shared",
			"handed_x": true,
			"id": "AY02-ENTRY-AND-SIDE-TARGET-reconstruction-v3",
			"live_motion": "unchanged-shared",
			"side_target_clearance_m": 1.2,
			"side_target_policy": "authenticated-side-corridor-offense-half-planes-v1",
			"side_target_stage": "desired-before-shared-avoidance-and-integration"
		},
		"endowment": {
			"blueprint_value": 300,
			"copy_value": 275,
			"land_value": 0,
			"price_version": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"purpose": "content-comparison-only",
			"spendable": false,
			"total_value": 575
		},
		"environment": {
			"certificates": [],
			"night_eligible": false,
			"target_slots": [
				"13:10",
				"16:10"
			],
			"target_weather": [
				"clear"
			]
		},
		"field": {
			"id": "field.npc_venue",
			"values": {
				"back_wall_z_m": 23.4,
				"dead_ball_z_m": 29.0,
				"deep_air_z_m": 17.0,
				"deep_anchor_z_m": 19.5,
				"display_name": "NPC Venue",
				"environment_style": 0,
				"fair_half_angle_degrees": 42.0,
				"home_run_height_m": 3.25,
				"id": "field.npc_venue",
				"middle_anchor_z_m": 14.0,
				"middle_center_anchor_z_m": 17.0,
				"middle_center_available": false,
				"safe_hit_z_m": 11.25,
				"shallow_anchor_z_m": 8.5,
				"shallow_center_available": false,
				"side_anchor_x_m": 5.5
			}
		},
		"id": "AY-02",
		"items": [
			{
				"host": "field",
				"instance": "npc-candidate:AY-02:RECEIVER-PRIMARY",
				"item": "ST-079",
				"model": "starter-models-v1:ST-079",
				"role": "RECEIVER_CONTAINMENT_FOUL",
				"site": "RECEIVER-PRIMARY",
				"transform": [
					1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					-1.0499999523162842
				]
			},
			{
				"host": "field",
				"instance": "npc-candidate:AY-02:SIDE-SEAT-L",
				"item": "ST-027",
				"model": "wooden-bleachers-v1",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"site": "SIDE-SEAT-L",
				"transform": [
					0.0,
					0.0,
					-1.0,
					0.0,
					1.0,
					0.0,
					1.0,
					0.0,
					0.0,
					-24.0,
					0.0,
					12.5
				]
			},
			{
				"host": "field",
				"instance": "npc-candidate:AY-02:SIDE-SEAT-R",
				"item": "ST-027",
				"model": "wooden-bleachers-v1",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"site": "SIDE-SEAT-R",
				"transform": [
					0.0,
					0.0,
					1.0,
					0.0,
					1.0,
					0.0,
					-1.0,
					0.0,
					0.0,
					24.0,
					0.0,
					12.5
				]
			},
			{
				"host": "field",
				"instance": "npc-candidate:AY-02:O-R1",
				"item": "ST-001",
				"model": "starter-models-v1:ST-001",
				"role": "LIVE_RICOCHET",
				"site": "O-R1",
				"transform": [
					1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					8.0,
					0.0,
					14.0
				]
			}
		],
		"kind": "npc-authored-candidate",
		"live_units": 1,
		"mapping": "WORKING",
		"model_sources": {
			"actor_presentation": "522acbd3e2f61ffccb41aa75bc29012877d94505251113ed35caac152b8a95a7",
			"assembly": "459e12b74e9d6a049748a97bc55b914962c3a699f9125aad5202757375b7494d",
			"boundary": "5b7e8fe60a44b875e5e0e66ce2fe3d8a995e4482c8de79dedbaabcb9adc0d88a",
			"camera": "ac650e96bf4985c3cb329ee695ca212c471e361f5393463c52be6672f99879aa",
			"chair": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb",
			"coverage": "7f73b297534cc4c5ee820718fcf2872ec668a6ec495fcd71ea949a6f55137dc3",
			"field": "a9df5523562f2a237d205e72b252729a6a248dc2bbfd789d51d6f1e4c587b598",
			"field_semantics": "39cf09ce92b00c8c0d784f5e738623b810b512a12c3b3c9294a5133b33f413d2",
			"lab": "4fd69c4aec0e204688bce32b0a5c880bd4150c72aae3d1ceb79e0b92bb5b7173",
			"property": "22bef303555126ee2405520181c20570bc839ca1e43cd0914c4e90158eb1e30a",
			"receiver": "79a51e1fd14077d0ab1be26a61bed531124e9c4349806af9bc9a0321efb7464d",
			"receiver_adapter": "a5635a3eccd7507ecbf79849dc33daefc26474f79732e2b1dc3afbd3b9e3eb30",
			"receiver_algorithm": "8980a5bd60c3429f01e165ec36a8c9b2bc12387af413dd9edf6b4002c3190e77",
			"receiver_visual": "0be889d48a37c9e5d017fcd234b2289cc8928a386605352557a6c7631ceeb9e5",
			"render_quality": "a342c1bda3e7c5d4d3d8f004eb76d6044a0f7a7305181429226f3c2e3c8c39d7",
			"retained_actor_algorithm": "f578e0c28e35ae43cfc442cf70d69e974e38e0a6f1b593b0a99dc1bbe174e504",
			"seating_models": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb",
			"shared_motion": "ead78e617b06f824ca37d669e05364eb6df70257729918b58c821c850fae68a0",
			"starter_models": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
			"target_visibility": "54b2ec5d84a4495be4799e1d4418f03b5ff6e92b4cb94c1c10258c9ae18cd681",
			"template": "779ce82a8bc9ff872dc3e1cf5c50552f5cf7eaa5914e5857d9459904cbaf89af"
		},
		"property": "backyard",
		"receiver": {
			"batted_surfaces": [
				"ST079_BACK",
				"ST079_SEAT",
				"ST079_ARM-1",
				"ST079_ARM_SUPPORT-1",
				"ST079_FRONT_LEG-1",
				"ST079_REAR_LEG-1",
				"ST079_ARM1",
				"ST079_ARM_SUPPORT1",
				"ST079_FRONT_LEG1",
				"ST079_REAR_LEG1"
			],
			"catalog_item": "ST-079",
			"catching_layer": "",
			"cleanup_z": -1.4,
			"collider_motion": "rest-only",
			"configuration": "RX-CHAIR-079-00-v1",
			"id": "RX-CHAIR-079-00-v1",
			"max_pitch_contacts": 1,
			"pitch_surfaces": [
				"ST079_BACK",
				"ST079_SEAT",
				"ST079_ARM-1",
				"ST079_ARM_SUPPORT-1",
				"ST079_FRONT_LEG-1",
				"ST079_REAR_LEG-1",
				"ST079_ARM1",
				"ST079_ARM_SUPPORT1",
				"ST079_FRONT_LEG1",
				"ST079_REAR_LEG1"
			],
			"site": "RECEIVER-PRIMARY",
			"sweep_step": 1.0 / 240.0,
			"timeout": 0.24,
			"transform": [
				1.0,
				0.0,
				0.0,
				0.0,
				1.0,
				0.0,
				0.0,
				0.0,
				1.0,
				0.0,
				0.0,
				-1.0499999523162842
			],
			"visual_settle": 0.28
		},
		"render_profile": {
			"ball_geometry": "unchanged",
			"ball_material": "unchanged",
			"id": "AY02-WALL-MSAA4X-VIEWPORT-LEASE-v1",
			"minimum": "MSAA_4X",
			"owner": "authentic-BoundaryGraph",
			"restore": "unchanged-shared-owner-lease",
			"scope": "actual-installed-candidate-viewport"
		},
		"routing": {
			"boundary": "PERIM-BACKYARD-STRAIGHT-BX1-v1",
			"defender_radius": 0.54,
			"live_obstacles": [
				{
					"instance": "npc-candidate:AY-02:O-R1",
					"item": "ST-001",
					"role": "LIVE_RICOCHET",
					"site": "O-R1",
					"units": 1
				}
			],
			"version": 1
		},
		"status": "CANDIDATE",
		"surface": {
			"bounds": [
				-26,
				-10,
				52,
				42
			],
			"geometry": "flat",
			"grass": "default",
			"ground": "default",
			"id": "AY-02-default-backyard-v1",
			"lines": "default",
			"physics": "unchanged-reference-field",
			"styles": [],
			"version": 1
		},
		"version": 1
	}


static func transform(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0], values[1], values[2]),
		Vector3(values[3], values[4], values[5]), Vector3(values[6], values[7], values[8])),
		Vector3(values[9], values[10], values[11]))


static func canonical() -> Dictionary:
	return _reconstruct(payload(), "$", _vector_paths())


static func normalized(value: Variant) -> Dictionary:
	var paths: Dictionary = _vector_paths()
	if not _structure(value, payload(), "$", paths):
		return {}
	var result: Dictionary = _reconstruct(value.duplicate(true), "$", paths)
	return result if JSON.stringify(result, "", true, true) == JSON.stringify(
		canonical(), "", true, true) else {}


static func _vector_paths() -> Dictionary:
	# These arrays alone were serialized from Vector2/Vector3 scene storage by the source.
	# Camera arrays, scalar timings, fields, radius, prices and every other path stay untouched.
	var result: Dictionary = {"$.receiver.transform": 12}
	for index in range(4):
		result["$.items[%d].transform" % index] = 12
	for index in range(6):
		result["$.boundary.segments[%d].a" % index] = 2
		result["$.boundary.segments[%d].b" % index] = 2
	return result


static func _structure(value: Variant, expected: Variant, path: String, paths: Dictionary) -> bool:
	if paths.has(path):
		if not value is Array or value.size() != paths[path]:
			return false
		for number: Variant in value:
			if not (number is int or number is float) or not is_finite(float(number)) \
				or number < -1000 or number > 1000:
				return false
		return true
	if expected is Dictionary:
		if not value is Dictionary or value.size() != expected.size():
			return false
		for key: Variant in expected:
			if not value.has(key) or not _structure(value[key], expected[key],
				path + "." + str(key), paths):
				return false
		return true
	if expected is Array:
		if not value is Array or value.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _structure(value[index], expected[index], path + "[%d]" % index, paths):
				return false
		return true
	return typeof(value) == typeof(expected) and value == expected


static func _reconstruct(value: Variant, path: String, paths: Dictionary) -> Variant:
	if paths.has(path):
		var result: Array = Array(PackedFloat32Array(value))
		for index in range(result.size()):
			if result[index] == 0.0:
				result[index] = 0.0
		return result
	if value is Dictionary:
		for key: Variant in value:
			value[key] = _reconstruct(value[key], path + "." + str(key), paths)
	elif value is Array:
		for index in range(value.size()):
			value[index] = _reconstruct(value[index], path + "[%d]" % index, paths)
	return value

class_name StadiumHillsideDefinitionV1
extends RefCounted
## Exact DD eight-copy source prerequisite. Structural identity never grants venue authority.
## Pose and graph hashes use Godot's own canonical float32/JSON path, without guessed literals.

const SOURCE_PATHS: Dictionary = {
	"terrain-defender-motion":
	"res://src/presentation/fielding/stadium_hillside_defender_motion.gd",
	"terrain-ground-contact": "res://src/presentation/stadium/stadium_hillside_ground_contact.gd",
	"public-support-lease": "res://src/presentation/stadium/stadium_hillside_public_support.gd",
	"actual-ball-body": "res://src/presentation/ball/batted_ball_body.gd",
	"ball-tracking-visibility": "res://src/presentation/camera/ball_tracking_visibility.gd",
	"ordinary-boundary-observer": "res://src/gameplay/stadium/stadium_boundary_observer.gd",
	"ordinary-play-resolver": "res://src/gameplay/ball_in_play/ball_play_resolver.gd",
	"ordinary-play-state": "res://src/gameplay/ball_in_play/ball_play_state.gd",
	"paired-pitch-receiver": "res://src/presentation/stadium/stadium_pitch_receiver.gd",
	"paired-receiver": "res://src/presentation/stadium/stadium_paired_receiver.gd",
	"paired-target-receiver": "res://src/presentation/stadium/stadium_target_receiver.gd",
	"public-contact-adapter":
	"res://src/presentation/stadium/stadium_hillside_public_contact_adapter.gd",
	"public-paired-receiver": "res://src/presentation/stadium/stadium_hillside_public_receiver.gd",
	"public-terrain-visibility":
	"res://src/presentation/stadium/stadium_hillside_public_visibility.gd",
	"receiver-visibility": "res://src/presentation/stadium/stadium_receiver_visibility.gd",
	"retained-geometry": "res://src/presentation/stadium/stadium_npc_retained_geometry.gd",
	"retained-visibility": "res://src/presentation/stadium/stadium_npc_retained_visibility.gd",
	"timber-sphere-primitives": "res://src/gameplay/stadium/stadium_timber_dugout_boundary.gd",
	"wall-view-prisms": "res://src/presentation/camera/stadium_wall_view_prisms.gd",
	"asset-integrity": "res://src/gameplay/stadium/stadium_pool_party_asset_integrity.gd",
	"catalog-source": "res://src/gameplay/stadium/stadium_catalog.gd",
	"dugout-boundary-base": "res://src/gameplay/stadium/stadium_dugout_boundary.gd",
	"dugout-recipes": "res://src/gameplay/stadium/stadium_dugout_recipe.gd",
	"field-resource": "res://src/content/fields/npc_venue_field.tres",
	"field-semantics": "res://src/content/definitions/field_definition.gd",
	"flat-markers-and-seating-sites":
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_v1.gd",
	"foul-pole": "res://src/presentation/stadium/stadium_foul_pole_models.gd",
	"foul-pole-sites": "res://src/gameplay/stadium/stadium_foul_pole_sites.gd",
	"hillside-closed-slice-math":
	"res://src/presentation/stadium/stadium_hillside_boundary_body.gd",
	"hillside-terrain": "res://src/gameplay/stadium/stadium_hillside_terrain.gd",
	"hillside-terrain-models": "res://src/presentation/stadium/stadium_hillside_terrain_models.gd",
	"manifest-canonical": "res://src/gameplay/stadium/stadium_npc_manifest.gd",
	"portable-net": "res://src/presentation/stadium/stadium_net_models.gd",
	"primary-target": "res://src/presentation/stadium/stadium_target_models.gd",
	"public-boundary-source":
	"res://src/presentation/stadium/stadium_hillside_public_boundary_source.gd",
	"public-construction": "res://src/presentation/stadium/stadium_hillside_public_construction.gd",
	"public-graph": "res://src/gameplay/stadium/stadium_hillside_public_boundary.gd",
	"recipe-semantics": "res://src/gameplay/stadium/stadium_recipe_boundary.gd",
	"shared-cold-construction":
	"res://src/presentation/stadium/stadium_long_yard_public_construction.gd",
	"side-seating": "res://src/presentation/stadium/stadium_seating_models.gd",
	"starter-parts": "res://src/presentation/stadium/stadium_starter_models.gd",
	"timber-contract": "res://src/gameplay/stadium/stadium_timber_dugout_contract.gd",
	"timber-dugout": "res://src/presentation/stadium/stadium_timber_dugout_models.gd",
	"wall-recipes": "res://src/gameplay/stadium/stadium_wall_recipes.gd"
}


# Historical manifest identity remains immutable. These exact successors were reviewed
# for compatibility with the retained Hillside construction. Their use additionally
# requires an independently reviewed whole-current-source profile, never just this table.
const RETAINED_SOURCE_SUCCESSORS: Dictionary = {
	"terrain-defender-motion":
	{
		"retained": "c7cb93d6c94cfd1ef475489cb6570356952f403586f59ecf6beed5e3e7fe45ec",
		"current": "3c620b4bc7ff53a9e7e6361bb01bc31abb56e06fed187b9b9b1910eed753dfbf"
	},
	"actual-ball-body":
	{
		"retained": "706bdcdb59030712ce4d90994e32ce8727e3806ddb45e584843e9b8d34f66b6e",
		"current": "e9a6f7a3096ecbc8d9109b32ab633503756f630559fc0d102c466585cc9fa9a5"
	},
	"ball-tracking-visibility":
	{
		"retained": "344e28784f900c6f660c55574330a8afc2d8c46b7149edfa28841957952253a8",
		"current": "4f78b257d65cef9aeff28b8b2897eba9722fcccd44c4ba2985eb66b237d8bfd2"
	},
	"retained-geometry":
	{
		"retained": "4111690785527c210f27429e63a7f22b044816cc67757d0927f0e1457fd6b5ef",
		"current": "348f60aeeb04f5b59a73081e23d7766e4ea3700b4532be7d29bbe86a385879f9"
	},
	"catalog-source":
	{
		"retained": "390844e539404bc78b303aeeac31b8c11d129b334fd1ca342baa0091577e1ea1",
		"current": "f3e97e9c088f5ea494ef83ca8bc0702e98bd5d19e28b1f485ce9f0b5bb7e847b"
	},
}


static func canonical() -> Dictionary:
	return StadiumNpcManifest.canonical_shape(payload())


static func signature() -> String:
	return StadiumNpcManifest.payload_key(payload())


static func matches(value: Variant) -> bool:
	var actual: Dictionary = StadiumNpcManifest.canonical_shape(value)
	return (
		not actual.is_empty()
		and JSON.stringify(actual, "", true, true) == JSON.stringify(canonical(), "", true, true)
	)


static func payload() -> Dictionary:
	var graph: StadiumHillsidePublicBoundary = StadiumHillsidePublicBoundary.create_hillside()
	return {
		"version": 1,
		"id": "HILLSIDE",
		"revision": 1,
		"assembly": {"id": "HILLSIDE-public-deeper-center-v1", "version": 1},
		"field": "field.npc_venue",
		"tier": "expanded",
		"shape": "deeper_center",
		"rules_version": 1,
		"graph": {"id": graph.identity(), "version": 1, "sha256": graph.signature()},
		"catalog":
		{
			"version": 1,
			"sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f"
		},
		"models": model_pins(),
		"instances": instances(),
		"blueprints": ["ST-021", "ST-025", "ST-026", "ST-027", "ST-032"],
		"land": {"version": 1, "tier": "expanded", "stages": ["expanded"]},
		"surface_version": 1,
		"routing_version": 1,
		"environment_certificates": [],
		"presentation": {"profile": "HILLSIDE-1310-CLEAR-HUD-v1", "options": {}},
		"live_units": 0,
		"valuation":
		{
			"price_version": 1,
			"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"blueprints": 1530,
			"copies": 800,
			"land": 600,
			"total": 2930
		}
	}


static func instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(StadiumHillsidePublicConstruction.SITES.size()):
		var site: String = StadiumHillsidePublicConstruction.SITES[index]
		result.append(
			{
				"instance": StadiumHillsidePublicConstruction.INSTANCE_PREFIX + site,
				"item": StadiumHillsidePublicConstruction.ITEMS[index],
				"site": site,
				"host": "field",
				"transform":
				StadiumHillsidePublicConstruction.components(
					StadiumHillsidePublicConstruction.pose(site)
				)
			}
		)
	return result


static func source_paths() -> Dictionary:
	return SOURCE_PATHS.duplicate(true)




static func sources_valid() -> bool:
	var pins: Dictionary = model_pins()
	var needs_current_profile: bool = false
	for key: String in SOURCE_PATHS:
		var observed: String = FileAccess.get_sha256(SOURCE_PATHS[key])
		if observed == pins[key].sha256:
			continue
		var successor: Dictionary = RETAINED_SOURCE_SUCCESSORS.get(key, {})
		if (
			successor.is_empty()
			or pins[key].sha256 != successor.retained
			or observed != successor.current
		):
			return false
		needs_current_profile = true
	return (
		not needs_current_profile
		or StadiumNpcSourceQualification.matches_current(StadiumNpcPublicRuntime.SOURCE_PINS)
	)


static func model_pins() -> Dictionary:
	return {
		"terrain-defender-motion":
		{
			"sha256": "c7cb93d6c94cfd1ef475489cb6570356952f403586f59ecf6beed5e3e7fe45ec",
			"version": 1
		},
		"terrain-ground-contact":
		{
			"sha256": "ba11daed357799a08cdd18b20772a721767ce9f0be7a1c5eab146c5441c2dee8",
			"version": 1
		},
		"public-support-lease":
		{
			"sha256": "02b762573c4220ced8a8b7d166cae6a252216b6b409070c4d87395175e1efcd7",
			"version": 1
		},
		"actual-ball-body":
		{
			"sha256": "706bdcdb59030712ce4d90994e32ce8727e3806ddb45e584843e9b8d34f66b6e",
			"version": 1
		},
		"ball-tracking-visibility":
		{
			"sha256": "344e28784f900c6f660c55574330a8afc2d8c46b7149edfa28841957952253a8",
			"version": 1
		},
		"ordinary-boundary-observer":
		{
			"sha256": "406b1050fd62c2077d6804ee28d23662dd88bf1b71c1ff786bab900d2391a08c",
			"version": 1
		},
		"ordinary-play-resolver":
		{
			"sha256": "4470909adec562bf7d278a0019cecbd960605b2e69eee19178532b77d626f621",
			"version": 1
		},
		"ordinary-play-state":
		{
			"sha256": "8a31d563ea78bfa6637def55aeb83dcd036bb16a187773fece4e852676ad8c4c",
			"version": 1
		},
		"paired-pitch-receiver":
		{
			"sha256": "743274083e25dbc6ff7c0bcb57a531d8e2c72c53ef43920a9f7a4afe167203a3",
			"version": 1
		},
		"paired-receiver":
		{
			"sha256": "4a5b8429e56c31a8b29e6a22c783e5a8bfa422e0191cb6eebf4a0b44c40bccaf",
			"version": 1
		},
		"paired-target-receiver":
		{
			"sha256": "99341f1fbc0040236183eed3fb0693444db8bee10ba9b339f550e5f15b12d78b",
			"version": 1
		},
		"public-contact-adapter":
		{
			"sha256": "9644b020e560600324c41e45af2429ce4b3ea57ea5f5ce5fa77fd59e1972e548",
			"version": 1
		},
		"public-paired-receiver":
		{
			"sha256": "ccfd472ed27e816f6472e1e401921eacf4f06793d8d074b765f9a08a0ed44b78",
			"version": 1
		},
		"public-terrain-visibility":
		{
			"sha256": "f1fd51ee8e3b9be72425164a1c648d9edce4e293f2d0444724492d570d8e1ceb",
			"version": 1
		},
		"receiver-visibility":
		{
			"sha256": "6e91b28a5d7ff5282e531efa2df0965ec2b5076f82ff734ab71446edf13f007d",
			"version": 1
		},
		"retained-geometry":
		{
			"sha256": "4111690785527c210f27429e63a7f22b044816cc67757d0927f0e1457fd6b5ef",
			"version": 1
		},
		"retained-visibility":
		{
			"sha256": "45577b4c0d9de3cc09beb609317dc93ca559aecddd92b32a5a070bfe3992da03",
			"version": 1
		},
		"timber-sphere-primitives":
		{
			"sha256": "559c3ca40993c51c4b2a34902a165fbf78866259ae368bc618a93c00bf291dce",
			"version": 1
		},
		"wall-view-prisms":
		{
			"sha256": "c84ce7c1b7eb913589c06e928ea7536dca51ee346203dd4ab9186ff9b137beda",
			"version": 1
		},
		"asset-integrity":
		{
			"sha256": "5da71e546e50af6e69aaf1574655c463036ac72e6ab2043886c7828ce5be6a1e",
			"version": 1
		},
		"catalog-source":
		{
			"sha256": "390844e539404bc78b303aeeac31b8c11d129b334fd1ca342baa0091577e1ea1",
			"version": 1
		},
		"dugout-boundary-base":
		{
			"sha256": "8e7cb6c7ede2e74c399df58ecb7bfe509a26ff0f0aedb23644baf39e3c0cf888",
			"version": 1
		},
		"dugout-recipes":
		{
			"sha256": "9426ec13fc1ab673cafd856c0611dbd6aa6f90056d0315197cfb6313f6cc38a4",
			"version": 1
		},
		"field-resource":
		{
			"sha256": "a9df5523562f2a237d205e72b252729a6a248dc2bbfd789d51d6f1e4c587b598",
			"version": 1
		},
		"field-semantics":
		{
			"sha256": "39cf09ce92b00c8c0d784f5e738623b810b512a12c3b3c9294a5133b33f413d2",
			"version": 1
		},
		"flat-markers-and-seating-sites":
		{
			"sha256": "309016beb60b8512b3170e5d558e496cbfec248c6a386911c7b4f4baee96edf8",
			"version": 1
		},
		"foul-pole":
		{
			"sha256": "5e28063a3e8bc26412279df18861640c63604f8d3adbf8934f4363337d73eb53",
			"version": 1
		},
		"foul-pole-sites":
		{
			"sha256": "1e5f4c4c106c3b15f587ab2d46a81ec64d10ddafe434919643b973c51f067ff1",
			"version": 1
		},
		"hillside-closed-slice-math":
		{
			"sha256": "81c7d9a2896f18aa01d4f99d13e44f6bcde14e50e84c1b0657441c1436c9b427",
			"version": 1
		},
		"hillside-terrain":
		{
			"sha256": "804c48647be68caabb608a33ae252ec6491f1a87045621fa12dde1ba6374918d",
			"version": 1
		},
		"hillside-terrain-models":
		{
			"sha256": "883ae470bc3ee6c52c95203e9b0bf6f4c9826ffdfb28e27acac85ea1c628545f",
			"version": 1
		},
		"manifest-canonical":
		{
			"sha256": "a9bcacfacafb12f25d5a5fa86d7fff8537936f7fd071173c36583e5e1994bef1",
			"version": 1
		},
		"portable-net":
		{
			"sha256": "e54036913c3937c78d18cdfe857bd54a55ec883158f27eac13aa7e1080185398",
			"version": 2
		},
		"primary-target":
		{
			"sha256": "0334e3bc2588f17a2a7ec1f6d64209dedea8336c67461930415248f228d7ba0a",
			"version": 1
		},
		"public-boundary-source":
		{
			"sha256": "43b4c920c21955592c3ee3810fe96cb49b3014ad340af0b0cffbe55bd9217ae2",
			"version": 1
		},
		"public-construction":
		{
			"sha256": "21cba6f46b4a680dc82355dbb91a9dbce2afedbe000a2c5f3d4d1715ee939fc2",
			"version": 1
		},
		"public-graph":
		{
			"sha256": "79ce2e00f98d31e9a40c1303659cff29f1ad473ce59d4fdab969f39ef4b06906",
			"version": 1
		},
		"recipe-semantics":
		{
			"sha256": "a98381fd78d1f32fcd58ad7dbd2f29b29634c7b3572159980e781ffb6c66aca8",
			"version": 1
		},
		"shared-cold-construction":
		{
			"sha256": "3077470204e07a9786241bfb720ec0449ed1f11f75272e2474e5f4c31c554860",
			"version": 1
		},
		"side-seating":
		{
			"sha256": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb",
			"version": 1
		},
		"starter-parts":
		{
			"sha256": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
			"version": 1
		},
		"timber-contract":
		{
			"sha256": "83ac392468373e1add76f9bbddd04917ab9be862985cf1fd2e511e6ced00277d",
			"version": 1
		},
		"timber-dugout":
		{
			"sha256": "e12ec8c7dd758229202a51d4f5111e0bbcf5dc55a49930495802e91977886566",
			"version": 1
		},
		"wall-recipes":
		{"sha256": "2225255afd3ded7bddb8a94ac1ee639e91a4c2c77806e17f70db21f13fd822e5", "version": 1}
	}


static func source_layout() -> Dictionary:
	return {
		"id": "HILLSIDE-v1",
		"version": 1,
		"owner": "finals-venue:hillside:v1",
		"recipe": "DD-existing8-copy",
		"status": "Working-qualification-pending",
		"ground":
		{
			"tier": "expanded",
			"bounds": [-32, -16, 64, 54],
			"geometry": "CV-retained-hill",
			"profile": "hill",
			"ramp": [16, 26, 2],
			"formula": "2*(3*t*t-2*t*t*t)",
			"plateau_extension": false
		},
		"perimeter":
		{
			"xz": "unchanged-deeper-center",
			"back_relative_height": 3.25,
			"side_relative_height": 1.20,
			"paid_boundary_copies": 0,
			"dugout_replacements": ["DUGOUT-L", "DUGOUT-R"]
		},
		"catalog_copies": 8,
		"live_obstacles": [],
		"optional_sites": "all-other-sites-empty",
		"crowd": {"wooden_bleachers": 2, "represented_seats": 20, "crowd_objects": 0},
		"score_display": "HUD-only",
		"time": "13:10",
		"weather": "clear",
		"night_lighting": false,
		"qualification": "source-only-native-public-tests-pending",
		"timber_runtime_admitted": false,
		"production_ready": false,
		"progression_held": true
	}

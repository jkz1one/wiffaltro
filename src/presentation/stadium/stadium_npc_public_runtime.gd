class_name StadiumNpcPublicRuntime
extends RefCounted
const AC02_SETUP_RETURNS = preload("res://src/diagnostics/ac02_setup_return_diagnostics.gd")

const AC02_PASSIVE_1 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Additive ordinary/neutral-final saved-fixture facade. Retained algorithms stay frozen.
## Historical raw/private admission and compatibility pins are deliberately never called.
# gdlint: disable=max-returns,max-file-lines

const PUBLIC_BOUND: String = "stadium_npc_public_bound"
const REMOVED: Array[String] = [
	"Ground",
	"BackWall",
	"LiveObjectPole",
	"Plate",
	"MoundMarker",
	"SafeBoundary",
	"DeepAirBoundary",
	"RightFoulLine",
	"LeftFoulLine"
]
const CAMERA_STATE: Array[String] = [
	"shot",
	"_field_focus",
	"_batter_side",
	"_presentation_motion",
	"_presentation_progress",
	"_presentation_transition_speed",
	"_pitch_focus",
	"_live_coverage",
	"_standard_fov",
	"_tracking_height",
	"_shot_before_inspection"
]

const SOURCE_PINS: Dictionary = {
	"res://src/content/definitions/definition_base.gd":
	"d03b3f1f855f51f1f2e3a99f1be99a626cfe523e39c76bd9576b16cb6af4876f",
	"res://src/content/definitions/field_definition.gd":
	"39cf09ce92b00c8c0d784f5e738623b810b512a12c3b3c9294a5133b33f413d2",
	"res://src/content/fields/npc_venue_field.tres":
	"a9df5523562f2a237d205e72b252729a6a248dc2bbfd789d51d6f1e4c587b598",
	"res://src/content/fields/starter_field.tres":
	"b4cb96881a07e3980ecf4aba157bd7137b82ec75cb3d21b155d5bd2f699e1416",
	"res://src/gameplay/ball_in_play/ball_play_resolver.gd":
	"4470909adec562bf7d278a0019cecbd960605b2e69eee19178532b77d626f621",
	"res://src/gameplay/ball_in_play/ball_play_state.gd":
	"8a31d563ea78bfa6637def55aeb83dcd036bb16a187773fece4e852676ad8c4c",
	"res://src/gameplay/fielding/defender_spacing.gd":
	"60a99a60e46f45863a35c319a1b9a3cf100263b6bb0a3454000f7924d7ff5040",
	"res://src/gameplay/match/match_state.gd":
	"cdbcc87195fd80a23119552b9026b6d0934cbf62f90d98f2137c92c3027f99b8",
	"res://src/gameplay/season/season_final_venue.gd":
	"000447e6e6af40126f7f6974960b1bfc7e1ca3cb86e8c2dc383ad358a234e733",
	"res://src/gameplay/season/season_physical_fixtures.gd":
	"14cd84be8da46d2a2ec4db915e141bc620b8225c896c445119b80c0305b8be63",
	"res://src/gameplay/season/season_save.gd":
	"55fe1e3a664b437f429e7f26cf03374005884f0deeecba239109778a036f2660",
	"res://src/gameplay/season/season_state.gd":
	"16915695df78236aa7bbfaa5e9b03b86ba2c620dba69c5380d728ee107079f0b",
	"res://src/gameplay/season/season_venues.gd":
	"aeff1da8e0bc5abed03afe3124592f3bcd356e134010e7a22f7d931b15c8339b",
	"res://src/gameplay/simulation/physical_choice_evidence.gd":
	"da36dbad7fc22bdf0f72e65c2bf4eac630d9eb61c340aee62bff7cb02260228a",
	"res://src/gameplay/simulation/physical_match_report.gd":
	"82bcf3fc6f6d234b3b75c20138c17144aa4d11f0bf907f6338cd4a7b8653c1f4",
	"res://src/gameplay/simulation/physical_match_runner.gd":
	"4ddbb7afa37a4470ba3b9b79ce0c7130f8cc4477eefacc7263c391e973105956",
	"res://src/gameplay/simulation/physical_stadium_report.gd":
	"d500567f0902beef8f14c434984bf0a439cb1cde3aa90e8c1211c8a116643747",
	"res://src/gameplay/simulation/physical_tactical_evidence.gd":
	"42e47ef1f08ce88aff895e36da0932940035cbe344ec030cc62cb882071f7660",
	"res://src/gameplay/simulation/stadium_grand_i_public_report.gd":
	"4205ad72bc81df1082741c2f8c6fbdde57ff3aa423b1348c4757579997156535",
	"res://src/gameplay/simulation/stadium_grand_ii_public_report.gd":
	"0057c51c550209c1b6ee0075b483be3626e2d2e4b5c8b0e94531dd830c224411",
	"res://src/gameplay/simulation/stadium_grand_iii_public_report.gd":
	"05c203e687379c631f67a424cc6216bdc2c7359526dd14d76c83e65ce8f3d8e2",
	"res://src/gameplay/simulation/stadium_hillside_public_contacts.gd":
	"56998122f2cdf52ef542b6b2db2a751e8c717d9e041e1909e2c9872445cd3956",
	"res://src/gameplay/simulation/stadium_hillside_public_report.gd":
	"bdd7720c102de83fa6977990a6200707144466a97aa4cc2bbeeb5f57c8787b5f",
	"res://src/gameplay/simulation/stadium_long_yard_public_report.gd":
	"1327cb33d34faf58fa6b34997cfc47954fe475af763b490bf9a555ccc0624564",
	"res://src/gameplay/simulation/stadium_npc_public_contacts.gd":
	"3de06d759a637a9896a0425992bd2dbd1cd3d806f3e45329f41a48888a84033f",
	"res://src/gameplay/simulation/stadium_npc_public_report.gd":
	"bf728ec066ab2826311a135f0c1466b8e573b33c2bcc31584cf894f9f01de18b",
	"res://src/gameplay/simulation/stadium_npc_yard_two_human_evidence.gd":
	"bf2d04e76881c6b8e27cc0bcf46c309f9a4a5b0eb27c5ee15c02789f1d3dc843",
	"res://src/gameplay/simulation/stadium_pool_party_public_contacts.gd":
	"c8cdf3c7aadbe37ed1f9eeab5490b54017c1e5b450199b4e4d978fc37249c412",
	"res://src/gameplay/simulation/stadium_pool_party_public_report.gd":
	"4beff9b94e40042a53c2e9edbad6ef1fc317dec43e420e70729a55a43b80789f",
	"res://src/gameplay/stadium/stadium_baseline_sites.gd":
	"e59935264c2da05b2e009048a089284006826094715e28f656c3f2b48450efff",
	"res://src/gameplay/stadium/stadium_boundary_observer.gd":
	"406b1050fd62c2077d6804ee28d23662dd88bf1b71c1ff786bab900d2391a08c",
	"res://src/gameplay/stadium/stadium_catalog.gd":
	"390844e539404bc78b303aeeac31b8c11d129b334fd1ca342baa0091577e1ea1",
	"res://src/gameplay/stadium/stadium_club_boundary_sweep.gd":
	"f87c563a798e14b154196b7de63c6ab735e191db4b30fbe8c2a5d9bd59807ca1",
	"res://src/gameplay/stadium/stadium_curved_canopy_sites.gd":
	"8b4dfc28ab41a3e8b3f7883d5457640e19b006b975896779641d449cf02e1399",
	"res://src/gameplay/stadium/stadium_curved_lower_sites.gd":
	"96ade65b25151036696636a86c6f09ceeeabe54dd8b9bab00599b6b6f28cdef8",
	"res://src/gameplay/stadium/stadium_curved_stack_sites.gd":
	"be49339c61e0e42ddecb86a58e8cdc42846594ce0991d31b7a9e1a1765e7cc80",
	"res://src/gameplay/stadium/stadium_defender_routes.gd":
	"20ee83d92f23d2a021a34fd5b623793215f57157880dafbb95acb8febf813964",
	"res://src/gameplay/stadium/stadium_dugout_boundary.gd":
	"8e7cb6c7ede2e74c399df58ecb7bfe509a26ff0f0aedb23644baf39e3c0cf888",
	"res://src/gameplay/stadium/stadium_dugout_recipe.gd":
	"9426ec13fc1ab673cafd856c0611dbd6aa6f90056d0315197cfb6313f6cc38a4",
	"res://src/gameplay/stadium/stadium_fixture_environment.gd":
	"26d2474552740c0624dc425b6a804c9c0268d7bd3c0a9ef99e7e242050e159e3",
	"res://src/gameplay/stadium/stadium_foul_pole_sites.gd":
	"1e5f4c4c106c3b15f587ab2d46a81ec64d10ddafe434919643b973c51f067ff1",
	"res://src/gameplay/stadium/stadium_grand_i_definition_v1.gd":
	"a17d2ed8c77ea44dddcbed5562b6a38d9b61684e310488e76de756a015194772",
	"res://src/gameplay/stadium/stadium_grand_ii_definition_v1.gd":
	"520354f5f4af62f9f5f45548b07bb5f99d917bde0ceef988035aadc950e3a91b",
	"res://src/gameplay/stadium/stadium_grand_iii_definition_v1.gd":
	"3c2b477ee179f6b3ac8152d2afd8faa2f9bc804d779a306349d005b506b8e500",
	"res://src/gameplay/stadium/stadium_grand_three_stack_sites.gd":
	"03d86cb7464688a0a3ec861ca6d7b3a43ca55c6b0772063a362b25b43e99c414",
	"res://src/gameplay/stadium/stadium_height_boundary.gd":
	"6f39aff94fd087469348afa40ebf55799d07ac0b4f1407d66ad4101d803e388f",
	"res://src/gameplay/stadium/stadium_height_wall_recipes.gd":
	"30db6125b6c027ad762ebf4efbf84610f461c0f5def0c61f1591859cd90a768c",
	"res://src/gameplay/stadium/stadium_hillside_definition_v1.gd":
	"639335c9bb1e3cbfdc6d93738dba0e053f548df156dcef30dab6871e298387e7",
	"res://src/gameplay/stadium/stadium_hillside_public_boundary.gd":
	"79ce2e00f98d31e9a40c1303659cff29f1ad473ce59d4fdab969f39ef4b06906",
	"res://src/gameplay/stadium/stadium_hillside_terrain.gd":
	"804c48647be68caabb608a33ae252ec6491f1a87045621fa12dde1ba6374918d",
	"res://src/gameplay/stadium/stadium_long_yard_definition_v1.gd":
	"84d68ef56a9a4e7b943e8c2e03aacc1aaa5aab76e0c71fa76f6ae3b579464495",
	"res://src/gameplay/stadium/stadium_long_yard_lower_roof_sites.gd":
	"a56270540ba3ae0dd9dbdd670a65c4634caebc3bb28b50f3fed244b061b88106",
	"res://src/gameplay/stadium/stadium_lower_transition_sites.gd":
	"d8119bceb6e56543fdfb14d598a7dfd72e8b24f53f42e933fb3cc159359efb22",
	"res://src/gameplay/stadium/stadium_npc_ac02_public_graph.gd":
	"7c7a63a44feb7c1e4fa443c9241cb084744c4c4381870d5e372f3abd5546c367",
	"res://src/gameplay/stadium/stadium_npc_candidate_identity_v2.gd":
	"e4bc2c0eda86b8180d70326d7cc8e0d13f491e7fd2369420dbf40ea0c6260aa6",
	"res://src/gameplay/stadium/stadium_npc_candidates_v2.gd":
	"dc911ebeda07c303b35c8e745fd092e86125b90067cfb04ef6da0ecdd744a3be",
	"res://src/gameplay/stadium/stadium_npc_club_two_definition_v1.gd":
	"0a9ea1b1b59352e52858b2f04faf5221fb149f96c503ed9a3e5453429a588208",
	"res://src/gameplay/stadium/stadium_npc_expanded_two_definition_v1.gd":
	"d26c4356221af99ad29cfdb92f6185473169c4b193139d7884243bd09d2341a2",
	"res://src/gameplay/stadium/stadium_npc_manifest.gd":
	"a9bcacfacafb12f25d5a5fa86d7fff8537936f7fd071173c36583e5e1994bef1",
	"res://src/gameplay/stadium/stadium_npc_mogul_one_candidate_v1.gd":
	"aa2df62229dfc470f961707c5c712820e4f533d832f3daf9292d1185e7b6bbd2",
	"res://src/gameplay/stadium/stadium_npc_mogul_one_contract_v1.gd":
	"3ae7d5de511579fa0b1a90232ff4d62cdf5af7fc955422785fbba6860f99ce25",
	"res://src/gameplay/stadium/stadium_npc_mogul_two_candidate_v1.gd":
	"d868cd0fc90c6e791fb753938236743d0aa09e4dbf5cede71b46db7b510a5f26",
	"res://src/gameplay/stadium/stadium_npc_mogul_two_contract_v1.gd":
	"3c6cb6cc7ac8adb660d6d50ff48e3f567c4e8852fc0b71d124e22469227f0a81",
	"res://src/gameplay/stadium/stadium_npc_snapshot.gd":
	"8a79e9f07a81b74b489ab8ab2371520333fa932703d595d14eeb6e67b94750b9",
	"res://src/gameplay/stadium/stadium_npc_venues.gd":
	"087e08eb352c01059c3f38824bc713d2ec6d6ce91aaa073b59991b261a13da4c",
	"res://src/gameplay/stadium/stadium_pool_contract.gd":
	"94f06f487e3d020d5b26441a252e3e1c38d493ec588df69cda8735f40e8db9bd",
	"res://src/gameplay/stadium/stadium_pool_interior_v2.gd":
	"b855b7fd50069188a8426611cd164b0b4cb6a99bf3ff24a84435c14c5cd77ce0",
	"res://src/gameplay/stadium/stadium_pool_party_asset_integrity.gd":
	"5da71e546e50af6e69aaf1574655c463036ac72e6ab2043886c7828ce5be6a1e",
	"res://src/gameplay/stadium/stadium_pool_party_definition_v1.gd":
	"d61eace79317af91160e42ea9ee33057bb933a2fe798d72bfaddbda0e21d629c",
	"res://src/gameplay/stadium/stadium_recipe_boundary.gd":
	"a98381fd78d1f32fcd58ad7dbd2f29b29634c7b3572159980e781ffb6c66aca8",
	"res://src/gameplay/stadium/stadium_scoreboard_catalog.gd":
	"30482f13892d0245109e9cf9b7f63558620a53da433eda7542380257198d39ad",
	"res://src/gameplay/stadium/stadium_scoreboard_sites.gd":
	"1e06360bdbc88fb45cc4321b84a6393c6f90bbefa8c74a1e30757a2d6d3e18af",
	"res://src/gameplay/stadium/stadium_scoreboard_tier_sites.gd":
	"2877a534dce360a82dd15e54b6c81259042dfe6f0077889cee864d227fad6908",
	"res://src/gameplay/stadium/stadium_seating_layout.gd":
	"c3deb4bd8d844299438f0e0376185d57d545d0a02d365043762baa2a1e84983c",
	"res://src/gameplay/stadium/stadium_straight_stack_sites.gd":
	"42f9d01c4b0d4887d25b6243658ea85451aaec0d73de33e02ce76698bcf5f712",
	"res://src/gameplay/stadium/stadium_surface_rules.gd":
	"53ca09eff0ce6798aafec51ccbc07339edefdf16aee9b3852b7eeea7c2434f0e",
	"res://src/gameplay/stadium/stadium_timber_dugout_boundary.gd":
	"559c3ca40993c51c4b2a34902a165fbf78866259ae368bc618a93c00bf291dce",
	"res://src/gameplay/stadium/stadium_timber_dugout_contract.gd":
	"83ac392468373e1add76f9bbddd04917ab9be862985cf1fd2e511e6ced00277d",
	"res://src/gameplay/stadium/stadium_transition_concourse_sites.gd":
	"c8c0ec8ec0f2a21223bc631f232b63bebcf1413bef65e95ff2d277b3a1e07036",
	"res://src/gameplay/stadium/stadium_wall_recipes.gd":
	"2225255afd3ded7bddb8a94ac1ee639e91a4c2c77806e17f70db21f13fd822e5",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab.gd":
	"c194c59646f7bffb990fd384e79d47691286ab1c7df6612aaa1eb41190f32614",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab_defense_support.gd":
	"db8ba050b938c1be5a0fb3af8d17336408d784fba09b97f47bb19f8288edb16a",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab_presentation.gd":
	"580602076aeab451cd8e01a1af7b3718fc5faa92ead70649c6322c723ed4b464",
	"res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd":
	"0be889d48a37c9e5d017fcd234b2289cc8928a386605352557a6c7631ceeb9e5",
	"res://src/presentation/ball/batted_ball_body.gd":
	"e9a6f7a3096ecbc8d9109b32ab633503756f630559fc0d102c466585cc9fa9a5",
	"res://src/presentation/ball/pitch_flight_actor.gd":
	"1fd0bef6aada32afebb69cb25887a2d3a26758bd0ce5f0788a918b50533a2c98",
	"res://src/presentation/camera/ball_tracking_visibility.gd":
	"344e28784f900c6f660c55574330a8afc2d8c46b7149edfa28841957952253a8",
	"res://src/presentation/camera/match_camera_director.gd":
	"84f2cd886f686c6dbec4e7aa8a57d72f06c276d36f4b6bee076e33a46430aedb",
	"res://src/presentation/camera/stadium_wall_view_prisms.gd":
	"c84ce7c1b7eb913589c06e928ea7536dca51ee346203dd4ab9186ff9b137beda",
	"res://src/presentation/equipment/bat_actor.gd":
	"8f1021180ef1ea6312053b1a9b7ddf924cc9020097104fe58935eb2eeae670a0",
	"res://src/presentation/fielding/fielder_controller.gd":
	"020f096aaa95dd138cf0a95dd4f3b0d279cade0648453896fbe593dcb264b4b0",
	"res://src/presentation/fielding/stadium_hillside_defender_motion.gd":
	"c7cb93d6c94cfd1ef475489cb6570356952f403586f59ecf6beed5e3e7fe45ec",
	"res://src/presentation/players/player_avatar.gd":
	"f2bb9e1e1fa7ab7fd44d2d48d76804c866d0675512f3b4f70e6dca4c1b99c485",
	"res://src/presentation/season/season_app.gd":
	"52c5347475aebab63b95d514aa0e2224d8028e897de83ea8a6586c33953c6e69",
	"res://src/presentation/season/season_pages.gd":
	"a854246d43c79873067466df0e3b842157ebf0bcb2f0ccb5493a18ed14eca49f",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_board_v1.gd":
	"792fb4ec6ebe637fcfcf9da73137d2c509853106d655ed8d894d47162aad5411",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_boundary_body_v1.gd":
	"84eafa3bd93e0575b20903856363f9969d2c90c83490d32efbcce0d4fb6c8ca0",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_boundary_v1.gd":
	"2504c64ecb38dc928a247a5c7093e1febea3708ad6f19d50861cc227f7cd7456",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_display_v1.gd":
	"a5d25ac4d6f8df3b66bf8dc2e217d97363609555f8b12abe1d6ac9f35159b01b",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_dugout_graph_v1.gd":
	"5553a6c458f95058a9f5b7a6180d382868ba6b1545e0f840c2c4f2d73a1ff314",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_dugout_recipe_v1.gd":
	"3553fa43883384db280375a360f62de614e7075ac663dbacb8e207faba82b6a0",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_dugout_v1.gd":
	"3636efcc0031de01b4d5641cebb1e3222e7ab34b79af89fe68ac7968f21ce8af",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_foul_sites_v1.gd":
	"2ab9404223441636dfe3eff3da2b2d1ea7103f70e991ef5fe4c6839e8545e39d",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_graph_base_v1.gd":
	"626643c83ba07bfd9e6663b38149fe990f7c023ebc31edaeb9dee7e24452d68f",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_graph_v1.gd":
	"5d8e2b7457e43447586f3e4662858a828d4073a29feb6194475cbbe6cd449ef8",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_net_v1.gd":
	"f3cbf057bc0d6fc9f9af365559da99bd0f229cde07a4c06306b700d8f781a108",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_offset_graph_v1.gd":
	"527e6a7cc60709cca8bb9772289aadccf8224ff6e6e9b0b43641ad476669fa94",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_offset_panel_v1.gd":
	"48d3dcca61d4259132b874802e72c33e3867d76ea9cf0db1fa3deac8013adcc6",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_offset_recipes_v1.gd":
	"30dab7ddfd8f5809db0cb157617bba3e2490d4385bd793c2acc9b3bc8a3b69e4",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_pole_v1.gd":
	"c26dc68b91ed99688966c9309912107141d4166909a54d4eae57b02e54174fa8",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_primitives_v1.gd":
	"faaf94f839512f969a9c14ef59db68d93c95a3716f815a4115f165312c044346",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_seating_v1.gd":
	"d28788e587b25df03421419d6a3dc0e9d52b7fc17fdd86aaa9464aabfa1e7933",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_stand_sites_v1.gd":
	"e03f348257b3fc4a6f6131dd0b3205ec84596950ec54f97e0226686243ca5a58",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_stand_v1.gd":
	"2bd5b737763edf2e63ca9d641daf558495c4430210b66c336a3baf6c502510ab",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_target_v1.gd":
	"daed1056018b7681f9d65ad9f09d40f9d8799bc7832841719f3c0b441a961f13",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_v1.gd":
	"7c2a80cd6b1110be93799ccb7046272c745f22c830bb0b3536a39647c403c081",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_wall_panel_v1.gd":
	"ae0b28c49b45633ab652c4ed7452d952324b7859caa34f2935449fbe9a930c28",
	"res://src/presentation/stadium/npc_club_v1/stadium_npc_club_wall_recipes_v1.gd":
	"05cb8ade314b2a923d86948efd1ce23dd7c6f46e9e79baccd7738b22b6fcb243",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_bleachers_v1.gd":
	"dc128ab5b09190af1521dd8fc4e4b2e135522179364ac18d53b7937c9402d564",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_boundary_body_v1.gd":
	"f865ade87aba256305b178cd3b201ddffc33b701552d5b3f3239d02363e0c9a9",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_boundary_v1.gd":
	"b70e557ffa7623366179fdf39b7c162d91cd34bf9e25097b8939583f06e57760",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_club_v1.gd":
	"8c05fbbe6182a7c4e761942f04677695b088bacec397cf297c0eb4b969fa5ece",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_display_v1.gd":
	"ae384829742e399a36515c21dd9b788d96b8b342929e8ed39a1251711245dbfd",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_foul_sites_v1.gd":
	"f8f78f4f970568bb6333a2dc8ce17aa2a58309b51abc4e06a7a596a041444306",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_graph_v1.gd":
	"408139d524d156cfb3292cbc47f14e5eafff94bafbce377a7d6f4af9ecda89e2",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_net_v1.gd":
	"5c8b1e3984bbb4d559d8cadcc8a09c19710a7c937ef665a9eb7f6c7172367797",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_primitives_v1.gd":
	"a1a5c5cc3f0477c096e0e17cc637c2026609adc5220e077259ad0e7812fb5eab",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_seating_v1.gd":
	"fef573319b23476d9a78e1c2181dc623cd5d4f6f16f4e0596a29484163c026f0",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_target_v1.gd":
	"f56d1442fda50f884f746f505f07fe77c6fcbba8cc71b06fbd500c1a7fe55e92",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_v1.gd":
	"309016beb60b8512b3170e5d558e496cbfec248c6a386911c7b4f4baee96edf8",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_wall_panel_v1.gd":
	"63304c801975b7f04c2f0b2b2eba7065fee3de15a35b332110414ae024a7197e",
	"res://src/presentation/stadium/npc_expanded_v1/stadium_npc_expanded_wall_recipes_v1.gd":
	"08ba60132f26dd68676056ac27f24c3bff2c26e894c2b613b50ef113219a85f1",
	"res://src/presentation/stadium/npc_mogul_one_v1/stadium_npc_mogul_one_bowl_v1.gd":
	"6e93cabf649373a99de8c0eb168fed2761f7afb4a63ba3785699d5d91617b557",
	"res://src/presentation/stadium/npc_mogul_one_v1/stadium_npc_mogul_one_stand_v1.gd":
	"4173e62a3571f35ba0ffe93dd85b68e264e2e444421d230c7e2f29bd241bef1a",
	"res://src/presentation/stadium/npc_mogul_one_v1/stadium_npc_mogul_one_tower_sites_v1.gd":
	"b06003f131212251d7d92bb65f8035e3d3a020827df8da21b36e4c334ef52fcb",
	"res://src/presentation/stadium/npc_mogul_one_v1/stadium_npc_mogul_one_tower_v1.gd":
	"dc61ccf71986058f41c70899e87f8d413038ab9b199306bac6d5c636bce23b20",
	"res://src/presentation/stadium/npc_mogul_one_v1/stadium_npc_mogul_one_v1.gd":
	"fe02fe82779afbb47560e80b227ecc34b0318145bb745305f2802aeddb71c649",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_boundary_v1.gd":
	"0111ce0f523452d2b63faad82a432d99fc2acf7edc534b462269e8414e707496",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_graph_v1.gd":
	"cfeba134ed4eaec23c90d9525ba43e0df2986ea760b3b3e54c10df2c582d9698",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_height_graph_v1.gd":
	"5728bac6f756df588c1d2cb3557f6983d106d8a07bf752661c6f9d170fdef5c4",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_height_panel_v1.gd":
	"1402693b9cbe91a3de64dd29d4f61984447078b71b1b108dfed742c1f31c9682",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_height_recipes_v1.gd":
	"59f51b5f1361aee773d27609457b41a86efdb251e4a59ef26c786f378b99ad46",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_stack_v1.gd":
	"9b86fe0d42c6f5b9b269ad665e5885c5c2dc1b67d7b62243e11d7ba2de8b5d57",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_straight_v1.gd":
	"6823967a31c313c7f6af513772771c8dcb58bd9234e4c202359794a01fa951a4",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_tower_sites_v1.gd":
	"86e88c26085321e8ea8b3be8b1bc60c95b9396b1097f9bf51099376ddccbd2cc",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_tower_v1.gd":
	"5cc36d92c7dcaf599895e19fa53d1ff88d2c8290de010e81c17a994b828dfbc1",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_transition_sites_v1.gd":
	"57df9cf072ce3e40fe4ae7ba1c25e37036f3a310638f8a7646d65b921542ebda",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_transition_v1.gd":
	"4d91073044df6e1ee805b7f7bdc540cbb2dcb88f503d009b1bb38293ec0d633e",
	"res://src/presentation/stadium/npc_mogul_two_v1/stadium_npc_mogul_two_v1.gd":
	"f8fba4650dd7da5d6bda115db87a6aa4161dacbfdbb83bdd1fae41449eb3ec7b",
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_boundary_v1.gd":
	"40adbae31d956f96373def06acfc3415991d2c0993df215f2363e3ed671f351c",
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_graph_v1.gd":
	"c9472dd2fc773fe7dea49b701ebda52994c4d4d9874371835576d8599c6da3c7",
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_seating_v1.gd":
	"d18cf66a3d37b2ea60c19f26602b12a4bee4f6aec8d5e184e7504cdb3903953d",
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_v1.gd":
	"39261921875eedb0bf6058f6cb0829be36d11544400e9ff3a99e92f562d9fadd",
	"res://src/presentation/stadium/stadium_actor_cutaway_study.gd":
	"8a12c94f402ea835ee645cc190ec108749aef23e7cf904babf94d114d7ef14d7",
	"res://src/presentation/stadium/stadium_baseline_sightline_models.gd":
	"4fd7a994315acd1705f707ac36a18716d7f4304d2a2aa12bf464438c57d3d215",
	"res://src/presentation/stadium/stadium_baseline_stand_models.gd":
	"75e3700469a43ac53c6e3778a8de614893d7b154e66d5c5295bca341fd4ac13a",
	"res://src/presentation/stadium/stadium_club_boundary_study.gd":
	"c200f6aba39e2b0ae665608a5c6293dd84c721f6359b66702ebb491542c37bbd",
	"res://src/presentation/stadium/stadium_club_camera_director.gd":
	"962d0a3aaebdc67bf2cbcdb5d12b6dd685d18039c908e5f2f09ac658087d54a2",
	"res://src/presentation/stadium/stadium_club_field_visibility.gd":
	"d1f9efe0b32cb9904a95d03ddb303fed40e2cd8e8aed9ca7ab590f4c5adb646b",
	"res://src/presentation/stadium/stadium_club_models.gd":
	"c05a9a6c77791a12cbc9b5191240e3f96e94adec6aa239db5ce6e3f974eaa61f",
	"res://src/presentation/stadium/stadium_club_pitch_receiver.gd":
	"1330538a5b012c6f82af8665241d1d6efe381ca964bbe4c28f1d74e44f4e70ca",
	"res://src/presentation/stadium/stadium_club_receiver_visibility.gd":
	"ba9fab81b48e9c591fdbe00ff19ecd102a520beb235f4d50c908219845852778",
	"res://src/presentation/stadium/stadium_concrete_dugout_models.gd":
	"ac4ab6504e2c24b08e2693d1b0f821dcac2849b98b5a5be836eace0044c8ed21",
	"res://src/presentation/stadium/stadium_curved_canopy_models.gd":
	"6843c66ceed1b5af20cc59c625a8e1e76bbb641a0c7086b6690b62ff3051f4b8",
	"res://src/presentation/stadium/stadium_curved_lower_models.gd":
	"816a7a7792450d73440bce70f60e15d0be8446b03b16e8bf214cf596a28b7c17",
	"res://src/presentation/stadium/stadium_curved_stack_models.gd":
	"bf51952cac0741a4720664ad712a2c6fcce7d361a7883e536d4deb6af2319366",
	"res://src/presentation/stadium/stadium_expanded_camera_director.gd":
	"13044baf5de24345d9a34aa950d4da6684cb6c6c357cec06c819ed7b3a4c4790",
	"res://src/presentation/stadium/stadium_foul_pole_models.gd":
	"5e28063a3e8bc26412279df18861640c63604f8d3adbf8934f4363337d73eb53",
	"res://src/presentation/stadium/stadium_four_head_tower_models.gd":
	"4bfe5bb1b81e8f2db5698a0a8456863d790b8a605bb1cfa7c00b2f5840e30119",
	"res://src/presentation/stadium/stadium_four_head_tower_sites.gd":
	"71664f9063f38a142b0416ab7be21eec15207298bb0f432d335482b15af7441d",
	"res://src/presentation/stadium/stadium_game_stars.gdshader":
	"3a531d717a75acf1e32ca23d321aae76e0e57268ec3e1b1f179103db5a12b2db",
	"res://src/presentation/stadium/stadium_grand_i_camera_director.gd":
	"4fcf24a9ae7ec2c7c6680e9bde48b6c8dd3a115f7acca6aaa0a56c633585e39f",
	"res://src/presentation/stadium/stadium_grand_i_environment_v1.gd":
	"22d20804ef1b0046244863a783416e914acf1da4ba5fd360b8afa8d306e67300",
	"res://src/presentation/stadium/stadium_grand_i_lighting_v1.gd":
	"1a4f11af641ceca564e2abd7a9820e60459adc6f05f4667a23890b86068d98e9",
	"res://src/presentation/stadium/stadium_grand_i_public_boundary.gd":
	"54586e611e06bb0446d0afb9591cad0d9bf1487285cb40bac49c9b608b9c62c3",
	"res://src/presentation/stadium/stadium_grand_i_public_boundary_source.gd":
	"bd78c004d56528fcb148f0ac09a4dafd0cf5d41096bbe5879dd5d93cba86fe84",
	"res://src/presentation/stadium/stadium_grand_i_public_camera.gd":
	"bb6152127427b8fc5eda6b9aa5b6308bb9a357b51ba52b5d1f28cbf6125bdd1f",
	"res://src/presentation/stadium/stadium_grand_i_public_construction.gd":
	"2188367d2e77c982f1981dbde605661a41ef90cae6be19b7585890728efc0712",
	"res://src/presentation/stadium/stadium_grand_i_public_receiver.gd":
	"239cc081cd9c0f4f79ee7380cd037b1ee985d5e05f766bd8d966c77f050c020a",
	"res://src/presentation/stadium/stadium_grand_i_public_sweep.gd":
	"557c713f69fd45b456e7d15b508618ca5cd156a0b2639dea5ffd6ed1f840c215",
	"res://src/presentation/stadium/stadium_grand_i_public_visibility.gd":
	"7b7b49d3384a8e64e526c3dde52601790b3be8af63bbdb2ae54c0bd96a895867",
	"res://src/presentation/stadium/stadium_grand_ii_environment_v1.gd":
	"ffb7a989db965ce5551f2c491de033b95be3a5b559681062d656e3137ca451a1",
	"res://src/presentation/stadium/stadium_grand_ii_lighting_v1.gd":
	"cd11cb4ec907d6439f22a22f8648a640f43b82023225db3720353ea03ba1008f",
	"res://src/presentation/stadium/stadium_grand_ii_public_boundary.gd":
	"2f8ed7c54a29b94ae2e404ae57a61020ea081d4f93786129ac2eea6662c1f175",
	"res://src/presentation/stadium/stadium_grand_ii_public_camera.gd":
	"84c03542861f8b8627c061155eebf0c5c4cff8c3db00d55b78597f8e626d532c",
	"res://src/presentation/stadium/stadium_grand_ii_public_construction.gd":
	"ed5ceb346833223dbe582fa0d8ed4788345d4d870e7f4fe5ab18b55cdfed7176",
	"res://src/presentation/stadium/stadium_grand_ii_public_receiver.gd":
	"2c86d3676cd572238d5b7f1109913e5887539ac1848ac5ff6e51d2955f5b6b9f",
	"res://src/presentation/stadium/stadium_grand_ii_public_visibility.gd":
	"f10a28e8fefabd0e525bb12791e04c52b677f580e648406272c16b61f40044db",
	"res://src/presentation/stadium/stadium_grand_iii_environment_v1.gd":
	"9148abb9acd05916879ca5f9b8947a6587410ae11201926e0895cf84cf35d57b",
	"res://src/presentation/stadium/stadium_grand_iii_lighting_v1.gd":
	"688ceae01eff0b0dfa07263f290106f74208d24394b003adc0b5ebdb87dd1fed",
	"res://src/presentation/stadium/stadium_grand_iii_public_boundary.gd":
	"e23adbcd6e2f37bd9164076efd34381a59127a2a173e7509fa12a7b28fdd6ae9",
	"res://src/presentation/stadium/stadium_grand_iii_public_camera.gd":
	"d98baee1bca2f21d30c5f92a2371a2283cab96a272a48370bc958c5992e76f04",
	"res://src/presentation/stadium/stadium_grand_iii_public_construction.gd":
	"42194e237db6c501acb8305e84ff7a0aa57050971fbb99024e3e7ae380c95b5e",
	"res://src/presentation/stadium/stadium_grand_iii_public_receiver.gd":
	"7ca2ac552d022e67ce15bf8d2c5ae1434f4561c7f5451750117a61eb7f07e008",
	"res://src/presentation/stadium/stadium_grand_iii_public_visibility.gd":
	"ce74a8bb6fcd652060476e5c637db969cc56d7b9c48c9e10909bf4edf19bbaac",
	"res://src/presentation/stadium/stadium_grand_iii_venue_study.gd":
	"b2d008393250b4e4911bbd6546a2b480e8d956bc670e77710560ebc495f230d3",
	"res://src/presentation/stadium/stadium_grand_three_stack_models.gd":
	"d39bc2e7c4c205014f07f2439f3ce0f5c756842e5b2a9c613bf5b7c7047ce4a2",
	"res://src/presentation/stadium/stadium_height_wall_study.gd":
	"6ea91b74375790034a7252ed9b97cd06afe5292bc4034bd83ac6ce25e8cd032b",
	"res://src/presentation/stadium/stadium_hillside_boundary_body.gd":
	"81c7d9a2896f18aa01d4f99d13e44f6bcde14e50e84c1b0657441c1436c9b427",
	"res://src/presentation/stadium/stadium_hillside_environment_v1.gd":
	"aa3c1d022decfe68c683c90237b6640e99457cef87542a54fc2b5a4e6dd6bcfd",
	"res://src/presentation/stadium/stadium_hillside_ground_contact.gd":
	"ba11daed357799a08cdd18b20772a721767ce9f0be7a1c5eab146c5441c2dee8",
	"res://src/presentation/stadium/stadium_hillside_public_boundary_source.gd":
	"43b4c920c21955592c3ee3810fe96cb49b3014ad340af0b0cffbe55bd9217ae2",
	"res://src/presentation/stadium/stadium_hillside_public_construction.gd":
	"21cba6f46b4a680dc82355dbb91a9dbce2afedbe000a2c5f3d4d1715ee939fc2",
	"res://src/presentation/stadium/stadium_hillside_public_contact_adapter.gd":
	"9644b020e560600324c41e45af2429ce4b3ea57ea5f5ce5fa77fd59e1972e548",
	"res://src/presentation/stadium/stadium_hillside_public_receiver.gd":
	"ccfd472ed27e816f6472e1e401921eacf4f06793d8d074b765f9a08a0ed44b78",
	"res://src/presentation/stadium/stadium_hillside_public_support.gd":
	"02b762573c4220ced8a8b7d166cae6a252216b6b409070c4d87395175e1efcd7",
	"res://src/presentation/stadium/stadium_hillside_public_visibility.gd":
	"f1fd51ee8e3b9be72425164a1c648d9edce4e293f2d0444724492d570d8e1ceb",
	"res://src/presentation/stadium/stadium_hillside_terrain_models.gd":
	"883ae470bc3ee6c52c95203e9b0bf6f4c9826ffdfb28e27acac85ea1c628545f",
	"res://src/presentation/stadium/stadium_long_yard_camera.gd":
	"3c593b82c15c34926a5fbd5a0f913679454dc1d744ef4d8e59aa14541f56eedb",
	"res://src/presentation/stadium/stadium_long_yard_environment_v1.gd":
	"b3325a82ae1e7659fe129a66fab011d71cf360da84e19df345fb5894a939f351",
	"res://src/presentation/stadium/stadium_long_yard_lower_roof_models.gd":
	"6e9e2327dceff712af8cdfd41c13ea2ccdabd3a4b14bd9e8fe5b6760a5efdacc",
	"res://src/presentation/stadium/stadium_long_yard_public_boundary.gd":
	"215aebed0e9a7b399cc4cdaa48345c7874d78e12798785e1d556b190aabf1039",
	"res://src/presentation/stadium/stadium_long_yard_public_boundary_source.gd":
	"86cd303e1402c17d3faad0ea7c876b8872ae068f9a9faea2acc79c0fc59945b6",
	"res://src/presentation/stadium/stadium_long_yard_public_camera.gd":
	"c5ed4eb82a061ac44695ff9fb1097c7e9c7e93987beac75f217ecbbee4829659",
	"res://src/presentation/stadium/stadium_long_yard_public_construction.gd":
	"3077470204e07a9786241bfb720ec0449ed1f11f75272e2474e5f4c31c554860",
	"res://src/presentation/stadium/stadium_long_yard_public_receiver.gd":
	"5f37c5fa66c5024f9ecea9c1f89a0d06cf49f8cc4ff4eb5544d1139818076adb",
	"res://src/presentation/stadium/stadium_long_yard_public_sweep.gd":
	"eaae2c5bc8215b057b58257b263415388737da940397169c726aa479cd21dd61",
	"res://src/presentation/stadium/stadium_long_yard_public_visibility.gd":
	"a0372fd5afdbe47c700966e271d5240deb7de6041efc91714424e59ccff9fd2f",
	"res://src/presentation/stadium/stadium_lower_transition_models.gd":
	"6906b2fb169942c79578bb2b2821f3d4b4fe7abbe4117c0107ed8b239d51407c",
	"res://src/presentation/stadium/stadium_mogul_one_camera.gd":
	"092ad0eead86cce89d9682500ba90525fe87247073e52c1b97ce3db6b09c48c9",
	"res://src/presentation/stadium/stadium_mogul_two_camera.gd":
	"2b89096ce0709a623e19149ac0fc75e2f791fb366e0da18a9df5fb319ab04f62",
	"res://src/presentation/stadium/stadium_mogul_two_visibility.gd":
	"9d7dc99d02c898f461554eda44183a85f298f1a679ba45f3ad856cadc4630461",
	"res://src/presentation/stadium/stadium_mounted_scoreboard_contract.gd":
	"d20b7044e83156786437685cc49e38384ee58990d5bb102b2449e0aa242b9458",
	"res://src/presentation/stadium/stadium_net_models.gd":
	"e54036913c3937c78d18cdfe857bd54a55ec883158f27eac13aa7e1080185398",
	"res://src/presentation/stadium/stadium_npc_ac02_public_boundary.gd":
	"be575a88d5581110152cb474e4c646eb6bfae01ff2e7cb75f37e62d172ad6cca",
	"res://src/presentation/stadium/stadium_npc_ac02_public_boundary_source.gd":
	"59fd392368b4ba96cb1b292b59974f780219c8b98847b2e8ff349a88cec701e4",
	"res://src/presentation/stadium/stadium_npc_ac02_public_camera.gd":
	"4dc6ec4df48f2e26989cace001e915bcf68e179829f50dd3bc0dd5769bd10745",
	"res://src/presentation/stadium/stadium_npc_ac02_public_construction.gd":
	"24873743264f1854870ff1c215796da04c2d05fc1ec16c0e9e00f543d17c789b",
	"res://src/presentation/stadium/stadium_npc_ac02_public_guides.gd":
	"58f5350b895cfba5260b5f9c45709fecbbd8e4f9d70e04736f5dc664d2683f87",
	"res://src/presentation/stadium/stadium_npc_ac02_public_light_sites.gd":
	"90e850ddaa6cc8bc3a35dc7b837af039e46020ece3b4beb689b5a63eda36d6fc",
	"res://src/presentation/stadium/stadium_npc_ac02_public_receiver.gd":
	"4570a9d1f45ba8cf481bcbe2a2b6ebee9fd6f6a4569c0c8fedef88b4a069ba44",
	"res://src/presentation/stadium/stadium_npc_ac02_public_sweep.gd":
	"c0a8a865fa247f00a2813fe267c154e8588c2cc742b831d1bff6eec58e8d8aa6",
	"res://src/presentation/stadium/stadium_npc_ac02_public_visibility.gd":
	"dd921f01e0bf6a3d393ecd29c599ed46a77e183a6041658a221d8bd6fd12cf6a",
	"res://src/presentation/stadium/stadium_npc_ae02_public_actors.gd":
	"7aae63daf4a71d1de721c89f356d1a122d26cd38ccbd92003039621e1d27ef0c",
	"res://src/presentation/stadium/stadium_npc_ae02_public_camera.gd":
	"9bb2fdd296f8dc4d3f4a306ae17e06a9a69bd8a11858c7cbbb0b78d6f4157d59",
	"res://src/presentation/stadium/stadium_npc_ae02_public_construction.gd":
	"d8476e1b3c97cdcb53cf3c1a0ceffd17bcafd42b590dde3079ad3a01231a11eb",
	"res://src/presentation/stadium/stadium_npc_ae02_public_receiver.gd":
	"4f0b64b327be3fba5bf85dc81a86d111b7adc0f3113645964249f5300e6f0bed",
	"res://src/presentation/stadium/stadium_npc_ae02_public_visibility.gd":
	"6ec9912aac4077e92fa5c742a9b49273ecbdff484198793e5451497fa9aa677b",
	"res://src/presentation/stadium/stadium_npc_am01_public_boundary.gd":
	"780de2fb317278818504b837ae61d10b7066a957742b88ab030d2bb069c57877",
	"res://src/presentation/stadium/stadium_npc_am01_public_camera.gd":
	"d351aadb27552bb23b467aaa6962e4a82f84db9ba519222e922497e2a39b3fd3",
	"res://src/presentation/stadium/stadium_npc_am01_public_construction.gd":
	"a6dd7a128c1ef8dcf10b11f8cea5613989fd4f20089b61202d538bef6402727f",
	"res://src/presentation/stadium/stadium_npc_am01_public_receiver.gd":
	"d06a013986566dd43ff1285a47f273736f6f39647b90d10d31e43620caf81ebf",
	"res://src/presentation/stadium/stadium_npc_am01_public_sweep.gd":
	"948e3f990a7d0c8b2403a527e7edb4da5197b60da5f001dc3c863f3bcdaca5e3",
	"res://src/presentation/stadium/stadium_npc_am01_public_visibility.gd":
	"0a5dd61f9561cb98186c0cc6ccb48fc3c86317b911e0114709bd76b400eadc6a",
	"res://src/presentation/stadium/stadium_npc_am02_public_boundary.gd":
	"1e20d72c1bc36bc4891acc268981ab3348b7666ce2875b156469e1bc2272ef9e",
	"res://src/presentation/stadium/stadium_npc_am02_public_camera.gd":
	"ab7b4a9a2760707e9e68f54f0d909516a34fa898648a521c91e59e28e9094679",
	"res://src/presentation/stadium/stadium_npc_am02_public_construction.gd":
	"8964e9d5e0ecbd1309d5fbb550838312f34692eb67954a5dd58391c1ab21a287",
	"res://src/presentation/stadium/stadium_npc_am02_public_receiver.gd":
	"3b82720563feb9df483ad4ccd8bd0845b411600e05cd96e6ebbfb71a4a7c1c28",
	"res://src/presentation/stadium/stadium_npc_am02_public_sweep.gd":
	"63e5c3cdb56dbd5221e8eb9678ac763ad2f0858c71c09b3d6bf67cf891c30830",
	"res://src/presentation/stadium/stadium_npc_am02_public_visibility.gd":
	"961dab13e009462ace8cb8e62c2bbe68aec3f5231235d7655656a5fc485ce3d7",
	"res://src/presentation/stadium/stadium_npc_candidate_construction_v2.gd":
	"e69c1982526b666e808fc198eb284adc4dae095561afecaca01e523fa19b74ad",
	"res://src/presentation/stadium/stadium_npc_candidate_routes_v2.gd":
	"820a8bbbafc41e22250f9d8906461469acf297053ff6ba3b60e856067bb00cae",
	"res://src/presentation/stadium/stadium_npc_public_property.gd":
	"e8a2d6da7ed8926597ef0405013dd27a0c9908eeb60fba79a4fba220e3b6962c",
	"res://src/presentation/stadium/stadium_npc_retained_actor_cutaway.gd":
	"f578e0c28e35ae43cfc442cf70d69e974e38e0a6f1b593b0a99dc1bbe174e504",
	"res://src/presentation/stadium/stadium_npc_retained_ball_readability.gd":
	"6706e1f4b7bce69037cd311504f0317d05bbd3311aa2905c408f6d1d78f1bfe6",
	"res://src/presentation/stadium/stadium_npc_retained_club_boundary.gd":
	"e47c6fe7d6860bab0e20bbdb9acdd3504d00d2907e73d403ebd8afd3320f2fc9",
	"res://src/presentation/stadium/stadium_npc_retained_club_receiver.gd":
	"4f6d7f889e03da1b2fbd7176d838750c1f6f7b6b1aefecac1c6e342a86812b65",
	"res://src/presentation/stadium/stadium_npc_retained_club_sweep.gd":
	"e4429bc74b75ddeed1101a8d7273c6ee3ded0445b6a920178a18a30843272393",
	"res://src/presentation/stadium/stadium_npc_retained_geometry.gd":
	"4111690785527c210f27429e63a7f22b044816cc67757d0927f0e1457fd6b5ef",
	"res://src/presentation/stadium/stadium_npc_retained_property.gd":
	"47773ef76cb7266fc0e57b6bdf2a7cdfe623bcf72bda2f06b4254550af0b6ad5",
	"res://src/presentation/stadium/stadium_npc_retained_receiver.gd":
	"c591e3a65504373d70641681e703e5b8e008f73ae327df67c5fb01e04138f79b",
	"res://src/presentation/stadium/stadium_npc_retained_visibility.gd":
	"45577b4c0d9de3cc09beb609317dc93ca559aecddd92b32a5a070bfe3992da03",
	"res://src/presentation/stadium/stadium_paired_receiver.gd":
	"4a5b8429e56c31a8b29e6a22c783e5a8bfa422e0191cb6eebf4a0b44c40bccaf",
	"res://src/presentation/stadium/stadium_pitch_receiver.gd":
	"743274083e25dbc6ff7c0bcb57a531d8e2c72c53ef43920a9f7a4afe167203a3",
	"res://src/presentation/stadium/stadium_pool_models.gd":
	"f1a52e86332860738bf473fce8bfa4a503049e43528a0e28b24dcaed9d121b76",
	"res://src/presentation/stadium/stadium_pool_models_v2.gd":
	"0c87e65213cdb81e092a9d25e08daed2bb3ed4800927a0e37868db1fecc3d6cf",
	"res://src/presentation/stadium/stadium_pool_party_environment_v1.gd":
	"db15336d5518d3a50f02764b43a3dd4c0073dc0fde061c7a14ea5c5d37f743e3",
	"res://src/presentation/stadium/stadium_pool_party_public_boundary.gd":
	"f4eecd48d17f6b7c42c6ff0e6afa555093a5040bc35e3f4b68963150c313b06a",
	"res://src/presentation/stadium/stadium_pool_party_public_boundary_source.gd":
	"d329a6e28b86d9a89fa6ffdcdd78ecdcde1b9f2f1fb6ebf331bed387cf263bb5",
	"res://src/presentation/stadium/stadium_pool_party_public_camera.gd":
	"0e6041395051046bca16340dcb74af4f11ee7ba5e178fabcee019ca2fccc7a10",
	"res://src/presentation/stadium/stadium_pool_party_public_construction.gd":
	"9256729a36f24bc6a74c9ea852d4ce3d6d92324bb4e0064a9047c202c843eb1a",
	"res://src/presentation/stadium/stadium_pool_party_public_receiver.gd":
	"086b00f89b1bb0a613af3e18063d024ae4ed9c9bab94f65473a373ce3511f1e7",
	"res://src/presentation/stadium/stadium_pool_party_public_sweep.gd":
	"0f55709b40515cb897470aa440e642ad06ab7689ded07f9d95e1c49c58c8001e",
	"res://src/presentation/stadium/stadium_pool_party_public_visibility.gd":
	"0a7cc219be876b3e4de07d20eeb7b871d554819ad18b6b7d78176f8aebe2871d",
	"res://src/presentation/stadium/stadium_pool_party_runtime.gd":
	"c1689a623a105b8a19f6b93086e4d3b30753b8c687a1e770cbd0715bebaed87e",
	"res://src/presentation/stadium/stadium_premium_light_tower_models.gd":
	"ce1356ae6f1fc11c6363b2aa3f1bd03ba950a5da1813e88f780f862cddb6ad6c",
	"res://src/presentation/stadium/stadium_premium_light_tower_sites.gd":
	"6c0e0e8c821e8f0ade13fe7ba7223521c4572ba8acfb064df720e0ceb8b738cc",
	"res://src/presentation/stadium/stadium_property_geometry.gd":
	"b0d33c030cb8bb7fd2e65c7a03f82a069f2184693dedef1fbcded5aac3571375",
	"res://src/presentation/stadium/stadium_property_runtime.gd":
	"99803304dbef3335d4d0b5be38c42d1512a94f0424ba9289a4a66c56240cc3e8",
	"res://src/presentation/stadium/stadium_receiver_net_models.gd":
	"cec34955f5d8d52b9a7df68034667cb2ba10fab29aaf612f257f0fe20a2ad7ef",
	"res://src/presentation/stadium/stadium_receiver_visibility.gd":
	"6e91b28a5d7ff5282e531efa2df0965ec2b5076f82ff734ab71446edf13f007d",
	"res://src/presentation/stadium/stadium_scoreboard_display.gd":
	"a0d660fe489aaf487b8dca84d350e83efb41163abd39d75385319c45fdcb151c",
	"res://src/presentation/stadium/stadium_scoreboard_models.gd":
	"ab5d5f2c6b49d6d9f47830cf4e83dd7acd1611f92bfddaca8b087c50490851d1",
	"res://src/presentation/stadium/stadium_scoreboard_readout.gd":
	"5aeca515729de240e4fa18772ee56ab52aed62746b85a5f69ecc3b179727ae39",
	"res://src/presentation/stadium/stadium_scoreboard_tier_display.gd":
	"42f93d4acd2d8b4dfc9b25d8fdb40c9df2fa2128dac02e720184df6e703317fb",
	"res://src/presentation/stadium/stadium_scoreboard_tiers.gd":
	"b8ffe92afcf58cd0ec684d42006f5a86ab4fddd7683d80480ca276c4323bb921",
	"res://src/presentation/stadium/stadium_seating_models.gd":
	"56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb",
	"res://src/presentation/stadium/stadium_starter_models.gd":
	"c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
	"res://src/presentation/stadium/stadium_straight_stack_models.gd":
	"205a6fac539b4de8b51e59b088274d6e6794e0f2725a23d22b1c0a681b5720ad",
	"res://src/presentation/stadium/stadium_target_models.gd":
	"0334e3bc2588f17a2a7ec1f6d64209dedea8336c67461930415248f228d7ba0a",
	"res://src/presentation/stadium/stadium_target_receiver.gd":
	"99341f1fbc0040236183eed3fb0693444db8bee10ba9b339f550e5f15b12d78b",
	"res://src/presentation/stadium/stadium_timber_dugout_models.gd":
	"e12ec8c7dd758229202a51d4f5111e0bbcf5dc55a49930495802e91977886566",
	"res://src/presentation/stadium/stadium_transition_concourse_models.gd":
	"7a39445aeaeec6d3963bc981856aaa17e84913970d9382d392028fdb71ff8170",
	"res://src/presentation/stadium/stadium_wall_panel_models.gd":
	"aa2cb103cf6998f81466c9173bdb3eb206a91835f84857e73380ca98e38ada7b",
	"res://src/presentation/stadium/stadium_wall_render_quality.gd":
	"a342c1bda3e7c5d4d3d8f004eb76d6044a0f7a7305181429226f3c2e3c8c39d7",
	"res://src/presentation/stadium/stadium_waterfall_models.gd":
	"49e65674e040be17db057d883be28702e80934ac29463ae6156cdd0183e9409c",
	"res://src/presentation/stadium/stadium_waterfall_sites.gd":
	"22e1e5d03f42510c588b622bc6e20df2aa640bff8f2b05eff183e77826c187d9",
	"res://src/presentation/stadium/stadium_yard_light_models.gd":
	"28e58ea8f4dceac92466f4510a97fb28649b9694b1149f98ddf8503aa600d1b9",
	"res://src/presentation/ui/play_sounds.gd":
	"f35dcf43167242f16a4e0a16c51b6f24dc779627db2bf3a4727bb658a4f1913e",
	"res://src/gameplay/season/stadium_surface_night_human_evidence.gd":
	"9c9094186c416260f76bb980957b0826398d849dc35a655ece07cda01f6d034e",
	"res://src/gameplay/simulation/stadium_surface_night_report.gd":
	"58d44bac6fd79a94f2a0d44a167afb2c9244a3558658009d5c47112b1fd85b70",
	"res://src/gameplay/stadium/stadium_surface_night_layout.gd":
	"c65ad02b11de75add987a2d085e4bde5dc43b16c5b39a7d2a2d40afc8a04eb6c",
	"res://src/gameplay/stadium/stadium_surface_night_snapshot.gd":
	"932547bb0a4989f63407c4bc80c53b9fe48ed42982d793eab1adee8fb6924715",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab_feel_support.gd":
	"f04ac2b981b397049d71ada884a397b37028b2ccf0af39190ebd138be7b25f7e",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab_pitch_call.gd":
	"5a856d0f190d38e6be878ae568fa607ae1bd57c7ac7f3911f50761e3b6cbcc8f",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab_swing_support.gd":
	"ff81e93c0633eed0a027dd877276897da2f94d550f41a192cf63aae194ad2bdb",
	"res://src/presentation/ball/ball_visibility.gd":
	"ccdded612a43c7276b8c239b3e513befd217fde79602190ccf98b3673d8f13a1",
	"res://src/presentation/stadium/stadium_surface_night_palette.gd":
	"9ff15aa6983bb60c39dfb984bb874f7f0236f66e6b2dffbb69da121f617901d9",
	"res://src/presentation/stadium/stadium_surface_night_preview.gd":
	"41c144e22ddec81cb657efa0e41722c6d8741a1f9e8c05c2170ec9a48e5f2171",
	"res://src/presentation/stadium/stadium_surface_night_runtime.gd":
	"69dec25398a1fbe4a817d510870d572afbdde63c1c15a396f176a106b659c664",
	"res://src/gameplay/stadium/stadium_surface_terrain.gd":
	"1c076efa17f27a3a4d9d0a0f15192535661955534663a34fe370e2c4c490ac75",
	"res://src/presentation/stadium/stadium_surface_terrain_runtime.gd":
	"5fbc2eda1e9169f4a0b2c2a4d45841b3c97739e80fc0d0ff019b90f74a55c242",
	"res://src/presentation/stadium/surfaces/surface_finish.gdshader":
	"5112d722de692aa6b7c8a6e7cf0c9e02e022dc8d8acb75b8017f860dcc77ce2e",
	"res://src/gameplay/stadium/stadium_flag_items.gd":
	"6de333b55b44c29822c263fba2403ae63e315093e0681165e918fd276019f4f6",
	"res://src/presentation/stadium/stadium_flag_models.gd":
	"4e87934fe90a3467b79ee8496307c584b244f1125f8d839fb12cc5df4669592f",
	"res://src/presentation/ball/wiffle_ball_visual.gd":
	"b555b60b83ec0132e0b35ee17674343b5d626149c9a3da9e67027ba0527d0ae6",
	"res://src/presentation/stadium/stadium_night_ball_style.gd":
	"67b01b0365e52a3aff2d73fca65db425f8dd6bceec63cd1a2b33ae5e53a27b5d",
	"res://src/gameplay/stadium/stadium_ground_props_items.gd":
	"db89a24bb8fe41b174345d7ffac8870eb218e94fed6a0eaa08540c431fffc8f7",
	"res://src/presentation/stadium/stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4",
	"res://src/gameplay/simulation/physical_stadium_contacts.gd":
	"e069f9c4ce4cc724e0008f699b30d572f8bae76f94148f4fa2bb3a5524d97d41",
}


static func supports_definition(id: String, revision: int) -> bool:
	return (
		(id in ["AY-01", "AE-01", "AC-01"] and revision == 2)
		or (
			(
				id
				in [
					"AE-02",
					"AC-02",
					"AM-01",
					"AM-02",
					"LONG-YARD",
					"GRAND-I",
					"GRAND-II",
					"GRAND-III",
					"POOL-PARTY",
					"HILLSIDE"
				]
			)
			and revision == 1
		)
	)


static func definition(id: String) -> Dictionary:
	if id == "HILLSIDE":
		return StadiumHillsideDefinitionV1.payload()
	if id == "POOL-PARTY":
		return StadiumPoolPartyDefinitionV1.payload()
	if id == "GRAND-III":
		return StadiumGrandIIIDefinitionV1.payload()
	if id == "GRAND-II":
		return StadiumGrandIIDefinitionV1.payload()
	if id == "GRAND-I":
		return StadiumGrandIDefinitionV1.payload()
	if id == "LONG-YARD":
		return StadiumLongYardDefinitionV1.payload()
	if id == "AC-02":
		return StadiumNpcClubTwoDefinitionV1.payload()
	if id == "AE-02":
		return StadiumNpcExpandedTwoDefinitionV1.payload()
	if id == "AM-02":
		return StadiumNpcMogulTwoCandidateV1.definition()
	return (
		StadiumNpcMogulOneCandidateV1.definition()
		if id == "AM-01"
		else (StadiumNpcCandidatesV2.definition(id))
	)


static func identity_prefix(id: String) -> String:
	return (
		"npc:"
		+ id
		+ (
			":r1:"
			if (
				id
				in [
					"AE-02",
					"AC-02",
					"AM-01",
					"AM-02",
					"LONG-YARD",
					"GRAND-I",
					"GRAND-II",
					"GRAND-III",
					"POOL-PARTY",
					"HILLSIDE"
				]
			)
			else ":r2:"
		)
	)


static func _visibility(id: String) -> StadiumNpcRetainedVisibility:
	if id == "HILLSIDE":
		return StadiumHillsidePublicVisibility.new()
	if id == "POOL-PARTY":
		return StadiumPoolPartyPublicVisibility.new()
	if id == "GRAND-III":
		return StadiumGrandIIIPublicVisibility.new()
	if id == "GRAND-II":
		return StadiumGrandIIPublicVisibility.new()
	if id == "GRAND-I":
		return StadiumGrandIPublicVisibility.new()
	if id == "LONG-YARD":
		return StadiumLongYardPublicVisibility.new()
	if id == "AC-02":
		return StadiumNpcAc02PublicVisibility.new()
	if id == "AE-02":
		return StadiumNpcAe02PublicVisibility.new()
	if id == "AM-02":
		return StadiumNpcAm02PublicVisibility.new()
	return (
		StadiumNpcAm01PublicVisibility.new()
		if id == "AM-01"
		else (StadiumNpcRetainedVisibility.new())
	)


static func supports_snapshot(snapshot: Dictionary) -> bool:
	if (
		not snapshot.get("manifest") is Dictionary
		or not snapshot.manifest.get("id") is String
		or not SeasonOwnership._whole(snapshot.manifest.get("revision"), 1, 2)
		or not supports_definition(snapshot.manifest.id, int(snapshot.manifest.revision))
	):
		return false
	var version: int = (
		StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
		if snapshot.manifest.id == "HILLSIDE"
		else (
			StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION
			if snapshot.manifest.id == "POOL-PARTY"
			else (
				StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION
				if snapshot.manifest.id == "GRAND-III"
				else (
					StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION
					if snapshot.manifest.id == "GRAND-II"
					else (
						StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION
						if snapshot.manifest.id == "GRAND-I"
						else (
							StadiumNpcSnapshot.FINAL_FIXTURE_VERSION
							if snapshot.manifest.id == "LONG-YARD"
							else StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION
						)
					)
				)
			)
		)
	)
	return SeasonOwnership._whole(snapshot.get("version"), version, version)


static func source_qualified() -> bool:
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime.source_qualified")
	var ac02_result: bool = _ac02_passive_01_source_qualified()
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_source_qualified() -> bool:
	# The original whole-source profile remains exact; current composition is separate.
	# Never accept independent old/new hashes, which would admit an unreviewed mixture.
	if StadiumNpcSourceQualification.matches_original(SOURCE_PINS):
		return true
	return StadiumNpcSourceQualification.matches_current(SOURCE_PINS)


static func _property(lab: PitchBatLab) -> StadiumNpcPublicProperty:
	if not is_instance_valid(lab) or not lab.has_meta("stadium_property"):
		return null
	return lab.get_meta("stadium_property") as StadiumNpcPublicProperty


static func _live_lab(lab: PitchBatLab) -> bool:
	return (
		is_instance_valid(lab)
		and lab.get_script() == PitchBatLab
		and is_instance_valid(lab._pitch_actor)
		and is_instance_valid(lab._primary_fielder)
		and is_instance_valid(lab._ball_play_resolver)
		and is_instance_valid(lab._camera)
		and is_instance_valid(lab._camera_director)
	)


static func _public_context(
	lab: PitchBatLab, property: StadiumNpcPublicProperty = null, strict: bool = true
) -> bool:
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime._public_context")
	var ac02_result: bool = _ac02_passive_01_private_public_context(lab, property, strict)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_private_public_context(
	lab: PitchBatLab, property: StadiumNpcPublicProperty = null, strict: bool = true
) -> bool:
	if (
		not _live_lab(lab)
		or lab._match_state == null
		or lab._match_state.get_script() != MatchState
		or not lab._match_mode
		or lab._configured_match != null
		or lab._npc_season == null
		or lab._npc_season.get_script() != SeasonState
		or (not lab._managed_match and lab._automation == null)
		or lab._stadium_ledger != null
		or lab.pool_active_receipt != null
		or lab.pool_controller_active != null
		or lab.hillside_private_runtime != null
		or lab._hillside_private_owner_identity != null
		or lab.has_node("HillsidePrivateRuntime")
		or StadiumPoolBoundExtension.requested(lab)
		or StadiumPoolOwnedExtension.requested(lab)
	):
		return false
	for marker: StringName in (
		StadiumScoreboardRuntime.AUTHORING
		+ [
			&"stadium_npc_retained_lab_only",
			&"stadium_npc_ay02_installed_lab_only",
			&"stadium_npc_ay03_installed_lab_only",
			&"stadium_candidate_only",
			&"stadium_npc_runtime_interrupted",
			&"stadium_npc_runtime_restoring"
		]
	):
		if lab.has_meta(marker):
			return false
	var snapshot: Dictionary = lab._match_state.stadium
	if (
		not supports_snapshot(snapshot)
		or not snapshot.get("binding") is Dictionary
		or snapshot.binding.get("venue_id") != snapshot.manifest.id
		or not SeasonOwnership._whole(
			snapshot.binding.get("venue_revision"),
			int(snapshot.manifest.revision),
			int(snapshot.manifest.revision)
		)
		or not SeasonOwnership._whole(
			snapshot.binding.get("fixture"),
			(
				32
				if (
					snapshot.manifest.id
					in ["LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"]
				)
				else 0
			),
			(
				32
				if (
					snapshot.manifest.id
					in ["LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"]
				)
				else 31
			)
		)
	):
		return false
	if lab._managed_match:
		if (
			snapshot.manifest.id
			in ["LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"]
		):
			if snapshot.binding.get("away") != 0 and snapshot.binding.get("batting_home") != 0:
				return false
			if lab._player_home != (snapshot.binding.get("batting_home") == 0):
				return false
		elif lab._player_home or snapshot.binding.get("away") != 0:
			return false
	var fixture: Dictionary = SeasonVenues.fixture_for_id(
		lab._npc_season, int(snapshot.binding.fixture)
	)
	if (
		property != null
		and (
			not property.public_bound
			or property.bound_state != lab._match_state
			or property.public_season != lab._npc_season
			or property.public_automation != lab._automation
			or property.public_managed != lab._managed_match
			or property.public_snapshot != snapshot
			or property.public_assignments != lab._npc_season.npc_venues
			or (
				(
					snapshot.manifest.id
					in ["LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"]
				)
				and property.public_final_assignment != lab._npc_season.final_venue
			)
			or property.public_fixture != fixture
		)
	):
		return false
	if (
		lab._automation != null
		and (
			lab._automation.get_script() != MatchAutomation
			or lab._automation.seed != snapshot.binding.get("match_seed")
		)
	):
		return false
	if not strict and property != null:
		# Fresh current authority is compared every time, without JSON or geometry hashing.
		return (
			lab._npc_season.season_seed == snapshot.binding.get("season_seed")
			and SeasonVenues.run_for(lab._npc_season) == snapshot.binding.get("career_run")
		)
	var normalized: Dictionary = StadiumNpcSnapshot.normalized(snapshot)
	return (
		not normalized.is_empty()
		and StadiumNpcSnapshot.matches_fixture(normalized, lab._npc_season, fixture)
	)


static func _fresh_match(state: MatchState) -> bool:
	return (
		state != null
		and state.phase == MatchState.Phase.PRE_PITCH
		and state.inning == 1
		and state.top_half
		and state.plate_appearance_number == 1
		and state.balls == 0
		and state.strikes == 0
		and state.outs == 0
		and state.between_batters
		and state.elapsed_seconds == 0.0
		and is_finite(state.ai_tactical_quality)
		and state.ai_tactical_quality >= 0.0
		and state.ai_tactical_quality <= 1.0
		and state.performance.players.is_empty()
		and state.sides.rows.is_empty()
		and state.sure_shot.releases.is_empty()
		and state.sure_shot.calls.is_empty()
		and state.cold.appearances.is_empty()
		and state.clean_outs.rows.is_empty()
		and state.ai_choice_events.is_empty()
		and state._ai_choice_prepared.is_empty()
		and state.base_flow.ready.is_empty()
		and state.base_flow.results.is_empty()
		and state.base_flow.tags.is_empty()
		and state.base_flow.advances.is_empty()
		and state.frozen_contacts.is_empty()
		and state.bases.occupied_count() == 0
		and not state.gear_usage.started
		and state.gear_usage.first_pitch.is_empty()
		and _fresh_teams(state)
	)


static func _fresh_teams(state: MatchState) -> bool:
	var away: TeamMatchState = PhysicalMatchRequest._team(state.away_team)
	var home: TeamMatchState = PhysicalMatchRequest._team(state.home_team)
	if away == null or home == null:
		return false
	var ids: Dictionary = {}
	for team: TeamMatchState in [away, home]:
		for player: PlayerMatchState in team.roster:
			if ids.has(player.definition.id):
				return false
			ids[player.definition.id] = true
	return true


static func _admissible(lab: PitchBatLab) -> bool:
	if (
		not _public_context(lab)
		or not _fresh_match(lab._match_state)
		or not StadiumMountedScoreboardContract.origin_clean(lab)
		or not StadiumPropertyRuntime.authoring_delivery_idle(lab)
		or lab.has_meta(PUBLIC_BOUND)
		or lab.has_meta("stadium_property")
		or lab.has_meta("stadium_snapshot")
		or lab._field_id != PitchBatLab.FIELD_ID
		or is_instance_valid(lab._batted_ball)
		or lab._pitch_actor.receiver_router.is_valid()
		or lab._throw_number != 0
		or not lab._play_records.is_empty()
		or (lab._automation != null and not lab._automation.releases.is_empty())
		or not lab._camera_director.presentation_override.is_null()
	):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if (
		host == null
		or host.get_script() != StarterFieldLabGeometry
		or not host.is_inside_tree()
		or host.global_transform != Transform3D.IDENTITY
		or not host.has_node("PitchReceiverDebug")
		or host.has_node("HomeProperty")
	):
		return false
	for body: CollisionObject3D in host.find_children("*", "CollisionObject3D", true, false):
		if body.get_parent() != host or String(body.name) not in REMOVED:
			return false
	return true


static func install_bound(lab: PitchBatLab) -> bool:
	if is_instance_valid(lab) and lab.ac02_startup_pending():
		if lab._ac02_startup_attempt != null:
			lab._ac02_startup_attempt.abort("public install reentered startup")
		return false
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime.install_bound")
	var ac02_result: bool = _ac02_passive_01_install_bound(lab)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_install_bound(lab: PitchBatLab) -> bool:
	var property: StadiumNpcPublicProperty = _stage(lab)
	if property == null:
		StadiumGrandIIIEnvironmentV1.diagnose_install(lab, "stage/refused")
		return false
	if not _commit(lab, property):
		StadiumGrandIIIEnvironmentV1.diagnose_install(lab, "commit/refused")
		if is_instance_valid(property):
			property.free()
		return false
	return true


static func _stage(lab: PitchBatLab) -> StadiumNpcPublicProperty:
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime._stage")
	var ac02_result: StadiumNpcPublicProperty = _ac02_passive_01_private_stage(lab)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_private_stage(lab: PitchBatLab) -> StadiumNpcPublicProperty:
	if not _admissible(lab) or not source_qualified():
		StadiumGrandIIIEnvironmentV1.diagnose_install(lab, "stage/admissible-or-source")
		return null
	var property: StadiumNpcPublicProperty = _construct(lab, lab._match_state.stadium.manifest.id)
	if property == null:
		StadiumGrandIIIEnvironmentV1.diagnose_install(lab, "stage/construction")
		return null
	property.bound_state = lab._match_state
	property.public_snapshot = lab._match_state.stadium.duplicate(true)
	property.public_season = lab._npc_season
	property.public_assignments = lab._npc_season.npc_venues.duplicate(true)
	if (
		property.venue_id
		in ["LONG-YARD", "GRAND-I", "GRAND-II", "GRAND-III", "POOL-PARTY", "HILLSIDE"]
	):
		property.public_final_assignment = lab._npc_season.final_venue.duplicate(true)
	property.public_fixture = (
		SeasonVenues
		. fixture_for_id(lab._npc_season, int(property.public_snapshot.binding.fixture))
		. duplicate(true)
	)
	property.public_automation = lab._automation
	property.public_managed = lab._managed_match
	property.process_priority = -100
	property.process_physics_priority = -100
	if not _complete(lab, property):
		StadiumGrandIIIEnvironmentV1.diagnose_install(lab, "stage/complete")
		property.free()
		return null
	return property


static func refuse_bound_start(lab: PitchBatLab) -> void:
	if not is_instance_valid(lab):
		return
	lab.set_meta(PUBLIC_BOUND, true)
	lab.set_meta("stadium_npc_runtime_interrupted", true)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab._automation = null
	# This also protects an action boundary after its property reference disappeared.
	if is_instance_valid(lab._batted_ball):
		lab._batted_ball.freeze = true
		lab._batted_ball.process_mode = Node.PROCESS_MODE_DISABLED
		lab._batted_ball.set_process(false)
		lab._batted_ball.set_physics_process(false)
		lab._batted_ball.physics_contact_router = Callable()
		if lab._batted_ball.surface_contact.is_connected(lab._on_batted_surface_contact):
			lab._batted_ball.surface_contact.disconnect(lab._on_batted_surface_contact)
	if is_instance_valid(lab._ball_play_resolver):
		lab._ball_play_resolver.segment_observer = Callable()
		if lab._ball_play_resolver.play_resolved.is_connected(lab._on_ball_play_resolved):
			lab._ball_play_resolver.play_resolved.disconnect(lab._on_ball_play_resolved)
	if is_instance_valid(lab._pitch_actor):
		lab._pitch_actor.receiver_router = Callable()
		lab._pitch_actor.reset_pitch()
	if is_instance_valid(lab._release_controller):
		lab._release_controller.cancel()
	if is_instance_valid(lab._at_bat_cadence):
		lab._at_bat_cadence.stop()


static func installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	if is_instance_valid(lab) and lab.ac02_startup_pending():
		return false
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime.installed_bound")
	var ac02_result: bool = _ac02_passive_01_installed_bound(lab, snapshot)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	var issued_property: StadiumNpcPublicProperty = _property(lab)
	var issued_owner: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	if issued_owner != null or (issued_property != null and issued_property.has_ac02_issue()):
		if (
			issued_property == null
			or issued_owner == null
			or issued_property._ac02_issue != issued_owner
			or issued_property._ac02_issue_pin != issued_owner
		):
			if issued_owner != null:
				issued_owner.revoke("deep dispatcher token lost")
			elif issued_property != null:
				issued_property.ac02_revoke("deep dispatcher token lost")
			return false
		return (
			issued_property.public_snapshot == snapshot
			and issued_owner.deep_intact(lab, issued_property)
		)
	return _installed_bound_historical(lab, snapshot)


static func _installed_bound_historical(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	var property: StadiumNpcPublicProperty = _property(lab)
	return is_instance_valid(property) and property.public_snapshot == snapshot and installed(lab)


static func _construct(lab: PitchBatLab, id: String) -> StadiumNpcPublicProperty:
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime._construct")
	var ac02_result: StadiumNpcPublicProperty = _ac02_passive_01_private_construct(lab, id)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_private_construct(
	lab: PitchBatLab, id: String
) -> StadiumNpcPublicProperty:
	if definition(id).is_empty():
		return null
	var property: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
	property.venue_id = id
	property.name = "HomeProperty"
	if id == "HILLSIDE":
		property.construction = StadiumHillsidePublicConstruction.build()
	elif id == "POOL-PARTY":
		property.construction = StadiumPoolPartyPublicConstruction.build()
	elif id == "GRAND-III":
		property.construction = StadiumGrandIIIPublicConstruction.build()
	elif id == "GRAND-II":
		property.construction = StadiumGrandIIPublicConstruction.build()
	elif id == "GRAND-I":
		property.construction = StadiumGrandIPublicConstruction.build()
	elif id == "LONG-YARD":
		property.construction = StadiumLongYardPublicConstruction.build()
	elif id == "AC-02":
		property.construction = StadiumNpcAc02PublicConstruction.build()
	elif id == "AE-02":
		property.construction = StadiumNpcAe02PublicConstruction.build()
	elif id == "AM-02":
		property.construction = StadiumNpcMogulTwoV1.build()
	elif id == "AM-01":
		property.construction = StadiumNpcMogulOneV1.build()
	elif id == "AC-01":
		property.construction = StadiumNpcClubV1.build()
	else:
		property.construction = (
			StadiumNpcYardV1.build() if id == "AY-01" else (StadiumNpcExpandedV1.build())
		)
	if property.construction == null:
		property.free()
		return null
	property.add_child(property.construction)
	property.objects = property.construction.objects
	property.field = property.construction.field
	property.tier = property.construction.tier
	if (
		id
		in [
			"AC-01",
			"AC-02",
			"AM-01",
			"AM-02",
			"LONG-YARD",
			"GRAND-I",
			"GRAND-II",
			"GRAND-III",
			"POOL-PARTY",
			"HILLSIDE"
		]
	):
		var boundary: Node3D = (
			StadiumLongYardPublicBoundary.new()
			if id == "LONG-YARD"
			else (
				StadiumNpcAc02PublicBoundary.new()
				if id == "AC-02"
				else (
					StadiumNpcAm02PublicBoundary.new()
					if id == "AM-02"
					else (
						StadiumNpcAm01PublicBoundary.new()
						if id == "AM-01"
						else (StadiumNpcRetainedClubBoundary.new())
					)
				)
			)
		)
		if id == "POOL-PARTY":
			boundary.free()
			boundary = StadiumPoolPartyPublicBoundary.new()
		if id == "GRAND-III":
			boundary.free()
			boundary = StadiumGrandIIIPublicBoundary.new()
		if id == "GRAND-II":
			boundary.free()
			boundary = StadiumGrandIIPublicBoundary.new()
		if id == "GRAND-I":
			boundary.free()
			boundary = StadiumGrandIPublicBoundary.new()
		if id == "HILLSIDE":
			boundary.free()
			boundary = StadiumHillsidePublicContactAdapter.new()
		boundary.name = "RetainedClubContactAdapter"
		property.add_child(boundary)
		if not boundary.configure(
			property.construction.get_node(
				"HillsideBoundary" if id == "HILLSIDE" else "ClubBoundary"
			)
		):
			property.free()
			return null
		property.boundary = boundary
		if id == "HILLSIDE" and not boundary.bind_public_property(property):
			property.free()
			return null
		boundary.contact_applied.connect(property._club_contact)
	else:
		property.boundary = property.construction.get_node("BoundaryGraph")
	# owned_copy is only the legacy contact-key spelling. No ledger/layout is constructed.
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		if id == "POOL-PARTY" and identity == StadiumPoolPartyRuntime.COPY:
			continue
		model.set_meta("owned_copy", identity)
		for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
			body.set_meta("owned_copy", identity)
	if id != "AY-01":
		property.receiver = (
			StadiumLongYardPublicReceiver.new()
			if id == "LONG-YARD"
			else (
				StadiumNpcAc02PublicReceiver.new()
				if id == "AC-02"
				else (
					StadiumNpcAe02PublicReceiver.new()
					if id == "AE-02"
					else (
						StadiumNpcAm02PublicReceiver.new()
						if id == "AM-02"
						else (
							StadiumNpcAm01PublicReceiver.new()
							if id == "AM-01"
							else (
								StadiumNpcRetainedClubReceiver.new()
								if id == "AC-01"
								else (StadiumNpcRetainedReceiver.new())
							)
						)
					)
				)
			)
		)
		if id == "HILLSIDE":
			property.receiver.free()
			property.receiver = StadiumHillsidePublicReceiver.new()
		if id == "POOL-PARTY":
			property.receiver.free()
			property.receiver = StadiumPoolPartyPublicReceiver.new()
		if id == "GRAND-III":
			property.receiver.free()
			property.receiver = StadiumGrandIIIPublicReceiver.new()
		if id == "GRAND-II":
			property.receiver.free()
			property.receiver = StadiumGrandIIPublicReceiver.new()
		if id == "GRAND-I":
			property.receiver.free()
			property.receiver = StadiumGrandIPublicReceiver.new()
		if (
			id
			in [
				"AC-01",
				"AC-02",
				"AM-01",
				"AM-02",
				"LONG-YARD",
				"GRAND-I",
				"GRAND-II",
				"GRAND-III",
				"POOL-PARTY",
				"HILLSIDE"
			]
		):
			property.receiver.camera_protection = property._receiver_camera_protection
		property.receiver.name = "PitchReceiverPresentation"
		property.add_child(property.receiver)
		if not property.receiver.configure_pair(
			property.objects["npc:" + id + ":r1:RECEIVER-PRIMARY"],
			property.objects["npc:" + id + ":r1:RECEIVER-CATCH"],
			lab._sounds
		):
			property.free()
			return null
		# DD's exact eight-copy Hillside recipe deliberately uses the ordinary HUD.
		# This branch does not add a supported definition or grant installation authority.
		if id != "HILLSIDE":
			var board: Node3D = property.objects.get("npc:" + id + ":r1:" + board_site(id))
			if not is_instance_valid(board):
				property.free()
				return null
			property.display = board.get_node_or_null("Visual/ScoreDisplay")
			if not is_instance_valid(property.display):
				property.free()
				return null
		for body: StaticBody3D in property.find_children("*", "StaticBody3D", true, false):
			if (
				id != "HILLSIDE"
				and (id != "POOL-PARTY" or not StadiumPoolPartyRuntime.owns_node(property, body))
			):
				body.collision_layer |= 64
	if id == "AE-02":
		property.ae02_actors = StadiumNpcAe02PublicActors.new()
		if not property.ae02_actors.bind(property):
			property.free()
			return null
	if id == "AM-02" and not StadiumNpcAm02PublicConstruction.normalize_status_labels(property):
		property.free()
		return null
	if id == "AM-01" and not StadiumNpcAm01PublicConstruction.normalize_status_labels(property):
		property.free()
		return null
	if not _construction_valid(property, true):
		property.free()
		return null
	if id == "AC-02":
		# Exact reviewed factory provenance; no metadata declaration or subclass adoption.
		property._ac02_factory_origin = [
			property, property.construction, property.boundary, property.receiver, property.field
		]
		property._ac02_factory_origin.make_read_only()
		property._ac02_factory_origin_pin = property._ac02_factory_origin
	return property


static func _references(property: StadiumNpcPublicProperty) -> bool:
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime._references")
	var ac02_result: bool = _ac02_passive_01_private_references(property)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_private_references(property: StadiumNpcPublicProperty) -> bool:
	if (
		not is_instance_valid(property)
		or property.get_script() != StadiumNpcPublicProperty
		or (
			property.venue_id
			not in [
				"AY-01",
				"AE-01",
				"AE-02",
				"AC-01",
				"AC-02",
				"AM-01",
				"AM-02",
				"LONG-YARD",
				"GRAND-I",
				"GRAND-II",
				"GRAND-III",
				"POOL-PARTY",
				"HILLSIDE"
			]
		)
		or not is_instance_valid(property.construction)
		or not is_instance_valid(property.boundary)
	):
		return false
	var construction: Script = {
		"AY-01": StadiumNpcYardV1,
		"AE-01": StadiumNpcExpandedV1,
		"AE-02": StadiumNpcAe02PublicConstruction,
		"AC-02": StadiumNpcAc02PublicConstruction,
		"AC-01": StadiumNpcClubV1,
		"AM-01": StadiumNpcMogulOneV1,
		"AM-02": StadiumNpcMogulTwoV1,
		"LONG-YARD": StadiumLongYardPublicConstruction,
		"GRAND-I": StadiumGrandIPublicConstruction,
		"GRAND-II": StadiumGrandIIPublicConstruction,
		"GRAND-III": StadiumGrandIIIPublicConstruction,
		"POOL-PARTY": StadiumPoolPartyPublicConstruction,
		"HILLSIDE": StadiumHillsidePublicConstruction
	}[property.venue_id]
	var boundary: Script = {
		"AY-01": StadiumNpcYardBoundaryV1,
		"AE-01": StadiumNpcExpandedBoundaryV1,
		"AE-02": StadiumNpcExpandedBoundaryV1,
		"AC-01": StadiumNpcRetainedClubBoundary,
		"AC-02": StadiumNpcAc02PublicBoundary,
		"AM-01": StadiumNpcAm01PublicBoundary,
		"AM-02": StadiumNpcAm02PublicBoundary,
		"LONG-YARD": StadiumLongYardPublicBoundary,
		"GRAND-I": StadiumGrandIPublicBoundary,
		"GRAND-II": StadiumGrandIIPublicBoundary,
		"GRAND-III": StadiumGrandIIIPublicBoundary,
		"POOL-PARTY": StadiumPoolPartyPublicBoundary,
		"HILLSIDE": StadiumHillsidePublicContactAdapter
	}[property.venue_id]
	if (
		property.construction.get_script() != construction
		or property.boundary.get_script() != boundary
	):
		return false
	if property.venue_id == "AY-01":
		return property.receiver == null and property.display == null
	if (
		not property.receiver is Node
		or not is_instance_valid(property.receiver)
		or (property.venue_id != "HILLSIDE" and not is_instance_valid(property.display))
		or (property.venue_id == "HILLSIDE" and not property.score_display_intact())
	):
		return false
	if property.venue_id == "HILLSIDE":
		return (
			property.receiver.get_script() == StadiumHillsidePublicReceiver
			and is_instance_valid(property.boundary.source)
			and property.boundary.graph != null
		)
	if property.venue_id == "POOL-PARTY":
		return (
			property.receiver.get_script() == StadiumPoolPartyPublicReceiver
			and property.display.get_script() == StadiumScoreboardDisplay
			and is_instance_valid(property.boundary.source)
			and property.boundary.graph != null
		)
	if property.venue_id == "GRAND-III":
		return (
			property.receiver.get_script() == StadiumGrandIIIPublicReceiver
			and property.display.get_script() == StadiumScoreboardTierDisplay
			and property.display.tier == "video"
			and is_instance_valid(property.boundary.source)
			and property.boundary.graph != null
		)
	if property.venue_id == "GRAND-II":
		return (
			property.receiver.get_script() == StadiumGrandIIPublicReceiver
			and property.display.get_script() == StadiumScoreboardDisplay
			and is_instance_valid(property.boundary.source)
			and property.boundary.graph != null
		)
	if property.venue_id == "GRAND-I":
		return (
			property.receiver.get_script() == StadiumGrandIPublicReceiver
			and property.display.get_script() == StadiumScoreboardDisplay
			and is_instance_valid(property.boundary.source)
			and property.boundary.graph != null
		)
	if property.venue_id == "LONG-YARD":
		return (
			property.receiver.get_script() == StadiumLongYardPublicReceiver
			and property.display.get_script() == StadiumScoreboardDisplay
			and is_instance_valid(property.boundary.source)
			and property.boundary.graph != null
		)
	if property.venue_id in ["AE-01", "AE-02"]:
		return (
			(
				property.receiver.get_script()
				== (
					StadiumNpcAe02PublicReceiver
					if property.venue_id == "AE-02"
					else StadiumNpcRetainedReceiver
				)
			)
			and property.display.get_script() == StadiumNpcExpandedDisplayV1
			and property.boundary.graph != null
		)
	return (
		(
			property.receiver.get_script()
			== (
				StadiumNpcAc02PublicReceiver
				if property.venue_id == "AC-02"
				else (
					StadiumNpcAm02PublicReceiver
					if property.venue_id == "AM-02"
					else (
						StadiumNpcAm01PublicReceiver
						if property.venue_id == "AM-01"
						else StadiumNpcRetainedClubReceiver
					)
				)
			)
		)
		and property.display.get_script() == StadiumNpcClubDisplayV1
		and is_instance_valid(property.boundary.source)
		and property.boundary.graph != null
	)


static func _complete(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, admission: Variant = null
) -> bool:
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime._complete")
	var ac02_result: bool = _ac02_passive_01_private_complete(lab, property, admission)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_private_complete(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, admission: Variant = null
) -> bool:
	if (
		not _references(property)
		or property.field == null
		or (
			property.tier
			!= (
				{
					"AY-01": "backyard",
					"AE-01": "expanded",
					"AE-02": "expanded",
					"AC-01": "club",
					"AC-02": "club",
					"AM-01": "mogul",
					"AM-02": "mogul",
					"LONG-YARD": "club",
					"GRAND-I": "mogul",
					"GRAND-II": "mogul",
					"GRAND-III": "mogul",
					"POOL-PARTY": "expanded",
					"HILLSIDE": "expanded"
				}
				. get(property.venue_id)
			)
		)
		or property.construction.tier != property.tier
		or not is_instance_valid(property.boundary)
		or property.construction.get_parent() != property
		or not _boundary_complete(property)
		or not _construction_valid(property)
	):
		return false
	if (
		(
			(
				property.venue_id
				in [
					"AC-01",
					"AC-02",
					"AM-01",
					"AM-02",
					"LONG-YARD",
					"GRAND-I",
					"GRAND-II",
					"GRAND-III",
					"POOL-PARTY",
					"HILLSIDE"
				]
			)
			and not property.receiver is StadiumNpcRetainedClubReceiver
			and not property.receiver is StadiumPoolPartyPublicReceiver
			and not property.receiver is StadiumHillsidePublicReceiver
		)
		or (
			property.venue_id in ["AE-01", "AE-02"]
			and not property.receiver is StadiumNpcRetainedReceiver
		)
	):
		return false
	var expected: StadiumNpcPublicProperty = _construct(lab, property.venue_id)
	if expected == null:
		return false
	if admission != null:
		admission.add_root(expected)
	var same: bool = _construction_same(property, expected, admission)
	if property.is_inside_tree():
		var actual_view: StadiumNpcRetainedVisibility = (
			lab._camera_director.tracking_visibility as StadiumNpcRetainedVisibility
		)
		var expected_view: StadiumNpcRetainedVisibility = _visibility(property.venue_id)
		expected_view.configure_property(expected)
		same = (
			same
			and actual_view != null
			and actual_view.get_script() == expected_view.get_script()
			and actual_view._wall_prisms != null
			and (
				property.venue_id != "GRAND-III"
				or (actual_view._groups.size() == 50 and expected_view._groups.size() == 50)
			)
			and (
				property.venue_id != "GRAND-II"
				or (actual_view._groups.size() == 28 and expected_view._groups.size() == 28)
			)
			and (
				property.venue_id != "GRAND-I"
				or (actual_view._groups.size() == 18 and expected_view._groups.size() == 18)
			)
			and (
				property.venue_id != "LONG-YARD"
				or (actual_view._groups.size() == 11 and expected_view._groups.size() == 11)
			)
			and (
				property.venue_id != "AC-02"
				or (actual_view._groups.size() == 15 and expected_view._groups.size() == 15)
			)
			and (
				property.venue_id != "AM-02"
				or (actual_view._groups.size() == 32 and expected_view._groups.size() == 32)
			)
			and actual_view._obstacles == expected_view._obstacles
			and actual_view._uprights == expected_view._uprights
			and actual_view._wall_bounds == expected_view._wall_bounds
			and actual_view.field_wall_z == expected_view.field_wall_z
			and actual_view._groups == expected_view._groups
			and actual_view._rails == expected_view._rails
			and actual_view._wall_prisms.walls == expected_view._wall_prisms.walls
			and (
				property.venue_id != "HILLSIDE"
				or (actual_view as StadiumHillsidePublicVisibility).cold_valid(
					expected_view as StadiumHillsidePublicVisibility
				)
			)
			and (
				property.venue_id != "AE-02"
				or (
					(actual_view as StadiumNpcAe02PublicVisibility).owners_intact()
					and (
						(actual_view as StadiumNpcAe02PublicVisibility).canonical_side_state()
						== (expected_view as StadiumNpcAe02PublicVisibility).canonical_side_state()
					)
				)
			)
		)
	for key: String in StadiumNpcYardV1.FIELD:
		same = same and property.field.get(key) == expected.field.get(key)
	same = same and property.objects.size() == expected.objects.size()
	for identity: String in expected.objects:
		var model: Node3D = property.objects.get(identity)
		same = (
			same
			and is_instance_valid(model)
			and property.construction.is_ancestor_of(model)
			and (
				model.get_meta("npc_instance", "") == identity
				or (
					property.venue_id == "POOL-PARTY"
					and identity == StadiumPoolPartyRuntime.COPY
					and model == property.construction.pool_model
				)
			)
		)
	if property.venue_id != "AY-01":
		var prefix: String = identity_prefix(property.venue_id)
		same = (
			same
			and property.receiver != null
			and property.receiver.chair == property.objects.get(prefix + "RECEIVER-PRIMARY")
			and property.receiver.net == property.objects.get(prefix + "RECEIVER-CATCH")
			and property.receiver.sounds == lab._sounds
			and property.boundary.graph.get_script() == expected.boundary.graph.get_script()
			and property.boundary.graph.segments() == expected.boundary.graph.segments()
			and property.boundary.graph.polygon() == expected.boundary.graph.polygon()
			and property.score_display_intact()
		)
	if (
		property.venue_id
		in [
			"AC-01",
			"AC-02",
			"AM-01",
			"AM-02",
			"LONG-YARD",
			"GRAND-I",
			"GRAND-II",
			"GRAND-III",
			"POOL-PARTY",
			"HILLSIDE"
		]
	):
		same = same and property.receiver.camera_protection == property._receiver_camera_protection
		var source: Node3D = property.boundary.source
		var reference: Node3D = expected.boundary.source
		same = same and source.bodies.size() == reference.bodies.size()
		for index in range(mini(source.bodies.size(), reference.bodies.size())):
			var path: NodePath = reference.get_path_to(reference.bodies[index])
			same = same and source.get_node_or_null(path) == source.bodies[index]
	expected.free()
	return same


static func board_site(id: String) -> String:
	if id == "HILLSIDE":
		return ""
	if id == "POOL-PARTY":
		return StadiumPoolPartyPublicConstruction.BOARD_SITE
	if id == "GRAND-III":
		return StadiumGrandIIIPublicConstruction.BOARD_SITE
	return StadiumNpcClubV1.BOARD_SITE if id == "AC-01" else "SCORE-SMALL"


static func _boundary_complete(property: StadiumNpcPublicProperty) -> bool:
	if property.venue_id == "HILLSIDE":
		var source: StadiumHillsidePublicBoundarySource = (
			property.construction.get_node_or_null("HillsideBoundary")
			as StadiumHillsidePublicBoundarySource
		)
		return (
			property.boundary is StadiumHillsidePublicContactAdapter
			and source != null
			and source.get_script() == StadiumHillsidePublicBoundarySource
			and source.graph != null
			and source.graph.get_script() == StadiumHillsidePublicBoundary
			and property.boundary.source == source
			and property.boundary.graph == source.graph
			and property.boundary.bodies == source.member_bodies
			and property.boundary.contact_applied.is_connected(property._club_contact)
			and property.boundary.contact_applied.get_connections().size() == 1
		)
	if property.venue_id == "LONG-YARD":
		var yard_source: StadiumLongYardPublicBoundarySource = (
			property.construction.get_node_or_null("ClubBoundary")
			as StadiumLongYardPublicBoundarySource
		)
		return (
			property.boundary is StadiumLongYardPublicBoundary
			and yard_source != null
			and yard_source.get_script() == StadiumLongYardPublicBoundarySource
			and yard_source.graph != null
			and yard_source.graph.get_script() == StadiumDugoutBoundary
			and property.boundary.source == yard_source
			and property.boundary.graph == yard_source.graph
			and property.boundary.bodies == yard_source.bodies
			and property.boundary.items == yard_source.items
			and property.boundary.contact_applied.is_connected(property._club_contact)
			and property.boundary.contact_applied.get_connections().size() == 1
		)
	if property.venue_id == "POOL-PARTY":
		var yard_source: StadiumPoolPartyPublicBoundarySource = (
			property.construction.get_node_or_null("ClubBoundary")
			as StadiumPoolPartyPublicBoundarySource
		)
		return (
			property.boundary is StadiumPoolPartyPublicBoundary
			and yard_source != null
			and yard_source.get_script() == StadiumPoolPartyPublicBoundarySource
			and yard_source.graph != null
			and yard_source.graph.get_script() == StadiumTimberDugoutBoundary
			and is_instance_valid(property.boundary.pool_model)
			and property.boundary.pool_model == property.objects.get(StadiumPoolPartyRuntime.COPY)
			and property.boundary.pool_model == property.construction.pool_model
			and property.boundary.pool_model.has_node("Collision")
			and property.boundary.pool_bodies.size() == 5
			and (
				property.boundary.pool_bodies
				== property.boundary.pool_model.get_node("Collision").get_children()
			)
			and property.boundary.source == yard_source
			and property.boundary.graph == yard_source.graph
			and property.boundary.bodies == yard_source.bodies
			and property.boundary.items == yard_source.items
			and property.boundary.contact_applied.is_connected(property._club_contact)
			and property.boundary.contact_applied.get_connections().size() == 1
		)
	if property.venue_id == "GRAND-III":
		var yard_source: StadiumGrandIPublicBoundarySource = (
			property.construction.get_node_or_null("ClubBoundary")
			as StadiumGrandIPublicBoundarySource
		)
		return (
			property.boundary is StadiumGrandIIIPublicBoundary
			and yard_source != null
			and yard_source.get_script() == StadiumGrandIPublicBoundarySource
			and yard_source.graph != null
			and yard_source.graph.get_script() == StadiumDugoutBoundary
			and property.boundary.source == yard_source
			and property.boundary.graph == yard_source.graph
			and property.boundary.bodies == yard_source.bodies
			and property.boundary.items == yard_source.items
			and property.boundary.contact_applied.is_connected(property._club_contact)
			and property.boundary.contact_applied.get_connections().size() == 1
		)
	if property.venue_id == "GRAND-II":
		var yard_source: StadiumGrandIPublicBoundarySource = (
			property.construction.get_node_or_null("ClubBoundary")
			as StadiumGrandIPublicBoundarySource
		)
		return (
			property.boundary is StadiumGrandIIPublicBoundary
			and yard_source != null
			and yard_source.get_script() == StadiumGrandIPublicBoundarySource
			and yard_source.graph != null
			and yard_source.graph.get_script() == StadiumDugoutBoundary
			and property.boundary.source == yard_source
			and property.boundary.graph == yard_source.graph
			and property.boundary.bodies == yard_source.bodies
			and property.boundary.items == yard_source.items
			and property.boundary.contact_applied.is_connected(property._club_contact)
			and property.boundary.contact_applied.get_connections().size() == 1
		)
	if property.venue_id == "GRAND-I":
		var yard_source: StadiumGrandIPublicBoundarySource = (
			property.construction.get_node_or_null("ClubBoundary")
			as StadiumGrandIPublicBoundarySource
		)
		return (
			property.boundary is StadiumGrandIPublicBoundary
			and yard_source != null
			and yard_source.get_script() == StadiumGrandIPublicBoundarySource
			and yard_source.graph != null
			and yard_source.graph.get_script() == StadiumDugoutBoundary
			and property.boundary.source == yard_source
			and property.boundary.graph == yard_source.graph
			and property.boundary.bodies == yard_source.bodies
			and property.boundary.items == yard_source.items
			and property.boundary.contact_applied.is_connected(property._club_contact)
			and property.boundary.contact_applied.get_connections().size() == 1
		)
	if property.venue_id == "AC-02":
		# RightShelf has its own exact 18-edge graph and physical boundary source.
		var club_source: StadiumNpcAc02PublicBoundarySource = (
			property.construction.get_node_or_null("ClubBoundary")
			as StadiumNpcAc02PublicBoundarySource
		)
		return (
			property.boundary is StadiumNpcAc02PublicBoundary
			and club_source != null
			and club_source.get_script() == StadiumNpcAc02PublicBoundarySource
			and club_source.graph != null
			and club_source.graph.get_script() == StadiumNpcAc02PublicGraph
			and property.boundary.source == club_source
			and property.boundary.graph == club_source.graph
			and property.boundary.bodies == club_source.bodies
			and property.boundary.items == club_source.items
			and property.boundary.contact_applied.is_connected(property._club_contact)
			and property.boundary.contact_applied.get_connections().size() == 1
		)
	if property.venue_id == "AM-02":
		# The retained Left Loft boundary is a distinct concrete type despite its node name.
		var mogul_source: StadiumNpcMogulTwoBoundaryV1 = (
			property.construction.get_node_or_null("ClubBoundary") as StadiumNpcMogulTwoBoundaryV1
		)
		return (
			property.boundary is StadiumNpcAm02PublicBoundary
			and mogul_source != null
			and mogul_source.get_script() == StadiumNpcMogulTwoBoundaryV1
			and property.boundary.source == mogul_source
			and property.boundary.graph == mogul_source.graph
			and property.boundary.bodies == mogul_source.bodies
			and property.boundary.items == mogul_source.items
			and property.boundary.contact_applied.is_connected(property._club_contact)
			and property.boundary.contact_applied.get_connections().size() == 1
		)
	if property.venue_id not in ["AC-01", "AM-01"]:
		return property.boundary == property.construction.get_node_or_null("BoundaryGraph")
	var source: StadiumNpcClubBoundaryBodyV1 = property.construction.get_node_or_null(
		"ClubBoundary"
	)
	return (
		(
			property.boundary is StadiumNpcRetainedClubBoundary
			or property.boundary is StadiumNpcAm01PublicBoundary
		)
		and source != null
		and property.boundary.source == source
		and property.boundary.graph == source.graph
		and property.boundary.bodies == source.bodies
		and property.boundary.contact_applied.is_connected(property._club_contact)
		and property.boundary.contact_applied.get_connections().size() == 1
	)


static func _commit(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime._commit")
	var ac02_result: bool = _ac02_passive_01_private_commit(lab, property)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_private_commit(
	lab: PitchBatLab, property: StadiumNpcPublicProperty
) -> bool:
	if (
		not _admissible(lab)
		or property == null
		or not _public_context(lab, property)
		or property.get_parent() != null
		or not source_qualified()
		or not _complete(lab, property)
	):
		StadiumGrandIIIEnvironmentV1.diagnose_install(lab, "commit/preflight")
		return false

	# AC02 admits genuine current guides before issue. Apply the ordinary marker presenter
	# while no property is bound, before its receiver refresh can inspect guide ownership.
	if property.venue_id == "AC-02":
		PitchBatLabPresentation.refresh_markers(lab)
	var host: StarterFieldLabGeometry = lab.get_node("StarterFieldGeometry")
	property.host_children.assign(host.get_children())
	property.old_field_id = lab._field_id
	property.old_field = lab._field_definition
	property.old_camera_mask = lab._camera.cull_mask
	property.old_camera = lab._camera_director
	property.old_visibility = lab._camera_director.tracking_visibility
	property.old_observer = lab._ball_play_resolver.segment_observer
	property.old_clip = lab._primary_fielder.stadium_boundary_clip
	property.old_obstacles = lab._primary_fielder.stadium_obstacles.duplicate(true)
	property.old_receiver = lab._pitch_actor.receiver_router
	if property.venue_id == "HILLSIDE":
		property.environment_lease = StadiumHillsideEnvironmentV1.capture_lab(lab)
		if property.environment_lease.is_empty():
			return false
		property.hillside_support = StadiumHillsidePublicSupport.new()
		if not property.hillside_support.prepare(lab, property):
			StadiumHillsideEnvironmentV1.restore(lab, property.environment_lease)
			return false
		# Capture rollback owners before remove/add notifications can run external callbacks.
		property.lab_ref = weakref(lab)
		property.presentation_director = lab._camera_director
		property.presentation_camera = weakref(lab._camera)
		property.pin_lab(lab)
		lab.set_meta("stadium_property", property)
		lab.set_meta(PUBLIC_BOUND, true)
		lab.set_meta("stadium_snapshot", property.public_snapshot.duplicate(true))
	for id: String in REMOVED:
		var old: Node = host.get_node_or_null(NodePath(id))
		if old != null:
			if property.venue_id == "HILLSIDE":
				property.old_nodes.append(old)
			host.remove_child(old)
			if property.venue_id != "HILLSIDE":
				property.old_nodes.append(old)
			if (
				property.venue_id == "HILLSIDE"
				and not property.hillside_support.staging_actors_intact()
			):
				_restore(lab, property)
				return false
	host.add_child(property)
	if not is_instance_valid(property):
		return false
	if (
		property.venue_id == "HILLSIDE"
		and (
			not property.hillside_support.staging_actors_intact()
			or property.get_parent() != host
			or _property(lab) != property
		)
	):
		_restore(lab, property)
		if property.get_parent() != null:
			property.get_parent().remove_child(property)
		return false
	lab.set_meta("stadium_property", property)
	lab.set_meta(PUBLIC_BOUND, true)
	lab.set_meta("stadium_snapshot", property.public_snapshot.duplicate(true))
	property.lab_ref = weakref(lab)
	lab._field_id = property.field.id
	lab._field_definition = property.field
	lab._ball_play_resolver.segment_observer = property.observe
	lab._primary_fielder.stadium_boundary_clip = property.clip
	lab._primary_fielder.stadium_obstacles = property.route_obstacles()
	lab._pitch_actor.receiver_router = Callable()
	if property.receiver != null:
		lab._pitch_actor.receiver_router = property.receiver_route
		var camera: StadiumClubCameraDirector = (
			StadiumLongYardPublicCamera.new()
			if property.venue_id == "LONG-YARD"
			else (
				StadiumNpcAc02PublicCamera.new()
				if property.venue_id == "AC-02"
				else (
					StadiumNpcAe02PublicCamera.new()
					if property.venue_id == "AE-02"
					else (
						StadiumNpcAm02PublicCamera.new()
						if property.venue_id == "AM-02"
						else (
							StadiumNpcAm01PublicCamera.new()
							if property.venue_id == "AM-01"
							else (
								StadiumClubCameraDirector.new()
								if property.venue_id == "AC-01"
								else StadiumExpandedCameraDirector.new()
							)
						)
					)
				)
			)
		)
		if property.venue_id == "POOL-PARTY":
			camera = StadiumPoolPartyPublicCamera.new()
		if property.venue_id == "GRAND-III":
			camera = StadiumGrandIIIPublicCamera.new()
		if property.venue_id == "GRAND-II":
			camera = StadiumGrandIIPublicCamera.new()
		if property.venue_id == "GRAND-I":
			camera = StadiumGrandIPublicCamera.new()
		if camera is StadiumPoolPartyPublicCamera:
			camera.lab_ref = weakref(lab)
		elif camera is StadiumGrandIIIPublicCamera:
			camera.lab_ref = weakref(lab)
		elif camera is StadiumGrandIIPublicCamera:
			camera.lab_ref = weakref(lab)
		elif camera is StadiumGrandIPublicCamera:
			camera.lab_ref = weakref(lab)
		elif camera is StadiumLongYardPublicCamera:
			camera.lab_ref = weakref(lab)
		elif camera is StadiumNpcAc02PublicCamera:
			camera.lab_ref = weakref(lab)
		elif camera is StadiumNpcAe02PublicCamera:
			camera.lab_ref = weakref(lab)
		elif camera is StadiumNpcAm02PublicCamera:
			camera.lab_ref = weakref(lab)
		elif camera is StadiumNpcAm01PublicCamera:
			camera.lab_ref = weakref(lab)
		camera.camera_mask |= 64
		for key: String in CAMERA_STATE:
			camera.set(key, lab._camera_director.get(key))
		lab._camera_director = camera
	lab._camera_director.tracking_visibility = _visibility(property.venue_id)
	lab._camera_director.tracking_visibility.configure(host)
	property.presentation_director = lab._camera_director
	property.presentation_camera = weakref(lab._camera)
	if property.venue_id == "AC-02":
		property.ac02_guides = StadiumNpcAc02PublicGuides.new()
		if not property.ac02_guides.configure(lab, property, lab._camera):
			_restore(lab, property)
			if property.get_parent() != null:
				property.get_parent().remove_child(property)
			return false
	if property.venue_id == "HILLSIDE":
		var applied: Dictionary = StadiumHillsideEnvironmentV1.apply(
			lab, property.public_snapshot.environment, property.environment_lease
		)
		if applied.is_empty():
			_restore(lab, property)
			if property.get_parent() != null:
				property.get_parent().remove_child(property)
			return false
		property.environment_lease = applied
	if property.venue_id == "LONG-YARD":
		property.environment_lease = StadiumLongYardEnvironmentV1.apply(
			lab, property.public_snapshot.environment
		)
		if property.environment_lease.is_empty():
			_restore(lab, property)
			if property.get_parent() != null:
				property.get_parent().remove_child(property)
			return false
	if property.venue_id == "POOL-PARTY":
		property.environment_lease = StadiumPoolPartyEnvironmentV1.apply(
			lab, property.public_snapshot.environment
		)
		if property.environment_lease.is_empty():
			_restore(lab, property)
			if property.get_parent() != null:
				property.get_parent().remove_child(property)
			return false
	if property.venue_id == "GRAND-III":
		property.environment_lease = StadiumGrandIIIEnvironmentV1.apply(
			lab, property.public_snapshot.environment
		)
		if property.environment_lease.is_empty():
			_restore(lab, property)
			if property.get_parent() != null:
				property.get_parent().remove_child(property)
			return false
	if property.venue_id == "GRAND-II":
		property.environment_lease = StadiumGrandIIEnvironmentV1.apply(
			lab, property.public_snapshot.environment
		)
		if property.environment_lease.is_empty():
			_restore(lab, property)
			if property.get_parent() != null:
				property.get_parent().remove_child(property)
			return false
	if property.venue_id == "GRAND-I":
		property.environment_lease = StadiumGrandIEnvironmentV1.apply(
			lab, property.public_snapshot.environment
		)
		if property.environment_lease.is_empty():
			_restore(lab, property)
			if property.get_parent() != null:
				property.get_parent().remove_child(property)
			return false
	property.pin_lab(lab)
	if property.venue_id == "HILLSIDE":
		_finish_hillside_install(lab, property, property.bound_state)
		return true
	property.rebind(lab._match_state)
	if property.venue_id == "AC-02":
		AC02_SETUP_RETURNS.capture(
			"markers", PitchBatLabPresentation.refresh_ac02_setup_markers(lab)
		)
		AC02_SETUP_RETURNS.capture("receiver", StadiumNpcAc02SetupAdmission.refresh_receiver(lab))
	else:
		PitchBatLabPresentation.refresh_markers(lab)
		StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	if not installed(lab) or not property.issue_installation():
		StadiumGrandIIIEnvironmentV1.diagnose_install(lab, "commit/installed-or-issue")
		_restore(lab, property)
		if property.get_parent() != null:
			property.get_parent().remove_child(property)
		return false
	if lab._camera_director is StadiumPoolPartyPublicCamera:
		StadiumWallRenderQuality.attach(property)
	elif lab._camera_director is StadiumGrandIIIPublicCamera:
		StadiumWallRenderQuality.attach(property)
	elif lab._camera_director is StadiumGrandIIPublicCamera:
		StadiumWallRenderQuality.attach(property)
	elif lab._camera_director is StadiumGrandIPublicCamera:
		StadiumWallRenderQuality.attach(property)
	elif lab._camera_director is StadiumLongYardPublicCamera:
		StadiumWallRenderQuality.attach(property)
		lab._camera_director.acquire_precontact_entry()
	elif lab._camera_director is StadiumNpcAc02PublicCamera:
		StadiumWallRenderQuality.attach(property)
	elif lab._camera_director is StadiumNpcAe02PublicCamera:
		StadiumWallRenderQuality.attach(property)
		lab._camera_director.acquire_precontact_entry()
	elif lab._camera_director is StadiumNpcAm02PublicCamera:
		lab._camera_director.acquire_precontact_entry()
	elif lab._camera_director is StadiumNpcAm01PublicCamera:
		lab._camera_director.acquire_precontact_entry()
	return true


static func installed(lab: PitchBatLab, admission: Variant = null) -> bool:
	if is_instance_valid(lab) and lab.ac02_startup_pending():
		return false
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime.installed")
	var ac02_result: bool = _ac02_passive_01_installed(lab, admission)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_installed(lab: PitchBatLab, admission: Variant = null) -> bool:
	var property: StadiumNpcPublicProperty = _property(lab)
	if (
		not _live_lab(lab)
		or property == null
		or not _public_context(lab, property)
		or not source_qualified()
		or not _binding_mode(lab, property, true)
	):
		return false
	var id: String = property.venue_id

	var host: Node3D = lab.get_node_or_null("StarterFieldGeometry")
	if (
		property == null
		or property.suspended
		or (
			property.venue_id == "HILLSIDE"
			and (property.hillside_support == null or property.hillside_support.pending)
		)
		or not property.support_intact()
		or property.venue_id != id
		or host == null
		or host.get_script() != StarterFieldLabGeometry
		or property.lab_ref == null
		or property.lab_ref.get_ref() != lab
		or property.process_mode != Node.PROCESS_MODE_INHERIT
		or not property.is_processing()
		or not property.is_physics_processing()
		or property.process_priority != -100
		or property.process_physics_priority != -100
		or property.get_parent() != host
		or host.global_transform != Transform3D.IDENTITY
		or property.transform != Transform3D.IDENTITY
		or not _complete(lab, property, admission)
		or property.presentation_director != lab._camera_director
		or property.presentation_camera == null
		or property.presentation_camera.get_ref() != lab._camera
		or not lab._camera_director.presentation_override.is_null()
		or lab._camera.cull_mask != property.old_camera_mask
		or not property.actor_cutaway is StadiumNpcRetainedActorCutaway
		or not property.ball_readability is StadiumNpcRetainedBallReadability
	):
		return false
	var count: int = 1
	for node: Node in property.host_children:
		if not is_instance_valid(node):
			return false
		if property.old_nodes.has(node):
			if node.get_parent() != null:
				return false
		else:
			count += 1
			if node.get_parent() != host:
				return false
	for body: CollisionObject3D in host.find_children("*", "CollisionObject3D", true, false):
		if not property.is_ancestor_of(body):
			return false
	if (
		host.get_child_count() != count
		or lab._field_id != property.field.id
		or lab._field_definition != property.field
		or lab._ball_play_resolver.segment_observer != property.observe
		or not lab._ball_play_resolver.play_resolved.is_connected(lab._on_ball_play_resolved)
		or lab._primary_fielder.stadium_boundary_clip != property.clip
		or lab._primary_fielder.stadium_obstacles != property.route_obstacles()
	):
		return false
	var bound_ids: Dictionary = {}
	for reference: WeakRef in property.bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		if bound_ids.has(ball.get_instance_id()) or ball.get_parent() != lab:
			return false
		bound_ids[ball.get_instance_id()] = true
		if (
			(
				ball.physics_contact_router
				!= property._boundary_contact_batch.bind(lab._ball_play_resolver)
			)
			or (
				(
					id
					not in [
						"AC-01",
						"AC-02",
						"AM-01",
						"AM-02",
						"LONG-YARD",
						"GRAND-I",
						"GRAND-II",
						"GRAND-III",
						"POOL-PARTY",
						"HILLSIDE"
					]
				)
				and not ball.body_entered.is_connected(
					property._ball_contact.bind(ball, lab._ball_play_resolver)
				)
			)
		):
			return false
		if (
			(
				id
				not in [
					"AC-01",
					"AC-02",
					"AM-01",
					"AM-02",
					"LONG-YARD",
					"GRAND-I",
					"GRAND-II",
					"GRAND-III",
					"POOL-PARTY",
					"HILLSIDE"
				]
			)
			and not ball.tree_exited.is_connected(
				property.boundary._forget.bind(ball.get_instance_id())
			)
		):
			return false
		if (
			id
			in [
				"AC-01",
				"AC-02",
				"AM-01",
				"AM-02",
				"LONG-YARD",
				"GRAND-I",
				"GRAND-II",
				"GRAND-III",
				"POOL-PARTY",
				"HILLSIDE"
			]
		):
			var ball_id: int = ball.get_instance_id()
			var resolver_id: int = lab._ball_play_resolver.get_instance_id()
			if (
				not ball.launch_started.is_connected(property.boundary._seed.bind(ball_id))
				or not ball.tree_exited.is_connected(
					property.boundary._forget.bind(ball_id, resolver_id)
				)
				or property.boundary._resolver_ids.get(ball_id) != resolver_id
				or not property.boundary._bound_balls.has(ball_id)
				or property.boundary._bound_balls[ball_id].get_ref() != ball
				or not property.boundary._previous.has(ball_id)
				or not property.boundary._previous[ball_id] is Vector3
				or not property.boundary._previous[ball_id].is_finite()
			):
				return false
	if (
		id
		in [
			"AC-01",
			"AC-02",
			"AM-01",
			"AM-02",
			"LONG-YARD",
			"GRAND-I",
			"GRAND-II",
			"GRAND-III",
			"POOL-PARTY",
			"HILLSIDE"
		]
	):
		for maps: Dictionary in [
			property.boundary._bound_balls,
			property.boundary._resolver_ids,
			property.boundary._previous
		]:
			if maps.size() != bound_ids.size():
				return false
			for ball_id: int in maps:
				if not bound_ids.has(ball_id):
					return false
		for resolver_id: int in property.boundary.last_live:
			if bound_ids.is_empty() or resolver_id != lab._ball_play_resolver.get_instance_id():
				return false
	var visibility: StadiumNpcRetainedVisibility = (
		lab._camera_director.tracking_visibility as StadiumNpcRetainedVisibility
	)
	if (
		visibility == null
		or visibility.property != property
		or visibility._recipe == null
		or visibility._wall_prisms == null
	):
		return false
	var graph: StadiumRecipeBoundary = property.view_graph()
	if (
		visibility._recipe.get_script() != graph.get_script()
		or visibility._recipe.segments() != graph.segments()
		or visibility._recipe.polygon() != graph.polygon()
		or (
			id != "HILLSIDE"
			and (
				visibility._wall_prisms.walls
				!= (
					StadiumNpcRetainedVisibility
					. prisms(
						graph,
						(
							"AC-01"
							if (
								id
								in [
									"AC-02",
									"AM-01",
									"AM-02",
									"LONG-YARD",
									"GRAND-I",
									"GRAND-II",
									"GRAND-III",
									"POOL-PARTY",
									"HILLSIDE"
								]
							)
							else id
						)
					)
					. walls
				)
			)
		)
	):
		return false
	if id == "AY-01":
		return not lab._pitch_actor.receiver_router.is_valid() and property.receiver == null
	return (
		lab._pitch_actor.receiver_router == property.receiver_route
		and (
			property.score_display_intact()
			if id == "HILLSIDE"
			else property.display._match == lab._match_state
		)
		and (
			(
				id == "HILLSIDE"
				and lab._camera_director.get_script() == StadiumExpandedCameraDirector
			)
			or (
				id == "POOL-PARTY"
				and lab._camera_director.get_script() == StadiumPoolPartyPublicCamera
				and lab._camera_director.lab_ref != null
				and lab._camera_director.lab_ref.get_ref() == lab
			)
			or (
				id == "GRAND-III"
				and lab._camera_director.get_script() == StadiumGrandIIIPublicCamera
				and lab._camera_director.lab_ref != null
				and lab._camera_director.lab_ref.get_ref() == lab
			)
			or (
				id == "GRAND-II"
				and lab._camera_director.get_script() == StadiumGrandIIPublicCamera
				and lab._camera_director.lab_ref != null
				and lab._camera_director.lab_ref.get_ref() == lab
			)
			or (
				id == "GRAND-I"
				and lab._camera_director.get_script() == StadiumGrandIPublicCamera
				and lab._camera_director.lab_ref != null
				and lab._camera_director.lab_ref.get_ref() == lab
			)
			or (
				id == "LONG-YARD"
				and lab._camera_director.get_script() == StadiumLongYardPublicCamera
				and lab._camera_director.lab_ref != null
				and lab._camera_director.lab_ref.get_ref() == lab
			)
			or (id == "AC-01" and lab._camera_director.get_script() == StadiumClubCameraDirector)
			or (
				id == "AC-02"
				and lab._camera_director.get_script() == StadiumNpcAc02PublicCamera
				and lab._camera_director.lab_ref != null
				and lab._camera_director.lab_ref.get_ref() == lab
			)
			or (
				id == "AM-01"
				and lab._camera_director.get_script() == StadiumNpcAm01PublicCamera
				and lab._camera_director.lab_ref != null
				and lab._camera_director.lab_ref.get_ref() == lab
			)
			or (
				id == "AM-02"
				and lab._camera_director.get_script() == StadiumNpcAm02PublicCamera
				and lab._camera_director.lab_ref != null
				and lab._camera_director.lab_ref.get_ref() == lab
			)
			or (
				id == "AE-02"
				and lab._camera_director.get_script() == StadiumNpcAe02PublicCamera
				and lab._camera_director.lab_ref != null
				and lab._camera_director.lab_ref.get_ref() == lab
			)
			or (
				id == "AE-01" and lab._camera_director.get_script() == StadiumExpandedCameraDirector
			)
		)
		and lab._camera_director.camera_mask == 80
	)


static func _binding_mode(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, strict: bool = true
) -> bool:
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime._binding_mode")
	var ac02_result: bool = _ac02_passive_01_private_binding_mode(lab, property, strict)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_private_binding_mode(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, strict: bool = true
) -> bool:
	return (
		_public_context(lab, property, strict)
		and typeof(lab.get_meta(PUBLIC_BOUND, false)) == TYPE_BOOL
		and lab.get_meta(PUBLIC_BOUND, false) == true
		and lab.get_meta("stadium_snapshot", {}) == property.public_snapshot
		and (
			not strict
			or (
				StadiumPoolPartyRuntime.origin_clean(lab, property)
				if property.venue_id == "POOL-PARTY"
				else StadiumMountedScoreboardContract.origin_clean(lab)
			)
		)
	)


static func callback_bound(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	if is_instance_valid(lab) and lab.ac02_startup_pending():
		return false
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime.callback_bound")
	var ac02_result: bool = _ac02_passive_01_callback_bound(lab, property)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_callback_bound(
	lab: PitchBatLab, property: StadiumNpcPublicProperty
) -> bool:
	if (
		not _live_lab(lab)
		or property == null
		or property.suspended
		or not _binding_mode(lab, property, false)
		or _property(lab) != property
		or property.lab_ref == null
		or property.lab_ref.get_ref() != lab
		or property.get_parent() != lab.get_node_or_null("StarterFieldGeometry")
		or not property.is_inside_tree()
		or property.is_queued_for_deletion()
		or property.get_parent().get_script() != StarterFieldLabGeometry
		or property.get_parent().global_transform != Transform3D.IDENTITY
		or property.transform != Transform3D.IDENTITY
		or property.top_level
		or property.process_mode != Node.PROCESS_MODE_INHERIT
		or not property.is_processing()
		or not property.is_physics_processing()
		or property.process_priority != -100
		or property.process_physics_priority != -100
		or lab._field_id != property.field.id
		or lab._field_definition != property.field
		or property.presentation_director != lab._camera_director
		or property.presentation_camera == null
		or property.presentation_camera.get_ref() != lab._camera
		or not lab._camera_director.presentation_override.is_null()
		or lab._camera.cull_mask != property.old_camera_mask
	):
		return false
	var ancestor: Node = property.get_parent()
	while ancestor != null:
		if not StadiumMountedScoreboardContract._clean(ancestor):
			return false
		ancestor = ancestor.get_parent()
	for node: Node in property.host_children:
		if (
			not is_instance_valid(node)
			or (property.old_nodes.has(node) and node.get_parent() != null)
			or (not property.old_nodes.has(node) and node.get_parent() != property.get_parent())
		):
			return false
	return (
		property.support_intact(false)
		and property.routing_intact()
		and property.issued_intact()
		and property.visibility_intact(false)
	)


static func bind_ball(lab: PitchBatLab, ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	var property: StadiumNpcPublicProperty = _property(lab)
	# Ordinary issued installations already crossed the cold source/geometry boundary.
	# Custom callbacks still select installed() through callback_intact().
	if (
		property == null
		or not property.callback_intact()
		or not is_instance_valid(ball)
		or ball.get_script() != BattedBallBody
		or not ball.is_inside_tree()
		or ball.get_parent() != lab
		or lab._batted_ball != ball
		or resolver != lab._ball_play_resolver
		or resolver.state == null
		or resolver.state.get_script() != BallPlayState
		or resolver.field != property.field
		or resolver.state.dead
	):
		return false
	if property.venue_id == "HILLSIDE" and ball._started:
		return false
	property.bind_contacts(ball, resolver)
	if property.has_ac02_issue():
		return (
			property._ac02_issue_pin != null
			and property._ac02_issue_pin.bound_ball(lab, ball)
			and _ball_wiring(property, ball, resolver)
		)
	return _ball_wiring(property, ball, resolver)


static func rebind_match(lab: PitchBatLab) -> bool:
	var issued_property: StadiumNpcPublicProperty = _property(lab)
	if (
		StadiumNpcAc02IssuedStateV1.current(lab) != null
		or (issued_property != null and issued_property.has_ac02_issue())
	):
		return installed_bound(
			lab, issued_property.public_snapshot if issued_property != null else {}
		)
	# A public installation never adopts a different MatchState or saved fixture.
	return installed(lab)


static func teardown(lab: PitchBatLab) -> bool:
	if is_instance_valid(lab) and lab.ac02_startup_pending():
		if lab._ac02_startup_attempt != null:
			lab._ac02_startup_attempt.abort("teardown interrupted startup")
		return false
	var property: StadiumNpcPublicProperty = _property(lab)
	var issued_owner: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	if (
		issued_owner != null
		and (
			property == null
			or property._ac02_issue_pin != issued_owner
			or not issued_owner.owns_cleanup(lab, property)
		)
	):
		issued_owner.revoke("teardown owner replaced")
		return false
	if (
		not _live_lab(lab)
		or property == null
		or not StadiumPropertyRuntime.authoring_delivery_idle(lab)
		or is_instance_valid(lab._batted_ball)
		or property.lab_ref == null
		or property.lab_ref.get_ref() != lab
	):
		return false
	_restore(lab, property)
	property.free()
	return true


static func _ball_wiring(
	property: StadiumNpcPublicProperty, ball: BattedBallBody, resolver: BallPlayResolver
) -> bool:
	if (
		property.venue_id == "HILLSIDE"
		and (
			property.hillside_support == null
			or not is_instance_valid(property.hillside_support.ground)
			or not property.hillside_support.ground.public_binding_intact(ball, resolver.state)
			or not property.boundary.binding_intact(ball, resolver, resolver.state)
		)
	):
		return false
	if ball.physics_contact_router != property._boundary_contact_batch.bind(resolver):
		return false
	var id: int = ball.get_instance_id()
	if (
		property.venue_id
		not in [
			"AC-01",
			"AC-02",
			"AM-01",
			"AM-02",
			"LONG-YARD",
			"GRAND-I",
			"GRAND-II",
			"GRAND-III",
			"POOL-PARTY",
			"HILLSIDE"
		]
	):
		return (
			ball.body_entered.is_connected(property._ball_contact.bind(ball, resolver))
			and ball.tree_exited.is_connected(property.boundary._forget.bind(id))
		)
	return (
		ball.launch_started.is_connected(property.boundary._seed.bind(id))
		and ball.tree_exited.is_connected(
			property.boundary._forget.bind(id, resolver.get_instance_id())
		)
		and property.boundary._resolver_ids.get(id) == resolver.get_instance_id()
		and property.boundary._bound_balls.get(id) is WeakRef
		and property.boundary._bound_balls[id].get_ref() == ball
		and property.boundary._previous.get(id) is Vector3
		and property.boundary._previous[id].is_finite()
	)


static func _restore(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, deferred: bool = false
) -> void:
	if property.ac02_startup_pending():
		property._abort_startup("preparation restore requested")
		return
	if property.has_ac02_issue():
		property.ac02_revoke("runtime restore")
		if property._ac02_issue_pin != null:
			property._ac02_issue_pin.restore_owned(lab, property, deferred)
		else:
			property.ac02_cleanup_local()
		return
	if property.venue_id == "HILLSIDE":
		_restore_hillside(lab, property)
		return
	# Shared cleanup for explicit teardown and unexpected property removal. The latter can
	# occur inside a busy parent notification, so restore original siblings deferred.
	property.pause_invalid()
	property.disconnect_balls()
	if property.venue_id == "HILLSIDE":
		if property.hillside_support != null:
			property.hillside_support.retire()
		if not property.environment_lease.is_empty():
			property._disconnect_environment()
			StadiumHillsideEnvironmentV1.restore(lab, property.environment_lease)
			property.environment_lease.clear()
	if property.venue_id == "POOL-PARTY" and not property.environment_lease.is_empty():
		property._disconnect_environment()
		StadiumPoolPartyEnvironmentV1.restore(lab, property.environment_lease)
		property.environment_lease.clear()
	if property.venue_id == "GRAND-III" and not property.environment_lease.is_empty():
		property._disconnect_environment()
		StadiumGrandIIIEnvironmentV1.restore(lab, property.environment_lease)
		property.environment_lease.clear()
	if property.venue_id == "GRAND-II" and not property.environment_lease.is_empty():
		property._disconnect_environment()
		StadiumGrandIIEnvironmentV1.restore(lab, property.environment_lease)
		property.environment_lease.clear()
	if property.venue_id == "GRAND-I" and not property.environment_lease.is_empty():
		property._disconnect_environment()
		StadiumGrandIEnvironmentV1.restore(lab, property.environment_lease)
		property.environment_lease.clear()
	if property.venue_id == "LONG-YARD" and not property.environment_lease.is_empty():
		property._disconnect_environment()
		StadiumLongYardEnvironmentV1.restore(lab, property.environment_lease)
		property.environment_lease.clear()
	property.lab_ref = null
	if is_instance_valid(property.display):
		property.display.bind_match(null)
	if is_instance_valid(lab._pitch_actor):
		lab._pitch_actor.receiver_router = property.old_receiver
	if is_instance_valid(lab._ball_play_resolver):
		lab._ball_play_resolver.segment_observer = property.old_observer
	if is_instance_valid(lab._primary_fielder):
		lab._primary_fielder.stadium_boundary_clip = property.old_clip
		lab._primary_fielder.stadium_obstacles = property.old_obstacles
	lab._field_id = property.old_field_id
	lab._field_definition = property.old_field
	if is_instance_valid(lab._camera):
		lab._camera.cull_mask = property.old_camera_mask
	lab._camera_director = property.old_camera
	if is_instance_valid(lab._camera_director):
		lab._camera_director.tracking_visibility = property.old_visibility
	if lab.has_meta("stadium_property") and lab.get_meta("stadium_property") == property:
		lab.remove_meta("stadium_property")
	if property.public_bound:
		# Restored starter geometry cannot continue or report the saved public game.
		if lab.has_meta("stadium_snapshot"):
			lab.remove_meta("stadium_snapshot")
		lab.set_meta(PUBLIC_BOUND, true)
	var originals: Array[Node] = property.old_nodes.duplicate()
	var order: Array[Node] = property.host_children.duplicate()
	property.old_nodes.clear()
	if deferred or property.public_bound:
		var live: bool = (
			property.public_bound
			or not is_instance_valid(lab._pitch_actor)
			or not StadiumPropertyRuntime.authoring_delivery_idle(lab)
			or is_instance_valid(lab._batted_ball)
			or lab._automation != null
		)
		var previous_mode: int = lab.process_mode
		lab.process_mode = Node.PROCESS_MODE_DISABLED
		lab.set_meta("stadium_npc_runtime_restoring", true)
		if live:
			lab.set_meta("stadium_npc_runtime_interrupted", true)
		_restore_originals.call_deferred(
			weakref(lab),
			originals,
			order,
			previous_mode,
			live,
			property.hillside_support if property.venue_id == "HILLSIDE" else null
		)
	else:
		_restore_originals(weakref(lab), originals, order)


static func unexpected_exit(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	if (
		is_instance_valid(lab)
		and is_instance_valid(property)
		and lab.has_meta("stadium_property")
		and lab.get_meta("stadium_property") == property
	):
		_restore(lab, property, true)


static func _restore_originals(
	reference: WeakRef,
	originals: Array[Node],
	order: Array[Node],
	previous_mode: int = -1,
	interrupted: bool = false,
	hillside: StadiumHillsidePublicSupport = null
) -> void:
	if hillside != null:
		_restore_hillside_originals(hillside, originals, order)
		return
	var lab: PitchBatLab = reference.get_ref() as PitchBatLab
	var host: Node = (
		lab.get_node_or_null("StarterFieldGeometry") if is_instance_valid(lab) else null
	)
	if (
		not is_instance_valid(lab)
		or lab.is_queued_for_deletion()
		or not lab.is_inside_tree()
		or not is_instance_valid(host)
		or host.is_queued_for_deletion()
	):
		for node: Node in originals:
			if is_instance_valid(node) and node.get_parent() == null:
				node.free()
		if is_instance_valid(lab) and not lab.is_queued_for_deletion():
			lab.process_mode = Node.PROCESS_MODE_DISABLED
			lab.set_meta("stadium_npc_runtime_interrupted", true)
			lab.remove_meta("stadium_npc_runtime_restoring")
		return
	for node: Node in originals:
		if is_instance_valid(node) and node.get_parent() == null:
			host.add_child(node)
	for index in range(order.size()):
		if is_instance_valid(order[index]) and order[index].get_parent() == host:
			host.move_child(order[index], mini(index, host.get_child_count() - 1))
	if previous_mode >= 0:
		if interrupted:
			# Never resume or manufacture a result for a game whose physical venue vanished.
			lab._automation = null
			if is_instance_valid(lab._pitch_actor):
				lab._pitch_actor.reset_pitch()
			if is_instance_valid(lab._release_controller):
				lab._release_controller.cancel()
			if is_instance_valid(lab._at_bat_cadence):
				lab._at_bat_cadence.stop()
			if hillside == null:
				_cancel_ball(lab)
			else:
				hillside.restore_actors()
		else:
			lab.process_mode = previous_mode as Node.ProcessMode
		lab.remove_meta("stadium_npc_runtime_restoring")


static func _cancel_ball(lab: PitchBatLab) -> void:
	# Mirror ordinary cleanup while tolerating actors destroyed before deferred restoration.
	if is_instance_valid(lab._ball_visibility):
		lab._ball_visibility.clear()
	if is_instance_valid(lab._home_run):
		lab._home_run.active = false
	if is_instance_valid(lab._pitcher_marker):
		lab._pitcher_marker.position = PitchBatLab.MOUND_ORIGIN
		lab._pitcher_marker.rotation = Vector3.ZERO
	if is_instance_valid(lab._batted_ball):
		if lab._batted_ball.surface_contact.is_connected(lab._on_batted_surface_contact):
			lab._batted_ball.surface_contact.disconnect(lab._on_batted_surface_contact)
		lab._batted_ball.queue_free()
	lab._batted_ball = null
	if is_instance_valid(lab._primary_fielder):
		lab._primary_fielder.end_play()
	lab._settled_seconds = 0.0


static func admits_action(lab: PitchBatLab) -> bool:
	var issued_owner: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	if issued_owner != null:
		return issued_owner.continue_action(lab)
	if not is_instance_valid(lab):
		return false
	var applies: bool = (
		lab.has_meta(PUBLIC_BOUND)
		or (lab._match_state != null and supports_snapshot(lab._match_state.stadium))
	)
	if not applies:
		return true
	var property: StadiumNpcPublicProperty = _property(lab)
	if pending_hillside(lab):
		return false
	if is_instance_valid(property) and property.callback_intact():
		if (
			property.venue_id == "GRAND-III"
			and (
				property.public_snapshot.environment.get("version")
				== StadiumGrandIIIEnvironmentV1.TIME_ENVIRONMENT_VERSION
			)
		):
			var state: MatchState = lab._match_state
			if (
				StadiumGrandIIIEnvironmentV1.advance_time(lab, property.environment_lease)
				and is_instance_valid(property)
				and _property(lab) == property
				and lab._match_state == state
				and property.callback_intact()
			):
				return true
			if (
				is_instance_valid(property)
				and _property(lab) == property
				and lab._match_state == state
			):
				property.pause_invalid()
			return false
		return true
	if is_instance_valid(property):
		property.pause_invalid()
	else:
		refuse_bound_start(lab)
	return false


static func _construction_valid(property: StadiumNpcPublicProperty, remap: bool = false) -> bool:
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime._construction_valid")
	var ac02_result: bool = _ac02_passive_01_private_construction_valid(property, remap)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_private_construction_valid(
	property: StadiumNpcPublicProperty, remap: bool = false
) -> bool:
	match property.venue_id:
		"HILLSIDE":
			return StadiumHillsidePublicConstruction.valid(property)
		"POOL-PARTY":
			return StadiumPoolPartyPublicConstruction.valid(property)
		"GRAND-III":
			return StadiumGrandIIIPublicConstruction.valid(property)
		"GRAND-II":
			return StadiumGrandIIPublicConstruction.valid(property)
		"GRAND-I":
			return StadiumGrandIPublicConstruction.valid(property)
		"LONG-YARD":
			return StadiumLongYardPublicConstruction.valid(property)
		"AC-02":
			return StadiumNpcAc02PublicConstruction.valid(property)
		"AE-02":
			return StadiumNpcAe02PublicConstruction.valid(property)
		"AM-02":
			return StadiumNpcAm02PublicConstruction.valid(property)
		"AM-01":
			return StadiumNpcAm01PublicConstruction.valid(property)
	return (
		StadiumNpcCandidateConstructionV2.remap(property)
		if remap
		else (StadiumNpcCandidateConstructionV2.valid(property))
	)


static func _construction_same(
	actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty, admission: Variant = null
) -> bool:
	var ac02_token: int = AC02_PASSIVE_1.enter("stadium_npc_public_runtime._construction_same")
	var ac02_result: bool = _ac02_passive_01_private_construction_same(actual, expected, admission)
	AC02_PASSIVE_1.leave(ac02_token)
	return ac02_result


static func _ac02_passive_01_private_construction_same(
	actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty, admission: Variant = null
) -> bool:
	match actual.venue_id:
		"HILLSIDE":
			return StadiumHillsidePublicConstruction.same(actual, expected)
		"POOL-PARTY":
			return StadiumPoolPartyPublicConstruction.same(actual, expected)
		"GRAND-III":
			var lighting_root: Node
			if not actual.environment_lease.is_empty():
				var lab: PitchBatLab = actual.lab_ref.get_ref() if actual.lab_ref != null else null
				if not StadiumGrandIIIEnvironmentV1.installed(lab, actual.environment_lease):
					return false
				lighting_root = actual.environment_lease.active_lighting.root
			return StadiumGrandIIIPublicConstruction.same(actual, expected, lighting_root)
		"GRAND-II":
			var lighting_root: Node
			if not actual.environment_lease.is_empty():
				var lab: PitchBatLab = actual.lab_ref.get_ref() if actual.lab_ref != null else null
				if not StadiumGrandIIEnvironmentV1.installed(lab, actual.environment_lease):
					return false
				lighting_root = actual.environment_lease.active_lighting.root
			return StadiumGrandIIPublicConstruction.same(actual, expected, lighting_root)
		"GRAND-I":
			var lighting_root: Node
			if not actual.environment_lease.is_empty():
				var lab: PitchBatLab = actual.lab_ref.get_ref() if actual.lab_ref != null else null
				if not StadiumGrandIEnvironmentV1.installed(lab, actual.environment_lease):
					return false
				lighting_root = actual.environment_lease.active_lighting.root
			return StadiumGrandIPublicConstruction.same(actual, expected, lighting_root)
		"LONG-YARD":
			return StadiumLongYardPublicConstruction.same(actual, expected)
		"AC-02":
			return StadiumNpcAc02PublicConstruction.same(actual, expected, admission)
		"AE-02":
			return StadiumNpcAe02PublicConstruction.same(actual, expected)
		"AM-02":
			return StadiumNpcAm02PublicConstruction.same(actual, expected)
		"AM-01":
			return StadiumNpcAm01PublicConstruction.same(actual, expected)
	return StadiumNpcRetainedGeometry.same(actual, expected)


static func pending_hillside(lab: PitchBatLab) -> bool:
	var property: StadiumNpcPublicProperty = _property(lab)
	return (
		is_instance_valid(property)
		and property.venue_id == "HILLSIDE"
		and lab.hillside_public_pending == property
		and property.hillside_support != null
		and property.hillside_support.pending
		and not property.suspended
	)


static func _finish_hillside_install(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, state: MatchState
) -> void:
	# Keep the captured cleanup lease even if its Node owner exits during this wait.
	var support: StadiumHillsidePublicSupport = property.hillside_support
	await lab.get_tree().physics_frame
	if not is_instance_valid(property):
		if support != null:
			support.retire()
			support.report_install(false)
		return
	if (
		support == null
		or not support.cleanup_owned()
		or not is_instance_valid(lab)
		or not lab.is_inside_tree()
		or lab._match_state != state
		or property.bound_state != state
		or _property(lab) != property
		or lab.hillside_public_pending != property
		or property.hillside_support != support
		or not _public_context(lab, property)
		or not support.finish_registration()
	):
		_restore(lab, property)
		property.queue_free()
		if support != null:
			support.report_install(false)
		return
	property.rebind(state)
	if not support.cleanup_owned():
		_restore(lab, property)
		property.queue_free()
		return
	PitchBatLabPresentation.refresh_markers(lab)
	if (
		not support.cleanup_owned()
		or not installed(lab)
		or not property.issue_installation()
		or not support.resume_processing()
	):
		_restore(lab, property)
		property.queue_free()
		support.report_install(false)
		return
	# No callback-created match inherits the captured continuation or its completion signal.
	lab._finish_hillside_public_start(property, state)
	support.report_install(
		(
			is_instance_valid(property)
			and _property(lab) == property
			and property.issued
			and not property.suspended
		)
	)


static func reject_hillside_candidate(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, ball: BattedBallBody
) -> void:
	# Dispose the captured candidate even if its property was freed. Never select lab._batted_ball.
	if is_instance_valid(property):
		property.clear_hillside_ball(ball)
	if is_instance_valid(ball) and ball.get_script() == BattedBallBody:
		ball.freeze = true
		ball.physics_contact_router = Callable()
		if (
			is_instance_valid(lab)
			and ball.surface_contact.is_connected(lab._on_batted_surface_contact)
		):
			ball.surface_contact.disconnect(lab._on_batted_surface_contact)
		if (
			is_instance_valid(property)
			and property.hillside_support != null
			and property.hillside_support.cleanup_owned()
			and lab._batted_ball == ball
		):
			lab._batted_ball = null
		ball.queue_free()
	if is_instance_valid(property):
		property.retire_installation("Hillside candidate or owner changed during callback")


static func _restore_hillside(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var support: StadiumHillsidePublicSupport = property.hillside_support
	property.pause_invalid()
	property.disconnect_balls()
	var originals: Array[Node] = property.old_nodes.duplicate()
	var order: Array[Node] = property.host_children.duplicate()
	property.old_nodes.clear()
	if support == null or not support.cleanup_owned():
		property._disconnect_environment()
		if not property.environment_lease.is_empty():
			StadiumHillsideEnvironmentV1.abandon(lab, property.environment_lease)
		property.environment_lease.clear()
		property.lab_ref = null
		_dispose_hillside_originals(originals)
		return
	property.environment_lease.clear()
	# These are still the captured slots, verified after all pause/presentation callbacks.
	lab._pitch_actor.receiver_router = property.old_receiver
	lab._ball_play_resolver.segment_observer = property.old_observer
	lab._primary_fielder.stadium_boundary_clip = property.old_clip
	lab._primary_fielder.stadium_obstacles = property.old_obstacles
	lab._field_id = property.old_field_id
	lab._field_definition = property.old_field
	lab._camera.cull_mask = property.old_camera_mask
	lab._camera_director = property.old_camera
	if is_instance_valid(lab._camera_director):
		lab._camera_director.tracking_visibility = property.old_visibility
	if lab.has_meta("stadium_snapshot"):
		lab.remove_meta("stadium_snapshot")
	lab.set_meta(PUBLIC_BOUND, true)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab.set_meta("stadium_npc_runtime_restoring", true)
	lab.set_meta("stadium_npc_runtime_interrupted", true)
	if not support.begin_restore():
		_dispose_hillside_originals(originals)
		return
	property.lab_ref = null
	_restore_hillside_originals.call_deferred(support, originals, order)


static func _dispose_hillside_originals(originals: Array[Node]) -> void:
	for node: Node in originals:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()


static func _restore_hillside_originals(
	support: StadiumHillsidePublicSupport, originals: Array[Node], order: Array[Node]
) -> void:
	if (
		not support.cleanup_owned()
		or not support._lab.is_inside_tree()
		or support._lab.is_queued_for_deletion()
		or support._host.is_queued_for_deletion()
	):
		_dispose_hillside_originals(originals)
		return
	var lab: PitchBatLab = support._lab
	var host: Node = support._host
	for node: Node in originals:
		if is_instance_valid(node) and node.get_parent() == null:
			host.add_child(node)
			if not support.cleanup_owned():
				_dispose_hillside_originals(originals)
				return
	for index in range(order.size()):
		if is_instance_valid(order[index]) and order[index].get_parent() == host:
			host.move_child(order[index], mini(index, host.get_child_count() - 1))
			if not support.cleanup_owned():
				return
	support.restore_actors()
	if support.cleanup_owned():
		lab.remove_meta("stadium_npc_runtime_restoring")
		support.end_restore()


static func _stage_startup(attempt: RefCounted) -> StadiumNpcPublicProperty:
	var lab: PitchBatLab = attempt.lab
	if not attempt.context() or not _admissible(lab) or not source_qualified():
		return null
	var property: StadiumNpcPublicProperty = _construct(lab, "AC-02")
	if property == null:
		return null
	property.bound_state = lab._match_state
	property.public_snapshot = lab._match_state.stadium.duplicate(true)
	property.public_season = lab._npc_season
	property.public_assignments = lab._npc_season.npc_venues.duplicate(true)
	property.public_fixture = (
		SeasonVenues
		. fixture_for_id(lab._npc_season, int(property.public_snapshot.binding.fixture))
		. duplicate(true)
	)
	property.public_automation = lab._automation
	property.public_managed = lab._managed_match
	property.process_priority = -100
	property.process_physics_priority = -100
	return property


static func _commit_startup(attempt: RefCounted, property: StadiumNpcPublicProperty) -> bool:
	var lab: PitchBatLab = attempt.lab
	if (
		not attempt.owns(property)
		or not _admissible(lab)
		or not _public_context(lab, property)
		or property.get_parent() != null
		or not source_qualified()
		or not attempt.preflight(property)
	):
		return false
	PitchBatLabPresentation.refresh_markers(lab)
	var host: StarterFieldLabGeometry = lab.get_node("StarterFieldGeometry")
	if not attempt.context() or not attempt._tree_edges(host):
		return false
	property.host_children.assign(host.get_children())
	property.old_field_id = lab._field_id
	property.old_field = lab._field_definition
	property.old_camera_mask = lab._camera.cull_mask
	property.old_camera = lab._camera_director
	property.old_visibility = lab._camera_director.tracking_visibility
	property.old_observer = lab._ball_play_resolver.segment_observer
	property.old_clip = lab._primary_fielder.stadium_boundary_clip
	property.old_obstacles = lab._primary_fielder.stadium_obstacles.duplicate(true)
	property.old_receiver = lab._pitch_actor.receiver_router
	for id: String in REMOVED:
		var old: Node = host.get_node_or_null(NodePath(id))
		if old != null:
			if not attempt._tree_edges(old):
				return false
			property.old_nodes.append(old)
			attempt.originals.append(old)
			host.remove_child(old)
			if not attempt.owns(property) or lab.get_node_or_null("StarterFieldGeometry") != host:
				return false
	host.add_child(property)
	if (
		not attempt.owns(property)
		or property.get_parent() != host
		or lab.get_node_or_null("StarterFieldGeometry") != host
	):
		return false
	lab.set_meta("stadium_property", property)
	lab.set_meta(PUBLIC_BOUND, true)
	lab.set_meta("stadium_snapshot", property.public_snapshot.duplicate(true))
	property.lab_ref = weakref(lab)
	lab._field_id = property.field.id
	lab._field_definition = property.field
	lab._ball_play_resolver.segment_observer = property.observe
	lab._primary_fielder.stadium_boundary_clip = property.clip
	lab._primary_fielder.stadium_obstacles = property.route_obstacles()
	lab._pitch_actor.receiver_router = property.receiver_route
	var camera: StadiumNpcAc02PublicCamera = StadiumNpcAc02PublicCamera.new()
	camera.lab_ref = weakref(lab)
	camera.camera_mask |= 64
	for key: String in CAMERA_STATE:
		camera.set(key, lab._camera_director.get(key))
	lab._camera_director = camera
	camera.tracking_visibility = _visibility("AC-02")
	var startup_view: StadiumNpcAc02PublicVisibility = (
		camera.tracking_visibility as StadiumNpcAc02PublicVisibility
	)
	if startup_view == null or not startup_view._configure_startup(attempt, property):
		return false
	property.presentation_director = camera
	property.presentation_camera = weakref(lab._camera)
	property.ac02_guides = StadiumNpcAc02PublicGuides.new()
	if not property.ac02_guides._configure_startup(attempt, property):
		return false
	property.pin_lab(lab)
	property.rebind(lab._match_state)
	if not attempt.markers() or not property._ac02_startup_receiver(attempt):
		return false
	if StadiumWallRenderQuality.attach(property):
		attempt.wall_viewport = weakref(property.get_viewport())
	return attempt.setup_owners(property)

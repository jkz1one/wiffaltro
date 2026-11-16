class_name StadiumNpcRetainedCompatibility
extends RefCounted
## Qualification compatibility contract v3, not a gameplay/environment certificate.
## These exact implementations plus retained construction are the supported semantics.
## Drift fails isolated installation; it does not re-sign historical r1 manifest bytes.
## Engine/renderer/runtime source identity belongs to the external qualification packet.

const VERSION: int = 3
const SOURCES: Dictionary = {
	"res://src/presentation/equipment/bat_actor.gd":
		"0ffde0469bae52363304cf94d5d2c6b0f8d0b786e1847b5108626e2a04456c14",
	"res://src/presentation/players/player_avatar.gd":
		"f2bb9e1e1fa7ab7fd44d2d48d76804c866d0675512f3b4f70e6dca4c1b99c485",
	"res://src/presentation/stadium/stadium_actor_cutaway_study.gd":
		"8a12c94f402ea835ee645cc190ec108749aef23e7cf904babf94d114d7ef14d7",
	"res://src/gameplay/stadium/stadium_club_boundary_sweep.gd":
		"f87c563a798e14b154196b7de63c6ab735e191db4b30fbe8c2a5d9bd59807ca1",
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
	"res://src/presentation/stadium/stadium_club_boundary_study.gd":
		"c200f6aba39e2b0ae665608a5c6293dd84c721f6359b66702ebb491542c37bbd",
	"res://src/presentation/stadium/stadium_club_field_visibility.gd":
		"d1f9efe0b32cb9904a95d03ddb303fed40e2cd8e8aed9ca7ab590f4c5adb646b",
	"res://src/presentation/stadium/stadium_club_pitch_receiver.gd":
		"1330538a5b012c6f82af8665241d1d6efe381ca964bbe4c28f1d74e44f4e70ca",
	"res://src/presentation/stadium/stadium_club_receiver_visibility.gd":
		"ba9fab81b48e9c591fdbe00ff19ecd102a520beb235f4d50c908219845852778",
	"res://src/presentation/stadium/stadium_receiver_net_models.gd":
		"cec34955f5d8d52b9a7df68034667cb2ba10fab29aaf612f257f0fe20a2ad7ef",
	"res://src/presentation/stadium/stadium_target_models.gd":
		"0334e3bc2588f17a2a7ec1f6d64209dedea8336c67461930415248f228d7ba0a",

	"res://src/gameplay/fielding/defender_spacing.gd":
		"60a99a60e46f45863a35c319a1b9a3cf100263b6bb0a3454000f7924d7ff5040",
	"res://src/gameplay/match/match_state.gd":
		"cdbcc87195fd80a23119552b9026b6d0934cbf62f90d98f2137c92c3027f99b8",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab.gd":
		"fbf5cb3ce2d6502c93bf21d80510f02d1bedb083e8c70af85243cd4311fb03ac",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab_defense_support.gd":
		"3227e3358e432ced68d359e8578a8e37f05c1392a38e103185f807ade8a016a3",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab_presentation.gd":
		"a522fb5099d54eee83ccaa77eef0d3e781a94bf4a332d9429e0de22a961925a6",
	"res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd":
		"0be889d48a37c9e5d017fcd234b2289cc8928a386605352557a6c7631ceeb9e5",
	"res://src/presentation/camera/match_camera_director.gd":
		"84f2cd886f686c6dbec4e7aa8a57d72f06c276d36f4b6bee076e33a46430aedb",
	"res://src/presentation/fielding/fielder_controller.gd":
		"1b982fec0971e212900bc183c97953865f6027abb71c76f56b213579f132fab6",
	"res://src/presentation/stadium/stadium_property_geometry.gd":
		"779ce82a8bc9ff872dc3e1cf5c50552f5cf7eaa5914e5857d9459904cbaf89af",
	"res://src/content/definitions/definition_base.gd":
		"d03b3f1f855f51f1f2e3a99f1be99a626cfe523e39c76bd9576b16cb6af4876f",
	"res://src/content/definitions/field_definition.gd":
		"39cf09ce92b00c8c0d784f5e738623b810b512a12c3b3c9294a5133b33f413d2",
	"res://src/gameplay/ball_in_play/ball_play_resolver.gd":
		"371da37f8112eb6da3881aa07b3225ddc4c6cfd4160d29eb06fc55241dbdaa4a",
	"res://src/gameplay/ball_in_play/ball_play_state.gd":
		"8a31d563ea78bfa6637def55aeb83dcd036bb16a187773fece4e852676ad8c4c",
	"res://src/gameplay/stadium/stadium_boundary_observer.gd":
		"406b1050fd62c2077d6804ee28d23662dd88bf1b71c1ff786bab900d2391a08c",
	"res://src/gameplay/stadium/stadium_defender_routes.gd":
		"409a38d7c349d2b6040725c7f6cceb7863ab98c6d7941d1fa015cedba4908646",
	"res://src/gameplay/stadium/stadium_recipe_boundary.gd":
		"a98381fd78d1f32fcd58ad7dbd2f29b29634c7b3572159980e781ffb6c66aca8",
	"res://src/gameplay/stadium/stadium_surface_rules.gd":
		"53ca09eff0ce6798aafec51ccbc07339edefdf16aee9b3852b7eeea7c2434f0e",
	"res://src/presentation/ball/batted_ball_body.gd":
		"706bdcdb59030712ce4d90994e32ce8727e3806ddb45e584843e9b8d34f66b6e",
	"res://src/presentation/ball/pitch_flight_actor.gd":
		"79a51e1fd14077d0ab1be26a61bed531124e9c4349806af9bc9a0321efb7464d",
	"res://src/presentation/camera/ball_tracking_visibility.gd":
		"344e28784f900c6f660c55574330a8afc2d8c46b7149edfa28841957952253a8",
	"res://src/presentation/camera/stadium_wall_view_prisms.gd":
		"c84ce7c1b7eb913589c06e928ea7536dca51ee346203dd4ab9186ff9b137beda",
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
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_boundary_v1.gd":
		"40adbae31d956f96373def06acfc3415991d2c0993df215f2363e3ed671f351c",
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_graph_v1.gd":
		"c9472dd2fc773fe7dea49b701ebda52994c4d4d9874371835576d8599c6da3c7",
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_seating_v1.gd":
		"d18cf66a3d37b2ea60c19f26602b12a4bee4f6aec8d5e184e7504cdb3903953d",
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_v1.gd":
		"39261921875eedb0bf6058f6cb0829be36d11544400e9ff3a99e92f562d9fadd",
	"res://src/presentation/stadium/stadium_club_camera_director.gd":
		"962d0a3aaebdc67bf2cbcdb5d12b6dd685d18039c908e5f2f09ac658087d54a2",
	"res://src/presentation/stadium/stadium_expanded_camera_director.gd":
		"13044baf5de24345d9a34aa950d4da6684cb6c6c357cec06c819ed7b3a4c4790",
	"res://src/presentation/stadium/stadium_paired_receiver.gd":
		"4a5b8429e56c31a8b29e6a22c783e5a8bfa422e0191cb6eebf4a0b44c40bccaf",
	"res://src/presentation/stadium/stadium_pitch_receiver.gd":
		"8980a5bd60c3429f01e165ec36a8c9b2bc12387af413dd9edf6b4002c3190e77",
	"res://src/presentation/stadium/stadium_receiver_visibility.gd":
		"6e91b28a5d7ff5282e531efa2df0965ec2b5076f82ff734ab71446edf13f007d",
	"res://src/presentation/stadium/stadium_target_receiver.gd":
		"99341f1fbc0040236183eed3fb0693444db8bee10ba9b339f550e5f15b12d78b",
}


static func valid() -> bool:
	for path: String in SOURCES:
		if FileAccess.get_sha256(path) != SOURCES[path]:
			return false
	return club_receiver_valid() \
		and PitchFlightActor.RECEIVER_PLANE_Z == StadiumNpcYardV1.RECEIVER.plane_z \
		and PitchFlightActor.MIN_RECEIVER_TRAVEL_SECONDS == StadiumNpcYardV1.RECEIVER.min_travel \
		and PitchFlightActor.MAX_RECEIVER_TRAVEL_SECONDS == StadiumNpcYardV1.RECEIVER.max_travel \
		and PitchFlightActor.RECEIVER_HOLD_SECONDS == StadiumNpcYardV1.RECEIVER.hold \
		and StadiumPitchReceiver.STEP == StadiumNpcExpandedV1.RECEIVER.step \
		and StadiumPitchReceiver.TIMEOUT == StadiumNpcExpandedV1.RECEIVER.timeout \
		and StadiumPairedReceiver.PAIR_CLEANUP_Z == StadiumNpcExpandedV1.RECEIVER.cleanup_z


static func club_receiver_valid() -> bool:
	return StadiumPitchReceiver.STEP == StadiumNpcClubV1.RECEIVER.step \
		and StadiumClubPitchReceiver.PAIR_TIMEOUT == StadiumNpcClubV1.RECEIVER.timeout \
		and StadiumClubPitchReceiver.PAIR_CLEANUP == StadiumNpcClubV1.RECEIVER.cleanup_z \
		and StadiumClubPitchReceiver.CAMERA_CUT == StadiumNpcClubV1.RECEIVER.camera_cut_z \
		and StadiumNpcClubNetV1.SETTLE == StadiumNpcClubV1.RECEIVER.net_settle_duration \
		and StadiumNpcClubNetV1.FLEX == StadiumNpcClubV1.RECEIVER.net_flex_depth

class_name StadiumNpcYardProvenance
extends RefCounted
## Admission-time provenance check, deliberately separate from pure historical lookup.
## Changes require review/versioned retention, never automatic re-signing of the literal.

const SOURCES: Dictionary = {
	"res://src/content/definitions/definition_base.gd":
	"d03b3f1f855f51f1f2e3a99f1be99a626cfe523e39c76bd9576b16cb6af4876f",
	"res://src/content/definitions/field_definition.gd":
	"39cf09ce92b00c8c0d784f5e738623b810b512a12c3b3c9294a5133b33f413d2",
	"res://src/content/fields/starter_field.tres":
	"b4cb96881a07e3980ecf4aba157bd7137b82ec75cb3d21b155d5bd2f699e1416",
	"res://src/gameplay/stadium/stadium_boundary_graph.gd":
	"0d7c7c9d81a3b5817bf6a04e66b092af946721b75e344134a90b1e0c1f4dcbda",
	"res://src/gameplay/stadium/stadium_catalog.gd":
	"b52cf22b397a5369c7759f02dd6a9d8fa265c84a66ba6b5864985c428d9daaf2",
	"res://src/gameplay/stadium/stadium_property.gd":
	"594b08bf9420b7221c6e4dc741b3bb5e9720065c2e3ff5fdc88054e4688e3bd6",
	"res://src/gameplay/stadium/stadium_yard_fixture_study.gd":
	"882f3891a69fd2d91627877e85cb606f8773140822cd523e2287fe83d9cda8c4",
	"res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd":
	"0be889d48a37c9e5d017fcd234b2289cc8928a386605352557a6c7631ceeb9e5",
	"res://src/presentation/ball/pitch_flight_actor.gd":
	"79a51e1fd14077d0ab1be26a61bed531124e9c4349806af9bc9a0321efb7464d",
	"res://src/presentation/stadium/stadium_boundary_prototype.gd":
	"5b7e8fe60a44b875e5e0e66ce2fe3d8a995e4482c8de79dedbaabcb9adc0d88a",
	"res://src/presentation/stadium/stadium_property_geometry.gd":
	"779ce82a8bc9ff872dc3e1cf5c50552f5cf7eaa5914e5857d9459904cbaf89af",
	"res://src/presentation/stadium/stadium_seating_models.gd":
	"56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb",
	"res://src/presentation/stadium/stadium_yard_field_visibility.gd":
	"b538a2095df380d4bcddb076505cfc8fac2f1afd7087973da0f1455edef83a04",
	"res://src/presentation/stadium/stadium_yard_lab.gd":
	"1e28e54ba4543ebe23f190b52917b6257d8649d8db34e83c1d9cc059537f8ae0",
	"res://src/presentation/stadium/stadium_yard_venue_study.gd":
	"1cea7b608501022f95b7a3b537087c914d5f69f1f014c8801f15959375933a87"
}

const CONSTRUCTION_SOURCES: Dictionary = {
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_boundary_v1.gd":
	"40adbae31d956f96373def06acfc3415991d2c0993df215f2363e3ed671f351c",
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_graph_v1.gd":
	"c9472dd2fc773fe7dea49b701ebda52994c4d4d9874371835576d8599c6da3c7",
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_seating_v1.gd":
	"d18cf66a3d37b2ea60c19f26602b12a4bee4f6aec8d5e184e7504cdb3903953d",
	"res://src/presentation/stadium/npc_yard_v1/stadium_npc_yard_v1.gd":
	"39261921875eedb0bf6058f6cb0829be36d11544400e9ff3a99e92f562d9fadd"
}

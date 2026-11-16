extends Node3D
## Opt-in art/clearance preview only. There is no match, ownership or save integration.

@export var enable_center_board: bool = false
@export_enum("straight", "deeper_center", "left_loft", "right_shelf", "offset_gables")
var wall_shape: String = "offset_gables"
var _board: Node3D
var _camera: Camera3D
var _director: MatchCameraDirector = MatchCameraDirector.new()


func _ready() -> void:
	if not enable_center_board:
		return
	var graph: StadiumRecipeBoundary = StadiumCenterBoardCandidate.graph_for(wall_shape)
	var checked: Dictionary = StadiumCenterBoardCandidate.inspect(graph)
	if not checked.ok:
		push_error(checked.error)
		return
	set_meta("stadium_candidate_only", true)
	_board = StadiumCenterBoardCandidate.create(true)
	_board.transform = StadiumCenterBoardCandidate.pose()
	add_child(_board)
	var state: MatchState = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD CLUB")
	state.inning = 7
	state.home_team.runs = 12
	state.away_team.runs = 9
	state.balls = 2
	state.strikes = 1
	state.outs = 2
	StadiumCenterBoardCandidate.display(_board).bind_match(state)
	var wall: StadiumRecipeBoundaryBody
	if wall_shape == "offset_gables":
		wall = StadiumOffsetBoundaryBody.new()
	elif wall_shape in StadiumHeightWallRecipes.SHAPES:
		wall = StadiumHeightBoundaryBody.new()
	else:
		wall = StadiumRecipeBoundaryBody.new()
	wall.build(wall_shape, "ST-024")
	add_child(wall)
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.mesh = BoxMesh.new()
	ground.mesh.size = StadiumProperty.ground_bounds("backyard").size
	ground.position = StadiumProperty.ground_bounds("backyard").get_center()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("68734c")
	ground.material_override = material
	add_child(ground)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.2
	add_child(light)
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("8fa6b4")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("ffffff")
	world.environment.ambient_light_energy = 0.6
	add_child(world)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true
	_review_camera()
	var hint: Label = Label.new()
	hint.position = Vector2(16, 16)
	hint.text = "CENTER BOARD STUDY | 1: overview  2: right batting  3: left batting\n" \
		+ "Visual prototype only; no saved layout, purchases or gameplay activation"
	add_child(hint)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _camera == null:
		return
	if event.keycode == KEY_1:
		_review_camera()
	elif event.keycode in [KEY_2, KEY_3]:
		_director.set_batter_handedness(event.keycode == KEY_3)
		_director.set_shot(MatchCameraDirector.Shot.BATTING)
		_director.snap(_camera)


func _review_camera() -> void:
	_camera.position = Vector3(9, 10, 18)
	_camera.look_at(Vector3(0, 5.4, 30.75))

class_name StadiumCenterBoardProperty
extends StadiumAdvancedPropertyGeometry
## Complete isolated authoring substrate. No owned board placement or snapshot family.

const PROVENANCE: String = "center-board-live-authoring-v1"
var candidate: Node3D
var celebration: StadiumCenterBoardCelebration


func build_candidate(shape: String, explicit_opt_in: bool = false) -> bool:
	if not explicit_opt_in or not build_authoring_field(shape):
		return false
	candidate = StadiumCenterBoardCandidate.create(true)
	if candidate == null:
		return _rollback()
	candidate.transform = StadiumCenterBoardCandidate.pose()
	add_child(candidate)
	set_meta("stadium_candidate_only", true)
	return true


func build_authoring_field(shape: String) -> bool:
	if get_child_count() != 0 or shape not in StadiumCenterBoardCandidate.SHAPES \
		or not StadiumCenterBoardCandidate.inspect(StadiumCenterBoardCandidate.graph_for(shape)).ok:
		return false
	# Reuse the full ground/plate/mound/field builder, with no authored ownership,
	# purchase quotes, fabricated old site, paid fixture or saved season mutation.
	if not build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()):
		return false
	boundary = StadiumOffsetBoundaryBody.new() if shape == "offset_gables" else (
		StadiumHeightBoundaryBody.new() if shape in StadiumHeightWallRecipes.SHAPES \
		else StadiumRecipeBoundaryBody.new())
	if not boundary.build(shape, "ST-024"):
		return _rollback()
	get_node("TemplateBackWall").free()
	boundary.name = "BoundaryGraph"
	add_child(boundary)
	set_meta("center_board_authoring_source", PROVENANCE)
	set_meta("center_board_wall_shape", shape)
	return true


func rebind_displays(state: MatchState) -> void:
	super.rebind_displays(state)
	if is_instance_valid(celebration):
		celebration.bind_match(state)
	if is_instance_valid(candidate):
		StadiumCenterBoardCandidate.display(candidate).bind_match(state)


func bind_celebration(lab: PitchBatLab) -> void:
	celebration = StadiumCenterBoardCelebration.new()
	celebration.name = "CenterBoardCelebration"
	add_child(celebration)
	celebration.configure(lab, candidate)


func _exit_tree() -> void:
	# Drop held/pending scores and the old MatchState on teardown as well as null unbind.
	rebind_displays(null)

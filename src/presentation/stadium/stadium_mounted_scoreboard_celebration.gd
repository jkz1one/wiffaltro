class_name StadiumMountedScoreboardCelebration
extends StadiumScoreboardCelebrationCore
## Normal exact-owned-center binding. Never accepts authoring provenance or eligibility flags.

var _property: StadiumScoreboardPropertyGeometry
var _frozen: Dictionary = {}


func _bind(lab: PitchBatLab, property: StadiumScoreboardPropertyGeometry,
	frozen: Dictionary) -> void:
	# Called only by the shared installer after its same-call paid-prefix validation.
	_property = property
	_frozen = frozen.duplicate(true)
	_configure(lab, StadiumScoreboardAssembly.center_model(property))


func _eligible() -> bool:
	return is_instance_valid(_lab) and is_instance_valid(_board) \
		and is_instance_valid(_property) and is_instance_valid(_director) \
		and is_instance_valid(_resolver) and is_instance_valid(_camera) \
		and StadiumMountedPresentationContract.camera_target(_lab) \
		and get_parent() == _property \
		and _property.celebration == self and _property.is_visible_in_tree() \
		and _lab._match_state != null and _lab._home_run != null and _lab._match_mode \
		and _lab._field_id == PitchBatLab.FIELD_ID \
		and _lab._camera == _camera and _lab._camera_director == _director \
		and _lab._ball_play_resolver == _resolver \
		and _director.presentation_override == _update_camera \
		and StadiumMountedPresentationContract.listeners_match(self) \
		and _lab.get_meta("stadium_property", null) is StadiumScoreboardPropertyGeometry \
		and _lab.get_meta("stadium_property") == _property \
		and _lab.get_node_or_null("StarterFieldGeometry/HomeProperty") == _property \
		and StadiumScoreboardAssembly.center_model(_property) == _board \
		and ClubCareer.same(_lab._match_state.stadium, _frozen) \
		and _lab.get_meta("stadium_snapshot", {}) is Dictionary \
		and ClubCareer.same(_lab.get_meta("stadium_snapshot", {}), _frozen) \
		and StadiumMountedScoreboardContract.origin_clean(_lab)

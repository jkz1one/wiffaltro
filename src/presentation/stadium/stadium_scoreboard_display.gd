class_name StadiumScoreboardDisplay
extends Node3D
## Read-only manual-board numbers. New scores wait until an actionable pitch/play ends.

var shown: Dictionary = {"inning": 1, "home": 0, "away": 0}
var _pending: Dictionary = {}
var _labels: Dictionary = {}
var _match: MatchState


func build() -> void:
	if not _labels.is_empty():
		return
	for index in range(3):
		var key: String = ["inning", "home", "away"][index]
		var x: float = (index - 1) * 1.4
		_label(key.to_upper(), Vector3(x, 3.90, 0.15), 12)
		_labels[key] = _label(str(shown[key]), Vector3(x, 3.73, 0.15), 24)
	set_process(false)


func bind_match(state: MatchState) -> void:
	_match = state
	set_process(state != null)


func present(value: Dictionary, pitch_active: bool) -> bool:
	if not SeasonOwnership._keys(value, ["inning", "home", "away"]):
		return false
	for key: String in value:
		if not SeasonOwnership._whole(value[key], 1 if key == "inning" else 0, 9999):
			return false
	_pending = {"inning": int(value.inning), "home": int(value.home), "away": int(value.away)}
	if not pitch_active and shown != _pending:
		shown = _pending.duplicate(true)
		for key: String in _labels:
			_labels[key].text = str(shown[key])
	return true


func _process(_delta: float) -> void:
	if _match == null or _match.home_team == null or _match.away_team == null:
		return
	present({"inning": _match.inning, "home": _match.home_team.runs, "away": _match.away_team.runs},
		_match.phase in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY])


func _label(text: String, point: Vector3, size: int) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = point
	label.font_size = size
	label.pixel_size = 0.010
	label.modulate = Color("dcd8c4")
	label.outline_size = 0
	add_child(label)
	return label

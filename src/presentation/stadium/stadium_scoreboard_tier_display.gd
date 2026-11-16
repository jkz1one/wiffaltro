class_name StadiumScoreboardTierDisplay
extends StadiumScoreboardDisplay
## New candidate readouts share the held-score rule across every live component.

var tier: String = "manual"
var details: Dictionary = {}
var _detail_labels: Dictionary = {}


func build() -> void:
	if not _labels.is_empty() or not StadiumScoreboardTiers.TIERS.has(tier):
		return
	for key: String in StadiumScoreboardTiers.readouts(tier):
		var slot: Dictionary = StadiumScoreboardTiers.readouts(tier)[key]
		var label: Label3D = _make(str(shown.get(key, "—")), slot)
		label.modulate = Color("eee4c7") if tier == "manual" else (
			Color("efd48a") if tier == "electronic" else Color("def0e9"))
		_labels[key] = label
		if tier == "manual":
			var heading: Label3D = _label(key.to_upper(), Vector3(slot.point.x, 5.03, 0.32), 28)
			heading.pixel_size = 0.009
	for key: String in StadiumScoreboardTiers.detail_slots(tier):
		var slot: Dictionary = StadiumScoreboardTiers.detail_slots(tier)[key]
		var fallback: String = "AWAY" if key == "away_name" else "HOME" if key == "home_name" \
			else "INNING" if key == "half" else "NOW BATTING" if key == "batter_heading" \
			else "ON THE MOUND" if key == "pitcher_heading" else "—"
		_detail_labels[key] = _make(fallback, slot)
		if key in ["balls", "strikes", "outs"]:
			_detail_labels[key].modulate = Color("efd48a")
		elif key.ends_with("heading"):
			_detail_labels[key].modulate = Color("9ac4c9")
	var state: MatchState = _match
	_match = null
	bind_match(state)


func _make(value: String, slot: Dictionary) -> Label3D:
	var label: Label3D = _label(value, slot.point, slot.font_size)
	label.pixel_size = slot.pixels
	return label


func bind_match(state: MatchState) -> void:
	if state != null and state == _match:
		return
	_match = state
	_pending.clear()
	shown.clear()
	details.clear()
	for label: Label3D in _labels.values() + _detail_labels.values():
		label.text = "—"
	set_process(state != null and not _labels.is_empty())
	if _labels.is_empty():
		return
	var data: Dictionary = StadiumScoreboardReadout.capture(state)
	if not data.is_empty():
		_apply(data)


func present(value: Dictionary, pitch_active: bool) -> bool:
	return false if _labels.is_empty() else super.present(value, pitch_active)


func _process(_delta: float) -> void:
	var data: Dictionary = StadiumScoreboardReadout.capture(_match)
	if data.is_empty():
		return
	if data.held:
		_pending = data.base.duplicate(true)
		return
	_apply(data)


func _apply(data: Dictionary) -> void:
	if not present(data.base, false):
		return
	if details == data.details:
		return
	details = data.details.duplicate(true)
	for key: String in _detail_labels:
		var label: Label3D = _detail_labels[key]
		var slot: Dictionary = StadiumScoreboardTiers.detail_slots(tier)[key]
		label.text = _fit(str(details.get(key, "")), label, slot.width)


static func _fit(value: String, label: Label3D, width: float) -> String:
	var result: String = value if not value.is_empty() else "—"
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	if font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x \
		* label.pixel_size <= width * 0.94:
		return result
	while result.length() > 1:
		result = result.left(result.length() - 1)
		if font.get_string_size(result + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x \
			* label.pixel_size <= width * 0.94:
			return result + "…"
	return "…"

extends "res://src/tests/stadium_physical_test.gd"
## Two actual full-perimeter games plus exact report9 geometry/surface replay.


func _complete_boundary() -> bool:
	return true


func _tamper(report: Dictionary, source: MatchState) -> void:
	super._tamper(report, source)
	_check(report.version == 9 and report.surfaces.size() == report.plays.size(),
		"every play carries an explicit boundary/owned-surface record")
	var index: int = -1
	for row in range(report.surfaces.size()):
		if not report.surfaces[row].events.is_empty():
			index = row
			break
	_check(index >= 0, "real game actually exercises at least one field surface")
	if index < 0:
		return
	for patch: Dictionary in [{"source": "foreign"}, {"id": "not-owned"},
		{"surface": "unknown"}, {"kind": "catch"}, {"time": -1}, {"time": true},
		{"position": [1000, 0, 0]}, {"position": [0, NAN, 0]}, {"extra": true}]:
		var bad: Dictionary = report.duplicate(true)
		bad.surfaces[index].events[0].merge(patch, true)
		_check(not PhysicalMatchReport.valid(bad), "malformed or foreign surface event rejects")
	var bad: Dictionary = report.duplicate(true)
	bad.erase("surfaces")
	_check(not PhysicalMatchReport.valid(bad), "complete-boundary report requires its event records")
	bad = report.duplicate(true)
	bad.surfaces = []
	_check(not PhysicalMatchReport.valid(bad), "surface records cannot be stripped from the game")
	bad = report.duplicate(true)
	bad.version = 8
	bad.resolver = PhysicalStadiumReport.LEGACY_RESOLVER
	bad.erase("surfaces")
	_check(not PhysicalMatchReport.valid(bad), "old report version cannot impersonate new boundaries")
	bad = report.duplicate(true)
	bad.property.boundary = "different-graph"
	_check(not PhysicalMatchReport.valid(bad), "unrecognized boundary signature rejects")

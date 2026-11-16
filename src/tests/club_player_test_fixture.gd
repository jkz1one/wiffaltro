class_name ClubPlayerTestFixture
extends RefCounted
## Explicit historical schema construction only; never a production migration or unlock bypass.


static func before_ownership(career: Dictionary) -> void:
	career.erase("assets")
	career.erase("pennants")
	career.erase("plaques")
	for row: Dictionary in career.runs:
		row.erase("player_progress")

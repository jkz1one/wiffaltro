extends Node
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _ready() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):
			path = arg.trim_prefix("--evidence=")
	var text: String = FileAccess.get_file_as_string(path)
	var evidence: Dictionary = JSON.parse_string(text)
	var snapshot: Dictionary = evidence.snapshot
	var contacts: Array = evidence.contacts
	var plays: Array = evidence.core.plays
	var graph: StadiumLowWallGraph = StadiumOwnedLayout.graph_for(snapshot.layout)
	check(StadiumLowWallSnapshot.valid(snapshot), "original paid cold snapshot is valid")
	check(
		PhysicalStadiumContacts.valid(contacts, plays, snapshot),
		"unchanged retained genuine eight-play contact evidence validates"
	)
	check(
		not PhysicalMatchReport.valid(evidence.core),
		"partial game is not promoted to complete report"
	)
	var event: Dictionary = contacts[7].events[0]
	var point: Vector3 = Vector3(event.position[0], event.position[1], event.position[2])
	var row: Dictionary = graph.segment(event.surface)
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID).aero_profile.radius_m
	check(
		(
			event.kind == "crossing"
			and event.role == "BACK_WALL_TERMINAL"
			and plays[7].result == "double"
		),
		"genuine sphere sweep kind and original award remain unchanged"
	)
	check(
		PhysicalStadiumContacts._low_wall_event(event, point, graph),
		"exact retained swept sphere center accepted"
	)
	for offset: float in [-0.0002, 0.0002, -sphere.radius, sphere.radius * 2.0]:
		check(
			not PhysicalStadiumContacts._low_wall_event(
				event, point + Vector3(0, 0, offset), graph
			),
			"off-shell forged center refused " + str(offset)
		)
	var bad: Array = contacts.duplicate(true)
	bad[7].events[0]["radius"] = sphere.radius * 2.0
	check(
		not PhysicalStadiumContacts.valid(bad, plays, snapshot),
		"caller-supplied forged radius is not a supported proof field"
	)
	var altered: Dictionary = event.duplicate(true)
	altered.role = "SIDE_RETURN_LIVE"
	check(
		not PhysicalStadiumContacts._low_wall_event(altered, point, graph),
		"foreign live role refused"
	)
	altered.role = "BACK_CLEAR"
	check(
		not PhysicalStadiumContacts._low_wall_event(altered, point, graph),
		"grounded swept center cannot be relabeled HR clearance"
	)
	var clear: Vector3 = Vector3(point.x, row.height + sphere.radius + 0.01, row.a.y)
	check(
		PhysicalStadiumContacts._low_wall_event(altered, clear, graph),
		"real above-cap line crossing is separately recognized"
	)
	altered.kind = "contact"
	check(
		not PhysicalStadiumContacts._low_wall_event(altered, clear, graph),
		"manifold contact cannot claim HR crossing"
	)
	altered = event.duplicate(true)
	var cap: Vector3 = Vector3(point.x, row.height + sphere.radius, row.a.y + 0.1)
	check(
		PhysicalStadiumContacts._low_wall_event(altered, cap, graph),
		"exact sphere tangent above solid cap remains terminal wall contact"
	)
	check(
		not PhysicalStadiumContacts._low_wall_event(altered, cap + Vector3(0, 0.0002, 0), graph),
		"above-shell cap near miss rejected"
	)
	altered.kind = "contact"
	var face: Vector3 = Vector3(point.x, 1.0, row.a.y)
	check(
		PhysicalStadiumContacts._low_wall_event(altered, face, graph),
		"native manifold face position accepted"
	)
	check(
		not PhysicalStadiumContacts._low_wall_event(altered, face + Vector3(0, 0, 0.1), graph),
		"arbitrary interior manifold point rejected"
	)
	check(
		not PhysicalStadiumContacts._low_wall_event(altered, face - Vector3(0, 0, 0.0002), graph),
		"outside face beyond recorder allowance rejected"
	)
	altered.kind = "crossing"
	check(
		PhysicalStadiumContacts._low_wall_event(altered, face, graph),
		"inherited native manifold fallback crossing-face accepted"
	)
	check(
		not PhysicalStadiumContacts._low_wall_event(altered, face + Vector3(0, 0, 0.1), graph),
		"crossing label does not admit arbitrary interior point"
	)
	check(
		FileAccess.get_file_as_string(path) == text,
		"original retained physical evidence bytes remain unchanged"
	)
	print(
		(
			"LOW_COLD_CONTACT_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"unchanged_evidence_sha256": text.sha256_text(),
					"complete_game": false
				}
			)
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)

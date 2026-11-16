extends "res://src/tests/stadium_owned_low_wall_test.gd"


func _install(ledger: ClubAssetLedger) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = StadiumLayoutSnapshot.capture(ledger)
	lab._stadium_ledger = ledger
	check(StadiumPropertyRuntime.install_bound(lab), "real paid guard installation")
	return lab


func _runtime(ledger: ClubAssetLedger, profile: String) -> void:
	var first: PitchBatLab = _install(ledger)
	var second: PitchBatLab = _install(ledger)
	if not first.has_meta("stadium_property") or not second.has_meta("stadium_property"):
		first.free()
		second.free()
		return
	var a: StadiumLowWallBoundaryRuntime = first.get_meta("stadium_property").get_node(
		"BoundaryGraph"
	)
	var b: StadiumLowWallBoundaryRuntime = second.get_meta("stadium_property").get_node(
		"BoundaryGraph"
	)
	check(a.deep_intact() and b.deep_intact(), "both complete transitions intact " + profile)
	var proof: Dictionary = a._low_pool_evidence.get("evidence", {})
	check(
		(
			not proof.is_empty()
			and proof.before > proof.after
			and proof.before_fingerprint == proof.after_fingerprint
		),
		"pool reduces only identical values with exact whole-boundary fingerprint"
	)
	for row: Dictionary in a._low_resources:
		for other: Dictionary in b._low_resources:
			check(
				row.resource != other.resource,
				"no resource identity shared across installed boundaries"
			)
	var selected: StadiumLowWallNodeSeal
	for seal: StadiumLowWallNodeSeal in a._low_hot_nodes:
		if seal.visual != null:
			selected = seal
			break
	check(selected != null, "real native visual row available")
	if selected != null:
		var visual: MeshInstance3D = selected.visual
		var old_layers: int = visual.layers
		visual.layers = old_layers ^ 1
		check(not selected.intact(), "render layer substitution immediately rejected")
		visual.layers = old_layers
		visual.visible = false
		check(not selected.intact(), "hidden geometry immediately rejected")
		visual.visible = selected.n_visible
		visual.position += Vector3(0, 0.001, 0)
		check(not selected.intact(), "small transform change immediately rejected")
		visual.transform = selected.n_transform
		var replacement: Mesh = visual.mesh.duplicate()
		visual.mesh = replacement
		check(not selected.intact(), "equal-value foreign mesh identity rejected")
		visual.mesh = selected.v_mesh
		var internal: MeshInstance3D = MeshInstance3D.new()
		internal.mesh = BoxMesh.new()
		visual.add_child(internal, false, Node.INTERNAL_MODE_BACK)
		check(not selected.intact(), "internal visual descendant immediately rejected")
		internal.free()
		visual.set_meta("foreign", {"claim": true})
		check(not selected.intact(), "extra native metadata immediately rejected")
		visual.remove_meta("foreign")
		check(
			selected.intact() and a.intact(),
			"exact original restoration before any boundary refusal remains intact"
		)
		visual.process_priority += 1
		check(selected.intact(), "non-rendering native scheduling metadata is transition-only")
		check(not a.deep_intact(), "full transition rejects changed native scheduling field")
		check(not a.intact(), "transition refusal terminally retires issued boundary")
	var material: StandardMaterial3D
	for row: Dictionary in b._low_resources:
		if row.resource is StandardMaterial3D:
			material = row.resource
			break
	check(material != null, "pooled native material captured")
	if material != null:
		material.albedo_color = Color.MAGENTA
		check(
			not b.intact(),
			"pooled material value mutation immediately rejects without cached success"
		)
	first.free()
	second.free()
	await get_tree().process_frame

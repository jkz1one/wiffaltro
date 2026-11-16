extends "res://src/tests/stadium_low_wall_guard_test.gd"


func _ready() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5, "homers": 5})
	for material: String in ["ST-077", "ST-078"]:
		var ledger: ClubAssetLedger = ClubAssetLedger.new(194, credits, progress)
		for item: Array in [
			[material, "standard", 23, "stadium_buy", 8],
			[material + "-L", "low", 23, "stadium_wall_piece", 1]
		]:
			var bought: Dictionary = ledger.commit(
				{
					"id": item[1],
					"rev": ledger.revision(),
					"op": item[3],
					"item": item[0],
					"quantity": item[2],
					"price_version": item[4],
					"through": 40,
					"progress_through": 40
				}
			)
			check(bought.ok, "paid fallback purchase " + str(item[0]) + ": " + bought.error)
		var layout: Dictionary = StadiumLowWallLayout.upgrade(
			ledger.view().stadium_draft, ledger.surface_owned()
		)
		var suggestion: Dictionary = StadiumLowWallManifest.suggest(
			"low_outfield", material, ledger.construction(), ledger.wall_pieces().stock
		)
		check(suggestion.ok, "paid nondefault profile suggestion")
		if not suggestion.ok:
			continue
		layout.low_wall = suggestion.manifest
		var draft: Dictionary = ledger.commit(
			{"id": "draft", "rev": ledger.revision(), "op": "stadium_draft", "layout": layout}
		)
		check(draft.ok, "nondefault paid draft " + draft.error)
		var applied: Dictionary = ledger.commit(
			{
				"id": "apply",
				"rev": ledger.revision(),
				"op": "stadium_apply",
				"layout": layout,
				"geometry": StadiumLowWallLayout.geometry("backyard", layout)
			}
		)
		check(applied.ok, "nondefault paid apply " + applied.error)
		if not applied.ok:
			continue
		var lab: PitchBatLab = _install(ledger)
		if not lab.has_meta("stadium_property"):
			lab.free()
			continue
		var boundary: StadiumLowWallBoundaryRuntime = lab.get_meta("stadium_property").get_node(
			"BoundaryGraph"
		)
		check(
			not boundary._low_pool_evidence.get("pooled", true),
			"MultiMesh selects exhaustive fallback " + material
		)
		check(boundary.intact(), "untouched exhaustive fallback intact")
		var start: int = Time.get_ticks_usec()
		for index in range(10):
			check(boundary.intact(), "unchanged nondefault boundary timing probe")
		print(
			(
				"LOW_FALLBACK_COST "
				+ JSON.stringify(
					{
						"material": material,
						"calls": 10,
						"elapsed_us": Time.get_ticks_usec() - start,
						"gameplay_performance_qualified": false
					}
				)
			)
		)
		var nodes: Array[Node] = boundary.find_children("*", "MultiMeshInstance3D", true, false)
		check(not nodes.is_empty(), "actual paid model contains MultiMesh")
		if not nodes.is_empty():
			var visual: MultiMeshInstance3D = nodes[0]
			visual.multimesh = null
			check(not boundary.intact(), "MultiMesh replacement immediately refused " + material)
		lab.free()
		await get_tree().process_frame
	# Admission classification probes cover nondefault empty-family art without
	# pretending these synthetic nodes are paid installed boundary evidence.
	for node: Node3D in [Label3D.new(), MultiMeshInstance3D.new()]:
		var root: Node3D = Node3D.new()
		root.add_child(node)
		var result: Dictionary = StadiumLowWallResourcePool.prepare(root)
		check(
			result.ok and not result.pooled,
			"unsupported native class explicitly retains exhaustive path"
		)
		root.free()
	var root: Node3D = Node3D.new()
	var cylinder: MeshInstance3D = MeshInstance3D.new()
	cylinder.mesh = CylinderMesh.new()
	root.add_child(cylinder)
	var result: Dictionary = StadiumLowWallResourcePool.prepare(root)
	check(result.ok and not result.pooled, "non-Box mesh retains exhaustive path")
	root.free()
	print("LOW_WALL_FALLBACK_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)

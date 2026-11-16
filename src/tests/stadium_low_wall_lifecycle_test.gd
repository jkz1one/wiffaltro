extends "res://src/tests/stadium_low_wall_guard_test.gd"


## Contract3 distinguishes supported authority/lifetime mutations from arbitrary
## cosmetic debugger edits. No cached frame and no fabricated physical reports.
func _runtime(ledger: ClubAssetLedger, profile: String) -> void:
	for scenario: String in [
		"cosmetic",
		"shape",
		"raw_ledger",
		"nested_ledger",
		"supported_commit",
		"construction",
		"snapshot",
		"hierarchy",
		"delete"
	]:
		var paid: ClubAssetLedger = ledger
		if scenario == "supported_commit":
			paid = ClubAssetLedger.from_data(ledger.to_data(), 194, credits, progress)
		var lab: PitchBatLab = _install(paid)
		if not lab.has_meta("stadium_property"):
			lab.free()
			continue
		var property: StadiumLowWallProperty = lab.get_meta("stadium_property")
		var boundary: StadiumLowWallBoundaryRuntime = property.get_node("BoundaryGraph")
		check(boundary.deep_intact(), "new issued admission deep-validates " + scenario)
		match scenario:
			"cosmetic":
				var rows: Array[Node] = boundary.find_children("*", "MeshInstance3D", true, false)
				check(not rows.is_empty(), "native cosmetic visual exists")
				if not rows.is_empty():
					var mesh: MeshInstance3D = rows[0]
					mesh.visible = false
					check(
						boundary.intact(),
						"arbitrary cosmetic debugger edit is not claimed as per-action anti-cheat"
					)
					check(
						not boundary.deep_intact(), "deep report/transition rejects changed visual"
					)
					mesh.visible = true
					check(not boundary.intact(), "failed deep transition permanently revokes lease")
			"shape":
				var rows: Array[Node] = boundary.find_children("*", "CollisionShape3D", true, false)
				check(not rows.is_empty(), "issued native collision shape exists")
				if not rows.is_empty():
					var shape: CollisionShape3D = rows[0]
					shape.disabled = true
					check(
						boundary.intact(),
						"unsupported direct native collision field edit is not a per-action anti-tamper promise"
					)
					check(
						not boundary.deep_intact(),
						"deep issued proof refuses changed native collision field"
					)
			"raw_ledger":
				var generation: int = paid.mutation_generation()
				var old_spent: int = paid._spent
				paid._spent += 1
				check(
					paid.mutation_generation() == generation and not property.low_context_intact(),
					"same-generation raw paid backing change detected"
				)
				check(not boundary.intact(), "raw ownership refusal revokes issued boundary")
				paid._spent = old_spent
				check(
					not boundary.intact(),
					"restoring ledger bytes cannot resurrect stale issued authority"
				)
			"nested_ledger":
				var old_events: Array[Dictionary] = paid._events.duplicate(true)
				check(
					not paid._events.is_empty(),
					"issued ledger has actual nested transaction values"
				)
				if not paid._events.is_empty():
					paid._events[0]["id"] = "foreign-nested-transaction"
					check(
						property.low_context_intact() and boundary.intact(),
						"unsupported old-history debugger edit is outside the immediate API contract"
					)
					check(
						not boundary.deep_intact(),
						"deep receipt proof rejects true nested paid transaction value difference"
					)
					paid._events = old_events
					check(
						not boundary.intact(), "restored nested values cannot resurrect authority"
					)
			"supported_commit":
				var generation: int = paid.mutation_generation()
				var result: Dictionary = paid.commit(
					{
						"id": "issued-change-" + profile,
						"rev": paid.revision(),
						"op": "stadium_buy",
						"item": "ST-024",
						"quantity": 1,
						"price_version": 8,
						"through": 40,
						"progress_through": 40
					}
				)
				check(
					result.ok and paid.mutation_generation() != generation,
					"supported paid writer advances generation"
				)
				check(
					not property.low_context_intact() and not boundary.intact(),
					"supported paid mutation cannot continue issued geometry"
				)
			"construction":
				check(
					(
						not StadiumPropertyGeometry.construction_target_allowed(property)
						and not StadiumPropertyGeometry.construction_target_allowed(boundary)
					),
					"construction-target-gated authoring refuses issued low geometry"
				)
				check(
					StadiumPropertyRuntime._action_property_intact(lab, property),
					"exact low action dispatch preserves an unchanged issued owner"
				)
			"snapshot":
				lab._match_state.stadium = {}
				check(
					not property.low_context_intact() and not boundary.intact(),
					"current active snapshot replacement refused synchronously"
				)
			"delete":
				var rows: Array[Node] = boundary.find_children("*", "CollisionShape3D", true, false)
				check(not rows.is_empty(), "issued physical node exists for lifetime probe")
				if not rows.is_empty():
					rows[0].queue_free()
					check(
						not boundary.intact(),
						"required native node queued deletion revokes before deferred free"
					)
					check(
						not StadiumPropertyRuntime._action_property_intact(lab, property),
						"property action route refuses retired boundary authority"
					)
			"hierarchy":
				var child: Node3D = Node3D.new()
				boundary.add_child(child)
				check(
					not boundary._live,
					"hierarchy change synchronously revokes via lifecycle signal"
				)
				check(not boundary.intact(), "new child cannot inherit issued authority")
		lab.free()
		await get_tree().process_frame

extends Node3D
## Complete AC-01 content candidate; eligibility remains gated on whole-field runtime qualification.

var _failures: int = 0


func _ready() -> void:
	var property: StadiumPropertyGeometry = StadiumClubVenueStudy.build(self)
	_check(property != null, "complete AC-01 assembly builds without human purchase history")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue")
	_check(record.status == "CANDIDATE" and record.items.size() == 68
		and record.live_units == 0 and record.environment_certificates.is_empty(),
		"original sixty-eight-copy record grants no night or published eligibility")
	var ids: Array[String] = []
	var sites: Array[String] = []
	for row: Dictionary in record.items:
		_check(not ids.has(row.instance) and not sites.has(row.site),
			"every candidate copy and exact slot is distinct")
		ids.append(row.instance)
		sites.append(row.site)
		_check(row.transform.size() == 12 and row.instance.begins_with("npc-candidate:"),
			"actual transforms and NPC provenance are stored, not only a generation seed")
	_check(record.land_value == 2200 and record.endowment_value
		== record.land_value + record.copy_value + record.blueprint_value,
		"content valuation includes ordered land and exact pieces without creating spendable money")
	_check(ClubCareer.same(record, JSON.parse_string(StadiumClubVenueStudy.encode(record))),
		"candidate content record retains values through JSON encoding")
	_check(property.get_node_or_null("TemplateBackWall") == null,
		"no obsolete infinite back wall remains behind the candidate")
	var boundary: StadiumClubBoundaryStudy = property.get_node("ClubBoundary")
	_check(boundary.items.size() == 61, "original shared infrastructure is exactly sixty-one copies")
	for left in [false, true]:
		var from: Vector3 = StadiumDugoutRecipe.rail_point(13, -0.5, left) + Vector3.UP * 0.5
		var to: Vector3 = StadiumDugoutRecipe.rail_point(13, 0.5, left) + Vector3.UP * 0.5
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(StadiumClubBoundarySweep.event(boundary, from, to).get("role") == "DUGOUT_OPENING_DEAD",
			"whole assembly preserves the open dugout instead of a hidden old side wall")
	_check(await StadiumAssetCapture.save(self,
		AABB(Vector3(-33, 0, -8), Vector3(66, 10, 40)), "AC-01-complete-candidate",
		Vector3(-1, 1.25, -1)), "native whole-field candidate preview saved")
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro club venue study passed: exact AC-01 copies and complete candidate assembly.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

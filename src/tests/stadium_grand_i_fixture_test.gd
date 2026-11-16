extends Node3D
## Canonical source-bound Grand I records, negative guards, and atomic authoring IO.


class FailedTemplate:
	extends StadiumPropertyGeometry

	func build(property_tier: String, layout: Dictionary, stock: StadiumStock) -> bool:
		super.build(property_tier, layout, stock)
		return false


class TransformedTemplate:
	extends StadiumPropertyGeometry

	func build(property_tier: String, layout: Dictionary, stock: StadiumStock) -> bool:
		if not super.build(property_tier, layout, stock):
			return false
		position.x = 0.25
		return true


var _failures: int = 0


func _ready() -> void:
	var property: StadiumPropertyGeometry = StadiumGrandIVenueStudy.build(self)
	_check(property != null, "complete Grand I builds for fixture capture")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue").duplicate(true)
	property.queue_free()
	await get_tree().process_frame
	var fixture: Dictionary = StadiumGrandIFixtureStudy.capture(record)
	_check(StadiumGrandIFixtureStudy.valid(fixture), "canonical complete fixture accepted")
	_check(
		ClubCareer.same(
			fixture, StadiumGrandIFixtureStudy.decode(StadiumGrandIFixtureStudy.encode(fixture))
		),
		"full precision canonical JSON roundtrip"
	)
	record.items[0].site = "caller-mutation"
	_check(
		(
			StadiumGrandIFixtureStudy.valid(fixture)
			and fixture.venue.items[0].site != record.items[0].site
		),
		"capture owns a deep copy"
	)
	_check(
		(
			StadiumGrandIFixtureStudy.decode("{").is_empty()
			and StadiumGrandIFixtureStudy.decode(" ".repeat(1048577)).is_empty()
		),
		"malformed and oversized input fail closed"
	)
	_check(
		not StadiumLayoutSnapshot.valid(fixture) and not StadiumClubFixtureStudy.valid(fixture),
		"authoring has no production or AC identity"
	)
	var path: String = "user://grand-i-fixture-%d.json" % OS.get_process_id()
	_check(
		(
			StadiumGrandIFixtureStudy.save(path, fixture)
			and StadiumGrandIFixtureStudy.save(path, fixture)
		),
		"canonical saves and replaces atomically"
	)
	var bytes: String = FileAccess.get_file_as_string(path)
	_check(
		ClubCareer.same(StadiumGrandIFixtureStudy.load_file(path), fixture),
		"saved complete fixture reloads exactly"
	)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_grand_i_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var old: Node = lab.get_node("StarterFieldGeometry/BackWall")
	await _stage_failures(lab)
	for edit in range(20):
		var bad: Dictionary = fixture.duplicate(true)
		match edit:
			0:
				bad.kind = "PRODUCTION"
			1:
				bad.version = 999
			2:
				bad.venue.id = "AC-01"
			3:
				bad.venue.property = "club"
			4:
				bad.venue.items.pop_back()
			5:
				bad.venue.items[1].instance = bad.venue.items[0].instance
			6:
				bad.venue.items[1].site = bad.venue.items[0].site
			7:
				bad.venue.items[0].transform[9] += 0.125
			8:
				bad.venue.items[0].transform[0] = NAN
			9:
				bad.venue.items[0].item = "ST-082"
			10:
				bad.venue.environment.night_eligible = true
			11:
				bad.venue.environment.certificates = ["free-night"]
			12:
				bad.venue.model_sources.stadium_curved_lower_models = "f".repeat(64)
			13:
				bad.venue.items[0].host = "untrusted-owner"
			14:
				bad.venue.lighting.dormant = false
			15:
				bad.venue.field.safe_hit_z_m += 0.5
			16:
				bad.venue.field.deep_air_z_m += 0.5
			17:
				bad.venue.field.fair_half_angle_degrees += 1.0
			18:
				bad.venue.field.middle_anchor_z_m += 0.5
			19:
				bad.venue.model_sources["src/content/fields/starter_field.tres"] = "f".repeat(64)
		_check(not StadiumGrandIFixtureStudy.valid(bad), "tamper rejects " + str(edit))
		_check(
			(
				not StadiumGrandIFixtureStudy.save(path, bad)
				and FileAccess.get_file_as_string(path) == bytes
			),
			"failed write preserves original"
		)
		_check(
			(
				not StadiumGrandILab.install_frozen(lab, bad)
				and old == lab.get_node_or_null("StarterFieldGeometry/BackWall")
				and not lab.has_meta("stadium_property")
			),
			"failed install preserves old geometry"
		)
		if edit >= 2:
			_check(
				StadiumGrandIFixtureStudy.capture(bad.venue).is_empty(),
				"recomputed checksum cannot bless noncanonical record " + str(edit)
			)
	var source_field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var original_safe: float = source_field.safe_hit_z_m
	source_field.safe_hit_z_m += 0.5
	_check(
		not StadiumGrandIFixtureStudy.valid(fixture),
		"actual in-memory field mutation invalidates an earlier fixture even with unchanged files"
	)
	source_field.safe_hit_z_m = original_safe
	_check(
		StadiumGrandIFixtureStudy.valid(fixture),
		"restoring the exact field restores original source-bound fixture validity"
	)

	_check(
		not StadiumGrandILab.install_frozen(lab, {}), "empty frozen means failure, never defaults"
	)
	remove_child(lab)
	var orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check(
		(
			not StadiumGrandILab.install(lab)
			and Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == orphans
		),
		"detached host fails without allocating orphan assembly"
	)
	add_child(lab)
	_check(StadiumGrandILab.install_frozen(lab, fixture), "exact frozen candidate installs")
	_check(
		ClubCareer.same(
			fixture.venue, lab.get_meta("stadium_property").get_meta("candidate_venue")
		),
		"installed identity stays exact"
	)
	_check(PhysicalMatchReport.capture(lab).is_empty(), "no reward report authority")
	DirAccess.remove_absolute(path)
	lab.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Grand I fixture passed: canonical source identity, atomic IO, fail-closed install."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _stage_failures(lab: PitchBatLab) -> void:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var previous: Array[Node] = host.get_children()
	var router: Callable = lab._pitch_actor.receiver_router
	for candidate: StadiumPropertyGeometry in [FailedTemplate.new(), TransformedTemplate.new()]:
		_check(
			StadiumGrandIVenueStudy.build(host, candidate) == null,
			"partially constructed template failure aborts the whole assembly"
		)
		_check(
			(
				host.get_children() == previous
				and not lab.has_meta("stadium_property")
				and lab._pitch_actor.receiver_router == router
			),
			"mid-stage failure retains every original node and receiver adapter"
		)
		await get_tree().process_frame
		_check(not is_instance_valid(candidate), "failed staging releases its temporary property")
	var staged: StadiumGrandIProperty = StadiumGrandIProperty.new()
	_check(
		StadiumGrandIVenueStudy.build(host, staged) == staged,
		"receiver rejection probe builds the real complete staged assembly"
	)
	var net: Node3D = staged.objects["npc-candidate:GRAND-I:v1:RECEIVER-CATCH"]
	var observer: Callable = lab._ball_play_resolver.segment_observer
	net.position.x += 0.01
	_check(
		not staged.configure_candidate(lab),
		"actual displaced ST073 rejects receiver configuration despite unchanged metadata"
	)
	for original: Node in previous:
		_check(
			is_instance_valid(original) and original.get_parent() == host,
			"receiver configuration failure retains each original geometry object"
		)
	_check(
		(
			lab._pitch_actor.receiver_router == router
			and lab._ball_play_resolver.segment_observer == observer
			and not lab.has_meta("stadium_property")
		),
		"failed staged pair never changes original receiver or physical observer callbacks"
	)
	host.remove_child(staged)
	staged.queue_free()
	await get_tree().process_frame
	_check(
		not is_instance_valid(staged) and host.get_children() == previous,
		"failed staged receiver assembly fully releases without removing prior geometry"
	)

	var transformed: Node3D = Node3D.new()
	transformed.position.x = 1
	add_child(transformed)
	var child: Node3D = Node3D.new()
	transformed.add_child(child)
	_check(
		StadiumGrandIVenueStudy.build(child) == null and child.get_child_count() == 0,
		"nonidentity ancestor fails before allocating any candidate"
	)
	transformed.queue_free()

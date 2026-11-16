class_name StadiumMountedClockRuntime
extends Node
## Paid analog clock. Reuses the existing completed-play/half presentation clock.
## No wall-clock reads, per-frame work, scoring authority, audio or Night admission.

const NODE: String = "MountedClockRuntime"
const HANDS: Array[String] = ["hour", "minute"]
const PATHS: Array[String] = ["HourHandPivot", "MinuteHandPivot"]
var retired: bool = false
var _lab: WeakRef
var _property: StadiumPropertyGeometry
var _state: MatchState
var _paid: ClubAssetLedger
var _generation: int = -1
var _paid_state: String = ""
var _titles: Dictionary = {}
var _snapshot: Dictionary = {}
var _pitch: PitchFlightActor
var _rows: Array[Dictionary] = []
var _clock: Dictionary = {}
var _records: Array[PlayRecord] = []
var _record_data: Array[Dictionary] = []
var _writing: bool = false


static func time_values(profile: Variant, plays: Variant, halves: Variant) -> Dictionary:
	if (
		not profile is String
		or StadiumSurfaceNightSnapshot.start_minute(profile) < 0
		or not SeasonOwnership._whole(plays, 0, 100000)
		or not SeasonOwnership._whole(halves, 0, 10000)
	):
		return {}
	var result: Dictionary = StadiumSurfaceNightSnapshot.clock(profile, int(plays), int(halves))
	if result.is_empty():
		return {}
	var seconds: int = (int(result.start_minute) * 60 + int(result.elapsed_seconds)) % 86400
	result["mode"] = profile
	result["seconds_of_day"] = seconds
	result["hour_radians"] = -TAU * float(seconds % 43200) / 43200.0
	result["minute_radians"] = -TAU * float(seconds % 3600) / 3600.0
	return result


static func required(lab: PitchBatLab) -> bool:
	if StadiumLowWallClockAdapter.required(lab):
		return true
	if not is_instance_valid(lab) or lab._match_state == null or lab._stadium_ledger == null:
		return false
	var layout: Dictionary = lab._match_state.stadium.get("layout", {})
	if StadiumWaterfallAnimationLayout.is_family(layout):
		layout = StadiumWaterfallAnimationLayout.presentation_base(layout)
	if not (
		StadiumMountedDisplayItems.is_family(layout)
		or (
			StadiumStringLightItems.is_family(layout)
			or (
				StadiumSalvageCarItems.is_family(layout)
				or (
					StadiumMasteryBannerItems.is_family(layout)
					or (
						StadiumWaterfallItems.is_family(layout)
						or (
							StadiumLightingKitItems.is_family(layout)
							or (
								StadiumOutfieldPlazaItems.is_family(layout)
								or StadiumWaterfallLiveItems.is_family(layout)
							)
						)
					)
				)
			)
		)
	):
		return false
	for row: Dictionary in layout.get("mounted_displays", []):
		if lab._stadium_ledger._stock.copies.get(row.copy, {}).get("item", "") == "ST-069":
			return true
	return false


static func current(lab: PitchBatLab) -> StadiumMountedClockRuntime:
	if not is_instance_valid(lab) or not lab.has_meta("stadium_property"):
		return null
	var property: Variant = lab.get_meta("stadium_property")
	if not is_instance_valid(property) or not property is StadiumPropertyGeometry:
		return null
	return property.get_node_or_null(NODE) as StadiumMountedClockRuntime


static func install(lab: PitchBatLab, property: StadiumPropertyGeometry) -> bool:
	if not required(lab):
		return true
	if (
		current(lab) != null
		or property.has_node(NODE)
		or not property.props_intact()
		or not StadiumLayoutSnapshot.matches(lab._match_state.stadium, lab._stadium_ledger)
		or lab._match_state.stadium.get("environment", {}).get("mode", "day") != "day"
	):
		return false
	var owner: StadiumMountedClockRuntime = StadiumMountedClockRuntime.new()
	owner.name = NODE
	owner._lab = weakref(lab)
	owner._property = property
	owner._state = lab._match_state
	owner._paid = lab._stadium_ledger
	owner._generation = owner._paid.mutation_generation()
	owner._paid_state = StadiumSurfaceNightRuntime._ledger_state(owner._paid)
	owner._titles = owner._paid._championships.duplicate(true)
	owner._snapshot = owner._state.stadium.duplicate(true)
	owner._pitch = lab._pitch_actor
	owner._clock = time_values("day", 0, 0)
	for saved: Dictionary in owner._snapshot.layout.mounted_displays:
		if owner._paid._stock.copies.get(saved.copy, {}).get("item", "") != "ST-069":
			continue
		var model: Node3D = property.objects.get(saved.copy)
		if not is_instance_valid(model) or model.get_meta("stadium_item", "") != "ST-069":
			owner.free()
			return false
		for index: int in HANDS.size():
			var hand: Node3D = model.get_node_or_null(PATHS[index]) as Node3D
			var captured: Dictionary = {}
			var found_seal: Dictionary = {}
			for seal: Dictionary in property._infrastructure:
				if seal.root == model:
					for node_row: Dictionary in seal.rows:
						if node_row.node == hand:
							captured = node_row
							found_seal = seal
			var field_index: int = captured.get("fields", []).find(&"transform")
			if (
				hand == null
				or captured.is_empty()
				or field_index < 0
				or hand.transform != StadiumMountedDisplayModels.hand_pose(HANDS[index], 47400)
			):
				owner.free()
				return false
			owner._rows.append(
				{
					"copy": saved.copy,
					"model": model,
					"hand": hand,
					"kind": HANDS[index],
					"path": PATHS[index],
					"seal": found_seal,
					"captured": captured,
					"field_index": field_index
				}
			)
	if owner._rows.is_empty():
		owner.free()
		return false
	property.add_child(owner)
	if not owner._advance():
		owner.retire()
		return false
	return true


static func before_pitch(lab: PitchBatLab) -> bool:
	var owner: StadiumMountedClockRuntime = current(lab)
	return not required(lab) if owner == null else owner._advance()


func clock_value() -> Dictionary:
	return _clock.duplicate(true)


func intact() -> bool:
	if (
		retired
		or get_script() != StadiumMountedClockRuntime
		or _lab == null
		or not is_inside_tree()
		or not is_instance_valid(_property)
		or not _property.is_inside_tree()
		or not _property_script_valid()
		or get_parent() != _property
		or _property.get_node_or_null(NODE) != self
	):
		return false
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	if (
		not is_instance_valid(lab)
		or lab.get_script() != PitchBatLab
		or not lab.is_inside_tree()
		or not lab.has_meta("stadium_property")
		or lab.get_meta("stadium_property") != _property
		or lab._match_state != _state
		or _state.get_script() != MatchState
		or not ClubCareer.same(_state.stadium, _snapshot)
		or lab._stadium_ledger != _paid
		or _paid == null
		or _paid.get_script() != ClubAssetLedger
		or _paid.mutation_generation() != _generation
		or StadiumSurfaceNightRuntime._ledger_state(_paid) != _paid_state
		or _paid_state.is_empty()
		or not ClubCareer.same(_paid._championships, _titles)
		or lab._pitch_actor != _pitch
		or not is_instance_valid(_pitch)
		or _pitch.get_script() != PitchFlightActor
	):
		return false
	for row: Dictionary in _rows:
		if (
			not is_instance_valid(row.model)
			or _property.objects.get(row.copy) != row.model
			or row.model.get_parent() != _property
			or row.model.get_meta("stadium_item", "") != "ST-069"
			or not is_instance_valid(row.hand)
			or row.model.get_node_or_null(row.path) != row.hand
			or not _property._infrastructure.has(row.seal)
			or not row.seal.rows.has(row.captured)
			or (
				row.captured.values[row.field_index]
				!= StadiumMountedDisplayModels.hand_pose(row.kind, int(_clock.seconds_of_day))
			)
		):
			return false
	return (
		(_property as StadiumWaterfallAnimationProperty).deep_props_intact()
		if _property.get_script() == StadiumWaterfallAnimationProperty
		else _property.props_intact()
	)


func _input_clock(lab: PitchBatLab) -> Dictionary:
	# Same authoritative completed-play count and half index as the Sun/lights runtime.
	# Completed records are typed, finished and monotonic; once observed, their exact
	# identities/data cannot be silently rewritten. No caller supplies clock counts.
	if (
		_state.inning < 1
		or _state.inning > 5000
		or lab._play_records.size() > 100000
		or lab._play_records.size() < _records.size()
	):
		return {}
	var halves: int = (_state.inning - 1) * 2 + (0 if _state.top_half else 1)
	var previous_number: int = -1
	for index: int in lab._play_records.size():
		var record: PlayRecord = lab._play_records[index]
		if (
			record == null
			or record.get_script() != PlayRecord
			or record.result in [&"", &"pending"]
			or record.play_number <= previous_number
			or record.play_number > lab._throw_number
			or record.inning < 1
			or record.inning > _state.inning
			or (record.inning - 1) * 2 + (0 if record.top_half else 1) > halves
		):
			return {}
		if (
			index < _records.size()
			and (
				record != _records[index]
				or not ClubCareer.same(record.to_dict(), _record_data[index])
			)
		):
			return {}
		previous_number = record.play_number
	var next: Dictionary = time_values("day", lab._play_records.size(), halves)
	if (
		next.is_empty()
		or next.completed_plays < _clock.completed_plays
		or next.completed_halves < _clock.completed_halves
	):
		return {}
	return next


func _advance() -> bool:
	if _writing or not intact():
		retire()
		return false
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	# No advancing during pause, delivery, flight or any other non-PRE_PITCH phase.
	if (
		get_tree().paused
		or _state.phase != MatchState.Phase.PRE_PITCH
		or _pitch.running
		or is_instance_valid(lab._batted_ball)
	):
		return true
	var next: Dictionary = _input_clock(lab)
	if next.is_empty():
		retire()
		return false
	return _advance_remaining_checks(lab, next)


func _advance_remaining_checks(lab: PitchBatLab, next: Dictionary) -> bool:
	if not ClubCareer.same(next, _clock):
		var input_seal: String = _transaction_inputs(lab)
		_writing = true
		# Seal and write one hand at a time, preserving the other hand's current exact
		# expected pose. Synchronous property callbacks must pass the same lease.
		for row: Dictionary in _rows:
			if not _raw_context(lab, input_seal):
				_writing = false
				retire()
				return false
			var pose: Transform3D = StadiumMountedDisplayModels.hand_pose(
				row.kind, int(next.seconds_of_day)
			)
			row.captured.values[row.field_index] = pose
			row.hand.transform = pose
			if not _raw_context(lab, input_seal) or row.hand.transform != pose:
				_writing = false
				retire()
				return false
		_clock = next
		_writing = false
	_records.assign(lab._play_records)
	_record_data.clear()
	for record: PlayRecord in _records:
		_record_data.append(record.to_dict())
	if not intact():
		retire()
		return false
	return true


func _transaction_inputs(lab: PitchBatLab) -> String:
	var records: Array = []
	for record: PlayRecord in lab._play_records:
		if record == null or record.get_script() != PlayRecord:
			return ""
		records.append(
			[record.get_instance_id(), record.get_script().get_instance_id(), record.to_dict()]
		)
	return JSON.stringify(
		[
			_state.phase,
			_state.inning,
			_state.top_half,
			_pitch.running,
			get_tree().paused,
			is_instance_valid(lab._batted_ball),
			lab._throw_number,
			records
		],
		"",
		true,
		true
	)


func _raw_context(lab: PitchBatLab, input_seal: String) -> bool:
	return (
		not input_seal.is_empty()
		and not retired
		and get_script() == StadiumMountedClockRuntime
		and is_inside_tree()
		and is_instance_valid(lab)
		and lab.is_inside_tree()
		and lab.get_script() == PitchBatLab
		and lab._match_state == _state
		and _state.get_script() == MatchState
		and lab._pitch_actor == _pitch
		and is_instance_valid(_pitch)
		and _pitch.get_script() == PitchFlightActor
		and is_instance_valid(_property)
		and _property_script_valid()
		and _property.is_inside_tree()
		and get_parent() == _property
		and _transaction_inputs(lab) == input_seal
		and lab._stadium_ledger == _paid
		and _paid != null
		and _paid.get_script() == ClubAssetLedger
		and _paid.mutation_generation() == _generation
		and StadiumSurfaceNightRuntime._ledger_state(_paid) == _paid_state
		and ClubCareer.same(_paid._championships, _titles)
		and ClubCareer.same(_state.stadium, _snapshot)
		and lab.has_meta("stadium_property")
		and lab.get_meta("stadium_property") == _property
		and _property.get_node_or_null(NODE) == self
		and (
			(_property as StadiumWaterfallAnimationProperty).deep_props_intact()
			if _property.get_script() == StadiumWaterfallAnimationProperty
			else _property.props_intact()
		)
	)


func retire() -> void:
	retired = true


func _exit_tree() -> void:
	retired = true
	_lab = null


func _property_script_valid() -> bool:
	return (
		is_instance_valid(_property)
		and (
			_property.get_script() == StadiumPropertyGeometry
			or StadiumLowWallClockAdapter.property_valid(_property, _snapshot)
			or (
				_property.get_script() == StadiumWaterfallAnimationProperty
				and StadiumWaterfallAnimationSnapshot.is_family(_snapshot)
				and (_property as StadiumWaterfallAnimationProperty).motion_context_intact()
				and (
					(_property as StadiumWaterfallAnimationProperty).animation_layout
					== _snapshot.layout
				)
			)
		)
	)

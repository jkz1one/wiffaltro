extends RefCounted
enum Outcome { FALLBACK, DENIED, HANDLED }

## One synchronous, explicitly opted-in manual AC02 QC command. Not gameplay authority.
## No context, audit success or continuation permission survives this call stack.
# gdlint: disable=max-returns
const COMMAND_CONTRACT_VERSION: int = 1
const PROFILE = preload(
	"res://src/presentation/stadium/stadium_npc_ac02_issued_runtime_profile_v1.gd"
)
const SOURCE_PROFILE_ID: String = "ac02-hr-followthrough10-final-20261023"
const RUNTIME_PROFILE_ID: String = "ac02-hr-followthrough10-final-bounded-20261023"
const MAX_RECORDS: int = 4096
const MAX_DEPTH: int = 24
const MAX_ENTRIES: int = 262144
const MAX_STRING_BYTES: int = 16777216


static func run(lab: PitchBatLab, output: bool, terminal: bool = true) -> Outcome:
	# Leave the historical no-pending terminal no-op, including its ordering, alone.
	if not output and _native(lab, "Node3D", PitchBatLab):
		var current: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
		if (
			_native(current, "RefCounted", StadiumNpcAc02IssuedStateV1)
			and not current._manual_qc_flushing
			and current._manual_qc_dirty_revision <= current._manual_qc_saved_revision
		):
			return Outcome.FALLBACK
	var admission: Dictionary = _capture(lab)
	if admission.outcome != Outcome.HANDLED:
		return admission.outcome
	var context: Dictionary = admission.context
	var issue: StadiumNpcAc02IssuedStateV1 = context.issue
	# A repeated terminal attempt suppresses I/O, not the fresh original-session check.
	if not output and terminal and issue._manual_qc_terminal_attempted:
		return (
			Outcome.HANDLED
			if (
				_intact(context, context.metadata)
				and context.count == issue._manual_qc_terminal_count
				and context.revision == issue._manual_qc_terminal_revision
			)
			else Outcome.DENIED
		)
	issue._manual_qc_flushing = true
	if not output and terminal:
		issue._manual_qc_terminal_attempted = true
		issue._manual_qc_terminal_count = context.count
		issue._manual_qc_terminal_revision = context.revision
	var plan: Dictionary = context.exporter.prepare_manual_ac02_v1(
		context.records, context.field, context.lab_snapshot
	)
	if not _intact(context, context.metadata):
		return _deny(context)
	# The ONLY full installation audit. Preparation grants nothing; failure publishes nothing.
	if (
		not StadiumNpcPublicRuntime.installed_bound(context.lab, context.receipt)
		or not _intact(context, context.metadata)
	):
		return _deny(context)
	# Audit-to-publication interval: native I/O and original-context reads only.
	# No serializer, normalization, git process, await or extensible exporter is called.
	if output:
		if not _intact(context, context.metadata):
			return _deny(context)
		print(plan.field_line)
		if not _intact(context, context.metadata):
			return _deny(context)
		print(plan.records_line)
	var persisted: Dictionary = _persist(context, plan)
	if persisted.get("context_lost", false):
		return _deny(context)
	# Logger callbacks can revoke or reenter. Warn with the guard still held, then
	# recheck the original context in _finish before acknowledging/allowing continuation.
	if persisted.error != OK and _intact(context, persisted.metadata):
		push_warning("QC export failed: %s" % error_string(persisted.error))
	var result: Outcome = _finish(context, persisted.metadata, persisted.error == OK)
	# Status is last, after acknowledgment; it can never authorize a save or continuation.
	if (
		output
		and result == Outcome.HANDLED
		and is_instance_valid(context.status)
		and context.lab._status_label == context.status
		and _native(context.status, "Label", null)
	):
		context.status.text = (
			plan.success_status
			if persisted.error == OK
			else "QC save failed. Records remain in Output."
		)
	return result


static func _capture(lab: PitchBatLab) -> Dictionary:
	var fallback: Dictionary = {"outcome": Outcome.FALLBACK}
	var denied: Dictionary = {"outcome": Outcome.DENIED}
	# A custom lab is never inspected through its fields. Historical entry returns here.
	if (
		not _native(lab, "Node3D", PitchBatLab)
		or not lab._ac02_issued_history
		or not _profile_selected()
	):
		return fallback
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	if not _native(issue, "RefCounted", StadiumNpcAc02IssuedStateV1):
		return denied
	if (
		issue.state != StadiumNpcAc02IssuedStateV1.Lifetime.ACTIVE
		or issue.generation != 1
		or issue._manual_qc_flushing
		or lab.has_meta("stadium_npc_runtime_interrupted")
		or not is_same(issue._bindings, issue._bindings_pin)
		or not issue._bindings.is_read_only()
		or not issue._bindings.has_all(["lab", "property", "match", "field", "automation"])
		or issue._bindings.lab != lab
		or issue._bindings.match != lab._match_state
		or issue._bindings.field != lab._field_definition
		or issue._bindings.automation != lab._automation
	):
		return denied
	var property: Variant = lab.get_meta("stadium_property", null)
	if property != issue._bindings.property:
		return denied
	if not _native(property, "Node3D", StadiumNpcPublicProperty):
		return fallback
	if (
		property._ac02_issue != issue
		or property._ac02_issue_pin != issue
		or property._ac02_generation != 1
		or not property._ac02_issued_once
		or not property.issued
		or property.suspended
		or property._cleaning
	):
		return denied
	if lab._automation != null or issue._manual_qc_opted_out:
		return fallback
	if (
		not _native(lab._match_state, "RefCounted", MatchState)
		or not _native(lab._field_definition, "Resource", FieldDefinition)
		or not _native(lab._record_export, "RefCounted", PlayRecordExport)
		or (lab._status_label != null and not _native(lab._status_label, "Label", null))
		or not StadiumNpcAc02IssuedStateV1._exact_participants(lab, property)
		or _other_boundary(lab)
	):
		return fallback
	if (
		not is_same(issue._sources, issue._sources_pin)
		or not issue._sources.is_read_only()
		or not issue._sources.has_all(["receipt", "lab_snapshot", "public_snapshot"])
		or not is_same(lab._match_state.stadium, issue._sources.receipt)
		or not is_same(lab.get_meta("stadium_snapshot", null), issue._sources.lab_snapshot)
		or not is_same(property.public_snapshot, issue._sources.public_snapshot)
	):
		return denied
	for snapshot: Variant in [
		issue._sources.receipt, issue._sources.lab_snapshot, issue._sources.public_snapshot
	]:
		if not _snapshot19(snapshot):
			return fallback
	var exporter: PlayRecordExport = lab._record_export
	var records: Array[PlayRecord] = lab._play_records
	if typeof(exporter._source_dirty) not in [TYPE_NIL, TYPE_BOOL] or records.size() > MAX_RECORDS:
		return fallback
	# Reject unknown participants and nested opaque data BEFORE any serializer or effect.
	var budget: Array[int] = [MAX_ENTRIES, MAX_STRING_BYTES]
	if not _primitive([exporter.path, exporter._revision], budget, []):
		return fallback
	for record: PlayRecord in records:
		if not _native(record, "RefCounted", PlayRecord) or not _record_plain(record, budget):
			return fallback
	if issue._manual_qc_started:
		if (
			issue._manual_qc_exporter != exporter
			or not is_same(issue._manual_qc_records, records)
			or issue._manual_qc_count != records.size()
		):
			return denied
	elif (
		not records.is_empty()
		or issue._manual_qc_count != 0
		or issue._manual_qc_dirty_revision != 0
		or issue._manual_qc_saved_revision != 0
	):
		return fallback
	# All observable scripted participants have been classified. This fresh hot proof
	# preserves the existing owner/session contract; it is not the full export audit.
	if not issue.manual_qc_owner(lab):
		return denied
	var ordered: Array[PlayRecord] = records.duplicate()
	ordered.make_read_only()
	var metadata: Array = [exporter.path, exporter._revision, exporter._source_dirty]
	metadata.make_read_only()
	var context: Dictionary = {
		"lab": lab,
		"issue": issue,
		"property": property,
		"generation": issue.generation,
		"property_generation": property._ac02_generation,
		"bindings": issue._bindings,
		"sources": issue._sources,
		"issue_record": issue._record,
		"match": lab._match_state,
		"field": lab._field_definition,
		"receipt": lab._match_state.stadium,
		"lab_snapshot": issue._sources.lab_snapshot,
		"public_snapshot": property.public_snapshot,
		"exporter": exporter,
		"metadata": metadata,
		"records": records,
		"ordered": ordered,
		"count": records.size(),
		"revision": issue._manual_qc_dirty_revision,
		"saved_revision": issue._manual_qc_saved_revision,
		"started": issue._manual_qc_started,
		"batch_exporter": issue._manual_qc_exporter,
		"batch_records": issue._manual_qc_records,
		"batch_count": issue._manual_qc_count,
		"status": lab._status_label
	}
	context.make_read_only()
	return {"outcome": Outcome.HANDLED, "context": context}


static func _intact(context: Dictionary, expected_metadata: Array) -> bool:
	# Original identities only. expected_metadata is an I/O-stage value, never an audit
	# result: the immutable original triple, or the plan's known native assignment.
	var lab: PitchBatLab = context.lab
	var issue: StadiumNpcAc02IssuedStateV1 = context.issue
	var property: StadiumNpcPublicProperty = context.property
	if (
		not _native(lab, "Node3D", PitchBatLab)
		or not _native(issue, "RefCounted", StadiumNpcAc02IssuedStateV1)
		or not _native(property, "Node3D", StadiumNpcPublicProperty)
		or not _native(context.match, "RefCounted", MatchState)
		or not _native(context.field, "Resource", FieldDefinition)
		or not _native(context.exporter, "RefCounted", PlayRecordExport)
		or not _native(context.bindings.season, "RefCounted", SeasonState)
		or (context.status != null and not _native(context.status, "Label", null))
	):
		return false
	if (
		lab._ac02_issued_owner != issue
		or not lab._ac02_issued_history
		or lab.has_meta("stadium_npc_runtime_interrupted")
		or _other_boundary(lab)
		or lab.get_meta("stadium_property", null) != property
		or property._ac02_issue != issue
		or property._ac02_issue_pin != issue
		or issue.state != StadiumNpcAc02IssuedStateV1.Lifetime.ACTIVE
		or issue.generation != context.generation
		or property._ac02_generation != context.property_generation
		or not property._ac02_issued_once
		or not property.issued
		or property.suspended
		or property._cleaning
		or lab._automation != null
		or lab._match_state != context.match
		or lab._field_definition != context.field
		or property.field != context.field
		or property.bound_state != context.match
		or lab._record_export != context.exporter
		or lab._status_label != context.status
		or lab._npc_season != context.bindings.season
		or property.public_season != context.bindings.season
		or property.public_automation != null
		or context.bindings.season.career != context.bindings.career
		or not is_same(lab._play_records, context.records)
		or context.records.size() != context.count
	):
		return false
	if (
		not is_same(issue._bindings, context.bindings)
		or not is_same(issue._bindings_pin, context.bindings)
		or not is_same(issue._sources, context.sources)
		or not is_same(issue._sources_pin, context.sources)
		or not is_same(issue._record, context.issue_record)
		or not is_same(issue._record_pin, context.issue_record)
		or not is_same(context.match.stadium, context.receipt)
		or not is_same(lab.get_meta("stadium_snapshot", null), context.lab_snapshot)
		or not is_same(property.public_snapshot, context.public_snapshot)
		or issue._manual_qc_opted_out
		or issue._manual_qc_started != context.started
		or issue._manual_qc_exporter != context.batch_exporter
		or not is_same(issue._manual_qc_records, context.batch_records)
		or issue._manual_qc_count != context.batch_count
		or issue._manual_qc_dirty_revision != context.revision
		or issue._manual_qc_saved_revision != context.saved_revision
		or context.exporter.path != expected_metadata[0]
		or context.exporter._revision != expected_metadata[1]
		or not is_same(context.exporter._source_dirty, expected_metadata[2])
	):
		return false
	for index: int in range(context.count):
		if (
			context.records[index] != context.ordered[index]
			or not _native(context.ordered[index], "RefCounted", PlayRecord)
		):
			return false
	return true


static func _persist(context: Dictionary, plan: Dictionary) -> Dictionary:
	var metadata: Array = context.metadata
	if not _intact(context, metadata):
		return {"error": ERR_UNAUTHORIZED, "metadata": metadata, "context_lost": true}
	if plan.mkdir:
		var directory_error: Error = DirAccess.make_dir_recursive_absolute("user://qc")
		if directory_error != OK:
			return {"error": directory_error, "metadata": metadata}
		if not _intact(context, metadata):
			return {"error": ERR_UNAUTHORIZED, "metadata": metadata, "context_lost": true}
		# Match save's post-mkdir / pre-open path-and-revision publication. These exact
		# script fields have no setters. The original capture is never refreshed.
		context.exporter.path = plan.metadata[0]
		context.exporter._revision = plan.metadata[1]
		context.exporter._source_dirty = plan.metadata[2]
		metadata = plan.metadata
	if not _intact(context, metadata):
		return {"error": ERR_UNAUTHORIZED, "metadata": metadata, "context_lost": true}
	var file: FileAccess = FileAccess.open(metadata[0] + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"error": FileAccess.get_open_error(), "metadata": metadata}
	if not _intact(context, metadata):
		file.close()
		return {"error": ERR_UNAUTHORIZED, "metadata": metadata, "context_lost": true}
	file.store_string(plan.file_text)
	if not _intact(context, metadata):
		file.close()
		return {"error": ERR_UNAUTHORIZED, "metadata": metadata, "context_lost": true}
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if not _intact(context, metadata):
		return {"error": ERR_UNAUTHORIZED, "metadata": metadata, "context_lost": true}
	if write_error != OK:
		return {"error": write_error, "metadata": metadata}
	# Recheck immediately before rename; _finish checks again after persistence.
	if not _intact(context, metadata):
		return {"error": ERR_UNAUTHORIZED, "metadata": metadata, "context_lost": true}
	return {
		"error": DirAccess.rename_absolute(metadata[0] + ".tmp", metadata[0]), "metadata": metadata
	}


static func _deny(context: Dictionary) -> Outcome:
	if _native(context.issue, "RefCounted", StadiumNpcAc02IssuedStateV1):
		context.issue._manual_qc_flushing = false
	return Outcome.DENIED


static func _finish(context: Dictionary, metadata: Array, saved: bool) -> Outcome:
	var intact: bool = _intact(context, metadata)
	# Only the original exact issuer is released. A replacement never inherits this command.
	if _native(context.issue, "RefCounted", StadiumNpcAc02IssuedStateV1):
		context.issue._manual_qc_flushing = false
	if not intact:
		return Outcome.DENIED
	if saved:
		context.issue._manual_qc_saved_revision = context.revision
	# Ordinary diagnostic I/O failure is continuation-safe, not persistence success.
	return Outcome.HANDLED


static func _profile_selected() -> bool:
	# Loaded immutable profile identity, not a fabricated per-issuer profile field.
	# Genuine issuance and the unchanged installed_bound audit still establish authority.
	return (
		PROFILE.REVIEW_STATUS == "reviewed"
		and PROFILE.PROFILE_ID == RUNTIME_PROFILE_ID
		and PROFILE.SOURCE_PROFILE_ID == SOURCE_PROFILE_ID
		and StadiumNpcSourceQualification.PROFILE.REVIEW_STATUS == "reviewed"
		and StadiumNpcSourceQualification.PROFILE.PROFILE_ID == SOURCE_PROFILE_ID
	)


static func _other_boundary(lab: PitchBatLab) -> bool:
	return (
		lab.has_meta(StadiumSurfaceNightRuntime.OWNER)
		or lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
		or lab.has_meta(StadiumSurfaceTerrainRuntime.OWNER)
		or lab.has_meta(StadiumSurfaceTerrainRuntime.BOUND)
	)


static func _snapshot19(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.size() == 6
		and value.has_all(
			["version", "authority", "manifest", "manifest_key", "binding", "environment"]
		)
		and typeof(value.get("version")) == TYPE_INT
		and value.version == 19
		and value.get("authority") == StadiumNpcSnapshot.AUTHORITY
		and not value.has("layout")
		and not value.has("boundary")
		and value.get("manifest") is Dictionary
		and value.manifest.get("id") == "AC-02"
		and typeof(value.manifest.get("revision")) == TYPE_INT
		and value.manifest.revision == 1
	)


static func _native(value: Variant, native_class: String, script: Variant) -> bool:
	return StadiumNpcAc02IssuedStateV1._native(value, native_class, script)


static func _record_plain(record: PlayRecord, budget: Array[int]) -> bool:
	if (
		not _primitive(record.pitch_disclosure, budget, [])
		or not _primitive(record.frozen_launch, budget, [])
		or not _primitive(record.stadium_contacts, budget, [])
	):
		return false
	# Native typed fields cannot call user code, but nonfinite numbers are not JSON primitives.
	for number: float in [
		record.effort,
		record.fatigue,
		record.execution_quality,
		record.release_offset_seconds,
		record.release_overdrive,
		record.plate_speed_mps,
		record.ai_awareness,
		record.ai_swing_chance,
		record.ai_aim_sigma,
		record.contact_quality,
		record.timing_error_m,
		record.horizontal_error_m,
		record.vertical_error_m,
		record.exit_speed_mps,
		record.launch_angle_degrees,
		record.spray_degrees
	]:
		if not is_finite(number):
			return false
	return (
		record.intended_target.is_finite()
		and record.crossing_point.is_finite()
		and record.ai_plate_read.is_finite()
		and record.swing_aim.is_finite()
		and record.first_ground_position.is_finite()
		and record.resolution_position.is_finite()
		and _primitive(
			[
				record.mode,
				String(record.batter_id),
				String(record.pitcher_id),
				String(record.pitch_id),
				String(record.swing_profile_id),
				String(record.resolution_reason),
				String(record.last_defender_touch),
				String(record.result)
			],
			budget,
			[]
		)
	)


static func _primitive(
	value: Variant, budget: Array[int], ancestors: Array, depth: int = 0
) -> bool:
	budget[0] -= 1
	if depth > MAX_DEPTH or budget[0] < 0:
		return false
	if value is Dictionary or value is Array:
		if value.size() > budget[0]:
			return false
		for ancestor: Variant in ancestors:
			if is_same(value, ancestor):
				return false
		ancestors.append(value)
		if value is Dictionary:
			for key: Variant in value:
				if (
					typeof(key) != TYPE_STRING
					or not _primitive(key, budget, ancestors, depth + 1)
					or not _primitive(value[key], budget, ancestors, depth + 1)
				):
					return false
		else:
			for item: Variant in value:
				if not _primitive(item, budget, ancestors, depth + 1):
					return false
		ancestors.pop_back()
		return true
	if typeof(value) == TYPE_STRING:
		if value.length() > budget[1]:
			return false
		budget[1] -= value.to_utf8_buffer().size()
		return budget[1] >= 0
	return (
		typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT]
		or (typeof(value) == TYPE_FLOAT and is_finite(value))
	)

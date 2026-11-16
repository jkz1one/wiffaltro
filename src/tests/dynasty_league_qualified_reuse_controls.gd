extends RefCounted
## Test-only exact prior path and same-input differential controls. No admission token.
const Owner = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Legacy = preload("res://src/gameplay/season/dynasty_owner.gd")

static func legacy_qualified(owner: Dictionary, slot: String, snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary: return {}
	var checked: Dictionary = Authority._qualify_session(owner.career, owner[slot].session_id, snapshot)
	if checked.is_empty(): return {}
	var session: Dictionary = checked.session
	if session.owner_id != owner.owner_id or session.lineage_id != owner.lineage.id \
		or session.session_id != owner[slot].session_id \
		or not Profile.same(checked.reference, owner[slot].reference) \
		or not Profile.same(checked.raw_reference, owner.raw_references[slot]): return {}
	var expected: Dictionary = Owner._slot(checked)
	expected.snapshot_version = int(snapshot.version)
	if not Profile.same(expected, owner[slot]): return {}
	if slot == "dynasty" and (not Profile.same(checked.season._dynasty_start, owner.lineage.start_profile) \
		or not Legacy._current_matches(owner.lineage, checked.season)): return {}
	var rebound: Dictionary = Authority._checkpoint_standard_checked(owner.career, session.session_id, snapshot, checked) \
		if checked.has("grant") and snapshot.version == Authority.STANDARD_LIVE_SAVE_VERSION \
		else Authority.checkpoint_session(owner.career, session.session_id, snapshot)
	return checked if not rebound.is_empty() and Profile.same(rebound, owner.career) else {}

static func selected(value: Dictionary, snapshot: Variant, old: bool) -> Dictionary:
	var owner: Dictionary = Owner.normalize(value)
	if owner.is_empty(): return {}
	return legacy_qualified(owner, owner.selected, snapshot) if old else Owner._qualified(owner, owner.selected, snapshot)

static func reuse(authority: Dictionary, id: String, snapshot: Dictionary, checked: Dictionary) -> Dictionary:
	if snapshot.version == 91:
		return Authority._checkpoint_league_home_checked(authority, id, snapshot, checked)
	return Authority._checkpoint_dynasty_home_checked(authority, id, snapshot, checked)

static func positive(owner: Dictionary, snapshot: Dictionary, check: Callable, label: String) -> Dictionary:
	var before: String = JSON.stringify([owner, snapshot], "", true, true)
	Engine.set_meta("league_reuse_calls", 0)
	var prior: Dictionary = selected(owner, snapshot, true)
	var old_count: int = Engine.get_meta("league_reuse_calls", 0)
	Engine.set_meta("league_reuse_calls", 0)
	var actual: Dictionary = selected(owner, snapshot, false)
	var new_count: int = Engine.get_meta("league_reuse_calls", 0)
	check.call(not prior.is_empty() and not actual.is_empty(), label + " both selected-owner paths accept")
	if prior.is_empty() or actual.is_empty(): return {}
	check.call(old_count == 2 and new_count == 1, label + " instrumented full replay callbacks 2 -> 1")
	print("LEAGUE_REUSE_COUNT ", label, " old=", old_count, " new=", new_count)
	for field: String in actual:
		if field != "season":
			check.call(Profile.same(prior.get(field), actual[field]), label + " exact checked " + field)
	check.call(Profile.same(SeasonSave.snapshot(prior.season), SeasonSave.snapshot(actual.season)), label + " identical reconstructed output")
	var public_result: Dictionary = Authority.checkpoint_session(owner.career, actual.session.session_id, snapshot)
	check.call(not public_result.is_empty() and Profile.same(public_result,
		reuse(owner.career, actual.session.session_id, snapshot, actual)), label + " identical normalized checkpoint and progress")
	check.call(before == JSON.stringify([owner, snapshot], "", true, true), label + " caller owner and snapshot bytes unchanged")
	return actual

static func run(owner: Dictionary, snapshot: Dictionary, check: Callable, label: String) -> void:
	var checked: Dictionary = positive(owner, snapshot, check, label)
	if checked.is_empty(): return
	var id: String = checked.session.session_id
	var before: String = JSON.stringify([owner, snapshot], "", true, true)
	var mutations: Array[String] = ["raw", "session", "grant", "home", "outer", "bound", "bound_session"]
	if snapshot.version == 92:
		mutations.append_array(["owner_revision", "owner_reference", "source_reference", "lineage_header"])
	for field: String in mutations:
		var bad: Dictionary = snapshot.duplicate(true)
		match field:
			"raw": _core(bad).seed += 1
			"session": bad.session.session_id += "-forged"
			"grant": bad.grant.owner_id += "-forged"
			"home": bad.home_property.revision += 1
			"outer": bad["extra"] = true
			"owner_revision": bad.owner_revision += 1
			"owner_reference": bad.owner_reference.sha256 = "0".repeat(64)
			"source_reference": bad.source_reference.sha256 = "0".repeat(64)
			"lineage_header": bad.lineage.id += "-forged"
			"bound":
				if snapshot.version == 91: bad.checkpoint.checkpoint.version = 83 if int(checked.session.tier) > 0 else 85
				else: bad.checkpoint.version = 83 if int(checked.session.tier) > 0 else 85
			"bound_session":
				if snapshot.version == 91: bad.checkpoint.checkpoint.session.session_id += "-forged"
				else: bad.checkpoint.session.session_id += "-forged"
		check.call(selected(owner, bad, true).is_empty() and selected(owner, bad, false).is_empty(), label + " owner differential rejects " + field)
		check.call(Authority.checkpoint_session(owner.career, id, bad).is_empty()
			and reuse(owner.career, id, bad, checked).is_empty(), label + " stale checked rejects " + field)
		# Even updated full/raw hashes cannot excuse a substituted frozen envelope.
		var rebound: Dictionary = checked.duplicate(true)
		rebound.reference = Save.snapshot_reference(bad)
		check.call(reuse(owner.career, id, bad, rebound).is_empty(), label + " exact envelope rejects rehashed " + field)
	for field: String in ["reference", "raw_reference", "revision", "owner_id", "lineage", "session"]:
		var bad: Dictionary = owner.duplicate(true)
		match field:
			"reference": bad[owner.selected].reference.sha256 = "0".repeat(64)
			"raw_reference": bad.raw_references[owner.selected].sha256 = "0".repeat(64)
			"revision": bad.revision += 1
			"owner_id": bad.owner_id += "-forged"
			"lineage": bad.lineage.id += "-forged"
			"session": bad[owner.selected].session_id += "-forged"
		check.call(selected(bad, snapshot, true).is_empty() and selected(bad, snapshot, false).is_empty(), label + " owner differential rejects " + field)
	for field: String in ["inner", "reference", "raw_reference", "session", "home"]:
		var bad: Dictionary = checked.duplicate(true)
		match field:
			"inner": _core(bad.inner).seed += 1
			"reference": bad.reference.sha256 = "0".repeat(64)
			"raw_reference": bad.raw_reference.sha256 = "0".repeat(64)
			"session": bad.session.session_id += "-forged"
			"home":
				if snapshot.version == 91: bad.home_property.revision += 1
				else: bad.dynasty_home.owner_revision += 1
		check.call(reuse(owner.career, id, snapshot, bad).is_empty(), label + " local checked mutation rejects " + field)
	var entry_bad: Dictionary = owner.career.duplicate(true)
	if snapshot.version == 91: entry_bad.sessions[id].league_home_grant.owner_id += "-forged"
	else: entry_bad.sessions[id].dynasty_home.owner_revision += 1
	check.call(Authority.checkpoint_session(entry_bad, id, snapshot).is_empty()
		and reuse(entry_bad, id, snapshot, checked).is_empty(), label + " changed authoritative entry rejected")
	check.call(before == JSON.stringify([owner, snapshot], "", true, true), label + " negative controls leave caller bytes unchanged")

static func _core(value: Dictionary) -> Dictionary:
	var result: Dictionary = value
	while result.get("version") != 57 and result.get("checkpoint") is Dictionary:
		result = result.checkpoint
	return result

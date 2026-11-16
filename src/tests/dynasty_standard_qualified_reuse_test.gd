extends "res://src/tests/dynasty_standard_owner_test.gd"
## Synthetic no-game differential controls, not native replay performance proof.
const V2 = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
func _step(op: String, operands: Dictionary) -> Dictionary:
	if op == "close":
		_reuse_controls()
	return super._step(op, operands)
func _reuse_controls() -> void:
	var found: Dictionary = Store.inspect(path)
	var owner: Dictionary = found.owner
	var id: String = owner.other.session_id
	var snapshot: Dictionary = Store.read_snapshot(path, owner.other.reference)
	var before: Dictionary = {"owner": owner.duplicate(true), "snapshot": snapshot.duplicate(true)}
	var checked: Dictionary = Authority._qualify_session(owner.career, id, snapshot)
	check(not checked.is_empty(), "full qualifier provides direct local result")
	if checked.is_empty(): return
	var public_result: Dictionary = Authority.checkpoint_session(owner.career, id, snapshot)
	var reused: Dictionary = Authority._checkpoint_standard_checked(owner.career, id, snapshot, checked)
	check(not public_result.is_empty() and ClubCareer.same(public_result, reused), "same snapshot public full checkpoint equals local reuse")
	check(Owner.validate_selected(owner, snapshot) != null, "selected owner accepts identical qualified snapshot")
	check(_legacy_selected(owner, snapshot), "legacy duplicate qualification accepts same positive")
	for mutation: String in ["raw", "grant", "session"]:
		var bad: Dictionary = snapshot.duplicate(true)
		if mutation == "raw": bad.checkpoint.seed += 1
		elif mutation == "grant": bad.grant.owner_id += "-forged"
		else: bad.session.session_id += "-forged"
		check(Authority.checkpoint_session(owner.career, id, bad).is_empty(), "public checkpoint independently rejects " + mutation)
		check(Authority._checkpoint_standard_checked(owner.career, id, bad, checked).is_empty(), "reuse exact binding rejects changed " + mutation)
		check(Owner.validate_selected(owner, bad) == null and not _legacy_selected(owner, bad), "public owner differential rejects " + mutation)
	var raw_bad: Dictionary = checked.duplicate(true)
	raw_bad.inner.seed += 1
	check(Authority._checkpoint_standard_checked(owner.career, id, snapshot, raw_bad).is_empty(), "mutated local raw result rejected")
	var grant_bad: Dictionary = checked.duplicate(true)
	grant_bad.grant.owner_id += "-forged"
	check(Authority._checkpoint_standard_checked(owner.career, id, snapshot, grant_bad).is_empty(), "local grant cannot replace committed witness")
	var proof_bad: Dictionary = checked.duplicate(true)
	proof_bad.contribution.proof.draws = []
	check(Authority._checkpoint_standard_checked(owner.career, id, snapshot, proof_bad).is_empty(), "unchanged contribution guards reject forged proof")
	var fresh: SeasonState = Live.create(checked.grant, checked.session)
	var stale: Dictionary = {"version": snapshot.version, "session": checked.session.duplicate(true),
		"grant": checked.grant.duplicate(true), "checkpoint": Live.capture_raw(fresh)}
	check(not Authority._qualify_session(owner.career, id, stale).is_empty(), "earlier draft snapshot is independently valid")
	check(Owner.validate_selected(owner, stale) == null and not _legacy_selected(owner, stale), "current selected reference rejects stale valid snapshot")
	for field: String in ["reference", "raw_reference", "revision"]:
		var bad_owner: Dictionary = owner.duplicate(true)
		if field == "reference": bad_owner.other.reference.sha256 = "0".repeat(64)
		elif field == "raw_reference": bad_owner.raw_references.other.sha256 = "0".repeat(64)
		else: bad_owner.revision += 1
		check(Owner.validate_selected(bad_owner, snapshot) == null and not _legacy_selected(bad_owner, snapshot), "owner differential rejects changed " + field)
	check(ClubCareer.same(before.owner, owner) and ClubCareer.same(before.snapshot, snapshot), "reuse does not mutate caller owner or snapshot")
	print("STANDARD_QUALIFIED_REUSE controls complete")
func _legacy_selected(value: Dictionary, snapshot: Dictionary) -> bool:
	# Exact prior Standard path, kept test-only as a differential oracle.
	var owner: Dictionary = V2.normalize(value)
	if owner.is_empty(): return false
	var slot: Dictionary = owner[owner.selected]
	var checked: Dictionary = Authority._qualify_session(owner.career, slot.session_id, snapshot)
	if checked.is_empty(): return false
	var session: Dictionary = checked.session
	if session.owner_id != owner.owner_id or session.lineage_id != owner.lineage.id \
		or session.session_id != slot.session_id or not Profile.same(checked.reference, slot.reference) \
		or not Profile.same(checked.raw_reference, owner.raw_references[owner.selected]): return false
	var expected: Dictionary = V2._slot(checked)
	expected.snapshot_version = int(snapshot.version)
	if not Profile.same(expected, slot): return false
	var rebound: Dictionary = Authority.checkpoint_session(owner.career, session.session_id, snapshot)
	return not rebound.is_empty() and Profile.same(rebound, owner.career)

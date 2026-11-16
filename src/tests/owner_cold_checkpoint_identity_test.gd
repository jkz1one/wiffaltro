extends Node
const OwnerV2 = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
 checks += 1
 if not value: failures += 1
 print("IDENTITY_CHECK ", checks, " ", value, " ", label)
func _ready() -> void:
 var data: Dictionary = {"version": 89, "checkpoint": {"venue": Vector3(13.909624099731445, 2.3, -0.7).x, "result": 8}}
 var cold: Dictionary = JSON.parse_string(JSON.stringify(data, "", true, true))
 var ref: Dictionary = SeasonSave.DynastyCareerSave.snapshot_reference(data)
 check(ref == SeasonSave.DynastyCareerSave.snapshot_reference(cold), "exact transport reference cold stable")
 check(SeasonSave._owner_checkpoint_id(data, {"version": 2}, {}) == SeasonSave._owner_checkpoint_id(cold, {"version": 2}, {}), "new warm and cold IDs identical")
 var slot: Dictionary = {"session_id": "test:1", "reference": ref}
 var owner: Dictionary = {"version": 2, "last_action": {"id": "save:old-raw", "kind": "checkpoint"}, "operands": {"op": "checkpoint", "request_id": "save:old-raw", "session_id": "test:1", "snapshot": ref}}
 check(SeasonSave._owner_checkpoint_id(data, owner, slot) == "save:old-raw", "warm exact existing operand retains request")
 check(SeasonSave._owner_checkpoint_id(cold, owner, slot) == "save:old-raw", "cold exact existing operand retains request")
 var request: Dictionary = {"op": "checkpoint", "request_id": "save:old-raw", "expected_revision": 8, "session_id": "test:1", "snapshot": data}
 var cold_request: Dictionary = request.duplicate(true)
 cold_request.snapshot = cold
 check(OwnerV2.Legacy.fingerprint(OwnerV2._compact(request)) == OwnerV2.Legacy.fingerprint(OwnerV2._compact(cold_request)), "same canonical data retains complete request fingerprint")
 for field: String in ["expected_revision", "session_id", "request_id"]:
  var forged: Dictionary = cold_request.duplicate(true)
  forged[field] = 7 if field == "expected_revision" else "forged"
  check(OwnerV2.Legacy.fingerprint(OwnerV2._compact(request)) != OwnerV2.Legacy.fingerprint(OwnerV2._compact(forged)), "complete fingerprint rejects altered " + field)
 var altered: Dictionary = cold.duplicate(true)
 altered.checkpoint.result = 9
 check(SeasonSave._owner_checkpoint_id(altered, owner, slot) != "save:old-raw", "changed result cannot reuse receipt")
 for field: String in ["op", "request_id", "session_id", "snapshot"]:
  var changed: Dictionary = owner.duplicate(true)
  changed.operands[field] = {} if field == "snapshot" else "different"
  check(SeasonSave._owner_checkpoint_id(cold, changed, slot) == "save:" + ref.sha256, "mismatch " + field + " cannot reuse receipt")
 var wrong_slot: Dictionary = slot.duplicate(true)
 wrong_slot.reference = {}
 check(SeasonSave._owner_checkpoint_id(cold, owner, wrong_slot) == "save:" + ref.sha256, "slot reference mismatch cannot reuse receipt")
 owner.last_action.kind = "resume"
 check(SeasonSave._owner_checkpoint_id(cold, owner, slot) == "save:" + ref.sha256, "non-checkpoint cannot reuse receipt")
 owner.version = 1
 check(SeasonSave._owner_checkpoint_id(data, owner, slot) == "save:" + JSON.stringify(data, "", true, true).sha256_text(), "v1 raw identity unchanged")
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--identity-fixture="):
   var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--identity-fixture=")))
   check(not source.is_empty(), "retained snapshot readable")
   var next: Dictionary = JSON.parse_string(JSON.stringify(source, "", true, true))
   var actual_ref: Dictionary = SeasonSave.DynastyCareerSave.snapshot_reference(source)
   check(actual_ref == SeasonSave.DynastyCareerSave.snapshot_reference(next), "retained full snapshot exact canonical reference stable")
   var existing: Dictionary = {"version": 2, "last_action": {"id": "save:retained-raw", "kind": "checkpoint"}, "operands": {"op": "checkpoint", "request_id": "save:retained-raw", "session_id": "retained:1", "snapshot": actual_ref}}
   var selected: Dictionary = {"session_id": "retained:1", "reference": actual_ref}
   check(SeasonSave._owner_checkpoint_id(source, existing, selected) == SeasonSave._owner_checkpoint_id(next, existing, selected), "retained complete cold snapshot request identical")
   next.checkpoint["unexpected_evidence"] = true
   check(SeasonSave._owner_checkpoint_id(next, existing, selected) != "save:retained-raw", "changed complete checkpoint cannot reuse retained receipt")
 print("IDENTITY_RESULT checks=", checks, " failures=", failures)
 get_tree().quit(1 if failures else 0)

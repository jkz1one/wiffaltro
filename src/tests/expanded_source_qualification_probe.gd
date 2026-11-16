extends Node
## Read-only qualification and historical exclusion checks; no gameplay or issuance.
const Contract = preload("res://src/gameplay/simulation/stadium_pool_party_ai22_retained_contract.gd")
const Issued = preload("res://src/presentation/stadium/stadium_npc_ac02_issued_qualification_v1.gd")
const ANCHORS = [
    "res://src/gameplay/simulation/stadium_pool_party_ai22_retained_contract.gd",
    "res://src/presentation/stadium/stadium_npc_ac02_issued_qualification_v1.gd",
    "res://src/presentation/stadium/stadium_npc_ac02_issued_runtime_profile_v1.gd"]

func _ready() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1 or not args[0].is_absolute_path() or FileAccess.file_exists(args[0]) or OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") != "1":
        push_error("Qualification probe requires bounded launcher and fresh absolute output")
        get_tree().quit(2)
        return
    var before: Dictionary = {}
    for path: String in ANCHORS:
        before[path] = FileAccess.get_sha256(path)
    var facts: Dictionary = {
        "original": StadiumNpcSourceQualification.matches_original(StadiumNpcPublicRuntime.SOURCE_PINS),
        "current": StadiumNpcSourceQualification.matches_current(StadiumNpcPublicRuntime.SOURCE_PINS),
        "accepted": StadiumNpcPublicRuntime.source_qualified(),
        "profile_id": StadiumNpcSourceQualification.PROFILE.PROFILE_ID,
        "issued_source_profile_id": Issued.PROFILE.SOURCE_PROFILE_ID,
        "issued_eligible": Issued.eligible(),
        "retained_inventory": Contract.inventory_sha256(),
        "retained_contract": Contract.CONTRACT,
        "retained_inventory_matches": Contract.inventory_matches(),
        "anchors_before": before,
        "retained_ai": {}, "retained_human": {}}
    var checks: Dictionary = {
        "original_rejected": not facts.original,
        "current_accepted": facts.current,
        "public_source_accepted": facts.accepted,
        "exact_new_profile": facts.profile_id == "v6-integration-20261112-r1",
        "historical_issued_profile_distinct": facts.profile_id != facts.issued_source_profile_id,
        "issued_not_eligible": not facts.issued_eligible,
        "retained_digest_present": facts.retained_inventory.length() == 64,
        "retained_digest_changed": facts.retained_inventory != facts.retained_contract,
        "retained_inventory_rejected": not facts.retained_inventory_matches}
    for row: Array in [["PRODUCER", Contract.PRODUCER], ["QUALIFIED_SUCCESSOR", Contract.QUALIFIED_SUCCESSOR], ["QUALIFIED_CURRENT", Contract.QUALIFIED_CURRENT]]:
        facts.retained_ai[row[0]] = Contract.accepts(row[1])
        checks["ai_rejected_" + row[0]] = not facts.retained_ai[row[0]]
    for row: Array in [
        ["PRODUCER", Contract.PRODUCER],
        ["HUMAN6_SUCCESSOR", Contract.HUMAN6_SUCCESSOR],
        ["HUMAN6_CURRENT", Contract.HUMAN6_CURRENT],
        ["HUMAN6_NORMALIZATION_BASELINE", Contract.HUMAN6_NORMALIZATION_BASELINE],
        ["HUMAN6_PRIVATE_HASH_BASELINE", Contract.HUMAN6_PRIVATE_HASH_BASELINE],
        ["HUMAN6_RELEASE_DISPATCH_BASELINE", Contract.HUMAN6_RELEASE_DISPATCH_BASELINE],
        ["HUMAN6_LOADING_FEEDBACK_BASELINE", Contract.HUMAN6_LOADING_FEEDBACK_BASELINE],
        ["HUMAN6_PID_GUARD_BASELINE", Contract.HUMAN6_PID_GUARD_BASELINE],
        ["HUMAN6_DRAFT_RECOVERY_BASELINE", Contract.HUMAN6_DRAFT_RECOVERY_BASELINE],
        ["HUMAN6_INTEGRATED_DRAFT_BASELINE", Contract.HUMAN6_INTEGRATED_DRAFT_BASELINE]]:
        facts.retained_human[row[0]] = Contract.accepts_human6(row[1])
        checks["human_rejected_" + row[0]] = not facts.retained_human[row[0]]
    var after: Dictionary = {}
    for path: String in ANCHORS:
        after[path] = FileAccess.get_sha256(path)
    facts["anchors_after"] = after
    checks["historical_anchor_bytes_unchanged"] = before == after
    var failures: int = 0
    for key: String in checks:
        if not checks[key]:
            failures += 1
            push_error("Source qualification predicate failed: " + key)
    facts["checks"] = checks
    facts["failures"] = failures
    var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
    if file == null:
        push_error("Qualification output could not be opened")
        get_tree().quit(2)
        return
    file.store_string(JSON.stringify(facts, "", true, true))
    file.flush()
    if file.get_error() != OK:
        push_error("Qualification output write failed")
        get_tree().quit(2)
        return
    file.close()
    print("EXPANDED_SOURCE_QUALIFICATION checks=%d failures=%d" % [checks.size(), failures])
    get_tree().quit(0 if failures == 0 else 1)

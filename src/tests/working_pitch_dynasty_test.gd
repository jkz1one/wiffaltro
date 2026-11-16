extends Node
## Isolated in-memory domain projection. No physical wins or durable owner writes.
## A locked origin may exercise deterministic projection, but Store admission must refuse it.
const Owner = preload("res://src/gameplay/season/dynasty_career_owner.gd")
const Current = preload("res://src/gameplay/season/working_pitch_dynasty_owner.gd")
const Authority = preload("res://src/gameplay/season/working_pitch_dynasty_authority.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
var failures: int = 0


func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)


static func cold(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _ready() -> void:
	_run()
	print("Current Dynasty domain failures: %d; physical games and durable writes: 0" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _run() -> void:
	var source: SeasonState = SeasonState.create(719, false, true, true)
	source.physical = SeasonPhysicalFixtures.new()
	source.opponents._format = 13
	var career: ClubCareer = ClubCareer.new()
	check(WorkingPitchCareerProgress.admit(source, career), "fresh current origin")
	check(ClubPlayerDraft.apply(source, ClubPlayers.owned(career)), "ordinary draft access")
	check(career.start(source), "origin starts without manufactured history")
	source.career = career
	for _pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin draft")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "fixture-lineage", "fixture-owner")
	check(not profile.is_empty(), "source replay captures current access profile")
	if profile.is_empty(): return
	var season: SeasonState = Bridge.create(profile)
	var authority: Dictionary = Authority.create(origin, profile.owner_id)
	var invalid_leagues: Array[String] = Authority.available_leagues({})
	var locked_leagues: Array[String] = Authority.available_leagues(authority)
	check(invalid_leagues.is_empty() and locked_leagues.is_empty(),
		"invalid and locked authorities return typed empty league lists without granting access")
	check(Authority.install_start(authority, season), "fresh exact earned-history prefix")
	if season == null: return
	var raw: Dictionary = SeasonSave.snapshot(season)
	check(raw.get("version") == WorkingPitchDynastySave.VERSION, "explicit raw100")
	check(SeasonSave._decode(cold(raw)) != null, "raw100 actual JSON cold replay")
	if raw.is_empty(): return
	check(SeasonSave._decode(raw.checkpoint) == null, "old raw80 cannot admit stripped current book")
	var snapshot: Dictionary = WorkingPitchDynastySave.wrap_checkpoint(raw,
		WorkingPitchDynastySave.binding_for(season, profile.owner_id, profile.lineage_id, 0, 1, "fixture-lineage:1"))
	check(WorkingPitchDynastySave.qualify(cold(snapshot)).has("season"), "bound101 JSON replay")
	_public_route_negatives(raw, snapshot)
	var nested: Dictionary = cold(snapshot)
	# Compare mutations against the same JSON representation. The hot binding
	# normalizes integer fields; JSON parsing retains those numeric values as floats.
	var prior: Dictionary = nested.duplicate(true)
	var leaf: Dictionary = SeasonRoundSettlement._physical_payload(nested)
	check(not leaf.is_empty(), "bound101 settlement leaf validates")
	if leaf.is_empty(): return
	check(ClubCareer.same(prior, nested), "settlement traversal does not change authority")
	leaf.physical.pending = {"identity_probe": true}
	check(nested.checkpoint.checkpoint.checkpoint.checkpoint.physical.pending.get("identity_probe", false),
		"bound101 leaf aliases the original envelope, not a qualification copy")
	leaf.physical.pending = {}
	check(nested.checkpoint.checkpoint.checkpoint.checkpoint.physical.pending.is_empty(),
		"clearing pending mutates original bound101 replay input")
	check(WorkingPitchProgression.is_version(nested.version, WorkingPitchDynastySave.BOUND_VERSION)
		and nested.session == prior.session and nested.pitch_catalog == prior.pitch_catalog
		and nested == prior,
		"nested mutation preserves exact cold session, catalog and complete envelope")
	check(WorkingPitchDynastySave.binding(nested.session) == WorkingPitchDynastySave.binding(snapshot.session),
		"cold and hot session bindings normalize to the same exact authority")
	var request: Dictionary = {"op": "create", "request_id": "fixture-create", "expected_revision": 0,
		"payload": {"lineage": Lineage.create(profile), "snapshot": snapshot,
			"session_id": "fixture-lineage:1", "origin": origin}}
	var created: Dictionary = Owner.project({}, cold(request))
	check(not created.is_empty(), "Owner3 source-dependent deterministic projection")
	if created.is_empty(): return
	var owner: Dictionary = created.owner
	check(owner.version == Current.VERSION, "versioned owner3, no conversion")
	check(not Owner.new_request_admitted({}, request, owner), "locked origin cannot publish a fresh owner")
	check(Owner.validate_selected(cold(owner), cold(snapshot)) != null, "selected exact binding cold validation")
	check(Owner.transition_valid({}, owner, created.receipt), "create receipt binds projection")
	check(Owner.qualify_origin(owner, created.origin, origin), "exact real origin retained")
	var bad: Dictionary = cold(owner)
	bad.version = 2
	check(Owner.normalize(bad).is_empty(), "Owner2 cannot downgrade current authority")
	bad = cold(snapshot)
	bad.session.owner_id = "other-owner"
	check(Owner.validate_selected(owner, bad) == null, "cross-owner rejects")
	bad = cold(snapshot)
	bad.pitch_catalog = "wrong"
	check(SeasonSave._decode(bad) == null, "cross-catalog rejects")
	var sources: Dictionary = {owner.dynasty.reference.sha256: snapshot}
	var closed: Dictionary = Owner.project(owner, {"op": "close", "request_id": "fixture-close",
		"expected_revision": owner.revision, "session_id": owner.dynasty.session_id, "reason": "abandon"}, sources)
	check(not closed.is_empty(), "abandon preserves unearned credit at zero")
	if closed.is_empty(): return
	var advanced: Dictionary = Owner.project(closed.owner, {"op": "begin_next", "request_id": "fixture-next",
		"expected_revision": closed.owner.revision, "seed": 720, "tier": 0}, sources)
	check(not advanced.is_empty(), "current next generation uses exact carry and decay")
	if advanced.is_empty(): return
	check(advanced.owner.lineage.ordinal == 2 and advanced.owner.career.sessions.size() == 2,
		"new session retained beside immutable settled prefix")
	check(advanced.owner.lineage.start_profile.get("pitch_catalog") == WorkingPitchCatalog.signature(),
		"carry stays bound to same catalog")
	bad = cold(advanced.owner)
	bad.career.sessions[bad.dynasty.session_id].exotic_start = []
	check(Owner.normalize(bad).is_empty(), "stripped prior earned-proof history rejects")
	bad = cold(advanced.owner)
	bad.career.sessions[bad.dynasty.session_id].admission_frontier = {}
	check(Owner.normalize(bad).is_empty(), "stripped prior session reference rejects")
	bad = cold(advanced.owner)
	bad.career.sessions[bad.dynasty.session_id].session.ordinal = 1
	bad.career.sessions[bad.dynasty.session_id].session.generation = 0
	check(Owner.normalize(bad).is_empty(), "duplicate or mislabeled generation rejects")
	var job: Dictionary = {"version": 1, "token": "fixture", "request": "a".repeat(64),
		"fixture": 0, "season": snapshot}
	check(PhysicalRoundProcess.decode_request(job, "fixture") == null, "worker1 cannot downgrade bound101")
	job.version = WorkingPitchDynastySave.WORKER_VERSION
	job["pitch_catalog"] = WorkingPitchCatalog.signature()
	check(PhysicalRoundProcess.decode_request(job, "fixture") == null, "worker10 requires inspected durable owner")
	season.home_property = {"unsupported": true}
	check(WorkingPitchDynastySave.capture(season).is_empty(), "unsupported home is not stripped")


func _public_route_negatives(raw: Dictionary, bound: Dictionary) -> void:
	var prior_path: String = SeasonSave._dynasty_owner_path
	SeasonSave._dynasty_owner_path = ""
	for value: Dictionary in [raw, bound]:
		var detached: SeasonState = SeasonSave._decode(cold(value))
		check(detached != null, "internal current owner replay remains available")
		check(SeasonSave._decode_public(cold(value)) == null,
			"standalone public read rejects raw100 and bound101")
		check(not WorkingPitchDynastySave.public_playable(detached),
			"detached structurally valid proof is not playable authority")
		check(not SeasonSave.save(detached), "public save refuses before any disk write")
		check(not SeasonSave.Operations2._public_save(detached), "direct ordinary writer also refuses")
		var app: SeasonApp = SeasonApp.new()
		app.season = detached
		var controller: RefCounted = load("res://src/presentation/season/dynasty_career_controller.gd").new(app)
		check(not controller.playable(), "unbound shared-controller shortcut also refuses")
		check(not app.commit_shop({"op": "open"}), "unbound current shop mutation refuses")
		check(not app.commit_inventory({"op": "inventory_sell"}), "unbound current inventory mutation refuses")
		app.free()
	SeasonSave._dynasty_owner_path = prior_path

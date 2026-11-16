extends Node
## Synthetic historical funding/public purchase input. Creates no physical results.
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Live = preload("res://src/gameplay/season/dynasty_standard_live.gd")
var checks: int = 0
var failures: int = 0
var destination: String = ""
var funding: String = ""
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("NIGHT_SETUP_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--night-owner-root="):
			destination = arg.trim_prefix("--night-owner-root=")
		if arg.begins_with("--night-funding-input="):
			funding = arg.trim_prefix("--night-funding-input=")
	_run()
	SeasonSave._dynasty_owner_path = ""
	print("SHARED_NIGHT_SETUP checks=%d failures=%d physical_games=0 synthetic_funding=true" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _run() -> void:
	if not check(destination.is_absolute_path() and destination == destination.simplify_path()
		and funding.is_absolute_path() and FileAccess.file_exists(funding)
		and not DirAccess.dir_exists_absolute(destination) and not FileAccess.file_exists(destination),
		"fresh isolated owner root and retained synthetic paid funding input"):
		return
	if not check(StadiumNpcPublicRuntime.source_qualified(), "independently qualified exact source before setup"):
		return
	var funding_hash: String = FileAccess.get_sha256(funding)
	var origin: Variant = JSON.parse_string(FileAccess.get_file_as_string(funding))
	var ordinary: SeasonState = SeasonSave._decode(origin) if origin is Dictionary else null
	if not check(ordinary != null and ordinary.career != null and ordinary.phase == SeasonState.Phase.COMPLETE,
		"retained synthetic completed legacy funding decodes"):
		return
	var paid: ClubAssetLedger = ClubPlayers.assets(ordinary.career)
	if not check(paid != null and not StadiumSurfaceNightLayout.capture(paid).is_empty(), "actual purchased paid layout supports ordinary Night"):
		return
	var authority: Dictionary = Authority.create(origin, "night-setup-prerequisite")
	if not check(not authority.is_empty() and "dynasty" in Authority.available_leagues(authority),
		"validated source tier3 title admits new Dynasty enrollment"):
		return
	var profile: Dictionary = Profile.capture_access_season(origin, "night-physical-lineage", "night-physical-owner")
	var dynasty: SeasonState = Bridge.create(profile)
	if not check(dynasty != null, "synthetic origin qualifies shared owner setup"):
		return
	if not check(DirAccess.make_dir_recursive_absolute(destination) == OK
		and DirAccess.copy_absolute(funding, destination.path_join("synthetic-paid-origin.json")) == OK,
		"retain exact funding bytes before owner creation"):
		return
	var path: String = destination.path_join("owner.json")
	var context: Dictionary = Save.binding_for(dynasty, profile.owner_id, profile.lineage_id, 0, 1, "%s:1" % profile.lineage_id)
	var initial: Dictionary = Save.wrap_checkpoint(SeasonSave.snapshot(dynasty), context)
	if not check(context.get("session_id") == "%s:1" % profile.lineage_id and not initial.is_empty(),
		"initial Dynasty identity matches exact lineage ordinal and qualified envelope"):
		return
	var created: Dictionary = Store.create({"lineage": Lineage.create(profile),
		"snapshot": initial,
		"session_id": context.session_id, "origin": origin}, path)
	if not check(created.get("status") == "committed", "new isolated durable shared owner: " + str(created.get("reason", created.get("error", "")))):
		return
	var owner: Dictionary = created.owner
	var grant: Dictionary = Grant.capture(owner.career)
	var binding: Dictionary = Bound.binding({"owner_id": owner.owner_id, "lineage_id": owner.lineage.id,
		"generation": 0, "ordinal": 1, "session_id": "night-physical-standard:1", "seed": 301,
		"tier": 0, "league": "standard", "format": 89, "starting_profile": "night",
		"grant_sha256": Save.snapshot_reference(grant).sha256})
	var season: SeasonState = Live.create(grant, binding)
	if not check(season != null and season.career == null and season.owned_surface_night.get("mode") == "night",
		"selected Night derives exact immutable paid policy"):
		return
	var opened: Dictionary = Store.transact({"op": "switch", "request_id": "night-physical-open",
		"expected_revision": owner.revision, "target": "other", "session_id": binding.session_id,
		"snapshot": Bound.capture(season, binding, grant, owner.career)}, path)
	if not check(opened.get("status") == "committed" and SeasonSave.bind_dynasty_owner(path), "Night89 owner admission"):
		return
	season = SeasonSave.restore()
	if not check(season != null, "public admitted owner restore"):
		return
	for index in range(4):
		if not check(season.choose_player(season.offers()[0]), "ordinary draft pick " + str(index)):
			return
	if not check(SeasonSave.save(season), "bound full draft checkpoint"):
		return
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	var cold: SeasonState = SeasonSave.restore()
	if not check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), snapshot)
		and cold.owned_surface_night.get("mode") == "night", "selected Night and four picks cold restore exactly"):
		return
	check(ClubCareer.same(cold.pending_fixture(), {"id": 0, "round": 0, "away": 0, "home": 5})
		and cold.results.is_empty() and cold.player_results.is_empty()
		and cold.physical.reports.is_empty() and cold.physical.pending.is_empty(), "natural unchanged away opener; no game evidence manufactured")
	check(ClubPlayerLegend.enabled(cold), "prospective production collector enabled")
	var ready: Dictionary = Store.inspect(path)
	check(ready.get("status") == "ready" and not FileAccess.file_exists(path + ".intent"), "ready owner and no pending intent")
	check(FileAccess.get_sha256(funding) == funding_hash
		and FileAccess.get_sha256(destination.path_join("synthetic-paid-origin.json")) == funding_hash,
		"original synthetic funding and retained copy unchanged")
	_write("night-start89.json", snapshot)
	_write("night-setup-summary.json", {"checks": checks, "failures": failures, "physical_games": 0,
		"synthetic_funding": true, "funding_sha256": funding_hash, "owner_path": path,
		"owner_revision": ready.get("revision"), "source_qualified": StadiumNpcPublicRuntime.source_qualified()})
func _write(name: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(destination.path_join(name), FileAccess.WRITE)
	if not check(file != null, "artifact writable " + name):
		return
	file.store_string(JSON.stringify(value, "", true, true))

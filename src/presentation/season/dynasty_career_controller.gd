extends "res://src/presentation/season/dynasty_owner_controller.gd"
## Candidate owner-v2 UI adapter. Existing owner-v1 controller stays unchanged.

const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const CareerUI = preload("res://src/presentation/season/dynasty_career_ui.gd")
const LeagueController = preload("res://src/presentation/season/league_career_controller.gd")
const TierUI = preload("res://src/presentation/season/dynasty_career_tier_ui.gd")
const Unlocks = preload("res://src/gameplay/season/league_unlocks.gd")

var _next_choice: Dictionary = {}
var _next_ticket: int = 0
var _next_profile_choice: Variant = null  # Empty Day must survive unattempted back/refresh.
var _next_profile_source: String = ""


func view() -> Dictionary:
	var owner: Dictionary = found().get("owner", {})
	return _authority(owner).view(owner.career) if owner.get("version") in [2, 3] else {}


func available_tiers(league: String) -> Array[int]:
	var owner: Dictionary = found().get("owner", {})
	if owner.get("version") not in [2, 3] or league not in LeagueController.IDS + ["dynasty"]:
		return []
	return _authority(owner).available_tiers(owner.career, league)


func available_leagues() -> Array[String]:
	var owner: Dictionary = found().get("owner", {})
	return _authority(owner).available_leagues(owner.career) if owner.get("version") in [2, 3] else []


func ask_next() -> void:
	if not ready() or not _safe_hub():
		return
	var owner: Dictionary = found().owner
	if owner.selected != "dynasty" or not owner.pending_next.is_empty() \
		or owner.lineage.state != "closed":
		super.ask_next()
		return
	TierUI.show(app)


func prepare_next(tier: int, seed_value: int, expected: int) -> bool:
	if not ready() or not _safe_hub():
		return false
	var current: Dictionary = found()
	if current.revision != expected or current.owner.selected != "dynasty" \
		or current.owner.lineage.state != "closed" or not current.owner.pending_next.is_empty() \
		or tier not in available_tiers("dynasty") \
		or not SeasonOwnership._whole(seed_value, 0, 2147483647):
		app.notice = "Reopen the next Dynasty season and choose an unlocked difficulty."
		return false
	var source_key: String = Save.snapshot_reference(current.owner).sha256
	if _next_profile_source != source_key:
		_next_profile_source = source_key
		_next_profile_choice = null
	var selected: String = load("res://src/gameplay/season/dynasty_shared_time.gd").preference(app.season) \
		if _next_profile_choice == null else str(_next_profile_choice)
	_next_ticket += 1
	_next_choice = {"ticket": _next_ticket, "tier": tier, "seed": seed_value, "revision": expected,
		"starting_profile": selected}
	return true


func cancel_next(ticket: int) -> void:
	if not ready(): return  # An uncertain durable attempt retains its exact ticket.
	if not _next_choice.is_empty() and _next_choice.ticket == ticket:
		_next_choice = {}
		_next_ticket += 1


func commit_next(ticket: int) -> bool:
	if _next_choice.is_empty() or _next_choice.ticket != ticket:
		app.notice = "This next-season choice is no longer current."
		return false
	var choice: Dictionary = _next_choice.duplicate()
	if not begin_next_tier(choice.seed, choice.revision, choice.tier, choice.get("starting_profile", "")):
		return false
	cancel_next(ticket)
	return true


func begin_next(seed_value: int, expected: int = -1) -> bool:
	return begin_next_tier(seed_value, expected, 0)


func begin_next_tier(seed_value: int, expected: int, tier: int, starting_profile: String = "") -> bool:
	if not starting_profile.is_empty() and not load("res://src/gameplay/season/dynasty_shared_time.gd").ENTRY_ENABLED:
		app.notice = "Modern home-time Dynasty entry is not enabled yet. Recover any saved attempt unchanged."
		return false
	if not ready() or not _safe_hub():
		return false
	var current: Dictionary = found()
	if (expected >= 0 and current.revision != expected) \
		or current.owner.selected != "dynasty" or current.owner.lineage.state != "closed" \
		or not current.owner.pending_next.is_empty() or tier not in available_tiers("dynasty"):
		app.notice = "This next-season choice is out of date or its difficulty is locked."
		return false
	if not starting_profile.is_empty() and starting_profile not in load("res://src/gameplay/season/dynasty_shared_time.gd").PROFILES: return false
	var payload: Dictionary = {"seed": seed_value, "tier": tier}
	if not starting_profile.is_empty(): payload["starting_profile"] = starting_profile
	var ok: bool = transact(_request("begin_next", current, payload))
	if ok and not found().get("owner", {}).get("pending_next", {}).is_empty():
		show_choice()
	return ok


func ready() -> bool:
	var current: Dictionary = found()
	return (
		current.get("status") == "ready" and current.get("owner", {}).get("version") in [2, 3]
		and app.season != null and not SeasonSave._dynasty_owner_content_blocked
	)


func _safe_hub() -> bool:
	if not super._safe_hub() or app._unsaved_draft != null:
		return false
	if not SeasonSave.dynasty_owner_bound():
		return true
	var owner: Dictionary = found().get("owner", {})
	if owner.is_empty() or not ClubCareer.same(
		Save.snapshot_reference(SeasonSave.snapshot(app.season)), owner[owner.selected].reference
	):
		app.notice = "Save or recover the current season before switching or closing it."
		return false
	return true


func playable() -> bool:
	if not WorkingPitchDynastySave.public_playable(app.season):
		return false
	if not SeasonSave.dynasty_owner_bound():
		return true
	if not ready() or not super.playable():
		return false
	var owner: Dictionary = found().owner
	return owner.career.sessions[owner[owner.selected].session_id].settled == 0


func switch_to(target: String, expected: int = -1, _seed_value: int = -1) -> bool:
	var owner: Dictionary = found().get("owner", {})
	if not ready() or target not in ["dynasty", "other"] or owner.get(target, {}).is_empty():
		app.notice = "Recover the save or choose a fresh alternate in League selection."
		return false
	if target == "other" and owner.career.sessions[owner.other.session_id].settled > 0:
		app.notice = "That alternate is closed. Its result remains in the shared club record."
		return false
	return super.switch_to(target, expected)


func ask_switch(target: String) -> void:
	if not ready() or not _safe_hub():
		return
	var expected: int = int(found().revision)
	app._confirm(
		"Switch to the saved season? Your current season and roster stay saved exactly as they are.",
		func() -> void: switch_to(target, expected)
	)
	app._dialog.get_cancel_button().grab_focus()


func close_current(reason: String, expected: int = -1) -> bool:
	var current: Dictionary = found()
	if not ready() or (expected >= 0 and current.get("revision") != expected):
		app.notice = "This season choice is out of date. Recover or reopen it."
		return false
	var owner: Dictionary = current.owner
	return transact(_request("close", current, {
		"session_id": owner[owner.selected].session_id, "reason": reason
	}))


func ask_end() -> void:
	if not ready() or not _safe_hub():
		return
	var current: Dictionary = found()
	var complete: bool = app.season.phase == SeasonState.Phase.COMPLETE
	var is_dynasty: bool = current.owner.selected == "dynasty"
	var message: String = (
		"Confirm this completed season is closed? Saved rewards cannot be paid twice."
		if complete else "Abandon this unfinished season? It earns no season-completion Club Bucks."
	)
	message += " The Dynasty roster stays for its next season." if is_dynasty else (
		" Dynasty stays saved. This alternate's roster will not carry into a replacement."
	)
	app._confirm(message, close_current.bind("complete" if complete else "abandon", current.revision))
	app._dialog.get_cancel_button().grab_focus()


func start_other(league: String, expected: int, seed_value: int, tier: int = 0, starting_profile: String = "") -> bool:
	if league != "standard" and not starting_profile.is_empty() \
		and not load("res://src/gameplay/season/dynasty_shared_time.gd").ENTRY_ENABLED:
		app.notice = "Modern home-time alternate entry is not enabled yet. Existing seasons are unchanged."
		return false
	if (league == "standard" and starting_profile not in ["", "day", "sunset", "night"]) \
		or (league != "standard" and not starting_profile.is_empty() and starting_profile not in load("res://src/gameplay/season/dynasty_shared_time.gd").PROFILES):
		return false
	if not _other_entry_ready(league, tier):
		return false
	var current: Dictionary = found()
	var owner: Dictionary = current.owner
	if current.revision != expected or owner.selected != "dynasty":
		app.notice = "Return to Dynasty and reopen League selection before starting an alternate."
		return false
	if not owner.other.is_empty():
		var prior: Dictionary = owner.career.sessions.get(owner.other.session_id, {})
		if prior.get("settled", 0) == 0:
			app.notice = "Resume or close the saved alternate before replacing it."
			return false
	var id: String = "alternate:%d:%d" % [expected, seed_value]
	if league == "standard":
		var snapshot: Dictionary = _standard_candidate(owner, seed_value, tier, id, starting_profile)
		if snapshot.is_empty():
			app.notice = "The selected home-time profile is unavailable for this frozen paid home field. Existing seasons are unchanged." \
				if not starting_profile.is_empty() else "Could not prepare owned Standard. Existing seasons are unchanged."
			return false
		return transact(_request("switch", current, {
			"target": "other", "session_id": id, "snapshot": snapshot
		}))
	var context: Dictionary = Save.binding({"owner_id": owner.owner_id,
		"lineage_id": owner.lineage.id, "generation": owner.lineage.generation,
		"ordinal": owner.lineage.ordinal, "session_id": id, "seed": seed_value,
		"league": league, "tier": tier,
		"access_sha256": ClosedContentAccess.digest(Authority.access(owner.career))})
	var snapshot: Dictionary = load("res://src/gameplay/season/dynasty_shared_time.gd").prepare_alternate(owner.career, context, starting_profile) \
		if not starting_profile.is_empty() else load("res://src/gameplay/season/dynasty_league_home_live.gd").prepare(owner.career, context)
	if snapshot.is_empty():
		app.notice = "The new alternate failed validation. Existing seasons are unchanged."
		return false
	return transact(_request("switch", current, {
		"target": "other", "session_id": id, "snapshot": snapshot
	}))


func _standard_candidate(owner: Dictionary, seed_value: int, tier: int, id: String, starting_profile: String = "") -> Dictionary:
	var bound: GDScript = load("res://src/gameplay/season/dynasty_standard_save.gd")
	var grant: Dictionary = load("res://src/gameplay/season/dynasty_standard_grant.gd").capture(owner.career)
	if grant.is_empty():
		return {}
	var context: Dictionary = bound.binding({"owner_id": owner.owner_id, "lineage_id": owner.lineage.id,
		"generation": owner.lineage.generation, "ordinal": owner.lineage.ordinal,
		"session_id": id, "seed": seed_value, "tier": tier, "league": "standard",
		"format": bound.LIVE_VERSION, "grant_sha256": Save.snapshot_reference(grant).sha256})
	if not starting_profile.is_empty():
		context["starting_profile"] = starting_profile
		context = bound.binding(context)
	var next: SeasonState = load("res://src/gameplay/season/dynasty_standard_live.gd").create(grant, context)
	return bound.capture(next, context, grant, owner.career) if next != null else {}


func _other_entry_ready(league: String, tier: int) -> bool:
	if league in LeagueController.IDS and league not in available_leagues():
		app.notice = Unlocks.requirement(league) + " Existing seasons are unchanged."
		return false
	return ready() and _safe_hub() and league in LeagueController.IDS \
		and tier in available_tiers(league)


func draft_pick(id: String) -> bool:
	if not ready() or not _safe_hub() or app.season.phase != SeasonState.Phase.DRAFT:
		return false
	var next: SeasonState = SeasonSave._decode(SeasonSave.snapshot(app.season))
	if next == null or not next.choose_player(id):
		app.notice = "Choose one of the current three offers."
		return false
	if next.picks.size() == 4 and not next.league_rules.is_empty() and not SeasonInventoryRules.enable(next):
		app.notice = "Could not admit the alternate inventory. Your prior picks stay saved."
		return false
	next._dynasty_owner_binding = app.season._dynasty_owner_binding.duplicate(true)
	if not SeasonSave.save(next):
		app.notice = SeasonSave.last_error
		return false
	app.season = next
	app.menu.draft_selection = ""
	app.notice = ""
	return true


func add_controls(menu: SeasonMenu, parent: Control) -> void:
	if not SeasonSave.dynasty_owner_bound():
		return
	if not ready():
		menu._button(parent, "RECOVER SHARED CAREER", _recover)
		if app.dynasty_enrollment.pending():
			menu._button(parent, "RETRY DYNASTY START", CareerUI.enrollment.bind(app))
		return
	var owner: Dictionary = found().owner
	menu._button(parent, "CHOOSE LEAGUE", CareerUI.show.bind(app))
	if owner.selected == "other":
		menu._button(parent, "RETURN TO DYNASTY", ask_switch.bind("dynasty"))
		if owner.career.sessions[owner.other.session_id].settled == 0:
			menu._button(parent, "RETRY RESULT SAVE" if app.season.phase == SeasonState.Phase.COMPLETE
				else "ABANDON ALTERNATE", _retry_completed if app.season.phase == SeasonState.Phase.COMPLETE
				else ask_end)
	else:
		var pending_result: bool = (
			app.season.phase == SeasonState.Phase.COMPLETE and owner.lineage.state != "closed"
		)
		menu._button(parent, "RETRY RESULT SAVE" if pending_result else
			("NEXT DYNASTY SEASON" if owner.lineage.state == "closed" else "END DYNASTY SEASON"),
			_retry_completed if pending_result else ask_next)


func _retry_completed() -> void:
	if app.season != null and app.season.phase == SeasonState.Phase.COMPLETE:
		app._checkpoint()
	app.show_season()


func _recover() -> void:
	recover()
	app.menu.show_home()


func next_starting_profile(ticket: int, selected: String) -> bool:
	if not ready() or not _safe_hub() or _next_choice.is_empty(): return false
	var current: Dictionary = found()
	if current.revision != _next_choice.revision or current.owner.selected != "dynasty" \
		or current.owner.lineage.state != "closed" or not current.owner.pending_next.is_empty(): return false
	if _next_choice.ticket != ticket \
		or (not selected.is_empty() and selected not in load("res://src/gameplay/season/dynasty_shared_time.gd").PROFILES): return false
	_next_ticket += 1
	_next_choice.ticket = _next_ticket
	_next_choice.starting_profile = selected
	_next_profile_choice = selected
	return true


static func _authority(owner: Dictionary) -> GDScript:
	return load("res://src/gameplay/season/working_pitch_dynasty_authority.gd") if owner.get("version") == 3 else Authority

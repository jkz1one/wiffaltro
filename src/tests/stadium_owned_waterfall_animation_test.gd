extends Node3D
## Synthetic paid progress, real exact-copy journals and public runtime installer. Not earned
## career.
const LIVE: String = "purchase:motion-water:0"
const PLAZA: String = "purchase:motion-water:1"
const KIT: String = "purchase:motion-plaza:0"
var checks: int = 0
var failures: Array[String] = []
var credits: Array = []
var progress: Array = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("OWNED_WATERFALL_MOTION " + label)


func _ready() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5, "homers": 5})
	var paid: ClubAssetLedger = ClubAssetLedger.new(216, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		check(
			(
				paid
				. commit(
					{
						"id": "motion-land-" + tier,
						"rev": paid.revision(),
						"op": "stadium_land",
						"tier": tier,
						"through": 40,
						"progress_through": 40,
						"price_version": 1
					}
				)
				. ok
			),
			"paid land " + tier
		)
	for row: Array in [
		["motion-water", "ST-046", 2, "stadium_buy", 32],
		["motion-plaza", "ST-112", 1, "stadium_buy", 34],
		["motion-standard", "ST-024", 23, "stadium_buy", 8],
		["motion-low", "ST-024-L", 23, "stadium_wall_piece", 1]
	]:
		var result: Dictionary = paid.commit(
			{
				"id": row[0],
				"rev": paid.revision(),
				"op": row[3],
				"item": row[1],
				"quantity": row[2],
				"price_version": row[4],
				"through": 40,
				"progress_through": 40
			}
		)
		check(result.ok, "paid stock " + str(row[1]) + ": " + result.error)
	var historical: Dictionary = paid.to_data()
	var historical_revision: int = paid.revision()
	var stock: StadiumStock = paid.construction()
	var static45: Dictionary = StadiumWaterfallLiveItems.place(
		paid.view().stadium_draft, stock, LIVE, "WF-LIVE-LF", 0, paid.surface_owned()
	)
	static45 = StadiumOutfieldPlazaItems.place(
		static45, stock, KIT, "promenade_court", paid.surface_owned()
	)
	static45 = StadiumOutfieldPlazaItems.place_occupant(static45, PLAZA, "PLAZA-W")
	var moving: Dictionary = StadiumWaterfallAnimationLayout.select(static45, LIVE, true)
	moving = StadiumWaterfallAnimationLayout.select(moving, PLAZA, true)
	check(_valid(paid, moving).ok, "complete paid45 live/plaza motion layout")
	check(
		ClubCareer.same(StadiumWaterfallAnimationLayout.base(moving), static45),
		"retained45 exact base projection, no history mutation"
	)
	check(
		not StadiumHomeLayout.validate(moving, stock, "mogul").ok,
		"stock-only route cannot grant complete47 ownership"
	)
	var bad: Dictionary = moving.duplicate(true)
	bad.animation_base = 46
	check(not _valid(paid, bad).ok, "swapped base46 without its exact contract rejected")
	bad = moving.duplicate(true)
	bad.waterfall_motion.append(LIVE)
	check(not _valid(paid, bad).ok, "duplicate motion copy rejected")
	bad = moving.duplicate(true)
	bad.waterfall_motion = [KIT]
	check(not _valid(paid, bad).ok, "infrastructure copy cannot animate as waterfall")
	bad = moving.duplicate(true)
	bad.waterfall_motion.reverse()
	check(not _valid(paid, bad).ok, "noncanonical copy order rejected")
	if _apply(paid, moving, "45-live-and-plaza"):
		_cold(paid, "45-live-and-plaza")
		if "--animation-runtime" in OS.get_cmdline_user_args():
			await _runtime(paid, true)
			await _attach_callback_control(paid)
	check(
		paid.to_data().version == 56 and paid.to_data().has("waterfall_animation_catalog"),
		"canonical additive ledger56"
	)
	check(
		ClubCareer.same(paid.prefix(historical_revision).to_data(), historical),
		"all historical headers and exact prefix preserved"
	)
	bad = paid.to_data()
	bad.erase("waterfall_animation_catalog")
	check(
		ClubAssetLedger.from_data(bad, 216, credits, progress) == null,
		"missing motion catalog rejected"
	)
	bad = paid.to_data()
	bad.version = 55
	bad.erase("waterfall_animation_catalog")
	check(
		ClubAssetLedger.from_data(bad, 216, credits, progress) == null,
		"pre56 journal cannot carry47 events"
	)
	var stored: Dictionary = StadiumWaterfallAnimationLayout.store_copy(moving, LIVE)
	check(
		(
			_valid(paid, stored).ok
			and stored.live_waterfalls.is_empty()
			and stored.waterfall_motion == [PLAZA]
			and stored.outfield_plaza[0].occupants[0].copy == PLAZA
		),
		"Store exact live copy preserves other model and clears only its motion"
	)
	if _apply(paid, stored, "45-decorative-only"):
		_cold(paid, "45-decorative-only")
	bad = stored.duplicate(true)
	bad.waterfall_motion.append(LIVE)
	bad.waterfall_motion.sort()
	check(not _valid(paid, bad).ok, "stored paid copy cannot animate offstage")
	for profile: String in StadiumLowWallRecipes.PROFILES:
		var low: Dictionary = StadiumLowWallLayout.upgrade(
			StadiumWaterfallAnimationLayout.base(stored), paid.surface_owned()
		)
		var suggested: Dictionary = StadiumLowWallManifest.suggest(
			profile, "ST-024", stock, paid.wall_pieces().stock
		)
		check(suggested.ok, "exact low profile suggestion " + profile)
		if not suggested.ok:
			continue
		low.low_wall = suggested.manifest
		var low_moving: Dictionary = StadiumWaterfallAnimationLayout.select(low, PLAZA, true)
		check(_valid(paid, low_moving).ok, "retained46 decorative full-size plaza " + profile)
		check(
			ClubCareer.same(StadiumWaterfallAnimationLayout.base(low_moving), low),
			"retained46 projects losslessly " + profile
		)
		bad = low_moving.duplicate(true)
		bad.animation_base = 45
		check(not _valid(paid, bad).ok, "low ownership cannot masquerade as45 " + profile)
		bad = low_moving.duplicate(true)
		bad.live_waterfalls = [{"copy": LIVE, "site": "WF-LIVE-LF"}]
		check(not _valid(paid, bad).ok, "46 live composition remains explicitly blocked " + profile)
		if _apply(paid, low_moving, profile):
			_cold(paid, profile)
			if "--animation-runtime" in OS.get_cmdline_user_args():
				await _runtime(paid, false)
		var stored_plaza: Dictionary = StadiumWaterfallAnimationLayout.store_copy(low_moving, PLAZA)
		check(
			(
				_valid(paid, stored_plaza).ok
				and stored_plaza.waterfall_motion.is_empty()
				and stored_plaza.outfield_plaza[0].occupants.is_empty()
				and stored_plaza.low_wall == low.low_wall
			),
			"46 Store keeps low owners and plaza infrastructure " + profile
		)
	print(
		(
			"OWNED_WATERFALL_ANIMATION_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_progression": true,
					"runtime_requested": "--animation-runtime" in OS.get_cmdline_user_args(),
					"native_visual_qualification": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _valid(paid: ClubAssetLedger, layout: Dictionary) -> Dictionary:
	return StadiumOwnedLayout.validate(
		layout,
		paid.construction(),
		paid.wall_pieces(),
		paid.surface_owned(),
		paid.view().land,
		paid.scoreboards()
	)


func _apply(paid: ClubAssetLedger, layout: Dictionary, label: String) -> bool:
	var balance: int = paid.balance()
	var stock: Dictionary = paid.construction().to_data()
	var saved: Dictionary = paid.commit(
		{
			"id": "motion-draft-" + str(paid.revision()),
			"rev": paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	check(saved.ok, "paid draft " + label + ": " + saved.error)
	if not saved.ok:
		return false
	var applied: Dictionary = paid.commit(
		{
			"id": "motion-apply-" + str(paid.revision()),
			"rev": paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry(paid.view().land, layout)
		}
	)
	check(
		(
			applied.ok
			and balance == paid.balance()
			and ClubCareer.same(stock, paid.construction().to_data())
		),
		"paid Apply, no charge or inventory mutation " + label + ": " + applied.error
	)
	return applied.ok


func _cold(paid: ClubAssetLedger, label: String) -> void:
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(paid.to_data(), "", true, true)), 216, credits, progress
	)
	check(
		cold != null and ClubCareer.same(cold.to_data(), paid.to_data()),
		"cold canonical56 full journal " + label
	)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(paid)
	check(
		(
			not snapshot.is_empty()
			and snapshot.version == 34
			and StadiumLayoutSnapshot.valid(snapshot)
			and StadiumLayoutSnapshot.matches(snapshot, paid)
		),
		"exact immutable entry34 " + label
	)
	if snapshot.is_empty():
		return
	var copy: Dictionary = JSON.parse_string(JSON.stringify(snapshot, "", true, true))
	check(
		(
			StadiumLayoutSnapshot.valid(copy)
			and StadiumLayoutSnapshot.key(copy) == StadiumLayoutSnapshot.key(snapshot)
		),
		"cold snapshot key stable " + label
	)
	var fixture: Dictionary = StadiumWaterfallAnimationSnapshot.fixture(snapshot, 216, 1)
	check(
		(
			StadiumLayoutSnapshot.valid(fixture)
			and fixture.version == 35
			and fixture.environment.mode == "day"
		),
		"exact fixture35 day-only " + label
	)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.layout.waterfall_motion = []
	check(
		not StadiumLayoutSnapshot.matches(bad, paid),
		"even structurally legal static selection cannot borrow paid receipt " + label
	)


func _runtime(paid: ClubAssetLedger, live: bool) -> void:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(paid)
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = snapshot
	lab._stadium_ledger = paid
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	check(
		installed,
		(
			"ordinary exact paid47 installer accepts base "
			+ str(snapshot.get("layout", {}).get("animation_base"))
		)
	)
	if installed:
		var property: StadiumWaterfallAnimationProperty = lab.get_meta("stadium_property")
		var owner: StadiumWaterfallAnimationRuntime = StadiumWaterfallAnimationRuntime.current(lab)
		owner.set_process(false)
		check(
			(
				owner != null
				and property.props_intact()
				and StadiumBoundaryRuntime.installed(lab, snapshot)
			),
			"complete47 context and observer live"
		)
		check(property.has_live_waterfall() == live, "only declared45 live model owns native trap")
		if live:
			await _foreign_owner_control(lab, property, paid)
		lab._match_state.phase = MatchState.Phase.PLAY_DEAD
		lab._at_bat_cadence.state = AtBatCadenceController.State.IDLE
		owner._process(0.1)
		check(
			not owner.retired and owner._lease.phase > 0 and property.props_intact(),
			"installed exact-copy clock advances only quiet dead play"
		)
		var phase: float = owner._lease.phase
		for action: MatchState.Phase in [
			MatchState.Phase.PRE_PITCH,
			MatchState.Phase.PITCH_IN_FLIGHT,
			MatchState.Phase.BALL_IN_PLAY
		]:
			lab._match_state.phase = action
			owner._process(0.15)
			check(
				owner._lease.phase == phase, "action phase freezes without catch-up " + str(action)
			)
		check(
			owner._lease.advance(0.1, false, false) and owner._lease.phase == phase,
			"direct bound lease caller cannot bypass active-ball gate"
		)
		check(
			owner._lease.reset() and owner._lease.phase == phase,
			"direct bound reset cannot change actionable phase"
		)
		lab._match_state.phase = MatchState.Phase.PLAY_DEAD
		lab._debug_paused = true
		owner._process(0.15)
		check(owner._lease.phase == phase, "actual lab pause freezes motion")
		lab._debug_paused = false
		owner._process(0.4)
		check(owner._lease.phase == phase, "long frame freezes motion")
		check(
			StadiumWaterfallAnimationRuntime.before_pitch(lab) and owner._lease.phase == phase,
			"pre-pitch guard preserves exact frozen phase"
		)
		await _claim_controls(paid)
		check(
			owner.intact() and property.props_intact(),
			"independent claim controls leave original installation intact"
		)
		lab._automation = MatchAutomation.new()
		# Same initial workload map as MatchAutomation.begin, without starting a
		# delivery. This is report formation only, never a completed-game receipt.
		for team: TeamMatchState in [lab._match_state.away_team, lab._match_state.home_team]:
			for player: PlayerMatchState in team.roster:
				lab._automation.initial[String(player.definition.id)] = player.stamina_remaining
		check(
			not PhysicalMatchReport._capture_core(lab).is_empty(),
			"report negative has a real nonempty ordinary fallback control"
		)
		lab._match_state.stadium = {}
		lab.remove_meta(StadiumWaterfallAnimationInstall.BOUND)
		lab.remove_meta("stadium_property")
		check(
			PhysicalMatchReport.capture(lab).is_empty(),
			"simultaneous snapshot and markers stripping cannot report as ordinary baseball"
		)
		lab._match_state.stadium = snapshot
		lab.set_meta(StadiumWaterfallAnimationInstall.BOUND, true)
		lab.set_meta("stadium_property", property)
		lab._automation = null
		lab._match_state.stadium.layout.animation_base = (
			46 if snapshot.layout.animation_base == 45 else 45
		)
		check(
			(
				not owner.intact()
				and not StadiumBoundaryRuntime.installed(lab, lab._match_state.stadium)
			),
			"swapped base cannot keep installed authority"
		)
		owner._process(0.1)
		check(
			owner.retired and owner._lease.phase == phase,
			"foreign snapshot retires without uniform overwrite"
		)
	else:
		print(
			"MOTION_INSTALL_DIAGNOSTIC ",
			{
				"snapshot": snapshot.keys(),
				"property": lab.has_meta("stadium_property"),
				"boundary": lab.get_meta("boundary_signature", "")
			}
		)
	lab.queue_free()
	await get_tree().process_frame


func _attach_callback_control(source: ClubAssetLedger) -> void:
	var paid: ClubAssetLedger = ClubAssetLedger.from_data(source.to_data(), 216, credits, progress)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(paid)
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = snapshot
	lab._stadium_ledger = paid
	var original_generation: int = paid.mutation_generation()
	var probe: Dictionary = {"fired": false}
	var host: StarterFieldLabGeometry = lab.get_node("StarterFieldGeometry")
	host.child_entered_tree.connect(
		func(child: Node) -> void:
			if child.name == "HomeProperty" and not probe.fired:
				paid._credits[0] += 1
				probe.fired = true
	)
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	check(
		probe.fired and paid.mutation_generation() == original_generation,
		"same-generation raw-ledger callback control actually executes during attach"
	)
	check(
		(
			not installed
			and StadiumWaterfallAnimationRuntime.current(lab) == null
			and not StadiumBoundaryRuntime.installed(lab, snapshot)
		),
		"attach callback cannot be adopted as initial paid authority"
	)
	lab.queue_free()
	await get_tree().process_frame


func _foreign_owner_control(
	source_lab: PitchBatLab,
	source_property: StadiumWaterfallAnimationProperty,
	paid: ClubAssetLedger
) -> void:
	var other: PitchBatLab = PitchBatLab.new()
	add_child(other)
	PitchBatLabFeelSupport.skip_match_presentation(other)
	PitchBatLabPresentation.hide_match_presentation(other)
	other.set_process(false)
	other.set_physics_process(false)
	other._pitch_actor.set_physics_process(false)
	other._primary_fielder.set_physics_process(false)
	other._match_state.stadium = source_lab._match_state.stadium.duplicate(true)
	other._stadium_ledger = paid
	var installed: bool = StadiumPropertyRuntime.install_bound(other)
	check(installed, "foreign-owner refusal has a second real exact paid installation")
	if installed:
		var property: StadiumWaterfallAnimationProperty = other.get_meta("stadium_property")
		var owner: StadiumWaterfallAnimationRuntime = StadiumWaterfallAnimationRuntime.current(
			other
		)
		owner.set_process(false)
		source_lab.set_meta("stadium_property", property)
		check(
			(
				StadiumWaterfallAnimationRuntime.current(source_lab) == null
				and not StadiumWaterfallAnimationRuntime.before_pitch(source_lab)
			),
			"a real foreign owner cannot satisfy caller's pre-pitch gate"
		)
		check(
			not owner.retired and owner.intact() and property.props_intact(),
			"refusing the foreign claim never retires or mutates its rightful installation"
		)
		source_lab.set_meta("stadium_property", source_property)
	other.queue_free()
	await get_tree().process_frame


func _claim_controls(paid: ClubAssetLedger) -> void:
	# Issued-context revocation is sticky. Each negative needs its own public installation;
	# restoring metadata must never resurrect the retired paid binding.
	for mode: String in ["absent", "text", "array", "foreign-node"]:
		var snapshot: Dictionary = StadiumLayoutSnapshot.capture(paid)
		var lab: PitchBatLab = PitchBatLab.new()
		add_child(lab)
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		PitchBatLabPresentation.hide_match_presentation(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		lab._pitch_actor.set_physics_process(false)
		lab._primary_fielder.set_physics_process(false)
		lab._match_state.stadium = snapshot
		lab._stadium_ledger = paid
		var installed: bool = StadiumPropertyRuntime.install_bound(lab)
		check(installed, "fresh paid claim control installation " + mode)
		if installed:
			var property: StadiumWaterfallAnimationProperty = lab.get_meta("stadium_property")
			var owner: StadiumWaterfallAnimationRuntime = StadiumWaterfallAnimationRuntime.current(
				lab
			)
			check(
				owner != null and owner.intact() and property.props_intact(),
				"claim control starts with intact issued authority " + mode
			)
			owner.set_process(false)
			var foreign: Node = Node.new()
			if mode == "absent":
				lab.remove_meta("stadium_property")
			elif mode == "text":
				lab.set_meta("stadium_property", "foreign")
			elif mode == "array":
				lab.set_meta("stadium_property", [])
			else:
				lab.set_meta("stadium_property", foreign)
			check(
				(
					StadiumWaterfallAnimationRuntime.current(lab) == null
					and not owner.intact()
					and not property.props_intact()
					and not StadiumBoundaryRuntime.installed(lab, snapshot)
				),
				"missing/foreign claim refuses safely " + mode
			)
			lab.set_meta("stadium_property", property)
			foreign.free()
			check(
				(
					not owner.intact()
					and not property.props_intact()
					and not StadiumWaterfallAnimationRuntime.before_pitch(lab)
				),
				"restored metadata cannot resurrect revoked issued authority " + mode
			)
		lab.queue_free()
		await get_tree().process_frame

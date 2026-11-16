extends RefCounted
## Test-only exact original capture body. No runtime replacement or production dispatch.
## Source correspondence is checked by verify_staging.py.


static func capture(lab: PitchBatLab) -> Dictionary:
	if (
		is_instance_valid(lab)
		and (
			StadiumWaterfallAnimationInstall.requested(lab)
			or lab.has_meta(StadiumWaterfallAnimationInstall.BOUND)
			or (
				StadiumWaterfallAnimationRuntime.property_claim(lab)
				is StadiumWaterfallAnimationProperty
			)
			or (
				lab._ball_play_resolver != null
				and lab._ball_play_resolver.segment_observer.is_valid()
				and (
					(
						lab._ball_play_resolver.segment_observer.get_object()
						is StadiumWaterfallAnimationBoundary
					)
					or (
						lab._ball_play_resolver.segment_observer.get_object()
						is StadiumWaterfallAnimationLowBoundary
					)
				)
			)
		)
	):
		if (
			lab._match_state == null
			or not StadiumWaterfallAnimationInstall.installed_bound(lab, lab._match_state.stadium)
		):
			return {}
	elif (
		is_instance_valid(lab)
		and (
			lab.has_meta(StadiumLowWallRuntime.BOUND)
			or (
				lab.has_meta("stadium_property")
				and lab.get_meta("stadium_property") is StadiumLowWallProperty
			)
			or (
				lab._ball_play_resolver != null
				and lab._ball_play_resolver.segment_observer.is_valid()
				and (
					lab._ball_play_resolver.segment_observer.get_object()
					is StadiumLowWallBoundaryRuntime
				)
			)
		)
	):
		if (
			lab._match_state == null
			or not StadiumLowWallRuntime.installed_bound(lab, lab._match_state.stadium)
		):
			return {}
	if (
		is_instance_valid(lab)
		and (
			lab.has_meta(StadiumSurfaceTerrainRuntime.BOUND)
			or (
				lab._match_state != null
				and StadiumLayoutSnapshot.is_terrain(lab._match_state.stadium)
			)
		)
	):
		return PhysicalStadiumReport.terrain_capture(lab)
	if (
		is_instance_valid(lab)
		and (
			lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
			or (
				lab._match_state != null
				and StadiumSurfaceNightSnapshot.is_family(lab._match_state.stadium)
			)
		)
	):
		return StadiumSurfaceNightReport.capture(lab)
	if (
		lab == null
		or lab._match_state == null
		or lab._automation == null
		or lab.get_meta("stadium_candidate_only", false)
		or lab.get_meta("stadium_npc_retained_lab_only", false)
		or lab.has_meta(StadiumNpcYardThreeRuntimeV1.OPT_IN)
		or lab.has_meta("stadium_npc_runtime_interrupted")
		or lab.has_meta("stadium_npc_runtime_restoring")
	):
		return {}
	# Public installation history prevents fallback after removal or failed binding.
	if lab.has_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND):
		if not StadiumNpcPublicRuntime.installed_bound(lab, lab._match_state.stadium):
			return {}
		if (
			lab._match_state.stadium.get("version")
			== StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
		):
			return StadiumHillsidePublicReport.capture(lab)
		if (
			lab._match_state.stadium.get("version")
			== StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION
		):
			return StadiumPoolPartyPublicReport.capture(lab)
		if (
			lab._match_state.stadium.get("version")
			== StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION
		):
			return StadiumGrandIIIPublicReport.capture(lab)
		if (
			lab._match_state.stadium.get("version")
			== StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION
		):
			return StadiumGrandIIPublicReport.capture(lab)
		if (
			lab._match_state.stadium.get("version")
			== StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION
		):
			return StadiumGrandIPublicReport.capture(lab)
		return (
			StadiumLongYardPublicReport.capture(lab)
			if lab._match_state.stadium.get("version") == StadiumNpcSnapshot.FINAL_FIXTURE_VERSION
			else StadiumNpcPublicReport.capture(lab)
		)
	# A removed or failed AY03 public install must never fall back to ordinary baseball.
	if lab.has_meta(StadiumNpcYardThreeRuntimeV1.PUBLIC_BOUND):
		if not StadiumNpcYardThreeRuntimeV1.installed_bound(lab, lab._match_state.stadium):
			return {}
		return StadiumNpcYardThreeReport.capture(lab)
	if StadiumNpcSnapshot.is_public(lab._match_state.stadium):
		var resolver: String = PhysicalStadiumReport.npc_resolver(lab._match_state.stadium)
		if resolver == StadiumHillsidePublicReport.RESOLVER:
			return StadiumHillsidePublicReport.capture(lab)
		if resolver == StadiumPoolPartyPublicReport.RESOLVER:
			return StadiumPoolPartyPublicReport.capture(lab)
		if resolver == StadiumGrandIIIPublicReport.RESOLVER:
			return StadiumGrandIIIPublicReport.capture(lab)
		if resolver == StadiumGrandIIPublicReport.RESOLVER:
			return StadiumGrandIIPublicReport.capture(lab)
		if resolver == StadiumGrandIPublicReport.RESOLVER:
			return StadiumGrandIPublicReport.capture(lab)
		if resolver == StadiumLongYardPublicReport.RESOLVER:
			return StadiumLongYardPublicReport.capture(lab)
		if resolver == StadiumNpcPublicReport.RESOLVER:
			return StadiumNpcPublicReport.capture(lab)
		if resolver == StadiumNpcYardTwoReport.RESOLVER:
			return StadiumNpcYardTwoReport.capture(lab)
		if resolver == StadiumNpcYardThreeReport.RESOLVER:
			return StadiumNpcYardThreeReport.capture(lab)
		return {}
	if (
		lab._match_state != null
		and lab._match_state.stadium.get("version") == StadiumPoolOwnedSnapshot.FIXTURE_VERSION
	):
		return StadiumPoolOwnedReport.capture(lab)
	var state: MatchState = lab._match_state
	var result: Dictionary = PhysicalMatchReport._capture_core(lab)
	if not state.stadium.is_empty():
		var installed: Variant = lab.get_meta("stadium_snapshot", null)
		if (
			not installed is Dictionary
			or StadiumLayoutSnapshot.key(installed) != StadiumLayoutSnapshot.key(state.stadium)
		):
			return {}
		if (
			state.stadium.has("boundary")
			and not StadiumBoundaryRuntime.installed(lab, state.stadium)
		):
			return {}
		return PhysicalStadiumReport.wrap(
			result,
			state.stadium,
			(
				PhysicalStadiumContacts.capture(lab._play_records)
				if state.stadium.has("boundary")
				else []
			)
		)
	return result

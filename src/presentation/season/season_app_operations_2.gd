extends RefCounted
## Stateless operations for the original SeasonApp owner.


# gdlint: disable=max-returns
static func _source_private_begin_season_final_profile(_source_owner: SeasonApp,
	seed_value: int,
	working_progression: bool,
	permanent_players: bool,
	home_stadium: bool,
	complete_boundary: bool,
	surface_progression: bool,
	selected_tier: int,
	night_opt_in: bool,
	starting_profile: String,
	gardens_profile: String
) -> void:
	if _source_owner._unsaved_draft != null:
		_source_owner.show_season()
		return
	if SeasonSave.dynasty_owner_bound():
		_source_owner.notice = "Use the saved profile controls to switch seasons."
		_source_owner.menu.show_home()
		return
	if (
		not gardens_profile.is_empty()
		and (
			gardens_profile not in ["day", "sunset", "night"]
			or selected_tier != 4
			or not working_progression
			or not permanent_players
			or not home_stadium
			or not complete_boundary
			or not surface_progression
		)
	):
		_source_owner.notice = "That Gardens starting profile is unavailable. Your season is unchanged."
		_source_owner.menu.show_home()
		return
	if (
		selected_tier not in [0, 1, 2, 3, 4]
		or (selected_tier == 4 and not ClubCareer.D4_PUBLIC_ACTIVATION_ENABLED)
		or (
			selected_tier > 0
			and (
				not working_progression
				or not permanent_players
				or not home_stadium
				or not complete_boundary
			)
		)
	):
		_source_owner.notice = \
			"That Standard tier is unavailable. Your season and club history are unchanged."
		_source_owner.menu.show_home()
		return
	var selected_seed: int = int(Time.get_unix_time_from_system()) & 0x7fffffff
	var previous: SeasonState = _source_owner.season
	if (
		previous == null
		and (
			FileAccess.file_exists(SeasonSave.path)
			or FileAccess.file_exists(SeasonSave.path + ".bak")
		)
	):
		_source_owner.notice = (
			"The saved season could not be read. It was left untouched. "
			+ "Restore it before starting another season."
		)
		_source_owner.menu.show_home()
		return
	var candidate: SeasonState = SeasonState.create(
		selected_seed if seed_value < 0 else seed_value,
		false,
		working_progression,
		working_progression
	)
	candidate.difficulty = 1
	if working_progression:
		candidate.physical = SeasonPhysicalFixtures.new()
		candidate.opponents._format = 13
	if working_progression or (previous != null and previous.career != null):
		var club: ClubCareer = ClubCareer.new()
		if previous != null and previous.career != null:
			club = previous.career.fork()
			if not club.close(previous):
				_source_owner.notice = "Could not preserve the current club record. Your season is unchanged."
				_source_owner.menu.show_home()
				return
		# Fresh careers adopt the explicit catalog. Existing historical careers keep
		# their original books; a current career retains its bound catalog on restart.
		if working_progression and (club.runs.is_empty() or not club._pitch_catalog.is_empty()) \
			and not WorkingPitchCareerProgress.admit(candidate, club):
			_source_owner.notice = "Could not prepare the pitch catalog. Your season is unchanged."
			_source_owner.menu.show_home()
			return
		if (
			working_progression
			and permanent_players
			and not ClubPlayerDraft.apply(candidate, ClubPlayers.owned(club))
		):
			_source_owner.notice = "Could not validate permanent player access. Your season is unchanged."
			_source_owner.menu.show_home()
			return
		if (
			selected_tier > 0
			and not (
				candidate.build.enable_d4_sponsors()
				if selected_tier == 4
				else (
					candidate.build.enable_d3_sponsors()
					if selected_tier == 3
					else candidate.build.enable_d1_pricing()
				)
			)
		):
			_source_owner.notice = (
				"Could not prepare the selected Standard price and sponsor rules. Your season is unchanged."
				if selected_tier >= 3
				else "Could not prepare the shared Standard price rule. Your season is unchanged."
			)
			_source_owner.menu.show_home()
			return
		if working_progression and not club.start(candidate, selected_tier):
			_source_owner.notice = \
				"Could not start another career season. Your season and club history are unchanged."
			_source_owner.menu.show_home()
			return
		if (
			surface_progression
			and working_progression
			and permanent_players
			and home_stadium
			and complete_boundary
			and (previous == null or previous.career == null)
		):
			club._assets = (
				ClubAssetLedger
				. new_club(
					int(club.runs[0].seed),
					ClubPlayers.income(club),
					StadiumCareerProgress.capture(club)
				)
				. to_data()
			)
		candidate.career = club
		if working_progression and permanent_players and home_stadium:
			candidate.home_property = StadiumLayoutSnapshot.capture(
				ClubPlayers.assets(club), complete_boundary
			)
			if candidate.home_property.is_empty():
				_source_owner.notice = "Could not validate the owned home layout. Your season is unchanged."
				_source_owner.menu.show_home()
				return
	if working_progression and permanent_players and home_stadium:
		# The selected Standard tier sets the venue quota, independently of tactical difficulty.
		var venues_ready: Dictionary = SeasonVenues.readiness(selected_tier)
		if not venues_ready.get("ok", false):
			_source_owner.notice = (
				"Could not prepare the selected away parks. Your season is unchanged. "
				+ str(venues_ready.get("error", "Unavailable venue bucket."))
			)
			_source_owner.menu.show_home()
			return
		candidate.npc_venues = SeasonVenues.capture_five(
			candidate.season_seed, candidate.career.current, selected_tier
		)
		if candidate.npc_venues.is_empty():
			_source_owner.notice = "Could not freeze the away venue assignment. Your season is unchanged."
			_source_owner.menu.show_home()
			return
		if not gardens_profile.is_empty():
			candidate.final_venue = SeasonFinalVenue.capture_standard_d4_time(
				candidate, gardens_profile
			)
		else:
			candidate.final_venue = (
				SeasonFinalVenue.capture_standard_d4(candidate)
				if selected_tier == 4
				else (
					SeasonFinalVenue.capture_standard_d3(candidate)
					if selected_tier == 3
					else (
						SeasonFinalVenue.capture_standard_d2(candidate)
						if selected_tier == 2
						else (
							SeasonFinalVenue.capture_standard_d1(candidate)
							if selected_tier == 1
							else SeasonFinalVenue.capture_standard_base(candidate)
						)
					)
				)
			)
		if candidate.final_venue.is_empty():
			_source_owner.notice = "Could not freeze the selected Standard final. Your season is unchanged."
			_source_owner.menu.show_home()
			return
	if not starting_profile.is_empty():
		candidate.owned_surface_night = (
			StadiumSurfaceNightSnapshot.capture_policy(
				candidate, ClubPlayers.assets(candidate.career)
			)
			if (
				starting_profile == "night"
				and StadiumLightingKitNightCandidate.is_candidate_layout(
					candidate.home_property.get("layout")
				)
			)
			else StadiumSurfaceNightSnapshot.capture_time_policy(
				candidate, ClubPlayers.assets(candidate.career), starting_profile
			)
		)
		if (
			not candidate.owned_surface_night.is_empty()
			and StadiumLightingKitNightCandidate.is_candidate_layout(
				candidate.home_property.get("layout")
			)
			and not StadiumLightingKitNightCandidate.renderer_supported(candidate.home_property)
		):
			_source_owner.notice = (
				StadiumLightingKitNightCandidate.renderer_reason(candidate.home_property)
				+ " Your season is unchanged."
			)
			_source_owner.menu.show_home()
			return
		# Unlit Day retains the ordinary day branch. Unsupported dark starts never fall back.
		if candidate.owned_surface_night.is_empty() and starting_profile != "day":
			_source_owner.notice = (
				(
					"This exact kit pattern and rough-dirt composition need reviewed fixed-Night "
					+ "evidence; Sunset is not calibrated. Your season is unchanged."
				)
				if StadiumLightingKitNightCandidate.is_candidate_layout(
					candidate.home_property.get("layout")
				)
				else (
					StadiumStringLightItemsUI.NIGHT_REASON + " Your season is unchanged."
					if not (
						candidate
						. home_property
						. get("layout", {})
						. get("string_lights", [])
						. is_empty()
					)
					else (
						StadiumMountedDisplayItemsUI.NIGHT_REASON + " Your season is unchanged."
						if not (
							candidate
							. home_property
							. get("layout", {})
							. get("mounted_displays", [])
							. is_empty()
						)
						else (
							StadiumPlayerTunnelItemsUI.NIGHT_REASON + " Your season is unchanged."
							if StadiumPlayerTunnelItems.is_family(
								candidate.home_property.get("layout", {})
							)
							else (
								(
									StadiumWallTopTerraceItemsUI.NIGHT_REASON
									+ " Your season is unchanged."
								)
								if StadiumWallTopTerraceItems.is_family(
									candidate.home_property.get("layout", {})
								)
								else (
									(
										StadiumRisingAppleItemsUI.NIGHT_REASON
										+ " Your season is unchanged."
									)
									if StadiumRisingAppleItems.is_family(
										candidate.home_property.get("layout", {})
									)
									else (
										(
											StadiumOutfieldBleacherItemsUI.NIGHT_REASON
											+ " Your season is unchanged."
										)
										if StadiumOutfieldBleacherItems.is_family(
											candidate.home_property.get("layout", {})
										)
										else (
											(
												StadiumLandmarkItemsUI.NIGHT_REASON
												+ " Your season is unchanged."
											)
											if StadiumLandmarkItems.is_family(
												candidate.home_property.get("layout", {})
											)
											else (
												(
													StadiumTreehouseItemsUI.NIGHT_REASON
													+ " Your season is unchanged."
												)
												if StadiumTreehouseItems.is_family(
													candidate.home_property.get("layout", {})
												)
												else (
													(
														StadiumPracticeFacilityItemsUI.NIGHT_REASON
														+ " Your season is unchanged."
													)
													if StadiumPracticeFacilityItems.is_family(
														candidate.home_property.get("layout", {})
													)
													else (
														(
															StadiumGroundBoxItemsUI.NIGHT_REASON
															+ " Your season is unchanged."
														)
														if StadiumGroundBoxItems.is_family(
															candidate.home_property.get(
																"layout", {}
															)
														)
														else (
															(
																(
																	StadiumMoldedSeatItemsUI
																	. NIGHT_REASON
																)
																+ " Your season is unchanged."
															)
															if StadiumMoldedSeatItems.is_family(
																candidate.home_property.get(
																	"layout", {}
																)
															)
															else (
																(
																	(
																		StadiumSmallYardSceneryItemsUI
																		. NIGHT_REASON
																	)
																	+ " Your season is unchanged."
																)
																if (
																	StadiumSmallYardSceneryItems
																	. is_family(
																		candidate.home_property.get(
																			"layout", {}
																		)
																	)
																)
																else (
																	(
																		(
																			StadiumLiveFurnishingItemsUI
																			. NIGHT_REASON
																		)
																		+ " Your season is unchanged."
																	)
																	if (
																		StadiumLiveFurnishingItems
																		. is_family(
																			(
																				candidate
																				. home_property
																				. get("layout", {})
																			)
																		)
																	)
																	else (
																		(
																			(
																				StadiumLandscapeOwnedItemsUI
																				. NIGHT_REASON
																			)
																			+ " Your season is unchanged."
																		)
																		if (
																			StadiumLandscapeOwnedItems
																			. is_family(
																				(
																					candidate
																					. home_property
																					. get(
																						"layout", {}
																					)
																				)
																			)
																		)
																		else (
																			(
																				(
																					StadiumFloodlightOwnedItems
																					. night_reason(
																						(
																							candidate
																							. home_property
																						)
																					)
																				)
																				+ " Your season is unchanged."
																			)
																			if (
																				StadiumFloodlightOwnedItems
																				. is_family(
																					(
																						candidate
																						. home_property
																						. get(
																							"layout",
																							{}
																						)
																					)
																				)
																			)
																			else ("Sunset and Night require the qualified paid four-pole home field. " + \
																				"Your season is unchanged.")
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
			_source_owner.menu.show_home()
			return
	if night_opt_in:
		candidate.owned_surface_night = StadiumSurfaceNightSnapshot.capture_policy(
			candidate, ClubPlayers.assets(candidate.career)
		)
		if (
			not candidate.owned_surface_night.is_empty()
			and StadiumLightingKitNightCandidate.is_candidate_layout(
				candidate.home_property.get("layout")
			)
			and not StadiumLightingKitNightCandidate.renderer_supported(candidate.home_property)
		):
			_source_owner.notice = (
				StadiumLightingKitNightCandidate.renderer_reason(candidate.home_property)
				+ " Your season is unchanged."
			)
			_source_owner.menu.show_home()
			return
		if candidate.owned_surface_night.is_empty():
			_source_owner.notice = (
				(
					"This exact kit pattern and rough-dirt composition need reviewed fixed-Night "
					+ "evidence; Sunset is not calibrated. Your season is unchanged."
				)
				if StadiumLightingKitNightCandidate.is_candidate_layout(
					candidate.home_property.get("layout")
				)
				else (
					StadiumStringLightItemsUI.NIGHT_REASON + " Your season is unchanged."
					if not (
						candidate
						. home_property
						. get("layout", {})
						. get("string_lights", [])
						. is_empty()
					)
					else (
						StadiumMountedDisplayItemsUI.NIGHT_REASON + " Your season is unchanged."
						if not (
							candidate
							. home_property
							. get("layout", {})
							. get("mounted_displays", [])
							. is_empty()
						)
						else (
							StadiumPlayerTunnelItemsUI.NIGHT_REASON + " Your season is unchanged."
							if StadiumPlayerTunnelItems.is_family(
								candidate.home_property.get("layout", {})
							)
							else (
								(
									StadiumWallTopTerraceItemsUI.NIGHT_REASON
									+ " Your season is unchanged."
								)
								if StadiumWallTopTerraceItems.is_family(
									candidate.home_property.get("layout", {})
								)
								else (
									(
										StadiumRisingAppleItemsUI.NIGHT_REASON
										+ " Your season is unchanged."
									)
									if StadiumRisingAppleItems.is_family(
										candidate.home_property.get("layout", {})
									)
									else (
										(
											StadiumOutfieldBleacherItemsUI.NIGHT_REASON
											+ " Your season is unchanged."
										)
										if StadiumOutfieldBleacherItems.is_family(
											candidate.home_property.get("layout", {})
										)
										else (
											(
												StadiumLandmarkItemsUI.NIGHT_REASON
												+ " Your season is unchanged."
											)
											if StadiumLandmarkItems.is_family(
												candidate.home_property.get("layout", {})
											)
											else (
												(
													StadiumTreehouseItemsUI.NIGHT_REASON
													+ " Your season is unchanged."
												)
												if StadiumTreehouseItems.is_family(
													candidate.home_property.get("layout", {})
												)
												else (
													(
														StadiumPracticeFacilityItemsUI.NIGHT_REASON
														+ " Your season is unchanged."
													)
													if StadiumPracticeFacilityItems.is_family(
														candidate.home_property.get("layout", {})
													)
													else (
														(
															StadiumGroundBoxItemsUI.NIGHT_REASON
															+ " Your season is unchanged."
														)
														if StadiumGroundBoxItems.is_family(
															candidate.home_property.get(
																"layout", {}
															)
														)
														else (
															(
																(
																	StadiumMoldedSeatItemsUI
																	. NIGHT_REASON
																)
																+ " Your season is unchanged."
															)
															if StadiumMoldedSeatItems.is_family(
																candidate.home_property.get(
																	"layout", {}
																)
															)
															else (
																(
																	(
																		StadiumSmallYardSceneryItemsUI
																		. NIGHT_REASON
																	)
																	+ " Your season is unchanged."
																)
																if (
																	StadiumSmallYardSceneryItems
																	. is_family(
																		candidate.home_property.get(
																			"layout", {}
																		)
																	)
																)
																else (
																	(
																		(
																			StadiumLiveFurnishingItemsUI
																			. NIGHT_REASON
																		)
																		+ " Your season is unchanged."
																	)
																	if (
																		StadiumLiveFurnishingItems
																		. is_family(
																			(
																				candidate
																				. home_property
																				. get("layout", {})
																			)
																		)
																	)
																	else (
																		(
																			(
																				StadiumLandscapeOwnedItemsUI
																				. NIGHT_REASON
																			)
																			+ " Your season is unchanged."
																		)
																		if (
																			StadiumLandscapeOwnedItems
																			. is_family(
																				(
																					candidate
																					. home_property
																					. get(
																						"layout", {}
																					)
																				)
																			)
																		)
																		else (
																			(
																				(
																					StadiumFloodlightOwnedItems
																					. night_reason(
																						(
																							candidate
																							. home_property
																						)
																					)
																				)
																				+ " Your season is unchanged."
																			)
																			if (
																				StadiumFloodlightOwnedItems
																				. is_family(
																					(
																						candidate
																						. home_property
																						. get(
																							"layout",
																							{}
																						)
																					)
																				)
																			)
																			else ("Night opt-in requires the paid Expanded short-grass/plate-sand " + \
																				"four-pole field. Your season is unchanged.")
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
			_source_owner.menu.show_home()
			return
	_source_owner.season = candidate
	if not _source_owner._checkpoint():
		_source_owner.season = previous
		_source_owner.menu.show_home()
		return
	_source_owner.menu.draft_selection = ""
	_source_owner.film_game = -1
	_source_owner.film_recipe = ""
	_source_owner.copy_game = -1
	_source_owner.copy_receipt = "?"
	_source_owner.insurance_game = -1
	_source_owner.insurance_receipt = ""
	_source_owner.menu.show_draft()
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_choose_player(_source_owner: SeasonApp, id: String) -> void:
	if _source_owner._unsaved_draft != null:
		_source_owner.show_season()
		return
	if _source_owner.season.choose_player(id):
		_source_owner.menu.draft_selection = ""
		if not _source_owner._checkpoint():
			_source_owner._unsaved_draft = _source_owner.season
			_source_owner._guard_draft_quit()
		_source_owner.show_season()
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_show_season(_source_owner: SeasonApp) -> void:
	if _source_owner._unsaved_draft != null:
		_source_owner.menu._show_draft_save_retry()
		return
	if _source_owner.lab == null:
		_source_owner.close_inventory_for_hub()
	if _source_owner.season == null:
		_source_owner.menu.show_home()
	elif _source_owner.season.phase == SeasonState.Phase.DRAFT:
		_source_owner.menu.show_draft()
	else:
		_source_owner.menu.show_hub()
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_retry_draft_save(_source_owner: SeasonApp) -> void:
	_source_owner._prepare_draft_exit()
	_source_owner.show_season()
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_prepare_draft_exit(_source_owner: SeasonApp) -> bool:
	if _source_owner._unsaved_draft == null:
		return true
	if _source_owner.season != _source_owner._unsaved_draft:
		_source_owner.notice = \
			"The unsaved draft owner changed. Leaving is blocked; no save was attempted."
		return false
	if not _source_owner._checkpoint():
		return false
	_source_owner._unsaved_draft = null
	_source_owner._restore_draft_quit_policy()
	return true
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_request_quit(_source_owner: SeasonApp) -> void:
	if not _source_owner._prepare_draft_exit():
		_source_owner.show_season()
		return
	_source_owner.get_tree().quit()
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_notification(_source_owner: SeasonApp, what: int) -> void:
	if what == SeasonApp.NOTIFICATION_WM_CLOSE_REQUEST and _source_owner._unsaved_draft != null:
		_source_owner._request_quit()
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_enter_tree(_source_owner: SeasonApp) -> void:
	if _source_owner._unsaved_draft != null:
		_source_owner._guard_draft_quit()
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_guard_draft_quit(_source_owner: SeasonApp) -> void:
	if _source_owner._draft_quit_tree == _source_owner.get_tree():
		return
	_source_owner._draft_quit_tree = _source_owner.get_tree()
	_source_owner._draft_auto_accept_quit = _source_owner._draft_quit_tree.auto_accept_quit
	_source_owner._draft_quit_tree.auto_accept_quit = false
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_restore_draft_quit_policy(_source_owner: SeasonApp) -> void:
	if is_instance_valid(_source_owner._draft_quit_tree):
		_source_owner._draft_quit_tree.auto_accept_quit = _source_owner._draft_auto_accept_quit
	_source_owner._draft_quit_tree = null
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_play_season_game(_source_owner: SeasonApp) -> void:
	var ac02_token: int = SeasonApp.AC02_PASSIVE_16.enter("season_app.play_season_game")
	_source_owner._ac02_passive_16_play_season_game()
	SeasonApp.AC02_PASSIVE_16.leave(ac02_token)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_ac02_passive_16_play_season_game(_source_owner: SeasonApp) -> void:
	if not WorkingPitchDynastySave.public_playable(_source_owner.season):
		_source_owner.notice = "Recover the exact saved Dynasty owner before playing or changing this roster."
		return
	if SeasonSave.dynasty_owner_bound() and (_source_owner.dynasty_owner == null or not \
		_source_owner.dynasty_owner.playable()):
		_source_owner.notice = "Finish the saved Dynasty choice before playing."
		return
	if (
		_source_owner.lab != null
		or _source_owner.season == null
		or _source_owner.season.pending_fixture().is_empty()
		or (_source_owner.season.physical != null and not \
			_source_owner.season.physical.pending.is_empty())
	):
		return
	if _source_owner.season.build != null and _source_owner.season.build.pack_pending():
		_source_owner.notice = "Choose or skip your open development pack before the next game."
		_source_owner.open_shop()
		return
	# Grant and departure credits commit together with the pregame checkpoint.
	if not SeasonPregameCommit.save(_source_owner):
		_source_owner.menu.show_hub()
		return
	var fixture: Dictionary = _source_owner.season.pending_fixture()
	var field: FieldDefinition = SeasonState.field_for_fixture(fixture, _source_owner.season)
	if field == null:
		_source_owner.notice = "The saved away venue assignment is invalid. Your season is unchanged."
		_source_owner.show_season()
		return
	_source_owner._fixture_id = fixture["id"]
	_source_owner._open_match(_source_owner.season.make_match(), fixture["home"] == 0, true, field.id)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_play_exhibition(_source_owner: SeasonApp) -> void:
	if _source_owner.lab != null:
		return
	_source_owner._open_match(
		MatchLabSupport.create_match(
			PitchBatLab.DEBUG_PLAYER_ID, PitchBatLab.PLAYER_TEAM_NAME, PitchBatLab.RIVAL_TEAM_NAME
		),
		false,
		false
	)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_open_match(_source_owner: SeasonApp,
	state: MatchState,
	player_home: bool,
	season_game: bool,
	field_id: StringName = PitchBatLab.FIELD_ID
) -> void:
	if is_instance_valid(_source_owner.lab) and _source_owner.lab.ac02_startup_pending():
		if _source_owner.lab._ac02_startup_attempt != null:
			_source_owner.lab._ac02_startup_attempt.abort("SeasonApp open reentered")
		return
	var ac02_token: int = SeasonApp.AC02_PASSIVE_16.enter("season_app._open_match")
	_source_owner._ac02_passive_16_private_open_match(state, player_home, season_game, field_id)
	SeasonApp.AC02_PASSIVE_16.leave(ac02_token)
# gdlint: enable=max-returns

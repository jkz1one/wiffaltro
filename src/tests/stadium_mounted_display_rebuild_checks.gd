extends "res://src/tests/stadium_mounted_display_rebuild_checks_fixture_base.gd"
func _md_preview_focus(row: Dictionary) -> void:
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(640, 360)
	preview.build(
		_md_layout, _md_ledger.construction(), true, "mogul", null, null, _md_ledger.surface_owned()
	)
	await get_tree().process_frame
	await get_tree().process_frame
	_md_assert(
		"workshop_build",
		(
			preview.preview_property != null
			and preview.preview_property.props_intact()
			and not preview.night_eligible
		),
		"native Workshop builds current paid assembly in ordinary daylight " + row.copy
	)
	preview.focus_copy(row.copy)
	preview.camera.reset_physics_interpolation()
	preview.camera.force_update_transform()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
	var box: AABB = preview.board_bounds.get(row.copy, AABB())
	var contained: bool = preview.board_bounds.has(row.copy) and rect.has_area()
	var corners: Array[Dictionary] = []
	for index: int in range(8):
		var point: Vector3 = box.get_endpoint(index)
		var projected: Vector2 = preview.camera.unproject_position(point)
		var behind: bool = preview.camera.is_position_behind(point)
		corners.append(
			{"world": _md_v3(point), "pixel": [projected.x, projected.y], "behind": behind}
		)
		contained = contained and not behind and rect.has_point(projected)
	_md_operands = {
		"copy": row.copy,
		"has_bounds": preview.board_bounds.has(row.copy),
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"camera_position": _md_v3(preview.camera.global_position),
		"fov": preview.camera.fov,
		"corners": corners
	}
	_md_assert(
		"workshop_focus",
		contained,
		"native owned-copy focus contains all eight complete reservation corners " + row.copy
	)
	_md_focus.append(
		{
			"copy": row.copy,
			"item": row.item,
			"host": row.host,
			"all_eight_corners_in_frame": contained,
			"night_eligible": preview.night_eligible
		}
	)
	await RenderingServer.frame_post_draw
	preview.queue_free()
	await get_tree().process_frame


func _md_installed() -> void:
	_phase = "ordinary-installed-exact-paid-mounted-displays"
	var root: Node3D = _world()
	var lab: PitchBatLab = PitchBatLab.new()
	root.add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._batter_avatar.set_process(false)
	lab._pitcher_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = _md_snapshot.duplicate(true)
	lab._stadium_ledger = _md_ledger
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	_md_assert(
		"ordinary_install",
		installed,
		"ordinary current paid family38 snapshot installs every exact mounted display"
	)
	if not installed:
		await RenderingServer.frame_post_draw
		await _close_view()
		return
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var boundary: StadiumBoundaryOwnedRuntime = (
		property.get_node_or_null("BoundaryGraph") as StadiumBoundaryOwnedRuntime
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_md_assert(
		"installed_intact",
		(
			boundary != null
			and boundary.intact()
			and property.props_intact()
			and StadiumBoundaryRuntime.installed(lab, _md_snapshot)
		),
		"complete current property and original live boundary identity remain intact"
	)
	_md_assert(
		"no_live_budget",
		(
			property.objects.size() == 14
			and property.route_obstacles().is_empty()
			and lab._primary_fielder.stadium_obstacles.is_empty()
		),
		"seven exact hosts six mounted accessories and one flag add no live fielder budget"
	)
	_md_assert(
		"zero_game",
		(
			PhysicalStadiumContacts.valid([], [], _md_snapshot)
			and lab._play_records.is_empty()
			and lab._batted_ball == null
		),
		"zero-play installation invents no scoring performance or completed-game result"
	)
	if _failures != 0:
		await RenderingServer.frame_post_draw
		await _close_view()
		return
	var checked: Dictionary = _md_validate(_md_layout)
	for row: Dictionary in checked.mounted_display_placements:
		var model: Node3D = property.objects.get(row.copy)
		var host: Node3D = property.objects.get(row.host)
		_md_assert(
			"installed_parents",
			model != null and host != null,
			"both exact paid mount and host have complete ordinary runtime parents " + row.copy
		)
		if model == null or host == null:
			await RenderingServer.frame_post_draw
			await _close_view()
			return
		_md_runtime.append(_md_model_report(lab, property, model, host, row))
		var socket: Dictionary = StadiumMountedDisplayModels.socket(
			row.host_item, row.item, row.host_model
		)
		var support: Dictionary = StadiumMountedDisplayGeometryRebuildChecks.support_report(
			host, model, socket
		)
		_md_operands = support
		_md_assert(
			"installed_support",
			support.get("supported", false),
			"all authored bracket contacts bear on actual named installed host geometry " + row.copy
		)
		_md_support.append(
			{
				"copy": row.copy,
				"host": row.host,
				"item": row.item,
				"socket": row.socket,
				"report": support
			}
		)
		await _md_preview_focus(row)
	await _md_camera_clearance(lab, property, checked.mounted_display_placements)
	await _md_capture_view(root, property, false)
	await _md_capture_view(root, property, true)
	_md_clock_native(lab, property)
	_md_assert(
		"installed_final",
		boundary.intact() and property.props_intact() and lab._play_records.is_empty(),
		"all native mount camera focus and clock checks preserve exact assembly with zero games"
	)
	await RenderingServer.frame_post_draw
	await _close_view()


func _md_apply(layout: Dictionary) -> bool:
	_md_last_draft = {
		"id": "mounted-draft:%d" % _md_ledger.revision(),
		"rev": _md_ledger.revision(),
		"op": "stadium_draft",
		"layout": layout
	}
	var draft: Dictionary = _md_ledger.commit(_md_last_draft)
	if not draft.ok:
		_md_operands = {"stage": "draft", "error": draft.get("error", "")}
		return false
	_md_last_apply = {
		"id": "mounted-apply:%d" % _md_ledger.revision(),
		"rev": _md_ledger.revision(),
		"op": "stadium_apply",
		"layout": layout,
		"geometry": StadiumOwnedLayout.geometry(_md_ledger.view().land, layout)
	}
	var applied: Dictionary = _md_ledger.commit(_md_last_apply)
	_md_operands = {"stage": "apply", "error": applied.get("error", "")}
	return applied.ok


func _md_buy(item: String, quantity: int, version: int, cost: int) -> void:
	if _failures != 0:
		return
	var revision: int = _md_ledger.revision()
	var command: Dictionary = {
		"id": "mounted-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": version,
		"through": _md_credits.size(),
		"progress_through": _md_progress.size()
	}
	var balance: int = _md_ledger.balance()
	var count: int = _md_ledger.construction().copies.size()
	var result: Dictionary = _md_ledger.commit(command)
	_md_copies[item] = []
	var exact: bool = result.ok
	for index: int in range(quantity):
		var copy: String = "purchase:mounted-buy:%d:%d" % [revision, index]
		_md_copies[item].append(copy)
		exact = (
			exact
			and ClubCareer.same(
				_md_ledger.construction().copies.get(copy, {}),
				{
					"item": item,
					"paid": StadiumCatalog.item(item).copy_price,
					"source": "purchase-v1"
				}
			)
		)
	_md_operands = {
		"item": item, "quantity": quantity, "cost": cost, "error": result.get("error", "")
	}
	_md_assert(
		"purchase_charge",
		(
			result.ok
			and _md_ledger.balance() == balance - cost
			and _md_ledger.construction().copies.size() == count + quantity
		),
		"ordinary purchase charges exact unchanged blueprint and copy prices " + item
	)
	_md_assert(
		"purchase_identity",
		exact and _md_ledger.construction().blueprints.has(item),
		"all copies retain exact item price and source " + item
	)
	var before: Dictionary = _md_ledger.to_data().duplicate(true)
	var replay: Dictionary = _md_ledger.commit(command)
	_md_assert(
		"purchase_replay",
		replay.get("replayed", false) and ClubCareer.same(before, _md_ledger.to_data()),
		"immutable purchase retry preserves journal " + item
	)
	_md_receipts.append(
		{
			"item": item,
			"copies": _md_copies[item].duplicate(),
			"quantity": quantity,
			"command_revision": revision,
			"price_version": version,
			"charged": cost,
			"copy_paid": StadiumCatalog.item(item).copy_price,
			"source": "purchase-v1",
			"retry_replayed": replay.get("replayed", false)
		}
	)


func _md_refuse(label: String, layout: Dictionary, stale: bool = false) -> void:
	var before: Dictionary = _md_ledger.to_data().duplicate(true)
	var generation: int = _md_ledger.mutation_generation()
	var result: Dictionary = _md_ledger.commit(
		{
			"id": "mounted-refuse:" + label,
			"rev": _md_ledger.revision() - (1 if stale else 0),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	var unchanged: bool = (
		ClubCareer.same(before, _md_ledger.to_data())
		and generation == _md_ledger.mutation_generation()
	)
	_md_operands = {"case": label, "error": result.get("error", ""), "unchanged": unchanged}
	_md_assert(
		"immutable_refusal",
		not result.ok and unchanged,
		"ordinary draft refuses with complete journal and generation unchanged " + label
	)
	_md_refusals.append(
		{
			"case": label,
			"rejected": not result.ok,
			"unchanged": unchanged,
			"error": result.get("error", "")
		}
	)


func _md_negatives() -> void:
	for wrong: String in ["starter-v1:ST-003", _md_copies["ST-029"][1], "purchase:foreign:0"]:
		var bad: Dictionary = _md_layout.duplicate(true)
		bad.mounted_displays[0].copy = wrong
		_md_assert(
			"wrong_copy",
			not _md_validate(bad).ok,
			"wrong item or unowned identity cannot become a mounted display " + wrong
		)
	for kind: String in [
		"duplicate-copy",
		"unknown-socket",
		"unknown-field",
		"wrong-version",
		"missing-host",
		"non-array",
		"foreign-host",
		"stored-host",
		"wrong-host"
	]:
		var bad: Dictionary = _md_layout.duplicate(true)
		match kind:
			"duplicate-copy":
				bad.mounted_displays.append(bad.mounted_displays[0].duplicate(true))
			"unknown-socket":
				bad.mounted_displays[0].socket = "CURVED-RIBBON"
			"unknown-field":
				bad.mounted_displays[0]["yaw"] = 0
			"wrong-version":
				bad.version = 37
			"missing-host":
				bad.mounted_displays[0].erase("host")
			"non-array":
				bad.mounted_displays = {}
			"foreign-host":
				bad.mounted_displays[0].host = "purchase:foreign:0"
			"stored-host":
				bad.mounted_displays[0].host = _md_copies["ST-030"][1]
			"wrong-host":
				bad.mounted_displays[0].host = _md_copies["ST-035"][0]
		_md_assert(
			"malformed_row",
			not _md_validate(bad).ok,
			"exact bounded placement grammar rejects " + kind
		)
	for version: int in [14, 15]:
		var unsupported: Dictionary = _md_empty.duplicate(true)
		unsupported.version = version
		_md_assert(
			"unsupported_family",
			StadiumMountedDisplayItems.upgrade(unsupported, _md_ledger.surface_owned()).is_empty(),
			"scoreboard family bridge remains explicitly unsupported " + str(version)
		)
	for item: String in ["ST-029", "ST-031"]:
		var removed: Dictionary = _md_host(_md_layout, item, _md_copies[item][0], true)
		_md_refuse("remove-stack-support:" + item, removed)
	_md_refuse("stale-current", _md_layout, true)


func _md_record(label: String, layout: Dictionary) -> void:
	# Warm compact checkpoints do not repeatedly cold-replay the whole journal.
	var checked: Dictionary = _md_validate(layout)
	_md_assert(
		"warm_checkpoint",
		checked.ok and ClubCareer.same(_md_ledger.view().stadium_active, layout),
		"warm exact active layout checkpoint " + label
	)
	_md_lifecycle.append(
		{
			"case": label,
			"revision": _md_ledger.revision(),
			"layout_sha256": JSON.stringify(layout, "", true, true).sha256_text(),
			"mounted_displays": layout.get("mounted_displays", []).duplicate(true),
			"stored": checked.get("stored", []).duplicate(),
			"balance": _md_ledger.balance(),
			"copy_count": _md_ledger.construction().copies.size()
		}
	)


func _md_ownership() -> void:
	_phase = "exact-paid-purchases-store-first-and-one-final-cold-replay"
	for index: int in range(40):
		_md_credits.append(1000)
		_md_progress.append({"seasons": 1, "wins": 5, "strikeouts": 10, "hits": 4})
	_md_assert(
		"synthetic_metrics",
		StadiumCareerProgress.valid(_md_progress, _md_credits),
		"explicit synthetic funding and closed progression are valid without an earned-career claim"
	)
	_md_ledger = ClubAssetLedger.new_club(MD_SEED, _md_credits, _md_progress)
	var starter: Dictionary = StadiumLayoutSnapshot.capture(_md_ledger)
	_md_assert(
		"starter_inventory",
		(
			_md_ledger.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"adoption grants no display or host copies"
	)
	for operand: Dictionary in [
		{"item": "ST-068", "blueprint": 480, "copy": 80, "seasons": 18, "wins": 60},
		{"item": "ST-069", "blueprint": 330, "copy": 90, "seasons": 7, "wins": 20},
		{"item": "ST-070", "blueprint": 300, "copy": 85, "seasons": 6, "wins": 16}
	]:
		var entry: Dictionary = StadiumCatalog.item(operand.item)
		var gate: Dictionary = {"seasons": operand.seasons, "wins": operand.wins}
		_md_assert(
			"catalog_terms",
			(
				entry.blueprint_price == operand.blueprint
				and entry.copy_price == operand.copy
				and ClubCareer.same(entry.requires, gate)
			),
			"unchanged catalog prices and exact unlock operands " + operand.item
		)
		_md_assert(
			"threshold_quote",
			(
				StadiumPurchases
				. quote(_md_ledger.construction(), operand.item, 2, "mounted-gate", 29, gate)
				. ok
			),
			"current29 route accepts exact threshold " + operand.item
		)
		for key: String in gate:
			var below: Dictionary = gate.duplicate(true)
			below[key] -= 1
			_md_assert(
				"below_gate",
				not (
					StadiumPurchases
					. quote(
						_md_ledger.construction(),
						operand.item,
						2,
						"mounted-below:" + key,
						29,
						below
					)
					. ok
				),
				"each just-below unlock operand refuses " + operand.item + ":" + key
			)
		_md_assert(
			"old_price",
			not (
				StadiumPurchases
				. quote(_md_ledger.construction(), operand.item, 2, "mounted-old", 28, gate)
				. ok
			),
			"old28 route cannot grant mounted display " + operand.item
		)
	_md_buy("ST-068", 2, 29, 640)
	_md_buy("ST-069", 2, 29, 510)
	_md_buy("ST-070", 2, 29, 470)
	_md_buy("ST-029", 2, 12, 620)
	_md_buy("ST-030", 2, 12, 900)
	_md_buy("ST-031", 3, 12, 460)
	_md_buy("ST-035", 2, 12, 830)
	_md_buy("ST-039", 2, 3, 540)
	_md_buy("ST-043", 1, 10, 245)
	if _failures != 0:
		return
	_md_assert(
		"paid_inventory",
		(
			_md_ledger.construction().copies.size() == 21
			and StadiumLayoutSnapshot.matches(starter, _md_ledger)
		),
		"nine purchases create exactly18 paid copies preserving starter prefix"
	)
	for tier: String in ["expanded", "club", "mogul"]:
		var result: Dictionary = _md_ledger.commit(
			{
				"id": "mounted-land:" + tier,
				"rev": _md_ledger.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_md_assert(
			"land",
			result.ok and _md_ledger.construction().copies.size() == 21,
			"ordinary land purchase grants no display or host copies " + tier
		)
	if _failures != 0:
		return
	var inherited: Dictionary = StadiumPlayerTunnelItems.upgrade(
		_md_ledger.view().stadium_active, _md_ledger.surface_owned()
	)
	inherited.flags = [{"copy": _md_copies["ST-043"][0], "site": "FLAG-GROUND-L"}]
	_md_assert(
		"inherited_apply",
		_md_validate(inherited).ok and _md_apply(inherited),
		"accepted family37 applies with nonempty paid flag control"
	)
	if _failures != 0:
		return
	_md_prefix = StadiumLayoutSnapshot.capture(_md_ledger)
	_md_empty = StadiumMountedDisplayItems.upgrade(inherited, _md_ledger.surface_owned())
	_md_assert(
		"upgrade",
		(
			_md_empty.get("version", -1) == 38
			and _md_empty.get("mounted_displays") is Array
			and _md_empty.mounted_displays.is_empty()
			and ClubCareer.same(StadiumMountedDisplayItems.base(_md_empty), inherited)
			and _md_apply(_md_empty)
		),
		"empty family38 preserves every inherited channel"
	)
	if _failures != 0:
		return
	_md_record("empty-family38", _md_empty)
	_md_hosts = _md_empty.duplicate(true)
	for item: String in ["ST-029", "ST-031", "ST-030", "ST-035", "ST-039"]:
		_md_hosts = _md_host(_md_hosts, item, _md_copies[item][0])
		_md_assert(
			"host_assembly",
			_md_validate(_md_hosts).ok,
			"exact separately paid host/support installs " + item
		)
		if _failures != 0:
			return
	for item: String in ["ST-029", "ST-031"]:
		_md_hosts = _md_host(_md_hosts, item, _md_copies[item][1], false, "BASE-R1", 1)
		_md_assert(
			"host_assembly",
			_md_validate(_md_hosts).ok,
			"separate right-side concourse host installs " + item
		)
		if _failures != 0:
			return
	_md_assert(
		"hosts_apply", _md_apply(_md_hosts), "all current supported exact host parents coexist"
	)
	_mounted_display_paid_purchase_checks(inherited)


func _mounted_display_paid_purchase_checks(inherited: Dictionary) -> void:
	if _failures != 0:
		return
	var balance: int = _md_ledger.balance()
	for route: Dictionary in MD_ROUTES:
		var label: String = route.case
		var copy: String = _md_copies[route.item][route.index]
		var host: String = _md_copies[route.host_item][route.host_index]
		_md_assert(
			"bare_host_refusal",
			ClubCareer.same(_md_place(_md_empty, route), _md_empty),
			"paid accessory cannot fabricate its missing host " + label
		)
		var mounted: Dictionary = _md_place(_md_hosts, route)
		_md_assert(
			"mount_apply",
			(
				_md_validate(mounted).ok
				and (
					mounted.mounted_displays
					== [{"copy": copy, "host": host, "socket": route.socket}]
				)
				and _md_apply(mounted)
			),
			"named socket binds the exact separately paid host identity " + label
		)
		if _failures != 0:
			return
		_md_record("mounted:" + label, mounted)
		_md_assert(
			"same_select",
			ClubCareer.same(_md_place(mounted, route), mounted),
			"same exact mounted row reselect is idempotent " + label
		)
		var missing: Dictionary = _md_host(
			mounted, route.host_item, host, true, route.host_site, route.support_index
		)
		_md_assert(
			"host_row_preserved",
			(
				ClubCareer.same(missing.mounted_displays, mounted.mounted_displays)
				and not _md_validate(missing).ok
			),
			"host-first removal leaves exact attachment row and refuses " + label
		)
		_md_refuse("remove-host:" + label, missing)
		var changed: Dictionary = _md_host(
			mounted,
			route.host_item,
			_md_copies[route.host_item][route.spare_index],
			false,
			route.host_site,
			route.support_index
		)
		_md_refuse("replace-host:" + label, changed)
		var simultaneous: Dictionary = StadiumMountedDisplayItems.store_copy(missing, copy)
		_md_refuse("simultaneous-host-and-mount:" + label, simultaneous)
		var rebound: Dictionary = _md_place(
			StadiumMountedDisplayItems.store_copy(changed, copy), route, route.spare_index
		)
		_md_refuse("silent-rebind:" + label, rebound)
		var stored: Dictionary = StadiumMountedDisplayItems.store_copy(mounted, copy)
		_md_assert(
			"store_apply",
			(
				ClubCareer.same(stored, _md_hosts)
				and _md_validate(stored).stored.has(copy)
				and _md_apply(stored)
			),
			"explicit saved Store preserves hosts and every unrelated channel " + label
		)
		_md_record("stored:" + label, stored)
		var removed: Dictionary = _md_host(
			stored, route.host_item, host, true, route.host_site, route.support_index
		)
		_md_assert(
			"store_first_remove",
			_md_validate(removed).ok and _md_apply(removed),
			"host removal succeeds after separate saved accessory Store " + label
		)
		var restored: Dictionary = _md_host(
			removed, route.host_item, host, false, route.host_site, route.support_index
		)
		_md_assert(
			"restore_host",
			(
				ClubCareer.same(restored, _md_hosts)
				and restored.mounted_displays.is_empty()
				and _md_apply(restored)
			),
			"host restoration never remounts stored display implicitly " + label
		)
		_md_assert(
			"remount",
			ClubCareer.same(_md_place(restored, route), mounted) and _md_apply(mounted),
			"same paid copy explicitly remounts onto exact restored host " + label
		)
		_md_assert(
			"lifecycle_free",
			(
				_md_apply(_md_hosts)
				and _md_ledger.balance() == balance
				and _md_ledger.construction().copies.size() == 21
			),
			"bounded lifecycle creates no copies charges or refunds " + label
		)
		if _failures != 0:
			return
	_md_layout = _md_hosts.duplicate(true)
	for route: Dictionary in MD_ROUTES:
		_md_layout = _md_place(_md_layout, route)
	_md_assert(
		"combined_apply",
		(
			_md_validate(_md_layout).ok
			and _md_layout.mounted_displays.size() == MD_ROUTES.size()
			and _md_apply(_md_layout)
		),
		"all separately paid mounted displays coexist on their exact hosts"
	)
	if _failures != 0:
		return
	_md_record("current-combined", _md_layout)
	_md_negatives()
	var retry: Dictionary = _md_ledger.to_data().duplicate(true)
	_md_assert(
		"draft_apply_retry",
		(
			_md_ledger.commit(_md_last_draft).get("replayed", false)
			and _md_ledger.commit(_md_last_apply).get("replayed", false)
			and ClubCareer.same(retry, _md_ledger.to_data())
		),
		"exact draft and apply retries preserve journal"
	)
	_md_snapshot = StadiumLayoutSnapshot.capture(_md_ledger)
	_md_assert(
		"snapshot",
		(
			not _md_snapshot.is_empty()
			and StadiumLayoutSnapshot.matches(_md_snapshot, _md_ledger)
			and ClubCareer.same(_md_snapshot.layout, _md_layout)
		),
		"complete final paid snapshot authenticates the exact current layout"
	)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_md_ledger.to_data(), "", true, true)),
		MD_SEED,
		_md_credits,
		_md_progress
	)
	_md_assert(
		"strict_cold",
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _md_ledger.to_data())
			and _md_ledger.to_data().version == 46
			and StadiumLayoutSnapshot.matches(_md_prefix, cold)
			and StadiumLayoutSnapshot.matches(_md_snapshot, cold)
		),
		"one final strict ledger46 cold replay preserves old family37 prefix and exact current snapshot"
	)
	_md_assert(
		"final_inventory",
		(
			_md_ledger.balance() == balance
			and _md_ledger.construction().copies.size() == 21
			and ClubCareer.same(_md_layout.flags, inherited.flags)
		),
		"cold lifecycle preserves all paid copies and nonempty unrelated flag"
	)


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_md_assert(
		"native_entry",
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"rendered mounted display qualification has an explicit output directory"
	)
	if _failures == 0:
		_md_assert(
			"directory",
			DirAccess.make_dir_recursive_absolute(directory) == OK,
			"capture directory opens"
		)
	if _failures == 0:
		var before: int = _checks
		_md_ownership()
		_md_phase_counts.ownership = _checks - before
	if _failures == 0:
		var before: int = _checks
		_md_fit_checks()
		_md_phase_counts.fit = _checks - before
	if _failures == 0:
		var before: int = _checks
		_md_clock_math()
		_md_phase_counts.clock_math = _checks - before
	if _failures == 0:
		_phase = "complete-source-models-and-named-sockets"
		var root: Node3D = _world()
		var before: int = _checks
		_md_geometry = await StadiumMountedDisplayGeometryRebuildChecks.run(root, _check)
		_md_model_checks = _checks - before
		_md_assert(
			"geometry_count",
			_md_model_checks == StadiumMountedDisplayGeometryRebuildChecks.expected_checks(),
			"all bounded detailed model assertions are reached"
		)
		await RenderingServer.frame_post_draw
		await _close_view()
	if _failures == 0:
		var before: int = _checks
		await _md_installed()
		_md_phase_counts.runtime_and_views = _checks - before
	_phase = "completion"
	_md_assert(
		"images",
		_images == ["mounted-display-overview.png", "mounted-display-details.png"],
		"exactly two original native1280x720 images and zero completed games"
	)
	var payload: Dictionary = {
		"checks": _checks,
		"expected_checks": MD_EXPECTED_CHECKS,
		"failures": _failures,
		"images": _images,
		"games": 0,
		"synthetic_funding": true,
		"synthetic_progression": true,
		"earned_career_claim": false,
		"live_game_claim": false,
		"whole_game_acceptance_claim": false,
		"final_art_acceptance_claim": false,
		"physical_performance_claim": false,
		"audio_implementation_claim": false,
		"gameplay_bonus_claim": false,
		"night_qualification_claim": false,
		"curved_ribbon_claim": false,
		"scoreboard_family_bridge_claim": false,
		"model_checks": _md_model_checks,
		"model_expected_checks": StadiumMountedDisplayGeometryRebuildChecks.expected_checks(),
		"phase_checks": _md_phase_counts,
		"assertion_hits": _md_hits,
		"paid_copy_ids": _md_copies,
		"paid_inventory": _md_ledger.construction().to_data() if _md_ledger != null else {},
		"purchase_receipts": _md_receipts,
		"layout": _md_layout,
		"snapshot": _md_snapshot,
		"lifecycle": _md_lifecycle,
		"ownership_refusals": _md_refusals,
		"fit_cases": _md_fit,
		"geometry": _md_geometry,
		"runtime": _md_runtime,
		"support_cases": _md_support,
		"camera_cases": _md_cameras,
		"focus_cases": _md_focus,
		"capture_views": _md_views,
		"clock": _md_clock,
		"synthetic_metrics": StadiumCareerProgress.metrics(_md_progress, _md_progress.size()),
		"capture_scope":
		(
			"Separately paid mounted displays on exact current-family hosts; unsupported "
			+ "scoreboard14/15 bridge excluded."
		)
	}
	_md_assert(
		"evidence_cap",
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined evidence remains within128KiB"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("mounted-display-rebuild.json"), FileAccess.WRITE
	)
	_md_assert("evidence_open", file != null, "combined evidence opens")
	var preceding_hits: Dictionary = MD_EXPECTED_HITS.duplicate(true)
	preceding_hits.erase("exact_count")
	_md_assert(
		"exact_count",
		_checks + 1 == MD_EXPECTED_CHECKS and ClubCareer.same(_md_hits, preceding_hits),
		"every source-frozen bounded assertion is reached exactly"
	)
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		payload.assertion_hits = _md_hits
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "combined evidence fully writes")
		file.close()
	print(
		(
			(
				"MOUNTED_DISPLAY_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true synthetic_progression=true"
			)
			% [_checks, _failures, _md_model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}

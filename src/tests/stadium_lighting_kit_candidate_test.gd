extends Node
const CANDIDATE = preload("res://src/gameplay/stadium/stadium_lighting_kit_night_candidate.gd")
const PALETTE = preload("res://src/presentation/stadium/stadium_lighting_kit_night_palette.gd")
var checks: int = 0
var failures: Array[String] = []
var compositions: Dictionary = {}


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
	return ok


func _ready() -> void:
	_historical()
	_palette()
	_check(
		CANDIDATE.capture(null).is_empty() and not CANDIDATE.valid({}, null),
		"null ledger never produces candidate"
	)
	_check(
		not CANDIDATE.PUBLIC_READY and not CANDIDATE.RUNTIME_READY,
		"isolated readiness flags remain false"
	)
	for pattern: String in StadiumLightingKitItems.PATTERNS:
		_case(pattern)
	_historical()
	print(
		"KIT_CANDIDATE_RESULT ",
		JSON.stringify(
			{
				"checks": checks,
				"failures": failures,
				"candidate3": CANDIDATE.signature(),
				"palettes": PALETTE.signatures(),
				"compositions": compositions,
				"engine": Engine.get_version_info().string,
				"night_qualified": false,
				"production_writes": false,
				"evidence_unit_fixtures_are_synthetic": true
			}
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _historical() -> void:
	_check(
		(
			StadiumSurfaceNightLayout.signature()
			== "7a796ab1fface3e5952b97422b7b4052968c157d7c1840c1a6176c5e55e03952"
		),
		"candidate1 hash unchanged"
	)
	_check(
		(
			StadiumSurfaceNightLayout.floodlight_signature()
			== "9509c245db79f7cce61a646a6eb6ebbb809f55e795b3af1bfabaaf49b1cdb2e3"
		),
		"candidate2 hash unchanged"
	)
	_check(
		(
			StadiumSurfaceNightSnapshot.signature()
			== "149123bd7faff57f9d04e77071d117a74e9fb8d1b8b73d3840f32088a53b227d"
		),
		"fixture26 base unchanged"
	)
	_check(
		(
			StadiumSurfaceNightSnapshot.time_signature()
			== "178a407284dde8451423da5f711798cbb15ec3767b6ebb4554597cf637625cfe"
		),
		"fixture27 clock/base unchanged"
	)


func _ledger(pattern: String, tag: String = "candidate") -> ClubAssetLedger:
	var paid: ClubAssetLedger = ClubAssetLedger.new(
		163,
		[10000, 10000, 10000],
		[{"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}]
	)
	var buy: Dictionary = paid.commit(
		{
			"id": tag + "-kit",
			"rev": paid.revision(),
			"op": "stadium_buy",
			"through": 3,
			"progress_through": 3,
			"price_version": 33,
			"item": "ST-111",
			"quantity": 1
		}
	)
	if not _check(buy.ok, pattern + " paid kit purchase"):
		return null
	var layout: Dictionary = StadiumLightingKitItems.place(
		paid.view().stadium_draft, paid.construction(), "purchase:" + tag + "-kit:0", pattern
	)
	if pattern == "MIXED_EDGE":
		var poles: Dictionary = paid.commit(
			{
				"id": tag + "-poles",
				"rev": paid.revision(),
				"op": "stadium_buy",
				"through": 3,
				"progress_through": 3,
				"price_version": 7,
				"item": "ST-037",
				"quantity": 2
			}
		)
		if not _check(poles.ok, "mixed independent paid poles"):
			return null
		layout.lights = [
			{"copy": "purchase:" + tag + "-poles:0", "site": "YLIGHT-RL"},
			{"copy": "purchase:" + tag + "-poles:1", "site": "YLIGHT-RR"}
		]
	if not _apply(paid, layout, tag):
		return null
	return paid


func _apply(paid: ClubAssetLedger, layout: Dictionary, tag: String) -> bool:
	var drafted: Dictionary = paid.commit(
		{"id": tag + "-draft", "rev": paid.revision(), "op": "stadium_draft", "layout": layout}
	)
	var applied: Dictionary = (
		paid.commit(
			{
				"id": tag + "-apply",
				"rev": paid.revision(),
				"op": "stadium_apply",
				"layout": layout,
				"geometry": StadiumHomeLayout.geometry("backyard", layout)
			}
		)
		if drafted.ok
		else drafted
	)
	return _check(drafted.ok and applied.ok, tag + " atomic paid draft/apply")


func _case(pattern: String) -> void:
	var paid: ClubAssetLedger = _ledger(pattern)
	if paid == null:
		return
	var before: String = JSON.stringify(paid.to_data(), "", true, true)
	var candidate: Dictionary = CANDIDATE.capture(paid)
	if not _check(not candidate.is_empty(), pattern + " structural candidate capture"):
		return
	_check(
		CANDIDATE.candidate_shape(candidate) and CANDIDATE.valid(candidate, paid),
		pattern + " exact paid candidate valid"
	)
	_check(
		CANDIDATE.candidate_shape(JSON.parse_string(JSON.stringify(candidate))),
		pattern + " candidate JSON roundtrip"
	)
	var profile: Dictionary = CANDIDATE.structural_profile(candidate.entry)
	compositions[pattern] = profile.composition_key
	_check(
		(
			profile.pattern == pattern
			and profile.composition.source_count == (5 if pattern == "MIXED_EDGE" else 3)
		),
		pattern + " independent pattern composition"
	)
	_check(
		CANDIDATE.admission_profile(candidate.entry).is_empty(),
		pattern + " structural evidence never grants Night"
	)
	_check(
		(
			ClubCareer.same(StadiumSurfaceNightLayout.capture(paid), candidate)
			and StadiumSurfaceNightLayout.candidate_shape(candidate)
		),
		pattern + " dedicated structural dispatch keeps candidate3 separate from historical routes"
	)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(candidate.entry, 163, 0)
	_check(
		environment.mode == "day" and environment.profile == "",
		pattern + " ordinary fixture stays Day"
	)
	_check(
		JSON.stringify(paid.to_data(), "", true, true) == before,
		pattern + " structural APIs never mutate paid ledger"
	)
	var changed: Dictionary = candidate.duplicate(true)
	changed.contract = "0".repeat(64)
	_check(not CANDIDATE.candidate_shape(changed), pattern + " stale contract rejected")
	changed = candidate.duplicate(true)
	changed.entry.geometry = "0".repeat(64)
	_check(not CANDIDATE.candidate_shape(changed), pattern + " stale geometry rejected")
	changed = candidate.duplicate(true)
	changed.entry.layout.lighting_kits[0].copy = "foreign:copy"
	_check(not CANDIDATE.valid(changed, paid), pattern + " foreign kit copy rejected")
	changed = candidate.duplicate(true)
	changed.entry.layout.surface.condition = "prepared"
	_check(
		CANDIDATE.structural_profile(changed.entry).is_empty(),
		pattern + " unmeasured surface composition rejected"
	)
	changed = candidate.duplicate(true)
	changed.entry.tier = "expanded"
	_check(
		CANDIDATE.structural_profile(changed.entry).is_empty(),
		pattern + " unmeasured tier rejected"
	)
	var other: ClubAssetLedger = _ledger(pattern, "foreign")
	_check(
		other != null and not CANDIDATE.valid(candidate, other),
		pattern + " other paid-copy journal cannot authorize candidate"
	)
	for palette_profile: String in PALETTE.PROFILES:
		_installation(candidate, paid, palette_profile)
	var manifest: Dictionary = _synthetic_manifest(candidate.entry)
	_check(
		CANDIDATE.evidence_shape(manifest, candidate.entry),
		pattern + " synthetic evidence shape unit fixture only"
	)
	_check(
		(
			CANDIDATE.evidence_digest(manifest)
			== CANDIDATE.evidence_digest(JSON.parse_string(JSON.stringify(manifest)))
		),
		pattern + " immutable registry digest survives JSON numeric roundtrip"
	)
	_check(
		CANDIDATE.admission_profile(candidate.entry).is_empty(),
		pattern + " shape-valid unregistered synthetic evidence cannot authorize Night"
	)
	manifest.pattern = "MIXED_EDGE" if pattern != "MIXED_EDGE" else "PARALLEL"
	_check(
		not CANDIDATE.evidence_shape(manifest, candidate.entry),
		pattern + " foreign pattern evidence rejected"
	)
	manifest = _synthetic_manifest(candidate.entry)
	manifest.palette = "0".repeat(64)
	_check(
		not CANDIDATE.evidence_shape(manifest, candidate.entry),
		pattern + " stale palette evidence rejected"
	)
	manifest = _synthetic_manifest(candidate.entry)
	manifest.checks.actual_bat_contact = false
	_check(
		not CANDIDATE.evidence_shape(manifest, candidate.entry),
		pattern + " incomplete gameplay evidence rejected"
	)
	manifest = _synthetic_manifest(candidate.entry)
	manifest.artifacts.optics = ""
	_check(
		not CANDIDATE.evidence_shape(manifest, candidate.entry),
		pattern + " missing evidence digest rejected"
	)
	if pattern == "MIXED_EDGE":
		changed = candidate.duplicate(true)
		changed.entry.layout.lights.pop_back()
		_check(
			CANDIDATE.structural_profile(changed.entry).is_empty(),
			"mixed missing separately owned rear pole rejected"
		)
		changed = candidate.duplicate(true)
		changed.entry.layout.lights[0].site = "YLIGHT-FL"
		_check(
			CANDIDATE.structural_profile(changed.entry).is_empty(), "mixed wrong pole site rejected"
		)
	else:
		var next_pattern: String = "ZIGZAG" if pattern == "PARALLEL" else "PARALLEL"
		var next_layout: Dictionary = StadiumLightingKitItems.place(
			paid.view().stadium_active, paid.construction(), profile.kit_copy, next_pattern
		)
		if _apply(paid, next_layout, "switch"):
			_check(
				CANDIDATE.valid(candidate, paid),
				pattern + " retained paid prefix remains valid after free pattern switch"
			)
			var newer: Dictionary = CANDIDATE.capture(paid)
			_check(
				(
					not newer.is_empty()
					and newer.entry.layout.lighting_kits[0].site == next_pattern
					and newer != candidate
				),
				pattern + " free pattern switch freezes a different candidate"
			)
			_check(
				not CANDIDATE.evidence_shape(_synthetic_manifest(candidate.entry), newer.entry),
				pattern + " previous pattern evidence does not transfer"
			)


func _synthetic_manifest(entry: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"version": 1,
		"family": CANDIDATE.EVIDENCE_FAMILY,
		"candidate": CANDIDATE.signature(),
		"model": StadiumLightingKitModels.signature(),
		"palette": PALETTE.signature(),
		"palette_profile": PALETTE.BASELINE,
		"composition": CANDIDATE.structural_profile(entry).composition_key,
		"pattern": entry.layout.lighting_kits[0].site,
		"engine": "synthetic-unit-fixture-not-real-QA",
		"renderer": "mobile",
		"viewport": [1280, 720],
		"checks": {},
		"artifacts": {},
		"review_status": "reviewed-pass"
	}
	for field: String in CANDIDATE.REQUIRED_CHECKS:
		result.checks[field] = true
	for field: String in CANDIDATE.ARTIFACTS:
		result.artifacts[field] = ("SYNTHETIC-UNIT-TEST-" + field).sha256_text()
	return result


func _palette() -> void:
	_check(
		(
			(
				PALETTE.signature("BASE2048")
				== "f7bd91b00aa7fe81ae8c0d964bb4d1b77855ae783172dfea0fafa33f80bd0048"
			)
			and (
				PALETTE.signature("ATLAS4096")
				== "0ee1b864eddd163ff60600bc7bc86ba8883b5d7486687b464431b4eb0698a860"
			)
			and (
				PALETTE.signature("ATLAS4096_KITBIAS2")
				== "05e4b92686fdaa8dbea2ba6aa524918570bd23e6ba9badf1c4c0ac33728205e7"
			)
		),
		"all three historical palette hashes unchanged"
	)
	var first: Environment = PALETTE.environment()
	var second: Environment = PALETTE.environment()
	_check(
		first != second and StadiumLightingKitModels._resource_matches(first, second),
		"palette creates exact distinct canonical resources"
	)
	_check(
		(
			first.sky == null
			and first.background_mode == Environment.BG_COLOR
			and first.tonemap_exposure == 1.0
			and not first.fog_enabled
			and not first.glow_enabled
		),
		"palette owns sky/exposure/effects without Expanded ground dependency"
	)
	first.tonemap_exposure = 1.1
	_check(
		not StadiumLightingKitModels._resource_matches(first, second),
		"presentation field mutation detectable"
	)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.emission = Color("ffdc98")
	material.emission_energy_multiplier = 0
	var clone: StandardMaterial3D = PALETTE.lens(material)
	_check(
		(
			clone != material
			and clone.emission_enabled
			and is_equal_approx(clone.emission_energy_multiplier, 0.8)
			and clone.emission == material.emission
			and not material.emission_enabled
			and material.emission_energy_multiplier == 0
		),
		"lens clone preserves dormant source and disabled authored color"
	)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	_check(PALETTE.sun_geometry_valid(sun), "exact starter sun orientation accepted")
	sun.rotation_degrees.y += 1
	_check(not PALETTE.sun_geometry_valid(sun), "changed starter sun orientation rejected")
	sun.free()
	_check(
		(
			PALETTE.shadows().quadrants.size() == 4
			and PALETTE.shadows().quadrants[0] == Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
		),
		"explicit atlas supports five-source mixed rig"
	)


func _installation(candidate: Dictionary, paid: ClubAssetLedger, palette_profile: String) -> void:
	var pattern: String = candidate.entry.layout.lighting_kits[0].site
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab._sounds.set_muted(true)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._at_bat_cadence.stop()
	lab._match_state.stadium = candidate.entry.duplicate(true)
	lab._stadium_ledger = paid
	if not _check(
		StadiumPropertyRuntime.install_bound(lab),
		pattern + " actual paid sparse property installation"
	):
		lab.free()
		return
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var profile: Dictionary = CANDIDATE.structural_profile(candidate.entry)
	var kit: Node3D = property.objects[profile.kit_copy]
	var rear: Array[Node3D] = []
	for row: Dictionary in profile.rear_poles:
		rear.append(property.objects[row.copy])
	var environment: Environment = lab._world_environment.environment
	var sun: DirectionalLight3D = lab.get_node("StarterFieldGeometry/Sun")
	var energy: float = sun.light_energy
	var original_kit_bias: float = kit.get_node("Sources/Span00Source").shadow_normal_bias
	var lease: StadiumLightingKitPreviewRuntime = StadiumLightingKitPreviewRuntime.install(
		property, lab._world_environment, sun, kit, rear, palette_profile
	)
	if not _check(lease != null, pattern + " dedicated palette installs without plate-sand mesh"):
		lab.free()
		return
	lease.set_process(false)
	var row_count: int = lease._changes.size()
	_check(
		(
			not lease._change(lease.sources[0], &"visible", true, true)
			and lease._changes.size() == row_count
		),
		pattern + " duplicate indexed operand rejected without mutation"
	)
	var original_shadow_flags: Array[bool] = []
	for source: SpotLight3D in lease.sources:
		original_shadow_flags.append(source.shadow_enabled)
	_check(
		lease.set_night(true) and lease.intact() and property.props_intact(),
		pattern + " dedicated active palette preserves exact property seal"
	)
	_check(
		(
			lab._world_environment.environment != environment
			and StadiumLightingKitModels._resource_matches(
				lab._world_environment.environment, PALETTE.environment()
			)
		),
		pattern + " exact canonical active palette, original Day resource untouched"
	)
	_check(
		(
			lab.get_viewport().positional_shadow_atlas_size
			== (2048 if palette_profile in [PALETTE.BASELINE, "KIT_FILL2048"] else 4096)
		),
		pattern + " exact named atlas profile " + palette_profile
	)
	_check(
		(
			lease.sources[0].shadow_normal_bias
			== (2.0 if palette_profile == "ATLAS4096_KITBIAS2" else original_kit_bias)
		),
		pattern + " exact kit-only bias profile " + palette_profile
	)
	if palette_profile == "ATLAS4096_KITBIAS2":
		_check(
			lease.allows_change(lease.sources[0], &"shadow_normal_bias", original_kit_bias, 2.0),
			pattern + " exact scalar lease recognized"
		)
		_check(
			not lease.allows_change(lease.sources[0], &"shadow_bias", 0.05, 2.0),
			pattern + " arbitrary source scalar remains forbidden"
		)
		for pole: Node3D in rear:
			_check(
				not lease.allows_change(
					pole.get_node("FieldLight"), &"shadow_normal_bias", 2.0, 2.0
				),
				"legacy pole never receives kit scalar exception"
			)
	for source_index in range(lease.sources.size()):
		var source: SpotLight3D = lease.sources[source_index]
		_check(
			(
				source.shadow_enabled
				== (
					false
					if palette_profile == "KIT_FILL2048" and source_index < 3
					else original_shadow_flags[source_index]
				)
			),
			pattern + " exact source shadow scope " + palette_profile
		)
	_check(sun.shadow_enabled, pattern + " directional sun shadows remain unchanged")
	if palette_profile == "KIT_FILL2048":
		_check(
			lease.allows_change(lease.sources[0], &"shadow_enabled", true, false),
			pattern + " exact kit shadow-fill lease recognized"
		)
		_check(
			(
				not lease.allows_change(
					lease.sources[0], &"light_energy", lease.sources[0].light_energy, 0.0
				)
				and not lease.allows_change(
					lease.sources[0], &"shadow_normal_bias", original_kit_bias, 2.0
				)
			),
			pattern + " fill cannot borrow arbitrary energy or bias lease"
		)
		for pole: Node3D in rear:
			_check(
				not lease.allows_change(
					pole.get_node("FieldLight"), &"shadow_enabled", true, false
				),
				"legacy rear shadow exception forbidden"
			)
		lease.sources[0].shadow_enabled = true
		_check(
			not lease.intact() and not property.props_intact(),
			pattern + " same-frame kit shadow mutation rejected"
		)
		lease.sources[0].shadow_enabled = false
		_check(
			lease.intact() and property.props_intact(),
			pattern + " exact fill shadow expectation restored"
		)
		sun.shadow_enabled = false
		_check(not lease.intact(), pattern + " fill does not authorize directional shadow changes")
		sun.shadow_enabled = true
		for pole: Node3D in rear:
			pole.get_node("FieldLight").shadow_enabled = false
			_check(
				not lease.intact() and not property.props_intact(),
				"fill does not authorize rear-pole shadow change"
			)
			pole.get_node("FieldLight").shadow_enabled = true
	else:
		_check(
			not lease.allows_change(lease.sources[0], &"shadow_enabled", true, false),
			pattern + " prior palette cannot borrow new fill exception"
		)
	var saved_profile: String = lease._palette_profile
	lease._palette_profile = "ATLAS4096" if saved_profile != "ATLAS4096" else "BASE2048"
	_check(not lease.intact(), pattern + " palette profile mutation invalidates lease")
	lease._palette_profile = saved_profile
	_check(lease.intact(), pattern + " exact palette profile restoration passes")
	var original_bias: float = lease.sources[0].shadow_normal_bias
	lease.sources[0].shadow_normal_bias += 0.1
	_check(
		not lease.intact() and not property.props_intact(),
		pattern + " source shadow change cannot borrow visibility lease"
	)
	lease.sources[0].shadow_normal_bias = original_bias
	_check(lease.intact(), pattern + " exact shadow source restoration accepted")
	lease.restore()
	for source_index in range(lease.sources.size()):
		_check(
			lease.sources[source_index].shadow_enabled == original_shadow_flags[source_index],
			pattern + " exact dormant source shadow restoration " + palette_profile
		)
	_check(
		lease.sources[0].shadow_normal_bias == original_kit_bias,
		pattern + " source scalar restored exactly " + palette_profile
	)
	_check(
		(
			lab._world_environment.environment == environment
			and sun.light_energy == energy
			and property.props_intact()
			and StadiumLightingKitModels.valid(kit)
		),
		pattern + " palette teardown restores actual incoming identities and dormant Day state"
	)
	lab.free()

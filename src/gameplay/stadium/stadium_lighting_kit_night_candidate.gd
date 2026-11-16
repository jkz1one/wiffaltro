class_name StadiumLightingKitNightCandidate
extends RefCounted
## Structural candidate3 only. Neither paid ownership nor a shape-valid evidence document grants
## Night.
const PALETTE = preload("res://src/presentation/stadium/stadium_lighting_kit_night_palette.gd")
const CANDIDATE_VERSION: int = 3
const MUTATION_CONTRACT: String = "issued-immutable-receipt-supported-api-deep-transitions-v2"
const FAMILY: String = "owned-lighting-kit-night-candidate-v3"
const EVIDENCE_VERSION: int = 1
const EVIDENCE_FAMILY: String = "st111-rendered-readability-evidence-v1"
const RUNTIME_READY: bool = false
const PUBLIC_READY: bool = false
# Promotion is a reviewed source change, never a user-data/save field or arbitrary caller argument.
# Key = composition_key; value = {digest: sha256(canonical manifest), manifest: exact reviewed
# record}.
const QUALIFIED_MANIFESTS: String = "{}"  # Immutable source text, never a mutable trust dictionary.
const REQUIRED_CHECKS: Array[String] = [
	"rendered_motion",
	"actual_bat_contact",
	"ordinary_defense",
	"ground_and_sky_contrast",
	"camera_occlusion",
	"source_off_control",
	"ordinary_guard_performance",
	"mutation_guards",
	"fixture_replay",
	"restoration"
]
const ARTIFACTS: Array[String] = ["capture", "motion", "optics", "performance", "runtime"]
const DEFAULT_SURFACE: Dictionary = {"foundation": "dirt", "condition": "rough", "height": "short"}


static func signature() -> String:
	return (
		_data(
			{
				"candidate_version": CANDIDATE_VERSION,
				"family": FAMILY,
				"entry_version": 8,
				"layout_version": 43,
				"items": StadiumLightingKitItems.signature(),
				"model": StadiumLightingKitModels.signature(),
				"palettes": PALETTE.signatures(),
				"tier": "backyard",
				"surface": DEFAULT_SURFACE,
				"styles": {"grass": "", "line": ""},
				"ground": "",
				"boundary": _reference_boundary().signature(),
				"patterns": StadiumLightingKitItems.PATTERNS,
				"kit_count": 1,
				"mixed_rear_sites": ["YLIGHT-RL", "YLIGHT-RR"],
				"rear_model": StadiumYardLightModels.VERSION,
				"unrelated_placements": false,
				"runtime": "owned-st111-fixed-night-issued-v3",
				"mutation_contract": MUTATION_CONTRACT,
				"issuance": "single-use-owner-sticky-revocation-v1",
				"fixture": "explicit26-fixed-night-only",
				"target_policy": "reviewed-renderer-not-device-allowlist-v1",
				"evidence_digest": "canonical-json-roundtrip-v1",
				"empty_wrappers": [44, 45],
				"wrapper_rule": "validate-original-lossless-empty-projection-v1",
				"paid_prefix": "exact-entry8-retained-prefix-v1",
				"free_switch": "new-entry-freezes-new-pattern-never-mutates-existing-fixture"
			}
		)
		. sha256_text()
	)


static func structural_profile(entry: Variant) -> Dictionary:
	if StadiumLightingKitNightReceiptAdapter.supports_entry(entry):
		return _wrapped_structure(entry).get("profile", {})
	if (
		not entry is Dictionary
		or not (
			SeasonOwnership._whole(entry.get("version"), 8, 8)
			or StadiumLightingKitNightReceiptAdapter.supports_entry(entry)
		)
		or entry.get("tier") != "backyard"
		or not is_candidate_layout(entry.get("layout"))
		or not StadiumLayoutSnapshot.valid(entry)
	):
		return {}
	var layout: Dictionary = physical_layout(entry.layout)
	if layout.is_empty() or StadiumLightingKitItems.is_terrain(layout):
		return {}
	if (
		not ClubCareer.same(layout.surface, DEFAULT_SURFACE)
		or not ClubCareer.same(layout.styles, {"grass": "", "line": ""})
		or layout.ground != ""
		or not ClubCareer.same(layout.walls, StadiumWallLayout.empty())
		or layout.lighting_kits.size() != 1
	):
		return {}
	var graph: StadiumRecipeBoundary = StadiumLightingKitItems.graph_for(layout)
	if (
		graph == null
		or graph.signature() != _reference_boundary().signature()
		or (graph is StadiumBoundaryOwnedGraph and not graph.owned_sides.is_empty())
	):
		return {}
	var stock: StadiumStock = StadiumLayoutSnapshot.ownership(entry)
	var checked: Dictionary = StadiumLightingKitItems.validate(layout, stock, entry.tier)
	if not checked.ok:
		return {}
	var pattern: String = layout.lighting_kits[0].site
	var kit_copy: String = layout.lighting_kits[0].copy
	var rear: Array = []
	for placed: Dictionary in checked.placements:
		if placed.item == "ST-111" and placed.copy == kit_copy and placed.site == pattern:
			continue
		if (
			pattern != "MIXED_EDGE"
			or placed.item != "ST-037"
			or placed.site not in ["YLIGHT-RL", "YLIGHT-RR"]
		):
			return {}
		rear.append({"copy": placed.copy, "site": placed.site})
	rear.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	if (
		(
			pattern == "MIXED_EDGE"
			and (rear.size() != 2 or rear[0].site != "YLIGHT-RL" or rear[1].site != "YLIGHT-RR")
		)
		or (pattern != "MIXED_EDGE" and not rear.is_empty())
	):
		return {}
	var composition: Dictionary = {
		"tier": entry.tier,
		"surface": layout.surface.duplicate(true),
		"styles": layout.styles.duplicate(true),
		"ground": layout.ground,
		"boundary": graph.signature(),
		"pattern": pattern,
		"source_count": 5 if pattern == "MIXED_EDGE" else 3,
		"rear_sites": ["YLIGHT-RL", "YLIGHT-RR"] if pattern == "MIXED_EDGE" else []
	}
	return {
		"profile": "ST111-" + pattern + "-BACKYARD-ROUGH-v1",
		"pattern": pattern,
		"kit_copy": kit_copy,
		"rear_poles": rear,
		"composition": composition,
		"composition_key":
		_data({"candidate": signature(), "composition": composition}).sha256_text()
	}


static func capture(ledger: ClubAssetLedger) -> Dictionary:
	if ledger == null:
		return {}
	var entry: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	if structural_profile(entry).is_empty():
		return {}
	var result: Dictionary = {
		"candidate_version": CANDIDATE_VERSION,
		"family": FAMILY,
		"contract": contract_for(entry),
		"entry": entry.duplicate(true)
	}
	return result if valid(result, ledger) else {}


static func candidate_shape(candidate: Variant) -> bool:
	return (
		candidate is Dictionary
		and StadiumNpcSnapshot._json_types(candidate)
		and SeasonOwnership._keys(candidate, ["candidate_version", "family", "contract", "entry"])
		and SeasonOwnership._whole(
			candidate.candidate_version, CANDIDATE_VERSION, CANDIDATE_VERSION
		)
		and candidate.family == FAMILY
		and candidate.entry is Dictionary
		and candidate.contract == contract_for(candidate.entry)
		and not structural_profile(candidate.entry).is_empty()
	)


static func valid(candidate: Variant, ledger: ClubAssetLedger) -> bool:
	return (
		ledger != null
		and candidate_shape(candidate)
		and StadiumLayoutSnapshot.matches(candidate.entry, ledger)
	)


static func evidence_shape(manifest: Variant, entry: Dictionary) -> bool:
	# A syntactically passing record is NOT trusted. admission_profile requires the compiled registry.
	var profile: Dictionary = structural_profile(entry)
	if (
		profile.is_empty()
		or not manifest is Dictionary
		or not StadiumNpcSnapshot._json_types(manifest)
		or not SeasonOwnership._keys(
			manifest,
			[
				"version",
				"family",
				"candidate",
				"model",
				"palette",
				"composition",
				"pattern",
				"palette_profile",
				"engine",
				"renderer",
				"driver",
				"adapter",
				"vendor",
				"viewport",
				"checks",
				"artifacts",
				"review_status"
			]
		)
		or not SeasonOwnership._whole(manifest.version, EVIDENCE_VERSION, EVIDENCE_VERSION)
		or manifest.family != EVIDENCE_FAMILY
		or manifest.candidate != signature()
		or manifest.model != StadiumLightingKitModels.signature()
		or not manifest.palette_profile is String
		or not PALETTE.PROFILES.has(manifest.palette_profile)
		or manifest.palette != PALETTE.signature(manifest.palette_profile)
		or manifest.composition != profile.composition_key
		or manifest.pattern != profile.pattern
		or not manifest.engine is String
		or manifest.engine.is_empty()
		or manifest.renderer not in ["mobile", "forward_plus", "gl_compatibility"]
		or not manifest.driver is String
		or not manifest.adapter is String
		or not manifest.vendor is String
		or not ClubCareer.same(manifest.viewport, [1280, 720])
		or manifest.review_status != "reviewed-pass"
		or not manifest.checks is Dictionary
		or not SeasonOwnership._keys(manifest.checks, REQUIRED_CHECKS)
		or not manifest.artifacts is Dictionary
		or not SeasonOwnership._keys(manifest.artifacts, ARTIFACTS)
	):
		return false
	for check: String in REQUIRED_CHECKS:
		if not manifest.checks[check] is bool or not manifest.checks[check]:
			return false
	for artifact: String in ARTIFACTS:
		if not _digest(manifest.artifacts[artifact]):
			return false
	return true


static func admission_profile(entry: Dictionary) -> Dictionary:
	if StadiumLightingKitNightReceiptAdapter.supports_entry(entry):
		return _wrapped_admission(entry).get("profile", {})
	if not RUNTIME_READY or not PUBLIC_READY:
		return {}
	var result: Dictionary = structural_profile(entry)
	if result.is_empty():
		return {}
	var registry: Variant = JSON.parse_string(QUALIFIED_MANIFESTS)
	if not registry is Dictionary:
		return {}
	var approved: Variant = registry.get(result.composition_key)
	if (
		not approved is Dictionary
		or not SeasonOwnership._keys(approved, ["digest", "manifest"])
		or not _digest(approved.digest)
		or not evidence_shape(approved.manifest, entry)
		or approved.digest != evidence_digest(approved.manifest)
	):
		return {}
	result["qualification"] = approved.digest
	result["presentation"] = approved.manifest.palette
	result["presentation_profile"] = approved.manifest.palette_profile
	result["engine"] = approved.manifest.engine
	result["renderer"] = approved.manifest.renderer
	result["driver"] = approved.manifest.driver
	result["adapter"] = approved.manifest.adapter
	result["vendor"] = approved.manifest.vendor
	result["viewport"] = approved.manifest.viewport.duplicate()
	return result


static func evidence_digest(manifest: Dictionary) -> String:
	# JSON parses numbers as floats. Normalize both authored dictionaries and parsed
	# source records before hashing, so 1 vs 1.0 is not a serialization-dependent gate.
	return _data(JSON.parse_string(_data(manifest))).sha256_text()


static func _digest(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)


static func _data(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


static func _reference_boundary() -> StadiumBoundaryOwnedGraph:
	return StadiumBoundaryOwnedGraph.create_owned(
		{
			"version": StadiumBoundaryItems.LAYOUT_VERSION,
			"boundary": [],
			"walls": StadiumWallLayout.empty()
		}
	)


static func target_matches(profile: Dictionary, viewport: Viewport) -> bool:
	# Evidence records the exact capture engine/device/driver/reference viewport.
	# The reviewed renderer is a portability boundary, not an exact hardware allowlist.
	# Ordinary resizing or a different GPU does not manufacture a new evidence claim.
	return (
		not profile.is_empty()
		and is_instance_valid(viewport)
		and profile.get("renderer") == str(RenderingServer.get_current_rendering_method())
	)


static func is_candidate_layout(value: Variant) -> bool:
	return (
		value is Dictionary
		and (
			StadiumLightingKitItems.is_family(value)
			or SeasonOwnership._whole(value.get("version"), 44, 47)
		)
	)


static func contract_for(entry: Dictionary) -> String:
	if SeasonOwnership._whole(entry.get("version"), 8, 8):
		return signature()
	return (
		StadiumLightingKitNightReceiptAdapter.signature(signature())
		if StadiumLightingKitNightReceiptAdapter.supports_entry(entry)
		else ""
	)


static func physical_layout(layout: Dictionary) -> Dictionary:
	if StadiumLowWallLayout.is_family(layout) or StadiumWaterfallAnimationLayout.is_family(layout):
		var retained: Dictionary = StadiumLightingKitNightReceiptAdapter.retained_empty_base(layout)
		return _physical_legacy_layout(retained) if not retained.is_empty() else {}
	return _physical_legacy_layout(layout)


static func _physical_legacy_layout(layout: Dictionary) -> Dictionary:
	# This never rewrites the entry or paid receipt. Original validation is mandatory
	# in structural_profile before these explicitly empty wrappers are projected.
	var projected: Dictionary = layout.duplicate(true)
	for wrapper: Dictionary in [
		{
			"version": 45,
			"family": "reference-live-waterfall-v45",
			"field": "live_waterfalls",
			"path": "res://src/gameplay/stadium/stadium_waterfall_live_items.gd"
		},
		{
			"version": 44,
			"family": "reference-outfield-plaza-v44",
			"field": "outfield_plaza",
			"path": "res://src/gameplay/stadium/stadium_outfield_plaza_items.gd"
		}
	]:
		if not SeasonOwnership._whole(projected.get("version"), wrapper.version, wrapper.version):
			continue
		if (
			projected.get("family") != wrapper.family
			or not projected.get(wrapper.field) is Array
			or not projected[wrapper.field].is_empty()
			or not ResourceLoader.exists(wrapper.path)
		):
			return {}
		var api: Script = load(wrapper.path) as Script
		if api == null or not api.is_family(projected):
			return {}
		var base: Dictionary = api.base(projected)
		if base.is_empty() or not ClubCareer.same(api.with_base(projected, base), projected):
			return {}
		projected = base
	return projected if StadiumLightingKitItems.is_family(projected) else {}


static func renderer_supported(entry: Dictionary) -> bool:
	var profile: Dictionary = admission_profile(entry)
	return (
		not profile.is_empty()
		and profile.renderer == str(RenderingServer.get_current_rendering_method())
	)


static func renderer_reason(entry: Dictionary) -> String:
	var profile: Dictionary = admission_profile(entry)
	if profile.is_empty():
		return "This exact lighting-kit composition has no reviewed Night profile."
	return (
		"This lighting-kit Night profile is reviewed for %s, not the current %s renderer."
		% [profile.renderer, str(RenderingServer.get_current_rendering_method())]
	)


# Fixture36-only, call-local derivation. No public method accepts a validated
# receipt/context supplied by its caller. Historical entry8 paths above are unchanged.
static func _wrapped_structure(entry: Dictionary) -> Dictionary:
	if (
		not StadiumLightingKitNightReceiptAdapter.supports_entry(entry)
		or entry.get("tier") != "backyard"
	):
		return {}
	var owners: Dictionary = (
		StadiumLowWallSnapshot._validated_ownership(entry)
		if int(entry.version) == 32
		else StadiumWaterfallAnimationSnapshot._validated_ownership(entry)
	)
	if owners.is_empty():
		return {}
	var layout: Dictionary = physical_layout(entry.layout)
	if layout.is_empty() or StadiumLightingKitItems.is_terrain(layout):
		return {}
	if (
		not ClubCareer.same(layout.surface, DEFAULT_SURFACE)
		or not ClubCareer.same(layout.styles, {"grass": "", "line": ""})
		or layout.ground != ""
		or not ClubCareer.same(layout.walls, StadiumWallLayout.empty())
		or layout.lighting_kits.size() != 1
	):
		return {}
	var graph: StadiumRecipeBoundary = StadiumLightingKitItems.graph_for(layout)
	if (
		graph == null
		or graph.signature() != _reference_boundary().signature()
		or (graph is StadiumBoundaryOwnedGraph and not graph.owned_sides.is_empty())
	):
		return {}
	var stock: StadiumStock = owners.stock
	var checked: Dictionary = StadiumLightingKitItems.validate(layout, stock, entry.tier)
	if not checked.ok:
		return {}
	var pattern: String = layout.lighting_kits[0].site
	var kit_copy: String = layout.lighting_kits[0].copy
	var rear: Array = []
	for placed: Dictionary in checked.placements:
		if placed.item == "ST-111" and placed.copy == kit_copy and placed.site == pattern:
			continue
		if (
			pattern != "MIXED_EDGE"
			or placed.item != "ST-037"
			or placed.site not in ["YLIGHT-RL", "YLIGHT-RR"]
		):
			return {}
		rear.append({"copy": placed.copy, "site": placed.site})
	rear.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	if (
		(
			pattern == "MIXED_EDGE"
			and (rear.size() != 2 or rear[0].site != "YLIGHT-RL" or rear[1].site != "YLIGHT-RR")
		)
		or (pattern != "MIXED_EDGE" and not rear.is_empty())
	):
		return {}
	var composition: Dictionary = {
		"tier": entry.tier,
		"surface": layout.surface.duplicate(true),
		"styles": layout.styles.duplicate(true),
		"ground": layout.ground,
		"boundary": graph.signature(),
		"pattern": pattern,
		"source_count": 5 if pattern == "MIXED_EDGE" else 3,
		"rear_sites": ["YLIGHT-RL", "YLIGHT-RR"] if pattern == "MIXED_EDGE" else []
	}
	var profile: Dictionary = {
		"profile": "ST111-" + pattern + "-BACKYARD-ROUGH-v1",
		"pattern": pattern,
		"kit_copy": kit_copy,
		"rear_poles": rear,
		"composition": composition,
		"composition_key":
		_data({"candidate": signature(), "composition": composition}).sha256_text()
	}
	var canonical: Dictionary = (
		StadiumLowWallSnapshot._normalized_validated(entry, owners)
		if int(entry.version) == 32
		else StadiumWaterfallAnimationSnapshot._normalized_validated(entry, owners)
	)
	return {
		"entry": canonical,
		"entry_key": _data(canonical).sha256_text(),
		"profile": profile,
		"physical_layout": layout,
		"physical_geometry": StadiumLightingKitItems.geometry(entry.tier, layout)
	}


static func _wrapped_evidence_for_profile(manifest: Variant, profile: Dictionary) -> bool:
	if (
		profile.is_empty()
		or not manifest is Dictionary
		or not StadiumNpcSnapshot._json_types(manifest)
		or not SeasonOwnership._keys(
			manifest,
			[
				"version",
				"family",
				"candidate",
				"model",
				"palette",
				"composition",
				"pattern",
				"palette_profile",
				"engine",
				"renderer",
				"driver",
				"adapter",
				"vendor",
				"viewport",
				"checks",
				"artifacts",
				"review_status"
			]
		)
		or not SeasonOwnership._whole(manifest.version, EVIDENCE_VERSION, EVIDENCE_VERSION)
		or manifest.family != EVIDENCE_FAMILY
		or manifest.candidate != signature()
		or manifest.model != StadiumLightingKitModels.signature()
		or not manifest.palette_profile is String
		or not PALETTE.PROFILES.has(manifest.palette_profile)
		or manifest.palette != PALETTE.signature(manifest.palette_profile)
		or manifest.composition != profile.composition_key
		or manifest.pattern != profile.pattern
		or not manifest.engine is String
		or manifest.engine.is_empty()
		or manifest.renderer not in ["mobile", "forward_plus", "gl_compatibility"]
		or not manifest.driver is String
		or not manifest.adapter is String
		or not manifest.vendor is String
		or not ClubCareer.same(manifest.viewport, [1280, 720])
		or manifest.review_status != "reviewed-pass"
		or not manifest.checks is Dictionary
		or not SeasonOwnership._keys(manifest.checks, REQUIRED_CHECKS)
		or not manifest.artifacts is Dictionary
		or not SeasonOwnership._keys(manifest.artifacts, ARTIFACTS)
	):
		return false
	for check: String in REQUIRED_CHECKS:
		if not manifest.checks[check] is bool or not manifest.checks[check]:
			return false
	for artifact: String in ARTIFACTS:
		if not _digest(manifest.artifacts[artifact]):
			return false
	return true


static func _wrapped_admission(entry: Dictionary) -> Dictionary:
	if not RUNTIME_READY or not PUBLIC_READY:
		return {}
	var context: Dictionary = _wrapped_structure(entry)
	if context.is_empty():
		return {}
	var profile: Dictionary = _wrapped_approved_profile(context.profile)
	if profile.is_empty():
		return {}
	context.profile = profile
	return context


static func _wrapped_approved_profile(result: Dictionary) -> Dictionary:
	var registry: Variant = JSON.parse_string(QUALIFIED_MANIFESTS)
	if not registry is Dictionary:
		return {}
	var approved: Variant = registry.get(result.composition_key)
	if (
		not approved is Dictionary
		or not SeasonOwnership._keys(approved, ["digest", "manifest"])
		or not _digest(approved.digest)
		or not _wrapped_evidence_for_profile(approved.manifest, result)
		or approved.digest != evidence_digest(approved.manifest)
	):
		return {}
	result["qualification"] = approved.digest
	result["presentation"] = approved.manifest.palette
	result["presentation_profile"] = approved.manifest.palette_profile
	result["engine"] = approved.manifest.engine
	result["renderer"] = approved.manifest.renderer
	result["driver"] = approved.manifest.driver
	result["adapter"] = approved.manifest.adapter
	result["vendor"] = approved.manifest.vendor
	result["viewport"] = approved.manifest.viewport.duplicate()
	return result

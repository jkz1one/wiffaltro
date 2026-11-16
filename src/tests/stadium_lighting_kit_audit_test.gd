extends "res://src/tests/stadium_owned_waterfall_test.gd"
## Isolated synthetic regression audit. No earned-career, physical-game or Night claim.
const KIT_FIRST: String = "purchase:audit-kits:0"
const KIT_SPARE: String = "purchase:audit-kits:1"
const LEGACY: String = "purchase:audit-legacy:0"
const POLE_FIRST: String = "purchase:audit-poles:0"
const POLE_SPARE: String = "purchase:audit-poles:1"
const PATTERNS: Array[String] = ["PARALLEL", "ZIGZAG", "PERIMETER", "MIXED_EDGE"]
const LEGACY_CATALOG: String = "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f"


func _ready() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5})
	_set_authority()
	_kit_gates()
	_kit_case(false, false)
	_kit_case(false, true)
	_kit_case(true, true)
	print(
		(
			"LIGHTING_KIT_AUDIT_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_funding": true,
					"synthetic_progression": true,
					"synthetic_reward_authority": true,
					"physical_games": 0,
					"rendered_acceptance": false,
					"night_qualified": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _set_authority() -> void:
	var ordinary: Dictionary = {
		"version": 1,
		"season_id": 5,
		"season_number": 5,
		"league_id": "standard",
		"difficulty_id": "standard.d4",
		"era": StadiumClubIdentity.current()
	}
	var mastery: Dictionary = ordinary.duplicate(true)
	mastery["mastery_contract"] = "standard.d4"
	authority[StadiumPennantRewards.key(5)] = ordinary
	authority[StadiumPennantRewards.mastery_key()] = mastery
	var player: String = SeasonPlayerCatalog.ids()[0]
	authority[StadiumPlaqueRewards.key(player)] = {
		"version": 1,
		"player_id": player,
		"display_name": "Lighting Audit Fixture",
		"uniform_number": null,
		"season_id": 3,
		"award_game": 5,
		"award_completed": true,
		"era": StadiumClubIdentity.current(),
		"stats":
		{
			"hits": 40,
			"strikeouts": 0,
			"clean_outs": 0,
			"completed_seasons": [1, 2, 3],
			"credited_games": {"1": 5, "2": 5, "3": 5},
			"eligible": true,
			"evidence": "prospective-known-minimum"
		}
	}
	check(
		StadiumPennantRewards.valid_awards(authority, credits),
		"synthetic mixed title/plaque authority validates"
	)


func _kit_gates() -> void:
	check(
		StadiumCatalog.signature() == LEGACY_CATALOG,
		"historical base catalog remains frozen, not rebaselined"
	)
	check(
		(
			StadiumCatalog.item("ST-036").copy_price == 45
			and StadiumStringLightItems.PRESETS.size() == 2
		),
		"legacy14m span economics and profiles remain unchanged"
	)
	var stock: StadiumStock = StadiumStock.new_club()
	for metric: Array in [[2, 8, false], [3, 7, false], [3, 8, true]]:
		var quote: Dictionary = StadiumPurchases.quote(
			stock, "ST-111", 1, "audit-gate", 33, {"seasons": metric[0], "wins": metric[1]}
		)
		check(quote.ok == metric[2], "exact kit S3/W8 gate " + str(metric))
		if quote.ok:
			check(
				quote.blueprint_cost == 260 and quote.copy_cost == 120 and quote.cost == 380,
				"one whole kit Working260+120 quote"
			)
	for version in range(1, 33):
		check(
			not (
				StadiumPurchases
				. quote(stock, "ST-111", 1, "audit-old", version, {"seasons": 99, "wins": 999})
				. ok
			),
			"legacy price family cannot sell extension kit " + str(version)
		)
	check(
		StadiumLightingKitItems.sites() == PATTERNS and StadiumLightingKitItems.yaws() == [0],
		"exact four fixed kit patterns"
	)
	check(
		(
			StadiumLightingKitItems.row(KIT_FIRST, "ST-036", "PARALLEL").is_empty()
			and StadiumLightingKitItems.row(KIT_FIRST, "ST-111", "UNKNOWN").is_empty()
			and StadiumLightingKitItems.row(KIT_FIRST, "ST-111", "PARALLEL", 90).is_empty()
		),
		"kit route cannot reinterpret legacy span or invent pattern/yaw"
	)


func _buy(ledger: ClubAssetLedger, id: String, item: String, quantity: int, price: int) -> bool:
	var command: Dictionary = {
		"id": id,
		"rev": ledger.revision(),
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": price,
		"through": credits.size(),
		"progress_through": progress.size()
	}
	var result: Dictionary = ledger.commit(command)
	check(result.ok, "paid ordinary purchase " + item + ": " + result.error)
	if not result.ok:
		return false
	var after: Dictionary = ledger.to_data()
	check(
		(
			ledger.commit(_json(command)).get("replayed", false)
			and ClubCareer.same(after, ledger.to_data())
		),
		"cold duplicate purchase is idempotent " + item
	)
	var changed: Dictionary = command.duplicate(true)
	changed.quantity += 1
	_refuse(ledger, changed, "same purchase id with changed quantity refuses " + item)
	return true


func _kit_case(salvage: bool, earned: bool) -> void:
	var label: String = "salvage=%s earned=%s" % [salvage, earned]
	var ledger: ClubAssetLedger = (
		ClubAssetLedger.new_club(SEED, credits, progress, authority)
		if salvage
		else ClubAssetLedger.new(SEED, credits, progress, authority)
	)
	var original: Dictionary = ledger.to_data()
	if salvage:
		check(
			(
				ledger
				. commit(
					{
						"id": "audit-clear",
						"rev": ledger.revision(),
						"op": "stadium_salvage_clear",
						"copy": StadiumStock.SALVAGE_COPY,
						"price_version": 1,
						"through": credits.size()
					}
				)
				. ok
			),
			label + " clears inherited car"
		)
	if earned:
		for key: String in authority:
			var op: String = (
				"stadium_plaque"
				if authority[key].has("player_id")
				else (
					"stadium_mastery"
					if authority[key].has("mastery_contract")
					else "stadium_pennant"
				)
			)
			check(
				(
					ledger
					. commit(
						{"id": key, "rev": ledger.revision(), "op": op, "earned": authority[key]}
					)
					. ok
				),
				label + " preserves independently earned " + op
			)
	if not _buy(ledger, "audit-legacy", "ST-036", 1, 30):
		return
	if not _buy(ledger, "audit-poles", "ST-037", 2, 7):
		return
	var before: Dictionary = ledger.to_data()
	var old_stock: Dictionary = ledger.construction().to_data()
	var old_revision: int = ledger.revision()
	var old_snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var old_balance: int = ledger.balance()
	if not _buy(ledger, "audit-kits", "ST-111", 2, 33):
		return
	var stock: StadiumStock = ledger.construction()
	var current: Dictionary = ledger.to_data()
	check(
		(
			current.version == 52
			and stock.to_data().version == 6
			and ledger.balance() == old_balance - 500
		),
		label + " one blueprint/two exact kits cost500 with additive52/6 headers"
	)
	check(
		(
			ClubCareer.same(ledger.prefix(old_revision).to_data(), before)
			and ClubCareer.same(ledger.prefix(0).to_data(), original)
		),
		label + " historical journal headers/events/prefixes exact"
	)
	check(
		StadiumLayoutSnapshot.matches(old_snapshot, ledger),
		label + " earlier snapshot survives kit purchase"
	)
	for copy: String in old_stock.copies:
		check(
			ClubCareer.same(old_stock.copies[copy], stock.copies[copy]),
			label + " existing owned copy unchanged " + copy
		)
	if earned:
		check(
			stock.earned_count() == 3 and stock.plaque_count() == 1 and stock.pennant_count() == 1,
			label + " stock6 retains all three independent earned sources"
		)
	_stock_tamper(stock.to_data(), label)
	_journal_tamper(current, before, label)
	_cold(ledger, label + " purchased")
	var layout: Dictionary = StadiumLightingKitItems.upgrade(
		ledger.view().stadium_draft, ledger.surface_owned()
	)
	check(
		layout.version == 43 and layout.lighting_kits.is_empty(),
		label + " purchase never auto-places a kit"
	)
	var empty: Dictionary = layout.duplicate(true)
	var inventory: Dictionary = stock.to_data()
	for pattern: String in PATTERNS:
		var next: Dictionary = StadiumLightingKitItems.place(layout, stock, KIT_FIRST, pattern)
		check(
			next.lighting_kits == [{"copy": KIT_FIRST, "site": pattern}],
			label + " one same copy switches exactly " + pattern
		)
		var checked: Dictionary = StadiumHomeLayout.validate(next, stock, "backyard")
		check(
			checked.ok,
			label + " complete Backyard kit validates " + pattern + ": " + checked.get("error", "")
		)
		if not checked.ok:
			continue
		check(
			(
				not checked.night_qualified
				and checked.live_units == 0
				and checked.stored.has(KIT_SPARE)
				and checked.stored.has(LEGACY)
				and checked.stored.has(POLE_FIRST)
				and checked.stored.has(POLE_SPARE)
			),
			(
				label
				+ " distinct spare/legacy/poles remain stored and no Night/budget promotion "
				+ pattern
			)
		)
		if not _apply(ledger, next, label + " free pattern " + pattern):
			continue
		layout = next
		check(
			(
				ledger.balance() == old_balance - 500
				and ClubCareer.same(ledger.construction().to_data(), inventory)
			),
			label + " switch charges no fee and creates/replaces no ownership " + pattern
		)
		var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
		check(
			(
				not snapshot.is_empty()
				and StadiumLayoutSnapshot.valid(_json(snapshot))
				and (
					StadiumLayoutSnapshot.key(snapshot)
					== StadiumLayoutSnapshot.key(_json(snapshot))
				)
				and StadiumLayoutSnapshot.matches(snapshot, ledger)
			),
			label + " exact cold snapshot " + pattern
		)
		var substituted: Dictionary = snapshot.duplicate(true)
		substituted.layout.lighting_kits[0].copy = KIT_SPARE
		check(
			(
				StadiumLayoutSnapshot.valid(substituted)
				and not StadiumLayoutSnapshot.matches(substituted, ledger)
				and StadiumLayoutSnapshot.key(substituted) != StadiumLayoutSnapshot.key(snapshot)
			),
			label + "owned spare cannot impersonate frozen exact active kit " + pattern
		)
		check(
			(
				StadiumFixtureEnvironment.capture(snapshot, SEED, 0).mode == "day"
				and StadiumSurfaceNightLayout.capture(ledger).is_empty()
			),
			label + " no qualified season Night " + pattern
		)
		var stale: Dictionary = {
			"id": "audit-stale-" + pattern,
			"rev": ledger.revision() - 1,
			"op": "stadium_draft",
			"layout": next
		}
		_refuse(ledger, stale, label + " stale pattern change atomic " + pattern)
		_cold(ledger, label + " pattern " + pattern)
		if not salvage and not earned:
			_assembled(ledger, layout, pattern)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var exact: Dictionary = ledger.to_data()
	var revision: int = ledger.revision()
	var doubled: Dictionary = StadiumLightingKitItems.place(layout, stock, KIT_SPARE, "PARALLEL")
	check(
		(
			doubled.lighting_kits.size() == 2
			and not StadiumHomeLayout.validate(doubled, stock, "backyard").ok
		),
		label + " second paid kit does not silently replace occupied first"
	)
	_refuse(
		ledger,
		{
			"id": "audit-capacity",
			"rev": ledger.revision(),
			"op": "stadium_draft",
			"layout": doubled
		},
		label + " occupied-kit refusal atomic"
	)
	check(
		ClubCareer.same(StadiumLightingKitItems.store_copy(layout, KIT_SPARE), layout),
		label + " Store spare cannot clear active exact copy"
	)
	_mutation_cases(ledger, layout, label)
	var stored: Dictionary = StadiumLightingKitItems.store_copy(layout, KIT_FIRST)
	check(
		(
			stored.lighting_kits.is_empty()
			and ClubCareer.same(
				StadiumLightingKitItems.base(stored), StadiumLightingKitItems.base(empty)
			)
		),
		label + " Store removes only kit placement, not inherited channels"
	)
	if _apply(ledger, stored, label + " Store"):
		check(
			(
				ClubCareer.same(ledger.construction().to_data(), inventory)
				and StadiumLayoutSnapshot.matches(snapshot, ledger)
				and ClubCareer.same(ledger.prefix(revision).to_data(), exact)
			),
			label + " Store preserves complete stock and frozen history"
		)
	var legacy_layout: Dictionary = StadiumStringLightItems.place(stored, stock, LEGACY, "STR-LF")
	check(
		(
			legacy_layout.version == 43
			and legacy_layout.string_lights == [{"copy": LEGACY, "site": "STR-LF"}]
			and legacy_layout.lighting_kits.is_empty()
			and StadiumHomeLayout.validate(legacy_layout, stock, "backyard").ok
		),
		label + " old selector retains family43 and exact14m legacy copy"
	)
	_cold(ledger, label + " stored")
	if not salvage and not earned:
		_conflicts(ledger, stored)


func _stock_tamper(data: Dictionary, label: String) -> void:
	check(
		(
			data.has("extension_catalog")
			and data.extension_catalog is Dictionary
			and data.extension_catalog.keys() == ["ST-111"]
		),
		label + " bounded present-ID extension catalog"
	)
	var cold: StadiumStock = StadiumStock.from_data(_json(data))
	check(
		cold != null and ClubCareer.same(cold.to_data(), data),
		label + " stock6 JSON roundtrip is canonical"
	)
	for change: String in [
		"missing",
		"forged",
		"extra",
		"wrong-type",
		"old-header",
		"old-header-no-seal",
		"unknown-item",
		"wrong-price",
		"wrong-source",
		"missing-blueprint"
	]:
		var bad: Dictionary = data.duplicate(true)
		match change:
			"missing":
				bad.erase("extension_catalog")
			"forged":
				bad.extension_catalog["ST-111"] = "forged"
			"extra":
				bad.extension_catalog["ST-112"] = "forged"
			"wrong-type":
				bad.extension_catalog = []
			"old-header":
				bad.version = 5
			"old-header-no-seal":
				bad.version = 5
				bad.erase("extension_catalog")
			"unknown-item":
				bad.copies[KIT_FIRST].item = "ST-112"
			"wrong-price":
				bad.copies[KIT_FIRST].paid = 45
			"wrong-source":
				bad.copies[KIT_FIRST].source = "starter-v1"
			"missing-blueprint":
				bad.blueprints.erase("ST-111")
		check(
			StadiumStock.from_data(bad) == null, label + " reject stock extension tamper " + change
		)


func _journal_tamper(data: Dictionary, before: Dictionary, label: String) -> void:
	var new_fields: Array[String] = []
	for key: String in data:
		if not before.has(key):
			new_fields.append(key)
	check(
		not new_fields.is_empty(), label + " additive journal introduces authenticated kit catalogs"
	)
	for key: String in new_fields:
		var bad: Dictionary = data.duplicate(true)
		bad.erase(key)
		check(_load(bad) == null, label + " missing additive journal field rejects " + key)
		bad = data.duplicate(true)
		bad[key] = "forged"
		check(_load(bad) == null, label + " forged additive journal field rejects " + key)
	var older: Dictionary = data.duplicate(true)
	older.version = 51
	for key: String in new_fields:
		older.erase(key)
	check(_load(older) == null, label + " journal51 cannot smuggle kit purchase")


func _mutation_cases(ledger: ClubAssetLedger, layout: Dictionary, label: String) -> void:
	if layout.lighting_kits.is_empty():
		check(false, label + " active kit required before mutation coverage")
		return
	for change: String in [
		"foreign",
		"legacy-copy",
		"pole-copy",
		"pattern",
		"extra-field",
		"version",
		"family",
		"wrapper-field",
		"bad-type"
	]:
		var bad: Dictionary = layout.duplicate(true)
		match change:
			"foreign":
				bad.lighting_kits[0].copy = "purchase:foreign:0"
			"legacy-copy":
				bad.lighting_kits[0].copy = LEGACY
			"pole-copy":
				bad.lighting_kits[0].copy = POLE_FIRST
			"pattern":
				bad.lighting_kits[0].site = "PARALLEL-ALTERED"
			"extra-field":
				bad.lighting_kits[0]["yaw"] = 0
			"version":
				bad.version = 42
			"family":
				bad.family = "forged"
			"wrapper-field":
				bad["unbound_channel"] = []
			"bad-type":
				bad.lighting_kits[0].copy = true
		_refuse(
			ledger,
			{
				"id": "audit-mutation-" + change,
				"rev": ledger.revision(),
				"op": "stadium_draft",
				"layout": bad
			},
			label + " exact-schema mutation refuses " + change
		)


func _assembled(ledger: ClubAssetLedger, layout: Dictionary, pattern: String) -> void:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	var built: bool = property.build("backyard", layout, ledger.construction())
	check(built and property.props_intact(), "ordinary complete assembled kit seals " + pattern)
	if not built or not property.objects.has(KIT_FIRST):
		property.free()
		return
	var model: Node3D = property.objects[KIT_FIRST]
	check(
		(
			StadiumLightingKitModels.valid(model)
			and model.get_meta("owned_copy", "") == KIT_FIRST
			and model.get_meta("site", "") == pattern
		),
		"model binds exact paid kit and pattern " + pattern
	)
	check(
		property.route_obstacles().is_empty(),
		"kit stays out of defender route obstacles " + pattern
	)
	var sources: Array[Node] = model.find_children("*", "Light3D", true, false)
	check(not sources.is_empty(), "kit includes authored real light sources " + pattern)
	if not sources.is_empty():
		var source: Light3D = sources[0]
		var energy: float = source.light_energy
		source.light_energy += 0.125
		check(
			not property.props_intact(),
			"nested emitter energy mutation invalidates property " + pattern
		)
		source.light_energy = energy
		check(property.props_intact(), "exact energy restoration recovers seal " + pattern)
		source.visible = not source.visible
		check(
			not property.props_intact(),
			"nested emitter visibility mutation invalidates property " + pattern
		)
		source.visible = not source.visible
		var had: bool = source.has_meta("model_source")
		var previous: Variant = source.get_meta("model_source") if had else false
		source.set_meta("model_source", "forged-archive")
		check(
			not property.props_intact(),
			"nested model_source metadata mutation invalidates property " + pattern
		)
		if had:
			source.set_meta("model_source", previous)
		else:
			source.remove_meta("model_source")
		check(property.props_intact(), "exact metadata restoration recovers seal " + pattern)
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	check(not meshes.is_empty(), "kit contains complete modeled spans/supports " + pattern)
	if not meshes.is_empty():
		var mesh: MeshInstance3D = meshes[0]
		var material: StandardMaterial3D = mesh.material_override
		if material != null:
			var color: Color = material.albedo_color
			material.albedo_color = Color.MAGENTA
			check(
				not property.props_intact(),
				"nested shared material mutation invalidates property " + pattern
			)
			material.albedo_color = color
			check(property.props_intact(), "exact material restoration recovers seal " + pattern)
	property.free()


func _conflicts(ledger: ClubAssetLedger, empty: Dictionary) -> void:
	var stock: StadiumStock = ledger.construction()
	var mixed: Dictionary = StadiumLightingKitItems.place(empty, stock, KIT_FIRST, "MIXED_EDGE")
	var old: Dictionary = StadiumStringLightItems.place(empty, stock, LEGACY, "STR-LF")
	check(
		(
			StadiumHomeLayout.validate(mixed, stock, "backyard").ok
			and StadiumHomeLayout.validate(old, stock, "backyard").ok
		),
		"both isolated kit and legacy14m occupant validate"
	)
	var combined_a: Dictionary = StadiumStringLightItems.place(mixed, stock, LEGACY, "STR-LF")
	var combined_b: Dictionary = StadiumLightingKitItems.place(old, stock, KIT_FIRST, "MIXED_EDGE")
	check(
		(
			not StadiumHomeLayout.validate(combined_a, stock, "backyard").ok
			and not StadiumHomeLayout.validate(combined_b, stock, "backyard").ok
			and combined_a.lighting_kits.size() == 1
			and combined_a.string_lights.size() == 1
		),
		"physical span/post conflict refuses both command orders without storing either copy"
	)
	_refuse(
		ledger,
		{
			"id": "audit-geometry-conflict",
			"rev": ledger.revision(),
			"op": "stadium_draft",
			"layout": combined_a
		},
		"physical geometry conflict preserves complete saved state atomically"
	)
	var pair: Dictionary = mixed.duplicate(true)
	pair.lights = [
		{"copy": POLE_FIRST, "site": "YLIGHT-RL"}, {"copy": POLE_SPARE, "site": "YLIGHT-RR"}
	]
	check(
		StadiumHomeLayout.validate(pair, stock, "backyard").ok,
		"MixedEdge supports separately purchased rear pair"
	)
	check(
		(
			pair.lighting_kits == mixed.lighting_kits
			and stock.copies[POLE_FIRST].item == "ST-037"
			and stock.copies[POLE_SPARE].item == "ST-037"
		),
		"MixedEdge never includes/transforms/fabricates ST037 ownership"
	)
	var pad: Dictionary = StadiumMoldedSeatItems.upgrade(
		StadiumStarterLayout.empty(), ledger.surface_owned()
	)
	pad = StadiumLightingKitItems.upgrade(pad, ledger.surface_owned())
	check(
		(
			StadiumMoldedSeatItems.has_pad(pad)
			and StadiumHomeLayout.validate(pad, stock, "expanded").ok
		),
		"empty molded pad alone valid on Expanded property"
	)
	var pad_conflict: Dictionary = StadiumLightingKitItems.place(pad, stock, KIT_FIRST, "ZIGZAG")
	check(
		not StadiumHomeLayout.validate(pad_conflict, stock, "expanded").ok,
		"Zigzag left support at(-25.5,20) cannot pierce inherited molded-seat pad reservation"
	)

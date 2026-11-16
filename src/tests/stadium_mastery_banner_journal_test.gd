extends Node
## Synthetic credits/progress/title authority exercise the actual permanent journal.
## No physical games, authentic career achievement, rendered review or production save claim.

const SEED: int = 176
const BUY: String = "mastery-journal-lower"
const LOWER: String = "purchase:mastery-journal-lower:0"
var checks: int = 0
var failures: Array[String] = []
var credits: Array = []
var progress: Array = []
var authority: Dictionary = {}
var mastery: Dictionary
var banner: String


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("MASTERY_BANNER_JOURNAL: " + label)


func _ready() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5})
	var ordinary: Dictionary = {
		"version": 1,
		"season_id": 5,
		"season_number": 5,
		"league_id": "standard",
		"difficulty_id": "standard.d4",
		"era": StadiumClubIdentity.current()
	}
	mastery = ordinary.duplicate(true)
	mastery["mastery_contract"] = "standard.d4"
	banner = StadiumPennantRewards.mastery_key()
	authority[StadiumPennantRewards.key(5)] = ordinary
	authority[banner] = mastery
	check(
		(
			StadiumCareerProgress.valid(progress, credits)
			and StadiumPennantRewards.valid_awards(authority, credits)
		),
		"explicitly synthetic authority is structurally valid"
	)
	_case(false)
	_case(true)
	print(
		(
			"MASTERY_BANNER_JOURNAL_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_funding": true,
					"synthetic_progression": true,
					"synthetic_title_authority": true,
					"physical_games": 0,
					"rendered_acceptance": false,
					"authentic_earned_career": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _case(with_salvage: bool) -> void:
	var label: String = "salvage origin" if with_salvage else "legacy origin"
	var ledger: ClubAssetLedger = (
		ClubAssetLedger.new_club(SEED, credits, progress, authority)
		if with_salvage
		else ClubAssetLedger.new(SEED, credits, progress, authority)
	)
	var initial: Dictionary = ledger.to_data()
	check(ledger.fork() != null and ledger.revision() == 0, label + " initial journal is valid")
	if with_salvage:
		var clearance: Dictionary = ledger.commit(
			{
				"id": "mastery-clear",
				"rev": ledger.revision(),
				"op": "stadium_salvage_clear",
				"copy": StadiumStock.SALVAGE_COPY,
				"price_version": 1,
				"through": credits.size()
			}
		)
		check(
			(
				clearance.ok
				and ledger.view().salvage_cleared
				and ledger.view().stadium_active.salvage_cars.is_empty()
			),
			label + " paid190 clearance stores original car before structural placement"
		)
		if not clearance.ok:
			return
	for tier: String in ["expanded", "club"]:
		var prior_balance: int = ledger.balance()
		var land: Dictionary = ledger.commit(
			{
				"id": "mastery-land-" + tier,
				"rev": ledger.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": credits.size(),
				"progress_through": progress.size(),
				"price_version": StadiumLand.VERSION
			}
		)
		check(
			(
				land.ok
				and ledger.view().land == tier
				and ledger.balance() == prior_balance - int(StadiumCatalog.LAND[tier].price)
			),
			label + " real ordered land purchase " + tier
		)
		if not land.ok:
			return
	var prior_balance: int = ledger.balance()
	var bought: Dictionary = ledger.commit(
		{
			"id": BUY,
			"rev": ledger.revision(),
			"op": "stadium_buy",
			"item": "ST-029",
			"quantity": 1,
			"price_version": StadiumStraightItems.PRICE_VERSION,
			"through": credits.size(),
			"progress_through": progress.size()
		}
	)
	check(
		(
			bought.ok
			and ledger.balance() == prior_balance - 520
			and ledger.construction().copies.has(LOWER)
		),
		label + " actual520 blueprint-plus-copy lower purchase"
	)
	if not bought.ok:
		return
	var before_rewards: Dictionary = ledger.to_data()
	var before_reward_revision: int = ledger.revision()
	var paid_balance: int = ledger.balance()
	for id: String in [StadiumPennantRewards.key(5), banner]:
		var awarded: Dictionary = ledger.commit(
			{
				"id": id,
				"rev": ledger.revision(),
				"op": "stadium_mastery" if id == banner else "stadium_pennant",
				"earned": authority[id]
			}
		)
		check(awarded.ok and ledger.balance() == paid_balance, label + " free journal reward " + id)
		if not awarded.ok:
			return
	var rewarded: Dictionary = ledger.to_data()
	var reward_revision: int = ledger.revision()
	var owned: Dictionary = ledger.construction().to_data()
	check(
		(
			rewarded.version == 49
			and owned.version == 4
			and rewarded.mastery_catalog == StadiumPennantRewards.mastery_signature()
			and not rewarded.has("mastery_layout_catalog")
		),
		label + " reward-only49 pins reward contract without inventing layout contract"
	)
	check(
		(
			ledger.prefix(before_reward_revision) != null
			and ClubCareer.same(ledger.prefix(before_reward_revision).to_data(), before_rewards)
		),
		label + " pre-award prefix retains exact old headers and purchases"
	)
	var layout: Dictionary = StadiumMasteryBannerItems.upgrade(
		ledger.view().stadium_draft, ledger.surface_owned()
	)
	layout = StadiumStraightItemsUI.select(
		layout, ledger.construction(), LOWER, {"site": "BASE-L1", "lower": "", "concourse": ""}
	)
	layout = StadiumMasteryBannerItems.place(layout, ledger.construction(), banner, LOWER)
	check(
		(
			layout.version == 41
			and StadiumHomeLayout.validate(layout, ledger.construction(), "club").ok
		),
		label + " earned banner and paid lower form valid family41"
	)
	if not _apply(ledger, layout, label + " mount"):
		return
	var mounted: Dictionary = ledger.to_data()
	var mounted_revision: int = ledger.revision()
	check(
		(
			mounted.version == 49
			and mounted.mastery_layout_catalog == StadiumMasteryBannerItems.signature()
		),
		label + " first actual layout41 event pins distinct layout signature"
	)
	check(
		(
			ledger.prefix(reward_revision) != null
			and ClubCareer.same(ledger.prefix(reward_revision).to_data(), rewarded)
		),
		label + " pre-layout prefix drops only absent layout signature"
	)
	check(
		(
			ledger.balance() == paid_balance
			and ClubCareer.same(ledger.construction().to_data(), owned)
		),
		label + " placement cannot charge or rewrite any owned copy"
	)
	_cold(ledger, label + " mounted")
	_mastery_mounted_snapshot(
		with_salvage, label, ledger, initial, paid_balance, owned, layout, mounted, mounted_revision
	)


func _mastery_mounted_snapshot(
	with_salvage: bool, label: String, ledger: ClubAssetLedger, initial: Dictionary,
	paid_balance: int, owned: Dictionary, layout: Dictionary, mounted: Dictionary,
	mounted_revision: int
) -> void:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.valid(snapshot)
			and StadiumLayoutSnapshot.matches(snapshot, ledger)
		),
		label + " actual applied journal produces exact-prefix frozen snapshot"
	)
	check(
		(
			StadiumLayoutSnapshot.valid(_json(snapshot))
			and StadiumLayoutSnapshot.key(snapshot) == StadiumLayoutSnapshot.key(_json(snapshot))
		),
		label + " bound snapshot survives cold JSON without key drift"
	)
	for field: String in ["mastery_catalog", "mastery_layout_catalog"]:
		var bad: Dictionary = mounted.duplicate(true)
		bad.erase(field)
		check(_load(bad) == null, label + " missing " + field + " refused")
		bad = mounted.duplicate(true)
		bad[field] = "forged"
		check(_load(bad) == null, label + " forged " + field + " refused")
	check(
		ClubCareer.same(ledger.to_data(), mounted),
		label + " failed cold loads cannot alter live journal"
	)
	var bad_layout: Dictionary = layout.duplicate(true)
	bad_layout.mastery_banners[0].socket = "crest"
	_refuse(
		ledger,
		{
			"id": "mastery-bad-socket",
			"rev": ledger.revision(),
			"op": "stadium_draft",
			"layout": bad_layout
		},
		label + " malformed exact mount refuses atomically"
	)
	bad_layout = layout.duplicate(true)
	bad_layout.hosts[0].site = "BASE-R1"
	_refuse(
		ledger,
		{
			"id": "mastery-rebind-host",
			"rev": ledger.revision(),
			"op": "stadium_draft",
			"layout": bad_layout
		},
		label + " retained banner cannot travel with directly moved host"
	)
	_refuse(
		ledger,
		{
			"id": "mastery-stale-draft",
			"rev": ledger.revision() - 1,
			"op": "stadium_draft",
			"layout": layout
		},
		label + " stale family41 draft refuses atomically"
	)
	var stored: Dictionary = StadiumMasteryBannerItems.store_copy(layout, banner)
	if not _apply(ledger, stored, label + " banner Store"):
		return
	check(
		(
			ledger.view().stadium_active.mastery_banners.is_empty()
			and ledger.view().stadium_active.hosts.size() == 1
			and (
				StadiumHomeLayout
				. validate(ledger.view().stadium_active, ledger.construction(), "club")
				. stored
				. has(banner)
			)
		),
		label + " banner Store preserves paid host and exact earned copy"
	)
	if not _apply(ledger, layout, label + " explicit remount"):
		return
	var host_stored: Dictionary = StadiumStraightItemsUI.select(
		layout, ledger.construction(), LOWER, {}
	)
	if not _apply(ledger, host_stored, label + " host Store"):
		return
	check(
		(
			ledger.view().stadium_active.hosts.is_empty()
			and ledger.view().stadium_active.mastery_banners.is_empty()
		),
		label + " host Store atomically stores its dependent banner"
	)
	check(
		(
			ledger.balance() == paid_balance
			and ClubCareer.same(ledger.construction().to_data(), owned)
			and ledger.construction().to_data().version == 4
		),
		label + " all lifecycle edits are free and preserve stock4 including history"
	)
	check(
		(
			ledger.prefix(mounted_revision) != null
			and ClubCareer.same(ledger.prefix(mounted_revision).to_data(), mounted)
		),
		label + " mounted historical prefix survives later storage"
	)
	check(
		StadiumLayoutSnapshot.matches(snapshot, ledger),
		label + " later storage cannot rewrite frozen season snapshot"
	)
	check(
		ledger.prefix(0) != null and ClubCareer.same(ledger.prefix(0).to_data(), initial),
		label + " zero-event prefix retains exact original grant/origin identity"
	)
	if with_salvage:
		check(
			(
				ledger.construction().copies.has(StadiumStock.SALVAGE_COPY)
				and not ledger.construction().blueprints.has("ST-005")
				and ledger.to_data().salvage_origin == initial.salvage_origin
				and ledger.view().salvage_cleared
			),
			label + " mixed49 retains cleared original car without blueprint or duplicate grant"
		)
	_cold(ledger, label + " stored")
	check(
		ClubAssetLedger.from_data(_json(ledger.to_data()), SEED, credits, progress) == null,
		label + " saved journal without supplied title authority cannot self-authorize reward"
	)


func _apply(ledger: ClubAssetLedger, layout: Dictionary, label: String) -> bool:
	var balance: int = ledger.balance()
	var stock_before: Dictionary = ledger.construction().to_data()
	var active_before: Dictionary = ledger.view().stadium_active
	var before: Dictionary = ledger.to_data()
	var draft: Dictionary = {
		"id": "mastery-draft:%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_draft",
		"layout": layout
	}
	var preview: Dictionary = ledger.preview(draft)
	check(
		preview.ok and ClubCareer.same(ledger.to_data(), before),
		label + " draft preview is read-only"
	)
	var saved: Dictionary = ledger.commit(draft)
	check(
		(
			saved.ok
			and ClubCareer.same(ledger.view().stadium_active, active_before)
			and ClubCareer.same(ledger.view().stadium_draft, layout)
		),
		label + " draft saves without premature activation: " + saved.error
	)
	if not saved.ok:
		return false
	var apply: Dictionary = {
		"id": "mastery-apply:%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_apply",
		"layout": layout,
		"geometry": StadiumMasteryBannerItems.geometry(ledger.view().land, layout)
	}
	var bad: Dictionary = apply.duplicate(true)
	bad.id += ":wrong-geometry"
	bad.geometry = "incorrect-family-signature"
	_refuse(ledger, bad, label + " wrong geometry refuses atomically")
	var result: Dictionary = ledger.commit(apply)
	check(
		(
			result.ok
			and ClubCareer.same(ledger.view().stadium_active, layout)
			and ledger.balance() == balance
			and ClubCareer.same(ledger.construction().to_data(), stock_before)
		),
		(
			label
			+ " Apply activates only exact saved draft without spending/ownership change: "
			+ result.error
		)
	)
	if not result.ok:
		return false
	var complete: Dictionary = ledger.to_data()
	check(
		(
			ledger.commit(draft).get("replayed", false)
			and ledger.commit(apply).get("replayed", false)
			and ClubCareer.same(ledger.to_data(), complete)
		),
		label + " exact draft/Apply retries are idempotent"
	)
	return true


func _refuse(ledger: ClubAssetLedger, command: Dictionary, label: String) -> void:
	var before: Dictionary = ledger.to_data()
	var generation: int = ledger.mutation_generation()
	var denied: Dictionary = ledger.commit(command)
	check(
		(
			not denied.ok
			and ClubCareer.same(before, ledger.to_data())
			and generation == ledger.mutation_generation()
		),
		label
	)


func _cold(ledger: ClubAssetLedger, label: String) -> void:
	var cold: ClubAssetLedger = _load(_json(ledger.to_data()))
	check(
		cold != null and ClubCareer.same(cold.to_data(), ledger.to_data()),
		label + " full cold journal replay retains canonical header/events"
	)
	if cold != null:
		check(
			(
				ClubCareer.same(cold.view(), ledger.view())
				and ClubCareer.same(cold.construction().to_data(), ledger.construction().to_data())
			),
			label + " full cold replay retains active/draft/wallet/inventory"
		)


func _load(value: Variant) -> ClubAssetLedger:
	return ClubAssetLedger.from_data(value, SEED, credits, progress, authority)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

extends Node
## Synthetic funding isolates exact copy receipts and field-prefix preservation.

var _failures: int = 0
var _flag_checks: int = 0


var _ground_checks: int = 0

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--club-flag"):
		_flag_owned()
		return
	var credits: Array = [500, 500, 500, 500]
	var progress: Array = []
	for index in range(4):
		progress.append({"seasons": 1, "wins": 5})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(6, credits, progress)
	var original: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var board: Dictionary = _buy(ledger, "ST-039", 2)
	_check(ledger.preview(board).price == 540, "two boards cost one blueprint and two copies")
	_check(ledger.commit(board).ok and ledger.balance() == 1460, "exact board charge")
	_check(
		ledger.commit(board).replayed and ledger.balance() == 1460, "board receipt is idempotent"
	)
	_check(
		ledger.commit(_buy(ledger, "ST-041", 2)).ok and ledger.balance() == 1310,
		"two independent signs cost 100 plus 25 plus 25"
	)
	_check(ledger.construction().copies.size() == 7, "no mounted extras or invisible free copies")
	var layout: Dictionary = StadiumClubItems.upgrade(StadiumStarterLayout.empty())
	layout.displays = [
		{"copy": "purchase:display:0:0", "site": "SCORE-SMALL"},
		{"copy": "purchase:display:1:0", "site": "SIGN-GROUND-L"},
		{"copy": "purchase:display:1:1", "site": "SIGN-GROUND-R"}
	]
	_check(
		ledger.commit({"id": "draft", "rev": 2, "op": "stadium_draft", "layout": layout}).ok,
		"one scoreboard and two distinct handed signs can be drafted"
	)
	_check(
		(
			ledger
			. commit(
				{
					"id": "apply",
					"rev": 3,
					"op": "stadium_apply",
					"layout": layout,
					"geometry": StadiumHomeLayout.geometry("backyard", layout)
				}
			)
			. ok
		),
		"free exact display Apply"
	)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(
		snapshot.layout.version == 4 and StadiumLayoutSnapshot.matches(snapshot, ledger),
		"version-four layout preserves exact ownership"
	)
	_check(StadiumLayoutSnapshot.matches(original, ledger), "old home prefix remains unchanged")
	var moved: Dictionary = layout.duplicate(true)
	moved.displays[0].copy = "purchase:display:0:1"
	var preview: Dictionary = StadiumHomeLayout.preview(layout, moved, ledger.construction())
	_check(
		preview.ok and preview.cost == 0 and preview.displaced == ["purchase:display:0:0"],
		"scoreboard replacement previews the precise old copy going to storage"
	)
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 6, credits, progress
	)
	_check(
		restored != null and ClubCareer.same(restored.view(), ledger.view()),
		"display receipts and placement replay exactly"
	)
	_tamper(ledger, credits, progress, layout)
	if _failures == 0:
		print(
			"Wiffaltro owned display checks passed: exact copies, free replacement and old snapshots."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _buy(ledger: ClubAssetLedger, item: String, quantity: int) -> Dictionary:
	return {
		"id": "display:%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": 3,
		"through": 4,
		"progress_through": 4
	}


func _tamper(ledger: ClubAssetLedger, credits: Array, progress: Array, layout: Dictionary) -> void:
	var fresh: ClubAssetLedger = ClubAssetLedger.new(6, credits, progress)
	for patch: Dictionary in [
		{"item": "ST-040"},
		{"item": "ST-080"},
		{"item": true},
		{"price_version": true},
		{"price_version": 2},
		{"progress_through": 1},
		{"progress_through": true},
		{"progress_through": 5},
		{"quantity": 0},
		{"through": 0}
	]:
		var command: Dictionary = _buy(fresh, "ST-039", 1)
		command.merge(patch, true)
		_check(
			not fresh.commit(command).ok and fresh.revision() == 0,
			"unsupported, malformed or stale display request leaves ownership unchanged"
		)
	var data: Dictionary = ledger.to_data()
	data.version = 8
	data.erase("display_catalog")
	data.erase("display_layout_catalog")
	data.erase("ground_catalog")
	data.erase("ground_layout_catalog")
	data.erase("bleacher_catalog")
	data.erase("bleacher_layout_catalog")
	data.erase("target_catalog")
	data.erase("target_layout_catalog")
	data.erase("net_catalog")
	data.erase("net_layout_catalog")
	data.erase("light_catalog")
	data.erase("light_layout_catalog")
	data.erase("infield_catalog")
	data.erase("infield_layout_catalog")
	data.erase("wall_catalog")
	data.erase("wall_layout_catalog")
	data.erase("surface_catalog")
	data.erase("surface_layout_catalog")
	data.erase("surface_origin")
	data.erase("wall_piece_catalog")
	data.erase("advanced_layout_catalog")
	data.erase("scoreboard_catalog")
	data.erase("scoreboard_layout_catalog")
	data.erase("mounted_scoreboard_layout_catalog")
	data.erase("pool_catalog")
	data.erase("pool_layout_catalog")
	_check(
		ClubAssetLedger.from_data(data, 6, credits, progress) == null,
		"older journal cannot smuggle display purchases or geometry"
	)
	data = fresh.to_data()
	data.version = 8
	data.erase("display_catalog")
	data.erase("display_layout_catalog")
	data.erase("ground_catalog")
	data.erase("ground_layout_catalog")
	data.erase("bleacher_catalog")
	data.erase("bleacher_layout_catalog")
	data.erase("target_catalog")
	data.erase("target_layout_catalog")
	data.erase("net_catalog")
	data.erase("net_layout_catalog")
	data.erase("light_catalog")
	data.erase("light_layout_catalog")
	data.erase("infield_catalog")
	data.erase("infield_layout_catalog")
	data.erase("wall_catalog")
	data.erase("wall_layout_catalog")
	data.erase("surface_catalog")
	data.erase("surface_layout_catalog")
	data.erase("surface_origin")
	data.erase("wall_piece_catalog")
	data.erase("advanced_layout_catalog")
	data.erase("scoreboard_catalog")
	data.erase("scoreboard_layout_catalog")
	data.erase("mounted_scoreboard_layout_catalog")
	data.erase("pool_catalog")
	data.erase("pool_layout_catalog")
	_check(
		ClubAssetLedger.from_data(data, 6, credits, progress) != null,
		"older style journal remains valid without inventing displays"
	)
	var bad: Dictionary = layout.duplicate(true)
	bad.displays[2].copy = bad.displays[1].copy
	_check(
		not StadiumHomeLayout.validate(bad, ledger.construction()).ok,
		"one purchased sign cannot be placed on both sides"
	)
	bad = layout.duplicate(true)
	bad.obstacles = [{"copy": "purchase:display:0:0", "site": "O-L1", "yaw": 0}]
	_check(
		not StadiumHomeLayout.validate(bad, ledger.construction()).ok,
		"scenery cannot bypass the live-object budget by using an obstacle site"
	)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _flag_owned() -> void:
	var credits: Array = [500, 500]
	var progress: Array = [{"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 2}]
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(6, credits, progress)
	var initial: Dictionary = ledger.to_data()
	var original: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var entry: Dictionary = StadiumCatalog.item("ST-043")
	_flag_check(
		(
			entry.blueprint_price == 190
			and entry.copy_price == 55
			and entry.requires == {"seasons": 2, "wins": 5}
		),
		"exact approved existing catalog price and access"
	)
	_flag_check(
		not (
			StadiumFlagItems
			. quote(ledger.construction(), "ST-043", 1, "low-seasons", {"seasons": 1, "wins": 5})
			. ok
		),
		"one completed season refuses"
	)
	_flag_check(
		not (
			StadiumFlagItems
			. quote(ledger.construction(), "ST-043", 1, "low-wins", {"seasons": 2, "wins": 4})
			. ok
		),
		"four regular wins refuse"
	)
	var poor: ClubAssetLedger = ClubAssetLedger.new_club(6, [100, 100], progress)
	_flag_check(
		not poor.commit(_flag_buy(poor, 1)).ok and poor.revision() == 0,
		"insufficient wallet preserves ownership"
	)
	_flag_check(
		not (
			StadiumPurchases
			. quote(
				ledger.construction(),
				"ST-043",
				1,
				"old-price",
				StadiumPurchases.DISPLAY_VERSION,
				{"seasons": 2, "wins": 5}
			)
			. ok
		),
		"old display catalog cannot acquire a flag"
	)
	var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
		ledger.view().stadium_active, ledger.surface_owned()
	)
	_flag_check(
		not terrain.is_empty() and _flag_apply(ledger, terrain),
		"ordinary rough terrain is adopted before flag purchase"
	)
	if terrain.is_empty():
		_flag_owned_finish()
		return
	var terrain_prefix: Dictionary = ledger.to_data()
	var terrain_revision: int = ledger.revision()
	_flag_check(
		terrain_prefix.version == 24 and ledger.prefix(0).to_data() == initial,
		"terrain24 and original23 prefixes remain exact"
	)
	var command: Dictionary = _flag_buy(ledger, 2)
	var quote: Dictionary = ledger.preview(command)
	_flag_check(quote.ok and quote.price == 300, "two flags quote190 plus two55 copies")
	_flag_check(
		ledger.commit(command).ok and ledger.balance() == 700,
		"actual ledger debits exact first pair"
	)
	_flag_check(
		ledger.commit(command).replayed and ledger.balance() == 700,
		"exact request replay cannot debit twice"
	)
	var copy_prefix: String = "purchase:" + command.id
	_flag_check(
		ledger.commit(_flag_buy(ledger, 1)).ok and ledger.balance() == 645,
		"additional flag pays55 only"
	)
	_flag_check(
		ledger.construction().copies.size() == 6 and ledger.construction().blueprints.has("ST-043"),
		"three exact purchased flags plus three starter copies"
	)
	var prep: Dictionary = {
		"id": "flag-prep",
		"rev": ledger.revision(),
		"op": "stadium_surface",
		"through": 2,
		"price_version": StadiumSurfaceProgression.VERSION,
		"item": "ground_prep"
	}
	_flag_check(
		ledger.commit(prep).ok, "existing ground preparation is bought through the ordinary journal"
	)
	var paid_balance: int = ledger.balance()
	for mode: String in ["rough", "prepared"]:
		var layout: Dictionary = StadiumFlagItems.upgrade(terrain, ledger.surface_owned())
		layout.surface.condition = mode
		layout.flags = [
			{"copy": copy_prefix + ":0", "site": "FLAG-GROUND-L"},
			{"copy": copy_prefix + ":1", "site": "FLAG-GROUND-R"}
		]
		var checked: Dictionary = StadiumOwnedLayout.validate(
			layout,
			ledger.construction(),
			ledger.wall_pieces(),
			ledger.surface_owned(),
			"backyard",
			ledger.scoreboards()
		)
		_flag_check(
			checked.ok and checked.live_units == 0 and checked.placements.size() == 2,
			"both flag placements remain decorative on selected terrain"
		)
		_flag_check(
			_flag_apply(ledger, layout) and ledger.balance() == paid_balance,
			"rough and leveled composite each commit without another flag charge"
		)
		var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
		_flag_check(
			(
				snapshot.get("version") == 28
				and snapshot.layout.version == 18
				and snapshot.layout.base_version == 17
				and StadiumLayoutSnapshot.matches(snapshot, ledger)
				and snapshot.terrain.mode == ("leveled" if mode == "prepared" else "rough")
			),
			"complete terrain and flag ownership survive entry28"
		)
		var fixture: Dictionary = StadiumLayoutSnapshot.terrain_fixture(snapshot, 101, 3)
		var decoded: Variant = JSON.parse_string(JSON.stringify(fixture))
		var contact_projection: Dictionary = fixture.duplicate(true)
		contact_projection.layout = StadiumFlagItems.contacts_layout(layout)
		_flag_check(
			(
				StadiumLayoutSnapshot.valid(decoded)
				and ClubCareer.same(StadiumLayoutSnapshot.normalized(decoded), fixture)
				and PhysicalStadiumContacts.valid([], [], contact_projection)
			),
			"fixture29 cold canonical join and ordinary decorative contact projection"
		)
	var active: Dictionary = ledger.view().stadium_active
	var flat: Dictionary = StadiumFlagItems.with_base(
		active, StadiumSurfaceLayout.terrain_base(StadiumFlagItems.base(active))
	)
	_flag_check(
		(
			flat.version == 18
			and flat.base_version == 12
			and flat.flags == active.flags
			and _flag_apply(ledger, flat)
		),
		"explicit flat return retains exact flag copies"
	)
	var flat_snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_flag_check(
		flat_snapshot.get("version") == 8 and StadiumLayoutSnapshot.matches(flat_snapshot, ledger),
		"flat flag layout uses unchanged complete surface entry8"
	)
	var fixture: Dictionary = flat_snapshot.duplicate(true)
	fixture.version = 9
	fixture["environment"] = StadiumFixtureEnvironment.capture(flat_snapshot, 101, 3)
	_flag_check(
		StadiumLayoutSnapshot.valid(fixture) and fixture.environment.mode == "day",
		"flat flag fixture9 remains honest daylight"
	)
	_flag_check(
		(
			ledger.to_data().version == 25
			and ledger.to_data().has("terrain_catalog")
			and ledger.prefix(terrain_revision).to_data() == terrain_prefix
			and StadiumLayoutSnapshot.matches(original, ledger)
		),
		"journal25 keeps exact prior terrain24 and original home prefix"
	)
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 6, credits, progress
	)
	_flag_check(
		(
			restored != null
			and ClubCareer.same(restored.view(), ledger.view())
			and ClubCareer.same(restored.to_data(), ledger.to_data())
		),
		"full journal25 cold replay preserves every paid operand"
	)
	for patch: Dictionary in [
		{"flag_catalog": "bad"},
		{"flag_layout_catalog": "bad"},
		{"terrain_catalog": "bad"},
		{"version": true}
	]:
		var bad: Dictionary = ledger.to_data()
		bad.merge(patch, true)
		_flag_check(
			ClubAssetLedger.from_data(bad, 6, credits, progress) == null,
			"malformed new catalog or version refuses"
		)
	var bad: Dictionary = ledger.to_data()
	bad.version = 24
	bad.erase("flag_catalog")
	bad.erase("flag_layout_catalog")
	_flag_check(
		ClubAssetLedger.from_data(bad, 6, credits, progress) == null,
		"old24 cannot smuggle flag events"
	)
	bad = initial.duplicate(true)
	bad.version = 25
	bad["flag_catalog"] = StadiumFlagItems.price_signature()
	bad["flag_layout_catalog"] = StadiumFlagItems.signature()
	_flag_check(
		ClubAssetLedger.from_data(bad, 6, credits, progress) == null,
		"empty flag25 declaration cannot collapse to legacy23"
	)
	bad = flat.duplicate(true)
	bad.flags[1].copy = bad.flags[0].copy
	_flag_check(
		not StadiumFlagItems.validate(bad, ledger.construction()).ok,
		"one exact flag cannot occupy both sites"
	)
	bad = flat.duplicate(true)
	bad.flags[0].site = "O-L1"
	_flag_check(
		not StadiumFlagItems.validate(bad, ledger.construction()).ok,
		"a live obstacle site cannot host decorative flags"
	)
	bad = flat.duplicate(true)
	bad.base_version = true
	_flag_check(
		not StadiumFlagItems.validate(bad, ledger.construction()).ok,
		"malformed composite base refuses"
	)
	var moved: Dictionary = flat.duplicate(true)
	moved.flags = [{"copy": copy_prefix + ":1", "site": "FLAG-GROUND-L"}]
	var preview: Dictionary = StadiumOwnedLayout.preview(
		flat,
		moved,
		ledger.construction(),
		ledger.wall_pieces(),
		ledger.surface_owned(),
		"backyard",
		ledger.scoreboards()
	)
	_flag_check(
		(
			preview.ok
			and preview.cost == 0
			and preview.displaced == [copy_prefix + ":0"]
			and preview.moved == [copy_prefix + ":1"]
		),
		"replacement stores exact displaced copy with no debit"
	)
	_flag_owned_finish()


func _flag_buy(ledger: ClubAssetLedger, quantity: int) -> Dictionary:
	return {
		"id": "flag:%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_buy",
		"item": "ST-043",
		"quantity": quantity,
		"price_version": StadiumFlagItems.PRICE_VERSION,
		"through": 2,
		"progress_through": 2
	}


func _flag_apply(ledger: ClubAssetLedger, layout: Dictionary) -> bool:
	var revision: int = ledger.revision()
	return (
		(
			ledger
			. commit(
				{
					"id": "flag-draft:%d" % revision,
					"rev": revision,
					"op": "stadium_draft",
					"layout": layout
				}
			)
			. ok
		)
		and (
			ledger
			. commit(
				{
					"id": "flag-apply:%d" % (revision + 1),
					"rev": revision + 1,
					"op": "stadium_apply",
					"layout": layout,
					"geometry": StadiumOwnedLayout.geometry("backyard", layout)
				}
			)
			. ok
		)
	)


func _flag_check(ok: bool, message: String) -> void:
	_flag_checks += 1
	_check(ok, message)


func _flag_owned_finish() -> void:
	print(
		(
			"STADIUM_CLUB_FLAG_OWNED checks=%d failures=%d games=0 synthetic_history=true"
			% [_flag_checks, _failures]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)




func ground_props_owned() -> Dictionary:
	var credits: Array = [700, 700, 700, 700, 700]
	var progress: Array = []
	for index in range(5):
		progress.append({"seasons": 1, "wins": 4})
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(6, credits, progress)
	var original: Dictionary = ledger.to_data()
	var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
		ledger.view().stadium_active, ledger.surface_owned()
	)
	_ground_check(
		_ground_apply(ledger, terrain), "rough terrain adopts through the ordinary journal"
	)
	var terrain_revision: int = ledger.revision()
	var terrain_prefix: Dictionary = ledger.to_data()
	var flag_command: Dictionary = _ground_buy(ledger, "ST-043", 2, StadiumFlagItems.PRICE_VERSION)
	_ground_check(
		ledger.commit(flag_command).ok, "two real flags are bought before the additive cohort"
	)
	var flags: Dictionary = StadiumFlagItems.upgrade(terrain, ledger.surface_owned())
	flags.flags = [
		{"copy": "purchase:" + flag_command.id + ":0", "site": "FLAG-GROUND-L"},
		{"copy": "purchase:" + flag_command.id + ":1", "site": "FLAG-GROUND-R"}
	]
	_ground_check(_ground_apply(ledger, flags), "complete flag18 rough base installs first")
	var flag_revision: int = ledger.revision()
	var flag_prefix: Dictionary = ledger.to_data()
	var copies: Dictionary = {}
	var purchased: bool = true
	for item: String in StadiumGroundPropsItems.PRICES:
		var entry: Dictionary = StadiumCatalog.item(item)
		var prices: Array = StadiumGroundPropsItems.PRICES[item]
		var command: Dictionary = _ground_buy(ledger, item)
		var quote: Dictionary = ledger.preview(command)
		_ground_check(
			(
				entry.blueprint_price == prices[0]
				and entry.copy_price == prices[1]
				and quote.ok
				and quote.price == prices[0] + prices[1]
				and not (
					StadiumGroundPropsItems
					. quote(ledger.construction(), item, 1, "locked", {"seasons": 1, "wins": 20})
					. ok
				)
			),
			"catalog price and actual unlock gate for " + item + " quote=" + JSON.stringify(quote)
		)
		purchased = ledger.commit(command).ok and purchased
		copies[item] = "purchase:" + command.id + ":0"
	_ground_check(
		purchased and ledger.balance() == 610 and ledger.construction().copies.size() == 14,
		(
			"nine real paid items join both flags and three starters; balance="
			+ str(ledger.balance())
			+ " copies="
			+ str(ledger.construction().copies.size())
		)
	)
	var extra: Dictionary = _ground_buy(ledger, "ST-015")
	_ground_check(
		(
			ledger.preview(extra).price == 35
			and ledger.commit(extra).ok
			and ledger.commit(extra).replayed
			and ledger.balance() == 575
		),
		"extra fern charges copy-only once"
	)
	var extra_copy: String = "purchase:" + extra.id + ":0"
	_ground_check(
		(
			(
				ledger
				. commit(
					{
						"id": "ground-prep",
						"rev": ledger.revision(),
						"op": "stadium_surface",
						"through": 5,
						"price_version": StadiumSurfaceProgression.VERSION,
						"item": "ground_prep"
					}
				)
				. ok
			)
			and ledger.balance() == 495
		),
		"ordinary preparation leaves the exact495 budget"
	)
	var poor: ClubAssetLedger = ClubAssetLedger.new_club(6, [1, 1, 1, 1, 1], progress)
	_ground_check(
		(
			not poor.commit(_ground_buy(poor, "ST-004")).ok
			and poor.revision() == 0
			and not (
				StadiumPurchases
				. quote(
					ledger.construction(),
					"ST-005",
					1,
					"no-car",
					StadiumGroundPropsItems.PRICE_VERSION,
					{"seasons": 99, "wins": 99}
				)
				. ok
			)
		),
		"insufficient wallet and out-of-scope car both refuse"
	)
	var layout: Dictionary = StadiumGroundPropsItems.upgrade(flags, ledger.surface_owned())
	layout.props = [
		{"copy": copies["ST-017"], "site": "BED-R"},
		{"copy": copies["ST-015"], "site": "PLANT-L1"},
		{"copy": copies["ST-016"], "site": "PLANT-L2"}
	]
	var arrangements: Array = [
		[
			{"copy": copies["ST-004"], "site": "OM-L"},
			{"copy": copies["ST-008"], "site": "O-R1"},
			{"copy": copies["ST-009"], "site": "O-R2"}
		],
		[{"copy": copies["ST-010"], "site": "OM-L"}, {"copy": copies["ST-011"], "site": "OM-R"}],
		[{"copy": copies["ST-012"], "site": "OL-L"}]
	]
	var paid: Array = []
	for arrangement: Array in arrangements:
		var current: ClubAssetLedger = ClubAssetLedger.from_data(
			JSON.parse_string(JSON.stringify(ledger.to_data())), 6, credits, progress
		)
		var next: Dictionary = layout.duplicate(true)
		next.props.append_array(arrangement)
		next.props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
		var checked: Dictionary = StadiumGroundPropsItems.validate(next, current.construction())
		_ground_check(
			(
				checked.ok
				and checked.live_units == 4
				and _ground_apply(current, next)
				and current.balance() == 495
			),
			"a complete measured four-unit arrangement installs free"
		)
		var snapshot: Dictionary = StadiumLayoutSnapshot.capture(current)
		var fixture: Dictionary = StadiumLayoutSnapshot.terrain_fixture(snapshot, 101, 3)
		_ground_check(
			(
				snapshot.get("version") == 28
				and snapshot.layout.version == 19
				and snapshot.layout.base_version == 17
				and snapshot.layout.flags == flags.flags
				and snapshot.terrain.mode == "rough"
				and StadiumLayoutSnapshot.matches(snapshot, current)
				and StadiumLayoutSnapshot.valid(JSON.parse_string(JSON.stringify(fixture)))
			),
			"rough entry28/fixture29 and complete flags survive cold normalization"
		)
		paid.append(current)
	var changed: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(paid[0].to_data())), 6, credits, progress
	)
	var active: Dictionary = changed.view().stadium_active
	var leveled: Dictionary = active.duplicate(true)
	leveled.surface.condition = "prepared"
	_ground_check(
		(
			_ground_apply(changed, leveled)
			and StadiumLayoutSnapshot.capture(changed).terrain.mode == "leveled"
			and changed.balance() == 495
		),
		"paid preparation changes grade without deleting props or flags"
	)
	var flat: Dictionary = StadiumGroundPropsItems.with_base(
		leveled,
		StadiumSurfaceLayout.terrain_base(
			StadiumFlagItems.base(StadiumGroundPropsItems.base(leveled))
		)
	)
	_ground_check(
		(
			flat.base_version == 12
			and flat.props == active.props
			and flat.flags == active.flags
			and _ground_apply(changed, flat)
			and StadiumLayoutSnapshot.capture(changed).version == 8
		),
		"explicit flat return preserves full paid composition"
	)
	var replacement: Dictionary = flat.duplicate(true)
	for row: Dictionary in replacement.props:
		if row.site == "PLANT-L1":
			row.copy = extra_copy
	var preview: Dictionary = StadiumOwnedLayout.preview(
		flat,
		replacement,
		changed.construction(),
		changed.wall_pieces(),
		changed.surface_owned(),
		"backyard",
		changed.scoreboards()
	)
	_ground_check(
		(
			preview.ok
			and preview.cost == 0
			and preview.displaced == [copies["ST-015"]]
			and _ground_apply(changed, replacement)
		),
		"replacement stores precisely the original fern"
	)
	var stored: Dictionary = replacement.duplicate(true)
	stored.props = []
	_ground_check(
		(
			_ground_apply(changed, stored)
			and _ground_apply(changed, flat)
			and changed.balance() == 495
			and changed.construction().to_data() == ledger.construction().to_data()
		),
		"store and free remount preserve every exact paid copy"
	)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(changed.to_data())), 6, credits, progress
	)
	_ground_check(
		(
			cold != null
			and ClubCareer.same(cold.view(), changed.view())
			and ClubCareer.same(cold.to_data(), changed.to_data())
			and changed.to_data().version == 26
		),
		"journal26 cold replay is exact"
	)
	_ground_check(
		(
			ClubCareer.same(changed.prefix(0).to_data(), original)
			and ClubCareer.same(changed.prefix(terrain_revision).to_data(), terrain_prefix)
			and ClubCareer.same(changed.prefix(flag_revision).to_data(), flag_prefix)
		),
		"all old23/24/25 prefixes remain exact across cold numeric normalization"
	)
	var bad: Dictionary = flat.duplicate(true)
	bad.props[1].copy = bad.props[0].copy
	_ground_check(
		not StadiumGroundPropsItems.validate(bad, changed.construction()).ok,
		"one copy cannot occupy two sites"
	)
	bad = flat.duplicate(true)
	bad.props.append({"copy": copies["ST-011"], "site": "OM-R"})
	bad.props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	var four: Dictionary = layout.duplicate(true)
	four = StadiumGroundPropsItems.with_base(
		four,
		StadiumSurfaceLayout.terrain_base(StadiumFlagItems.base(StadiumGroundPropsItems.base(four)))
	)
	four.obstacles = [
		{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-L2", "yaw": 0}
	]
	four.props.append_array(
		[{"copy": copies["ST-008"], "site": "O-R1"}, {"copy": copies["ST-009"], "site": "O-R2"}]
	)
	four.props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	var four_checked: Dictionary = StadiumGroundPropsItems.validate(four, changed.construction())
	var five: Dictionary = paid[2].view().stadium_active
	five = StadiumGroundPropsItems.with_base(
		five,
		StadiumSurfaceLayout.terrain_base(StadiumFlagItems.base(StadiumGroundPropsItems.base(five)))
	)
	five.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-R1", "yaw": 0}]
	var five_checked: Dictionary = StadiumGroundPropsItems.validate(five, changed.construction())
	_ground_check(
		(
			not StadiumGroundPropsItems.validate(bad, changed.construction()).ok
			and StadiumCatalog.within_live_budget(["ST-001", "ST-003", "ST-008", "ST-009"])
			and not StadiumCatalog.within_live_budget(
				["ST-001", "ST-003", "ST-008", "ST-009", "ST-008"]
			)
			and StadiumCatalog.within_live_budget(["ST-010", "ST-011"])
			and not StadiumCatalog.within_live_budget(["ST-012", "ST-001"])
			and four_checked.ok
			and four_checked.live_units == 4
			and not five_checked.ok
		),
		(
			"both four-instance/four-unit limits count old cone/chair rows; four="
			+ JSON.stringify(four_checked)
			+ " five="
			+ JSON.stringify(five_checked)
		)
	)
	bad = flat.duplicate(true)
	bad.props.append({"copy": extra_copy, "site": "PLANT-R1"})
	bad.props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	_ground_check(
		not StadiumGroundPropsItems.validate(bad, changed.construction()).ok,
		"flowerbed excludes its same-side small plants"
	)
	for key: String in ["ground_props_catalog", "ground_props_layout_catalog"]:
		bad = changed.to_data()
		bad[key] = "foreign"
		_ground_check(
			ClubAssetLedger.from_data(bad, 6, credits, progress) == null,
			"new cohort signature cannot be substituted"
		)
	bad = changed.to_data()
	bad.version = 25
	bad.erase("ground_props_catalog")
	bad.erase("ground_props_layout_catalog")
	_ground_check(
		ClubAssetLedger.from_data(bad, 6, credits, progress) == null,
		"old journal cannot hide new paid events"
	)
	return {"checks": _ground_checks, "failures": _failures, "paid": paid}


func _ground_buy(
	ledger: ClubAssetLedger,
	item: String,
	quantity: int = 1,
	price_version: int = StadiumGroundPropsItems.PRICE_VERSION
) -> Dictionary:
	return {
		"id": "ground-props:%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": price_version,
		"through": 5,
		"progress_through": 5
	}


func _ground_apply(ledger: ClubAssetLedger, layout: Dictionary) -> bool:
	var draft: Dictionary = ledger.commit(
		{
			"id": "ground-draft:%d" % ledger.revision(),
			"rev": ledger.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	var applied: Dictionary = (
		ledger.commit(
			{
				"id": "ground-apply:%d" % ledger.revision(),
				"rev": ledger.revision(),
				"op": "stadium_apply",
				"layout": layout,
				"geometry": StadiumOwnedLayout.geometry("backyard", layout)
			}
		)
		if draft.ok
		else {}
	)
	if not draft.ok or not applied.get("ok", false):
		print(
			"GROUND_PROPS_APPLY_FAILURE ",
			JSON.stringify(
				{"draft": draft, "apply": applied, "balance": ledger.balance(), "layout": layout}
			)
		)
	return draft.ok and applied.get("ok", false)


func _ground_check(ok: bool, message: String) -> void:
	_ground_checks += 1
	_check(ok, message)

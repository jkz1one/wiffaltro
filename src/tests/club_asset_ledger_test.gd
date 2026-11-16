extends Node
## Synthetic credited-income fixtures isolate journal accounting; no real-season earning claim.

const GenerationData = preload("res://src/tests/stadium_mounted_scoreboard_test_data.gd")

var _failures: int = 0
var _checks: int = 0
var _generation_checks: int = 0


func _ready() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(17, [35, 65, 0])
	var opening: Dictionary = _open(ledger, "open:0", 2)
	var before: Dictionary = ledger.to_data()
	_check(ledger.preview(opening).balance_after == 20 and ledger.to_data() == before,
		"preview neither spends nor reveals a new saved pack")
	_check(ledger.commit(opening).ok and ledger.balance() == 20, "one real ledger charge")
	var choices: Array = ledger.view().pending.choices
	_check(choices.size() == 3 and ledger.commit(opening).replayed and ledger.balance() == 20,
		"same opening retries without another debit or reroll")
	_check(not ledger.commit(_open(ledger, "open:other", 2)).ok,
		"unresolved pack blocks another purchase")
	var saved: Variant = JSON.parse_string(JSON.stringify(ledger.to_data(), "", true, true))
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(saved, 17, [35, 65, 0])
	_check(restored != null and ClubCareer.same(ledger.view(), restored.view()),
		"paid reveal survives JSON reload exactly")
	for patch: Dictionary in [{"player": "player.alex_finch"}, {"player": "player.ash_cole"},
		{"pack": "wrong"}, {"extra": true}]:
		var bad_pick: Dictionary = _pick(ledger, "invalid", choices[0])
		bad_pick.merge(patch, true)
		_check(not ledger.commit(bad_pick).ok and ledger.balance() == 20,
			"forged, owned, feat-only or foreign choices preserve the paid reveal")
	var fork: ClubAssetLedger = ledger.fork()
	var pick: Dictionary = _pick(fork, "pick:0", choices[1])
	_check(fork.commit(pick).ok and ledger.view().pending.choices == choices,
		"private candidate selection cannot mutate the original")
	_check(fork.owned().has(choices[1]) and fork.balance() == 20 and fork.commit(pick).replayed,
		"choose once with no extra charge; duplicate retry stays idempotent")
	_check(not fork.commit(_pick(fork, "pick:again", choices[1])).ok,
		"no second choice from same pack")
	_check(not fork.commit(_open(fork, "open:poor", 2)).ok, "shared balance prevents overspend")
	var funded: ClubAssetLedger = fork.with_credits([35, 65, 180])
	_check(funded != null and funded.balance() == 200 and fork.balance() == 20,
		"new validated career earnings extend the same spending history")
	_check(funded.commit(_open(funded, "open:1", 3)).ok, "newly earned funds can buy next pack")
	_check(not funded.view().pending.choices.has(choices[1]), "owned character never appears again")
	_tamper(saved)
	_exhaustion()
	for credits: Variant in [[true], [-1], [NAN], [1.5], ["180"]]:
		_check(ClubAssetLedger.from_data(saved, 17, credits) == null, "invalid income rejects")
	_check(ClubAssetLedger.from_data(saved, 18, [35, 65, 0]) == null,
		"changed seed cannot reroll a save")
	_generation_controls()
	_check(_generation_checks == 119 and _checks + 1 == 227,
		"V61 ledger fixture must complete 119 generation and 227 total assertions")
	if _failures == 0:
		print("Wiffaltro asset ledger checks passed: exact spending, saved choice and exhaustion.")
		print("V61 generation assertions passed: %d." % _generation_checks)
		print("V61 ledger total assertions passed: %d." % _checks)
	get_tree().quit(0 if _failures == 0 else 1)


func _tamper(saved: Dictionary) -> void:
	for patch: Dictionary in [{"price_version": 99}, {"through": 1}, {"through": 3}, {"rev": 9}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.events[0].merge(patch, true)
		_check(ClubAssetLedger.from_data(bad, 17, [35, 65, 0]) == null,
			"forged price, unearned epoch, insufficient credit or revision rejects")
	var repeated: Dictionary = saved.duplicate(true)
	repeated.events.append(repeated.events[0].duplicate(true))
	_check(ClubAssetLedger.from_data(repeated, 17, [35, 65, 0]) == null,
		"duplicate event rows are not a second replayable debit")
	for patch: Dictionary in [{"version": true}, {"seed": true}, {"seed": "17"}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.merge(patch, true)
		_check(ClubAssetLedger.from_data(bad, 17, [35, 65, 0]) == null,
			"malformed top-level identity rejects")
	_check(ClubAssetLedger.from_data(saved, 17, [35, 5, 0]) == null,
		"erasing earned funding cannot retain paid ownership")
	var wrong: Dictionary = saved.duplicate(true)
	wrong.catalog = "changed"
	_check(ClubAssetLedger.from_data(wrong, 17, [35, 65, 0]) == null,
		"unknown catalog revision cannot silently change entitlement or revealed choices")


func _exhaustion() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(29, [2000])
	for index in range(18):
		_check(ledger.commit(_open(ledger, "open:%d" % index, 1)).ok, "open next unowned pack")
		var choices: Array = ledger.view().pending.choices
		_check(choices.size() == mini(3, 18 - index), "actual remaining choices are disclosed")
		var prior: Array = ledger.owned()
		_check(ledger.commit(_pick(ledger, "pick:%d" % index, choices[0])).ok,
			"select a offered unowned character")
		_check(ledger.owned().size() == prior.size() + 1, "one purchase owns exactly one new character")
	var before: Dictionary = ledger.to_data()
	_check(not ledger.commit(_open(ledger, "empty", 1)).ok and ledger.to_data() == before,
		"exhausted pool never burns currency or substitutes a feat character")
	_check(ledger.balance() == 560 and ledger.owned().size() == 30,
		"18 packs cost1440 trial CB and leave all18 feat characters separate")
	var copy: ClubAssetLedger = ClubAssetLedger.from_data(ledger.to_data(), 29, [2000])
	_check(copy != null and ClubCareer.same(copy.view(), ledger.view()),
		"whole purchase history replays")


func _open(ledger: ClubAssetLedger, id: String, through: int) -> Dictionary:
	return {"id": id, "rev": ledger.revision(), "op": "player_pack_open", "through": through,
		"price_version": ClubPlayerCatalog.PRICE_VERSION}


func _pick(ledger: ClubAssetLedger, id: String, player: String) -> Dictionary:
	return {"id": id, "rev": ledger.revision(), "op": "player_pack_pick",
		"pack": ledger.view().pending.get("id", ""), "player": player}


# These reuse existing synthetic accounting inputs and real journal commands only.
# They do not establish earned career eligibility, gameplay results or native execution.
func _generation_controls() -> void:
	_generation_construction()
	var ledger: ClubAssetLedger = _generation_operations()
	if ledger != null:
		_generation_aliases(ledger)
		_generation_replacements(ledger)
	_generation_exhaustion()


func _generation_construction() -> void:
	var legacy: ClubAssetLedger = ClubAssetLedger.new(GenerationData.SEED)
	_generation_check(legacy.mutation_generation() == 1 and legacy.revision() == 0,
		"constructor enters the first generation without creating a journal event")
	var rough: ClubAssetLedger = ClubAssetLedger.new_club(GenerationData.SEED)
	_generation_check(rough.mutation_generation() == 3 and rough.revision() == 0,
		"new club counts construction, rough origin and separately versioned salvage initialization")
	var before: Dictionary = GenerationData.state(rough)
	rough._initialize_surface_origin(StadiumSurfaceProgression.LEGACY_ORIGIN)
	_generation_check(rough.mutation_generation() == 4 and rough.revision() == 0
		and not ClubCareer.same(before, GenerationData.state(rough)),
		"live surface initialization advances generation despite unchanged journal revision")
	before = GenerationData.state(rough)
	rough._initialize_surface_origin(StadiumSurfaceProgression.LEGACY_ORIGIN)
	_generation_check(rough.mutation_generation() == 5 and rough.revision() == 0
		and ClubCareer.same(before, GenerationData.state(rough)),
		"repeated same-origin initialization cannot restore an earlier generation")
	rough._init(GenerationData.SEED)
	_generation_check(rough.mutation_generation() == 6 and rough.revision() == 0,
		"manual constructor entry advances rather than resets a live generation")
	rough._init(-1)
	_generation_check(rough.mutation_generation() == 7
		and not rough.commit(_open(rough, "invalid-init", 0)).ok
		and rough.mutation_generation() == 7,
		"invalid manual construction advances once and later rejection remains pure")
	var invalid: ClubAssetLedger = ClubAssetLedger.new(-1)
	_generation_check(invalid.mutation_generation() == 1
		and not invalid.commit(_open(invalid, "invalid-new", 0)).ok
		and invalid.mutation_generation() == 1,
		"invalid fresh construction still has a generation and cannot publish")
	var credits: Array = GenerationData.credits()
	var progress: Array = GenerationData.progress()
	var copied: ClubAssetLedger = ClubAssetLedger.new(GenerationData.SEED, credits, progress)
	before = GenerationData.state(copied)
	_corrupt_generation_output(credits)
	_corrupt_generation_output(progress)
	_generation_check(_generation_unchanged(copied, before, 1)
		and copied.preview(_generation_land(copied)).ok,
		"constructor credit and nested progress inputs cannot mutate trusted journal inputs")
	for key: String in ["mutation_generation", "_mutation_generation"]:
		var saved: Dictionary = legacy.to_data()
		_generation_check(not saved.has(key) and not legacy.view().has(key),
			"generation is absent from save and view: " + key)
		saved[key] = 1
		_generation_check(ClubAssetLedger.from_data(saved, GenerationData.SEED, []) == null,
			"strict import rejects a persisted generation field: " + key)


# gdlint: disable=max-returns
func _generation_operations() -> ClubAssetLedger:
	# This retained generation fixture predates salvage and exercises its original rough layout.
	# New-club salvage generation and clearance are covered by stadium_salvage_journal_test.
	var ledger: ClubAssetLedger = ClubAssetLedger.new(
		GenerationData.SEED, GenerationData.credits(), GenerationData.progress())
	ledger._initialize_surface_origin(StadiumSurfaceProgression.ROUGH_ORIGIN)
	if not _generation_command(ledger, _open(ledger, "generation-open", 22)):
		return null
	if not _generation_command(ledger, _pick(
		ledger, "generation-pick", ledger.view().pending.choices[0])):
		return null
	if not _generation_command(ledger,
		GenerationData.buy(ledger, "stadium_buy", "ST-001", 1)):
		return null
	if not _generation_command(ledger, _generation_land(ledger)):
		return null
	if not _generation_command(ledger, {"id": "generation-style", "rev": ledger.revision(),
		"op": "stadium_style", "through": 22, "progress_through": 22,
		"price_version": StadiumFieldStyles.VERSION, "item": "ST-062a"}):
		return null
	if not _generation_command(ledger, {"id": "generation-surface", "rev": ledger.revision(),
		"op": "stadium_surface", "through": 22,
		"price_version": StadiumSurfaceProgression.VERSION, "item": "ground_prep"}):
		return null
	if not _generation_command(ledger,
		GenerationData.buy(ledger, "stadium_wall_piece", "ST-024-L", 1)):
		return null
	if not _generation_command(ledger,
		GenerationData.buy(ledger, "stadium_scoreboard", "ST-090", 1)):
		return null
	var layout: Dictionary = ledger.view().stadium_draft
	layout.receiver = "starter-v1:ST-079"
	if not _generation_command(ledger, {"id": "generation-draft", "rev": ledger.revision(),
		"op": "stadium_draft", "layout": layout.duplicate(true)}):
		return null
	if not _generation_command(ledger, {"id": "generation-apply", "rev": ledger.revision(),
		"op": "stadium_apply", "layout": layout.duplicate(true),
		"geometry": StadiumOwnedLayout.geometry(ledger.view().land, layout)}):
		return null
	_generation_check(ledger.revision() == 10 and ledger.mutation_generation() == 12,
		"all ten supported operations each add exactly one transient generation")
	return ledger

# gdlint: enable=max-returns


func _generation_command(ledger: ClubAssetLedger, command: Dictionary) -> bool:
	var label: String = command.op
	var generation: int = ledger.mutation_generation()
	var revision: int = ledger.revision()
	var before: Dictionary = GenerationData.state(ledger)
	var preview: Dictionary = ledger.preview(command)
	_generation_check(preview.ok and not preview.replayed
		and _generation_unchanged(ledger, before, generation), label + ": preview is pure")
	_corrupt_generation_output(preview)
	_generation_check(_generation_unchanged(ledger, before, generation),
		label + ": mutable preview results have no live aliases")
	var stale: Dictionary = command.duplicate(true)
	stale.id += "-stale"
	stale.rev = revision + 1
	_generation_check(not ledger.commit(stale).ok
		and _generation_unchanged(ledger, before, generation),
		label + ": rejected future revision does not advance generation")
	var replay_command: Dictionary = command.duplicate(true)
	var result: Dictionary = ledger.commit(command)
	_generation_check(result.ok and not result.replayed and ledger.revision() == revision + 1
		and ledger.mutation_generation() == generation + 1,
		label + ": accepted command advances exactly once")
	if not result.ok:
		return false
	before = GenerationData.state(ledger)
	generation += 1
	_corrupt_generation_output(command)
	_corrupt_generation_output(result)
	_generation_check(_generation_unchanged(ledger, before, generation),
		label + ": accepted command and mutable commit result are detached")
	result = ledger.commit(replay_command)
	_generation_check(result.ok and result.replayed
		and _generation_unchanged(ledger, before, generation),
		label + ": exact duplicate replay does not advance generation")
	_corrupt_generation_output(result)
	_generation_check(_generation_unchanged(ledger, before, generation),
		label + ": mutable replay result is detached")
	replay_command.rev = ledger.revision()
	_generation_check(not ledger.commit(replay_command).ok
		and _generation_unchanged(ledger, before, generation),
		label + ": conflicting request identity does not advance generation")
	return true


func _generation_land(ledger: ClubAssetLedger) -> Dictionary:
	return {"id": "generation-land", "rev": ledger.revision(), "op": "stadium_land",
		"tier": "expanded", "through": 22, "progress_through": 22,
		"price_version": StadiumLand.VERSION}


func _generation_aliases(ledger: ClubAssetLedger) -> void:
	var generation: int = ledger.mutation_generation()
	_generation_check(ledger.commit(_open(ledger, "generation-alias-pending", 22)).ok
		and ledger.mutation_generation() == generation + 1,
		"alias control has a real paid pending pack with nested mutable choices")
	generation = ledger.mutation_generation()
	var before: Dictionary = GenerationData.state(ledger)
	for output: Variant in [ledger.view(), ledger.to_data(), ledger.surface_owned(), ledger.owned()]:
		_corrupt_generation_output(output)
		_generation_check(_generation_unchanged(ledger, before, generation),
			"public view, journal, surface and player containers are independently detached")
	var stock: StadiumStock = ledger.construction()
	_corrupt_generation_output(stock.copies)
	stock.blueprints.clear()
	stock.styles.clear()
	stock.starter = "unresolved"
	_generation_check(_generation_unchanged(ledger, before, generation),
		"public construction object and nested owned-copy rows are detached")
	var pieces: StadiumWallPieceOwnership = ledger.wall_pieces()
	_corrupt_generation_output(pieces.stock.copies)
	pieces.blueprints.clear()
	pieces.stock = StadiumWallPieceStock.new()
	_generation_check(_generation_unchanged(ledger, before, generation),
		"public wall-piece object, blueprint list and nested stock object are detached")
	var boards: StadiumScoreboardOwnership = ledger.scoreboards()
	_corrupt_generation_output(boards.copies)
	boards.blueprints.clear()
	_generation_check(_generation_unchanged(ledger, before, generation),
		"public scoreboard object and nested copy rows are detached")
	var saved: Dictionary = ledger.to_data()
	var credits: Array = GenerationData.credits()
	var progress: Array = GenerationData.progress()
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		saved, GenerationData.SEED, credits, progress)
	_generation_check(restored != null and restored != ledger
		and restored.mutation_generation() == restored.revision() + 2
		and ClubCareer.same(before, GenerationData.state(restored)),
		"strict replay creates an independently generated object with equal journal state")
	if restored == null:
		return
	var restored_before: Dictionary = GenerationData.state(restored)
	var restored_generation: int = restored.mutation_generation()
	_corrupt_generation_output(saved)
	_corrupt_generation_output(credits)
	_corrupt_generation_output(progress)
	var next_land: Dictionary = _generation_land(restored)
	next_land.id = "generation-import-alias"
	next_land.tier = "club"
	_generation_check(_generation_unchanged(restored, restored_before, restored_generation)
		and restored.preview(next_land).ok
		and _generation_unchanged(ledger, before, generation),
		"import event, credit and nested progress inputs cannot mutate either ledger")


func _generation_replacements(ledger: ClubAssetLedger) -> void:
	var before: Dictionary = GenerationData.state(ledger)
	var generation: int = ledger.mutation_generation()
	for replacement: ClubAssetLedger in [ledger.fork(), ledger.with_credits(GenerationData.credits()),
		ledger.prefix(ledger.revision())]:
		_generation_check(replacement != null and replacement != ledger
			and replacement.revision() == ledger.revision()
			and replacement.mutation_generation() == replacement.revision() + 2
			and ClubCareer.same(before, GenerationData.state(replacement)),
			"fork, credit replacement and full prefix retain bytes but create a distinct owner")
		if replacement == null:
			continue
		var replacement_generation: int = replacement.mutation_generation()
		_generation_check(replacement.commit({"id": "generation-replacement-draft",
			"rev": replacement.revision(), "op": "stadium_draft",
			"layout": replacement.view().stadium_draft}).ok
			and replacement.mutation_generation() == replacement_generation + 1
			and _generation_unchanged(ledger, before, generation),
			"mutating a reconstructed replacement cannot change its original's generation or bytes")
	var prefix: ClubAssetLedger = ledger.prefix(0)
	_generation_check(prefix != null and prefix != ledger and prefix.revision() == 0
		and prefix.mutation_generation() == 2 and _generation_unchanged(ledger, before, generation),
		"shorter prefix builds its own origin generation without touching the live original")
	_generation_check(ledger.prefix(-1) == null and ledger.prefix(ledger.revision() + 1) == null
		and _generation_unchanged(ledger, before, generation),
		"rejected prefix requests cannot alter the original generation")


func _generation_exhaustion() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(GenerationData.SEED, [1000])
	# Deliberate test-only private injection reaches the otherwise impractical integer limit.
	# Arbitrary private writes are not supported generation-tracked production mutations.
	ledger._mutation_generation = 9223372036854775806
	var opening: Dictionary = _open(ledger, "generation-max-open", 1)
	_generation_check(ledger.commit(opening).ok
		and ledger.mutation_generation() == 9223372036854775807 and ledger.revision() == 1,
		"last positive generation is representable and does not wrap")
	var before: Dictionary = GenerationData.state(ledger)
	_generation_check(ledger.commit(opening).replayed
		and _generation_unchanged(ledger, before, 9223372036854775807),
		"duplicate replay does not exhaust a generation")
	var pick: Dictionary = _pick(ledger, "generation-max-pick", ledger.view().pending.choices[0])
	var rejected: Dictionary = pick.duplicate(true)
	rejected.rev += 1
	_generation_check(not ledger.commit(rejected).ok
		and _generation_unchanged(ledger, before, 9223372036854775807),
		"rejection does not exhaust a generation")
	_generation_check(ledger.commit(pick).ok and ledger.mutation_generation() == -1
		and ledger.revision() == 2, "accepted overflow enters the permanent fail-safe sentinel")
	_generation_check(ledger.commit(_open(ledger, "generation-after-max", 1)).ok
		and ledger.mutation_generation() == -1 and ledger.revision() == 3,
		"ordinary journal work cannot revive exhausted ownership generation")
	ledger._initialize_surface_origin(StadiumSurfaceProgression.LEGACY_ORIGIN)
	_generation_check(ledger.mutation_generation() == -1,
		"surface initialization cannot revive exhausted generation")
	ledger._init(GenerationData.SEED)
	_generation_check(ledger.mutation_generation() == -1,
		"manual constructor entry cannot revive exhausted generation")
	_generation_check(not ledger.to_data().has("mutation_generation")
		and not ledger.to_data().has("_mutation_generation"),
		"even the exhausted sentinel is never serialized")


func _generation_unchanged(ledger: ClubAssetLedger, state: Dictionary, generation: int) -> bool:
	return ledger.mutation_generation() == generation \
		and ClubCareer.same(state, GenerationData.state(ledger))


func _corrupt_generation_output(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value.keys():
			_corrupt_generation_output(value[key])
		value["generation_alias_probe"] = true
	elif value is Array:
		for child: Variant in value:
			_corrupt_generation_output(child)
		value.clear()


func _generation_check(condition: bool, message: String) -> void:
	_generation_checks += 1
	_check(condition, "V61 generation: " + message)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)

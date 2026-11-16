extends Node
## Malformed inventory versions must reject before version-dependent key dispatch.

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	var legacy: Dictionary = StadiumStock.new_club().to_data()
	for value: Variant in [null, true, false, [], {}, "1", "6", 0, -1, 7, 1.5]:
		var bad: Dictionary = legacy.duplicate(true)
		bad.version = value
		var before: String = JSON.stringify(bad)
		_check(StadiumStock.from_data(bad) == null, "reject malformed version %s" % str(value))
		_check(JSON.stringify(bad) == before, "reject does not mutate caller")
		bad["extension_catalog"] = {}
		_check(StadiumStock.from_data(bad) == null, "extension key cannot rescue invalid version")
	for nonfinite: float in [INF, NAN]:
		var bad: Dictionary = legacy.duplicate(true)
		bad.version = nonfinite
		_check(StadiumStock.from_data(bad) == null, "nonfinite version rejects")
	var missing: Dictionary = legacy.duplicate(true)
	missing.erase("version")
	_check(StadiumStock.from_data(missing) == null, "missing version rejects")
	for value: Variant in [null, true, false, [], "stock", 1, 1.0]:
		_check(StadiumStock.from_data(value) == null, "non-dictionary root rejects")
	_roundtrip(legacy, "historical stock1 grant")
	_roundtrip(StadiumStock.new().to_data(), "historical unresolved stock1")
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(175, [1000])
	_roundtrip(ledger.construction().to_data(), "current salvage stock3")
	var extension: StadiumStock = StadiumStock.new_club()
	extension.blueprints.append("ST-111")
	_roundtrip(extension.to_data(), "sealed extension stock6")
	var extra: Dictionary = legacy.duplicate(true)
	extra["extension_catalog"] = {}
	_check(StadiumStock.from_data(extra) == null, "legacy rejects extension-only key")
	var absent: Dictionary = extension.to_data()
	absent.erase("extension_catalog")
	_check(StadiumStock.from_data(absent) == null, "extension requires its exact seal field")
	print("STOCK_VERSION_GUARD_RESULT ", JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures == 0 else 1)


func _roundtrip(value: Dictionary, label: String) -> void:
	var bytes: String = JSON.stringify(value, "", true, true)
	for data: Dictionary in [value, JSON.parse_string(bytes)]:
		var restored: StadiumStock = StadiumStock.from_data(data)
		_check(restored != null, label + " accepts warm/JSON numeric versions")
		if restored != null:
			print("STOCK_COMPAT ", label, " ",
				JSON.stringify(restored.to_data(), "", true, true).sha256_text())
			_check(ClubCareer.same(restored.to_data(), data),
				label + " preserves JSON-normalized historical values")
	_check(JSON.stringify(value, "", true, true) == bytes, label + " preserves input")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)

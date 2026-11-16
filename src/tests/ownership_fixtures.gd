class_name OwnershipFixtures
extends RefCounted
## Synthetic transaction fixtures, never season-shop stock or gameplay effects.


static func catalog() -> Dictionary:
	var result: Dictionary = {
		"fixture.bat6": {"kind": "gear", "slot": "bat", "price": 6, "sale": "half"},
		"fixture.bat15": {"kind": "gear", "slot": "bat", "price": 15, "sale": "half"},
		"fixture.ball0": {"kind": "gear", "slot": "ball", "price": 0, "sale": "half"},
		"fixture.misc99": {"kind": "gear", "slot": "misc", "price": 99, "sale": "half"},
		"fixture.card": {"kind": "held", "price": 0, "sale": "zero"},
		"fixture.capacity": {"kind": "sponsor", "price": 0, "sale": "half", "held_delta": 1},
		"fixture.blocked": {"kind": "sponsor", "price": 0, "sale": "blocked"},
		"fixture.zero_sale": {"kind": "sponsor", "price": 6, "sale": "zero"},
	}

	for index in range(6):
		result["fixture.sponsor%d" % index] = {"kind": "sponsor", "price": 0, "sale": "half"}
	return result


static func request(bank: SeasonOwnership, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id": "test-%d" % bank.revision(), "rev": bank.revision(), "op": op}
	result.merge(fields)
	return result


static func buy(
	bank: SeasonOwnership, offer: String, replace: String = "", discard: Array = []
) -> Dictionary:
	return request(bank, "buy", {"offer": offer, "replace": replace, "discard": discard})

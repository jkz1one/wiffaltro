extends RefCounted
## Exact original uncached builder, independent of the generated production return.

const VERSION = StadiumCatalog.VERSION
const ROWS = StadiumCatalog.ROWS
const STARTERS = StadiumCatalog.STARTERS
const LIVE_UNITS = StadiumCatalog.LIVE_UNITS
const LAND = StadiumCatalog.LAND


static func signature() -> String:
	var rules: Dictionary = {}
	for id: String in ROWS:
		var row: Array = ROWS[id]
		rules[id] = [row[1], row[2], row[3], row[4]]
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"items": rules,
				"starters": STARTERS,
				"units": LIVE_UNITS,
				"land": LAND
			},
			"",
			true,
			true
		)
		. sha256_text()
	)
